@tool
extends McpTestSuite

# Rune of Overload (Epic): Lightning spells and abilities build Static, building
# it at the cap Overloads, and a break from Lightning makes you Grounded (no Overload).

const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Details = preload("res://scripts/core/details.gd")

func suite_name() -> String:
	return "lightning_runes"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_overload_is_an_epic_rune() -> void:
	assert_true(Runes.PATHS.has("overload") and Runes.ALL.has("overload"), "registered")
	assert_eq(Runes.rarity("overload"), Runes.EPIC)
	assert_eq(Runes.rune_name("overload"), "Rune of Overload")
	assert_eq(Runes.max_copies("overload"), 1)
	assert_ne(Runes.check_limits(["overload", "overload"]), "", "an Epic rune is equipped once")
	assert_eq(Runes.check_limits(["overload", "hair_trigger", "frost"]), "", "fine next to other runes")
	var text := Runes.description("overload")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_contains(text, "Static")
	assert_contains(text, "Overload")
	assert_contains(text, "Grounded")

func test_numbers() -> void:
	assert_eq(Balance.STATIC_MAX_STACKS, 15)
	assert_eq(Balance.STATIC_DAMAGE_PCT, 2.5, "+2.5% Lightning damage per stack")
	assert_eq(Balance.OVERLOAD_LOCKOUT, 4.0, "4 s without building")
	assert_eq(Balance.OVERLOAD_GROUND_AFTER, 3.0, "3 s off Lightning")
	assert_eq(Balance.OVERLOAD_GROUND_TIME, 10.0, "10 s without Overload")
	assert_true(Balance.STATIC_TIME > Balance.OVERLOAD_GROUND_AFTER, "the stacks outlast the break")
	var rune := Runes.get_resource("overload")
	assert_true(is_equal_approx(float(rune.effect_amount), 0.1), "0.1 Frost Bolts per stack")
	assert_eq(str(rune.damage_type), "lightning")
	assert_true(is_equal_approx(OverloadKit.overload_coef(15, float(rune.effect_amount)), 1.5), "a full Overload = 1.5 Frost Bolts")
	assert_eq(OverloadKit.overload_coef(0, 0.1), 0.0)
	assert_eq(Details.HIT_NAMES.get("overload", ""), "Overload", "its own line on the meter")

func test_what_builds_static() -> void:
	var p := _player()
	var spell := PackedStringArray(["Lightning", "Spell"])
	var strike := PackedStringArray(["Lightning", "Ability", "Melee"])
	assert_true(OverloadKit.builds_static("lightning", spell, false, false, 10), "Lightning spells")
	assert_true(OverloadKit.builds_static("lightning", strike, false, false, 10), "Lightning abilities")
	assert_false(OverloadKit.builds_static("lightning", spell, true, false, 10), "procs (chain jumps, runes) don't")
	assert_false(OverloadKit.builds_static("lightning", spell, false, true, 10), "damage-over-time ticks don't")
	assert_false(OverloadKit.builds_static("lightning", spell, false, false, 0), "a hit that did nothing doesn't")
	assert_false(OverloadKit.builds_static("fire", PackedStringArray(["Fire", "Spell"]), false, false, 10), "other schools don't")
	assert_false(OverloadKit.builds_static("lightning", PackedStringArray(["AutoAttack"]), false, false, 10), "auto-attacks don't")

func _hit(type: String, tags: Array, dot: bool = false) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	info.is_dot = dot
	return info

func test_static_boosts_lightning_damage() -> void:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx: Resource = OverloadKit.make_static_fx()
	assert_eq(int(fx.max_stacks), Balance.STATIC_MAX_STACKS)
	assert_eq(float(fx.duration), Balance.STATIC_TIME)
	assert_false(bool(fx.consume_on_use), "hits don't use it up")
	for i in 3:
		st.apply(fx)
	assert_eq(st.stacks_of("static"), 3)
	var bolt := _hit("lightning", ["Lightning", "Spell"])
	st.collect_damage_mods(bolt, false)
	assert_true(absf(bolt.bonus_pct - 7.5) < 0.001, "3 stacks = +7.5%%, got %s" % bolt.bonus_pct)
	var strike := _hit("lightning", ["Lightning", "Ability", "Melee"])
	st.collect_damage_mods(strike, false)
	assert_true(absf(strike.bonus_pct - 7.5) < 0.001, "abilities too")
	var tick := _hit("lightning", ["Lightning", "Spell", "DoT"], true)
	st.collect_damage_mods(tick, false)
	assert_true(absf(tick.bonus_pct - 7.5) < 0.001, "damage over time too")
	for i in 20:
		st.apply(fx)
	assert_eq(st.stacks_of("static"), Balance.STATIC_MAX_STACKS, "never more than the cap")
	var fire := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(fire, false)
	assert_eq(fire.bonus_pct, 0.0, "only Lightning damage")
	st._flush_consumed()
	assert_eq(st.stacks_of("static"), Balance.STATIC_MAX_STACKS, "hits don't use it up")

## A break from Lightning makes you Grounded, and Grounded stops the Overload.
func test_grounded() -> void:
	var p := _player()
	assert_false(OverloadKit.grounds(2.9), "not yet")
	assert_true(OverloadKit.grounds(3.0), "3 s without Lightning")
	assert_true(OverloadKit.grounds(60.0), "and for as long as you stay off it")
	var cap: int = Balance.STATIC_MAX_STACKS
	assert_false(OverloadKit.overloads(cap - 1, false), "below the cap: nothing happens")
	assert_true(OverloadKit.overloads(cap, false), "at the cap: Overload")
	assert_false(OverloadKit.overloads(cap, true), "Grounded: the stacks stay")
	var fx: Resource = OverloadKit.make_grounded_fx()
	assert_eq(float(fx.duration), Balance.OVERLOAD_GROUND_TIME)
	assert_false(bool(fx.is_debuff))
	assert_eq(int(fx.max_stacks), 1)

func test_overloaded_lockout() -> void:
	var fx: Resource = OverloadKit.make_overloaded_fx()
	assert_eq(float(fx.duration), Balance.OVERLOAD_LOCKOUT)
	assert_true(bool(fx.is_debuff))
	assert_eq(float(fx.damage_mod_pct), 0.0, "it only blocks Static")
