@tool
extends McpTestSuite

# The Arcane caster's first talents: Seventh Sigil, Etched Darts, Frayed, Chain
# Reaction, Polished Glass, Deep Well, Aftershock and Long Step.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")

# [key, name, ranks, the ability it needs, slot]
const TALENTS := [
	["arcane_seventh_sigil", "Seventh Sigil", 2, "arcanemissiles", "arcane_r1c3"],
	["arcane_long_step", "Long Step", 2, "", "arcane_r1c4"],
	["arcane_frayed", "Frayed", 2, "unravel", "arcane_r1c5"],
	["arcane_etched_darts", "Etched Darts", 3, "arcanemissiles", "arcane_r2c2"],
	["arcane_chain_reaction", "Chain Reaction", 3, "countdown", "arcane_r2c6"],
	["arcane_polished_glass", "Polished Glass", 3, "mirrorsigil", "arcane_r3c3"],
	["arcane_deep_well", "Deep Well", 2, "collapse", "arcane_r3c5"],
	["arcane_aftershock", "Aftershock", 2, "collapse", "arcane_r4c4"],
]

func suite_name() -> String:
	return "arcane_talents"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _id(key: String) -> String:
	return Talents.id_for_key(key)

func test_they_are_in_the_tree() -> void:
	for row in TALENTS:
		var id := _id(str(row[0]))
		assert_eq(id, str(row[4]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[2]))
		assert_eq(Talents.required_ability(id), str(row[3]))
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		var text := Talents.description(id)
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % row[1])
		assert_false(text.contains("?"), "%s: %s" % [row[1], text])

func test_links() -> void:
	assert_true(Talents.targets_of(_id("arcane_seventh_sigil")).has(_id("arcane_etched_darts")), "Sigil Darts' two are joined")
	assert_true(Talents.targets_of(_id("arcane_deep_well")).has(_id("arcane_aftershock")), "so are Collapse's")
	# The more important one of each pair is the higher one.
	assert_true(Talents.tier_of(_id("arcane_seventh_sigil")) < Talents.tier_of(_id("arcane_etched_darts")))
	assert_true(Talents.tier_of(_id("arcane_deep_well")) < Talents.tier_of(_id("arcane_aftershock")))

func test_seventh_sigil() -> void:
	var id := _id("arcane_seventh_sigil")
	assert_eq(Talents.value_at(id, 1), 1.0)
	assert_eq(Talents.value_at(id, 2), 2.0)
	var p := _player()
	assert_eq(p.dart_count(0.0), 6)
	assert_eq(p.dart_count(1.0), 7)
	assert_eq(p.dart_count(2.0), 8, "two more darts in the same channel")
	assert_false(str(Abilities.get_resource("arcanemissiles").description).contains("ARCANE_MISSILES_COUNT"),
		"Sigil Darts' tooltip counts the darts with the talent")
	assert_eq(TextFill.leftover(Abilities.tooltip("arcanemissiles")), "")

func test_etched_darts_and_frayed() -> void:
	var etched := _id("arcane_etched_darts")
	assert_eq(Talents.value_at(etched, 1), 10.0)
	assert_eq(Talents.value_at(etched, 3), 30.0)
	assert_eq(Balance.ETCHED_DARTS_SECONDS, 0.5)
	var frayed := _id("arcane_frayed")
	assert_eq(Talents.value_at(frayed, 1), 50.0)
	assert_eq(Talents.value_at(frayed, 2), 100.0, "at max rank every Unravel crit takes its time off twice")

func test_chain_reaction() -> void:
	var id := _id("arcane_chain_reaction")
	assert_eq(Talents.value_at(id, 1), 10.0)
	assert_eq(Talents.value_at(id, 3), 30.0)
	assert_eq(Balance.CHAIN_REACTION_RADIUS, 5.0)
	var p := _player()
	assert_eq(p.chain_reaction_damage(1000, 30.0, 2), 300, "30% of what Countdown counted, to each enemy")
	assert_eq(p.chain_reaction_damage(1000, 30.0, 0), 0)
	assert_eq(p.chain_reaction_damage(0, 30.0, 3), 0)
	var crowd := Balance.AOE_TARGET_CAP * 2
	assert_eq(p.chain_reaction_damage(1000, 30.0, crowd), int(round(300.0 * Balance.aoe_share(crowd))), "a crowd shares it")
	assert_eq(Details.spell_name("chain_reaction"), "Chain Reaction", "its own line on the meter")

func test_polished_glass() -> void:
	var id := _id("arcane_polished_glass")
	var p := _player()
	assert_eq(p.mirror_pct(Talents.value_at(id, 1), false), 38.0)
	assert_eq(p.mirror_pct(Talents.value_at(id, 2), false), 41.0)
	assert_eq(p.mirror_pct(Talents.value_at(id, 3), false), 45.0)
	assert_contains(Talents.description(id), "38 / 41 / 45")

func test_deep_well_and_aftershock() -> void:
	var well := _id("arcane_deep_well")
	assert_eq(Balance.COLLAPSE_PULL + Talents.value_at(well, 1), 4.0)
	assert_eq(Balance.COLLAPSE_PULL + Talents.value_at(well, 2), 5.0)
	assert_contains(Talents.description(well), "4 / 5")
	var p := _player()
	var pulled: Vector3 = p.collapse_point(Vector3(6, 0, 0), Vector3.ZERO, 5.0, Balance.COLLAPSE_CORE)
	assert_true(pulled.is_equal_approx(Vector3(1, 0, 0)), "5 m toward the centre")
	var shock := _id("arcane_aftershock")
	assert_eq(Talents.value_at(shock, 1), 20.0)
	assert_eq(Talents.value_at(shock, 2), 40.0)
	assert_eq(Balance.AFTERSHOCK_TIME, 3.0)
	var fx: Resource = Effects.get_effect("aftershock")
	assert_true(fx != null and bool(fx.is_debuff))
	assert_eq(float(fx.duration), 3.0)
	assert_eq(float(fx.stat_modifiers.get("move_speed", 0.0)), -20.0, "the effect is rank 1's slow")
	assert_eq(p.aftershock_mult(20.0), 1.0)
	assert_eq(p.aftershock_mult(40.0), 2.0, "rank 2 doubles it: 40%")
	assert_eq(p.aftershock_mult(0.0), 0.0)

func test_long_step() -> void:
	var id := _id("arcane_long_step")
	assert_eq(Talents.value_at(id, 1), 1.0)
	assert_eq(Talents.value_at(id, 2), 2.0)
	var text := Talents.description(id)
	assert_contains(text, Abilities.ability_name("blink"))
	assert_contains(text, Abilities.ability_name("flicker"))
	# Both tooltips quote the distance with the talent.
	for ability in ["blink", "flicker"]:
		var desc := str(Abilities.get_resource(ability).description)
		assert_false(desc.contains("_DISTANCE"), "%s quotes its distance with Long Step" % ability)
		assert_eq(TextFill.leftover(Abilities.tooltip(ability)), "")
