extends Node


# Net (autoload "Net"): the party / game session between up to 5 players.
#
# Topology: host-authoritative. The party leader is the host; everyone else is
# connected to the host (Steam relay through SteamMultiplayerPeer, or ENet in
# LAN test mode) and the host relays messages between clients.
#
# Who simulates what:
#   - Every player simulates their OWN character (movement, abilities,
#     resources, health, loot, XP) and streams it to the others 15x/s.
#     Others see it as a puppet (remote_player.gd).
#   - The host simulates the WORLD: enemy AI and health, boss / gate / exit.
#     It streams enemy snapshots 10x/s. Clients report their hits to the host;
#     the host tells a player when an enemy hits them. Kills, loot and XP are
#     then handled on every machine for its own player.
#
# Host migration: every client keeps its own copy of the world (the host's
# snapshots) plus the migration order (host first, then join order). If the
# host drops, everyone pauses, the next player in that order becomes host, the
# rest reconnect to them, the new host takes over the enemies from its own copy
# and play resumes. Players are identified by member id (Steam ID) - never by
# peer id, since peer ids change when the host changes.

signal members_changed
signal chat_received(sender: String, text: String)
signal system_message(text: String)
signal migration_state(active: bool)

const REMOTE_PLAYER = preload("res://scripts/net/remote_player.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const FROST_BOLT = preload("res://scripts/frost_bolt.gd")
const ARROW = preload("res://scripts/arrow.gd")
const BLIZZARD = preload("res://scripts/blizzard.gd")
const FIRE_WALL = preload("res://scripts/fire_wall.gd")
const CRUCIBLE = preload("res://scripts/crucible.gd")
const CINDER_RAIN = preload("res://scripts/cinder_rain.gd")
const PHOENIX = preload("res://scripts/phoenix.gd")
const SLEET_WAVE = preload("res://scripts/sleet_wave.gd")
const BALL_LIGHTNING = preload("res://scripts/ball_lightning.gd")
const THUNDERHEAD = preload("res://scripts/thunderhead.gd")
const ICE_PATCH = preload("res://scripts/ice_patch.gd")
const LIVE_WIRE = preload("res://scripts/live_wire.gd")
const LASH = preload("res://scripts/lash.gd")
const ARCANE_MARK = preload("res://scripts/arcane_mark.gd")
const REFLECTIONS = preload("res://scripts/reflections.gd")
const DECOY = preload("res://scripts/decoy.gd")
const TRACE_GHOST = preload("res://scripts/trace_ghost.gd")
const BREACH_FX = preload("res://scripts/breach_fx.gd")
const PUPPETEER = preload("res://scripts/puppeteer.gd")
const HYMN_RING = preload("res://scripts/hymn_ring.gd")
const CENSER = preload("res://scripts/censer.gd")
const WEAPON_WHEEL = preload("res://scripts/weapon_wheel.gd")
const BRAWLER_ORBS = preload("res://scripts/brawler_orbs.gd")
const ROGUE_FX = preload("res://scripts/rogue_fx.gd")
const SHARP_FX = preload("res://scripts/sharpshooter_fx.gd")
const LIGHT_MOTE = preload("res://scripts/light_mote.gd")
const PRISM = preload("res://scripts/prism.gd")
const LIGHT_BEAM = preload("res://scripts/light_beam.gd")
const MULCH = preload("res://scripts/mulch_patch.gd")
const NATURE_CREATURE = preload("res://scripts/nature_creature.gd")
const HOUND = preload("res://scripts/hound.gd")
const Balance = preload("res://scripts/balance.gd")
const Abilities = preload("res://scripts/abilities.gd")

const PLAYER_RATE := 15.0         # own character updates per second
const ENEMY_RATE := 10.0          # host enemy snapshots per second
const META_INTERVAL := 2.0        # host re-sends party info (roster, order, run)
const CONNECT_TIMEOUT := 7.0
const MIGRATE_WAIT := 6.0         # new host waits this long for the others to reconnect
const WIPE_RESTART_DELAY := 4.0   # everyone dead -> restart the floor after this

enum Role { NONE, HOST, CLIENT }

var online := false
var host_member := 0
var members := {}                 # member id -> {"name", "level", "addr"}
var order: Array = []             # member ids: host first, then join order (= migration order)
var queue_path := ""
var token := 0                    # which scene load we're in (host bumps it on every load)
var run := {}                     # {"path", "depth", "seed"} while in a dungeon, {} in the lobby
var puppets := {}                 # member id -> remote player node
var migrating := false

var _role: int = Role.NONE
var _peer_member := {}            # host: peer id -> member id
var _leaving := false
var _joining := false
var _join_deadline := 0.0
var _connect_addr := ""
var _player_t := 0.0
var _enemy_t := 0.0
var _meta_t := 0.0
var _wipe_t := 0.0
var _mig_candidates: Array = []
var _mig_expected: Array = []
var _mig_until := 0.0
var _overlay: CanvasLayer
var _overlay_label: Label

func _online() -> Node:
	return get_node("/root/Online")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	get_node("/root/SignalBus").chat_message.connect(_on_local_chat)
	_build_overlay()

# --- Queries -------------------------------------------------------------------------

func is_host() -> bool:
	return online and _role == Role.HOST

func is_client() -> bool:
	return online and _role == Role.CLIENT

## True where the world is simulated: offline, or on the host.
func authority() -> bool:
	return not is_client()

## In a session with at least one other player.
func with_others() -> bool:
	return online and members.size() > 1

func my_id() -> int:
	return int(_online().my_id)

func member_name(id: int) -> String:
	if members.has(id):
		return str(members[id].get("name", "?"))
	return "?"

func leader_name() -> String:
	return member_name(host_member)

func _local_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

## The current dungeon scene, if we're in the run the party is in.
func _world() -> Node:
	if run.is_empty():
		return null
	var s := get_tree().current_scene
	if s == null or s.scene_file_path != str(run.get("path", "")) or _local_player() == null:
		return null
	return s

func _connected() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## Local player + every other member's puppet in this scene.
func party_bodies() -> Array:
	var out: Array = []
	var p := _local_player()
	if p:
		out.append(p)
	for id in puppets:
		if is_instance_valid(puppets[id]):
			out.append(puppets[id])
	return out

func any_party_alive() -> bool:
	for b in party_bodies():
		if b.is_alive():
			return true
	return false

func body_of(member: int) -> Node3D:
	if member == my_id():
		return _local_player()
	var p: Variant = puppets.get(member)
	return p if p != null and is_instance_valid(p) else null

func member_of(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	if node.is_in_group("player"):
		return my_id()
	var m: Variant = node.get("member_id")
	return int(m) if m != null else 0

## Where this player starts in a room (spread out so nobody overlaps).
func spawn_offset() -> Vector3:
	if not online:
		return Vector3.ZERO
	var i := maxi(order.find(my_id()), 0)
	if i == 0:
		return Vector3.ZERO
	var a := TAU * float(i - 1) / 4.0
	return Vector3(cos(a), 0, sin(a)) * 1.8

## Stable id of an enemy: its node path inside the scene (spawns are seeded,
## so every machine builds the same names).
func enemy_id(e: Node) -> String:
	if e == null or not is_instance_valid(e):
		return ""
	if e.has_meta("net_id"):
		return str(e.get_meta("net_id"))
	var s := get_tree().current_scene
	if s == null or not s.is_ancestor_of(e):
		return ""
	var id := str(s.get_path_to(e))
	e.set_meta("net_id", id)
	return id

func _enemy(w: Node, id: String) -> Node:
	return w.get_node_or_null(NodePath(id)) if id != "" else null

func _say(text: String) -> void:
	system_message.emit(text)

# --- Session lifecycle ---------------------------------------------------------------

func _my_info() -> Dictionary:
	var pd := get_node_or_null("/root/PlayerData")
	return {"name": str(_online().my_name), "level": int(pd.level) if pd else 1, "addr": ""}

func host_session(peer: MultiplayerPeer) -> void:
	_reset()
	multiplayer.multiplayer_peer = peer
	online = true
	_role = Role.HOST
	host_member = my_id()
	members = {host_member: _my_info()}
	order = [host_member]
	_peer_member = {1: host_member}
	members_changed.emit()

func join_session(peer: MultiplayerPeer, host_id: int, address: String = "") -> void:
	_reset()
	multiplayer.multiplayer_peer = peer
	online = true
	_role = Role.CLIENT
	host_member = host_id
	_connect_addr = address
	members = {my_id(): _my_info()}
	order = [my_id()]
	_joining = true
	_join_deadline = _now() + CONNECT_TIMEOUT
	members_changed.emit()

func leave_session() -> void:
	var was_online := online
	_reset()
	online = false
	_role = Role.NONE
	host_member = 0
	members.clear()
	order.clear()
	queue_path = ""
	if migrating:
		_end_migration()
	if was_online:
		members_changed.emit()

func _reset() -> void:
	_close_peer()
	_free_puppets()
	_peer_member.clear()
	_joining = false

func _close_peer() -> void:
	var p := multiplayer.multiplayer_peer
	if p == null or p is OfflineMultiplayerPeer:
		return
	_leaving = true
	p.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_leaving = false

func _on_connected() -> void:
	_joining = false
	rpc_id(1, "_hello", my_id(), _my_info(), token if migrating else -1)

func _on_connection_failed() -> void:
	_joining = false
	if migrating:
		_mig_candidates.pop_front()
		_mig_next()
	else:
		_fail_join("Couldn't connect to the party.")

func _fail_join(text: String) -> void:
	_online().toast.emit(text)
	_online().leave_party(true)

func _on_server_disconnected() -> void:
	if _leaving or not online:
		return
	if migrating:
		_mig_candidates.pop_front()
		_mig_next()
	else:
		_begin_migration()

func _on_peer_disconnected(peer: int) -> void:
	if not is_host() or _leaving:
		return
	var member: int = int(_peer_member.get(peer, 0))
	_peer_member.erase(peer)
	if member == 0 or not members.has(member):
		return
	var n := member_name(member)
	members.erase(member)
	order.erase(member)
	_remove_puppet(member)
	_say("%s left the party." % n)
	_send_meta()
	members_changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func _hello(member: int, info: Dictionary, have_token: int) -> void:
	if not is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	if not members.has(member) and members.size() >= int(_online().max_party()):
		rpc_id(peer, "_rejected", "That party is full.")
		return
	info["addr"] = _peer_address(peer)
	_peer_member[peer] = member
	var is_new := not members.has(member)
	members[member] = info
	if not order.has(member):
		order.append(member)
	if is_new and not migrating:
		_say("%s joined the party." % str(info.get("name", "?")))
	_send_meta()
	# Pull them into the current dungeon if they aren't already in it.
	if not run.is_empty() and have_token != token:
		rpc_id(peer, "_load", run["path"], run["depth"], run["seed"], token, str(run.get("diff", "solo")), run.get("extra", {}))
	if migrating:
		_mig_expected.erase(member)
		if _mig_expected.is_empty():
			_finish_host_migration()
	members_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rejected(text: String) -> void:
	_fail_join(text)

func _peer_address(peer: int) -> String:
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer:
		var pp := (p as ENetMultiplayerPeer).get_peer(peer)
		if pp:
			return pp.get_remote_address()
	return ""

# --- Party info (host -> everyone) ------------------------------------------------------

func _send_meta() -> void:
	if not is_host() or not _connected():
		return
	if not run.is_empty():
		run["rez_elapsed"] = _now() - _rez_t0
		run["rez_used"] = _rez_used
	rpc("_meta", members, order, host_member, queue_path, run)

@rpc("authority", "call_remote", "reliable")
func _meta(m: Dictionary, o: Array, host: int, q: String, r: Dictionary) -> void:
	if not is_client() or migrating:
		return
	members = m
	order = o
	host_member = host
	if members.has(host) and str(members[host].get("addr", "")) == "":
		members[host]["addr"] = _connect_addr
	queue_path = q
	run = r
	_rez_take(r)
	_online().on_party_queue(q)
	for id in puppets.keys():
		if not members.has(id):
			_remove_puppet(id)
	members_changed.emit()

func set_queue(path: String) -> void:
	if is_host():
		queue_path = path
		_send_meta()

## Leader found another queued group: the whole party moves into it.
func merge_into(lobby: int) -> void:
	if not is_host():
		return
	if _connected():
		rpc("_merge", lobby)
	# Give the others a moment to get the message before we disconnect.
	get_tree().create_timer(1.0, true).timeout.connect(func(): _online().move_to_lobby(lobby))

@rpc("authority", "call_remote", "reliable")
func _merge(lobby: int) -> void:
	_online().move_to_lobby(lobby)

# --- Combat rez charges (the party's, host-owned; rules: RezKit) -------------------------
# Every machine keeps the run's start (on its own clock) and the charges used, so
# the HUD can count down and a new host after a migration carries on. The host's
# numbers win: they ride along with the party info (_send_meta).

var _rez_t0 := 0.0   # when this run started (this machine's clock)
var _rez_used := 0

func combat_rez_charges() -> int:
	return RezKit.charges(_now() - _rez_t0, _rez_used)

func combat_rez_next_in() -> float:
	return RezKit.next_charge_in(_now() - _rez_t0)

## A revive in combat went off: one charge is used (the host keeps the count).
func spend_combat_rez() -> void:
	_rez_used += 1
	if is_host():
		_send_meta()
	elif _connected():
		rpc_id(1, "_rez_spend", token)

@rpc("any_peer", "call_remote", "reliable")
func _rez_spend(t: int) -> void:
	if is_host() and t == token:
		_rez_used += 1
		_send_meta()

func _rez_take(r: Dictionary) -> void:
	if r.has("rez_elapsed"):
		_rez_t0 = _now() - float(r["rez_elapsed"])
		_rez_used = int(r.get("rez_used", 0))

# --- Chat ------------------------------------------------------------------------------

func _on_local_chat(sender: String, text: String) -> void:
	if online and sender == "You" and _connected():
		rpc("_chat", str(_online().my_name), text)

@rpc("any_peer", "call_remote", "reliable")
func _chat(sender: String, text: String) -> void:
	chat_received.emit(sender, text)

# --- Game flow (host decides, everyone loads) -------------------------------------------

## `extra` = what the run needs besides the scene: {"dungeon": recipe id, "lvl": enemy level}.
func start_game(path: String, start_floor: int = 1, extra: Dictionary = {}) -> void:
	if not is_host():
		return
	queue_path = ""
	_online().on_run_started()
	_rez_t0 = _now()   # a new run: no combat rez charges yet
	_rez_used = 0
	run = {"path": path, "depth": maxi(start_floor, 1), "seed": randi(),
		"diff": str(get_node("/root/GameManager").difficulty), "extra": extra}
	_broadcast_load()

func descend() -> void:
	if not is_host() or run.is_empty():
		return
	run["depth"] = int(run["depth"]) + 1
	run["seed"] = randi()
	_broadcast_load()

func restart_floor() -> void:
	if is_host() and not run.is_empty():
		_broadcast_load()

## GameManager.restart() while in a party.
func request_restart() -> void:
	if is_host() and not any_party_alive():
		restart_floor()
	elif is_host():
		_local_error("Your party is still fighting - the floor restarts if everyone falls.")
	else:
		_local_error("Waiting for your party - the floor restarts if everyone falls.")

func _broadcast_load() -> void:
	token += 1
	_send_meta()
	var diff := str(run.get("diff", "solo"))
	if _connected():
		rpc("_load", run["path"], run["depth"], run["seed"], token, diff, run.get("extra", {}))
	_load(run["path"], run["depth"], run["seed"], token, diff, run.get("extra", {}))

@rpc("authority", "call_remote", "reliable")
func _load(path: String, depth: int, seed_value: int, t: int, diff: String, extra: Dictionary = {}) -> void:
	token = t
	run = {"path": path, "depth": depth, "seed": seed_value, "diff": diff, "extra": extra}
	_free_puppets()
	_wipe_t = 0.0
	get_node("/root/GameManager").net_load(path, depth, seed_value, diff, extra)

## Host: the whole party goes back to the lobby together (after a cleared floor).
func return_to_menu() -> void:
	if not is_host():
		return
	token += 1
	run = {}
	_send_meta()
	if _connected():
		rpc("_to_menu", token)
	_to_menu(token)

@rpc("authority", "call_remote", "reliable")
func _to_menu(t: int) -> void:
	token = t
	run = {}
	_free_puppets()
	_online().on_run_ended()
	get_node("/root/GameManager").net_to_menu()

## Leaving the dungeon on your own = leaving the group (the rest carry on,
## with a new leader if it was you).
func leave_run() -> void:
	run = {}
	_online().leave_party(true)
	get_node("/root/GameManager").net_to_menu()

func _local_error(text: String) -> void:
	get_node("/root/SignalBus").action_error.emit(text)

# --- Streams ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not online:
		return
	if _joining and _now() > _join_deadline:
		_joining = false
		if migrating:
			_mig_candidates.pop_front()
			_mig_next()
		else:
			_fail_join("Couldn't reach the party.")
		return
	if migrating:
		if is_host() and _now() > _mig_until:
			for m in _mig_expected:
				members.erase(m)
				order.erase(m)
				_remove_puppet(m)
			_mig_expected.clear()
			_finish_host_migration()
		return
	if not _connected():
		return
	if is_host():
		_meta_t -= delta
		if _meta_t <= 0.0:
			_meta_t = META_INTERVAL
			_send_meta()
	var w := _world()
	if w == null or not with_others():
		return
	_player_t -= delta
	if _player_t <= 0.0:
		_player_t = 1.0 / PLAYER_RATE
		var p := _local_player()
		var st := p.get_node_or_null("Status")
		rpc("_pstate", token, my_id(), p.global_position, p.rotation.y, str(p.get("current_state")),
			int(p.get("health")), int(p.get("max_health")), _my_role(),
			int(st.total_absorb()) if st and st.has_method("total_absorb") else 0)
	if is_host():
		_enemy_t -= delta
		if _enemy_t <= 0.0:
			_enemy_t = 1.0 / ENEMY_RATE
			rpc("_esnap", token, _enemy_snapshot())
		_check_wipe(delta)

## My role for the others' party frames (from my bars; worked out once a second).
var _role_cache := "dps"
var _role_at := -10.0
func _my_role() -> String:
	if _now() - _role_at >= 1.0:
		_role_at = _now()
		_role_cache = Abilities.role_of_bar(get_node("/root/PlayerData").action_bar)
	return _role_cache

func _check_wipe(delta: float) -> void:
	if not Balance.ROGUELIKE_DEATH:
		return   # death costs nothing: everyone revives on their own
	var bodies := party_bodies()
	var alive := bodies.size() < members.size()   # someone still loading counts as alive
	for b in bodies:
		if b.is_alive():
			alive = true
	_wipe_t = 0.0 if alive else _wipe_t + delta
	if _wipe_t >= WIPE_RESTART_DELAY:
		_wipe_t = 0.0
		restart_floor()

# Remote player state.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pstate(t: int, member: int, pos: Vector3, yaw: float, anim: String, hp: int, mhp: int, role: String = "", shield: int = 0) -> void:
	if t != token or member == my_id():
		return
	var w := _world()
	if w == null:
		return
	var p := _puppet(member, w)
	if p:
		p.apply_state(pos, yaw, anim, hp, mhp, role, shield)

func _puppet(member: int, w: Node) -> Node:
	var existing: Variant = puppets.get(member)
	if existing != null and is_instance_valid(existing):
		return existing
	if not members.has(member):
		return null
	var p := CharacterBody3D.new()
	p.set_script(REMOTE_PLAYER)
	p.member_id = member
	p.display_name = member_name(member)
	p.name = "Remote_%d" % member
	w.add_child(p)
	puppets[member] = p
	return p

func _remove_puppet(member: int) -> void:
	var p: Variant = puppets.get(member)
	if p != null and is_instance_valid(p):
		p.queue_free()
	puppets.erase(member)

func _free_puppets() -> void:
	for id in puppets.keys():
		_remove_puppet(id)
	puppets.clear()

# Enemy snapshot rows: [id, pos, yaw, health, max_health, state, moving, top-threat member,
#   status rows, threat rows, shield (absorb) health]
func _enemy_snapshot() -> Array:
	var rows: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var moving: bool = Vector2(e.velocity.x, e.velocity.z).length() > 0.1
		rows.append([enemy_id(e), e.global_position, e.rotation.y, int(e.health), int(e.max_health),
			int(e.state), moving, member_of(e.top_threat()), _status_rows(e), _threat_rows(e), _absorb_of(e)])
	return rows

## Shield health on an enemy (Shielded elites, a Rime Shell): clients show it on
## the health bar and on their damage numbers.
func _absorb_of(e: Node) -> int:
	var st := e.get_node_or_null("Status")
	return int(st.total_absorb()) if st and st.has_method("total_absorb") else 0

## An enemy's threat table as [[member, threat], ...] (aggro warnings on clients).
func _threat_rows(e: Node) -> Array:
	var out: Array = []
	for row in e.get_threat_list():
		var m := member_of(row["node"])
		if m != 0:
			out.append([m, float(row["value"])])
	return out

## Active status effects on an enemy:
## [[effect .tres path, stacks, seconds left, source member, shield health left on it]]
## Clients mirror them (status label, and so a new host can keep them going).
func _status_rows(e: Node) -> Array:
	var out: Array = []
	var st := e.get_node_or_null("Status")
	if st == null or st.effects.is_empty():
		return out
	var now := _now()
	for id in st.effects:
		var fx: Dictionary = st.effects[id]
		var res: Resource = fx["res"]
		if res == null or res.resource_path == "" or res.resource_path.contains("::"):
			continue
		var src: Variant = fx["source"]
		out.append([res.resource_path, int(fx["stacks"]), maxf(float(fx["expires"]) - now, 0.0),
			member_of(src) if is_instance_valid(src) else 0, int(st.absorb_left(str(id)))])
	return out

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _esnap(t: int, rows: Array) -> void:
	if t != token or not is_client():
		return
	var w := _world()
	if w == null:
		return
	var seen := {}
	for row in rows:
		var e := _enemy(w, str(row[0]))
		if e and e.has_method("net_apply"):
			e.net_apply(row[1], row[2], row[3], row[4], row[5], row[6], row[7])
			if row.size() > 8 and e.has_method("net_apply_status"):
				e.net_apply_status(row[8])
			if row.size() > 9 and e.has_method("net_apply_threat"):
				e.net_apply_threat(row[9])
			if row.size() > 10 and e.has_method("net_apply_absorb"):
				e.net_apply_absorb(int(row[10]))
			seen[e] = true
	# Enemies the host doesn't have any more (killed before we got here): remove quietly.
	for e in get_tree().get_nodes_in_group("enemies"):
		if seen.has(e):
			e.set_meta("net_missing", 0)
			continue
		var miss := int(e.get_meta("net_missing", 0)) + 1
		e.set_meta("net_missing", miss)
		if miss >= 5 and e.has_method("net_remove"):
			e.net_remove()

# --- World events -----------------------------------------------------------------------

## Host: an enemy died (everyone runs its death -> own loot + XP).
func enemy_died(e: Node, killer: int = -1) -> void:
	if not is_host() or not _connected() or _world() == null:
		return
	rpc("_edied", token, enemy_id(e), killer)

@rpc("authority", "call_remote", "reliable")
func _edied(t: int, id: String, killer: int = -1) -> void:
	if t != token:
		return
	var w := _world()
	var e := _enemy(w, id) if w else null
	if e and e.has_method("net_die"):
		e.net_die(killer)

## Client: my hit on an enemy (already rolled here: crit/armor/resist).
## `tags` = the spell / ability's tags, `params` = per effect what my talents
## made of it ({"dur", "slow"}, see StatusContainer.params_of) so the host's
## copy lasts as long and slows as much as mine.
func report_enemy_damage(e: Node, amount: int, ability_id: String, threat_mult: float, effects: Array,
		tags: PackedStringArray = PackedStringArray(), params: Array = []) -> void:
	if not is_client() or not _connected():
		return
	var paths: Array = []
	var sent_params: Array = []
	for i in effects.size():
		var eff: Variant = effects[i]
		if eff is Resource and eff.resource_path != "":
			paths.append(eff.resource_path)
			sent_params.append(params[i] if i < params.size() and params[i] is Dictionary else {})
	rpc_id(1, "_cdmg", token, my_id(), enemy_id(e), amount, ability_id, threat_mult, paths, tags, sent_params)

@rpc("any_peer", "call_remote", "reliable")
func _cdmg(t: int, member: int, id: String, amount: int, _ability_id: String, threat_mult: float, paths: Array,
		tags: PackedStringArray = PackedStringArray(), params: Array = []) -> void:
	if not is_host() or t != token:
		return
	var w := _world()
	var e := _enemy(w, id) if w else null
	if e == null or not e.is_alive():
		return
	if e.has_method("is_evading") and e.is_evading():
		return   # running home: nothing lands (the hit was sent before that showed over there)
	var src := body_of(member)
	var threat_amount := amount
	if src and e.has_method("note_attacker"):
		e.note_attacker(src)
	if amount > 0 and e.has_method("count_hit"):
		e.count_hit(tags)   # (Pin the Shadow)
	if amount > 0:
		var st_abs := e.get_node_or_null("Status")
		var through := amount
		if st_abs and st_abs.has_method("absorb_damage"):
			through = st_abs.absorb_damage(amount)   # Rime Shell etc.
		if through > 0:
			e.take_damage(through)
	if not e.is_alive():
		return
	if amount > 0 or not paths.is_empty():   # 0-damage hits can still apply effects (Flash Freeze)
		var st := e.get_node_or_null("Status")
		if st:
			for i in paths.size():
				var eff := load(str(paths[i]))
				if eff:
					# (Its damage over time is dealt on that player's machine, not here.)
					st.apply(eff, src, tags)
					if i < params.size() and params[i] is Dictionary:
						st.tune(eff, src, params[i])
	if src:
		e.add_threat(src, maxf(float(threat_amount), 1.0) * threat_mult)

## Host: an enemy hit another player's character -> that player takes the hit.
## The enemy's damage unit goes along: only the host knows it for sure (Frenzy,
## and an enemy that already died - a Volatile elite's blast - has no copy left
## over there to ask).
func send_enemy_hit(enemy: Node, target: Node, base: float, tags: PackedStringArray, damage_type: String,
		ability_id: String = "enemy_melee") -> void:
	if not is_host() or not _connected():
		return
	var member := member_of(target)
	var unit := float(enemy.damage_unit()) if is_instance_valid(enemy) and enemy.has_method("damage_unit") else -1.0
	for peer in _peer_member:
		if int(_peer_member[peer]) == member and int(peer) != 1:
			rpc_id(int(peer), "_ehit", token, enemy_id(enemy), base, tags, damage_type, unit, ability_id)
			return

@rpc("authority", "call_remote", "reliable")
func _ehit(t: int, id: String, base: float, tags: PackedStringArray, damage_type: String,
		unit: float = -1.0, ability_id: String = "enemy_melee") -> void:
	if t != token:
		return
	var w := _world()
	var p := _local_player()
	if w == null or p == null or not p.is_alive():
		return
	get_node("/root/CombatSystem").deal(enemy_hit_info(_enemy(w, id), p, base, tags, damage_type, unit, ability_id))

## The hit an enemy lands on my character, as the host described it.
static func enemy_hit_info(enemy: Node, me: Node, base: float, tags: PackedStringArray, damage_type: String,
		unit: float, ability_id: String) -> RefCounted:
	var info := DamageInfo.make(enemy, me, base, ability_id if ability_id != "" else "enemy_melee")
	info.tags = tags
	if damage_type != "":
		info.damage_type = damage_type
	if unit > 0.0:
		info.unit = unit
	return info

# --- Support spells across the party (heals, shields, taunts, shatters) --------------
# Healing / shielding another player happens on THAT player's machine (they own
# their health); enemies' threat, taunts and shields on enemies live on the host.
# Solo (or on the host) these just run locally.

const RIME_SHELL_FOE := preload("res://data/effects/rime_shell_foe.tres")
const SHIELDS := preload("res://scripts/core/shields.gd")

## Peer id that talks for `member` (the host relays for everyone else).
func _peer_of(member: int) -> int:
	for peer in _peer_member:
		if int(_peer_member[peer]) == member:
			return int(peer)
	return 1 if member == host_member else 0

func _send_to_member(member: int, method: String, args: Array) -> void:
	if not _connected():
		return
	if is_host():
		var peer := _peer_of(member)
		if peer > 1:
			callv("rpc_id", [peer, method] + args)
	else:
		# Clients only talk to the host; it forwards.
		callv("rpc_id", [1, "_relay", member, method, args])

@rpc("any_peer", "call_remote", "reliable")
func _relay(member: int, method: String, args: Array) -> void:
	if not is_host() or not method.begins_with("_sup_"):
		return
	if member == my_id():
		callv(method, args)
	else:
		_send_to_member(member, method, args)

## Heal another player's character (a puppet) for an exact amount.
func heal_ally(target: Node, caster: Node, amount: int) -> void:
	var member := member_of(target)
	if member == 0 or amount <= 0:
		return
	_send_to_member(member, "_sup_heal", [token, member_of(caster), amount])

@rpc("any_peer", "call_remote", "reliable")
func _sup_heal(t: int, caster: int, amount: int) -> void:
	var p := _local_player()
	if t != token or p == null or not p.is_alive():
		return
	get_node("/root/CombatSystem").heal(body_of(caster), p, float(amount), "heal", true)   # a party member's heal

## Revive a downed party member (their machine stands them back up).
func revive_ally(target: Node, caster: Node) -> void:
	var member := member_of(target)
	if member != 0:
		_send_to_member(member, "_sup_revive", [token, member_of(caster)])

@rpc("any_peer", "call_remote", "reliable")
func _sup_revive(t: int, caster: int) -> void:
	var p := _local_player()
	if t == token and p and p.has_method("revive"):
		p.revive(body_of(caster))

## A healer's out-of-combat rez: a dead (or downed) party member gets back up
## where they fell (their machine does it: GameManager.raise_local).
func raise_ally(target: Node, caster: Node) -> void:
	var member := member_of(target)
	if member != 0:
		_send_to_member(member, "_sup_raise", [token, member_of(caster)])

@rpc("any_peer", "call_remote", "reliable")
func _sup_raise(t: int, caster: int) -> void:
	if t == token:
		get_node("/root/GameManager").raise_local(str(member_name(caster)))

## A support effect for (or an answer to) another player's character: their
## machine's player handles it (Player.receive_support). `data` holds plain
## values only. Used by the Shadow healer's Strings: "heal", "string", "shield",
## "hold", "yank", and "cross_dmg" back from the ally to the healer.
func support_ally(target: Node, caster: Node, kind: String, data: Dictionary = {}) -> void:
	var member := member_of(target)
	if member != 0 and member != my_id():
		_send_to_member(member, "_sup_do", [token, member_of(caster), kind, data])

@rpc("any_peer", "call_remote", "reliable")
func _sup_do(t: int, caster: int, kind: String, data: Dictionary) -> void:
	var p := _local_player()
	if t != token or p == null or not p.has_method("receive_support"):
		return
	p.receive_support(kind, body_of(caster), data)

## Ping for the party (Pings.gd): kind "attack" (on an enemy) or "move".
func send_ping(kind: String, pos: Vector3, enemy: Node = null) -> void:
	if not with_others() or not _connected() or _world() == null:
		return
	rpc("_ping", token, my_id(), kind, pos, enemy_id(enemy) if enemy else "")

@rpc("any_peer", "call_remote", "reliable")
func _ping(t: int, member: int, kind: String, pos: Vector3, target_id: String) -> void:
	if t != token or member == my_id():
		return
	var w := _world()
	if w == null:
		return
	var pings := _local_player().get_node_or_null("Pings")
	var e := _enemy(w, target_id) as Node3D
	if pings and pings.has_method("show_ping"):
		pings.show_ping(member_name(member), kind, pos, e, member)

## Put a Rime Shell (absorbing `amount`) on another player's character.
## `armor_pct` = the caster's Hardened Frost, `shatters` = false with Everlasting Rime.
func shell_ally(target: Node, caster: Node, amount: int, armor_pct: float = 0.0, shatters: bool = true) -> void:
	var member := member_of(target)
	if member != 0:
		_send_to_member(member, "_sup_shell", [token, member_of(caster), amount, armor_pct, shatters])

@rpc("any_peer", "call_remote", "reliable")
func _sup_shell(t: int, caster: int, amount: int, armor_pct: float, shatters: bool) -> void:
	var p := _local_player()
	if t != token or p == null or not p.is_alive():
		return
	p.receive_rime_shell(body_of(caster), amount, armor_pct, shatters)

## Frozen Aegis rune: add a shield (up to `cap`) on another player's character.
func aegis_ally(target: Node, caster: Node, amount: int, cap: int, armor_pct: float) -> void:
	var member := member_of(target)
	if member != 0 and amount > 0:
		_send_to_member(member, "_sup_aegis", [token, member_of(caster), amount, cap, armor_pct])

@rpc("any_peer", "call_remote", "reliable")
func _sup_aegis(t: int, caster: int, amount: int, cap: int, armor_pct: float) -> void:
	var p := _local_player()
	if t != token or p == null or not p.is_alive():
		return
	p.receive_frozen_aegis(body_of(caster), amount, cap, armor_pct)

## Snow Ward: put its shield on another player's character.
func ward_ally(target: Node, caster: Node, amount: int, armor_pct: float) -> void:
	var member := member_of(target)
	if member != 0 and amount > 0:
		_send_to_member(member, "_sup_ward", [token, member_of(caster), amount, armor_pct])

@rpc("any_peer", "call_remote", "reliable")
func _sup_ward(t: int, caster: int, amount: int, armor_pct: float) -> void:
	var p := _local_player()
	if t != token or p == null or not p.is_alive():
		return
	p.receive_snow_ward(body_of(caster), amount, armor_pct)

## Put a Rime Shell on an enemy (host-side). Breaking it shatters for the caster.
func shell_enemy(enemy: Node, caster: Node, amount: int) -> void:
	if is_client() and _connected():
		rpc_id(1, "_sup_enemy_shell", token, member_of(caster), enemy_id(enemy), amount)
		return
	_do_enemy_shell(enemy, caster, amount)

@rpc("any_peer", "call_remote", "reliable")
func _sup_enemy_shell(t: int, caster: int, id: String, amount: int) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	if e:
		_do_enemy_shell(e, body_of(caster), amount)

func _do_enemy_shell(e: Node, caster: Node, amount: int) -> void:
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return
	var st := e.get_node_or_null("Status")
	if st == null:
		return
	SHIELDS.put_rime_shell(st, caster, amount, true, 0.0, _enemy_shatter(e, caster))

## What an enemy's Rime Shell does when its shield is used up: it shatters for its caster.
func _enemy_shatter(e: Node, caster: Node) -> Callable:
	var at := (e as Node3D).global_position
	return func():
		request_shatter(caster, (e as Node3D).global_position if is_instance_valid(e) else at)

func _arm_enemy_shell(e: Node, st: Node, caster: Node, amount: int) -> void:
	st.set_absorb("rime_shell_foe", amount, _enemy_shatter(e, caster), true)

## Take the shield off an enemy's Rime Shell without shattering it (Shattering
## Wave / Slam shatter it themselves). The shell stays on the enemy.
func drop_enemy_shield(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_enemy_unshield", token, enemy_id(enemy))
		var mine := enemy.get_node_or_null("Status")
		if mine and mine.effects.has("rime_shell_foe"):
			mine.effects["rime_shell_foe"].erase("net_absorb")   # shown at once; the host confirms
		return
	SHIELDS.drop_rime_shield(enemy.get_node_or_null("Status"), true)

@rpc("any_peer", "call_remote", "reliable")
func _sup_enemy_unshield(t: int, id: String) -> void:
	var w := _world()
	if t == token and is_host() and w:
		var e := _enemy(w, id)
		if e:
			SHIELDS.drop_rime_shield(e.get_node_or_null("Status"), true)

## This machine just became the host: an enemy's mirrored Rime Shell gets its
## shield health back (shields live on the host).
func restore_enemy_shell(e: Node, amount: int) -> void:
	var st := e.get_node_or_null("Status") if e and is_instance_valid(e) else null
	if st == null or amount <= 0 or not st.effects.has("rime_shell_foe"):
		return
	var caster: Variant = st.effects["rime_shell_foe"].get("source")
	_arm_enemy_shell(e, st, caster if is_instance_valid(caster) else null, amount)

## A Rime Shell (or Frozen enemy) shatters at `pos`: the CASTER's machine deals
## the damage (their stats, their threat).
func request_shatter(caster: Node, pos: Vector3) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	if caster.is_in_group("player"):
		caster.shatter_at(pos)
	else:
		_send_to_member(member_of(caster), "_sup_shatter", [token, pos])

@rpc("any_peer", "call_remote", "reliable")
func _sup_shatter(t: int, pos: Vector3) -> void:
	var p := _local_player()
	if t == token and p and p.is_alive():
		p.shatter_at(pos)

## Remove an effect (and its shield, WITHOUT breaking it) from anyone: an enemy
## (on the host), another player (on their machine) or me.
func remove_status(target: Node, effect_id: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.is_in_group("enemies"):
		if is_client() and _connected():
			rpc_id(1, "_sup_enemy_rm", token, enemy_id(target), effect_id)
		else:
			_strip(target, effect_id)
	elif target.is_in_group("player"):
		_strip(target, effect_id)
	else:
		_send_to_member(member_of(target), "_sup_rm", [token, effect_id])

func _strip(who: Node, effect_id: String) -> void:
	var st := who.get_node_or_null("Status")
	if st:
		st.break_absorb(effect_id, true)
		st.remove(effect_id)

@rpc("any_peer", "call_remote", "reliable")
func _sup_enemy_rm(t: int, id: String, effect_id: String) -> void:
	var w := _world()
	if t == token and is_host() and w:
		var e := _enemy(w, id)
		if e:
			_strip(e, effect_id)

@rpc("any_peer", "call_remote", "reliable")
func _sup_rm(t: int, effect_id: String) -> void:
	var p := _local_player()
	if t == token and p:
		_strip(p, effect_id)

## Taunt (threat lives on the host).
func taunt(enemy: Node, source: Node, duration: float) -> void:
	if is_client() and _connected():
		rpc_id(1, "_sup_taunt", token, member_of(source), enemy_id(enemy), duration)
	elif enemy.has_method("taunt"):
		enemy.taunt(source, duration)

@rpc("any_peer", "call_remote", "reliable")
func _sup_taunt(t: int, member: int, id: String, duration: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var src := body_of(member)
	if e and src and e.has_method("taunt"):
		e.taunt(src, duration)

## Leaf Cloak: `source`'s threat on `enemy` drops to nothing (threat lives on the host).
func drop_threat(enemy: Node, source: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_drop_threat", token, member_of(source), enemy_id(enemy))
	elif enemy.has_method("drop_threat"):
		enemy.drop_threat(source)

@rpc("any_peer", "call_remote", "reliable")
func _sup_drop_threat(t: int, member: int, id: String) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var src := body_of(member)
	if e and src and e.has_method("drop_threat"):
		e.drop_threat(src)

## Play Dead (Martial Utility): `enemy` forgets `source` for `time` seconds (0: it
## remembers them again). The host owns enemies.
func forget(enemy: Node, source: Node, time: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_forget", token, member_of(source), enemy_id(enemy), time)
	elif enemy.has_method("forget"):
		enemy.forget(source, time)

@rpc("any_peer", "call_remote", "reliable")
func _sup_forget(t: int, member: int, id: String, time: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var src := body_of(member)
	if e and src and e.has_method("forget"):
		e.forget(src, time)

## Reel In: drag `enemy` to `to` and make it attack `source` for `taunt_time`
## seconds (the host owns enemies). Something that can't be dragged (a training
## dummy) is only taunted.
func pull(enemy: Node, source: Node, to: Vector3, taunt_time: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_pull", token, member_of(source), enemy_id(enemy), to, taunt_time)
	elif enemy.has_method("pull_to"):
		enemy.pull_to(source, to, taunt_time, Balance.REEL_IN_DRAG_TIME)
	elif enemy.has_method("taunt"):
		enemy.taunt(source, taunt_time)

@rpc("any_peer", "call_remote", "reliable")
func _sup_pull(t: int, member: int, id: String, to: Vector3, taunt_time: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var src := body_of(member)
	if e == null or src == null:
		return
	if e.has_method("pull_to"):
		e.pull_to(src, to, taunt_time, Balance.REEL_IN_DRAG_TIME)
	elif e.has_method("taunt"):
		e.taunt(src, taunt_time)

## Collapse: slide `enemy` to `to` (the host owns enemies). Who it attacks does
## not change. Something that can't be dragged (a boss, a training dummy) stays put.
func drag(enemy: Node, to: Vector3, drag_time: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_drag", token, enemy_id(enemy), to, drag_time)
	elif enemy.has_method("drag_to"):
		enemy.drag_to(to, drag_time)

@rpc("any_peer", "call_remote", "reliable")
func _sup_drag(t: int, id: String, to: Vector3, drag_time: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	if e and e.has_method("drag_to"):
		e.drag_to(to, clampf(drag_time, 0.01, 1.0))

## Decoy: stand a Reflection of `whose` at `at` for `time` seconds; enemies
## within `radius` metres of it are made to attack it. Enemies live on the host,
## so a party member asks the host for the real one and shows a picture of their
## own. Everyone else gets a picture ("decoy" fx).
func decoy(whose: Node3D, at: Vector3, yaw: float, radius: float, time: float) -> void:
	var scene := get_tree().current_scene
	if is_client() and _connected():
		rpc_id(1, "_sup_decoy", token, member_of(whose), at, yaw, radius, time)
		DECOY.spawn(scene, whose, at, yaw, time)
	else:
		DECOY.spawn(scene, whose, at, yaw, time, radius)
	send_fx("decoy", at, null, "", {"yaw": yaw, "time": time})

@rpc("any_peer", "call_remote", "reliable")
func _sup_decoy(t: int, member: int, at: Vector3, yaw: float, radius: float, time: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var src := body_of(member)
	if src:
		DECOY.spawn(w, src, at, yaw, clampf(time, 0.1, 10.0), clampf(radius, 0.0, 20.0))

## Client: threat from healing goes to the host's enemies.
func report_heal_threat(healer: Node, target: Node, amount: float) -> void:
	if is_client() and _connected():
		rpc_id(1, "_sup_heal_threat", token, member_of(healer), member_of(target), amount)

@rpc("any_peer", "call_remote", "reliable")
func _sup_heal_threat(t: int, healer: int, target: int, amount: float) -> void:
	if t != token or not is_host():
		return
	var h := body_of(healer)
	var tg := body_of(target)
	if h == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_fighting") and (e.is_fighting(h) or (tg and e.is_fighting(tg))):
			e.add_threat(h, amount)

## My Rime Shell / Thawing state for the others (they can't see my
## status effects otherwise): lets their Rime Shell / Shattering Wave target me right.
## `shell_by` = the member who cast that Rime Shell (only its caster's
## Shattering Wave shatters it).
## `cracks` = how cracked that Rime Shell is (0-2: RimeShellFx), so the others see it too.
func send_support_state(has_shell: bool, lockouts: Dictionary, shell_by: int = 0, cracks: int = 0) -> void:
	if with_others() and _connected() and _world() != null:
		rpc("_sup_state", token, my_id(), has_shell, lockouts, shell_by, cracks)

@rpc("any_peer", "call_remote", "reliable")
func _sup_state(t: int, member: int, has_shell: bool, lockouts: Dictionary, shell_by: int = 0, cracks: int = 0) -> void:
	if t != token or member == my_id():
		return
	var p := body_of(member)
	if p:
		p.set("has_rime_shell", has_shell)
		p.set("rime_shell_by", shell_by if has_shell else 0)
		RimeShellFx.show_on(p, has_shell, cracks)
		var now := _now()
		var until := {}
		for k in lockouts:
			until[str(k)] = now + float(lockouts[k])
		p.set("lockouts", until)

## A party-wide buff from something I did (e.g. a rune): every other member
## applies it to their own character. `res` must be a saved StatusEffectData.
func send_party_status(res: Resource) -> void:
	if res == null or res.resource_path == "" or res.resource_path.contains("::"):
		return
	if not with_others() or not _connected() or _world() == null:
		return
	rpc("_party_status", token, my_id(), res.resource_path)

@rpc("any_peer", "call_remote", "reliable")
func _party_status(t: int, member: int, path: String) -> void:
	if t != token or member == my_id() or not path.begins_with("res://data/"):
		return
	var p := _local_player()
	if p == null or not p.is_alive():
		return
	var eff: Resource = load(path) if ResourceLoader.exists(path) else null
	var st := p.get_node_or_null("Status")
	if eff and st:
		st.apply(eff, body_of(member))

## Details meter: my hits / heals since the last send, for everyone's meter.
## Rows: [kind (0 damage / 1 heal), spell id, amount, crit, overheal].
func send_meter(events: Array) -> void:
	if events.is_empty() or not with_others() or not _connected() or _world() == null:
		return
	rpc("_meter", token, my_id(), events)

## Host: meter rows for `member` that only the host saw (their DoT ticks).
func send_meter_for(member: int, events: Array) -> void:
	if events.is_empty() or not is_host() or not with_others() or not _connected() or _world() == null:
		return
	rpc("_meter_fwd", token, member, events)

@rpc("authority", "call_remote", "reliable")
func _meter_fwd(t: int, member: int, events: Array) -> void:
	if t != token:
		return
	var d := get_node_or_null("/root/Details")
	if d and d.has_method("add_forwarded"):
		d.add_forwarded(member, events)

@rpc("any_peer", "call_remote", "reliable")
func _meter(t: int, member: int, events: Array) -> void:
	if t != token or member == my_id():
		return
	var d := get_node_or_null("/root/Details")
	if d and d.has_method("add_remote"):
		d.add_remote(member, events)

## Visual effects of my actions for the others (projectiles, Blizzard, melee
## swings, Frost Nova / Blink / shout rings).
func send_fx(kind: String, at: Vector3, target: Node = null, id: String = "", extra: Dictionary = {}) -> void:
	if not with_others() or not _connected() or _world() == null:
		return
	rpc("_fx", token, my_id(), kind, at, enemy_id(target) if target else "", id, extra)

@rpc("any_peer", "call_remote", "reliable")
func _fx(t: int, member: int, kind: String, at: Vector3, target_id: String, id: String, extra: Dictionary) -> void:
	if t != token or member == my_id():
		return
	var w := _world()
	var src := body_of(member) if w else null
	if src == null:
		return
	var tgt := _enemy(w, target_id) as Node3D
	match kind:
		"slash":
			if src.has_method("play_slash"):
				src.play_slash(float(extra.get("yaw", src.rotation.y)))
		"ring":
			if src.has_method("play_ring"):
				src.play_ring(float(extra.get("r", 1.0)), extra.get("c", Color.WHITE), at)
		"claws":
			# A Shadow spell landing: hands claw up out of the ground there (only a picture).
			BREACH_FX.burst(w, at, float(extra.get("r", 0.7)), int(extra.get("n", 4)), float(extra.get("h", 1.0)))
		"bolt":
			if tgt:
				FROST_BOLT.spawn(w, at, tgt, src, false, id, 0)
		"arrow":
			if tgt:
				ARROW.spawn(w, at, tgt, src, 0, id)
		"blizzard":
			var b := Node3D.new()
			b.set_script(BLIZZARD)
			b.source = src
			b.damage = 0
			b.radius = float(extra.get("r", b.radius))   # the caster's real size (Endless Winter)
			w.add_child(b)
			b.global_position = at
		"firewall":
			var fw := Node3D.new()
			fw.set_script(FIRE_WALL)
			fw.damage = 0.0   # visual only: the caster's machine deals the damage
			fw.length = float(extra.get("len", fw.length))
			fw.depth = float(extra.get("depth", fw.depth))
			fw.duration = float(extra.get("time", fw.duration))
			w.add_child(fw)
			fw.global_position = at
			fw.rotation.y = float(extra.get("yaw", 0.0))
		"cinderrain":
			var rain := Node3D.new()
			rain.set_script(CINDER_RAIN)
			rain.damage = 0.0   # visual only: the archer's machine deals the damage
			rain.radius = float(extra.get("r", rain.radius))
			rain.duration = float(extra.get("time", rain.duration))
			w.add_child(rain)
			rain.global_position = at
		"phoenix":
			# A party member's phoenix: the bird follows their character here; its
			# heals come from their machine (casts = 0: it heals nothing here).
			PHOENIX.spawn(w, src, 0, Balance.PHOENIX_INTERVAL, float(extra.get("time", 16.5)))
		"sleetwave":
			# A party member's Sleetwave: only the picture (no source = no damage here).
			var yaw := float(extra.get("yaw", 0.0))
			SLEET_WAVE.spawn(w, at, Vector3(-sin(yaw), 0.0, -cos(yaw)), null, 0.0,
				float(extra.get("len", 12.0)), float(extra.get("w", Balance.SLEETWAVE_WIDTH)), Balance.SLEETWAVE_SPEED)
		"balllightning":
			# A party member's Ball Lightning: only the picture (no source = no
			# damage and no Energy here). It drifts and zaps the same enemies.
			BALL_LIGHTNING.spawn(w, at, extra.get("dir", Vector3.FORWARD), null, 0.0, float(extra.get("r", 5.0)),
				float(extra.get("time", Balance.BALL_LIGHTNING_TIME)), float(extra.get("tick", Balance.BALL_LIGHTNING_TICK)),
				float(extra.get("speed", Balance.BALL_LIGHTNING_SPEED)))
		"thunderhead":
			# A party member's Thunderhead: only the cloud (no source = no damage here).
			THUNDERHEAD.spawn(w, at, float(extra.get("r", 5.0)), float(extra.get("time", Balance.THUNDERHEAD_TIME)),
				float(extra.get("tick", Balance.THUNDERHEAD_TICK)), null, 0.0)
		"icepatch":
			# A party member's Icy Retreat: only the ice (no callback = it Chills nothing here).
			ICE_PATCH.spawn(w, at, float(extra.get("r", 4.0)), float(extra.get("time", Balance.ICY_RETREAT_TIME)),
				Balance.ICY_RETREAT_TICK)
		"livewire":
			# A party member's Live Wire: the line between them and their target. It
			# ends here by itself (time, range, a dead target); one per member.
			if tgt:
				LIVE_WIRE.spawn(w, src, tgt, float(extra.get("time", 10.0)), str(member), Balance.LIVE_WIRE_RANGE)
		"lash":
			# A party member's Whiplash: the line from them to their target.
			if tgt:
				LASH.spawn(w, at, tgt.global_position + Vector3(0, 0.3, 0), extra.get("c", Color.WHITE))
		"crucible":
			# A party member's Crucible (placed or moved): only a picture here. It
			# boosts its owner's burns alone (Crucible.covers asks for "me"). One per member.
			CRUCIBLE.spawn(w, at, float(extra.get("r", 5.0)), float(extra.get("time", 10.0)), str(member))
		"arcanemark":
			# A party member's Mirror Sigil, Collapse or Afterimage: only a picture
			# here (their machine deals the hits). time 0 = it is gone (used up).
			var mark := str(extra.get("kind", "sigil"))
			if float(extra.get("time", 0.0)) <= 0.0:
				ARCANE_MARK.clear(w.get_tree(), mark, str(member))
			else:
				var placed := ARCANE_MARK.spawn(w, at, float(extra.get("r", 1.5)), float(extra.get("time", 4.0)), mark, str(member))
				if bool(extra.get("follow", false)):
					placed.set("follow", src)   # Rune of the Carried Sigil: it moves with them
		"reflections":
			# A party member's Reflections (Arcane tank): how many stand around them now.
			REFLECTIONS.show_on(src, int(extra.get("n", 0)))
		"ghosts":
			# A party member's Encore (Arcane melee): the ghosts of their Traces run
			# through its target. A picture; the damage is theirs.
			var through: Variant = extra.get("to")
			if through is Vector3:
				TRACE_GHOST.run(w, src, at, through, int(extra.get("n", 0)))
		"hymn":
			# A party member's Hymn (Holy healer): the ring of glyphs around them. A picture.
			HYMN_RING.show_on(src, str(extra.get("h", "")))
		"censer":
			# A party member's censer (Holy tank): how bright it is, whether it is out,
			# and Raise the Censer. A picture; the rules run on their machine.
			CENSER.show_on(src, int(extra.get("n", 0)), bool(extra.get("on", false)))
			if extra.has("up"):
				CENSER.raise(src, at, float(extra.get("h", 4.0)), float(extra.get("up", 0.0)), float(extra.get("r", 10.0)))
		"censer_flash":
			CENSER.flash(src)
		"wheel":
			# A party member's Wheel (Martial warrior): their weapons, the held one and its
			# Cracks. A picture; the rules run on their machine.
			WEAPON_WHEEL.show_on(src, extra.get("w", []), int(extra.get("h", 0)), int(extra.get("c", 0)))
		"wheel_burst":
			WEAPON_WHEEL.burst(src, str(extra.get("w", "")))
		"brawler":
			# A party member's Chain (Martial tank): the orbs on their back and their
			# Fighting Style. A picture; the rules run on their machine.
			BRAWLER_ORBS.show_on(src, extra.get("i", []), bool(extra.get("b", false)), bool(extra.get("o", false)))
		"brawler_burst":
			BRAWLER_ORBS.burst(src, extra.get("i", []), bool(extra.get("g", false)))
		"rogue":
			# A party member's Flow ring (Martial DPS: the Rogue) and Play Dead. A picture;
			# the rules run on their machine.
			ROGUE_FX.show_flow(src, int(extra.get("f", 0)), Balance.FLOW_MAX, bool(extra.get("k", false)))
			ROGUE_FX.play_dead(src, bool(extra.get("dead", false)))
		"sharpshooter":
			# A party member's quiver (Martial archer: Sharpshooter): their Streak, gold while
			# they hold a charged shot. A picture; the rules run on their machine.
			SHARP_FX.show_streak(src, int(extra.get("s", 0)), Balance.STREAK_MAX, bool(extra.get("g", false)))
		"rogue_daggers":
			# A party member's daggers stuck in an enemy (theirs only; one set per member).
			if tgt:
				ROGUE_FX.set_daggers(tgt, str(member), int(extra.get("n", 0)))
		"rogue_throw":
			if tgt:
				ROGUE_FX.throw(w, at, tgt.global_position + Vector3(0, 1.0, 0))
		"prisms":
			# A party member's prisms (Holy healer #2): where they stand and how full,
			# shown faint. A picture; only their beams charge them.
			var pkeys := []
			for row in extra.get("p", []):
				if row is Array and row.size() >= 5:
					var pkey := "%d:%s" % [member, str(row[0])]
					pkeys.append(pkey)
					PRISM.place(w, pkey, Vector3(float(row[1]), float(row[2]), float(row[3])), float(row[4]), false, false,
						row.size() > 5 and str(row[5]) == "gold")
			PRISM.keep_only(w.get_tree(), "%d:" % member, pkeys)
		"prism_burst":
			PRISM.shatter(w.get_tree(), "%d:%s" % [member, str(extra.get("k", ""))])
		"mulch":
			# A party member's mulch (Nature caster): where each patch lies, shown faint.
			# A picture; only their creatures use it.
			var mkeys := []
			for row in extra.get("p", []):
				if row is Array and row.size() >= 4:
					var mkey := "%d:%s" % [member, str(row[0])]
					mkeys.append(mkey)
					MULCH.place(w, mkey, Vector3(float(row[1]), float(row[2]), float(row[3])), false)
			MULCH.keep_only(w.get_tree(), "%d:" % member, mkeys)
		"creature":
			# ... and their creatures (one strike each): faint, the hit comes from their machine.
			var cto: Variant = extra.get("to")
			if cto is Vector3:
				NATURE_CREATURE.spawn(w, str(extra.get("k", "tiger")), at, cto, true)
		"beam":
			var to: Variant = extra.get("to")
			if to is Vector3:
				LIGHT_BEAM.flash(w, at, to, Color(0.95, 0.97, 1.0))
		"motes":
			# ... and their motes of light: faint here, only they can pick them up.
			var mkey := "%d:%s" % [member, str(extra.get("k", ""))]
			if extra.has("t"):
				LIGHT_MOTE.spawn(w, at, mkey, false, float(extra.get("t", 10.0)))
			else:
				LIGHT_MOTE.take(w.get_tree(), mkey, src)
		"hymn_boom":
			# ... and their boom: a column of light. The healing is theirs.
			HYMN_RING.boom(w, at, HYMN_RING.COLORS.get(str(extra.get("h", "")), Color.WHITE))
		"strings":
			# A party member's Strings (Shadow healer): the demon behind them and the
			# threads over whoever they hold. A picture; the healing is theirs.
			# m = member id -> how many Strings, e = enemy id -> 1. Both empty: all gone.
			var held: Array = []
			var on_members: Variant = extra.get("m")
			if on_members is Dictionary:
				for k in on_members:
					var ally := body_of(int(k))
					if ally:
						held.append([ally, int(on_members[k]), false])
			var on_enemies: Variant = extra.get("e")
			if on_enemies is Dictionary:
				for k in on_enemies:
					var foe := _enemy(w, str(k)) as Node3D
					if foe:
						held.append([foe, 1, true])
			PUPPETEER.hold(w, src, held)
		"strungup":
			# String Up: the enemy hangs off the ground for a while.
			if tgt:
				PUPPETEER.string_up(w, tgt, float(extra.get("time", 3.0)))
		"tangle":
			# Tangle: threads across the floor there.
			PUPPETEER.tangle(w, at, float(extra.get("r", 5.0)), float(extra.get("time", 4.0)))
		"hounds":
			# A party member's Hounds (Shadow melee): two demon dogs that follow their
			# character here and bite what theirs bite. A picture; the damage is
			# theirs. time 0 = the Hounds are gone.
			HOUND.show_for(w, src, tgt, float(extra.get("time", 0.0)), bool(extra.get("lunge", false)),
				int(extra.get("count", 2)))   # (three while Slipped Leash's third is out)
		"decoy":
			# A party member's Decoy: a picture here. Where enemies are simulated (the
			# host) the real one comes with their request instead (_sup_decoy).
			if not is_host():
				DECOY.spawn(w, src, at, float(extra.get("yaw", 0.0)), float(extra.get("time", Balance.DECOY_TIME)))

## Host: something an enemy did that the party should SEE (arrows, firebolts,
## cast wind-ups, being interrupted). Clients play it as a visual only - the
## damage itself still comes from the host (send_enemy_hit).
## kind: "arrow" / "bolt" (extra.at = muzzle), "cast" (extra.d = cast time), "interrupted".
func enemy_fx(enemy: Node, kind: String, target: Node = null, extra: Dictionary = {}) -> void:
	if not is_host() or not with_others() or not _connected() or _world() == null:
		return
	rpc("_efx", token, enemy_id(enemy), kind, member_of(target) if target else 0, extra)

@rpc("authority", "call_remote", "reliable")
func _efx(t: int, id: String, kind: String, target_member: int, extra: Dictionary) -> void:
	if t != token or not is_client():
		return
	var w := _world()
	var e := _enemy(w, id) if w else null
	if e == null or not e.has_method("net_fx"):
		return
	e.net_fx(kind, body_of(target_member) if target_member != 0 else null, extra)

## Interrupt an enemy's cast (Counterspell, Kick, Pummel). Casting lives on
## the host, so a party member's interrupt is sent there.
func interrupt(enemy: Node, source: Node, lockout: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_interrupt", token, member_of(source), enemy_id(enemy), lockout)
	elif enemy.has_method("interrupt"):
		enemy.interrupt(source, lockout)

@rpc("any_peer", "call_remote", "reliable")
func _sup_interrupt(t: int, member: int, id: String, lockout: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	if e and e.has_method("interrupt"):
		e.interrupt(body_of(member), lockout)

## Remove `source`'s copy of a status effect from an enemy (Stoke eating its
## Burning). Enemy effects live on the host, so a party member's is sent there too.
func remove_effect(enemy: Node, source: Node, effect_id: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_remove_effect", token, member_of(source), enemy_id(enemy), effect_id)
	var st := enemy.get_node_or_null("Status")
	if st:
		st.remove_from(effect_id, source)

@rpc("any_peer", "call_remote", "reliable")
func _sup_remove_effect(t: int, member: int, id: String, effect_id: String) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var st: Node = e.get_node_or_null("Status") if e else null
	if st:
		st.remove_from(effect_id, body_of(member))

## Set the stacks of `source`'s copy of a status effect on an enemy without
## touching its timer. Lives on the host like every enemy effect.
func set_effect_stacks(enemy: Node, source: Node, effect_id: String, stacks: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if is_client() and _connected():
		rpc_id(1, "_sup_effect_stacks", token, member_of(source), enemy_id(enemy), effect_id, stacks)
	var st := enemy.get_node_or_null("Status")
	if st:
		st.set_stacks_from(effect_id, source, stacks)

@rpc("any_peer", "call_remote", "reliable")
func _sup_effect_stacks(t: int, member: int, id: String, effect_id: String, stacks: int) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var st: Node = e.get_node_or_null("Status") if e else null
	if st:
		st.set_stacks_from(effect_id, body_of(member), stacks)

## Make `source`'s copy of a status effect on an enemy run out `seconds` from
## now (Fresh Tinder feeding an Immolate). Lives on the host like every enemy
## effect; a party member's own copy changes at once and keeps its clock until
## the host has caught up.
func set_effect_remaining(enemy: Node, source: Node, effect_id: String, seconds: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var remote := is_client() and _connected()
	if remote:
		rpc_id(1, "_sup_effect_remaining", token, member_of(source), enemy_id(enemy), effect_id, seconds)
	var st := enemy.get_node_or_null("Status")
	if st:
		st.set_remaining_from(effect_id, source, seconds, EFFECT_CLOCK_HOLD if remote else 0.0)

## Seconds a party member's machine trusts its own clock after changing an effect's time left.
const EFFECT_CLOCK_HOLD := 0.6

@rpc("any_peer", "call_remote", "reliable")
func _sup_effect_remaining(t: int, member: int, id: String, effect_id: String, seconds: float) -> void:
	var w := _world()
	if t != token or not is_host() or w == null:
		return
	var e := _enemy(w, id)
	var st: Node = e.get_node_or_null("Status") if e else null
	if st:
		st.set_remaining_from(effect_id, body_of(member), seconds)

## Host: dungeon events (boss woke up, floor cleared) -> scene.net_event().
func dungeon_event(ev: String, data: Dictionary = {}) -> void:
	if is_host() and _connected() and _world() != null:
		rpc("_devent", token, ev, data)

@rpc("authority", "call_remote", "reliable")
func _devent(t: int, ev: String, data: Dictionary) -> void:
	if t != token:
		return
	var w := _world()
	if w and w.has_method("net_event"):
		w.net_event(ev, data)

# --- Host migration -----------------------------------------------------------------------

func _begin_migration() -> void:
	var old := host_member
	var old_name := member_name(old)
	migrating = true
	migration_state.emit(true)
	members.erase(old)
	order.erase(old)
	_remove_puppet(old)
	_mig_candidates = order.duplicate()
	if not run.is_empty():
		get_tree().paused = true
	_show_overlay("%s (party leader) left.\nMoving the game to a new host…" % old_name)
	_say("%s (party leader) left - picking a new leader." % old_name)
	_mig_next()

func _mig_next() -> void:
	_close_peer()
	if _mig_candidates.is_empty() or int(_mig_candidates[0]) == my_id():
		_become_host()
		return
	var c := int(_mig_candidates[0])
	var addr := str(members.get(c, {}).get("addr", ""))
	var peer: MultiplayerPeer = _online().make_client_peer(c, addr)
	if peer == null:
		_mig_candidates.pop_front()
		_mig_next()
		return
	multiplayer.multiplayer_peer = peer
	_role = Role.CLIENT
	host_member = c
	_connect_addr = addr
	_joining = true
	_join_deadline = _now() + CONNECT_TIMEOUT
	_show_overlay("Reconnecting to %s (new party leader)…" % member_name(c))

func _become_host() -> void:
	var peer: MultiplayerPeer = _online().make_host_peer()
	if peer == null:
		_end_migration()
		_online().toast.emit("Couldn't take over as the party leader.")
		if not run.is_empty():
			leave_run()
		else:
			_online().leave_party(true)
		return
	multiplayer.multiplayer_peer = peer
	_role = Role.HOST
	host_member = my_id()
	order.erase(my_id())
	order.push_front(my_id())
	_peer_member = {1: my_id()}
	_mig_expected = order.slice(1)
	_mig_until = _now() + MIGRATE_WAIT
	_take_over_world()
	_online().on_became_host()
	if _mig_expected.is_empty():
		_finish_host_migration()
	else:
		_show_overlay("You're the new party leader.\nWaiting for the others to reconnect…")

## The new host's enemies keep fighting whoever they were fighting.
func _take_over_world() -> void:
	if _world() == null:
		return
	var bodies := party_bodies()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		if e.has_method("net_take_over"):
			e.net_take_over()   # mirrored slows / DoTs start running here now
		var st := int(e.state)
		if st != 1 and st != 2:   # only CHASE / ATTACK
			continue
		var who: Node3D = body_of(int(e.get("_net_threat")))
		if who == null or not who.is_alive():
			who = _nearest_alive(e, bodies)
		e.threat.clear()
		if who:
			e.add_threat(who, 5.0)

func _nearest_alive(from: Node3D, bodies: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in bodies:
		if b.is_alive():
			var d := from.global_position.distance_squared_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	return best

func _finish_host_migration() -> void:
	if _connected():
		rpc("_resume")   # first, so the roster below isn't ignored as "still migrating"
	_end_migration()
	_send_meta()
	_say("You are now the party leader.")
	members_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _resume() -> void:
	_end_migration()
	_say("%s is now the party leader." % leader_name())
	members_changed.emit()

func _end_migration() -> void:
	migrating = false
	_joining = false
	_mig_candidates.clear()
	if get_tree().paused:
		get_tree().paused = false
	_hide_overlay()
	migration_state.emit(false)
	_online().sync_owner()

# --- Migration overlay ---------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 95
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 26)
	_overlay_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	_overlay_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay_label.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(_overlay_label)
	_overlay.visible = false

func _show_overlay(text: String) -> void:
	_overlay_label.text = text
	_overlay.visible = true

func _hide_overlay() -> void:
	if _overlay:
		_overlay.visible = false
