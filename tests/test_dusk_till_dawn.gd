@tool
extends McpTestSuite

# Dusk till Dawn (Legendary rune): dealing Shadow damage gives Dusk (more Shadow
# damage), Dawn (more Holy damage) follows when Dusk runs out, and the next Dusk
# can only start once Dawn is over.

const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")

func suite_name() -> String:
	return "dusk_till_dawn"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_it_is_a_legendary_rune() -> void:
	assert_true(Runes.PATHS.has("dusk_till_dawn") and Runes.ALL.has("dusk_till_dawn"), "registered")
	assert_eq(Runes.rarity("dusk_till_dawn"), Runes.LEGENDARY)
	assert_eq(Runes.rune_name("dusk_till_dawn"), "Dusk till Dawn")
	assert_eq(Runes.max_copies("dusk_till_dawn"), 1)
	assert_ne(Runes.check_limits(["dusk_till_dawn", "dusk_till_dawn"]), "", "only one Legendary rune at a time")
	assert_eq(Runes.check_limits(["dusk_till_dawn", "overload", "long_fall", "frost"]), "", "fine next to Epic and lower runes")
	assert_true(Runes.any_of_rarity(Runes.LEGENDARY), "chests can roll a Legendary Mysterious Rune again")
	assert_eq(_player().DUSK_RUNE, "dusk_till_dawn")

func test_its_text_has_every_number_filled_in() -> void:
	var text := Runes.description("dusk_till_dawn")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_false(text.contains("?"), text)
	assert_contains(text, "Dusk")
	assert_contains(text, "Dawn")
	assert_contains(text, "%s%% more Shadow damage" % TextFill.num(Balance.DUSK_DAMAGE_PCT))
	assert_contains(text, "%s%% more Holy damage" % TextFill.num(Balance.DAWN_DAMAGE_PCT))
	assert_contains(text, "%s sec" % TextFill.num(Balance.DUSK_TIME))
	# Nothing is typed into the rune's own text: the numbers come from balance.gd.
	var raw := str(Runes.get_resource("dusk_till_dawn").description)
	var bare := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	assert_true(RegEx.create_from_string("\\d").search(bare) == null, raw)

func test_numbers() -> void:
	assert_eq(Balance.DUSK_TIME, 12.0)
	assert_eq(Balance.DUSK_DAMAGE_PCT, 20.0)
	assert_eq(Balance.DAWN_TIME, 12.0)
	assert_eq(Balance.DAWN_DAMAGE_PCT, 20.0)

func test_what_starts_dusk() -> void:
	var p := _player()
	assert_true(p.starts_dusk("shadow", 10, false, false), "Shadow damage")
	assert_false(p.starts_dusk("shadow", 0, false, false), "a hit that did nothing doesn't")
	assert_false(p.starts_dusk("holy", 10, false, false), "Holy damage doesn't")
	assert_false(p.starts_dusk("fire", 10, false, false), "other schools don't")
	assert_false(p.starts_dusk("shadow", 10, true, false), "Dusk is not refreshed")
	assert_false(p.starts_dusk("shadow", 10, false, true), "no Dusk while Dawn lasts")

func test_dawn_follows_a_dusk_that_ran_out() -> void:
	var p := _player()
	assert_true(p.dawn_follows(112.0, 112.0, true), "it ran its whole time")
	assert_true(p.dawn_follows(112.1, 112.0, true))
	assert_false(p.dawn_follows(105.0, 112.0, true), "cleared early (death, leaving): no Dawn")
	assert_false(p.dawn_follows(112.0, 112.0, false), "the rune came off")
	assert_false(p.dawn_follows(112.0, 0.0, true), "there was no Dusk")

func _hit(type: String, tags: Array, dot: bool = false) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	info.is_dot = dot
	return info

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func test_dusk_boosts_shadow_damage_only() -> void:
	var st := _status()
	var fx: Resource = _player().make_dusk_fx()
	assert_eq(float(fx.duration), Balance.DUSK_TIME)
	assert_eq(int(fx.max_stacks), 1)
	assert_false(bool(fx.is_debuff))
	assert_false(bool(fx.consume_on_use), "hits don't use it up")
	assert_true(st.apply(fx))
	var spell := _hit("shadow", ["Shadow", "Spell"])
	st.collect_damage_mods(spell, false)
	assert_true(absf(spell.bonus_pct - 20.0) < 0.001, "+20%% Shadow spells, got %s" % spell.bonus_pct)
	var strike := _hit("shadow", ["Shadow", "Ability", "Melee"])
	st.collect_damage_mods(strike, false)
	assert_true(absf(strike.bonus_pct - 20.0) < 0.001, "abilities too")
	var tick := _hit("shadow", ["Shadow", "Spell", "DoT"], true)
	st.collect_damage_mods(tick, false)
	assert_true(absf(tick.bonus_pct - 20.0) < 0.001, "damage over time too")
	var holy := _hit("holy", ["Holy", "Spell"])
	st.collect_damage_mods(holy, false)
	assert_eq(holy.bonus_pct, 0.0, "not Holy")
	var fire := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(fire, false)
	assert_eq(fire.bonus_pct, 0.0, "not other schools")

func test_dusk_is_not_refreshed() -> void:
	var st := _status()
	var fx: Resource = _player().make_dusk_fx()
	assert_true(st.apply(fx))
	st.set_remaining("dusk", 3.0)
	assert_false(st.apply(fx), "applying it again changes nothing")
	assert_true(st.remaining_of("dusk") <= 3.01, "its time was not reset: %s" % st.remaining_of("dusk"))
	assert_eq(st.stacks_of("dusk"), 1)

func test_dawn_boosts_holy_damage_only() -> void:
	var st := _status()
	var fx: Resource = _player().make_dawn_fx()
	assert_eq(float(fx.duration), Balance.DAWN_TIME)
	assert_eq(int(fx.max_stacks), 1)
	assert_false(bool(fx.is_debuff))
	assert_true(st.apply(fx))
	var holy := _hit("holy", ["Holy", "Spell"])
	st.collect_damage_mods(holy, false)
	assert_true(absf(holy.bonus_pct - 20.0) < 0.001, "+20%% Holy, got %s" % holy.bonus_pct)
	var strike := _hit("holy", ["Holy", "Ability", "Melee"])
	st.collect_damage_mods(strike, false)
	assert_true(absf(strike.bonus_pct - 20.0) < 0.001, "abilities too")
	var shadow := _hit("shadow", ["Shadow", "Spell"])
	st.collect_damage_mods(shadow, false)
	assert_eq(shadow.bonus_pct, 0.0, "not Shadow")

func test_it_is_wired_into_the_player() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "_dusk_on_hit(info)")
	assert_contains(src, "\t_tick_dusk()\n")
