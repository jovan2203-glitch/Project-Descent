class_name LootEntryData
extends Resource

## One possible drop inside a LootTableData.

## Base item id (e.g. "sword"), see Items.PATHS.
@export var item_id: StringName = &""
## Independent drop chance (used in the table's `chance_drops` list), 0..1.
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## Relative weight (used in the table's weighted `pool`).
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0
## Force a minimum rarity for this entry (-1 = roll normally).
@export_range(-1, 3) var min_rarity: int = -1
