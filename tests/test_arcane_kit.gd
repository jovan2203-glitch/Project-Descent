@tool
extends McpTestSuite

# The Arcane caster's cooldown kit: Sigil Darts (the channelled filler), Unravel,
# Countdown, Convergence, Rewind, Lapse, Mirror Sigil, Collapse, Scatter and
# Interval Ward, and the Rune of the Afterimage.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Runes = preload("res://scripts/runes.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const ArcaneMark = preload("res://scripts/arcane_mark.gd")

const NEW := ["unravel", "countdown", "convergence", "rewind", "lapse", "mirrorsigil", "collapse", "scatter", "intervalward", "glint"]
var ARCANE := PackedStringArray(["Arcane", "Spell"])

func _has_method(path: String, method: String) -> bool:
	for m in PlayerSource.methods_of(load(path)):
		if str(m["name"]) == method:
			return true
	return false

func suite_name() -> String:
	return "arcane_kit"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_new_abilities_are_draftable_arcane_spells() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_eq(Abilities.category_of(id), "arcane")
		assert_true(r.tags.has("Arcane") and r.tags.has("Spell"), "%s is an Arcane spell" % id)
		assert_eq(Abilities.resource_of(id), "mana")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])

func test_sigil_darts_is_a_channelled_filler() -> void:
	var r := Abilities.get_resource("arcanemissiles")
	assert_eq(str(r.display_name), "Sigil Darts")
	assert_eq(int(r.cast_type), 2, "a channel")
	assert_eq(float(r.cast_time), 2.0)
	assert_eq(float(r.cooldown), 0.0, "no cooldown: it is the filler")
	assert_eq(int(r.resource_cost), 1)
	assert_true(bool(r.requires_target))
	assert_eq(Balance.ARCANE_MISSILES_COUNT, 6)
	assert_true(is_equal_approx(float(r.damage) * Balance.ARCANE_MISSILES_COUNT, 1.2), "six darts, 1.2 in all")
	var p := _player()
	assert_true(p.on_gcd("arcanemissiles"))
	assert_false(p.ENEMY_BOLTS.has("arcanemissiles"), "a channel, not a bolt")
	assert_eq(TextFill.leftover(Abilities.tooltip("arcanemissiles")), "")

func test_what_counts_as_an_arcane_spell() -> void:
	var p := _player()
	assert_true(ArcaneCasterKit.arcane_spell(ARCANE))
	assert_true(ArcaneCasterKit.arcane_spell(PackedStringArray(["Arcane", "Spell", "Movement"])), "Phase Step counts")
	assert_false(ArcaneCasterKit.arcane_spell(PackedStringArray(["Arcane", "Melee"])), "a weapon ability is not a spell")
	assert_false(ArcaneCasterKit.arcane_spell(PackedStringArray(["Fire", "Spell"])))
	assert_false(ArcaneCasterKit.arcane_spell(ARCANE, true), "interrupts keep their shared cooldown")
	assert_true(Balance.INTERRUPT_LOCKOUT.has("counterspell"))

func test_unravel() -> void:
	var r := Abilities.get_resource("unravel")
	assert_eq(int(r.cast_type), 1)
	assert_eq(float(r.cast_time), 2.0)
	assert_eq(float(r.cooldown), 0.0, "no cooldown")
	assert_eq(float(r.damage), 1.1)
	assert_eq(Balance.UNRAVEL_SECONDS, 1.0)
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("unravel"))
	assert_eq(ArcaneCasterKit.unravel_cooldown(12.0), 11.0, "1 s off")
	assert_eq(ArcaneCasterKit.unravel_cooldown(0.4), 0.0, "never below ready")

func test_countdown() -> void:
	var r := Abilities.get_resource("countdown")
	assert_eq(float(r.cast_time), 1.5)
	assert_eq(float(r.cooldown), 12.0)
	assert_eq(float(r.damage), 1.0)
	assert_eq(Balance.COUNTDOWN_TIME, 5.0)
	assert_eq(Balance.COUNTDOWN_SHARE_PCT, 25.0)
	var fx: Resource = Effects.get_effect("countdown")
	assert_true(fx != null, "the mark is a status effect the party can see")
	assert_true(bool(fx.is_debuff))
	assert_true(bool(fx.per_caster), "own only: every caster has their own mark")
	assert_eq(float(fx.tick_damage), 0.0)
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("countdown"))
	assert_eq(ArcaneCasterKit.countdown_bonus(1000, 25.0), 250, "25% of what it counted")
	assert_eq(ArcaneCasterKit.countdown_bonus(0, 25.0), 0)
	assert_eq(ArcaneCasterKit.countdown_bonus(-50, 25.0), 0)

func test_convergence() -> void:
	var r := Abilities.get_resource("convergence")
	assert_eq(float(r.cast_time), 2.5)
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(float(r.damage), 2.0)
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("convergence"))
	assert_eq(ArcaneCasterKit.convergence_bonus(0), 0.0)
	assert_eq(ArcaneCasterKit.convergence_bonus(2), 30.0, "15% each")
	assert_eq(ArcaneCasterKit.convergence_bonus(5), 75.0)
	assert_eq(ArcaneCasterKit.convergence_bonus(9), 75.0, "five count at most")
	assert_true(is_equal_approx(ArcaneCasterKit.convergence_coef(2.0, 5), 3.5))
	assert_true(is_equal_approx(ArcaneCasterKit.convergence_coef(2.0, 0), 2.0))

func test_rewind() -> void:
	var r := Abilities.get_resource("rewind")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 45.0)
	assert_eq(Balance.REWIND_MAX_COOLDOWN, 15.0)
	var p := _player()
	assert_false(p.on_gcd("rewind"), "off the global cooldown")
	assert_true(ArcaneCasterKit.rewind_allows(ARCANE, 12.0), "Countdown")
	assert_true(ArcaneCasterKit.rewind_allows(ARCANE, 14.9))
	assert_false(ArcaneCasterKit.rewind_allows(ARCANE, 15.0), "under 15 s only")
	assert_false(ArcaneCasterKit.rewind_allows(ARCANE, 20.0), "Convergence")
	assert_false(ArcaneCasterKit.rewind_allows(ARCANE, 0.0), "nothing to reset on a spell without a cooldown")
	assert_false(ArcaneCasterKit.rewind_allows(PackedStringArray(["Frost", "Spell"]), 8.0), "Arcane only")
	assert_false(ArcaneCasterKit.rewind_allows(ARCANE, 8.0, true), "not an interrupt")
	# The spells it can reset right now.
	for id in ["countdown", "collapse", "scatter", "blink", "arcaneexplosion"]:
		var res := Abilities.get_resource(id)
		assert_true(ArcaneCasterKit.rewind_allows(res.tags, Abilities.cooldown_of(res), Balance.INTERRUPT_LOCKOUT.has(id)), "%s can be rewound" % id)
	for id in ["convergence", "mirrorsigil", "lapse", "intervalward", "unravel", "arcanemissiles", "counterspell"]:
		var res := Abilities.get_resource(id)
		assert_false(ArcaneCasterKit.rewind_allows(res.tags, Abilities.cooldown_of(res), Balance.INTERRUPT_LOCKOUT.has(id)), "%s can't" % id)

func test_lapse_and_interval_ward_speed_up_arcane_cooldowns() -> void:
	var r := Abilities.get_resource("lapse")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 90.0)
	assert_eq(Balance.LAPSE_TIME, 8.0)
	var p := _player()
	assert_false(p.on_gcd("lapse"), "off the global cooldown")
	assert_eq(ArcaneCasterKit.arcane_recovery_rate(false, false), 1.0)
	assert_eq(ArcaneCasterKit.arcane_recovery_rate(true, false), 2.0, "twice as fast")
	assert_true(is_equal_approx(ArcaneCasterKit.arcane_recovery_rate(false, true), 1.15), "15% faster")
	assert_true(is_equal_approx(ArcaneCasterKit.arcane_recovery_rate(true, true), 2.15), "they add up")

func test_interval_ward() -> void:
	var r := Abilities.get_resource("intervalward")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(Balance.INTERVAL_WARD_TIME, 8.0)
	assert_eq(Balance.INTERVAL_WARD_RATE_PCT, 15.0)
	assert_eq(float(Abilities.HEALS["intervalward"]), 1.5)
	assert_true(Abilities.SHIELD_ABILITIES.has("intervalward"))
	var p := _player()
	assert_true(p.on_gcd("intervalward"))
	assert_eq(ArcaneCasterKit.ward_cooldown_after_break(18.0, 6.0), 12.0, "the time it had left comes off")
	assert_eq(ArcaneCasterKit.ward_cooldown_after_break(3.0, 6.0), 0.0)
	assert_eq(ArcaneCasterKit.ward_cooldown_after_break(18.0, -1.0), 18.0)

func test_scatter() -> void:
	var r := Abilities.get_resource("scatter")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 8.0)
	assert_eq(Balance.SCATTER_TARGETS, 3)
	assert_eq(Balance.SCATTER_PCT, 30.0)
	var p := _player()
	assert_false(p.on_gcd("scatter"))
	# Six darts over three enemies: two each, in turn.
	var got := [0, 0, 0]
	for i in Balance.ARCANE_MISSILES_COUNT:
		got[ArcaneCasterKit.dart_target(i, 3)] += 1
	assert_eq(got, [2, 2, 2])
	assert_eq(ArcaneCasterKit.dart_target(4, 2), 0)
	assert_eq(ArcaneCasterKit.dart_target(5, 1), 0, "one enemy takes them all")
	assert_eq(ArcaneCasterKit.dart_target(3, 0), 0)
	# What it adds has its own line on the damage meter.
	var rows: Array = Details.split_amount("arcanemissiles", 130, false, [[ArcaneCasterKit.SCATTER_LABEL, Balance.SCATTER_PCT]])
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0][1]), 100)
	assert_eq(str(rows[1][0]), Details.BONUS_PREFIX + "Scatter")
	assert_eq(int(rows[1][1]), 30)

func test_mirror_sigil() -> void:
	var r := Abilities.get_resource("mirrorsigil")
	assert_eq(float(r.cast_time), 1.5)
	assert_eq(float(r.cooldown), 30.0)
	assert_false(bool(r.requires_target))
	assert_eq(Balance.MIRROR_SIGIL_TIME, 12.0)
	assert_eq(Balance.MIRROR_SIGIL_PCT, 35.0)
	var p := _player()
	assert_eq(ArcaneCasterKit.echo_amount(1000, 35.0), 350)
	assert_eq(ArcaneCasterKit.echo_amount(0, 35.0), 0)
	assert_true(ArcaneCasterKit.mirror_echoes(ARCANE, false, "unravel"))
	assert_true(ArcaneCasterKit.mirror_echoes(PackedStringArray(["Arcane", "Spell", "AoE"]), false, "collapse"))
	assert_true(ArcaneCasterKit.mirror_echoes(ARCANE, true, "countdown"), "Countdown going off is its spell")
	assert_false(ArcaneCasterKit.mirror_echoes(ARCANE, true, "unravel"), "not procs")
	assert_false(ArcaneCasterKit.mirror_echoes(ARCANE, true, "mirrorsigil"), "never its own echo")
	assert_false(ArcaneCasterKit.mirror_echoes(ARCANE, true, "afterimage"), "nor the image's")
	assert_false(ArcaneCasterKit.mirror_echoes(PackedStringArray(["Frost", "Spell"]), false, "frostbolt"), "Arcane only")
	assert_false(ArcaneCasterKit.mirror_echoes(PackedStringArray(["Arcane", "Melee"]), false, "arcanestrike"), "spells only")
	assert_eq(Details.spell_name("mirrorsigil"), "Mirror Sigil", "its own line on the meter")

func test_collapse() -> void:
	var r := Abilities.get_resource("collapse")
	assert_eq(int(r.cast_type), 3, "ground-targeted")
	assert_eq(float(r.cast_time), 2.0)
	assert_eq(float(r.cooldown), 10.0)
	assert_eq(float(r.damage), 1.4)
	assert_eq(float(r.radius), 6.0)
	assert_eq(Balance.COLLAPSE_DELAY, 1.5)
	assert_eq(Balance.COLLAPSE_PULL, 3.0)
	var p := _player()
	var c := Vector3(0, 0, 0)
	var far: Vector3 = ArcaneCasterKit.collapse_point(Vector3(6, 2, 0), c, 3.0, 0.6)
	assert_true(far.is_equal_approx(Vector3(3, 2, 0)), "3 m toward the centre, height kept")
	var near: Vector3 = ArcaneCasterKit.collapse_point(Vector3(0, 0, 2), c, 3.0, 0.6)
	assert_true(near.is_equal_approx(Vector3(0, 0, 0.6)), "never closer than the core")
	var inside: Vector3 = ArcaneCasterKit.collapse_point(Vector3(0.3, 0, 0), c, 3.0, 0.6)
	assert_true(inside.is_equal_approx(Vector3(0.3, 0, 0)), "already in the middle: it stays")
	assert_eq(ArcaneMark.closing(0.0, 1.5), 1.0)
	assert_eq(ArcaneMark.closing(1.5, 1.5), 0.0)
	assert_true(_has_method("res://scripts/enemy.gd", "drag_to"), "enemies can be dragged without a taunt")
	assert_true(_has_method("res://scripts/net/net.gd", "drag"), "and the host is asked in a party")
	assert_true(_has_method("res://scripts/net/net.gd", "_sup_drag"))

func test_glint() -> void:
	var r := Abilities.get_resource("glint")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(float(r.damage), 0.7)
	assert_eq(int(r.resource_cost), 1)
	assert_eq(float(r.cast_range), 30.0)
	assert_true(bool(r.requires_target))
	assert_eq(Balance.GLINT_TIME, 4.0)
	assert_true(Abilities.has_scaling("glint"))
	var p := _player()
	assert_true(p.on_gcd("glint"))
	assert_true(ArcaneCasterKit.rewind_allows(r.tags, Abilities.cooldown_of(r)), "a short cooldown for Rewind and Convergence")
	# What it lets you cast on the move: Unravel and Sigil Darts...
	assert_true(ArcaneCasterKit.glint_applies("unravel", ARCANE, 2.0, false))
	assert_true(ArcaneCasterKit.glint_applies("arcanemissiles", ARCANE, 2.0, false))
	assert_false(ArcaneCasterKit.glint_applies("convergence", ARCANE, 2.5, false), "nothing else without the rune")
	assert_false(ArcaneCasterKit.glint_applies("fireball", PackedStringArray(["Fire", "Spell"]), 2.0, false))
	# ... and with the Rune of Momentum any spell with a cast time.
	assert_true(ArcaneCasterKit.glint_applies("convergence", ARCANE, 2.5, true))
	assert_true(ArcaneCasterKit.glint_applies("fireball", PackedStringArray(["Fire", "Spell"]), 2.0, true))
	assert_true(ArcaneCasterKit.glint_applies("embervolley", PackedStringArray(["Fire", "Spell"]), 3.0, true), "channels too")
	assert_false(ArcaneCasterKit.glint_applies("steadyshot", PackedStringArray(["Ranged"]), 2.0, true), "spells only")
	assert_false(ArcaneCasterKit.glint_applies("rewind", ARCANE, 0.0, true), "instants don't use it up")

func test_the_two_arcane_runes() -> void:
	assert_true(Runes.ALL.has("momentum") and Runes.ALL.has("carried_sigil"))
	assert_eq(Runes.rarity("momentum"), Runes.RARE)
	assert_eq(Runes.max_copies("momentum"), 1)
	assert_eq(Runes.rarity("carried_sigil"), Runes.EPIC)
	assert_eq(Runes.max_copies("carried_sigil"), 1)
	for id in ["momentum", "carried_sigil"]:
		assert_eq(TextFill.leftover(Runes.description(id)), "", "%s: every placeholder is filled" % id)
	assert_contains(Runes.description("momentum"), Abilities.ability_name("glint"))
	assert_contains(Runes.description("carried_sigil"), Abilities.ability_name("mirrorsigil"))
	assert_eq(Balance.CARRIED_SIGIL_PCT, 20.0)
	var p := _player()
	assert_eq(ArcaneCasterKit.mirror_pct(0.0, false), 35.0)
	assert_eq(ArcaneCasterKit.mirror_pct(0.0, true), 20.0, "carried: it repeats less")
	assert_eq(ArcaneCasterKit.mirror_pct(10.0, true), 30.0, "Polished Glass still adds to it")
	assert_true(ArcaneMark.CARRIED_HEIGHT > ArcaneMark.SHARD_HEIGHT, "a carried sigil's shard floats over your head")

func test_which_of_them_scale() -> void:
	for id in ["rewind", "lapse", "scatter", "mirrorsigil"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)
	for id in ["arcanemissiles", "unravel", "countdown", "convergence", "collapse", "intervalward"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)

func test_rune_of_the_afterimage() -> void:
	var r := Runes.get_resource("afterimage")
	assert_true(r != null and Runes.ALL.has("afterimage"))
	assert_eq(Runes.rarity("afterimage"), Runes.RARE)
	assert_eq(Runes.max_copies("afterimage"), 1)
	assert_eq(Balance.AFTERIMAGE_TIME, 4.0)
	assert_eq(Balance.AFTERIMAGE_PCT, 50.0)
	var text := Runes.description("afterimage")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_contains(text, Abilities.ability_name("blink"))
	assert_contains(text, Abilities.ability_name("flicker"))
	assert_eq(Details.spell_name("afterimage"), "Afterimage", "its own line on the meter")
	var p := _player()
	assert_eq(ArcaneCasterKit.echo_amount(801, 50.0), 401)
	assert_eq(ArcaneCasterKit.afterimage_window(0.0, 0), Balance.AFTERIMAGE_BURST, "one spell: a moment")
	assert_true(is_equal_approx(ArcaneCasterKit.afterimage_window(1.5, 0), 1.5 + Balance.AFTERIMAGE_TRAVEL), "a channel: until it ends")
	assert_true(is_equal_approx(ArcaneCasterKit.afterimage_window(0.0, 4), 4 * Balance.ICE_SHARDS_INTERVAL + Balance.AFTERIMAGE_TRAVEL), "Ice Shards: every shard")
