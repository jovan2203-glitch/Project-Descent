class_name BiomeKit
extends Resource

# A BIOME KIT: the look of a dungeon, separate from its layout and enemies.
# Modular room pieces (floor, wall, doorway, pillar, corner) + a theme package
# (lighting, fog, darkness, props, music tag). The layout code never knows which
# kit it's building with, so swapping art later means editing these files
# (data/biomes/*.tres) or pointing a recipe at another kit.

## Key into names.gd (e.g. "biome_stone_crypt").
@export var name_key := ""

@export_group("Walls")
## Rock/wall texture: noise between these two colors.
@export var wall_dark := Color(0.13, 0.13, 0.15)
@export var wall_light := Color(0.36, 0.35, 0.37)
## Top of the rock mass (seen from above between rooms).
@export var top_color := Color(0.05, 0.05, 0.06)
## Room corners: "column" (round pillars), "chamfer" (cut corners) or "none".
@export var corner_piece := "column"
## Doorways: "arch" (posts + lintel), "frame" (posts only) or "none".
@export var doorway_piece := "arch"
@export var piece_color := Color(0.3, 0.29, 0.3)
## How the walls break up (so rooms aren't flat boxes):
##   "rough"   bulging cave walls, boulders and rounded corners
##   "masonry" buttresses and burial niches cut into the stone
##   "timber"  wooden posts, beams and wall planks (forts, mines)
##   "ice"     jutting ice slabs and icicles
@export var wall_style := "masonry"
## 0..1: how much of the free wall space gets broken up.
@export var chunk_density := 0.6

@export_group("Floor")
## "flagstone", "rough" (cave floor), "ice" or "planks".
@export var floor_pattern := "flagstone"
@export var floor_dark := Color(0.12, 0.115, 0.11)
@export var floor_light := Color(0.31, 0.3, 0.29)

@export_group("Light")
@export var background := Color(0.01, 0.01, 0.015)
@export var ambient := Color(0.3, 0.33, 0.45)
@export var ambient_energy := 0.35
## Dim fill light per room.
@export var fill_color := Color(0.75, 0.6, 0.5)
@export var fill_energy := 0.35
@export var boss_fill_color := Color(1.0, 0.35, 0.25)
## Wall torches (flickering). Color is also the flame's.
@export var torches := true
@export var torch_color := Color(1.0, 0.62, 0.3)
@export var fog := false
@export var fog_color := Color(0.1, 0.1, 0.12)
@export var fog_density := 0.01

@export_group("Props")
## Big props against the walls (they block movement): sarcophagus, coffin,
## bookshelf, weapon_rack, crate_stack, barrels, statue, hay, table, altar,
## boulder, ice_block, bone_pile.
@export var big_props: Array[String] = []
## Things hung on the walls: banner, chains, shield, moss, icicles, candles_ledge, planks.
@export var wall_decor: Array[String] = []
## Stains / puddles / moss / snow patches on the floor.
@export var decal_colors: Array[Color] = []
## The boss rooms' centerpiece: summoning_circle, crystal_cluster, throne, ice_statues.
@export var centerpiece := ""
## Small clutter (no collision) scattered along walls and floors: rubble, bones,
## skull, candles, urn, bucket, crystal, mushroom, ice_spike, stalagmite, brazier,
## crate, barrel. "pillar" = free-standing pillars in big rooms.
@export var props: Array[String] = []
## Props per room (average).
@export var prop_density := 4.0
## Glowing props (crystals, mushrooms, ice) use this color.
@export var glow_color := Color(0.3, 0.85, 1.0)

@export_group("Audio")
## Tag for the music system (no music is shipped yet).
@export var music_tag := ""

@export_group("Mechanics")
## How boss mechanics look in this dungeon (shapes never change; see
## scripts/dungeon/mechanic_look.gd). Empty = the default look.
@export var mechanic_theme: MechanicTheme
