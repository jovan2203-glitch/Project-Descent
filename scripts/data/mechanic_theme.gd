class_name MechanicTheme
extends Resource

# How one dungeon's boss mechanics LOOK. The shapes and what they mean never
# change (scripts/dungeon/mechanic_look.gd): a down arrow is always "stack up",
# outward arrows always "spread out". A theme only restyles them, e.g. an iron
# arrow in the Fort and a bone arrow in the Crypt. Set on a biome kit; anything
# left empty uses the default look.

## Family -> rim color (keep each within its family's hue so it still reads):
## avoid, safe, stack, spread, stay_out, interrupt, guards.
@export var colors := {}
## Marker -> a scene that replaces the default mesh (artists): stack_arrow,
## spread_arrow, pool_rim, guard_bubble. The scene is shown at the marker's place,
## 1 unit = the default size (stack/spread arrows are ~1.2 m long).
@export var scenes := {}
