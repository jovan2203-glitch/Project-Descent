@tool
extends McpTestSuite

# The Frost healer, Cold Comfort (scripts/player/frost_healer.gd): Rime Shell
# plus Meltwater, Glaze, Break the Ice, Frost Lattice, Rimefall, Frost Tide,
# Stillwater and the Spring Thaw rez. A Rime Shell of yours on an ally sends out
# Rime Shards when it breaks and melts into Runoff when it runs out.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Talents = preload("res://scripts/talents.gd")
const Kit = preload("res://scripts/player/frost_healer.gd")

const KIT := ["rimeshell", "meltwater", "glaze", "breaktheice", "frostlattice", "rimefall", "frosttide", "stillwater", "springthaw"]

func suite_name() -> String:
	return "frost_healer"

func _src() -> String:
	return PlayerSource.text()

# --- The spec ----------------------------------------------------------------------------

func test_cold_comfort_is_a_frost_healer_spec() -> void:
	assert_true(Abilities.HEALER_SPECS.has("Cold Comfort"))
	assert_eq(Abilities.SPEC_ROLES["Cold Comfort"], "healer")
	var spec: Array = []
	for s in Abilities.SPECS["frost"]:
		if s[0] == "Cold Comfort":
			spec = s[1]
	assert_eq(spec, KIT, "the kit, in order")
	for id in KIT:
		assert_true(Abilities.get_resource(id) != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "frost")
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)

func test_spring_thaw_is_the_out_of_combat_rez() -> void:
	assert_true(RezKit.IDS.has("springthaw"))
	assert_true(Abilities.get_resource("springthaw").tags.has("Resurrect"))

func test_numbers_come_from_balance() -> void:
	assert_eq(int(Abilities.get_resource("meltwater").resource_cost), int(Balance.ABILITIES["meltwater"]["cost"]))
	assert_eq(float(Abilities.get_resource("breaktheice").cooldown), float(Balance.ABILITIES["breaktheice"]["cooldown"]))
	assert_eq(float(Abilities.get_resource("rimefall").cast_time), float(Balance.ABILITIES["rimefall"]["cast_time"]))
	assert_eq(float(Abilities.get_resource("frosttide").cooldown), 120.0)

# --- Rime Shell -----------------------------------------------------------------------------

func test_rime_shell_is_instant_on_allies() -> void:
	assert_true(Abilities.INSTANT_ON_ALLIES.has("rimeshell"))
	assert_eq(float(Balance.ABILITIES["rimeshell"]["cast_time"]), 2.2, "still a cast on enemies")
	assert_true(_src().contains("Abilities.INSTANT_ON_ALLIES.has(spell) and (_cast_kind in [\"self\", \"ally\"]"), "instant when it goes on an ally or me")
	assert_contains(Abilities.tooltip("rimeshell"), "instant on allies")

func test_mouseover_prefers_allies() -> void:
	var src := _src()
	var ally_first := src.find("# It comes first, even for Rime Shell with an enemy targeted")
	var enemy := src.find("if id == \"rimeshell\" and _has_valid_target() and not _has_rune(\"everlasting_rime\")")
	assert_true(ally_first > 0 and enemy > ally_first, "the ally under the mouse is checked before the enemy target")

func test_rime_shards_and_runoff() -> void:
	# A shell of 1000 breaks next to 3 allies: each is healed 30%.
	assert_eq(Kit.shards_each(1000, 3), 300)
	# Past the AoE cap the heal is split evenly.
	assert_eq(Kit.shards_each(1000, 10), 150)
	# Deep Cracks.
	assert_eq(Kit.shards_each(1000, 1, 20.0), 360)
	# Runoff: half of what was left, Slow Runoff on top.
	assert_eq(Kit.runoff_total(400), 200)
	assert_eq(Kit.runoff_total(400, 60.0), 320)
	var src := _src()
	assert_true(src.contains("shell_broke(self, amount)"), "a shell breaking on me tells its caster's kit")
	assert_true(src.contains("\"rime_broke\", {\"amount\": amount}"), "... or its caster's machine")
	assert_true(src.contains("status.shield_expired.connect(_on_my_shield_expired)"), "a shell running out turns into Runoff")

func test_thawing_replaced_weakened_soul() -> void:
	assert_eq(str(Abilities.get_resource("rimeshell").ally_lockout_effect.display_name), "Thawing")

# --- The kit ----------------------------------------------------------------------------------

func test_meltwater_is_stronger_on_my_thawing() -> void:
	assert_eq(Kit.meltwater_mult(false), 1.0)
	assert_eq(Kit.meltwater_mult(true), 1.0 + Balance.MELTWATER_THAWING_PCT / 100.0)
	assert_true(Abilities.HEALS.has("meltwater"))

func test_break_the_ice_heals_from_what_was_left() -> void:
	assert_eq(Kit.break_heal_each(500, 2), 400)
	assert_eq(Kit.break_heal_each(500, 10), 200, "split past the AoE cap")
	assert_eq(Kit.break_heal_each(500, 0), 0)

func test_rimefall_grows_with_my_shells() -> void:
	assert_eq(Kit.rimefall_share(0), Balance.RIMEFALL_SHARE)
	assert_true(is_equal_approx(Kit.rimefall_share(2), Balance.RIMEFALL_SHARE + 2 * Balance.RIMEFALL_PER_SHELL))
	assert_true(is_equal_approx(Kit.rimefall_share(9), Balance.RIMEFALL_SHARE + Balance.RIMEFALL_MAX_SHELLS * Balance.RIMEFALL_PER_SHELL), "up to a cap")

func test_stillwater_only_saves_a_low_ally() -> void:
	assert_true(Kit.stillwater_ok(300.0, 1000.0))
	assert_false(Kit.stillwater_ok(350.0, 1000.0), "not at the line")
	assert_false(Kit.stillwater_ok(800.0, 1000.0))
	assert_false(Kit.stillwater_ok(0.0, 1000.0), "not on the dead")
	var fx: Resource = Kit.make_stillwater_fx(3.0)
	assert_true(fx.stun and fx.modifies_incoming and float(fx.damage_mod_pct) == -100.0, "no damage, can't act")

func test_frost_lattice_size() -> void:
	assert_eq(Kit.lattice_size(0.0), Balance.LATTICE_LINKS)
	assert_eq(Kit.lattice_size(1.0), Balance.LATTICE_LINKS + 1, "Wide Lattice")

func test_frost_tide_lifts_thawing() -> void:
	var src := _src()
	assert_true(src.contains("Frost Tide: Rime Shell ignores Thawing"))
	assert_true(src.contains("or (spell == \"rimeshell\" and frost_tide_on())"), "instant on enemies too")

func test_glaze_and_rimefall_refill_never_stack() -> void:
	var holder := Node.new()   # (a status container asks its owner about itself)
	var st: Node = Node.new()
	st.set_script(load("res://scripts/core/status_container.gd"))
	holder.add_child(st)
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 100, 5.0)
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 60, 5.0)
	assert_eq(st.absorb_left(Kit.GLAZE_FX), 100, "a smaller refill keeps what is there")
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 150, 5.0)
	assert_eq(st.absorb_left(Kit.GLAZE_FX), 150)
	holder.free()

func test_every_message_has_a_handler() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/frost_healer.gd")
	var relay := FileAccess.get_file_as_string("res://scripts/player/shadow_strings.gd")
	for kind in ["frost_shield", "rime_break", "stillwater", "lattice", "rime_drain", "rime_broke", "rime_runoff", "rime_broken", "lattice_bill"]:
		assert_true(src.contains("\"%s\":" % kind), "%s is handled" % kind)
		assert_true(relay.contains("\"%s\"" % kind), "%s reaches the kit" % kind)

# --- Talents --------------------------------------------------------------------------------

func test_the_talents() -> void:
	for key in ["frost_deep_cracks", "frost_slow_runoff", "frost_shard_spray", "frost_splinterheal", "frost_wide_lattice", "frost_cold_spread"]:
		assert_ne(Talents.id_for_key(key), "", "%s is in the tree" % key)
	assert_eq(Talents.get_talent(Talents.id_for_key("frost_wide_lattice"))["requires"], "frostlattice")
	assert_eq(Talents.get_talent(Talents.id_for_key("frost_cold_spread"))["requires"], "breaktheice")
	assert_true(Talents.targets_of(Talents.id_for_key("frost_deep_cracks")).has(Talents.id_for_key("frost_shard_spray")), "Deep Cracks opens Shard Spray")

# --- Frost Lattice: a hit on one linked shell is taken from all of them --------------------------

func _status() -> Array:   # [holder, status]: a status container asks its owner about itself
	var holder := Node.new()
	var st: Node = Node.new()
	st.set_script(load("res://scripts/core/status_container.gd"))
	holder.add_child(st)
	return [holder, st]

func test_a_linked_shell_pays_only_its_share() -> void:
	var hs := _status()
	var st: Node = hs[1]
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 300, 10.0)   # (any shield works the same)
	st.set_share(Kit.GLAZE_FX, 3, st._now() + 10.0)
	var billed := [0]
	st.shield_shared.connect(func(_id, b, _src): billed[0] += b)
	assert_eq(st.absorb_damage(300), 0, "the whole hit is soaked")
	assert_eq(st.absorb_left(Kit.GLAZE_FX), 200, "it loses a third")
	assert_eq(billed[0], 200, "the other two thirds go to the other linked shells")
	# A linked shell can soak up to n times its own shield.
	assert_eq(st.absorb_damage(700), 100, "200 left x 3 = 600 soaked")
	hs[0].free()

func test_the_others_are_drained_and_can_break() -> void:
	var hs := _status()
	var st: Node = hs[1]
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 100, 10.0)
	st.drain_absorb(Kit.GLAZE_FX, 40)
	assert_eq(st.absorb_left(Kit.GLAZE_FX), 60)
	var broke := [false]
	st.shield_broken.connect(func(_id): broke[0] = true)
	st.drain_absorb(Kit.GLAZE_FX, 80)
	assert_true(broke[0] and st.absorb_left(Kit.GLAZE_FX) == 0, "drained to nothing: it breaks")
	hs[0].free()

func test_sharing_ends_with_the_lattice() -> void:
	var hs := _status()
	var st: Node = hs[1]
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 300, 10.0)
	st.set_share(Kit.GLAZE_FX, 3, st._now() - 1.0)
	assert_eq(st.share_of(Kit.GLAZE_FX), 1, "past its time: not shared")
	assert_eq(st.absorb_damage(90), 0)
	assert_eq(st.absorb_left(Kit.GLAZE_FX), 210)
	hs[0].free()

func test_lattice_bill_is_split_evenly() -> void:
	assert_eq(Kit.lattice_each(200, 2), 100)
	assert_eq(Kit.lattice_each(201, 2), 101, "rounded up")
	assert_eq(Kit.lattice_each(200, 0), 0)
	var src := PlayerSource.text()
	assert_true(src.contains("status.shield_shared.connect(_on_my_shield_shared)"))
	assert_true(src.contains("\"lattice_bill\", {\"amount\": billed}"), "a party member's machine bills the healer")

# --- Rime Shell's cracks ------------------------------------------------------------------------

func test_the_shell_cracks_as_it_soaks() -> void:
	assert_eq(RimeShellFx.cracks_for(1.0), 0)
	assert_eq(RimeShellFx.cracks_for(0.7), 0)
	assert_eq(RimeShellFx.cracks_for(0.6), 1, "a third gone")
	assert_eq(RimeShellFx.cracks_for(0.3), 2, "two thirds gone")
	var hs := _status()
	var st: Node = hs[1]
	Kit.frost_shield_on(st, null, Kit.GLAZE_FX, 300, 10.0)
	st.absorb_damage(150)
	assert_eq(st.absorb_fraction(Kit.GLAZE_FX), 0.5)
	hs[0].free()

func test_the_cracked_shell_shows_on_everyone() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node3D.new()
	tree.current_scene.add_child(host)
	RimeShellFx.show_on(host, true, 1)
	var fx := host.get_node_or_null(RimeShellFx.NODE_NAME) as RimeShellFx
	assert_true(fx != null and fx.cracks == 1, "a shell with one set of cracks")
	RimeShellFx.show_on(host, true, 2)
	assert_eq(fx.cracks, 2)
	host.free()
	var src := PlayerSource.text()
	assert_true(src.contains("net.send_support_state(shell, locks, shell_by, cracks)"), "the others see the cracks")
	assert_true(FileAccess.get_file_as_string("res://scripts/net/net.gd").contains("RimeShellFx.show_on(p, has_shell, cracks)"))
	assert_true(FileAccess.get_file_as_string("res://scripts/training/ally_dummy.gd").contains("RimeShellFx.show_on(self"))
