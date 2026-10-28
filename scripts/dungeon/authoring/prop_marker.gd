@tool
class_name PropMarker
extends Marker3D

# A hand-placed prop inside a DungeonRoom (position relative to the room's middle;
# rotation.y = the way its front faces). Look only, built by biome_builder.gd
# (its BIG props: bookshelf, campfire, page_pile, siege_cart ...); the blocking ones
# get collision in the rock. Use them to tell the room's story; the biome kit's
# random wall props still fill in around them.

## A biome_builder.gd BIG prop kind.
@export var kind := "crate_stack"
