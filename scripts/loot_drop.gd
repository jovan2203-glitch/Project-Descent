extends Node3D

# An item lying on the ground. Walk over it to pick it up.

const Items = preload("res://scripts/items.gd")
const PICKUP_RADIUS := 1.1

var item_id := ""
var require_exit := false
var _gem: MeshInstance3D
var _t := 0.0
var _full_warned := false

func _ready() -> void:
	var it := Items.get_item(item_id)
	var col: Color = it.get("color", Color.WHITE)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.35)
	mat.emission_energy_multiplier = 1.6
	mat.metallic = 0.6
	mat.roughness = 0.3

	# Spinning double-pyramid "loot gem"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.3, 0.3, 0.3)
	prism.material = mat
	_gem = MeshInstance3D.new()
	_gem.mesh = prism
	_gem.position.y = 0.5
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem)
	var bottom := MeshInstance3D.new()
	bottom.mesh = prism
	bottom.rotation.x = PI
	bottom.position.y = -0.3
	_gem.add_child(bottom)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 1.2
	light.omni_range = 2.2
	light.position.y = 0.6
	add_child(light)

	var name_label := Label3D.new()
	name_label.text = Items.item_name(item_id)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.font_size = 40
	name_label.pixel_size = 0.006
	name_label.outline_size = 10
	name_label.modulate = Items.rarity_color(item_id) if Items.rarity_of(item_id) > 0 else Color(1.0, 0.85, 0.45)
	name_label.position.y = 1.05
	add_child(name_label)

func _process(delta: float) -> void:
	_t += delta
	_gem.rotation.y += delta * 2.0
	_gem.position.y = 0.5 + sin(_t * 3.0) * 0.08

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or ("health" in player and player.health <= 0):
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if d.length() > PICKUP_RADIUS:
		_full_warned = false
		require_exit = false
		return
	if require_exit:
		return   # dropped by the player: must walk away before it can be picked up again
	var pd := get_node("/root/PlayerData")
	if pd.add_item(item_id):
		queue_free()
	elif not _full_warned:
		_full_warned = true
		get_node("/root/SignalBus").action_error.emit("Inventory full")
