@tool
class_name SetPieceMarker
extends Marker3D

# A set piece inside a DungeonRoom (position relative to the room's middle;
# rotation.y = the way it faces). Kinds are run by scripts/dungeon/set_pieces.gd:
#   alarm_bell   its Bell Ringer rings it when a fight starts near it (reinforcements)
#   ballista     stand on its plate to load it; fires at boss `params.boss`
#   seal_light   one light on the final door per dead wing boss (params.boss)
#   defend_spot  where the room's defend circle goes (instead of the middle)
#   platform     a raised floor with stairs down (towers for archers); params:
#                size (Vector2, default 3.5 x 3.5), height (default 2.5); the
#                stairs come down the way the marker faces
#   wall         a solid block of wall inside the room (built by biome_builder.gd,
#                not set_pieces.gd): L-shapes, alcoves, aisles, pillars. params:
#                size (Vector2 x/z, default 2 x 2; not rotated: the marker's yaw is ignored)

@export_enum("alarm_bell", "ballista", "seal_light", "defend_spot", "platform", "wall") var kind := "alarm_bell"
## Extra settings for the kind (see set_pieces.gd).
@export var params := {}
