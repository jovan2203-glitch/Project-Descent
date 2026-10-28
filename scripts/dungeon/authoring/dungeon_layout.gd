@tool
class_name DungeonLayout
extends Node3D

# Root of a HAND-MADE dungeon layout scene (a recipe's `layout_scene`). Designers
# build the map in the editor from DungeonRoom nodes; Layouts.from_scene() turns it
# into the same room graph the random layouts make, so the builder, runner, map
# and navmesh never know the difference.
#
#   DungeonLayout
#     DungeonRoom "Landing"   (kind start)       <- the first room is the start
#       DungeonRoom "Gatehouse"                  <- a child room = a passage to it
#         PackMarker, SetPieceMarker ...         <- gameplay markers in that room
#
# Gameplay only: no art here. Art goes in the recipe's `art_scene` later.

## Grid spacing in metres; a room's `cell` is multiplied by it.
@export var cell_size := 22.0
## Passage width in metres.
@export var corridor := 3.6
## The last boss's door opens only when every other boss is dead (hub dungeons).
@export var final_needs_wings := false
