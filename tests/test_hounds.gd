@tool
extends McpTestSuite

# Shadow melee: the Hounds. Two demon dogs that fight beside you, on Rage: Sic
# and Open Up build it, Both At Once, Run Them Down, Guard Dogs and Leeching
# Strike spend it (and Rouse the Hounds), Off the Chain is the cooldown. The
# Hounds have no stats of their own: their hits are the player's, dealt as
# procs under their own names. And the dogs themselves (scripts/hound.gd).

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Hound = preload("res://scripts/hound.gd")

const KIT := ["sic", "openup", "bothatonce", "runthemdown", "guarddogs", "offthechain"]
const NAMES := {"sic": "Sic", "openup": "Open Up", "bothatonce": "Both At Once", "runthemdown": "Run Them Down",
	"guarddogs": "Guard Dogs", "offthechain": "Off the Chain"}
const LEVELS := {"sic": 6, "openup": 10, "bothatonce": 14, "runthemdown": 18, "guarddogs": 24, "offthechain": 40}
# id: [cooldown, weapon damage, Rage cost, Rage gained]
const NUMBERS := {"sic": [0.0, 1.0, 0, 15], "openup": [6.0, 1.4, 0, 25], "bothatonce": [4.0, 1.2, 40, 0],
	"runthemdown": [8.0, 0.6, 30, 0], "guarddogs": [30.0, 0.0, 20, 0], "offthechain": [90.0, 0.0, 0, 0]}
const SPENDERS := ["bothatonce", "runthemdown", "guarddogs", "shadowstrike"]

func suite_name() -> String:
	return "hounds"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _file(id: String) -> Resource:
	return ResourceLoader.load("res://data/abilities/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE)

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func _hit(type: String, tags: Array, dot := false) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	info.is_dot = dot
	return info

## Something shaped like a character: 1.8 m tall and 0.8 m wide, its origin in its middle.
func _body(at: Vector3) -> Node3D:
	var b := Node3D.new()
	track(b)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	b.add_child(cs)
	b.position = at
	return b

# --- The kit ---------------------------------------------------------------------------

func test_the_kit() -> void:
	for id in KIT:
		var r := _file(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_eq(str(r.display_name), str(NAMES[id]))
		assert_eq(int(r.weapon_requirement), 1, "%s: a melee weapon" % id)
		assert_false(bool(r.requires_dual_wield) or bool(r.requires_two_hand) or bool(r.requires_shield), "%s: any melee weapon" % id)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Shadow") and not r.tags.has("Spell"), "%s is a Shadow ability" % id)
		assert_eq(str(r.damage_type), "shadow")
		assert_eq(float(r.threat_multiplier), 1.0, "%s: a damage dealer's threat" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_eq(SkillCards.level_of(id), int(LEVELS[id]), "%s: its card's level" % id)
		assert_eq(Abilities.category_of(id), "shadow")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])
		assert_false(tip.contains("Frost Bolt"), "%s: real damage numbers" % id)
		assert_contains(tip, "Hounds", "%s says what it does with the Hounds" % id)
		assert_true(Keywords.mentions(tip).has("k:hounds"), "%s: Shift explains the Hounds" % id)
		assert_contains(tip, "Requires a melee weapon")
	# No card shares its place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if KIT.has(id) or KIT.has(str(orders.get(order, ""))):
			assert_false(orders.has(order), "%s: sort order %d is taken by %s" % [id, order, orders.get(order, "")])
		orders[order] = id

func test_numbers() -> void:
	for id in NUMBERS:
		var r := Abilities.get_resource(str(id))
		assert_eq(float(r.cooldown), float(NUMBERS[id][0]), "%s: cooldown" % id)
		assert_eq(float(r.weapon_damage_multiplier), float(NUMBERS[id][1]), "%s: weapon damage" % id)
		assert_eq(int(r.resource_cost), int(NUMBERS[id][2]), "%s: Rage cost" % id)
		assert_eq(int(r.resource_generated), int(NUMBERS[id][3]), "%s: Rage gained" % id)
		assert_eq(float(r.damage), 0.0)
	assert_eq(float(Abilities.get_resource("runthemdown").radius), 5.0)
	assert_eq(Balance.HOUND_COUNT, 2)
	assert_eq(Balance.HOUND_TIME, 30.0)
	assert_eq(Balance.HOUND_BITE, 0.15)
	assert_eq(Balance.HOUND_BITE_EVERY, 1.5)
	assert_eq(Balance.HOUND_DRAG, 0.75)
	assert_eq(Balance.ROUSED_TIME, 8.0)
	assert_eq(Balance.ROUSED_PCT, 25.0)
	assert_eq(Balance.LAID_OPEN_TIME, 8.0)
	assert_eq(Balance.LAID_OPEN_PCT, 30.0)
	assert_eq(Balance.HOUND_LUNGE, 0.6)
	assert_eq(Balance.RUN_DOWN_TIME, 6.0)
	assert_eq(Balance.RUN_DOWN_TARGETS, 2)
	assert_eq(Balance.RUN_DOWN_PCT, 50.0)
	assert_eq(Balance.GUARD_DOGS_TIME, 5.0)
	assert_eq(Balance.GUARD_DOGS_PCT, 30.0)
	assert_eq(Balance.OFF_THE_CHAIN_TIME, 10.0)
	assert_eq(Balance.OFF_THE_CHAIN_SPEED_PCT, 50.0)
	var p := _player()
	for id in ["sic", "openup", "bothatonce", "runthemdown", "guarddogs"]:
		assert_true(p.on_gcd(id), "%s is on the global cooldown" % id)
	assert_false(p.on_gcd("offthechain"), "Off the Chain is off the global cooldown")
	for id in ["sic", "openup", "bothatonce"]:
		assert_true(bool(Abilities.get_resource(id).requires_target))
		assert_true(Abilities.uses_weapon_reach(id), "%s: within the weapon's reach" % id)
	for id in ["runthemdown", "guarddogs", "offthechain"]:
		assert_false(bool(Abilities.get_resource(id).requires_target), "%s needs no target" % id)
	for id in ["sic", "openup", "bothatonce", "runthemdown"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)
	for id in ["guarddogs", "offthechain"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)

## The kit runs on Rage: two abilities build it, the rest spend it.
func test_it_builds_and_spends_rage() -> void:
	var p := _player()
	for id in ["sic", "openup"]:
		assert_eq(Abilities.resource_of(id), "rage", "%s builds Rage" % id)
		assert_true(Abilities.generated_of(id) > 0)
		assert_eq(Abilities.cost_of(id), 0)
		assert_contains(Abilities.tooltip(id), "Generates %d Rage" % Abilities.generated_of(id))
		assert_false(HoundsKit.rouses(Abilities.resource_of(id), float(Abilities.cost_of(id))), "%s costs nothing: it does not Rouse" % id)
	for id in SPENDERS:
		assert_eq(Abilities.resource_of(id), "rage", "%s spends Rage" % id)
		assert_true(Abilities.cost_of(id) > 0)
		assert_true(HoundsKit.rouses(Abilities.resource_of(id), float(Abilities.cost_of(id))), "%s Rouses the Hounds" % id)
		assert_contains(str(_file(id).description), "Rouses your Hounds")
	assert_contains(Abilities.tooltip("bothatonce"), "40 Rage")
	assert_eq(Abilities.resource_of("offthechain"), "", "Off the Chain is free")
	# Whatever costs Rage Rouses them: other books' abilities too. Nothing else does.
	assert_true(HoundsKit.rouses("rage", 50.0))
	assert_false(HoundsKit.rouses("rage", 0.0))
	assert_false(HoundsKit.rouses("energy", 40.0))
	assert_false(HoundsKit.rouses("mana", 40.0))
	assert_false(HoundsKit.rouses("", 0.0))

## Leeching Strike is part of the kit and otherwise what it was.
func test_leeching_strike_is_unchanged() -> void:
	var r := Abilities.get_resource("shadowstrike")
	assert_eq(str(r.display_name), "Leeching Strike")
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(float(r.weapon_damage_multiplier), 1.2)
	assert_eq(int(r.resource_cost), 30)
	assert_true(Balance.HEALS.has("shadowstrike"), "it still heals")
	assert_eq(_typed_number(str(_file("shadowstrike").description)), "")

func test_what_calls_the_hounds() -> void:
	var p := _player()
	for id in KIT + ["shadowstrike"]:
		assert_true(HoundsKit.calls_hounds(id), "%s calls them" % id)
		assert_eq(Abilities.category_of(id), "shadow")
		assert_eq(int(Abilities.get_resource(id).weapon_requirement), 1, "%s is a melee ability" % id)
	for id in ["corruption", "blight", "shadowarrow", "slam", "auto_melee", "bringitdown", ""]:
		assert_false(HoundsKit.calls_hounds(id), "%s does not" % id)
	assert_eq(HoundsKit.HOUND_CALLERS.size(), 7)

# --- Their bites -----------------------------------------------------------------------

func test_haste_makes_them_bite_faster() -> void:
	var p := _player()
	assert_eq(HoundsKit.hound_bite_interval(1.0, false), 1.5)
	assert_true(is_equal_approx(HoundsKit.hound_bite_interval(1.2, false), 1.25), "20% Haste: 20% more bites")
	assert_true(is_equal_approx(HoundsKit.hound_bite_interval(1.0, true), 1.0), "Off the Chain: 50% faster")
	assert_true(is_equal_approx(HoundsKit.hound_bite_interval(1.2, true), 1.5 / 1.8), "the two multiply")
	assert_true(HoundsKit.hound_bite_interval(0.0, false) > 0.0, "never a bite every frame")
	assert_true(HoundsKit.hound_bite_interval(1000.0, true) >= 0.2)

func test_roused_and_the_mark_add_to_a_bite() -> void:
	var p := _player()
	assert_eq(HoundsKit.hound_bite_bonuses(false, false), [])
	assert_eq(HoundsKit.hound_bite_bonuses(true, false), [[25.0, "Roused"]])
	assert_eq(HoundsKit.hound_bite_bonuses(false, true), [[30.0, "Laid Open"]])
	assert_eq(HoundsKit.hound_bite_bonuses(true, true), [[25.0, "Roused"], [30.0, "Laid Open"]])
	# On the hit they add up, and each gets its own line on the damage meter.
	var bite := _hit("shadow", HoundsKit.HOUND_TAGS)
	for b in HoundsKit.hound_bite_bonuses(true, true):
		bite.add_bonus(float(b[0]), str(b[1]))
	assert_eq(bite.bonus_pct, 55.0)
	var rows: Array = Details.split_amount("hound_bite", 155, false, bite.bonus_parts)
	assert_eq(rows.size(), 3)
	assert_eq(str(rows[0][0]), "hound_bite")
	assert_eq(int(rows[0][1]), 100, "the bite's own line keeps what it would have done alone")
	assert_eq(str(rows[1][0]), "bonus:Roused")
	assert_eq(int(rows[1][1]), 25)
	assert_eq(str(rows[2][0]), "bonus:Laid Open")
	assert_eq(int(rows[2][1]), 30)
	assert_eq(Details.spell_name("bonus:Roused"), "Roused")

## Their hits are the player's own: they scale like an ability, and they are
## named after what they are.
func test_their_hits() -> void:
	var p := _player()
	assert_true(HoundsKit.HOUND_TAGS.has("Ability") and HoundsKit.HOUND_TAGS.has("Shadow") and not HoundsKit.HOUND_TAGS.has("Spell"))
	assert_false(HoundsKit.HOUND_TAGS.has("Melee"), "not a melee swing of mine: Heat and the like do not count it")
	assert_eq(Details.spell_name(HoundsKit.HOUND_BITE_ID), "Hound Bite")
	assert_eq(Details.spell_name(HoundsKit.HOUND_LUNGE_ID), "Hound Lunge")
	assert_eq(Details.spell_name(HoundsKit.HOUND_DRAG_ID), "Drag Down")
	for id in [HoundsKit.HOUND_BITE_ID, HoundsKit.HOUND_LUNGE_ID, HoundsKit.HOUND_DRAG_ID]:
		assert_false(Abilities.PATHS.has(id), "%s is no ability" % id)
		assert_ne(Details.spell_color(id), Color(0.7, 0.7, 0.75), "%s has a colour on the meter" % id)
	# A proc: it feeds no Breach (Tainted Steel), whatever the talent's rank.
	assert_eq(DecayKit.decay_feed_pct(HoundsKit.HOUND_BITE_ID, PackedStringArray(HoundsKit.HOUND_TAGS), true, false, 30.0, 5.0), 0.0)
	var src := PlayerSource.text()
	assert_contains(src, "info.is_proc = true       # runes and \"on hit\" talents do not fire off it")
	assert_contains(src, "info.no_empower = true")
	# Dusk till Dawn's Dusk is a Shadow damage bonus of mine: their bites get it.
	var st := _status()
	st.apply(DuskTillDawnKit.make_dusk_fx())
	var bite := _hit("shadow", HoundsKit.HOUND_TAGS)
	bite.is_proc = true
	bite.no_empower = true
	st.collect_damage_mods(bite, false)
	assert_true(absf(bite.bonus_pct - Balance.DUSK_DAMAGE_PCT) < 0.001, "my Shadow damage bonuses are theirs")

func test_what_sets_them_on_an_enemy() -> void:
	var p := _player()
	# Always the last enemy I damaged directly, whoever my target is.
	assert_true(HoundsKit.sets_prey(false, false, 50), "every direct hit does")
	assert_false(HoundsKit.sets_prey(true, false, 50), "not a proc (their own bites, chain jumps, runes)")
	assert_false(HoundsKit.sets_prey(false, true, 50), "not a damage over time tick")
	assert_false(HoundsKit.sets_prey(false, false, 0), "not a hit that did nothing")
	# One cast that hits several enemies at once has no last one: my target wins.
	assert_true(HoundsKit.keeps_prey(true, true), "they were just sent to my target by this same cast")
	assert_false(HoundsKit.keeps_prey(true, false), "sent to another enemy by this cast: the next one hit takes them")
	assert_false(HoundsKit.keeps_prey(false, true), "a later hit on anything else always moves them")
	var src := PlayerSource.text()
	assert_contains(src, "if not sets_prey(bool(info.is_proc), bool(info.is_dot), int(info.amount)):")
	assert_contains(Keywords.keyword_text("hounds"), "the last enemy you damaged directly")

func test_run_them_down() -> void:
	var p := _player()
	assert_eq(HoundsKit.run_down_amount(200), 100)
	assert_eq(HoundsKit.run_down_amount(33), 17, "rounded")
	assert_eq(HoundsKit.run_down_amount(0), 0)
	assert_eq(HoundsKit.run_down_amount(-5), 0)
	var tip := Abilities.tooltip("runthemdown")
	assert_contains(tip, "within 5 m")
	assert_contains(tip, "For 6 sec")
	assert_contains(tip, "up to 2 other enemies")
	assert_contains(tip, "50% of its damage")
	var fx: Resource = HoundsKit.make_run_down_fx()
	assert_eq(float(fx.duration), Balance.RUN_DOWN_TIME)
	assert_eq(str(fx.display_name), "Run Them Down")

# --- Their time ------------------------------------------------------------------------

func test_their_time() -> void:
	var p := _player()
	var fx: Resource = HoundsKit.make_hounds_fx()
	assert_eq(float(fx.duration), Balance.HOUND_TIME)
	assert_false(bool(fx.is_debuff))
	assert_eq(float(fx.damage_mod_pct), 0.0, "the buff only shows them")
	# Nothing renews them.
	var st := _status()
	assert_true(st.apply(fx))
	st.set_remaining("hounds", 4.0)
	assert_false(st.apply(fx), "calling again changes nothing while they are out")
	assert_true(st.remaining_of("hounds") <= 4.01)
	# Their time up: each drags at its prey. Sent away early (death): not.
	assert_true(HoundsKit.hounds_time_up(130.0, 130.0))
	assert_true(HoundsKit.hounds_time_up(130.2, 130.0))
	assert_false(HoundsKit.hounds_time_up(112.0, 130.0), "cleared early")
	assert_false(HoundsKit.hounds_time_up(130.0, 0.0), "there were none")
	# Off the Chain: their time stands still while it lasts.
	assert_eq(HoundsKit.hounds_until_unchained(130.0, 110.0), 140.0)
	assert_eq(HoundsKit.hounds_until_unchained(130.0, 129.0), 140.0)
	var chain: Resource = HoundsKit.make_off_the_chain_fx()
	assert_eq(float(chain.duration), Balance.OFF_THE_CHAIN_TIME)
	assert_eq(str(chain.display_name), "Off the Chain")
	var tip := Abilities.tooltip("offthechain")
	assert_contains(tip, "50% faster")
	assert_contains(tip, "10 sec longer")

func test_roused_does_not_stack() -> void:
	var p := _player()
	var fx: Resource = HoundsKit.make_roused_fx()
	assert_eq(str(fx.display_name), "Roused")
	assert_eq(float(fx.duration), Balance.ROUSED_TIME)
	assert_eq(int(fx.max_stacks), 1)
	assert_eq(float(fx.damage_mod_pct), 0.0, "it boosts their bites alone (hound_bite_bonuses), not my own hits")
	var st := _status()
	st.apply(fx)
	st.set_remaining("roused", 2.0)
	st.apply(fx)
	assert_eq(st.stacks_of("roused"), 1)
	var left: float = st.remaining_of("roused")
	assert_true(left > Balance.ROUSED_TIME - 0.2, "spending Rage again starts its time over, got %s" % left)

func test_guard_dogs() -> void:
	var p := _player()
	var fx: Resource = HoundsKit.make_guard_dogs_fx()
	assert_eq(str(fx.display_name), "Guard Dogs")
	assert_eq(float(fx.duration), Balance.GUARD_DOGS_TIME)
	assert_false(bool(fx.is_debuff))
	var st := _status()
	st.apply(fx)
	for row in [["physical", ["Physical", "Melee"], false], ["fire", ["Fire", "Spell"], false], ["shadow", ["Shadow", "Spell", "DoT"], true]]:
		var info := _hit(str(row[0]), row[1], bool(row[2]))
		st.collect_damage_mods(info, true)
		assert_eq(info.bonus_pct, -30.0, "%s %s: 30%% less" % [row[0], "tick" if row[2] else "hit"])
	var mine := _hit("shadow", ["Shadow", "Ability", "Melee"])
	st.collect_damage_mods(mine, false)
	assert_eq(mine.bonus_pct, 0.0, "it changes nothing about the damage I deal")
	var tip := Abilities.tooltip("guarddogs")
	assert_contains(tip, "For 5 sec you take 30% less damage")
	assert_contains(tip, "keep biting")
	# Nothing stops the Hounds biting while it is up.
	var src := PlayerSource.text()
	var from := src.find("func _tick_hounds()")
	var tick := src.substr(from, src.find("\nfunc ", from + 10) - from)
	assert_true(tick.contains("_hound_bite(i)"), "the bite loop")
	assert_false(tick.contains("GUARD_DOGS_FX"), "the bite loop does not look at Guard Dogs")

# --- Open Up's mark ----------------------------------------------------------------------

func test_open_ups_mark_is_own_only() -> void:
	var p := _player()
	Balance.apply_effects()
	var mark: Resource = Effects.get_effect("laid_open")
	assert_true(mark != null)
	assert_eq(str(mark.display_name), "Laid Open")
	assert_true(bool(mark.get("is_debuff")))
	assert_true(bool(mark.get("per_caster")), "every player has their own")
	assert_eq(float(mark.get("damage_mod_pct")), 0.0, "it helps nobody else: only its caster's Hounds read it")
	assert_eq(float(Balance.EFFECTS["res://data/effects/laid_open.tres"]["duration"]), Balance.LAID_OPEN_TIME)
	assert_eq(str(_file("openup").on_hit_effect.id), "laid_open")
	assert_eq(HoundsKit.LAID_OPEN_FX, "laid_open")
	assert_eq(_typed_number(str(mark.description)), "")
	var text := TextFill.effect(mark)
	assert_eq(TextFill.leftover(text), "")
	assert_contains(text, "30% more damage")
	var st := _status()
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	st.apply(mark, ally)
	assert_false(st.has_from("laid_open", me), "an ally's mark does nothing for my Hounds")
	st.apply(mark, me)
	assert_true(st.has_from("laid_open", me))
	assert_contains(Abilities.tooltip("openup"), "30% more damage")
	assert_contains(PlayerSource.text(), "st.has_from(LAID_OPEN_FX, self)")

# --- Words ---------------------------------------------------------------------------------

func test_keywords() -> void:
	for kid in ["hounds", "roused"]:
		assert_true(Keywords.KEYWORDS.has(kid))
		var entry: Dictionary = Keywords.KEYWORDS[kid]
		assert_eq(_typed_number(str(entry["text"])), "", "%s: no typed number" % kid)
		var text := Keywords.keyword_text(kid)
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % kid)
		assert_false(text.contains("?"), text)
		assert_false(text.contains("Frost Bolt"), "real damage numbers")
	assert_true(Keywords.KEYWORDS["hounds"]["forms"].has("Hounds") and Keywords.KEYWORDS["hounds"]["forms"].has("Hound"))
	assert_true(Keywords.KEYWORDS["roused"]["forms"].has("Rouses"))
	var hounds := Keywords.keyword_text("hounds")
	assert_contains(hounds, "for 30 sec")
	assert_contains(hounds, "every 1.5 sec")
	assert_contains(hounds, "Enemies cannot attack them")
	var roused := Keywords.keyword_text("roused")
	assert_contains(roused, "for 8 sec")
	assert_contains(roused, "25% more damage")
	assert_contains(roused, "does not stack")
	assert_true(Keywords.mentions(Abilities.tooltip("bothatonce")).has("k:roused"))

# --- The dogs themselves (scripts/hound.gd) ----------------------------------------------

func test_where_they_stand() -> void:
	assert_eq(Hound.side_of(0), -1.0)
	assert_eq(Hound.side_of(1), 1.0)
	# At heel: one each side of their owner, a little behind (characters look down -Z).
	var left: Vector3 = Hound.heel_spot(Vector3(5, 0, 5), 0.0, -1.0)
	var right: Vector3 = Hound.heel_spot(Vector3(5, 0, 5), 0.0, 1.0)
	assert_true(left.x < 5.0 and right.x > 5.0)
	assert_true(left.z > 5.0 and right.z > 5.0, "behind, not in the way")
	assert_true(is_equal_approx(left.distance_to(right), Hound.HEEL_SIDE * 2.0))
	# Their owner turns round: so do they.
	var turned: Vector3 = Hound.heel_spot(Vector3(5, 0, 5), PI, -1.0)
	assert_true(turned.x > 5.0 and turned.z < 5.0)
	# At their prey: one each side of it, round from where their owner stands.
	var prey_at := Vector3(0, 0, -6)
	var me := Vector3.ZERO
	var a: Vector3 = Hound.flank_spot(prey_at, me, 0.4, -1.0)
	var b: Vector3 = Hound.flank_spot(prey_at, me, 0.4, 1.0)
	for s in [a, b]:
		assert_true(is_equal_approx((s as Vector3).distance_to(prey_at), 0.4 + Hound.STAND_OFF), "at its edge")
		assert_true((s as Vector3).z < prey_at.z, "on its far side from me")
	assert_true(a.x * b.x < 0.0, "one each side")
	assert_true(Hound.flank_spot(prey_at, prey_at, 0.4, 1.0).distance_to(prey_at) > 0.5, "standing in it: still beside it")
	assert_true(Hound.travel_time(Vector3.ZERO, Vector3(9, 0, 0)) > 1.0)
	assert_true(Hound.travel_time(Vector3.ZERO, Vector3(400, 0, 0)) < 1.5, "never a long wait: it runs faster to catch up")
	assert_eq(Hound.rise(0.0), 0.0)
	assert_eq(Hound.rise(Hound.RISE_TIME), 1.0)
	assert_eq(Hound.sink(0.0), 0.0)
	assert_eq(Hound.sink(Hound.LEAVE_TIME), 1.0)
	assert_true(Hound.HIDE.r > 0.5 and Hound.HIDE.g < 0.2, "red hide")
	assert_true(Hound.HORN.b > 0.8 and Hound.HORN.r > 0.5 and Hound.HORN.g < 0.5, "violet horns")

func test_a_pair_comes_up_and_goes_for_the_prey() -> void:
	var scene := Node3D.new()
	track(scene)
	var me := _body(Vector3(0, 0.9, 0))
	var prey := _body(Vector3(0, 0.9, -6))
	var pair: Array = Hound.call_pair(scene, me, prey, 30.0, false)
	assert_eq(pair.size(), 2)
	assert_eq(float(pair[0].side), -1.0)
	assert_eq(float(pair[1].side), 1.0)
	for h in pair:
		assert_eq(h.legs(), 4)
		assert_false(h.is_out(), "it climbs out, it is not just there")
		assert_true(is_equal_approx(h.spot().y, 0.0), "on the ground, not at its owner's middle")
		assert_true(h.spot().distance_to(Vector3(0, 0, -6)) < 1.3, "it comes up at its prey")
	for i in 12:
		for h in pair:
			h._advance(0.05)
	assert_true(pair[0].is_out() and pair[1].is_out())
	assert_true(pair[0].spot().distance_to(pair[1].spot()) > 1.0, "one each side")
	# It bites, and stays where it is.
	pair[0].bite()
	for i in 10:
		pair[0]._advance(0.05)
	assert_false(pair[0].is_queued_for_deletion())
	# Its prey is gone: back to heel.
	for h in pair:
		h.set_prey(null)
	for i in 80:
		for h in pair:
			h._advance(0.05)
	for h in pair:
		assert_true(h.spot().distance_to(Hound.heel_spot(Vector3.ZERO, 0.0, float(h.side))) < 0.2, "at heel")
	# A new prey a long way off: they run to it.
	var far := _body(Vector3(12, 0.9, 3))
	for h in pair:
		h.set_prey(far)
	for i in 60:
		for h in pair:
			h._advance(0.05)
	for h in pair:
		assert_true(h.spot().distance_to(Vector3(12, 0, 3)) < 1.3)
	# Both At Once: they leap, and land on their feet again.
	for h in pair:
		h.lunge()
		for i in 12:
			h._advance(0.05)
		assert_true(h.is_out())
	# Their time is up: they sink and are gone.
	for h in pair:
		h.leave(true)
		assert_true(h.leaving())
		for i in 14:
			h._advance(0.05)
		assert_true(h.is_queued_for_deletion())

func test_a_party_members_hounds() -> void:
	var scene := Node3D.new()
	track(scene)
	var puppet := _body(Vector3(3, 0.9, 3))
	var prey := _body(Vector3(3, 0.9, -2))
	# Their machine says they have Hounds: a pair appears at their character.
	Hound.show_for(scene, puppet, prey, 20.0)
	assert_true(puppet.has_meta(Hound.META))
	var pair: Array = puppet.get_meta(Hound.META)
	assert_eq(pair.size(), 2)
	assert_true(bool(pair[0].auto), "nothing tells these when to bite: they do it themselves")
	# Said again (a new prey, more time): the same two, not two more.
	Hound.show_for(scene, puppet, null, 25.0)
	assert_eq((puppet.get_meta(Hound.META) as Array).size(), 2)
	assert_true(is_same(puppet.get_meta(Hound.META)[0], pair[0]))
	assert_eq(float(pair[0].life), 25.0)
	assert_true(pair[0].prey == null)
	# Gone: they sink, and the next call brings a new pair.
	Hound.show_for(scene, puppet, null, 0.0)
	assert_true(pair[0].leaving() and pair[1].leaving())
	assert_false(puppet.has_meta(Hound.META))
	Hound.show_for(scene, puppet, prey, 30.0)
	assert_false(is_same(puppet.get_meta(Hound.META)[0], pair[0]))
	# Left alone, they go by themselves when their time is over.
	var late: Array = Hound.call_pair(scene, puppet, null, 1.0, true)
	for i in 60:
		late[0]._advance(0.05)
	assert_true(late[0].is_queued_for_deletion())
	# Nobody to follow: nothing is made.
	assert_eq(Hound.call_pair(scene, null, null, 30.0, false).size(), 0)

# --- They dash at prey that is far off -----------------------------------------------------

func test_they_dash_at_far_prey() -> void:
	assert_eq(Hound.DASH_AFTER, 1.0, "more than a second's run away")
	assert_true(Hound.DASH_SPEED > Hound.RUN_SPEED * 3.0)
	assert_false(Hound.dashes(Vector3.ZERO, Vector3(Hound.RUN_SPEED, 0, 0)), "a second's run exactly: it runs")
	assert_true(Hound.dashes(Vector3.ZERO, Vector3(Hound.RUN_SPEED + 0.5, 0, 0)))
	assert_false(Hound.dashes(Vector3.ZERO, Vector3(0, 50, 3)), "only the way over the ground counts")
	# A dash is there sooner than the run to something half as far.
	assert_true(is_equal_approx(Hound.travel_time(Vector3.ZERO, Vector3(20, 0, 0)), 20.0 / Hound.DASH_SPEED + 0.15))
	assert_true(Hound.travel_time(Vector3.ZERO, Vector3(20, 0, 0)) < Hound.travel_time(Vector3.ZERO, Vector3(9, 0, 0)))
	assert_true(is_equal_approx(Hound.travel_time(Vector3.ZERO, Vector3(4.5, 0, 0)), 0.65), "a short run takes what it took")
	var scene := Node3D.new()
	track(scene)
	var me := _body(Vector3(0, 0.9, 0))
	var pair: Array = Hound.call_pair(scene, me, null, 30.0, false)
	for i in 12:
		for h in pair:
			h._advance(0.05)
	var far := _body(Vector3(0, 0.9, -20))
	for h in pair:
		var was: Vector3 = h.spot()
		h.set_prey(far)
		h._advance(0.05)
		assert_true(h.is_dashing(), "its prey is 20 m off: it dashes")
		assert_true(h.spot().distance_to(was) > 1.5, "a dash covers ground: %s m in a frame" % h.spot().distance_to(was))
	for i in 14:
		for h in pair:
			h._advance(0.05)
	for h in pair:
		assert_false(h.is_dashing(), "the dash ends where it bites")
		assert_true(h.spot().distance_to(Vector3(0, 0, -20)) < 1.3, "and it is there in well under a second")
	# Prey close by: it runs, as before.
	var near := _body(Vector3(4, 0.9, -20))
	for h in pair:
		h.set_prey(near)
		h._advance(0.05)
		assert_false(h.is_dashing())
	# Back to heel from far off is no dash: only prey is dashed at.
	for h in pair:
		h.set_prey(null)
		h._advance(0.05)
		assert_false(h.is_dashing())
	var src := PlayerSource.text()
	assert_contains(src, "now + HOUND.travel_time(from, to.global_position)", "a bite waits for the dash, not for a run")
	assert_contains(Keywords.keyword_text("hounds"), "they dash to it")

# --- A third Hound (Slipped Leash's capstone) ----------------------------------------------

func test_a_third_hound() -> void:
	assert_eq(Balance.SLIPPED_LEASH_HOUNDS, 1)
	assert_eq(Hound.side_of(2), 0.0, "neither left nor right")
	# At heel it walks behind the pair; at their prey it takes the far side.
	var heel: Vector3 = Hound.heel_spot(Vector3(5, 0, 5), 0.0, 0.0)
	assert_true(is_equal_approx(heel.x, 5.0))
	assert_true(heel.z > Hound.heel_spot(Vector3(5, 0, 5), 0.0, 1.0).z + 0.5, "behind the two")
	var spot: Vector3 = Hound.flank_spot(Vector3(0, 0, -6), Vector3.ZERO, 0.4, 0.0)
	assert_true(absf(spot.x) < 0.01 and spot.z < -6.5, "straight across from me")
	for side in [-1.0, 1.0]:
		assert_true(spot.distance_to(Hound.flank_spot(Vector3(0, 0, -6), Vector3.ZERO, 0.4, side)) > 0.9, "not on top of the pair")
	var scene := Node3D.new()
	track(scene)
	var me := _body(Vector3(0, 0.9, 0))
	var prey := _body(Vector3(0, 0.9, -6))
	var third: Node3D = Hound.call_one(scene, me, prey, 12.0, false, 2)
	assert_true(third != null)
	assert_eq(float(third.side), 0.0)
	assert_eq(third.legs(), 4)
	assert_true(Hound.call_one(scene, null, prey, 12.0, false, 2) == null, "nobody to follow")
	# A party member's: their machine says how many there are.
	var puppet := _body(Vector3(3, 0.9, 3))
	Hound.show_for(scene, puppet, prey, 20.0, false, 3)
	var pack: Array = puppet.get_meta(Hound.META)
	assert_eq(pack.size(), 3)
	assert_eq(float(pack[2].side), 0.0)
	assert_true(bool(pack[2].auto))
	Hound.show_for(scene, puppet, prey, 15.0, true, 3)
	assert_eq((puppet.get_meta(Hound.META) as Array).size(), 3, "the same three, not one more")
	assert_true(is_same(puppet.get_meta(Hound.META)[2], pack[2]))
	# Off the Chain is over there: the third sinks, the pair stays.
	Hound.show_for(scene, puppet, prey, 15.0)
	assert_eq((puppet.get_meta(Hound.META) as Array).size(), 2)
	assert_true(pack[2].leaving())
	assert_false(pack[0].leaving() or pack[1].leaving())
	Hound.show_for(scene, puppet, null, 0.0)
	assert_true(pack[0].leaving() and pack[1].leaving())
	# In the rules: it bites, lunges and drags like the other two, for as long as Off the Chain lasts.
	var src := PlayerSource.text()
	assert_contains(src, "if _capstone(\"shadow_slipped_leash\"):\n\t\t\t_add_third_hound()")
	assert_contains(src, "if _hound_bite_at.size() > Balance.HOUND_COUNT and not status.has(OFF_THE_CHAIN_FX):\n\t\t_third_hound_gone()")
	assert_contains(src, "for i in _hound_bite_at.size():\n\t\t_hound_hit(foe, Balance.HOUND_LUNGE, HOUND_LUNGE_ID)", "every Hound out lunges")
	assert_contains(src, "\"count\": maxi(_hound_bite_at.size(), Balance.HOUND_COUNT)")
	assert_contains(FileAccess.get_file_as_string("res://scripts/net/net.gd"), "int(extra.get(\"count\", 2))")

# --- Bring It Down ---------------------------------------------------------------------------

func test_bring_it_down() -> void:
	var p := _player()
	var r := _file("bringitdown")
	assert_true(r != null)
	assert_eq(str(r.id), "bringitdown")
	assert_eq(str(r.display_name), "Bring It Down")
	assert_eq(float(r.cooldown), 10.0)
	assert_eq(float(Abilities.get_resource("bringitdown").cooldown), 10.0)
	assert_eq(int(r.resource_cost), 0, "it costs no Rage")
	assert_eq(int(r.resource_generated), 0, "and builds none")
	assert_eq(Abilities.resource_of("bringitdown"), "")
	assert_eq(int(r.weapon_requirement), 1, "a melee weapon, like the rest of the kit")
	assert_eq(int(r.cast_type), 0)
	assert_false(bool(r.requires_target), "it is their prey they drag down")
	assert_true(r.tags.has("Ability") and r.tags.has("Shadow") and not r.tags.has("Spell"))
	assert_eq(str(r.damage_type), "shadow")
	assert_true(Abilities.ALL.has("bringitdown") and Abilities.DRAFT_POOL.has("bringitdown") and SkillCards.ALL.has("bringitdown"))
	assert_eq(Abilities.category_of("bringitdown"), "shadow")
	assert_eq(SkillCards.ability_of("bringitdown"), "bringitdown")
	assert_eq(SkillCards.level_of("bringitdown"), 28)
	assert_false(Abilities.ICON_FORM.has("bringitdown"), "an icon of its own")
	assert_true(p.on_gcd("bringitdown"))
	assert_false(HoundsKit.rouses(Abilities.resource_of("bringitdown"), float(Abilities.cost_of("bringitdown"))), "free: it Rouses nothing")
	assert_false(HoundsKit.calls_hounds("bringitdown"), "it sends them away, it never calls them")
	assert_eq(_typed_number(str(r.description)), "")
	var tip := Abilities.tooltip("bringitdown")
	assert_eq(TextFill.leftover(tip), "")
	assert_false(tip.contains("?"), tip)
	assert_false(tip.contains("Frost Bolt"), "real damage numbers")
	assert_contains(tip, "Hounds")
	assert_true(Keywords.mentions(tip).has("k:hounds"))
	assert_contains(tip, "Requires a melee weapon")
	# It needs Hounds out, and something for them to drag down.
	assert_eq(HoundsKit.bring_down_error(false, true), HoundsKit.BRING_DOWN_NO_HOUNDS)
	assert_eq(HoundsKit.bring_down_error(false, false), HoundsKit.BRING_DOWN_NO_HOUNDS)
	assert_eq(HoundsKit.bring_down_error(true, false), HoundsKit.BRING_DOWN_NO_PREY)
	assert_eq(HoundsKit.bring_down_error(true, true), "")
	# The Drag Down is the one they deal when their time is up.
	var src := PlayerSource.text()
	var from := src.find("func _bring_it_down()")
	var body := src.substr(from, src.find("\nfunc ", from + 10) - from)
	assert_contains(body, "status.remove(HOUNDS_FX)")
	assert_contains(body, "_hounds_gone(true)")
	assert_contains(src, "\t\t\t_bring_it_down()")
	assert_contains(src, "return bring_down_error(hounds_out(), _prey_ok(_hound_prey) or (_has_valid_target() and _prey_ok(target)))")
	# Its card has a place of its own in the list.
	var mine := int(SkillCards.get_resource("bringitdown").sort_order)
	for id in SkillCards.ALL:
		if id != "bringitdown":
			assert_ne(int(SkillCards.get_resource(id).sort_order), mine, "%s has the same sort order" % id)

# --- What the talents do (the talents themselves: tests/test_shadow_talents.gd) --------------

func test_talent_rules() -> void:
	var p := _player()
	# Lean and Hungry: faster bites, on top of Haste and Off the Chain.
	assert_true(is_equal_approx(HoundsKit.hound_bite_interval(1.0, false, 12.0), 1.5 / 1.12))
	assert_true(is_equal_approx(HoundsKit.hound_bite_interval(1.2, true, 12.0), 1.5 / (1.2 * 1.5 * 1.12)), "the three multiply")
	assert_eq(HoundsKit.hound_bite_interval(1.0, false, -5.0), 1.5)
	# Long Night and Slipped Leash: more time.
	assert_eq(HoundsKit.hound_time(), 30.0)
	assert_eq(HoundsKit.hound_time(6.0), 36.0)
	assert_eq(HoundsKit.off_the_chain_time(), 10.0)
	assert_eq(HoundsKit.off_the_chain_time(4.0), 14.0)
	assert_eq(HoundsKit.hounds_until_unchained(130.0, 110.0, HoundsKit.off_the_chain_time(4.0)), 144.0, "the Hounds stay as much longer as it lasts")
	# Pack Leader, Pincer and Take It With You: each adds to its hits, under its own name on the meter.
	assert_eq(HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_BITE_ID, 0.0, 30.0, 50.0), [], "a bite is no lunge and no Drag Down")
	assert_eq(HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_BITE_ID, 15.0, 30.0, 50.0), [[15.0, "Pack Leader"]])
	assert_eq(HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_LUNGE_ID, 15.0, 30.0, 50.0), [[15.0, "Pack Leader"], [30.0, "Pincer"]])
	assert_eq(HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_DRAG_ID, 15.0, 30.0, 50.0), [[15.0, "Pack Leader"], [50.0, "Take It With You"]])
	assert_eq(HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_DRAG_ID, 0.0, 0.0, 0.0), [])
	var drag := _hit("shadow", HoundsKit.HOUND_TAGS)
	for b in HoundsKit.hound_hit_bonuses(HoundsKit.HOUND_DRAG_ID, 15.0, 30.0, 50.0):
		drag.add_bonus(float(b[0]), str(b[1]))
	var rows: Array = Details.split_amount("hound_drag", 165, false, drag.bonus_parts)
	assert_eq(rows.size(), 3)
	assert_eq(int(rows[0][1]), 100)
	assert_eq(str(rows[1][0]), "bonus:Pack Leader")
	assert_eq(str(rows[2][0]), "bonus:Take It With You")
	assert_eq(int(rows[2][1]), 50)
	# Worked Up's capstone: only while they are Roused.
	assert_eq(Balance.WORKED_UP_CRIT, 10.0)
	assert_eq(HoundsKit.worked_up_crit(true, true), 10.0)
	assert_eq(HoundsKit.worked_up_crit(true, false), 0.0)
	assert_eq(HoundsKit.worked_up_crit(false, true), 0.0)
	# Out of the Hole.
	assert_eq(HoundsKit.hole_feed(200, 50.0), 100.0)
	assert_eq(HoundsKit.hole_feed(200, 0.0), 0.0)
	assert_eq(HoundsKit.hole_feed(-5, 50.0), 0.0)
	# Stand Over: a share of maximum health, with its own line on the healing meter.
	assert_eq(HoundsKit.stand_over_heal(2000, 2.0), 40)
	assert_eq(HoundsKit.stand_over_heal(2000, 0.0), 0)
	assert_eq(Details.spell_name(HoundsKit.STAND_OVER_ID), "Stand Over")
	# Share the Kill: only while the Hounds are out.
	assert_eq(HoundsKit.leech_heal_mult(true, 100.0), 2.0)
	assert_eq(HoundsKit.leech_heal_mult(true, 50.0), 1.5)
	assert_eq(HoundsKit.leech_heal_mult(false, 100.0), 1.0)
	assert_eq(HoundsKit.leech_heal_mult(true, 0.0), 1.0)
	# Thick Blood.
	assert_true(is_equal_approx(HoundsKit.rage_decay(Balance.RAGE_DECAY, 45.0), Balance.RAGE_DECAY * 0.55))
	assert_eq(HoundsKit.rage_decay(5.0, 0.0), 5.0)
	assert_eq(HoundsKit.rage_decay(5.0, 150.0), 0.0, "never a gain")
	# Again.
	assert_true(HoundsKit.again_resets(10.0, 15.0))
	assert_false(HoundsKit.again_resets(15.0, 15.0))
	assert_false(HoundsKit.again_resets(0.0, 0.0), "not without the talent")
	# Still Wet's capstone: my own direct hits on an enemy carrying my mark.
	assert_eq(Balance.STILL_WET_PCT, 10.0)
	assert_true(HoundsKit.still_wet_applies(true, true, false, false))
	assert_false(HoundsKit.still_wet_applies(false, true, false, false), "not without the capstone")
	assert_false(HoundsKit.still_wet_applies(true, false, false, false), "an ally's mark is not mine")
	assert_false(HoundsKit.still_wet_applies(true, true, true, false), "no proc: the Hounds have Open Up's own bonus")
	assert_false(HoundsKit.still_wet_applies(true, true, false, true), "no tick")
	# Take It With You's capstone: the enemy died by my hand right after Drag Down hit it.
	assert_eq(Balance.DRAG_KILL_WINDOW, 1.5)
	assert_true(HoundsKit.drag_kill_counts(100.0, 101.5, true))
	assert_false(HoundsKit.drag_kill_counts(102.0, 101.5, true), "too long after")
	assert_false(HoundsKit.drag_kill_counts(100.0, 101.5, false), "somebody else's kill")
	assert_false(HoundsKit.drag_kill_counts(100.0, 0.0, true), "Drag Down never hit it")
	# Pincer's capstone and Feeding Frenzy.
	assert_eq(Balance.PINCER_RAGE, 10.0)
	assert_eq(Balance.FEEDING_FRENZY_TIME, 8.0)
	# Worked Up, Still Wet and Slipped Leash make an effect last longer: the game and the tooltips share this.
	var talents := func(key: String, _field: String) -> float:
		return float({"shadow_still_wet": 4.0, "shadow_worked_up": 2.0, "shadow_slipped_leash": 4.0}.get(key, 0.0))
	Balance.apply_effects()
	assert_eq(Abilities.effect_time_bonus(Effects.get_effect("laid_open"), talents), 4.0)
	assert_eq(Abilities.effect_time_bonus(HoundsKit.make_roused_fx(), talents), 2.0)
	assert_eq(Abilities.effect_time_bonus(HoundsKit.make_off_the_chain_fx(), talents), 4.0)
	assert_eq(Abilities.effect_time_bonus(HoundsKit.make_guard_dogs_fx(), talents), 0.0)
	assert_eq(Abilities.effect_time_bonus(HoundsKit.make_hounds_fx(), talents), 0.0, "Long Night sets their time itself")
	assert_contains(str(_file("offthechain").description), "{chain_time}")
	assert_contains(str(_file("openup").description), "{fx_time}")
	# Where each one is wired in.
	var src := PlayerSource.text()
	for line in ["_gain(\"rage\", _talent(\"shadow_fed\"))",
			"_decay_feed(foe, hole_feed(dealt, hole))",
			"float(stand_over_heal(max_health, stand)), STAND_OVER_ID, true)",
			"rage_decay(RAGE_DECAY, _talent(\"shadow_thick_blood\"))",
			"leech_heal_mult(hounds_out(), _talent(\"shadow_share_the_kill\"))",
			"chance += float(info.get_meta(HOUND_CRIT_META, 0.0))",
			"add_buff(FEEDING_FRENZY_FX, Stats.HASTE, frenzy, Balance.FEEDING_FRENZY_TIME",
			"hound_time(_talent(\"shadow_long_night\"))",
			"again_resets(randf() * 100.0, _talent(\"shadow_again\"))",
			"info.add_bonus(Balance.STILL_WET_PCT, STILL_WET_LABEL)",
			"_talent(\"shadow_lean_and_hungry\")",
			"hound_hit_bonuses(id, _talent(\"shadow_pack_leader\"), _talent(\"shadow_pincer\")",
			"_gain(\"rage\", refund)",
			"if _hounds_roused_next:"]:
		assert_contains(src, line)

func test_it_is_wired_in() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "\t_tick_hounds()\n")
	assert_contains(src, "\t_hounds_on_ability(id)")
	assert_contains(src, "\t_hounds_on_hit(info)")
	assert_contains(src, "\t\t\t_rouse_hounds()")
	assert_contains(src, "HOUND.call_pair(get_tree().current_scene, self")
	assert_contains(src, "_net_fx(\"hounds\"")
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_contains(net, "\"hounds\":")
	assert_contains(net, "HOUND.show_for(w, src, tgt")
