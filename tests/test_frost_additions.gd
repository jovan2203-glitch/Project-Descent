@tool
extends McpTestSuite

# Frost, second batch: Coldspike, Sleetwave, Deepwinter, Rimelock, Snow Ward,
# Winter Hide, Rime Edge, Icebreaker and Icepin - and the cooldown every
# interrupt shares.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const Shields = preload("res://scripts/core/shields.gd")
const SleetWave = preload("res://scripts/sleet_wave.gd")

const NEW := ["coldspike", "sleetwave", "deepwinter", "rimelock", "snowward", "winterhide", "rimeedge", "icebreaker", "icepin"]

func suite_name() -> String:
	return "frost_additions"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func test_new_abilities_are_registered() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "frost", "%s is in the Frost book" % id)
		assert_eq(str(r.damage_type), "frost")
		assert_true(r.tags.has("Frost"), "%s is tagged Frost" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s's card has a level" % id)
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_false(Abilities.tooltip(id).contains("{"), "%s: every number in the description is filled in: %s" % [id, Abilities.tooltip(id)])
		# Weapon abilities are Abilities, everything else is a Spell.
		assert_eq(r.tags.has("Ability"), int(r.weapon_requirement) != 0, "%s: Ability exactly when it needs a weapon" % id)
		assert_eq(r.tags.has("Spell"), int(r.weapon_requirement) == 0, "%s: Spell exactly when it needs none" % id)

func test_coldspike() -> void:
	var r := Abilities.get_resource("coldspike")
	assert_eq(int(r.cast_type), 1, "a cast")
	assert_eq(float(r.cast_time), 3.0)
	assert_eq(float(r.cooldown), 3.0)
	assert_eq(float(r.damage), 3.0 * float(Abilities.get_resource("frostbolt").damage), "3 Frost Bolts")
	assert_eq(Balance.COLDSPIKE_FROZEN_PCT, 25.0)
	assert_true(bool(r.requires_target))
	assert_true(_player().ENEMY_BOLTS.has("coldspike"), "cast at an enemy like Kiln Blast")

func test_sleetwave() -> void:
	var r := Abilities.get_resource("sleetwave")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 10.0)
	assert_eq(float(r.radius), 12.0, "travels 12 m")
	assert_eq(float(r.damage), 0.8)
	assert_true(r.on_hit_effect != null and str(r.on_hit_effect.id) == "chilled", "Chills what it passes")
	assert_false(bool(r.requires_target))
	var o := Vector3(2, 0, 3)
	var fwd := Vector3(0, 0, -1)
	var a: Vector2 = SleetWave.along_side(o, fwd, Vector3(3, 5, -1))
	assert_true(absf(a.x - 4.0) < 0.0001 and absf(a.y - 1.0) < 0.0001, "4 m along, 1 m to the side (height ignored), got %s" % a)
	assert_true(SleetWave.in_path(o, fwd, Vector3(3, 0, -1), 12.0, 3.0), "inside the strip")
	assert_false(SleetWave.in_path(o, fwd, Vector3(4, 0, -1), 12.0, 3.0), "2 m to the side of a 3 m wide wave")
	assert_true(SleetWave.in_path(o, fwd, Vector3(4, 0, -1), 12.0, 3.0, 0.6), "a big enemy overlapping the edge counts")
	assert_false(SleetWave.in_path(o, fwd, Vector3(2, 0, 5), 12.0, 3.0), "behind the caster")
	assert_false(SleetWave.in_path(o, fwd, Vector3(2, 0, -10), 12.0, 3.0), "13 m away: past the end")
	assert_true(SleetWave.in_path(o, fwd, Vector3(2, 0, -9), 12.0, 3.0), "12 m: the far end")
	assert_false(SleetWave.reached(o, fwd, Vector3(2, 0, -5), 6.0), "the wave is 6 m out, the enemy 8 m")
	assert_true(SleetWave.reached(o, fwd, Vector3(2, 0, -5), 8.0))
	assert_eq(SleetWave.travel_time(12.0, Balance.SLEETWAVE_SPEED), 0.5)
	assert_eq(Balance.aoe_share(10), 0.5, "10 enemies in the strip share 5 enemies' damage")

func test_deepwinter() -> void:
	var r := Abilities.get_resource("deepwinter")
	assert_eq(float(r.cooldown), 120.0, "2 min cooldown")
	assert_eq(Balance.DEEPWINTER_TIME, 15.0)
	var p := _player()
	var chilled: Resource = load("res://data/effects/chilled.tres")
	var frozen: Resource = load("res://data/effects/frozen.tres")
	var rooted: Resource = load("res://data/effects/rooted.tres")
	assert_eq(str(FrostMoreKit.winter_swap(chilled, true).id), "frozen", "a Chill is a Freeze instead")
	assert_eq(str(FrostMoreKit.winter_swap(chilled, false).id), "chilled", "not without Deepwinter")
	assert_eq(str(FrostMoreKit.winter_swap(frozen, true).id), "frozen")
	assert_eq(str(FrostMoreKit.winter_swap(rooted, true).id), "rooted", "other effects are left alone")
	assert_true(FrostMoreKit.winter_swap(null, true) == null)

func test_snow_ward() -> void:
	var r := Abilities.get_resource("snowward")
	assert_eq(float(r.cooldown), 60.0, "1 min cooldown")
	assert_eq(float(r.radius), 20.0, "allies within 20 m")
	assert_eq(Balance.SNOW_WARD_SHARE, 0.6, "60% of a Heal")
	assert_eq(Balance.SNOW_WARD_TIME, 10.0)
	assert_eq(float(Shields.ward_fx(0.0).duration), 10.0)
	assert_eq(float(Shields.ward_fx(5.0).stat_modifiers.get("armor%", 0.0)), 5.0, "Hardened Frost")
	assert_eq(Shields.ward_total(0, 100), 100)
	assert_eq(Shields.ward_total(150, 100), 150, "a smaller ward never shrinks the one that is there")
	assert_eq(Shields.ward_total(40, 100), 100, "it does not stack")
	var caster: Node = track(Node.new())
	var st := _status()
	Shields.set_ward(st, caster, 100, 0.0)
	assert_eq(int(st.absorb_left(Shields.WARD_ID)), 100)
	assert_true(st.has_from(Shields.WARD_ID, caster))
	Shields.set_ward(st, caster, 60, 0.0)
	assert_eq(int(st.absorb_left(Shields.WARD_ID)), 100)
	assert_eq(int(st.absorb_damage(130)), 30, "the shield soaks 100 of 130")
	assert_false(st.has(Shields.WARD_ID), "used up")

func test_winter_hide() -> void:
	var r := Abilities.get_resource("winterhide")
	assert_eq(float(r.cooldown), 60.0, "1 min cooldown")
	var p := _player()
	var fx: Resource = FrostMoreKit.make_winter_hide_fx()
	assert_eq(float(fx.duration), 8.0)
	assert_eq(float(fx.damage_mod_pct), -30.0, "30% less damage")
	assert_true(bool(fx.modifies_incoming), "on damage taken")
	assert_true(FrostMoreKit.winter_hide_chills(PackedStringArray(["Physical", "Melee"]), false), "a melee hit")
	assert_false(FrostMoreKit.winter_hide_chills(PackedStringArray(["Physical", "Melee"]), true), "not damage over time")
	assert_false(FrostMoreKit.winter_hide_chills(PackedStringArray(["Fire", "Spell", "Projectile"]), false), "not a spell or an arrow")

func test_rime_edge() -> void:
	var r := Abilities.get_resource("rimeedge")
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(Balance.RIME_EDGE_TIME, 12.0)
	assert_eq(float(r.damage), 0.15, "0.15 Frost Bolts extra")
	assert_eq(int(r.weapon_requirement), 1, "needs a melee weapon")
	assert_true(r.on_hit_effect != null and str(r.on_hit_effect.id) == "chilled", "its hit Chills")
	var p := _player()
	var melee := PackedStringArray(["Ability", "Frost", "Melee"])
	assert_true(FrostMoreKit.rime_edge_applies(melee, false, false, 10))
	assert_false(FrostMoreKit.rime_edge_applies(melee, true, false, 10), "never on a proc (so never on its own hit)")
	assert_false(FrostMoreKit.rime_edge_applies(melee, false, true, 10), "not on ticks")
	assert_false(FrostMoreKit.rime_edge_applies(melee, false, false, 0), "the hit has to land")
	assert_false(FrostMoreKit.rime_edge_applies(PackedStringArray(["Ability", "Frost", "Ranged"]), false, false, 10), "melee only")
	assert_true(Abilities.tags_of("auto_melee").has("Melee"), "auto-attacks count")

func test_icebreaker() -> void:
	var r := Abilities.get_resource("icebreaker")
	assert_eq(float(r.cooldown), 8.0)
	assert_eq(float(r.weapon_damage_multiplier), 2.0)
	assert_eq(Balance.ICEBREAKER_FROZEN_MULT, 3.5)
	assert_eq(int(r.weapon_requirement), 1)
	var p := _player()
	assert_eq(FrostMoreKit.icebreaker_coef(10.0, 2.0, 0.0, false), 20.0, "2x weapon damage")
	assert_eq(FrostMoreKit.icebreaker_coef(10.0, 2.0, 0.0, true), 35.0, "3.5x on a target I have Frozen")

func test_icepin() -> void:
	var r := Abilities.get_resource("icepin")
	assert_eq(float(r.cooldown), 15.0)
	assert_eq(float(r.weapon_damage_multiplier), 1.0)
	assert_eq(int(r.weapon_requirement), 2, "a bow ability")
	assert_true(r.on_hit_effect != null and str(r.on_hit_effect.id) == "rooted")
	assert_eq(float(r.on_hit_effect.duration), 3.0, "roots for 3 s")
	assert_true(bool(r.on_hit_effect.root))

func test_rimelock() -> void:
	var r := Abilities.get_resource("rimelock")
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(float(Balance.INTERRUPT_LOCKOUT.get("rimelock", 0.0)), 3.0, "3 s lockout")
	assert_true(r.tags.has("Interrupt"))
	assert_false(_player().on_gcd("rimelock"), "off the global cooldown")

## Honed Rime, Clean Break and Piercing Cold took the slots of Frostbite Edge,
## Chilled Mind and Frozen Veins.
func test_new_talents() -> void:
	const Talents = preload("res://scripts/talents.gd")
	const TalentIcons = preload("res://scripts/talent_icons.gd")
	var want := {
		"frost_honed_rime": ["frost_r4c3", [0.05, 0.1, 0.15], "rimeedge"],
		"frost_clean_break": ["frost_r7c2", [10.0, 20.0], "icebreaker"],   # moved down two rows (Talents.LINKS_MOVED)
		"frost_piercing_cold": ["frost_r6c3", [10.0, 20.0], "coldspike"],
	}
	for key in want:
		var id := Talents.id_for_key(key)
		var vals: Array = want[key][1]
		assert_eq(id, str(want[key][0]), "%s sits where it should" % key)
		assert_eq(Talents.max_rank(id), vals.size(), "%s ranks" % key)
		for i in vals.size():
			assert_eq(Talents.value_at(id, i + 1), float(vals[i]), "%s rank %d" % [key, i + 1])
		assert_eq(str(Talents.get_talent(id).get("requires", "")), str(want[key][2]))
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
	for gone in ["frost_ability_proc", "frost_spell_crit", "frost_veins_sp"]:
		assert_eq(Talents.id_for_key(gone), "", "%s is gone" % gone)
	# Honed Rime: 0.15 -> 0.2 / 0.25 / 0.3 Frost Bolts.
	var edge := float(Abilities.get_resource("rimeedge").damage)
	var honed := Talents.id_for_key("frost_honed_rime")
	for i in 3:
		assert_true(absf(edge + Talents.value_at(honed, i + 1) - [0.2, 0.25, 0.3][i]) < 0.0001, "Honed Rime rank %d" % (i + 1))
	# Piercing Cold: 25% -> 35 / 45%.
	var pierce := Talents.id_for_key("frost_piercing_cold")
	assert_eq(Balance.COLDSPIKE_FROZEN_PCT + Talents.value_at(pierce, 1), 35.0)
	assert_eq(Balance.COLDSPIKE_FROZEN_PCT + Talents.value_at(pierce, 2), 45.0)
	# Clean Break gives back Rage, which is what Icebreaker costs (never more than it cost).
	assert_eq(Abilities.resource_of("icebreaker"), "rage")
	assert_true(Talents.value_at(Talents.id_for_key("frost_clean_break"), 2) <= float(Abilities.get_resource("icebreaker").resource_cost))

func test_interrupts_share_a_cooldown() -> void:
	var p := _player()
	assert_eq(Balance.INTERRUPT_SHARED_COOLDOWN, 15.0)
	# Every interrupt is listed, and none has a cooldown under the shared one.
	for id in Abilities.PATHS:
		var r := Abilities.get_resource(id)
		assert_eq(r.tags.has("Interrupt"), Balance.INTERRUPT_LOCKOUT.has(id), "%s: tagged Interrupt exactly when it is one" % id)
	for id in Balance.INTERRUPT_LOCKOUT:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s is an ability" % id)
		assert_true(float(r.cooldown) >= Balance.INTERRUPT_SHARED_COOLDOWN, "%s: no interrupt under 15 s (it has %s)" % [id, r.cooldown])
		assert_false(p.on_gcd(id), "%s is off the global cooldown" % id)
		assert_true(Abilities.is_interrupt(id))
		assert_true(Abilities.tooltip(id).contains(Abilities.interrupt_note()), "%s's tooltip says so" % id)
	assert_false(Abilities.is_interrupt("frostbolt"))
	# Jolt used with everything else ready: all the others wait 15 s.
	var after: Dictionary = p.interrupt_cooldowns("jolt", 15.0, {})
	assert_eq(after.size(), Balance.INTERRUPT_LOCKOUT.size(), "only the interrupts")
	for id in Balance.INTERRUPT_LOCKOUT:
		assert_eq(float(after[id]), 15.0, "%s after Jolt" % id)
	# A longer own cooldown stays longer; one already further out is not shortened.
	after = p.interrupt_cooldowns("counterspell", 24.0, {"rimelock": 18.0, "jolt": 4.0, "frostnova": 9.0})
	assert_eq(float(after["counterspell"]), 24.0)
	assert_eq(float(after["rimelock"]), 18.0, "already longer: left alone")
	assert_eq(float(after["jolt"]), 15.0, "4 s left becomes 15")
	assert_eq(float(after["hush"]), 15.0)
	assert_false(after.has("frostnova"), "other abilities are untouched")
	# An interrupt whose own cooldown were shorter would still wait the shared one.
	assert_eq(float(p.interrupt_cooldowns("jolt", 8.0, {})["jolt"]), 15.0)
