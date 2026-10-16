@tool
extends McpTestSuite

# Arcane tank: a dodge tank with a melee weapon in each hand, on cooldowns alone.
# It lives on Reflections (images of itself): each one adds Dodge and raises the
# Dodge cap; a dodge uses one up and it shatters (damage around the tank, time
# off every Arcane cooldown). Double Up, Ripple and Full Set make Reflections;
# Missed Beat answers a shatter; Stand-In, Trade Places, Crowd of One and Decoy
# spend or keep them.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")
const CombatSystem = preload("res://scripts/core/combat_system.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Items = preload("res://scripts/items.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const Reflections = preload("res://scripts/reflections.gd")
const Decoy = preload("res://scripts/decoy.gd")

const KIT := ["doubleup", "ripple", "fullset", "missedbeat", "standin", "tradeplaces", "crowdofone", "decoy"]
const NAMES := {"doubleup": "Double Up", "ripple": "Ripple", "fullset": "Full Set", "missedbeat": "Missed Beat",
	"standin": "Stand-In", "tradeplaces": "Trade Places", "crowdofone": "Crowd of One", "decoy": "Decoy"}

var _saved_records := {}

func suite_name() -> String:
	return "arcane_tank"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

func _player() -> GDScript:
	return load("res://scripts/player.gd")

## The ability's data straight from its file (what the game loads when it starts).
func _file(id: String) -> Resource:
	return ResourceLoader.load("res://data/abilities/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE)

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _has_method(path: String, method: String) -> bool:
	for m in PlayerSource.methods_of(load(path)):
		if str(m["name"]) == method:
			return true
	return false

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	pd.level = 50
	return pd

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_arcane_and_needs_a_weapon_in_each_hand() -> void:
	for id in KIT:
		var r := _file(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_eq(str(r.display_name), str(NAMES[id]))
		assert_true(bool(r.requires_dual_wield), "%s needs a weapon in each hand" % id)
		assert_false(bool(r.requires_two_hand), "%s needs no two-handed weapon" % id)
		assert_false(bool(r.requires_shield), "%s needs no shield" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s: melee weapons" % id)
		assert_eq(Abilities.weapon_need(r), "a melee weapon in each hand")
		assert_eq(int(r.resource_type), 0, "%s has no resource: cooldowns alone" % id)
		assert_eq(int(r.resource_cost), 0)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_true(float(Abilities.get_resource(id).cooldown) > 0.0, "%s has a cooldown" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Arcane") and not r.tags.has("Spell"), "%s is an Arcane ability" % id)
		assert_eq(str(r.damage_type), "arcane")
		assert_true(r.get("on_hit_effect") == null, "%s applies no effect" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s: its card has a level" % id)
		assert_eq(SkillCards.level_of(id) % 2, 0, "%s: abilities come on even levels" % id)
		assert_eq(Abilities.category_of(id), "arcane")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var text := Abilities.fill(id, str(r.description), Callable(), {})
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % id)
		assert_false(text.contains("?"), "%s: %s" % [id, text])
		assert_false(text.contains("Frost Bolt"), "%s: real damage numbers" % id)
		assert_contains(Abilities.tooltip(id), "Requires a melee weapon in each hand")
	# No two cards share a place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if KIT.has(id):
			assert_false(orders.has(order), "%s: sort order %d is taken by %s" % [id, order, orders.get(order, "")])
		orders[order] = id
	for id in SkillCards.ALL:
		if not KIT.has(id):
			for mine in KIT:
				assert_ne(int(SkillCards.get_resource(id).sort_order), int(SkillCards.get_resource(mine).sort_order),
					"%s and %s share a sort order" % [id, mine])

func test_double_up() -> void:
	var r := Abilities.get_resource("doubleup")
	assert_eq(float(r.cooldown), 5.0)
	assert_eq(float(r.weapon_damage_multiplier), 1.0, "1.0 weapon damage")
	assert_eq(float(r.damage), 0.0)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_true(bool(r.requires_target))
	assert_true(r.tags.has("Melee"))
	assert_true(Abilities.uses_weapon_reach("doubleup"))
	assert_true(_player().on_gcd("doubleup"))
	assert_true(Abilities.has_scaling("doubleup"))
	assert_contains(Abilities.tooltip("doubleup"), "creates a Reflection")
	assert_contains(Abilities.tooltip("doubleup"), "with both weapons")

# Double Up and Missed Beat strike with both weapons: one hit of the Main Hand
# and Off Hand weapons' damage together.
func test_strikes_use_both_weapons() -> void:
	var p := _player()
	assert_true(is_equal_approx(float(ArcaneTankKit.dual_hit(0.45, 0.32, 1.0, 0.0)), 0.77))
	assert_true(is_equal_approx(float(ArcaneTankKit.dual_hit(0.45, 0.32, 2.0, 0.1)), 1.64), "multiplier on both, then the ability's own")
	assert_true(is_equal_approx(float(ArcaneTankKit.dual_hit(0.45, 0.0, 1.0, 0.0)), 0.45), "no Off Hand weapon adds nothing")
	assert_true(_has_method("res://scripts/player.gd", "_dual_weapon_hit"))
	var sword := Items.get_item("sword")
	var dagger := Items.get_item("dagger")
	# (With no weapon in the Off Hand the tooltip counts a basic dagger.)
	if Abilities.offhand_weapon().is_empty():
		var both := float(sword["damage"]) + float(dagger["damage"])
		for id in ["doubleup", "missedbeat"]:
			assert_true(is_equal_approx(Abilities.hit_base(id, sword), both), "%s: both weapons" % id)
		assert_true(is_equal_approx(Abilities.dual_wield_damage(sword), both))
	# The kit's other abilities do not count weapon damage.
	assert_true(is_equal_approx(Abilities.hit_base("ripple", sword), float(Abilities.get_resource("ripple").damage)))
	for id in ["doubleup", "missedbeat"]:
		assert_eq(_typed_number(str(_file(id).description)), "", "%s: no typed numbers" % id)
		assert_contains(str(_file(id).description), "with both weapons")

func test_ripple() -> void:
	var r := Abilities.get_resource("ripple")
	assert_eq(float(r.cooldown), 8.0)
	assert_eq(float(r.damage), 0.5)
	assert_eq(float(r.radius), 6.0)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_false(bool(r.requires_target), "it goes out around you")
	assert_true(r.tags.has("AoE"))
	assert_eq(Balance.RIPPLE_REFLECTION_ENEMIES, 3)
	var p := _player()
	assert_false(ArcaneTankKit.ripple_makes_reflection(0))
	assert_false(ArcaneTankKit.ripple_makes_reflection(2))
	assert_true(ArcaneTankKit.ripple_makes_reflection(3), "three enemies: a Reflection")
	assert_true(ArcaneTankKit.ripple_makes_reflection(9))
	assert_contains(Abilities.tooltip("ripple"), "if it hits 3 or more enemies")
	assert_contains(Abilities.tooltip("ripple"), "within 6 m")

func test_full_set() -> void:
	var r := Abilities.get_resource("fullset")
	assert_eq(float(r.cooldown), 30.0)
	assert_eq(Balance.REFLECTION_MAX, 4)
	assert_false(Abilities.has_scaling("fullset"), "nothing to scale")
	assert_true(_player().on_gcd("fullset"))
	var p := _player()
	assert_eq(ArcaneTankKit.reflections_after(0, Balance.REFLECTION_MAX), 4, "from none to all four")
	assert_eq(ArcaneTankKit.reflections_after(3, Balance.REFLECTION_MAX), 4)
	assert_contains(Abilities.tooltip("fullset"), "until you have 4")

func test_missed_beat() -> void:
	var r := Abilities.get_resource("missedbeat")
	assert_eq(float(r.cooldown), 3.0)
	assert_eq(float(r.weapon_damage_multiplier), 1.0)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_true(bool(r.requires_target))
	assert_eq(Balance.MISSED_BEAT_WINDOW, 4.0)
	assert_true(Abilities.OFF_GCD.has("missedbeat"))
	assert_false(_player().on_gcd("missedbeat"), "off the global cooldown")
	assert_contains(Abilities.tooltip("missedbeat"), "within 4 sec")

func test_stand_in() -> void:
	var r := Abilities.get_resource("standin")
	assert_eq(float(r.cooldown), 25.0)
	assert_eq(Balance.STAND_IN_TIME, 4.0)
	assert_false(Abilities.has_scaling("standin"), "nothing to scale")
	assert_true(_has_method("res://scripts/player.gd", "stand_in_for"), "the combat pipeline asks the player")
	# A hit a Reflection stood in for counts as avoided, and says what took it.
	var info := DamageInfo.make(null, null, 1.0, "enemy_melee")
	assert_false(info.stood_in)
	assert_false(info.avoided())
	info.stood_in = true
	assert_true(info.avoided(), "no damage, none of its effects")
	assert_eq(info.avoid_kind(), "reflection")
	assert_eq(CombatSystem.avoid_text(info.avoid_kind()), "Reflection")
	info.dodged = true
	assert_eq(info.avoid_kind(), "dodge", "a dodge is still a dodge")
	assert_contains(Abilities.tooltip("standin"), "For 4 sec")

func test_trade_places() -> void:
	var r := Abilities.get_resource("tradeplaces")
	assert_eq(float(r.cooldown), 30.0)
	assert_eq(Balance.TRADE_PLACES_WINDOW, 3.0)
	assert_eq(Balance.TRADE_PLACES_PCT, 20.0)
	assert_true(Abilities.OFF_GCD.has("tradeplaces"))
	assert_false(_player().on_gcd("tradeplaces"), "off the global cooldown")
	assert_false(Abilities.has_scaling("tradeplaces"), "a share of damage taken: nothing to scale")
	var p := _player()
	assert_eq(ArcaneTankKit.trade_places_heal(1000, 1), 200, "20% of it for one Reflection")
	assert_eq(ArcaneTankKit.trade_places_heal(1000, 4), 800, "20% for each of four")
	assert_eq(ArcaneTankKit.trade_places_heal(1000, 0), 0)
	assert_eq(ArcaneTankKit.trade_places_heal(0, 4), 0)
	assert_eq(ArcaneTankKit.trade_places_heal(333, 2), 133, "rounded")
	# What counts as damage taken lately: [time, damage] rows inside the window.
	var rows := [[10.0, 100], [11.5, 50], [12.9, 25]]
	assert_eq(ArcaneTankKit.damage_in_window(rows, 13.0, 3.0), 175, "all three in the last 3 sec")
	assert_eq(ArcaneTankKit.damage_in_window(rows, 14.0, 3.0), 75, "the first is too old")
	assert_eq(ArcaneTankKit.damage_in_window(rows, 20.0, 3.0), 0)
	assert_eq(ArcaneTankKit.damage_in_window([], 5.0, 3.0), 0)
	assert_ne(ArcaneTankKit.trade_places_error(0, 500, false), "", "no Reflections: nothing to give up")
	assert_ne(ArcaneTankKit.trade_places_error(2, 0, false), "", "no damage taken: nothing to heal")
	assert_ne(ArcaneTankKit.trade_places_error(2, 500, true), "", "already at full health")
	assert_eq(ArcaneTankKit.trade_places_error(1, 1, false), "")
	var text := Abilities.tooltip("tradeplaces")
	assert_contains(text, "20% of the damage you took in the last 3 sec")

func test_crowd_of_one() -> void:
	var r := Abilities.get_resource("crowdofone")
	assert_eq(float(r.cooldown), 90.0)
	assert_eq(Balance.CROWD_OF_ONE_TIME, 8.0)
	assert_false(Abilities.has_scaling("crowdofone"), "nothing to scale")
	assert_contains(Abilities.tooltip("crowdofone"), "For 8 sec")

func test_decoy() -> void:
	var r := Abilities.get_resource("decoy")
	assert_eq(float(r.cooldown), 90.0)
	assert_eq(float(r.damage), 0.5, "its burst")
	assert_eq(float(r.radius), 8.0, "draws in enemies within 8 m")
	assert_true(float(r.cast_range) > 0.0, "it is sent to a spot")
	assert_false(bool(r.requires_target), "placed on the ground")
	assert_eq(Balance.DECOY_TIME, 3.0)
	assert_true(Abilities.has_scaling("decoy"), "its burst scales")
	var text := Abilities.tooltip("decoy")
	assert_contains(text, "within 8 m")
	assert_contains(text, "for 3 sec")
	# A real, attackable image: enemies are told to attack it, and the host makes it.
	assert_true(_has_method("res://scripts/enemy.gd", "distract"), "enemies can be made to attack a Decoy")
	assert_true(_has_method("res://scripts/enemy.gd", "_hits_decoy"), "and their blows land on it")
	assert_true(_has_method("res://scripts/net/net.gd", "decoy") and _has_method("res://scripts/net/net.gd", "_sup_decoy"),
		"a party member's Decoy goes through the host")
	assert_eq(str(load("res://scripts/enemy.gd").DECOY_GROUP), Decoy.GROUP, "enemies look for Decoys in the group they are in")
	# Who it draws in: measured on the ground, to the edge of the enemy.
	assert_true(Decoy.in_reach(Vector3.ZERO, Vector3(8, 0, 0), 0.0, 8.0))
	assert_false(Decoy.in_reach(Vector3.ZERO, Vector3(8.5, 0, 0), 0.0, 8.0))
	assert_true(Decoy.in_reach(Vector3.ZERO, Vector3(8.5, 0, 0), 0.6, 8.0), "a wide enemy's edge is inside")
	assert_true(Decoy.in_reach(Vector3(0, 5, 0), Vector3(3, 0, 4), 0.0, 5.0), "height does not count")

# --- Reflections -----------------------------------------------------------------------

func test_reflection_numbers() -> void:
	assert_eq(Balance.REFLECTION_MAX, 4)
	assert_eq(Balance.REFLECTION_DODGE, 5.0)
	assert_eq(Balance.REFLECTION_DODGE_CAP, 5.0)
	assert_eq(Balance.REFLECTION_SHATTER, 0.3)
	assert_eq(Balance.REFLECTION_SHATTER_RADIUS, 5.0)
	assert_eq(Balance.REFLECTION_SHATTER_THREAT, 4.0, "high threat")
	assert_eq(Balance.REFLECTION_SHATTER_COOLDOWN, 0.5)
	var p := _player()
	assert_eq(ArcaneTankKit.reflections_after(0, 1), 1)
	assert_eq(ArcaneTankKit.reflections_after(3, 1), 4)
	assert_eq(ArcaneTankKit.reflections_after(4, 1), 4, "never more than four")
	assert_eq(ArcaneTankKit.reflections_after(2, 0), 2)
	assert_eq(ArcaneTankKit.reflections_after(2, -3), 2)

## The Reflections are a stacking buff: Dodge per stack, used up one at a time.
func test_reflections_are_stacks_of_dodge() -> void:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx := StatusContainer.make_buff("reflection", "Reflection", Stats.DODGE, Balance.REFLECTION_DODGE,
		Balance.REFLECTION_TIME, Balance.REFLECTION_MAX, Color.WHITE)
	st.apply(fx, owner_node)
	assert_eq(st.stacks_of("reflection"), 1)
	assert_eq(st.stat_mod(Stats.DODGE), 5.0, "+5% Dodge for one")
	st.set_stacks("reflection", Balance.REFLECTION_MAX)
	assert_eq(st.stacks_of("reflection"), 4)
	assert_eq(st.stat_mod(Stats.DODGE), 20.0, "+20% Dodge for four")
	st.apply(fx, owner_node)
	assert_eq(st.stacks_of("reflection"), 4, "a fifth does not fit")
	st.spend_stacks("reflection", 1)
	assert_eq(st.stacks_of("reflection"), 3, "a shatter uses one up")
	assert_eq(st.stat_mod(Stats.DODGE), 15.0)
	st.spend_stacks("reflection", 3)
	assert_false(st.has("reflection"), "the last one gone: the buff ends")
	assert_eq(st.stat_mod(Stats.DODGE), 0.0)

func test_dodge_cap() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.dodge_cap_for(0), Stats.MAX_DODGE, "30% without any")
	assert_eq(ArcaneTankKit.dodge_cap_for(1), 35.0)
	assert_eq(ArcaneTankKit.dodge_cap_for(4), 50.0, "30% to 50% at four")
	assert_eq(ArcaneTankKit.dodge_cap_for(9), 50.0)
	assert_true(_has_method("res://scripts/player.gd", "dodge_cap"), "the combat pipeline asks the player")
	# 48% Dodge, a roll of 45: over the usual cap of 30, under the cap of four Reflections.
	var usual: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 48.0, 0.0, 45.0, 99.0)
	assert_false(usual["dodged"])
	assert_eq(usual["amount"], 10)
	var four: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 48.0, 0.0, 45.0, 99.0,
		-1.0, ArcaneTankKit.dodge_cap_for(4))
	assert_true(four["dodged"])
	assert_eq(four["amount"], 0)
	assert_false(CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 80.0, 0.0, 51.0, 99.0,
		-1.0, ArcaneTankKit.dodge_cap_for(4))["dodged"], "50 is still a cap")
	# Damage over time cannot be dodged, Reflections or not.
	assert_false(CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, false, 1.0, 0.5, 100.0, 0.0, 1.0, 99.0,
		-1.0, 50.0)["dodged"])
	# The stat panel shows what counts.
	assert_eq(Stats.panel_line(Stats.DODGE, 48.0), "Dodge  30%")
	assert_eq(Stats.panel_line(Stats.DODGE, 48.0, {"dodge_cap": 50.0}), "Dodge  48%")
	assert_eq(Stats.panel_line(Stats.DODGE, 80.0, {"dodge_cap": 50.0}), "Dodge  50%")

## A shatter takes time off everything in the Arcane book, never off an interrupt.
func test_a_shatter_cuts_every_arcane_cooldown() -> void:
	var p := _player()
	assert_true(ArcaneTankKit.shatter_cuts("arcane", false))
	assert_false(ArcaneTankKit.shatter_cuts("arcane", true), "interrupts keep their shared cooldown")
	assert_false(ArcaneTankKit.shatter_cuts("fire", false))
	assert_false(ArcaneTankKit.shatter_cuts("", false))
	for id in ["doubleup", "ripple", "decoy", "crowdofone", "collapse", "convergence", "mirrorsigil", "blink", "arcanestrike"]:
		assert_true(ArcaneTankKit.shatter_cuts(Abilities.category_of(id), Balance.INTERRUPT_LOCKOUT.has(id)), "%s: spells and abilities alike" % id)
	assert_false(ArcaneTankKit.shatter_cuts(Abilities.category_of("counterspell"), Balance.INTERRUPT_LOCKOUT.has("counterspell")))
	assert_false(ArcaneTankKit.shatter_cuts(Abilities.category_of("stormshield"), false), "another book's ability")

## The shatter has its own line on the meter and a real damage number in the keyword.
func test_shatter_is_named_and_explained() -> void:
	assert_eq(ArcaneTankKit.REFLECTION_SHATTER_ID, "reflection_shatter")
	assert_eq(Details.spell_name("reflection_shatter"), "Reflection Shatter")
	assert_eq(Details.spell_color("reflection_shatter"), Abilities.color_of("blink"), "an Arcane line")
	var want := Abilities.fmt_amount(Abilities.coef_damage(Balance.REFLECTION_SHATTER, PackedStringArray(["Ability"])))
	assert_eq(TextFill.constants("{d:REFLECTION_SHATTER}"), want, "a coefficient as real damage")
	assert_eq(TextFill.constants("{d:NO_SUCH_CONSTANT}"), "?")
	assert_true(Keywords.KEYWORDS.has("reflection"))
	assert_true(Keywords.mentions("and creates a Reflection.").has("k:reflection"))
	assert_true(Keywords.mentions("all your Reflections").has("k:reflection"), "the plural too")
	var text := Keywords.keyword_text("reflection")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_false(text.contains("?"), text)
	assert_false(text.contains("Frost Bolt"), "a real damage number")
	assert_contains(text, "up to 4")
	assert_contains(text, "5% Dodge")
	assert_contains(text, "deals %s Arcane damage" % want)
	assert_contains(text, "within 5 m")
	assert_contains(text, "0.5 sec off")
	assert_eq(_typed_number(str(Keywords.KEYWORDS["reflection"]["text"])), "", "no number typed into it")
	# Shift on any of the kit's tooltips explains it.
	var detailed := Abilities.tooltip_bbcode("doubleup", true)
	assert_contains(detailed, "Keywords")
	assert_contains(detailed, "[color=#%s]Reflection[/color]: " % Keywords.COLOR.to_html(false))

# --- Dual wield ------------------------------------------------------------------------

func test_one_handed_melee_weapons_go_in_the_off_hand() -> void:
	assert_true(Items.is_one_handed_melee("sword"))
	assert_true(Items.is_one_handed_melee("dagger"))
	assert_false(Items.is_one_handed_melee("greatsword"), "two-handed")
	assert_false(Items.is_one_handed_melee("staff"), "two-handed")
	assert_false(Items.is_one_handed_melee("bow"), "not a melee weapon")
	assert_false(Items.is_one_handed_melee("shield"))
	assert_false(Items.is_one_handed_melee(""))
	assert_true(PlayerDataScript.fits_slot("sword", "Off Hand"))
	assert_true(PlayerDataScript.fits_slot("dagger", "Off Hand"))
	assert_true(PlayerDataScript.fits_slot("sword", "Main Hand"), "and still in the Main Hand")
	assert_true(PlayerDataScript.fits_slot("shield", "Off Hand"), "a shield as before")
	assert_false(PlayerDataScript.fits_slot("shield", "Main Hand"))
	assert_false(PlayerDataScript.fits_slot("greatsword", "Off Hand"))
	assert_false(PlayerDataScript.fits_slot("bow", "Off Hand"))
	assert_false(PlayerDataScript.fits_slot("sword", "Head"))

func test_dual_wield() -> void:
	var pd := _pd()
	assert_false(pd.has_dual_wield(), "empty hands")
	pd.inventory[0] = ItemDB.create("sword")
	pd.inventory[1] = ItemDB.create("dagger")
	assert_eq(pd.equip_from_inventory(0), "")
	assert_eq(Items.base_id(str(pd.equipment.get("Main Hand", ""))), "sword")
	assert_false(pd.has_dual_wield(), "one weapon is not two")
	assert_eq(pd.equip_from_inventory(1), "", "the second one-handed weapon goes to the free Off Hand")
	assert_eq(Items.base_id(str(pd.equipment.get("Off Hand", ""))), "dagger")
	assert_eq(Items.base_id(str(pd.equipment.get("Main Hand", ""))), "sword", "the Main Hand keeps its weapon")
	assert_true(pd.has_dual_wield())
	# A third replaces the Main Hand (both hands are taken).
	pd.inventory[2] = ItemDB.create("dagger")
	assert_eq(pd.equip_from_inventory(2), "")
	assert_eq(Items.base_id(str(pd.equipment.get("Main Hand", ""))), "dagger")
	assert_eq(Items.base_id(str(pd.inventory[2])), "sword", "the old one comes back to the bag")
	assert_true(pd.has_dual_wield())
	# The Off Hand weapon's stats count.
	assert_true(float(pd.gear_stats().get(Stats.CRIT_RATING, 0.0)) > float(Items.get_item(str(pd.equipment["Main Hand"]))["stats"].get(Stats.CRIT_RATING, 0.0)),
		"both weapons give their stats")
	# A shield in the Off Hand is not dual wield.
	pd.inventory[3] = ItemDB.create("shield")
	assert_eq(pd.equip_from_inventory(3), "")
	assert_eq(Items.base_id(str(pd.equipment.get("Off Hand", ""))), "shield")
	assert_false(pd.has_dual_wield())

func test_a_two_hander_takes_both_hands() -> void:
	var pd := _pd()
	pd.equipment["Main Hand"] = ItemDB.create("sword")
	pd.equipment["Off Hand"] = ItemDB.create("dagger")
	pd._invalidate_stats()
	assert_true(pd.has_dual_wield())
	pd.inventory[0] = ItemDB.create("greatsword")
	assert_eq(pd.equip_from_inventory(0), "")
	assert_false(pd.equipment.has("Off Hand"), "the Off Hand weapon is put away")
	assert_false(pd.has_dual_wield())
	assert_true(pd.is_slot_locked("Off Hand"))
	pd.inventory[5] = ItemDB.create("dagger")
	assert_ne(pd.equip_from_inventory(5, "Off Hand"), "", "nothing goes next to a two-handed weapon")
	# A bow and a dagger are two weapons, but not a melee weapon in each hand.
	var archer := _pd()
	archer.equipment["Main Hand"] = ItemDB.create("bow")
	archer.equipment["Off Hand"] = ItemDB.create("dagger")
	assert_false(archer.has_dual_wield())

func test_every_character_gets_a_second_weapon() -> void:
	var pd := _pd()
	assert_true(pd.STARTER_WEAPONS.has("sword") and pd.STARTER_WEAPONS.has("dagger"), "a weapon for each hand from the start")
	pd.give_starter_weapons()
	var got := []
	for item in pd.bank:
		if str(item) != "":
			got.append(Items.base_id(str(item)))
	assert_true(got.has("sword") and got.has("dagger"))

# --- The picture -----------------------------------------------------------------------

## Left, right, front and back of the character, close enough to overlap it by a fifth.
func test_where_reflections_stand() -> void:
	assert_eq(Reflections.SPOTS.size(), Balance.REFLECTION_MAX, "a place for each one")
	assert_eq(Reflections.OVERLAP, 0.2, "they overlap the character by 20%")
	assert_true(is_equal_approx(Reflections.SIDE, Reflections.BODY_WIDTH * 0.8))
	var left: Vector3 = Reflections.spot(0)
	var right: Vector3 = Reflections.spot(1)
	var front: Vector3 = Reflections.spot(2)
	var back: Vector3 = Reflections.spot(3)
	assert_true(left.x < 0.0 and is_zero_approx(left.z), "the first to the left")
	assert_true(right.x > 0.0 and is_zero_approx(right.z), "the second to the right")
	assert_true(front.z < 0.0 and is_zero_approx(front.x), "the third in front (characters face -Z)")
	assert_true(back.z > 0.0 and is_zero_approx(back.x), "the fourth behind")
	for i in Reflections.SPOTS.size():
		var at: Vector3 = Reflections.spot(i)
		assert_true(at.length() < Reflections.BODY_WIDTH, "%d: close enough to overlap" % i)
		assert_true(at.length() > Reflections.BODY_WIDTH * 0.4, "%d: not inside the character" % i)
		assert_eq(at.y, 0.0)
	assert_eq(Reflections.spot(99), back, "never past the last place")

func test_a_reflection_is_a_glass_copy_of_the_model() -> void:
	assert_true(ResourceLoader.exists("res://shaders/reflection.gdshader"))
	var mat := Reflections.glass_material()
	assert_true(mat.shader != null, "the shader loads")
	assert_true(Reflections.TINT.b > Reflections.TINT.g and Reflections.TINT.r > Reflections.TINT.g, "purple")
	var uniforms := []
	for u in mat.shader.get_shader_uniform_list():
		uniforms.append(str(u["name"]))
	for want in ["tint", "blur", "fade", "flash"]:
		assert_true(uniforms.has(want), "the shader has '%s'" % want)
	# The copy wears the glass, casts no shadow and carries no light.
	var model: Node3D = track(Node3D.new())
	model.name = "Model"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	model.add_child(OmniLight3D.new())
	var copy: Node3D = track(Reflections.make_copy(model, mat))
	var meshes := copy.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1)
	assert_true(is_same((meshes[0] as MeshInstance3D).material_override, mat))
	assert_eq((meshes[0] as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(copy.find_children("*", "Light3D", true, false).size(), 0, "an image lights nothing")
	assert_true((model.get_child(0) as MeshInstance3D).material_override == null, "the character itself is untouched")
	# Party members see them: the count is sent, and shown on the puppet.
	assert_true(_has_method("res://scripts/player.gd", "_sync_reflections"))
	assert_contains((load("res://scripts/net/net.gd") as GDScript).source_code, "\"reflections\":")

## The real character model: its copy has a skeleton and an animation player of
## its own, with every animation the character has, and stands where it stands.
func test_a_copy_of_the_character_moves_like_it() -> void:
	var scene: PackedScene = load("res://assets/player/Idle.fbx")
	var model: Node3D = track(scene.instantiate())
	model.position = Vector3(0, -0.9, 0)
	model.rotation.y = PI
	var src := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(src != null and src.has_animation("mixamo_com"), "the character model has its animation player")
	# (The game adds its idle / walk / cast clips in a library called "player".)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", src.get_animation("mixamo_com").duplicate())
	src.add_animation_library("player", lib)
	var mat := Reflections.glass_material()
	var copy: Node3D = track(Reflections.make_copy(model, mat))
	assert_false(is_same(copy, model))
	assert_true(copy.transform.is_equal_approx(model.transform), "it starts exactly where the character is")
	var dst := copy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(dst != null and not is_same(dst, src), "an animation player of its own")
	assert_true(dst.has_animation("player/idle"), "with the clips the game added")
	assert_true(dst.has_animation("mixamo_com"), "and the one the model came with")
	assert_eq(copy.find_children("*", "Skeleton3D", true, false).size(), model.find_children("*", "Skeleton3D", true, false).size(),
		"a skeleton of its own")
	var meshes := copy.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "it has the character's meshes")
	assert_eq(meshes.size(), model.find_children("*", "MeshInstance3D", true, false).size())
	for m in meshes:
		assert_true(is_same((m as MeshInstance3D).material_override, mat), "every mesh wears the glass")
	for m in model.find_children("*", "MeshInstance3D", true, false):
		assert_true((m as MeshInstance3D).material_override == null, "the character keeps its own look")
