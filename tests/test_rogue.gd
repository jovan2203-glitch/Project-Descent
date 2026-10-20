@tool
extends McpTestSuite

# Martial DPS: the Rogue (scripts/player/martial_rogue.gd). Rogue hits build Flow
# (more on a range switch); Go In spends it on a Kill window where the builders take
# their Kill forms; thrown daggers stick and melee rips them out. And Martial Utility:
# Pin the Shadow (the book's root, freed by hits), Over the Shoulder, Play Dead.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")

const BUTTONS := ["cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride", "rollwithit", "snatch"]
const FORMS := ["gut", "throughandthrough", "redwhirl", "backflip", "drivethrough"]
const UTILITY := ["pintheshadow", "overtheshoulder", "playdead"]
const LEVELS := {"cut": 2, "whirl": 4, "dartin": 6, "kickoff": 8, "twinstab": 10, "closeitout": 12,
	"rollwithit": 14, "hityourstride": 16, "snatch": 18, "pintheshadow": 14, "overtheshoulder": 18, "playdead": 22}

func suite_name() -> String:
	return "rogue"

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["martial"]:
		if s[0] == name:
			return s[1]
	return []

# --- Flow -------------------------------------------------------------------------------

func test_flow_builds_more_on_a_range_switch_and_caps() -> void:
	assert_eq(RogueKit.flow_after(0, 1, false), 1)
	assert_eq(RogueKit.flow_after(0, 1, true), 1 + Balance.FLOW_SWITCH, "a range switch gives more")
	assert_eq(RogueKit.flow_after(4, Balance.TWIN_STAB_FLOW, false), 4 + Balance.TWIN_STAB_FLOW)
	assert_eq(RogueKit.flow_after(Balance.FLOW_MAX - 1, 3, true), Balance.FLOW_MAX, "capped")
	assert_true(RogueKit.is_switch("melee", "thrown"))
	assert_true(RogueKit.is_switch("thrown", "melee"))
	assert_false(RogueKit.is_switch("melee", "melee"))
	assert_false(RogueKit.is_switch("", "melee"), "the first hit of a fight switches from nothing")

func test_whirl_gives_flow_per_enemy_up_to_its_cap() -> void:
	assert_eq(RogueKit.whirl_flow(1), 1)
	assert_eq(RogueKit.whirl_flow(99), Balance.WHIRL_FLOW_MAX)

# --- The Kill ---------------------------------------------------------------------------

func test_the_kill_window_lasts_per_flow_and_hit_your_stride_is_longer() -> void:
	assert_eq(RogueKit.window_time(5), 5.0 * Balance.KILL_PER_FLOW)
	assert_eq(RogueKit.window_time(Balance.FLOW_MAX, Balance.HIT_YOUR_STRIDE_MULT),
		float(Balance.FLOW_MAX) * Balance.KILL_PER_FLOW * Balance.HIT_YOUR_STRIDE_MULT)
	assert_eq(Balance.KILL_MIN_FLOW, 5)

func test_varied_kill_forms_add_time_up_to_the_cap() -> void:
	assert_eq(RogueKit.variety_add("", "gut", 0.0), 0.0, "the first form has nothing before it")
	assert_eq(RogueKit.variety_add("gut", "gut", 0.0), 0.0, "the same form again adds nothing")
	assert_eq(RogueKit.variety_add("gut", "redwhirl", 0.0), Balance.KILL_VARIETY)
	assert_eq(RogueKit.variety_add("gut", "redwhirl", Balance.KILL_VARIETY_MAX), 0.0, "capped")
	assert_true(absf(RogueKit.variety_add("gut", "redwhirl", Balance.KILL_VARIETY_MAX - 0.2) - 0.2) < 0.001, "up to the cap")

func test_builders_take_their_kill_forms_only_in_a_window() -> void:
	for b in Abilities.ROGUE_KILL_FORMS:
		var form := str(Abilities.ROGUE_KILL_FORMS[b])
		assert_eq(RogueKit.kill_form(b, true), form)
		assert_eq(RogueKit.kill_form(b, false), b)
		assert_eq(RogueKit.builder_of(form), b)
	assert_eq(RogueKit.kill_form("goin", true), "goin", "not a builder")
	assert_eq(RogueKit.close_it_out_coef(5.0), 5.0 * Balance.CLOSE_IT_OUT_PER_SEC)
	assert_eq(RogueKit.close_it_out_coef(-1.0), 0.0)

func test_kill_forms_share_their_builders_cooldowns() -> void:
	assert_eq(RogueKit.cooldown_partner("kickoff"), "backflip")
	assert_eq(RogueKit.cooldown_partner("backflip"), "kickoff")
	assert_eq(RogueKit.cooldown_partner("dartin"), "drivethrough")
	assert_eq(RogueKit.cooldown_partner("drivethrough"), "dartin")
	assert_eq(RogueKit.cooldown_partner("cut"), "")
	assert_eq(float(Abilities.get_resource("throughandthrough").cooldown), 0.0, "Through and Through has no cooldown")

func test_the_player_uses_the_kill_form() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "id = form_of(id)   # Martial DPS: in a Kill window a builder is its Kill form")
	assert_contains(src, "_rogue_use(id, res)   # Martial DPS: the Rogue, and Martial Utility")
	assert_contains(src, "chance = adjust_crit(info, chance)   # Over the Shoulder")
	assert_contains(src, "Abilities.is_kill_form(id)")

# --- Daggers ----------------------------------------------------------------------------

func test_daggers_cap_per_enemy() -> void:
	assert_eq(RogueKit.daggers_after(0, 2), 2)
	assert_eq(RogueKit.daggers_after(2, 3), Balance.DAGGER_MAX)
	assert_eq(RogueKit.daggers_after(1, -5), 0)
	assert_eq(Details.HIT_NAMES.get(RogueKit.RIP_ID, ""), "Ripped Out", "ripped-out daggers have their own meter line")
	assert_eq(Details.HIT_NAMES.get(RogueKit.OIL_ID, ""), "Oil Jar", "Snatch's Oil Jar has its own meter line")

func test_a_vault_lands_behind_the_target() -> void:
	var at := RogueKit.behind(Vector3.ZERO, Vector3(4, 0, 0), 1.5)
	assert_true(at.distance_to(Vector3(5.5, 0, 0)) < 0.001, "past it, on the far side")

# --- Content ----------------------------------------------------------------------------

func test_the_rogue_spec_and_its_abilities() -> void:
	var spec := _spec("Rogue")
	assert_eq(spec.size(), BUTTONS.size() + FORMS.size(), "the Rogue spec lists every button and Kill form")
	for id in BUTTONS + FORMS:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(Abilities.category_of(id), "martial")
		assert_true(bool(r.requires_dual_wield), "%s needs a weapon in each hand" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Physical"), "%s is a physical ability" % id)
		assert_true(Abilities.ROGUE_IDS.has(id))
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: %s" % [id, tip])
	for id in ["cut", "whirl", "dartin", "kickoff", "twinstab", "closeitout", "snatch"] + FORMS:
		assert_eq(Abilities.resource_of(id), "energy", "%s costs Energy" % id)
	for id in ["goin", "hityourstride", "rollwithit"]:
		assert_true(Abilities.OFF_GCD.has(id), "%s is off the global cooldown" % id)

func test_kill_forms_have_no_buttons() -> void:
	for id in FORMS:
		assert_true(Abilities.is_kill_form(id), id)
		assert_false(Abilities.listed_in_book(id), "%s is shown in the Kill forms table" % id)
		assert_false(Abilities.DRAFT_POOL.has(id))
	for id in BUTTONS:
		assert_false(Abilities.is_kill_form(id), id)
	assert_eq((Abilities.rogue_kill_table()[0][1] as Array).size(), FORMS.size(), "the table shows every form")

func test_names_and_learning() -> void:
	var names := {"cut": "Cut", "whirl": "Whirl", "dartin": "Dart In", "kickoff": "Kick Off", "twinstab": "Twin Stab",
		"goin": "Go In", "closeitout": "Close It Out", "hityourstride": "Hit Your Stride", "rollwithit": "Roll With It",
		"snatch": "Snatch", "gut": "Gut", "throughandthrough": "Through and Through", "redwhirl": "Red Whirl",
		"backflip": "Back Flip", "drivethrough": "Drive Through", "pintheshadow": "Pin the Shadow",
		"overtheshoulder": "Over the Shoulder", "playdead": "Play Dead"}
	for id in names:
		assert_eq(Abilities.ability_name(id), names[id])
	for id in LEVELS:
		assert_true(SkillCards.exists(id), "%s has a Skill Card" % id)
		assert_eq(SkillCards.level_of(id), LEVELS[id], "%s from level %d" % [id, LEVELS[id]])
		assert_true(Abilities.DRAFT_POOL.has(id))
	var pd_src := FileAccess.get_file_as_string("res://scripts/player_data.gd")
	assert_contains(pd_src, "return learned_abilities.has(\"cut\")", "Cut brings Go In and the Kill forms")

func test_numbers_are_in_balance() -> void:
	assert_eq(Abilities.cost_of("cut"), 20.0)
	assert_eq(float(Abilities.get_resource("twinstab").cooldown), 8.0)
	assert_eq(float(Abilities.get_resource("hityourstride").cooldown), 120.0)
	assert_eq(Effects.get_effect("pinned_shadow").duration, Balance.PIN_SHADOW_TIME)
	assert_eq(int(Effects.get_effect("pinned_shadow").break_after_hits), Balance.PIN_SHADOW_HITS)
	assert_eq(Effects.get_effect("blinded").duration, Balance.FLASH_POWDER_TIME)
	for kid in ["flow", "kill_window", "kill_form", "stuck_dagger", "blinded", "pinned"]:
		assert_true(Keywords.KEYWORDS.has(kid), "keyword %s" % kid)

# --- Martial Utility --------------------------------------------------------------------

func test_martial_utility_sits_in_the_utility_divider() -> void:
	assert_eq(_spec("Utility"), UTILITY)
	for id in UTILITY:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_true(r.tags.has("Utility"), id)
		assert_eq(Abilities.resource_of(id), "", "%s costs nothing (cooldown only)" % id)
		assert_false(bool(r.requires_dual_wield), "%s works for every Martial spec" % id)
		assert_eq(float(r.damage), 0.0, "%s deals no damage" % id)
		assert_gt(float(r.cooldown), 0.0)
	assert_true(Abilities.get_resource("pintheshadow").tags.has("Root"), "Pin the Shadow is Martial's root")
	assert_true(Abilities.OFF_GCD.has("playdead"))

func test_pin_the_shadow_ends_after_its_hits() -> void:
	var fx: Resource = Effects.get_effect("pinned_shadow")
	assert_true(fx.root and fx.is_debuff)
	var foe: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	foe.add_child(st)
	var me: Node = track(Node.new())
	st.apply(fx, me)
	for i in Balance.PIN_SHADOW_HITS - 1:
		st.count_hit()
	assert_true(st.has("pinned_shadow"), "still pinned one hit short")
	st.count_hit()
	assert_false(st.has("pinned_shadow"), "freed by the last hit")

func test_enemies_count_direct_hits_from_anyone() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert_contains(src, "if _replica() or tags.has(\"DoT\") or status == null:", "damage over time doesn't count")
	var cs := FileAccess.get_file_as_string("res://scripts/core/combat_system.gd")
	assert_contains(cs, "tgt.count_hit(info.tags)")
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_contains(net, "e.count_hit(tags)", "the host counts party members' hits too")

func test_play_dead_makes_enemies_forget() -> void:
	var e: Node3D = track(load("res://scripts/enemy.gd").new())
	var me := Node3D.new()
	var other := Node3D.new()
	track(me)
	track(other)
	me.add_to_group("player")
	other.add_to_group("player")
	e.threat[me.get_instance_id()] = {"node": me, "value": 100.0}
	e.threat[other.get_instance_id()] = {"node": other, "value": 10.0}
	assert_eq(e.top_threat(), me)
	e.forget(me, Balance.PLAY_DEAD_TIME)
	assert_eq(e.top_threat(), other, "it turns on someone else")
	assert_eq(float(e.threat[me.get_instance_id()]["value"]), 0.0, "my threat is dropped")
	e.threat.erase(other.get_instance_id())
	assert_eq(e.top_threat(), null)
	assert_true(e._waiting_on_forgotten(), "with nobody else it waits instead of going home")
	e.forget(me, 0.0)
	assert_eq(e.top_threat(), me, "it remembers me again")
	assert_false(e._waiting_on_forgotten())
