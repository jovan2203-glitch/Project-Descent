class_name DungeonRecipe
extends Resource

# A DUNGEON is just a recipe (data/dungeons/*.tres). Adding a dungeon = making a
# new recipe file; no code. The generic runner (scripts/dungeon/dungeon_run.gd)
# builds it: layout style + biome kit + enemy roster + bosses + objectives +
# modifiers. Every visible name is a key into scripts/dungeon/names.gd.

## Unique id (used by the queue and saves), e.g. "crypt".
@export var id := ""
@export var name_key := ""
@export var desc_key := ""
## Put in the "Random Dungeon" queue pool.
@export var in_random_pool := true
@export var biome: BiomeKit

## Layout style: "linear", "hub", "descent", "cavern", "arena" or "maze".
@export var layout := "linear"
## Combat rooms before each boss (linear / descent / cavern / maze).
@export var rooms_per_section := 3
## A hand-made map (a DungeonLayout scene). When set, `layout` and
## `rooms_per_section` are ignored and the map is the same every run.
@export var layout_scene: PackedScene
## Optional finished art for a hand-made map. Replaces the generated greybox:
## it must carry the collision and the walkable floors (see docs/DUNGEONS.md).
@export var art_scene: PackedScene

## Enemy roster: role -> skin. A skin is
##   {"scene": "res://scenes/zombie.tscn", "name": "<names key>", "weight": 3,
##    "tint": Color, "cast": "<names key>", "school": "shadow", "color": Color,
##    "summons": "swarmer"}
## Roles: brute, swarmer, caster, archer, defender, support, summoner.
@export var roster := {}
## Extra rosters by key, for rooms whose DungeonRoom.roster names one
## (a wing with its own enemies). Same format as `roster`.
@export var rosters := {}
@export var pack_min := 2
@export var pack_max := 4
## Chance a combat room also has an elite (0..1).
@export var elite_chance := 0.35

## Bosses, in order (3-4). Each is
##   {"name": "<names key>", "skin": {"scene", "tint", "scale"}, "role": "",
##    "hp": 1.0, "dmg": 1.0, "abilities": [ {"type": "slam", ...}, ... ]}
## Ability types: see scripts/dungeon/boss_kit.gd.
@export var bosses: Array = []

## Objective of each section before a boss (cycled): reach_exit, clear_pct,
## key_elites, survive_waves, defend, timed_escape. (Hub layouts give the final
## boss "wing_bosses" automatically.)
@export var objectives: Array[String] = ["clear_pct"]
## clear_pct: share of the section's enemies to slay.
@export var clear_pct := 75
## survive_waves: number of waves.
@export var waves := 3
## timed_escape: seconds.
@export var escape_time := 120.0
## defend: seconds of channeling.
@export var defend_time := 30.0

## Dungeon modifiers this dungeon can roll, and how many per run.
@export var modifier_pool: Array[String] = []
@export var modifier_count := 1
