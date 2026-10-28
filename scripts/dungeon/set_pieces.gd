extends Node

# Set pieces of a hand-made map (SetPieceMarker nodes, read by Layouts.from_scene).
# Child of the dungeon runner. The host (or solo player) decides; party members
# get the result through Net.dungeon_event -> net_event() here.
#
#   alarm_bell   a Bell Ringer stands at the bell. When a fight starts near it,
#                it casts "Ring the Alarm" (interrupt, stun or kill it). If the
#                cast finishes, a reinforcement pack from the room's roster comes.
#                params: role (reinforcement role, default: rolled from the roster)
#   ballista     stand on its plate (BALLISTA_LOAD_TIME) during the fight with
#                boss `params.boss` and it fires: the boss is Knocked Down,
#                then takes more damage for a while. Cooldown BALLISTA_COOLDOWN.
#                params: boss (index), needs_section (only after that section's
#                objective is done; default: the room's section)
#   seal_light   lights up when boss `params.boss` dies (the final door's seals)
#   defend_spot  (read by the runner: where the defend circle goes)
#
# Visuals are greybox, built here; swap-ready: a piece's `params.scene` (a
# PackedScene path) replaces the default look.

const Balance = preload("res://scripts/balance.gd")
const Names = preload("res://scripts/dungeon/names.gd")
const Look = preload("res://scripts/dungeon/mechanic_look.gd")
const FX = preload("res://scripts/dungeon/boss_abilities.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const KNOCKED_DOWN = preload("res://data/effects/knocked_down.tres")
const STAIRS = preload("res://scenes/dungeon/pieces/stairs.tscn")

var dungeon: Node
var _bells: Array = []      # {room, at, ringer, rung, retry_at, glow}
var _ballistas: Array = []  # {room, at, yaw, boss, section, ready_at, load, fill, label}
var _seals: Array = []      # {boss, mat, light, lit}
var _platforms: Array = []  # {inv (world -> platform space), size, h}
var _sent := 0.0

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _host() -> bool:
	var n := _net()
	return n == null or not n.is_client()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Build every set piece (every machine, same order, so names match).
func build() -> void:
	var rooms: Array = dungeon.rooms
	for ri in rooms.size():
		var pieces: Array = rooms[ri].get("pieces", [])
		for pi in pieces.size():
			var pc: Dictionary = pieces[pi]
			match str(pc["kind"]):
				"alarm_bell":
					_build_bell(ri, pi, pc)
				"ballista":
					_build_ballista(ri, pc)
				"seal_light":
					_build_seal(pc)
				"platform":
					_build_platform(pc)

# --- Alarm bell ----------------------------------------------------------------------------------

func _build_bell(ri: int, pi: int, pc: Dictionary) -> void:
	var at: Vector3 = pc["at"]
	var root := _piece_root(pc, at)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.7, 0.55, 0.25)
	glow.metallic = 0.8
	glow.roughness = 0.35
	if root.get_child_count() == 0:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.32, 0.22, 0.13)
		for s: float in [-0.7, 0.7]:
			_box(root, Vector3(0.18, 2.6, 0.18), Vector3(s, 1.3, 0), wood)
		_box(root, Vector3(1.6, 0.18, 0.22), Vector3(0, 2.6, 0), wood)
		var bell := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.48
		cm.height = 0.7
		bell.mesh = cm
		bell.material_override = glow
		bell.position = Vector3(0, 2.15, 0)
		root.add_child(bell)
	# The Bell Ringer: rooted beside the bell, so you come to it.
	var r := RandomNumberGenerator.new()
	r.seed = int(dungeon.seed_used) + ri * 131 + pi
	var e: Node3D = dungeon._make_enemy(str(pc["params"].get("ringer_role", "swarmer")), "normal",
		"Bell%d_%d" % [ri, pi], r, ri)
	e.display_name = Names.t("bell_ringer")
	e.show_name = true
	e.move_speed = 0.0
	var s := int(dungeon.rooms[ri]["section"])
	e.set_meta("section", s)
	if s >= 0 and s < dungeon.sections.size():
		dungeon.sections[s]["total"] = int(dungeon.sections[s]["total"]) + 1
	var side := Vector3(cos(float(pc["yaw"])), 0, -sin(float(pc["yaw"])))
	e.position = dungeon.enemies_root.to_local(at + side * 1.4 + Vector3(0, e.ground_offset(), 0))
	dungeon.enemies_root.add_child(e)
	_bells.append({"room": ri, "at": at, "ringer": e, "rung": false, "retry_at": 0.0, "glow": glow,
		"role": str(pc["params"].get("role", ""))})

func _tick_bell(i: int) -> void:
	var b: Dictionary = _bells[i]
	# Check before the typed read: a dead ringer is freed, and assigning a freed node to a typed var errors.
	if b["rung"] or not is_instance_valid(b["ringer"]):
		return
	var e: Node3D = b["ringer"]
	if not e.is_alive():
		return
	if e.is_casting() or e.is_silenced() or _now() < float(b["retry_at"]):
		return
	if e.status and e.status.has_flag("stun"):
		return
	if not (e.is_in_combat() or _fight_near(b["at"])):
		return
	b["retry_at"] = _now() + Balance.ALARM_RING_TIME + 1.0
	var title := Names.t("ab_ring_alarm")
	dungeon._announce("%s begins %s - stop it!" % [e.display_name, title], Look.color("interrupt"))
	_cast(e, title, Balance.ALARM_RING_TIME, func(): _ring(i))

## Any enemy close to the bell fighting?
func _fight_near(at: Vector3) -> bool:
	for en in dungeon.enemies_root.get_children():
		if en.has_method("is_alive") and en.is_alive() and en.is_in_combat() \
				and Vector2(en.global_position.x - at.x, en.global_position.z - at.z).length() <= Balance.ALARM_RADIUS:
			return true
	return false

func _ring(i: int) -> void:
	var b: Dictionary = _bells[i]
	b["rung"] = true
	_show_rung(i)
	var r := RandomNumberGenerator.new()
	r.seed = int(dungeon.seed_used) + 4242 + i
	var role: String = b["role"] if str(b["role"]) != "" else dungeon._pick_role(r, true, int(b["room"]))
	dungeon.summon_adds(b["at"], Balance.ALARM_REINFORCEMENTS, role, null)
	dungeon._announce(Names.t("alarm_raised"), Color(1.0, 0.5, 0.3))
	var n := _net()
	if n and n.is_host():
		n.dungeon_event("bell", {"i": i})

func _show_rung(i: int) -> void:
	var b: Dictionary = _bells[i]
	b["rung"] = true
	var m: StandardMaterial3D = b["glow"]
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.15)
	m.emission_energy_multiplier = 3.0
	FX.burst(get_tree().current_scene, b["at"], 6.0, Color(1.0, 0.5, 0.2))

## An interruptible cast on an enemy (it IS the enemy's cast tween).
func _cast(e: Node3D, title: String, time: float, done: Callable) -> void:
	e.cast_name = title
	e.busy_until = _now() + time
	e._show_cast(true, time)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(e, "cast", null, {"d": time, "n": title})
	var t := e.create_tween()
	e._cast_tween = t
	t.tween_interval(time)
	t.tween_callback(func():
		e._cast_tween = null
		e._show_cast(false)
		if is_instance_valid(e) and e.is_alive():
			done.call())

# --- Ballista ------------------------------------------------------------------------------------

func _build_ballista(ri: int, pc: Dictionary) -> void:
	var at: Vector3 = pc["at"]
	var root := _piece_root(pc, at)
	if root.get_child_count() == 0:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.36, 0.25, 0.14)
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.3, 0.3, 0.33)
		iron.metallic = 0.7
		_box(root, Vector3(1.0, 0.6, 2.2), Vector3(0, 0.3, 0), wood)          # base
		_box(root, Vector3(0.25, 0.25, 2.6), Vector3(0, 0.85, -0.2), wood)    # stock
		_box(root, Vector3(2.4, 0.16, 0.16), Vector3(0, 0.95, -1.2), wood)    # bow arms
		_box(root, Vector3(0.06, 0.06, 1.8), Vector3(0, 1.05, -0.6), iron)    # the bolt
	var params: Dictionary = pc["params"]
	# The loading plate behind it: a "go here" circle that fills while you stand on it.
	var plate_at := at + Vector3(sin(float(pc["yaw"])), 0, cos(float(pc["yaw"]))) * 1.8
	var plate := Node3D.new()
	dungeon.level_root.add_child(plate)
	plate.global_position = plate_at + Vector3(0, 0.04, 0)
	var col := Look.color("safe")
	var disc := _disc(Balance.BALLISTA_PLATE_RADIUS, Color(col, 0.22))
	plate.add_child(disc)
	var fill := _disc(Balance.BALLISTA_PLATE_RADIUS, Color(col, 0.5))
	fill.position.y = 0.01
	fill.scale = Vector3(0.01, 1, 0.01)
	plate.add_child(fill)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.outline_size = 8
	label.pixel_size = 0.01
	label.modulate = col.lightened(0.3)
	label.position = Vector3(0, 2.0, 0)
	plate.add_child(label)
	_ballistas.append({"room": ri, "at": at, "plate": plate_at, "boss": int(params.get("boss", 0)),
		"section": int(params.get("needs_section", dungeon.rooms[ri]["section"])),
		"ready_at": 0.0, "load": 0.0, "fill": fill, "label": label})
	_ballista_label(_ballistas.size() - 1)

func _ballista_on(i: int) -> bool:
	var b: Dictionary = _ballistas[i]
	var k: int = b["boss"]
	var s: int = b["section"]
	return s >= 0 and s < dungeon.sections.size() and bool(dungeon.sections[s]["done"]) \
		and k < dungeon.boss_started.size() and dungeon.boss_started[k] and not dungeon.boss_dead[k] \
		and dungeon.bosses[k] != null and is_instance_valid(dungeon.bosses[k])

func _ballista_label(i: int) -> void:
	var b: Dictionary = _ballistas[i]
	var left := float(b["ready_at"]) - _now()
	var text := Names.t("ballista")
	if left > 0.0:
		text += "\n%d s" % int(ceil(left))
	elif _ballista_on(i):
		text += "\n" + Names.t("ballista_hint")
	(b["label"] as Label3D).text = text

func _tick_ballista(i: int, delta: float) -> void:
	var b: Dictionary = _ballistas[i]
	var on := _ballista_on(i) and _now() >= float(b["ready_at"])
	var standing := false
	if on:
		for body in dungeon._party():
			if is_instance_valid(body) and body.is_alive() and \
					Vector2(body.global_position.x - b["plate"].x, body.global_position.z - b["plate"].z).length() <= Balance.BALLISTA_PLATE_RADIUS:
				standing = true
				break
	b["load"] = clampf(float(b["load"]) + (delta if standing else -delta * 2.0), 0.0, Balance.BALLISTA_LOAD_TIME)
	_show_load(i, float(b["load"]))
	if float(b["load"]) >= Balance.BALLISTA_LOAD_TIME:
		b["load"] = 0.0
		_fire(i)

func _show_load(i: int, l: float) -> void:
	var p := clampf(l / Balance.BALLISTA_LOAD_TIME, 0.01, 1.0)
	(_ballistas[i]["fill"] as Node3D).scale = Vector3(p, 1, p)

func _fire(i: int) -> void:
	var b: Dictionary = _ballistas[i]
	b["ready_at"] = _now() + Balance.BALLISTA_COOLDOWN
	var boss: Node3D = dungeon.bosses[int(b["boss"])]
	_show_fire(i)
	var n := _net()
	if n and n.is_host():
		n.dungeon_event("ballista", {"i": i})
	get_tree().create_timer(0.35).timeout.connect(func():
		if not is_instance_valid(boss) or not boss.is_alive():
			return
		var st: Node = boss.get_node_or_null("Status")
		if st:
			st.apply(_knocked_down(), null)
			st.apply(_weak_spot(), null)
		boss.take_damage(maxi(int(round(float(boss.max_health) * Balance.BALLISTA_DAMAGE_PCT / 100.0)), 1))
		dungeon._announce(Names.t("ballista_hit") % boss.display_name, Look.color("safe")))

## Bolt flies from the ballista to its boss (every machine).
func _show_fire(i: int) -> void:
	var b: Dictionary = _ballistas[i]
	b["ready_at"] = _now() + Balance.BALLISTA_COOLDOWN
	var k := int(b["boss"])
	var boss: Node3D = dungeon.bosses[k] if k < dungeon.bosses.size() else null
	if boss == null or not is_instance_valid(boss):
		return
	var bolt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 1.8)
	bolt.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.6)
	mat.emission_energy_multiplier = 2.0
	bolt.material_override = mat
	get_tree().current_scene.add_child(bolt)
	var from: Vector3 = b["at"] + Vector3(0, 1.05, 0)
	var to := boss.global_position + Vector3(0, 1.2, 0)
	bolt.global_position = from
	if (to - from).length() > 0.1:
		bolt.look_at(to, Vector3.UP)
	var t := bolt.create_tween()
	t.tween_property(bolt, "global_position", to, 0.35)
	t.tween_callback(func():
		FX.burst(get_tree().current_scene, to, 2.5, Color(1.0, 0.9, 0.6))
		bolt.queue_free())

## Knocked Down (the same effect the Maul uses) under its own id, so nothing
## that checks for a player's knockdowns reacts to it (own-only).
func _knocked_down() -> Resource:
	var r: Resource = KNOCKED_DOWN.duplicate()
	r.id = &"ballista_down"
	r.description = "Knocked down by a ballista bolt: cannot move, attack or cast."
	r.duration = Balance.BALLISTA_STUN
	return r

func _weak_spot() -> Resource:
	var r := StatusEffectScript.new()
	r.id = &"ballista_weak_spot"
	r.display_name = Names.t("weak_spot")
	r.description = "Takes %d%% more damage." % int(Balance.BALLISTA_EXPOSED_PCT)
	r.color = Color(1.0, 0.8, 0.4)
	r.duration = Balance.BALLISTA_STUN + Balance.BALLISTA_EXPOSED_TIME
	r.stack_mode = 0
	r.modifies_incoming = true
	r.damage_mod_pct = Balance.BALLISTA_EXPOSED_PCT
	return r

# --- Platforms ------------------------------------------------------------------------------------

## A raised floor (box collider, greybox look) with stairs coming down the way the
## marker faces. Built under the rock, so the navmesh covers it.
func _build_platform(pc: Dictionary) -> void:
	var params: Dictionary = pc["params"]
	var host: Node = dungeon.level_root.get_node_or_null("Rock")
	if host == null:
		host = dungeon.level_root
	var size: Vector2 = params.get("size", Vector2(3.5, 3.5))
	var h := float(params.get("height", 2.5))
	make_platform(host, pc["at"], float(pc.get("yaw", 0.0)), size, h)
	var xf := Transform3D(Basis(Vector3.UP, float(pc.get("yaw", 0.0))), pc["at"])
	_platforms.append({"inv": xf.affine_inverse(), "size": size, "h": h})

## The platform itself (also used by tools/walk_check.gd). Returns the stairs' low
## end and the platform's top middle, for walking checks.
static func make_platform(host: Node, at: Vector3, yaw: float, size: Vector2, h: float) -> Array:
	var root := Node3D.new()
	root.name = "Platform"
	host.add_child(root)
	root.global_position = at
	root.rotation.y = yaw
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, h, size.y)
	cs.shape = bs
	cs.position.y = h * 0.5
	body.add_child(cs)
	root.add_child(body)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.38, 0.33)
	stone.roughness = 0.9
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = stone
	mi.position.y = h * 0.5
	root.add_child(mi)
	# Stairs: low end on the floor out front, climbing back to the platform's edge.
	var stairs: Node3D = STAIRS.instantiate()
	stairs.run = h * 2.2
	stairs.rise = h
	stairs.width = minf(size.x, 2.0)
	stairs.step_material = stone
	root.add_child(stairs)
	stairs.position = Vector3(0, 0, size.y * 0.5 + h * 2.2)   # climbs towards local -Z, back to the platform
	return [root.to_global(stairs.position), root.to_global(Vector3(0, h, 0))]

## Is world point `p` on a platform's top or its stairs? (The navmesh keeps these as
## floor; everything else above a room's floor is a wall top.)
func is_floor(p: Vector3) -> bool:
	for pl in _platforms:
		var q: Vector3 = (pl["inv"] as Transform3D) * p
		var size: Vector2 = pl["size"]
		var h: float = pl["h"]
		if absf(q.x) <= size.x * 0.5 + 0.3 and absf(q.z) <= size.y * 0.5 + 0.3 and absf(q.y - h) <= 0.8:
			return true
		var run := h * 2.2
		var s := q.z - size.y * 0.5
		if absf(q.x) <= 1.3 and s >= -0.3 and s <= run + 0.3 and absf(q.y - h * (1.0 - clampf(s / run, 0.0, 1.0))) <= 0.8:
			return true
	return false

# --- Seal lights ----------------------------------------------------------------------------------

func _build_seal(pc: Dictionary) -> void:
	var root := _piece_root(pc, pc["at"])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.3)
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	gem.mesh = sm
	gem.material_override = mat
	gem.position.y = 2.4
	root.add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.position.y = 2.4
	root.add_child(light)
	_seals.append({"boss": int(pc["params"].get("boss", 0)), "mat": mat, "light": light, "lit": false})

func _tick_seals() -> void:
	for s in _seals:
		var k := int(s["boss"])
		if s["lit"] or k >= dungeon.boss_dead.size() or not dungeon.boss_dead[k]:
			continue
		s["lit"] = true
		var m: StandardMaterial3D = s["mat"]
		m.albedo_color = Color(1.0, 0.85, 0.4)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.3)
		m.emission_energy_multiplier = 3.0
		(s["light"] as OmniLight3D).light_energy = 2.5

# --- Per frame / network ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if dungeon == null:
		return
	_tick_seals()
	if _host():
		for i in _bells.size():
			_tick_bell(i)
		for i in _ballistas.size():
			_tick_ballista(i, delta)
		var n := _net()
		if n and n.is_host() and _now() - _sent > 0.25 and not _ballistas.is_empty():
			_sent = _now()
			var loads: Array = []
			for b in _ballistas:
				loads.append(float(b["load"]))
			n.dungeon_event("ballista_load", {"l": loads})
	for i in _ballistas.size():
		_ballista_label(i)

func net_event(ev: String, data: Dictionary) -> void:
	match ev:
		"bell":
			var i := int(data.get("i", -1))
			if i >= 0 and i < _bells.size():
				_show_rung(i)
		"ballista":
			var i := int(data.get("i", -1))
			if i >= 0 and i < _ballistas.size():
				_show_fire(i)
		"ballista_load":
			var loads: Array = data.get("l", [])
			for i in mini(loads.size(), _ballistas.size()):
				_show_load(i, float(loads[i]))

# --- Greybox helpers ------------------------------------------------------------------------------

## The piece's root at `at`, facing its marker's way; holds `params.scene` if given.
func _piece_root(pc: Dictionary, at: Vector3) -> Node3D:
	var root := Node3D.new()
	dungeon.level_root.add_child(root)
	root.global_position = at
	root.rotation.y = float(pc.get("yaw", 0.0))
	var scene_path := str(pc["params"].get("scene", ""))
	if scene_path != "" and ResourceLoader.exists(scene_path):
		root.add_child((load(scene_path) as PackedScene).instantiate())
	return root

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _disc(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 32
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
