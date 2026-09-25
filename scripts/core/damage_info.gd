extends RefCounted

# One damage event flowing through CombatSystem.deal().
# Build with DamageInfo.make(...), tweak fields, pass to CombatSystem.deal().
# After deal() returns, amount/crit/blocked hold the final result.
# Names for damage_type / tags live in res://scripts/core/combat_keys.gd.

var source: Node = null          # who dealt it (player, enemy, or null for environment)
var target: Node = null          # who receives it
var base: int = 0                # raw damage before bonuses/mitigation
var amount: int = 0              # final damage applied
var damage_type: String = "physical"   # physical, fire, frost, lightning, ...
var tags: PackedStringArray = PackedStringArray()
var ability_id: String = ""      # e.g. "frostbolt", "auto_melee", "zombie_melee"
var is_proc := false             # caused by an rune (runes ignore these)
var is_dot := false              # damage-over-time tick
var can_crit := true
var can_block := true
var add_power := true            # add the attacker's Spell / Attack Power (see stats.gd)
var power_share := 1.0           # fraction of that power bonus (DoT ticks get less)
var crit := false
var blocked := false
var effects: Array = []          # StatusEffectData applied on hit
var threat_multiplier := 1.0
## Summed percent damage modifiers (+20 = 20% more). Filled by CombatSystem from
## status effects on attacker and target, and by any SignalBus.damage_modify
## listener (talents, set bonuses, scripted interactions).
var bonus_pct := 0.0
## Human-readable list of what modified this hit, e.g. ["Stormfire x3 +60%"] (log/debug).
var modifiers: Array[String] = []

static func make(src: Node, tgt: Node, dmg: int, id: String = "") -> RefCounted:
	var d = load("res://scripts/core/damage_info.gd").new()
	d.source = src
	d.target = tgt
	d.base = dmg
	d.ability_id = id
	return d

func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Add a percent modifier with a label (shows up in the combat log).
func add_bonus(pct: float, label: String = "") -> void:
	bonus_pct += pct
	if label != "":
		modifiers.append("%s %+d%%" % [label, int(round(pct))])
