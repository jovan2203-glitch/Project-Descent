@tool
class_name DungeonRoom
extends Node3D

# One room of a hand-made layout (see dungeon_layout.gd). Its parent room is the
# room it connects to; rooms at different heights get stairs between them.
# In the editor it snaps to its cell and shows its outline.

## Grid cell (x, z). Neighbouring cells are joined by a passage or stairs.
@export var cell := Vector2i.ZERO:
	set(v):
		cell = v
		_refresh()
## Floor height in metres (stairs are built between different heights).
@export var floor_y := 0.0:
	set(v):
		floor_y = v
		_refresh()
## Floor size in metres (x, z). Must fit inside the cell with room for walls.
@export var size := Vector2(12, 12):
	set(v):
		size = v
		_refresh()
## start, combat, side, junction (empty), hub, boss.
@export_enum("start", "combat", "side", "junction", "hub", "boss") var kind := "combat"
## Which boss's section this room belongs to (its objective counts it).
@export var section := 0
## Boss index for a boss room, else -1.
@export var boss := -1
## names.gd key shown on the map / in announcements ("" = none).
@export var room_name := ""
## Key into the recipe's `rosters` for this room's enemies ("" = the main roster).
@export var roster := ""
## Dressing overrides ("" / empty = the biome kit's own).
@export var centerpiece := ""
@export var big_props: Array[String] = []
## Leave the room empty of random packs (only its PackMarkers spawn).
@export var no_random_packs := false

var _outline: MeshInstance3D

func _ready() -> void:
	_refresh()

## World-space middle of the floor, from the cell (node transforms are ignored).
func center(cell_size: float) -> Vector3:
	return Vector3(cell.x * cell_size, floor_y, cell.y * cell_size)

func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var layout := _layout()
	var cs: float = layout.cell_size if layout else 22.0
	global_position = center(cs)
	if _outline == null:
		_outline = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.4, 0.8, 1.0, 0.25) if kind != "boss" else Color(1.0, 0.4, 0.3, 0.3)
		_outline.material_override = mat
		add_child(_outline)   # not owned: never saved into the scene
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.1, size.y)
	_outline.mesh = bm

func _layout() -> Node:
	var n := get_parent()
	while n != null and not (n is DungeonLayout):
		n = n.get_parent()
	return n
