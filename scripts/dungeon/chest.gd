extends Node3D

# A treasure chest holding a random Skill Card the player doesn't own yet.
# Placed by the dungeon generator. Walk up to it to open it.
#   - `locked` chests (in rooms with enemies) open once that room is cleared.
#   - In a party every player has their own copy of each chest (opened locally),
#     so everyone gets their own card.
# Cards go into the permanent collection (PlayerData.owned_cards) and survive death.

const SkillCards = preload("res://scripts/skill_cards.gd")
const Abilities = preload("res://scripts/abilities.gd")
const OPEN_RADIUS := 1.4

var locked := false
var opened := false
## Skill Cards inside (different ones, all new to you).
var cards := 2
var _lid_pivot: Node3D
var _label: Label3D
var _light: OmniLight3D
var _glow_mat: StandardMaterial3D
var _t := 0.0

func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.2, 0.1)
	wood.roughness = 0.85
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.85, 0.65, 0.25)
	trim.metallic = 0.8
	trim.roughness = 0.35

	# Base (0.9 x 0.5 x 0.6 m) with a metal band.
	_add_box(self, Vector3(0.9, 0.5, 0.6), Vector3(0, 0.25, 0), wood)
	_add_box(self, Vector3(0.92, 0.08, 0.62), Vector3(0, 0.42, 0), trim)
	# Lid hinged at the back edge.
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, 0.5, -0.3)
	add_child(_lid_pivot)
	_add_box(_lid_pivot, Vector3(0.9, 0.22, 0.6), Vector3(0, 0.11, 0.3), wood)
	_add_box(_lid_pivot, Vector3(0.14, 0.24, 0.62), Vector3(0, 0.11, 0.3), trim)
	# Lock plate / inner glow.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.emission_enabled = true
	_add_box(self, Vector3(0.14, 0.14, 0.04), Vector3(0, 0.38, 0.31), _glow_mat)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.9, 0)
	_light.omni_range = 3.0
	add_child(_light)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.position.y = 1.25
	add_child(_label)
	_refresh()

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	m.mesh = b
	m.position = pos
	parent.add_child(m)

func unlock() -> void:
	if not locked:
		return
	locked = false
	_refresh()

func _refresh() -> void:
	var col := Color(0.4, 0.4, 0.45)
	if opened:
		_label.text = ""
		_light.light_energy = 0.0
		col = Color(0.2, 0.2, 0.2)
	elif locked:
		_label.text = "Chest (locked — clear the room)"
		_label.modulate = Color(0.75, 0.75, 0.8)
		_light.light_color = Color(0.6, 0.6, 0.7)
		_light.light_energy = 0.3
		col = Color(0.5, 0.5, 0.55)
	else:
		_label.text = "Chest"
		_label.modulate = Color(0.8, 0.6, 1.0)
		_light.light_color = Color(0.8, 0.6, 1.0)
		_light.light_energy = 1.4
		col = Color(0.8, 0.55, 1.0)
	_glow_mat.albedo_color = col
	_glow_mat.emission = col
	_glow_mat.emission_energy_multiplier = 0.2 if (opened or locked) else 2.5

func _process(delta: float) -> void:
	if opened:
		return
	_t += delta
	if not locked:
		_light.light_energy = 1.2 + 0.4 * sin(_t * 3.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("is_alive") or not player.is_alive():
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if d.length() > OPEN_RADIUS or locked:
		return
	_open()

func _open() -> void:
	opened = true
	var pd := get_node("/root/PlayerData")
	var color := Color(0.8, 0.6, 1.0)
	var names: Array[String] = []
	for i in cards:
		var card: String = pd.random_unowned_card()
		if card == "":
			break
		pd.grant_card(card)   # owned now, so the next roll picks a different one
		var aname := Abilities.ability_name(SkillCards.ability_of(card))
		names.append(aname)
		get_node("/root/SignalBus").skill_card_unlocked.emit(card)
		var gl := get_node_or_null("/root/GameLog")
		if gl:
			gl.event("Found Skill Card: %s (equip it in the Skill Cards tab)" % aname, color)
	var text := ""
	if names.is_empty():
		text = "Empty — you own every Skill Card"
		color = Color(0.7, 0.7, 0.75)
	else:
		text = "Skill Card%s: %s!" % ["s" if names.size() > 1 else "", " & ".join(names)]
	_float(text, color)
	var tw := create_tween()
	tw.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-110.0), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()

func _float(text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 52
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = color
	add_child(l)
	l.position = Vector3(0, 1.3, 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", 2.3, 1.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.4)
	t.chain().tween_callback(l.queue_free)
