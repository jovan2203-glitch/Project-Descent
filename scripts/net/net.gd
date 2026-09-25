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
		rpc_id(peer, "_load", run["path"], run["depth"], run["seed"], token)
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

# --- Chat ------------------------------------------------------------------------------

func _on_local_chat(sender: String, text: String) -> void:
	if online and sender == "You" and _connected():
		rpc("_chat", str(_online().my_name), text)

@rpc("any_peer", "call_remote", "reliable")
func _chat(sender: String, text: String) -> void:
	chat_received.emit(sender, text)

# --- Game flow (host decides, everyone loads) -------------------------------------------

func start_game(path: String, start_floor: int = 1) -> void:
	if not is_host():
		return
	queue_path = ""
	_online().on_run_started()
	run = {"path": path, "depth": maxi(start_floor, 1), "seed": randi()}
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
	if _connected():
		rpc("_load", run["path"], run["depth"], run["seed"], token)
	_load(run["path"], run["depth"], run["seed"], token)

@rpc("authority", "call_remote", "reliable")
func _load(path: String, depth: int, seed_value: int, t: int) -> void:
	token = t
	run = {"path": path, "depth": depth, "seed": seed_value}
	_free_puppets()
	_wipe_t = 0.0
	get_node("/root/GameManager").net_load(path, depth, seed_value)

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
		rpc("_pstate", token, my_id(), p.global_position, p.rotation.y, str(p.get("current_state")),
			int(p.get("health")), int(p.get("max_health")))
	if is_host():
		_enemy_t -= delta
		if _enemy_t <= 0.0:
			_enemy_t = 1.0 / ENEMY_RATE
			rpc("_esnap", token, _enemy_snapshot())
		_check_wipe(delta)

func _check_wipe(delta: float) -> void:
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
func _pstate(t: int, member: int, pos: Vector3, yaw: float, anim: String, hp: int, mhp: int) -> void:
	if t != token or member == my_id():
		return
	var w := _world()
	if w == null:
		return
	var p := _puppet(member, w)
	if p:
		p.apply_state(pos, yaw, anim, hp, mhp)

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

# Enemy snapshot rows: [id, pos, yaw, health, max_health, state, moving, top-threat member]
func _enemy_snapshot() -> Array:
	var rows: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var moving: bool = Vector2(e.velocity.x, e.velocity.z).length() > 0.1
		rows.append([enemy_id(e), e.global_position, e.rotation.y, int(e.health), int(e.max_health),
			int(e.state), moving, member_of(e.top_threat()), _status_rows(e)])
	return rows

## Active status effects on an enemy: [[effect .tres path, stacks, seconds left, source member]]
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
			member_of(src) if is_instance_valid(src) else 0])
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
func enemy_died(e: Node) -> void:
	if not is_host() or not _connected() or _world() == null:
		return
	rpc("_edied", token, enemy_id(e))

@rpc("authority", "call_remote", "reliable")
func _edied(t: int, id: String) -> void:
	if t != token:
		return
	var w := _world()
	var e := _enemy(w, id) if w else null
	if e and e.has_method("net_die"):
		e.net_die()

## Client: my hit on an enemy (already rolled here: crit/armor/resist).
func report_enemy_damage(e: Node, amount: int, ability_id: String, threat_mult: float, effects: Array) -> void:
	if not is_client() or not _connected():
		return
	var paths: Array = []
	for eff in effects:
		if eff is Resource and eff.resource_path != "":
			paths.append(eff.resource_path)
	rpc_id(1, "_cdmg", token, my_id(), enemy_id(e), amount, ability_id, threat_mult, paths)

@rpc("any_peer", "call_remote", "reliable")
func _cdmg(t: int, member: int, id: String, amount: int, _ability_id: String, threat_mult: float, paths: Array) -> void:
	if not is_host() or t != token:
		return
	var w := _world()
	var e := _enemy(w, id) if w else null
	if e == null or not e.is_alive():
		return
	var src := body_of(member)
	if amount > 0:
		e.take_damage(amount)
	if not e.is_alive():
		return
	if amount > 0:
		var st := e.get_node_or_null("Status")
		if st:
			for path in paths:
				var eff := load(str(path))
				if eff:
					st.apply(eff, src)
	if src:
		e.add_threat(src, maxf(float(amount), 1.0) * threat_mult)

## Host: an enemy hit another player's character -> that player takes the hit.
func send_enemy_hit(enemy: Node, target: Node, base: int, tags: PackedStringArray, damage_type: String) -> void:
	if not is_host() or not _connected():
		return
	var member := member_of(target)
	for peer in _peer_member:
		if int(_peer_member[peer]) == member and int(peer) != 1:
			rpc_id(int(peer), "_ehit", token, enemy_id(enemy), base, tags, damage_type)
			return

@rpc("authority", "call_remote", "reliable")
func _ehit(t: int, id: String, base: int, tags: PackedStringArray, damage_type: String) -> void:
	if t != token:
		return
	var w := _world()
	var p := _local_player()
	if w == null or p == null or not p.is_alive():
		return
	var info := DamageInfo.make(_enemy(w, id), p, base, "enemy_melee")
	info.tags = tags
	if damage_type != "":
		info.damage_type = damage_type
	get_node("/root/CombatSystem").deal(info)

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
		"ray":
			if tgt and src.has_method("play_ray"):
				src.play_ray(tgt, float(extra.get("d", 3.0)))
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
			w.add_child(b)
			b.global_position = at

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
