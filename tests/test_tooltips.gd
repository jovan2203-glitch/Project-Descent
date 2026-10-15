@tool
extends McpTestSuite

# Tooltips can't go stale: no description carries a typed number. Abilities,
# status effects, talents, runes and item effects hold placeholders that are
# filled from their own data and from balance.gd (scripts/core/text_fill.gd),
# and ability tooltips show what your talents change.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Talents = preload("res://scripts/talents.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## The one typed number a text may keep: the 100 of a percentage formula.
const ALLOWED := ["(100 - critical strike chance)"]

func suite_name() -> String:
	return "tooltips"

## "" if `raw` (a description before it is filled) has no typed number, else the number found.
func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	for phrase in ALLOWED:
		text = text.replace(phrase, "")
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func test_number_formatting() -> void:
	assert_eq(TextFill.num(2.0), "2")
	assert_eq(TextFill.num(0.5), "0.5")
	assert_eq(TextFill.num(0.25), "0.25")
	assert_eq(TextFill.num(100.0), "100")
	assert_eq(TextFill.ordinal(1), "1st")
	assert_eq(TextFill.ordinal(2), "2nd")
	assert_eq(TextFill.ordinal(3), "3rd")
	assert_eq(TextFill.ordinal(6), "6th")
	assert_eq(TextFill.ordinal(12), "12th")
	assert_eq(TextFill.ordinal(22), "22nd")
	assert_eq(TextFill.every(1.0), "every second")
	assert_eq(TextFill.every(0.5), "every 0.5 sec")

func test_balance_placeholders() -> void:
	assert_eq(TextFill.constants("{b:AOE_TARGET_CAP} enemies"), "%d enemies" % Balance.AOE_TARGET_CAP)
	assert_eq(TextFill.constants("{b%:VENT_FLAMES_CRIT_DAMAGE}%"), "%s%%" % TextFill.num(Balance.VENT_FLAMES_CRIT_DAMAGE * 100.0))
	assert_eq(TextFill.constants("{b2:CLINKER_RADIUS} m"), "%s m" % TextFill.num(Balance.CLINKER_RADIUS * 2.0))
	assert_eq(TextFill.constants("{bth:COLD_PRECISION_EVERY}"), TextFill.ordinal(Balance.COLD_PRECISION_EVERY))
	assert_eq(TextFill.constants("{bev:CLINKER_TICK}"), TextFill.every(Balance.CLINKER_TICK))
	assert_eq(TextFill.constants("{e:frozen.time} sec"), "%s sec" % TextFill.num(float(Balance.EFFECTS["res://data/effects/frozen.tres"]["duration"])))
	assert_eq(TextFill.constants("{e:frozen.slow}%"), "80%")
	assert_eq(TextFill.constants("{a:rimeshell.radius} m"), "%s m" % TextFill.num(float(Balance.ABILITIES["rimeshell"]["radius"])))
	assert_eq(TextFill.constants("{b:NO_SUCH_CONSTANT}"), "?", "an unknown name shows, it does not vanish")
	assert_eq(TextFill.constants("plain text"), "plain text")
	# Names: a rename changes every text that mentions the ability or effect.
	assert_eq(TextFill.constants("{n:frostbolt}"), Abilities.ability_name("frostbolt"))
	assert_eq(TextFill.constants("{ne:frozen}"), str(Effects.get_effect("frozen").display_name))

func test_no_ability_description_has_a_typed_number() -> void:
	for id in Abilities.PATHS:
		if Abilities.is_trinket_slot(id):
			continue   # ("Trinket 1" is a slot's name)
		var r := Abilities.get_resource(id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: every placeholder has a value: %s" % [id, tip])
		assert_false(tip.contains("Frost Bolts"), "%s: real damage numbers, never a count of Frost Bolts" % id)

func test_no_effect_description_has_a_typed_number() -> void:
	for id in Effects.all_ids():
		var fx := Effects.get_effect(id)
		assert_eq(_typed_number(str(fx.description)), "", "%s: number typed into its description" % id)
		var text := TextFill.effect(fx)
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % id)
		assert_false(text.contains("?"), "%s: %s" % [id, text])

func test_no_rune_or_item_effect_has_a_typed_number() -> void:
	for id in Runes.PATHS:
		var r := Runes.get_resource(id)
		assert_eq(_typed_number(str(r.description)), "", "rune %s: number typed into its description" % id)
		var text := Runes.description(id)
		assert_eq(TextFill.leftover(text), "", "rune %s: every placeholder is filled" % id)
		assert_false(text.contains("?"), "rune %s: %s" % [id, text])
		assert_false(text.contains("Frost Bolts") or text.contains("Frost Bolt's"), "rune %s: real numbers" % id)
	var checked := 0
	for item in Items.ALL:
		for fx in [Items.equip_effect_of(item), Items.use_effect_of(item)]:
			if fx == null:
				continue
			checked += 1
			assert_eq(_typed_number(str(fx.description)), "", "%s: number typed into its effect" % item)
			var text := Items.effect_text(item, fx)
			assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % item)
			assert_false(text.contains("?"), "%s: %s" % [item, text])
	assert_true(checked >= 8, "the trinkets' effects were checked")

func test_no_talent_description_has_a_typed_number() -> void:
	var checked := 0
	for cat in Talents.TALENTS:
		for id in Talents.in_tree(cat):
			var t := Talents.get_talent(id)
			if bool(t.get("placeholder", true)):
				continue
			checked += 1
			for raw in [str(t.get("desc", "")), str(t.get("capstone", ""))]:
				assert_eq(_typed_number(raw), "", "%s: number typed into its text" % t["name"])
			for text in [Talents.description(id), Talents.capstone_text(id), Talents.tooltip(id, 1)]:
				assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % t["name"])
				assert_false(text.contains("?"), "%s: %s" % [t["name"], text])
				assert_false(text.contains("Frost Bolts"), "%s: real damage numbers, never a count of Frost Bolts" % t["name"])
	assert_true(checked >= 50)

## The game must not reuse another game's ability names: these were replaced
## and must not come back, in a name or in any text the player reads.
const RETIRED_NAMES := ["Blizzard", "Frost Nova", "Ice Barrier", "Frost Strike", "Weakened Soul", "Arcane Missiles",
	"Arcane Explosion", "Arcane Shot", "Blink", "Counterspell", "Chain Lightning", "Shadow Bolt", "Corruption",
	"Shadow Strike", "Wrath", "Insect Swarm", "Entangling Roots", "Regrowth", "Holy Light", "Smite", "Crusader Strike",
	"Execute", "Whirlwind", "Battle Shout", "Second Wind", "Pummel", "Sinister Strike", "Rupture", "Fan of Knives",
	"Eviscerate", "Steady Shot", "Multi-Shot", "Immolate"]

func test_retired_names_are_gone() -> void:
	var seen := {}
	var texts: Array[String] = []
	for id in Abilities.PATHS:
		var n := Abilities.ability_name(id)
		assert_false(seen.has(n), "two abilities are called %s" % n)
		seen[n] = true
		assert_false(RETIRED_NAMES.has(n) or n == "Slam", "%s still has its old name %s" % [id, n])
		texts.append(Abilities.tooltip(id))
	for id in Effects.all_ids():
		assert_false(RETIRED_NAMES.has(str(Effects.get_effect(id).display_name)), "effect %s still has its old name" % id)
		texts.append(TextFill.effect(Effects.get_effect(id)))
	for id in Runes.PATHS:
		texts.append(Runes.description(id))
	for cat in Talents.TALENTS:
		for id in Talents.in_tree(cat):
			texts.append(Talents.tooltip(id, 1))
	for text in texts:
		for old in RETIRED_NAMES:
			assert_false(RegEx.create_from_string("\\b%s\\b" % old).search(text) != null, "\"%s\" is still in: %s" % [old, text.left(120)])
	assert_eq(Abilities.ability_name("blizzard"), "Whiteout")
	assert_eq(Abilities.ability_name("immolate"), "Blaze")
	assert_eq(str(Effects.get_effect("immolate").display_name), "Blaze")
	assert_eq(str(Effects.get_effect("weakened_soul").display_name), "Frostworn")
	assert_eq(Abilities.ability_name("slam"), "Heavy Blow")

func test_talent_texts_follow_their_values() -> void:
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("frost_bolt_cast"), "0.1 / 0.2 / 0.3 sec")
	assert_contains(d.call("fire_forge_heat"), "0.5 / 1 / 1.5 / 2 sec")
	assert_contains(d.call("frost_discipline"), "2 / 3 / 4%")
	assert_contains(d.call("frost_discipline"), "5 / 10 / 15%")
	# A value added to a base from balance.gd.
	assert_contains(d.call("fire_stoked_kiln"), "%s / %s%%" % [TextFill.num(Balance.KILN_BLAST_IMMOLATE_PCT + 10.0), TextFill.num(Balance.KILN_BLAST_IMMOLATE_PCT + 20.0)])
	assert_contains(d.call("fire_stoked_kiln"), "instead of %s%%" % TextFill.num(Balance.KILN_BLAST_IMMOLATE_PCT))
	assert_contains(d.call("fire_deep_brand"), "%s / %s%%" % [TextFill.num(Balance.BRAND_PCT + 3.0), TextFill.num(Balance.BRAND_PCT + 6.0)])
	assert_contains(d.call("frost_piercing_cold"), "%s / %s%%" % [TextFill.num(Balance.COLDSPIKE_FROZEN_PCT + 10.0), TextFill.num(Balance.COLDSPIKE_FROZEN_PCT + 20.0)])
	# Damage is shown as real numbers: Honed Rime's three ranks and what it replaces.
	var tags := Abilities.tags_of("rimeedge")
	var base := float(Abilities.get_resource("rimeedge").damage)
	var honed := Talents.id_for_key("frost_honed_rime")
	var want: Array[String] = []
	for rank in 3:
		want.append(Abilities.fmt_amount(Abilities.coef_damage(base + Talents.value_at(honed, rank + 1), tags)))
	assert_contains(Talents.description(honed), " / ".join(want))
	assert_contains(Talents.description(honed), "instead of %s" % Abilities.fmt_amount(Abilities.coef_damage(base, tags)))
	# Names come from the abilities, so a rename reaches the talents.
	assert_contains(d.call("frost_bolt_cast"), Abilities.ability_name("frostbolt"))
	assert_contains(Talents.capstone_text(Talents.id_for_key("frost_deep_freeze")), TextFill.ordinal(Balance.DEEP_FREEZE_BLIZZARD_EVERY))

## The Shift tooltip explains Spell / Attack Power scaling only for abilities
## that have a number to scale. Pure utility shows no Scaling section.
func test_only_abilities_with_numbers_show_scaling() -> void:
	for id in ["groundingsurge", "blink", "taunt", "coolhead", "counterspell", "rimelock", "deepwinter",
			"winterhide", "icebarrier", "battleshout", "crucible", "flashfreeze", "rekindle"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)
		assert_false(Abilities.tooltip_bbcode(id, true).contains("Scaling"), "%s: no Scaling section" % id)
	for id in ["frostbolt", "slam", "heal", "immolate", "hoarfrost", "snowward", "sacredbulwark", "cinderwing",
			"discharge", "groundout", "balllightning", "chainlightning", "heatsink", "kick"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)
		assert_contains(Abilities.tooltip_bbcode(id, true), "Scaling", "%s: keeps its Scaling section" % id)

func test_ability_texts_follow_the_data() -> void:
	var tip := func(id: String) -> String: return Abilities.tooltip(id)
	var nova := Abilities.get_resource("frostnova")
	assert_contains(tip.call("frostnova"), "within %s m" % TextFill.num(float(nova.radius)))
	assert_contains(tip.call("frostnova"), "80%% slower for %s sec" % TextFill.num(float(nova.on_hit_effect.duration)))
	assert_contains(tip.call("blizzard"), "%s m wide" % TextFill.num(float(Abilities.get_resource("blizzard").radius) * 2.0))
	assert_contains(tip.call("blizzard"), "for %s sec" % TextFill.num(Balance.BLIZZARD_TIME))
	assert_contains(tip.call("kilnblast"), "%s%% more" % TextFill.num(Balance.KILN_BLAST_IMMOLATE_PCT))
	assert_contains(tip.call("kick"), "for %s sec" % TextFill.num(float(Balance.INTERRUPT_LOCKOUT["kick"])))
	assert_contains(tip.call("brand"), "%s%% less damage" % TextFill.num(Balance.BRAND_PCT))
	assert_contains(tip.call("stoneguard"), "5x threat")
	assert_contains(tip.call("chainlightning"), "up to %d more enemies" % Balance.LEAPING_ARC_JUMPS)
	assert_contains(tip.call("multishot"), "up to %d enemies" % Balance.MULTISHOT_TARGETS)
	assert_contains(tip.call("arcanemissiles"), "%d sigil darts" % Balance.ARCANE_MISSILES_COUNT)
	assert_contains(tip.call("rimeshell"), "for %s sec" % TextFill.num(float(Balance.EFFECTS["res://data/effects/rime_shell.tres"]["duration"])))
	assert_contains(tip.call("lightningbolt"), "Lightning damage")
	assert_eq(str(Abilities.get_resource("lightningbolt").damage_type), "lightning", "Lightning Bolt is Lightning like the rest of its book")

## What a talent changes shows in the ability's tooltip, and the game uses the
## same maths (Abilities.effect_time_bonus / radius_bonus / base_cast_time).
func test_talent_maths_shared_with_the_game() -> void:
	var ranks := {"fire_long_burn": 3.0, "fire_thick_pitch": 4.0, "frost_hoarfrost": 4.0, "frost_dot_duration": 2.0}
	var talent_of := func(key: String, field: String) -> float:
		if key == "frost_hoarfrost":
			return float(ranks[key]) if field == "values2" else 25.0
		return float(ranks.get(key, 0.0))
	var none := func(_key: String, _field: String) -> float: return 0.0
	var immolate: Resource = Effects.get_effect("immolate")
	var hoarfrost: Resource = Effects.get_effect("hoarfrost")
	var pitched: Resource = Effects.get_effect("pitched")
	var chilled: Resource = Effects.get_effect("chilled")
	assert_eq(Abilities.effect_time_bonus(immolate, talent_of), 3.0, "Long Burn")
	assert_eq(Abilities.effect_time_bonus(pitched, talent_of), 4.0, "Thick Pitch")
	assert_eq(Abilities.effect_time_bonus(hoarfrost, talent_of), 6.0, "Deep Hoarfrost's seconds + Lingering Frost (a Frost damage over time effect)")
	assert_eq(Abilities.effect_time_bonus(chilled, talent_of), 0.0, "not a damage over time effect")
	assert_eq(Abilities.effect_time_bonus(immolate, none), 0.0)
	assert_eq(Abilities.effect_time_bonus(null, talent_of), 0.0)
	# Without talents (the editor has no character) the bonuses are zero.
	assert_eq(Abilities.radius_bonus("blizzard"), 0.0)
	assert_eq(Abilities.radius_bonus("frostnova"), 0.0, "no talent widens it")
	assert_eq(float(Abilities.RADIUS_TALENTS["crucible"][1]), 0.5, "Deep Crucible gives width: half of it is radius")
	assert_eq(Abilities.base_cast_time(Abilities.get_resource("frostbolt")), float(Abilities.get_resource("frostbolt").cast_time))
	assert_true(Abilities.SHIELD_ABILITIES.has("rimeslash"), "Rime Ward counts for Rime Slash's shell too")
