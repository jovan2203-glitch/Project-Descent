@tool
extends McpTestSuite

# Pacts: one deal for the dungeon, for every character (scripts/pacts.gd). A
# bonus, a drawback and a vow; break the vow and the bonus turns into the same
# amount as a penalty until the dungeon ends, while the drawback stays. The
# player applies them and watches the vows (player.gd, "Pacts").

const Pacts = preload("res://scripts/pacts.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Categories = preload("res://scripts/categories.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

const NAMES := {"unbowed": "Pact of the Unbowed", "thin_line": "Pact of the Thin Line", "relentless": "Pact of the Relentless",
	"sidestep": "Pact of the Sidestep", "purist": "Pact of the Purist", "fast": "Pact of the Fast",
	"shepherd": "Pact of the Shepherd", "vanguard": "Pact of the Vanguard", "restless": "Pact of the Restless",
	"reservoir": "Pact of the Reservoir"}
const PARTS := ["bonus", "drawback", "vow", "broken"]

func suite_name() -> String:
	return "pacts"

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func _has_method(script: GDScript, method: String) -> bool:
	for m in script.get_script_method_list():
		if str(m["name"]) == method:
			return true
	return false

# --- What they are ----------------------------------------------------------------------

func test_the_ten_pacts() -> void:
	assert_eq(Pacts.ORDER, ["unbowed", "thin_line", "relentless", "sidestep", "purist", "fast", "shepherd", "vanguard",
		"restless", "reservoir"], "their order never changes: a new one goes at the end")
	assert_eq(Pacts.INFO.size(), Pacts.ORDER.size())
	for id in Pacts.ORDER:
		assert_true(Pacts.exists(id))
		assert_eq(Pacts.pact_name(id), str(NAMES[id]))
		assert_true(Pacts.pact_name(id).begins_with("Pact of "), "%s: every one is a Pact of something" % id)
		for part in PARTS:
			var raw := str(Pacts.INFO[id][part])
			assert_true(raw != "", "%s has a %s" % [id, part])
			assert_eq(_typed_number(raw), "", "%s: number typed into its %s" % [id, part])
			var text := Pacts.text(id, part)
			assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % id)
			assert_false(text.contains("?"), text)
		assert_contains(Pacts.status_text(id, false), "Vow: ")
		assert_contains(Pacts.status_text(id, true), "Broken until the dungeon ends.")
	assert_false(Pacts.exists("hunter"), "removed")
	assert_false(Pacts.exists(""))
	assert_eq(Pacts.pact_name("nothing"), "")
	# Only two need a party.
	for id in Pacts.ORDER:
		assert_eq(Pacts.party_only(id), id == "shepherd" or id == "vanguard", "%s: party only" % id)
	# Only the Purist needs a book, and it is one of the eight.
	for id in Pacts.ORDER:
		assert_eq(Pacts.needs_book(id), id == "purist")
	for book in Categories.ORDER:
		assert_true(Pacts.valid_book(book))
	assert_false(Pacts.valid_book(Categories.RUNE), "Rune Spells is no book to be a Purist of")
	assert_false(Pacts.valid_book(""))
	assert_eq(Pacts.title("purist", "fire"), "Pact of the Purist (Fire)")
	assert_eq(Pacts.title("purist"), "Pact of the Purist")
	assert_eq(Pacts.title("unbowed", "fire"), "Pact of the Unbowed")

func test_their_numbers() -> void:
	assert_eq(Balance.PACT_UNBOWED_DAMAGE, 15.0)
	assert_eq(Balance.PACT_UNBOWED_TAKEN, 10.0)
	assert_eq(Balance.PACT_THIN_LINE_CRIT, 12.0)
	assert_eq(Balance.PACT_THIN_LINE_HEALTH, 10.0)
	assert_eq(Balance.PACT_THIN_LINE_FLOOR, 25.0)
	assert_eq(Balance.PACT_RELENTLESS_HASTE, 10.0)
	assert_eq(Balance.PACT_RELENTLESS_SLOW, 15.0)
	assert_eq(Balance.PACT_RELENTLESS_IDLE, 5.0)
	assert_eq(Balance.PACT_SIDESTEP_COOLDOWN, 20.0)
	assert_eq(Balance.PACT_SIDESTEP_COST, 10.0)
	assert_eq(Balance.PACT_SIDESTEP_HIT, 25.0)
	assert_eq(Balance.PACT_PURIST_DAMAGE, 20.0)
	assert_eq(Balance.PACT_PURIST_TAKEN, 5.0)
	assert_eq(Balance.PACT_PURIST_CONFIRM, 3.0)
	assert_eq(Balance.PACT_FAST_TAKEN, 10.0)
	assert_eq(Balance.PACT_FAST_HEALING, 15.0)
	assert_eq(Balance.PACT_FAST_HEALING_BROKEN, 30.0)
	assert_eq(Balance.PACT_SHEPHERD_HEALS, 15.0)
	assert_eq(Balance.PACT_SHEPHERD_SELF, 30.0)
	assert_eq(Balance.PACT_SHEPHERD_RANGE, 40.0)
	assert_eq(Balance.PACT_VANGUARD_TAKEN, 12.0)
	assert_eq(Balance.PACT_VANGUARD_DAMAGE, 10.0)
	assert_eq(Balance.PACT_RESTLESS_RESOURCE, 25.0)
	assert_eq(Balance.PACT_RESTLESS_BLEED, 1.0)
	assert_eq(Balance.PACT_RESTLESS_IDLE, 30.0)
	assert_eq(Balance.PACT_RESERVOIR_COST, 20.0)
	assert_eq(Balance.PACT_RESERVOIR_MANA, 15.0)
	assert_eq(Balance.PACT_RESERVOIR_FLOOR, 15.0)
	# The texts quote them.
	assert_contains(Pacts.text("purist", "bonus"), "20% more damage")
	assert_contains(Pacts.text("purist", "broken"), "20% less damage")
	assert_contains(Pacts.text("thin_line", "vow"), "25% health")
	assert_contains(Pacts.text("restless", "vow"), "30 sec")
	assert_contains(Pacts.text("fast", "broken"), "30% smaller")

# --- What they change, kept and broken ----------------------------------------------------

func test_damage_dealt_and_taken() -> void:
	# Kept: the bonus. Broken: the same amount the other way. The drawback never changes.
	assert_eq(Pacts.damage_dealt_pct("unbowed", false), 15.0)
	assert_eq(Pacts.damage_dealt_pct("unbowed", true), -15.0)
	assert_eq(Pacts.damage_taken_pct("unbowed", false), 10.0)
	assert_eq(Pacts.damage_taken_pct("unbowed", true), 10.0, "the drawback stays")
	assert_eq(Pacts.damage_dealt_pct("purist", false), 20.0)
	assert_eq(Pacts.damage_dealt_pct("purist", true), -20.0)
	assert_eq(Pacts.damage_taken_pct("purist", false), 5.0)
	assert_eq(Pacts.damage_taken_pct("purist", true), 5.0)
	assert_eq(Pacts.damage_taken_pct("fast", false), -10.0)
	assert_eq(Pacts.damage_taken_pct("fast", true), 10.0)
	assert_eq(Pacts.damage_taken_pct("vanguard", false), -12.0)
	assert_eq(Pacts.damage_taken_pct("vanguard", true), 12.0)
	assert_eq(Pacts.damage_dealt_pct("vanguard", false), -10.0)
	assert_eq(Pacts.damage_dealt_pct("vanguard", true), -10.0, "the drawback stays")
	# The others change no damage, and no Pact changes nothing at all.
	for id in ["thin_line", "relentless", "sidestep", "shepherd", "restless", "reservoir", "", "nothing"]:
		for broken in [false, true]:
			assert_eq(Pacts.damage_dealt_pct(id, broken) if id != "shepherd" else 0.0, 0.0, id)
			assert_eq(Pacts.damage_taken_pct(id, broken), 0.0, id)

func test_stats() -> void:
	assert_eq(Pacts.stat_mods("thin_line", false), {Stats.CRIT: 12.0, "max_health%": -10.0})
	assert_eq(Pacts.stat_mods("thin_line", true), {Stats.CRIT: -12.0, "max_health%": -10.0}, "still 10% less max health, not more")
	assert_eq(Pacts.stat_mods("relentless", false), {Stats.HASTE: 10.0, Stats.MOVE_SPEED: -15.0})
	assert_eq(Pacts.stat_mods("relentless", true), {Stats.HASTE: -10.0, Stats.MOVE_SPEED: -15.0})
	assert_eq(Pacts.stat_mods("reservoir", false), {"max_mana%": -15.0})
	assert_eq(Pacts.stat_mods("reservoir", true), {"max_mana%": -15.0})
	assert_eq(Pacts.stat_mods("unbowed", false), {})
	assert_eq(Pacts.stat_mod("thin_line", false, Stats.CRIT), 12.0)
	assert_eq(Pacts.stat_mod("thin_line", false, Stats.HASTE), 0.0)
	assert_eq(Pacts.stat_mod("", false, Stats.CRIT), 0.0)
	# A percent key is a percent of that stat (Stats.resolve): 10% less of 1000 max health.
	var raw := func(key: String) -> float:
		return 1000.0 if key == Stats.MAX_HEALTH else Pacts.stat_mod("thin_line", false, key)
	assert_true(_near(Stats.resolve(Stats.MAX_HEALTH, raw), 900.0))

func test_cooldowns_costs_and_resources() -> void:
	assert_true(_near(Pacts.cooldown_rate("sidestep", false), 1.2))
	assert_true(_near(Pacts.cooldown_rate("sidestep", true), 0.8))
	assert_eq(Pacts.cooldown_rate("unbowed", false), 1.0)
	assert_eq(Pacts.cooldown_rate("", true), 1.0)
	for res in ["mana", "rage", "energy"]:
		assert_true(_near(Pacts.cost_mult("sidestep", false, res), 1.1), "every resource")
		assert_true(_near(Pacts.cost_mult("sidestep", true, res), 1.1), "the drawback stays")
	assert_true(_near(Pacts.cost_mult("reservoir", false, "mana"), 0.8))
	assert_true(_near(Pacts.cost_mult("reservoir", true, "mana"), 1.2))
	assert_eq(Pacts.cost_mult("reservoir", false, "rage"), 1.0, "only mana: it gives a Rage build nothing")
	assert_eq(Pacts.cost_mult("reservoir", false, "energy"), 1.0)
	assert_eq(Pacts.cost_mult("unbowed", false, "mana"), 1.0)
	assert_true(_near(Pacts.resource_gain_mult("restless", false), 1.25))
	assert_true(_near(Pacts.resource_gain_mult("restless", true), 0.75))
	assert_eq(Pacts.resource_gain_mult("sidestep", false), 1.0)
	assert_eq(Pacts.bleed_pct("restless"), 1.0, "out of combat, kept or broken")
	assert_eq(Pacts.bleed_pct("unbowed"), 0.0)

func test_healing() -> void:
	# The Fast: every heal on me, from anyone.
	for from_self in [false, true]:
		assert_true(_near(Pacts.heal_taken_mult("fast", false, from_self), 0.85))
		assert_true(_near(Pacts.heal_taken_mult("fast", true, from_self), 0.7))
	# The Shepherd: bigger heals, but smaller on myself.
	assert_true(_near(Pacts.heal_done_mult("shepherd", false), 1.15))
	assert_true(_near(Pacts.heal_done_mult("shepherd", true), 0.85))
	assert_true(_near(Pacts.heal_taken_mult("shepherd", false, true), 0.7))
	assert_true(_near(Pacts.heal_taken_mult("shepherd", true, true), 0.7), "the drawback stays")
	assert_eq(Pacts.heal_taken_mult("shepherd", false, false), 1.0, "an ally's heal on me is whole")
	assert_eq(Pacts.heal_done_mult("fast", false), 1.0)
	assert_eq(Pacts.heal_taken_mult("", false, true), 1.0)

# --- The vows ------------------------------------------------------------------------------

func test_the_vows() -> void:
	# Unbowed: going down or dying.
	assert_true(Pacts.breaks_on_down("unbowed"))
	assert_false(Pacts.breaks_on_down("thin_line"))
	# Thin Line: left below a quarter of my health.
	assert_true(Pacts.breaks_on_hit("thin_line", 10, 249, 1000))
	assert_false(Pacts.breaks_on_hit("thin_line", 700, 250, 1000), "at it is not below it")
	assert_true(Pacts.breaks_on_hit("thin_line", 400, 0, 1000), "dead is below it too")
	# Sidestep: one hit for more than a quarter of my health.
	assert_true(Pacts.breaks_on_hit("sidestep", 251, 700, 1000))
	assert_false(Pacts.breaks_on_hit("sidestep", 250, 100, 1000), "many small ones are fine")
	assert_false(Pacts.breaks_on_hit("unbowed", 999, 1, 1000))
	assert_false(Pacts.breaks_on_hit("sidestep", 50, 0, 0))
	# Relentless and Restless: time.
	assert_false(Pacts.breaks_on_idle("relentless", 5.0))
	assert_true(Pacts.breaks_on_idle("relentless", 5.1))
	assert_false(Pacts.breaks_on_idle("restless", 99.0))
	assert_false(Pacts.breaks_on_rest("restless", 30.0))
	assert_true(Pacts.breaks_on_rest("restless", 30.1))
	assert_false(Pacts.breaks_on_rest("relentless", 99.0))
	# Purist: any other book, the basic abilities included; never an on-use item.
	assert_false(Pacts.breaks_on_ability("purist", "fire", "fire", false))
	assert_true(Pacts.breaks_on_ability("purist", "holy", "fire", false), "the basic Heal")
	assert_true(Pacts.breaks_on_ability("purist", "martial", "fire", false), "Taunt")
	assert_true(Pacts.breaks_on_ability("purist", Categories.RUNE, "fire", false), "a rune's spell")
	assert_true(Pacts.breaks_on_ability("purist", "", "fire", false))
	assert_false(Pacts.breaks_on_ability("purist", "", "fire", true), "an on-use item")
	assert_false(Pacts.breaks_on_ability("purist", "holy", "", false), "no book chosen: nothing to break")
	assert_false(Pacts.breaks_on_ability("unbowed", "holy", "fire", false))
	# Fast: a spell's or an ability's heal on myself.
	assert_true(Pacts.breaks_on_self_heal("fast", true))
	assert_false(Pacts.breaks_on_self_heal("fast", false), "Lifesteal, a talent's or a rune's heal")
	assert_false(Pacts.breaks_on_self_heal("shepherd", true))
	# Shepherd: a party member down near me.
	assert_true(Pacts.breaks_on_ally_down("shepherd", 40.0))
	assert_false(Pacts.breaks_on_ally_down("shepherd", 40.5), "too far away to have helped")
	assert_false(Pacts.breaks_on_ally_down("vanguard", 1.0))
	# Vanguard: an enemy leaving me for one of them.
	assert_true(Pacts.breaks_on_lost_enemy("vanguard"))
	assert_false(Pacts.breaks_on_lost_enemy("shepherd"))
	# Reservoir: under 15% mana.
	assert_true(Pacts.breaks_on_mana("reservoir", 149.0, 1000.0))
	assert_false(Pacts.breaks_on_mana("reservoir", 150.0, 1000.0))
	assert_false(Pacts.breaks_on_mana("unbowed", 0.0, 1000.0))
	assert_false(Pacts.breaks_on_mana("reservoir", 0.0, 0.0))

# --- Holding one ---------------------------------------------------------------------------

func test_taking_and_breaking_one() -> void:
	var pd = PlayerDataScript.new()
	assert_eq(pd.pact, "")
	assert_false(pd.pact_broken)
	assert_ne(pd.set_pact("hunter"), "", "no such Pact")
	assert_eq(pd.pact, "")
	assert_eq(pd.set_pact("unbowed"), "")
	assert_eq(pd.pact, "unbowed")
	# One at a time: another one replaces it.
	assert_eq(pd.set_pact("sidestep", "fire"), "")
	assert_eq(pd.pact, "sidestep")
	assert_eq(pd.pact_book, "", "only the Purist keeps a book")
	# The Purist needs its book.
	assert_ne(pd.set_pact("purist"), "")
	assert_ne(pd.set_pact("purist", "rune"), "")
	assert_eq(pd.pact, "sidestep", "a refused one changes nothing")
	assert_eq(pd.set_pact("purist", "shadow"), "")
	assert_eq([pd.pact, pd.pact_book], ["purist", "shadow"])
	# Broken: for the rest of the run, whatever else happens.
	pd.break_pact()
	assert_true(pd.pact_broken)
	pd.break_pact()
	assert_true(pd.pact_broken)
	# A new run from the menu: whole again.
	pd.start_pact_run()
	assert_false(pd.pact_broken)
	assert_eq(pd.pact, "purist", "the Pact itself is kept from dungeon to dungeon")
	# Giving it up.
	pd.break_pact()
	assert_eq(pd.set_pact(""), "")
	assert_eq([pd.pact, pd.pact_book, pd.pact_broken], ["", "", false])
	pd.break_pact()
	assert_false(pd.pact_broken, "nothing to break")
	pd.free()

func test_it_is_saved_and_locked_in_a_dungeon() -> void:
	var save := FileAccess.get_file_as_string("res://scripts/save_system.gd")
	for piece in ["cfg.set_value(\"progress\", \"pact\", pd.pact)", "cfg.set_value(\"progress\", \"pact_book\", pd.pact_book)",
			"Pacts.exists(saved_pact)", "pd.pact_broken = false"]:
		assert_contains(save, piece)
	assert_false(save.contains("\"pact_broken\""), "a broken Pact is never saved: it is whole again next dungeon")
	var data := FileAccess.get_file_as_string("res://scripts/player_data.gd")
	assert_contains(data, "return \"Pacts can only be changed in the main menu\"")
	# A run that starts from the menu clears the break: a dungeon, the Training Room, a party's dungeon.
	var gm := FileAccess.get_file_as_string("res://scripts/game_manager.gd")
	assert_eq(gm.count("start_pact_run()"), 3)
	assert_false(gm.substr(gm.find("func descend()"), 300).contains("start_pact_run"), "the next floor is the same dungeon")

# --- In the game and in the menu ---------------------------------------------------------------

func test_the_player_applies_it() -> void:
	var player: GDScript = load("res://scripts/player.gd")
	for m in ["pact_id", "pact_broken", "heal_taken_mult", "_tick_pact", "_break_pact", "_pact_on_down", "_pact_on_damage",
			"_pact_purist_blocks", "_pact_on_ability", "_pact_on_heal", "_pact_acted", "_pact_watch_party", "_pact_enemy_on_ally",
			"_pact_bleed_tick", "_pact_show", "_pact_outgoing", "_pact_incoming"]:
		assert_true(_has_method(player, m), "player.gd has %s" % m)
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	for piece in ["v += _pact_stat(key)", "_pact_incoming(info)", "_pact_outgoing(info)", "- step * pact_rate",
			"return cost * _pact_cost_mult(Abilities.resource_of(id))", "cost *= mana_unit() * _pact_cost_mult(\"mana\")",
			"amount *= PACTS.resource_gain_mult(pact_id(), pact_broken())", "or PACTS.bleed_pct(pact_id()) > 0.0",
			"amount * _pact_heal_mult(), ability_id)", "func _die() -> void:\n\t_pact_on_down()", "func _go_down() -> void:\n\t_pact_on_down()",
			"_pact_on_damage(amount)", "if _pact_purist_blocks(id):", "_bus().cast_finished.connect(_pact_on_ability)",
			"_pact_on_heal(healed, id)", "_pact_acted(info)", "\t_tick_pact(_delta)\n", "fx.show_time = false"]:
		assert_contains(src, piece)
	# Whoever is healed is asked how much of it they take.
	assert_contains(FileAccess.get_file_as_string("res://scripts/core/combat_system.gd"), "target.heal_taken_mult(source, ability_id)")

func test_the_pacts_tab_sits_above_rune_spells_and_the_books_do_not_move() -> void:
	var menu: GDScript = load("res://scripts/main_menu.gd")
	var consts := menu.get_script_constant_map()
	assert_eq(int(consts["SHELF_TAB_HEIGHT"]) * 2 + int(consts["SHELF_TAB_GAP"]), 60,
		"the two tabs together are as tall as the Rune Spells tab was alone")
	assert_eq((consts["PACT_LINES"] as Array).size(), PARTS.size())
	for i in PARTS.size():
		assert_eq(str(consts["PACT_LINES"][i][1]), str(PARTS[i]), "a card shows the bonus, the drawback, the vow, then what breaking it costs")
	assert_eq(_typed_number(str(consts["PACT_HINT"])), "")
	for m in ["_shelf_pact_tab", "_build_pacts_page", "_open_pacts", "_close_pacts", "_refresh_pacts", "_pact_card", "_take_pact"]:
		assert_true(_has_method(menu, m), "main_menu.gd has %s" % m)
	var src := FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	var pact_at := src.find("rune_tab.add_child(_shelf_pact_tab())")
	var rune_at := src.find("rune_tab.add_child(_shelf_rune_tab())")
	assert_true(pact_at > 0 and rune_at > pact_at, "Pacts first, Rune Spells under it")
	assert_contains(src, "for id in Pacts.ORDER:")
	assert_contains(src, "_close_pacts()   # Esc closes the Pacts page first")
