extends Node

# Online (autoload "Online"): the platform layer.
#
#   Steam (GodotSteam addon)
#     - Your username is your Steam name; your friends list is your Steam friends.
#     - A party is a Steam lobby (max 5). Inviting a friend creates the party.
#     - Queue: the leader marks the party's lobby as "looking for <dungeon>" and
#       searches for other queued lobbies. The smaller party moves into the
#       bigger one (ties: into the lower lobby id), so parties/solo players merge
#       until someone reaches 5, and then the run starts automatically.
#       A full party of 5 skips the queue and goes straight in.
#   LAN test mode (no GodotSteam, or Steam not running)
#     - Host a party on one PC, others join by IP. No friends list and no
#       matchmaking; "Queue" just starts with whoever is in the party.
#
# The connection between party members, the game session and host migration
# live in Net (net.gd). This script only finds/creates the party and hands Net
# a MultiplayerPeer.

signal changed                    # backend / party / queue / invites changed
signal friends_changed
signal toast(text: String)

const APP_ID := 480               # Steam's public test app (Spacewar) until the game has its own id
const GAME_KEY := "ngp_coop_v1"   # lobby tag: only ever match with this game (and this version)
const MAX_PARTY := 5
const LAN_PORT := 24570
const SEARCH_INTERVAL := 4.0

# Steam constants (literal so this script parses without GodotSteam installed).
const FRIEND_FLAG_IMMEDIATE := 4
const LOBBY_FRIENDS_ONLY := 1
const LOBBY_PUBLIC := 2
const LOBBY_EQUAL := 0
const LOBBY_DISTANCE_WORLDWIDE := 3
const PERSONA_STATES := ["Offline", "Online", "Busy", "Away", "Snooze", "Online", "Online"]

enum Backend { NONE, STEAM, LAN }

var backend: int = Backend.NONE
var steam: Object = null
var my_id := 0
var my_name := "Player"
var status_text := ""
var lobby_id := 0
var invites: Array = []           # [{"from": id, "name": String, "lobby": id}]
var queue_instance := ""          # scene path the party is queued for ("" = not queued)
var queue_started := 0.0          # Time (s) when the queue started

var _search_timer := 0.0
var _moving := false              # leaving our lobby to merge into another one
var _creating := false
var _after_create: Array[Callable] = []

func _net() -> Node:
	return get_node("/root/Net")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_steam()
	if backend == Backend.NONE:
		backend = Backend.LAN
		var r := RandomNumberGenerator.new()
		r.randomize()
		my_id = (r.randi() & 0x7fffffff) * 4294967296 + r.randi()
		var user := OS.get_environment("USERNAME")
		if user == "":
			user = OS.get_environment("USER")
		my_name = "%s-%02d" % [user if user != "" else "Player", r.randi() % 100]
	_check_command_line.call_deferred()

func _notification(what: int) -> void:
	# Closing the window: leave cleanly so the party migrates right away.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave_party(true)

# --- Steam startup -------------------------------------------------------------------

func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		status_text = "GodotSteam isn't installed, so online play is in LAN test mode."
		return
	steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	# GodotSteam 4.14+ is steamInitEx(app_id, embed_callbacks); older versions
	# had a leading retrieve_stats bool.
	var method := "steamInitEx" if steam.has_method("steamInitEx") else "steamInit"
	var first_arg := ""
	for m in steam.get_method_list():
		if str(m["name"]) == method and not (m["args"] as Array).is_empty():
			first_arg = str(m["args"][0]["name"])
			break
	var res: Variant = null
	if first_arg == "app_id":
		res = call_steam(method, [APP_ID, false])
	else:
		res = call_steam(method, [false, APP_ID, false])
	var ok := false
	if res is Dictionary:
		ok = int(res.get("status", 1)) == 0
		if not ok:
			status_text = "Steam couldn't start (%s), so online play is in LAN test mode." % str(res.get("verbal", "is Steam running?"))
	elif res is bool:
		ok = res
	if not ok:
		if status_text == "":
			status_text = "Steam isn't running, so online play is in LAN test mode."
		steam = null
		return
	backend = Backend.STEAM
	my_id = int(steam.getSteamID())
	my_name = str(steam.getPersonaName())
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		status_text = "Signed in to Steam, but SteamMultiplayerPeer is missing: install the GodotSteam MultiplayerPeer addon to play together."
	for pair in [
		["lobby_created", _on_lobby_created],
		["lobby_joined", _on_lobby_joined],
		["lobby_chat_update", _on_lobby_chat_update],
		["lobby_data_update", _on_lobby_data_update],
		["lobby_match_list", _on_lobby_match_list],
		["lobby_invite", _on_lobby_invite],
		["join_requested", _on_join_requested],
		["persona_state_change", _on_persona_change],
	]:
		if steam.has_signal(pair[0]):
			steam.connect(pair[0], pair[1])

## Calls a Steam method, trimming the argument list to what this GodotSteam
## version's method accepts (signatures changed between versions).
func call_steam(method: String, args: Array = []) -> Variant:
	return call_trimmed(steam, method, args)

static func call_trimmed(obj: Object, method: String, args: Array) -> Variant:
	if obj == null or not obj.has_method(method):
		return null
	var n := args.size()
	for m in obj.get_method_list():
		if str(m["name"]) == method:
			n = mini(n, (m["args"] as Array).size())
			break
	return obj.callv(method, args.slice(0, n))

func _check_command_line() -> void:
	# Launched from a Steam invite: "+connect_lobby <id>".
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if backend == Backend.STEAM and i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int():
		join_party(int(args[i + 1]))

func _process(delta: float) -> void:
	if steam:
		steam.run_callbacks()
	_tick_queue(delta)

# --- Status --------------------------------------------------------------------------

func is_steam() -> bool:
	return backend == Backend.STEAM

func max_party() -> int:
	return MAX_PARTY

func backend_name() -> String:
	return "Steam" if backend == Backend.STEAM else "LAN test mode"

func can_play_online() -> bool:
	return backend == Backend.LAN or ClassDB.class_exists("SteamMultiplayerPeer")

func in_party() -> bool:
	return _net().online

func is_leader() -> bool:
	return not _net().online or _net().is_host()

func party_size() -> int:
	return maxi(_net().members.size(), 1) if _net().online else 1

func _toast(text: String) -> void:
	toast.emit(text)

# --- Peers (the actual connection; Net uses these, also for host migration) -------------

func make_host_peer() -> MultiplayerPeer:
	if backend == Backend.STEAM:
		if not ClassDB.class_exists("SteamMultiplayerPeer"):
			return null
		var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		var err: Variant = call_trimmed(p, "create_host", [0])
		if err != null and int(err) != OK:
			return null
		return p
	var e := ENetMultiplayerPeer.new()
	if e.create_server(LAN_PORT, MAX_PARTY) != OK:
		return null
	return e

## host_id = the host's member id (Steam ID); address is only used in LAN mode.
func make_client_peer(host_id: int, address: String = "") -> MultiplayerPeer:
	if backend == Backend.STEAM:
		if not ClassDB.class_exists("SteamMultiplayerPeer"):
			return null
		var p: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		var err: Variant = call_trimmed(p, "create_client", [host_id, 0])
		if err != null and int(err) != OK:
			return null
		return p
	var e := ENetMultiplayerPeer.new()
	if e.create_client(address if address != "" else "127.0.0.1", LAN_PORT) != OK:
		return null
	return e

# --- Party -----------------------------------------------------------------------------

## Makes sure we're in a party (creating one if needed), then runs `then`.
func create_party(then: Callable = Callable()) -> void:
	if _net().online:
		if then.is_valid():
			then.call()
		return
	if not can_play_online():
		_toast(status_text)
		return
	if backend == Backend.STEAM:
		if then.is_valid():
			_after_create.append(then)
		if not _creating:
			_creating = true
			steam.createLobby(LOBBY_FRIENDS_ONLY, MAX_PARTY)
		return
	host_lan()
	if _net().online and then.is_valid():
		then.call()

func host_lan() -> void:
	if _net().online:
		leave_party(true)
	var peer := make_host_peer()
	if peer == null:
		_toast("Couldn't open port %d (is another copy of the game already hosting?)" % LAN_PORT)
		return
	_net().host_session(peer)
	_toast("Party created. Others can join you at your IP address.")
	changed.emit()

func join_lan(address: String) -> void:
	address = address.strip_edges()
	if address == "":
		address = "127.0.0.1"
	if _net().online:
		leave_party(true)
	var peer := make_client_peer(0, address)
	if peer == null:
		_toast("Couldn't connect to %s" % address)
		return
	_net().join_session(peer, 0, address)
	_toast("Joining %s…" % address)
	changed.emit()

func join_party(lid: int) -> void:
	if backend != Backend.STEAM or lid == 0:
		return
	if lid == lobby_id and _net().online:
		return
	if _net().online:
		leave_party(true)
	steam.joinLobby(lid)

## Leaving the party. If you were the leader, the others migrate to a new host.
func leave_party(quiet: bool = false) -> void:
	queue_instance = ""
	_moving = false
	if backend == Backend.STEAM and lobby_id != 0:
		steam.leaveLobby(lobby_id)
	lobby_id = 0
	_net().leave_session()
	if not quiet:
		_toast("You left the party.")
	changed.emit()

func invite(friend_id: int) -> void:
	if backend != Backend.STEAM:
		return
	if party_size() >= MAX_PARTY:
		_toast("Your party is full.")
		return
	create_party(func():
		steam.inviteUserToLobby(lobby_id, friend_id)
		_toast("Invited %s" % friend_name(friend_id)))

func accept_invite(index: int) -> void:
	if index < 0 or index >= invites.size():
		return
	var inv: Dictionary = invites[index]
	invites.remove_at(index)
	join_party(int(inv["lobby"]))
	changed.emit()

func decline_invite(index: int) -> void:
	if index >= 0 and index < invites.size():
		invites.remove_at(index)
		changed.emit()

## Steam has no "search by username", so adding friends goes through the overlay.
func open_add_friend() -> void:
	if backend == Backend.STEAM:
		call_steam("activateGameOverlay", ["Friends"])

# --- Friends -----------------------------------------------------------------------------

func friend_name(id: int) -> String:
	if backend == Backend.STEAM:
		return str(steam.getFriendPersonaName(id))
	return str(id)

## [{id, name, online, status, playing, in_party}] sorted: in this game, online, offline.
func get_friends() -> Array:
	var out: Array = []
	if backend != Backend.STEAM:
		return out
	var n := int(steam.getFriendCount(FRIEND_FLAG_IMMEDIATE))
	for i in n:
		var fid := int(steam.getFriendByIndex(i, FRIEND_FLAG_IMMEDIATE))
		var st := int(steam.getFriendPersonaState(fid))
		var game: Variant = steam.getFriendGamePlayed(fid)
		var playing: bool = game is Dictionary and int(game.get("id", 0)) == APP_ID
		out.append({
			"id": fid,
			"name": str(steam.getFriendPersonaName(fid)),
			"online": st != 0,
			"status": "In game" if playing else PERSONA_STATES[clampi(st, 0, PERSONA_STATES.size() - 1)],
			"playing": playing,
			"in_party": _net().members.has(fid),
		})
	out.sort_custom(func(a, b):
		var ra := 2 if a["playing"] else (1 if a["online"] else 0)
		var rb := 2 if b["playing"] else (1 if b["online"] else 0)
		if ra != rb:
			return ra > rb
		return str(a["name"]).nocasecmp_to(str(b["name"])) < 0)
	return out

# --- Queue -------------------------------------------------------------------------------

func queue_for(scene_path: String) -> void:
	if not is_leader():
		_toast("Only the party leader can queue.")
		return
	if party_size() >= MAX_PARTY:
		_toast("Full party — heading in!")
		get_node("/root/GameManager").start_game(scene_path)
		return
	if backend != Backend.STEAM:
		_toast("Matchmaking needs Steam, so you're going in with your current group.")
		get_node("/root/GameManager").start_game(scene_path)
		return
	create_party(func(): _begin_queue(scene_path))

func _begin_queue(scene_path: String) -> void:
	queue_instance = scene_path
	queue_started = _now()
	_search_timer = 0.0
	if lobby_id != 0:
		steam.setLobbyData(lobby_id, "queue", scene_path)
		steam.setLobbyType(lobby_id, LOBBY_PUBLIC)
		steam.setLobbyJoinable(lobby_id, true)
	_net().set_queue(scene_path)
	changed.emit()

func cancel_queue() -> void:
	if queue_instance == "":
		return
	queue_instance = ""
	if is_leader():
		_set_lobby_idle()
		_net().set_queue("")
	changed.emit()

## Start right now with the current party (solo if not in one).
func start_now(scene_path: String) -> void:
	if not is_leader():
		_toast("Only the party leader can start.")
		return
	cancel_queue()
	get_node("/root/GameManager").start_game(scene_path)

func queue_seconds() -> int:
	return int(_now() - queue_started)

func _set_lobby_idle() -> void:
	if backend == Backend.STEAM and lobby_id != 0:
		steam.setLobbyData(lobby_id, "queue", "")
		steam.setLobbyType(lobby_id, LOBBY_FRIENDS_ONLY)
		steam.setLobbyJoinable(lobby_id, true)

## Net: a run started (nobody random joins mid-dungeon).
func on_run_started() -> void:
	queue_instance = ""
	if backend == Backend.STEAM and lobby_id != 0 and is_leader():
		steam.setLobbyData(lobby_id, "queue", "")
		steam.setLobbyJoinable(lobby_id, false)
	changed.emit()

## Net: the party is back in the lobby.
func on_run_ended() -> void:
	if is_leader():
		_set_lobby_idle()
	changed.emit()

## Net: the queue state the leader told us about (party members only).
func on_party_queue(path: String) -> void:
	if is_leader():
		return
	if path != queue_instance:
		queue_instance = path
		queue_started = _now()
		changed.emit()

func _tick_queue(delta: float) -> void:
	if queue_instance == "" or _moving or not is_leader() or not _net().online:
		return
	if party_size() >= MAX_PARTY:
		var path := queue_instance
		queue_instance = ""
		_toast("Group found!")
		get_node("/root/GameManager").start_game(path)
		return
	if backend != Backend.STEAM:
		return
	_search_timer -= delta
	if _search_timer <= 0.0:
		_search_timer = SEARCH_INTERVAL
		steam.addRequestLobbyListStringFilter("game", GAME_KEY, LOBBY_EQUAL)
		steam.addRequestLobbyListStringFilter("queue", queue_instance, LOBBY_EQUAL)
		steam.addRequestLobbyListFilterSlotsAvailable(party_size())
		steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
		steam.requestLobbyList()

func _on_lobby_match_list(...a: Array) -> void:
	if a.is_empty() or queue_instance == "" or _moving or not is_leader():
		return
	var mine := party_size()
	var best := 0
	var best_n := -1
	for l in a[0]:
		var lid := int(l)
		if lid == lobby_id:
			continue
		if str(steam.getLobbyData(lid, "queue")) != queue_instance:
			continue
		var n := int(steam.getNumLobbyMembers(lid))
		if n <= 0 or n + mine > MAX_PARTY:
			continue
		# Smaller party moves into the bigger one; equal size moves into the lower id.
		# That way two searching parties never swap into each other at once.
		if n < mine or (n == mine and lid > lobby_id):
			continue
		if n > best_n:
			best_n = n
			best = lid
	if best != 0:
		_moving = true
		_toast("Found a group — joining…")
		_net().merge_into(best)

## Net: the leader found a group; everyone in our party moves into lobby `lid`.
func move_to_lobby(lid: int) -> void:
	_moving = true
	queue_instance = ""
	if lobby_id != 0 and backend == Backend.STEAM:
		steam.leaveLobby(lobby_id)
	lobby_id = 0
	_net().leave_session()
	steam.joinLobby(lid)
	changed.emit()

# --- Steam lobby callbacks ------------------------------------------------------------------

func _lobby_host(lid: int) -> int:
	var h := str(steam.getLobbyData(lid, "host"))
	if h.is_valid_int() and int(h) != 0:
		return int(h)
	return int(steam.getLobbyOwner(lid))

func _on_lobby_created(...a: Array) -> void:
	_creating = false
	if a.size() < 2 or int(a[0]) != 1:
		_toast("Couldn't create a party on Steam.")
		_after_create.clear()
		return
	lobby_id = int(a[1])
	steam.setLobbyData(lobby_id, "game", GAME_KEY)
	steam.setLobbyData(lobby_id, "host", str(my_id))
	steam.setLobbyData(lobby_id, "queue", "")
	steam.setLobbyJoinable(lobby_id, true)
	var peer := make_host_peer()
	if peer == null:
		_toast("Couldn't start the party connection.")
		leave_party(true)
		return
	_net().host_session(peer)
	var calls := _after_create.duplicate()
	_after_create.clear()
	for c in calls:
		c.call()
	changed.emit()

func _on_lobby_joined(...a: Array) -> void:
	if a.is_empty():
		return
	var lid := int(a[0])
	var response := int(a[3]) if a.size() > 3 else 1
	if response != 1:
		_moving = false
		_toast("Couldn't join that party (it may be full or gone).")
		changed.emit()
		return
	if _net().online and _net().is_host() and (lid == lobby_id or lobby_id == 0):
		lobby_id = lid   # our own freshly created lobby
		return
	var host := _lobby_host(lid)
	lobby_id = lid
	if host == my_id:
		return
	var peer := make_client_peer(host)
	_moving = false
	if peer == null:
		_toast("Couldn't connect to the party.")
		leave_party(true)
		return
	_net().join_session(peer, host)
	changed.emit()

func _on_lobby_chat_update(...a: Array) -> void:
	if not a.is_empty() and int(a[0]) == lobby_id:
		sync_owner()
		changed.emit()

func _on_lobby_data_update(...a: Array) -> void:
	if a.size() >= 2 and int(a[1]) == lobby_id:
		sync_owner()

func _on_lobby_invite(...a: Array) -> void:
	if a.size() < 2:
		return
	var from := int(a[0])
	var lid := int(a[1])
	for inv in invites:
		if int(inv["lobby"]) == lid:
			return
	invites.append({"from": from, "name": friend_name(from), "lobby": lid})
	_toast("%s invited you to their party." % friend_name(from))
	changed.emit()

func _on_join_requested(...a: Array) -> void:
	# Accepted an invite / clicked "Join game" in the Steam friends list.
	if not a.is_empty():
		join_party(int(a[0]))

func _on_persona_change(..._a: Array) -> void:
	friends_changed.emit()

## Keeps the Steam lobby owner = the game host (Steam picks its own new owner
## when the leader leaves; Net picks the new host by join order).
func sync_owner() -> void:
	if backend != Backend.STEAM or lobby_id == 0 or not _net().online:
		return
	var owner := int(steam.getLobbyOwner(lobby_id))
	var host: int = _net().host_member
	if owner != my_id:
		return
	if host != my_id and host != 0:
		steam.setLobbyOwner(lobby_id, host)
		return
	if str(steam.getLobbyData(lobby_id, "host")) != str(my_id):
		steam.setLobbyData(lobby_id, "host", str(my_id))
		steam.setLobbyData(lobby_id, "game", GAME_KEY)
		steam.setLobbyData(lobby_id, "queue", queue_instance)

## Net: we just became the host through migration.
func on_became_host() -> void:
	sync_owner()
	changed.emit()
