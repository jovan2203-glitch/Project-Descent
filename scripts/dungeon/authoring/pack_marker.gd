@tool
class_name PackMarker
extends Marker3D

# A hand-placed enemy pack inside a DungeonRoom (its position is relative to the
# room's middle). Rooms with markers spawn exactly these, plus random packs
# unless the room says no_random_packs.

## Roles in the pack (brute, swarmer, caster, archer, defender, support,
## summoner). A swarmer entry is one swarmer, not a group.
@export var roles: Array[String] = ["brute"]
## Elites added to the pack (random non-swarmer roles from the room's roster).
@export var elites := 0
## Elites here carry a key (key_elites objective).
@export var keybearer := false
## How the pack stands: ring (around the spot, facing anywhere), around (in a
## circle facing the spot: a campfire, a desk), line (side by side, facing the
## marker's forward, -Z: a drill line, gate guards).
@export_enum("ring", "around", "line") var formation := "ring"
## Metres from the spot (0 = the default for the pack's size).
@export var spread := 0.0
## Idle wander radius in metres (0 = stand still).
@export var roam := 0.0
