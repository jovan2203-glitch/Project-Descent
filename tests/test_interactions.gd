@tool
extends McpTestSuite

# Interaction system tests: percent damage modifiers, status-effect damage
# modifiers (outgoing / incoming / consume-on-use) and the Rune of Stormfire.

const CombatSystem = preload("res://scripts/core/combat_system.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Runes = preload("res://scripts/runes.gd")
const CK = preload("res://scripts/core/combat_keys.gd")

func suite_name() -> String:
	return "interactions"

const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const FX_PROPS := ["id", "display_name", "duration", "stack_mode", "max_stacks", "damage_mod_pct",
	"modifies_incoming", "mod_damage_types", "mod_required_tags", "mod_affects_dots", "consume_on_use",
	"mod_crit_only", "mod_scale_stat", "mod_scale_factor", "stat_modifiers"]
const Stats = preload("res://scripts/core/stats.gd")

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

# In the editor, resources loaded from .tres get placeholder scripts (no
# methods), so tests run on a real instance with the same data.
func _fx(id: String) -> Resource:
	var src := Effects.get_effect(id)
	var r: Resource = StatusEffectScript.new()
	for p in FX_PROPS:
		r.set(p, src.get(p))
	return r

func _hit(type: String, tags: Array, dot := false) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	info.is_dot = dot
	return info

# --- Damage maths ---------------------------------------------------------------------

func test_multiplier_scales_before_crit() -> void:
	# 5 x 2.0 = 10, crit doubles -> 20
	assert_eq(CombatSystem.compute_damage(5, 0, 100.0, 0.0, 0.0, 0.0, 99.0, true, true, 2.0)["amount"], 20)

func test_multiplier_rounding_roll() -> void:
	# 2 x 1.2 = 2.4: roll 0.5 -> 2, roll 0.7 -> 3
	assert_eq(CombatSystem.compute_damage(2, 0, 0.0, 0.0, 0.0, 99.0, 99.0, false, false, 1.2, 0.5)["amount"], 2)
	assert_eq(CombatSystem.compute_damage(2, 0, 0.0, 0.0, 0.0, 99.0, 99.0, false, false, 1.2, 0.7)["amount"], 3)

func test_multiplier_never_negative() -> void:
	assert_eq(CombatSystem.compute_damage(4, 0, 0.0, 0.0, 0.0, 99.0, 99.0, false, false, -1.0)["amount"], 0)

# --- Stormfire ----------------------------------------------------------------------------

func test_stormfire_data_loads() -> void:
	var fx := Effects.get_effect("stormfire")
	assert_true(fx != null, "effect registered by file name")
	assert_eq(int(fx.max_stacks), 5)
	assert_eq(float(fx.duration), 10.0)
	var rune := Runes.get_resource("stormfire")
	assert_true(rune != null and rune.status_effect == fx, "rune applies the Stormfire effect")
	assert_eq(Array(rune.required_damage_types), [CK.LIGHTNING])
	assert_true(bool(rune.include_procs) and bool(rune.include_dots), "every source of lightning damage counts")
	assert_eq(Array(fx.mod_damage_types), [CK.FIRE])
	assert_true(bool(fx.consume_on_use))

func test_stormfire_stacks_to_five() -> void:
	var st := _status()
	var fx := _fx("stormfire")
	for i in 7:
		st.apply(fx)
	assert_eq(st.stacks_of("stormfire"), 5)

func test_stormfire_boosts_fire_spell_per_stack() -> void:
	var st := _status()
	var fx := _fx("stormfire")
	for i in 3:
		st.apply(fx)
	var info := _hit(CK.FIRE, [CK.TAG_FIRE, CK.TAG_SPELL])
	st.collect_damage_mods(info, false)
	assert_eq(info.bonus_pct, 60.0)

func test_stormfire_ignores_other_hits() -> void:
	var st := _status()
	st.apply(_fx("stormfire"))
	for info in [_hit(CK.LIGHTNING, [CK.TAG_LIGHTNING, CK.TAG_SPELL]),
			_hit(CK.FIRE, [CK.TAG_FIRE, CK.TAG_MELEE]),
			_hit(CK.FIRE, [], true)]:
		st.collect_damage_mods(info, false)
		assert_eq(info.bonus_pct, 0.0)
		st.collect_damage_mods(info, true)   # not an incoming modifier either
		assert_eq(info.bonus_pct, 0.0)
	assert_eq(st.stacks_of("stormfire"), 1, "not consumed by non-matching hits")

func test_stormfire_consumed_once_for_whole_aoe() -> void:
	var st := _status()
	var fx := _fx("stormfire")
	st.apply(fx)
	st.apply(fx)
	# Three enemies hit by one Flame Nova in the same frame all get +40%.
	for i in 3:
		var info := _hit(CK.FIRE, [CK.TAG_FIRE, CK.TAG_SPELL, CK.TAG_AOE])
		st.collect_damage_mods(info, false)
		assert_eq(info.bonus_pct, 40.0)
	st._flush_consumed()
	assert_false(st.has("stormfire"), "used up after the cast")

func test_restack_after_consume_starts_fresh() -> void:
	var st := _status()
	var fx := _fx("stormfire")
	for i in 4:
		st.apply(fx)
	st.collect_damage_mods(_hit(CK.FIRE, [CK.TAG_SPELL]), false)
	st.apply(fx)   # lightning lands in the same frame after the fire spell
	st._flush_consumed()
	assert_eq(st.stacks_of("stormfire"), 1)

func test_power_bonus_is_fractional_and_rounded() -> void:
	# 1 base + 0.6 power, normal rounding -> 2
	assert_eq(CombatSystem.compute_damage(1, 0.6, 0.0, 0.0, 0.0, 99.0, 99.0, false, false)["amount"], 2)

# --- Stats ---------------------------------------------------------------------------------

func _near(a: float, b: float, tol: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= tol, "%s (got %s, expected %s)" % [msg, a, b])

func _raw(d: Dictionary) -> Callable:
	return func(k): return float(d.get(k, 0.0))

func test_primary_stats_convert() -> void:
	var raw := _raw({"intellect": 10.0, "agility": 10.0, "strength": 4.0, "constitution": 3.0})
	assert_eq(Stats.resolve(Stats.MAX_MANA, raw), 20.0, "10 base + 10 from intellect")
	assert_eq(Stats.resolve(Stats.SPELL_CRIT, raw), 5.0, "0.5% per intellect")
	assert_eq(Stats.resolve(Stats.SPELL_POWER, raw), 0.0, "intellect gives no spell power")
	assert_eq(Stats.resolve(Stats.ATTACK_POWER, raw), 9.0, "4 from strength + 5 from agility")
	assert_eq(Stats.resolve(Stats.CRIT, raw), 10.0, "5 base + 5 from agility")
	assert_eq(Stats.resolve(Stats.MAX_HEALTH, raw), 13.0, "10 base + 3 from constitution")
	var stat_of := func(s): return Stats.resolve(s, raw)
	_near(Stats.crit_chance(PackedStringArray(["Spell"]), stat_of), 15.0, 0.001, "spells add spell crit")
	_near(Stats.crit_chance(PackedStringArray(["Ability"]), stat_of), 10.0, 0.001, "abilities don't")

func test_percent_stat_modifier() -> void:
	var raw := _raw({"intellect": 10.0, "intellect%": 10.0})
	assert_eq(Stats.resolve(Stats.INTELLECT, raw), 11.0)
	assert_eq(Stats.resolve(Stats.MAX_MANA, raw), 21.0, "mana follows the boosted intellect")

func test_legacy_damage_counts_as_both_powers() -> void:
	var raw := _raw({"damage": 2.0})
	assert_eq(Stats.resolve(Stats.SPELL_POWER, raw), 2.0)
	assert_eq(Stats.resolve(Stats.ATTACK_POWER, raw), 2.0)

func test_spell_and_ability_power_split() -> void:
	var stat_of := func(s): return 10.0 if s == Stats.SPELL_POWER else 0.0
	_near(Stats.power_bonus(PackedStringArray(["Fire", "Spell"]), stat_of), 6.0, 0.001)
	_near(Stats.power_bonus(PackedStringArray(["Fire", "Ability", "Melee"]), stat_of), 2.0, 0.001)
	_near(Stats.power_bonus(PackedStringArray(["AutoAttack"]), stat_of), 2.0, 0.001)
	assert_eq(Stats.power_bonus(PackedStringArray(["Melee"]), stat_of), 0.0, "enemy attacks get no power")

func test_haste_multiplier() -> void:
	_near(Stats.haste_mult(25.0), 1.25, 0.001)

func test_every_player_ability_is_spell_or_ability() -> void:
	const Abilities = preload("res://scripts/abilities.gd")
	for id in Abilities.ALL:
		if Abilities.is_trinket_slot(id):
			continue   # item buttons (Use Trinket 1/2), not spells or abilities
		var tags: PackedStringArray = Abilities.tags_of(id)
		assert_true(tags.has("Spell") != tags.has("Ability"), "%s is exactly one of Spell / Ability" % id)
	assert_true(Abilities.tags_of("searingstrike").has("Ability"), "Searing Strike is an ability")
	assert_true(Abilities.tags_of("fireball").has("Spell"))

# --- Rune rarity & limits --------------------------------------------------------------------

func test_rune_rarities() -> void:
	assert_eq(Runes.rarity("smoldering_focus"), Runes.LEGENDARY)
	assert_eq(Runes.rarity("stormfire"), Runes.EPIC)
	assert_eq(Runes.rarity("frostbound_insight"), Runes.RARE)
	assert_eq(Runes.rarity("fury"), Runes.COMMON)

func test_rune_limits() -> void:
	assert_eq(Runes.check_limits(["fury", "fury", "fury", "frost", "", "stormfire", "smoldering_focus"]), "")
	assert_ne(Runes.check_limits(["fury", "fury", "fury", "fury"]), "", "max 3 of a common")
	assert_ne(Runes.check_limits(["stormfire", "stormfire"]), "", "epics don't stack")
	assert_ne(Runes.check_limits(["smoldering_focus", "smoldering_focus"]), "", "1 legendary")
	assert_ne(Runes.check_limits(["frostbound_insight", "frostbound_insight"]), "", "unique rare")

func test_equip_refused_over_rune_limit() -> void:
	const ItemDB = preload("res://scripts/core/item_db.gd")
	var saved := ItemDB.records.duplicate(true)
	var pd: Node = track(preload("res://scripts/player_data.gd").new())
	pd._ready()
	pd.equipment["Head"] = ItemDB.create("helmet", "stormfire")
	pd.inventory[0] = ItemDB.create("chestplate", "stormfire")
	assert_ne(pd.equip_from_inventory(0), "", "second Stormfire refused")
	assert_true(pd.inventory[0] != "", "item stays in the bag")
	pd.inventory[1] = ItemDB.create("chestplate", "fury")
	assert_eq(pd.equip_from_inventory(1), "")
	ItemDB.records = saved

func test_smoldering_focus_only_boosts_fire_spell_crits() -> void:
	var st := _status()
	var carrier_script := GDScript.new()
	carrier_script.source_code = "@tool\nextends Node\nfunc get_stat(n: String) -> float:\n\treturn 20.0 if n == 'crit_chance' else 0.0\n"
	carrier_script.reload()
	st.get_parent().set_script(carrier_script)
	var fx := _fx("smoldering_focus")
	for i in 3:
		st.apply(fx)
	var normal := _hit(CK.FIRE, [CK.TAG_SPELL])
	st.collect_damage_mods(normal, false)
	assert_eq(normal.bonus_pct, 0.0, "non-crit gets nothing")
	var crit := _hit(CK.FIRE, [CK.TAG_SPELL])
	crit.crit = true
	st.collect_damage_mods(crit, false)
	_near(crit.bonus_pct, 36.0, 0.001, "3 stacks x (20% crit x 0.6)")
	var ability_crit := _hit(CK.FIRE, [CK.TAG_ABILITY])
	ability_crit.crit = true
	st.collect_damage_mods(ability_crit, false)
	assert_eq(ability_crit.bonus_pct, 0.0, "fire abilities aren't fire spells")

func test_incoming_modifier_on_target() -> void:
	var st := _status()
	var vuln: Resource = preload("res://scripts/data/status_effect_data.gd").new()
	vuln.id = &"test_scorched"
	vuln.display_name = "Scorched"
	vuln.damage_mod_pct = 10.0
	vuln.modifies_incoming = true
	vuln.mod_damage_types = PackedStringArray([CK.FIRE])
	st.apply(vuln)
	var info := _hit(CK.FIRE, [])
	st.collect_damage_mods(info, true)
	assert_eq(info.bonus_pct, 10.0)
	var info2 := _hit(CK.FIRE, [])
	st.collect_damage_mods(info2, false)
	assert_eq(info2.bonus_pct, 0.0, "incoming debuff doesn't boost the carrier's own hits")
