@tool
extends McpTestSuite

# Frost, the bow: Shatter Shot, Glacial Draw, Rimefletch, Coldmark and Icy Retreat.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Effects = preload("res://scripts/core/effects.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const IcePatch = preload("res://scripts/ice_patch.gd")

const NEW := ["shattershot", "glacialdraw", "rimefletch", "coldmark", "icyretreat"]

func suite_name() -> String:
	return "frost_bow"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_the_abilities_are_registered() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "frost", "%s is in the Frost book" % id)
		assert_eq(str(r.damage_type), "frost")
		assert_true(r.tags.has("Frost") and r.tags.has("Ability") and not r.tags.has("Spell"), "%s is a Frost ability" % id)
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		assert_eq(Abilities.weapon_need(r), "a bow")
		assert_eq(Abilities.resource_of(id), "energy", "%s runs on Energy like the other arrows" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s's card has a level" % id)
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])
	# No two cards share a place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if NEW.has(id):
			assert_false(orders.has(order), "%s: sort order %d is taken" % [id, order])
		orders[order] = id
	# No two abilities share a name (the Ranger cast shot is already called Long Draw).
	var names := {}
	for id in Abilities.ALL:
		var n := Abilities.ability_name(id)
		assert_false(names.has(n), "%s and %s are both called %s" % [id, names.get(n, ""), n])
		names[n] = id
	assert_eq(Abilities.ability_name("glacialdraw"), "Glacial Draw")

func test_shatter_shot() -> void:
	var r := Abilities.get_resource("shattershot")
	assert_eq(float(r.weapon_damage_multiplier), 3.78)
	assert_eq(int(r.resource_cost), 30)
	assert_eq(float(r.cooldown), 10.0)
	assert_eq(float(r.radius), 4.0, "the burst reaches 4 m")
	assert_true(bool(r.requires_target))
	assert_eq(Balance.SHATTER_SHOT_FROZEN_PCT, 50.0)
	assert_eq(float(Balance.EXTRA_HITS["shattershot"]), 0.5 * float(Abilities.get_resource("frostbolt").damage), "half a Frost Bolt")
	var p := _player()
	assert_eq(FrostBowKit.shatter_shot_burst(1), 0.5)
	assert_eq(FrostBowKit.shatter_shot_burst(Balance.AOE_TARGET_CAP), 0.5, "up to the cap every burst is whole")
	assert_eq(FrostBowKit.shatter_shot_burst(Balance.AOE_TARGET_CAP * 2), 0.25, "twice the cap: half each")
	assert_true(FrostBowKit.is_arrow_ability("shattershot"))
	var tip := Abilities.tooltip("shattershot")
	assert_contains(tip, "50% more")
	assert_contains(tip, "within 4 m")
	assert_true(Abilities.has_scaling("shattershot"))

func test_glacial_draw() -> void:
	var r := Abilities.get_resource("glacialdraw")
	assert_eq(float(r.weapon_damage_multiplier), 2.97)
	assert_eq(int(r.resource_cost), 40)
	assert_eq(float(r.cooldown), 12.0)
	assert_eq(int(r.cast_type), 1, "a cast")
	assert_eq(float(r.cast_time), 2.0)
	assert_false(bool(r.can_move_while_casting), "you stand still to draw it")
	assert_true(bool(r.requires_target))
	var p := _player()
	assert_eq(FrostBowKit.GLACIAL_DRAW_ID, "glacialdraw")
	assert_false(p.ENEMY_BOLTS.has("glacialdraw"), "it is an arrow, not a bolt")
	assert_true(FrostBowKit.is_arrow_ability("glacialdraw"))
	var tip := Abilities.tooltip("glacialdraw")
	assert_contains(tip, "Cast time: 2 s")
	assert_contains(tip, "12 s cooldown")
	assert_contains(tip, Abilities.ability_name("icepin"))
	assert_contains(tip, "Instant against")

func test_rimefletch() -> void:
	var r := Abilities.get_resource("rimefletch")
	assert_eq(int(r.resource_cost), 20)
	assert_eq(float(r.cooldown), 30.0)
	assert_false(bool(r.requires_target))
	assert_eq(Balance.RIMEFLETCH_SHOTS, 4)
	assert_eq(Balance.RIMEFLETCH_TIME, 15.0)
	assert_eq(Balance.RIMEFLETCH_PCT, 30.0)
	var p := _player()
	assert_false(p.on_gcd("rimefletch"), "off the global cooldown")
	assert_eq(FrostBowKit.rimefletch_damage(200), 60.0, "30% of the shot")
	assert_eq(FrostBowKit.rimefletch_damage(0), 0.0)
	assert_false(FrostBowKit.rimefletch_freezes(false, false), "a fresh target is Chilled")
	assert_true(FrostBowKit.rimefletch_freezes(true, false), "a target I Chilled is Frozen instead")
	assert_true(FrostBowKit.rimefletch_freezes(false, true), "so is one I already Froze")
	assert_false(FrostBowKit.is_arrow_ability("rimefletch"), "it looses no arrow of its own")
	assert_false(Abilities.has_scaling("rimefletch"), "a share of the shot: nothing of its own to scale")
	var tip := Abilities.tooltip("rimefletch")
	assert_contains(tip, "next 4 auto-shots within 15 sec")
	assert_contains(tip, "30% more damage")
	assert_contains(tip, "Does not trigger the global cooldown")

func test_coldmark() -> void:
	var r := Abilities.get_resource("coldmark")
	assert_eq(int(r.resource_cost), 0, "free")
	assert_eq(float(r.cooldown), 20.0)
	assert_true(bool(r.requires_target))
	assert_true(r.on_hit_effect != null and str(r.on_hit_effect.id) == "coldmarked", "it leaves the mark")
	var fx: Resource = Effects.get_effect("coldmarked")
	assert_true(fx != null)
	assert_true(bool(fx.per_caster), "own only: every archer has their own mark")
	assert_true(bool(fx.is_debuff))
	assert_eq(float(fx.duration), 12.0)
	assert_eq(float(fx.duration), float(Balance.EFFECTS["res://data/effects/coldmarked.tres"]["duration"]))
	assert_eq(TextFill.leftover(TextFill.effect(fx)), "")
	var p := _player()
	assert_eq(FrostBowKit.COLDMARK_FX, "coldmarked")
	assert_false(FrostBowKit.is_arrow_ability("coldmark"), "marking is not an arrow")
	for id in ["frostarrow", "icepin", "stormarrow", "shadowarrow", "flamingarrow"]:
		assert_true(FrostBowKit.is_arrow_ability(id), "%s is an arrow ability" % id)
	for id in ["auto_ranged", "frostbolt", "froststrike", "icyretreat"]:
		assert_false(FrostBowKit.is_arrow_ability(id), "%s is not an arrow ability" % id)
	assert_true(Abilities.get_resource("iceshards") != null and int(Abilities.get_resource("iceshards").weapon_requirement) == 0,
		"Ice Shards needs no weapon, so it works with a bow")
	var tip := Abilities.tooltip("coldmark")
	assert_contains(tip, "for 12 sec")
	assert_contains(tip, "Ice Shard charge")
	# Own only, on a real status container.
	var foe: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	foe.add_child(st)
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	st.apply(fx, ally)
	assert_false(st.has_from(FrostBowKit.COLDMARK_FX, me), "an ally's mark gives me nothing")
	st.apply(fx, me)
	assert_true(st.has_from(FrostBowKit.COLDMARK_FX, me))
	assert_true(st.has_from(FrostBowKit.COLDMARK_FX, ally), "and theirs is still there")

func test_icy_retreat() -> void:
	var r := Abilities.get_resource("icyretreat")
	assert_eq(int(r.resource_cost), 15)
	assert_eq(float(r.cooldown), 15.0)
	assert_eq(float(r.radius), 4.0)
	assert_false(bool(r.requires_target))
	assert_true(r.tags.has("Movement"))
	assert_eq(Balance.ICY_RETREAT_DISTANCE, 8.0)
	assert_eq(Balance.ICY_RETREAT_TIME, 4.0)
	assert_eq(Balance.ICY_RETREAT_TICK, 1.0)
	var chilled: Resource = load("res://data/effects/chilled.tres")
	assert_true(float(chilled.duration) > Balance.ICY_RETREAT_TICK, "an enemy standing on the ice stays Chilled between ticks")
	assert_eq(IcePatch.ticks(Balance.ICY_RETREAT_TIME, Balance.ICY_RETREAT_TICK), 4)
	var centre := Vector3(2, 0, 3)
	assert_true(IcePatch.inside(centre, 4.0, Vector3(5, 3, 3)), "3 m away (height ignored)")
	assert_false(IcePatch.inside(centre, 4.0, Vector3(7, 0, 3)), "5 m away")
	assert_true(IcePatch.inside(centre, 4.0, Vector3(6.5, 0, 3), 0.6), "a big enemy overlapping the edge counts")
	assert_true(_player().on_gcd("icyretreat"))
	var tip := Abilities.tooltip("icyretreat")
	assert_contains(tip, "up to 8 m backward")
	assert_contains(tip, "for 4 sec")
	assert_contains(tip, "within 4 m")
	assert_contains(tip, Abilities.ability_name("frostarrow"))
	assert_contains(tip, "costs no Energy")
	# Icy Footing: the next Frost Arrow is free (Frost Arrow has no cooldown to reset: the filler).
	assert_eq(float(Abilities.get_resource("frostarrow").cooldown), 0.0)
	var src := PlayerSource.text()
	assert_contains(src, "\t\treturn 0.0   # Icy Footing", "Icy Footing makes it free")
	assert_contains(src, "status.remove(ICY_FOOTING_FX)", "and is used up when paid")
	assert_false(src.contains("cooldowns.erase(\"frostarrow\")"), "no cooldown left to reset")
	assert_contains(src, "Your next Frost Arrow costs no Energy.")

# --- The bow talents ------------------------------------------------------------------

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

## key -> [slot, ranks, values, required ability]. Winter Hunt's column group (the
## right edge), rows 1-5 (the rest of the group: tests/test_frost_tree.gd).
const BOW_TALENTS := {
	"frost_cold_draw": ["frost_r1c14", 3, [2.0, 4.0, 6.0], ""],
	"frost_frozen_quarry": ["frost_r1c16", 3, [4.0, 8.0, 12.0], ""],
	"frost_pinning_frost": ["frost_r2c14", 3, [5.0, 10.0, 15.0], ""],
	"frost_black_ice": ["frost_r2c15", 3, [33.0, 67.0, 100.0], "icyretreat"],
	"frost_clean_shatter": ["frost_r2c16", 3, [7.0, 13.0, 20.0], "shattershot"],
	"frost_cold_harvest": ["frost_r3c15", 3, [3.0, 7.0, 10.0], "rimefletch"],
	"frost_thin_ice": ["frost_r4c15", 3, [0.3, 0.7, 1.0], "glacialdraw"],
}

func test_the_bow_talents_sit_together() -> void:
	for key in BOW_TALENTS:
		var want: Array = BOW_TALENTS[key]
		var id := Talents.id_for_key(str(key))
		assert_eq(id, str(want[0]), "%s has its slot" % key)
		var t := Talents.get_talent(id)
		assert_false(bool(t.get("placeholder", true)), "%s is a real talent" % key)
		assert_true(bool(t.get("implemented", false)), "%s has an effect" % key)
		assert_eq(Talents.max_rank(id), int(want[1]), "%s: ranks" % key)
		assert_eq(t.get("values", []), want[2], "%s: values" % key)
		assert_eq(Talents.required_ability(id), str(want[3]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % key)
		assert_false(tip.contains("?"), "%s: %s" % [key, tip])
		# Winter Hunt's group, in the top five rows.
		assert_eq(Talents.group_of(id), "Winter Hunt", "%s is in Winter Hunt's columns" % key)
		assert_true(Talents.tier_of(id) <= 4, "%s is in rows 1-5" % key)
	assert_eq(Talents.get_talent(Talents.id_for_key("frost_clean_shatter")).get("values2", []), [1.5, 2.5, 4.0])
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("frost_cold_draw"), "2 / 4 / 6 Energy, 2 / 4 / 6 Fury")
	assert_eq(Talents.get_talent(Talents.id_for_key("frost_cold_draw")).get("values2", []), [0.1, 0.2, 0.3], "Cold Draw: mana points")
	assert_contains(d.call("frost_cold_draw"), "once every 1 sec")
	assert_contains(d.call("frost_black_ice"), "33 / 67 / 100% chance")
	assert_contains(d.call("frost_clean_shatter"), "refunds 7 / 13 / 20 Energy")
	assert_contains(d.call("frost_clean_shatter"), "1.5 / 2.5 / 4 sec")
	assert_contains(d.call("frost_cold_harvest"), "3 / 7 / 10 Energy")
	assert_contains(d.call("frost_thin_ice"), "0.3 / 0.7 / 1 sec faster")
	assert_contains(d.call("frost_frozen_quarry"), "4 / 8 / 12% more damage")
	assert_contains(d.call("frost_pinning_frost"), "targets you have rooted")

func test_talent_maths() -> void:
	var p := _player()
	assert_eq(FrostBowKit.thin_ice_cast(2.0, 0.5, true), 1.5)
	assert_eq(FrostBowKit.thin_ice_cast(2.0, 1.0, true), 1.0)
	assert_eq(FrostBowKit.thin_ice_cast(2.0, 1.0, false), 2.0, "only on a target I have Chilled")
	assert_eq(FrostBowKit.thin_ice_cast(2.0, 0.0, true), 2.0, "no talent, no change")
	assert_eq(FrostBowKit.thin_ice_cast(0.5, 1.0, true), 0.2, "never under 0.2 s")
	assert_eq(FrostBowKit.clean_shatter_cooldown(10.0, 2.0), 8.0)
	assert_eq(FrostBowKit.clean_shatter_cooldown(10.0, 4.0), 6.0)
	assert_eq(FrostBowKit.clean_shatter_cooldown(1.0, 4.0), 0.0, "never below zero")
	# They do nothing until their ability is learned; Cold Draw is generic.
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	pd.talents = {Talents.id_for_key("frost_cold_draw"): 3, Talents.id_for_key("frost_thin_ice"): 3,
		Talents.id_for_key("frost_frozen_quarry"): 3}
	assert_eq(pd.talent_value("frost_cold_draw"), 6.0)
	assert_eq(pd.talent_value("frost_frozen_quarry"), 12.0, "a keyword talent needs no ability")
	assert_eq(pd.talent_value("frost_thin_ice"), 0.0, "Glacial Draw is not learned")
	pd.learned_abilities.append("glacialdraw")
	assert_eq(pd.talent_value("frost_thin_ice"), 1.0)
	pd.free()

## The Frost book was rearranged for the bow talents (save version 4 -> 5): removed
## talents give their points back, moved ones keep theirs, and a slot that one
## talent left and another took is never mixed up.
func test_old_saves_keep_their_frost_points() -> void:
	const SaveSystemScript = preload("res://scripts/save_system.gd")
	assert_true(SaveSystemScript.VERSION >= 5)
	var old := {
		"frost_r1c3": 3,   # Frozen Focus: stays
		"frost_r1c4": 3,   # Deep Chill: removed
		"frost_r2c6": 3,   # Quickened Frost: moves left (Black Ice is in r2c6 now)
		"frost_r2c4": 2,   # Pinning Frost
		"frost_r3c2": 3,   # Endless Winter: removed (Deep Hoarfrost is in r3c2 now)
		"frost_r3c6": 2,   # Bitter Cold: moves to row 1 (Clean Shatter is in r3c6 now)
		"frost_r4c5": 1,   # Deep Hoarfrost: moves to row 3 (Cold Harvest is in r4c5 now)
		"frost_r5c4": 2,   # Third Bite
		"frost_r5c6": 3,   # Winter's Clarity: removed (Marked Prey is in r5c6 now)
		"fire_r1c1": 3,    # another book: untouched
	}
	var v5: Dictionary = Talents.rearranged(old, Talents.FROST_BOW_MOVED, Talents.FROST_BOW_REMOVED)
	assert_eq(v5, {"frost_r1c3": 3, "frost_r2c3": 3, "frost_r2c5": 2, "frost_r1c2": 2, "frost_r3c2": 1,
		"frost_r5c3": 2, "fire_r1c1": 3})
	# The next steps moved Frost talents again; then the column-group tree refunded every
	# point (Talents.TREE_VERSION), so LINKS_MOVED keeps no Frost entries any more.
	var now: Dictionary = Talents.rearranged(v5, Talents.LINKS_MOVED, [])
	assert_eq(now, v5, "nothing Frost moves on the 5 -> 6 step now")
	# (Those slots are gone since the ribbon layout; the refund drops their points.)
	for id in Talents.FROST_BOW_MOVED.values():
		assert_false(Talents.MOVED.has(str(id)), "the every-load table never touches %s" % id)
	for id in Talents.FROST_BOW_MOVED:
		assert_false(Talents.MOVED.has(str(id)))
