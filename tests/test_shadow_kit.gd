@tool
extends McpTestSuite

# The Shadow caster: Decay (a damage over time effect kept as an amount) and the
# spells around it - Blight, Erode, Call Due, Gnaw, Spill, Pall, Hush,
# Take It Back and Bottomless - plus the talent Tainted Steel, the Rune of Rot
# and the Rune of the Open Wound.
# Those are the names the code keeps. In the game Decay is the Breach (a hole
# under the enemy that demons claw through) and most of them are called
# something else: test_the_breach_theme has the list.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Runes = preload("res://scripts/runes.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusIcons = preload("res://scripts/ui/status_icons.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

const NEW := ["blight", "erode", "calldue", "gnaw", "spill", "pall", "hush", "takeitback", "bottomless"]
var SHADOW := PackedStringArray(["Shadow", "Spell"])

func suite_name() -> String:
	return "shadow_kit"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _has_method(method: String) -> bool:
	for m in PlayerSource.methods_of(_player()):
		if str(m["name"]) == method:
			return true
	return false

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

## The fields of a .tres file as written on disk ("name = value" lines).
func _fields(path: String) -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find(" = ")
		if at > 0:
			out[line.substr(0, at)] = line.substr(at + 3)
	return out

func test_new_abilities_are_draftable_shadow_spells() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_gt(SkillCards.level_of(id), 1)
		assert_eq(Abilities.category_of(id), "shadow")
		assert_true(r.tags.has("Shadow") and r.tags.has("Spell"), "%s is a Shadow spell" % id)
		assert_eq(str(r.damage_type), "shadow")
		assert_eq(Abilities.resource_of(id), "mana")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: no number typed into its text" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])
		assert_false(tip.contains("Frost Bolt"), "%s: real damage numbers" % id)
	# The book shows the caster's spells after Wither, the one spell it already had.
	var book := Abilities.in_category("shadow")
	assert_eq(book.size(), 40, "Wither, the caster's nine, Leeching Strike, the seven of the Hounds (test_hounds.gd), Shadow Arrow, the healer's nineteen (test_strings.gd), its out-of-combat rez and Climb the String (Utility)")
	assert_eq(book[0], "corruption")
	assert_true(book.find("bottomless") < book.find("shadowstrike"), "then the melee abilities")
	assert_true(book.find("shadowstrike") < book.find("sic") and book.find("offthechain") < book.find("shadowarrow"))
	assert_true(book.find("blight") < book.find("erode"))

func test_their_numbers() -> void:
	# [id, cast type, cast time, cooldown, damage]
	var want := [
		["blight", 1, 1.5, 0.0, 0.5], ["erode", 1, 2.0, 0.0, 1.0],
		["calldue", 0, 0.0, 15.0, 0.0], ["gnaw", 0, 0.0, 10.0, 0.4], ["spill", 0, 0.0, 10.0, 0.0],
		["pall", 3, 2.0, 12.0, 0.5], ["hush", 0, 0.0, 20.0, 0.3], ["takeitback", 0, 0.0, 45.0, 0.0],
		["bottomless", 0, 0.0, 90.0, 0.0],
	]
	for row in want:
		var id := str(row[0])
		var r := Abilities.get_resource(id)
		assert_eq(int(r.cast_type), int(row[1]), "%s: how it is cast" % id)
		if int(row[1]) != 0:
			assert_eq(float(r.cast_time), float(row[2]), "%s: cast time" % id)
		assert_eq(float(r.cooldown), float(row[3]), "%s: cooldown" % id)
		assert_eq(float(r.damage), float(row[4]), "%s: damage" % id)
	assert_eq(float(Abilities.get_resource("pall").radius), 6.0)
	assert_false(bool(Abilities.get_resource("pall").requires_target), "aimed at the ground")
	assert_false(bool(Abilities.get_resource("bottomless").requires_target))
	var p := _player()
	for id in ["blight", "erode"]:
		assert_true(p.ENEMY_BOLTS.has(id), "%s is cast at an enemy like the bolts" % id)
	for id in ["calldue", "gnaw", "spill", "takeitback", "bottomless", "pall"]:
		assert_false(p.ENEMY_BOLTS.has(id))
		assert_true(p.on_gcd(id), "%s is on the global cooldown" % id)
	for m in ["_tick_decay", "_on_damage_dealt_shadow", "_call_due", "_gnaw", "_spill", "_take_it_back",
			"_start_bottomless", "_hush", "_start_pall", "_cast_pall", "_blight_now", "_clear_decay", "decay_on"]:
		assert_true(_has_method(m), "player.gd has %s" % m)

func test_decay_numbers() -> void:
	assert_eq(Balance.DECAY_TICK, 1.0)
	assert_eq(Balance.DECAY_TICK_PCT, 8.0)
	assert_eq(Balance.DECAY_OPEN_TIME, 15.0)
	assert_eq(Balance.DECAY_FEED_PCT, 50.0)
	assert_eq(Balance.BLIGHT_FEED_PCT, 100.0)
	assert_eq(Balance.DECAY_LAST_DROP, 1.0)
	assert_eq(Balance.DECAY_JUMP_RADIUS, 10.0)
	assert_eq(float(Abilities.get_resource("calldue").cooldown), Balance.DECAY_OPEN_TIME,
		"the loop: Blight, grow it for as long as it is open, Call Due")

func test_a_tick_takes_its_share_and_the_decay_shrinks_by_it() -> void:
	var p := _player()
	assert_eq(DecayKit.decay_tick(1000.0), 80.0, "8%")
	assert_eq(DecayKit.decay_tick(0.0), 0.0)
	assert_eq(DecayKit.decay_tick(-5.0), 0.0)
	# Over time: half of it is dealt in about 8 ticks, and it never grows by itself.
	var left := 1000.0
	var dealt := 0.0
	for i in 8:
		var t: float = DecayKit.decay_tick(left)
		left -= t
		dealt += t
	assert_true(dealt > 480.0 and dealt < 490.0, "about half after 8 ticks: %s" % dealt)
	assert_true(is_equal_approx(left + dealt, 1000.0), "nothing is lost")

func test_haste_and_gnaw_make_it_tick_faster() -> void:
	var p := _player()
	assert_eq(DecayKit.decay_interval(1.0), 1.0)
	assert_true(is_equal_approx(DecayKit.decay_interval(1.25), 0.8), "25% Haste: 25% more ticks")
	assert_eq(Balance.GNAW_TIME, 4.0)
	assert_eq(Balance.GNAW_SPEED_MULT, 2.0)
	assert_eq(DecayKit.decay_interval(1.0, true), 0.5, "Gnaw: twice as often")
	assert_true(is_equal_approx(DecayKit.decay_interval(1.25, true), 0.4), "they multiply")
	assert_true(DecayKit.decay_interval(1000.0, true) >= 0.05, "never faster than the game can tick")

func test_what_feeds_an_open_decay() -> void:
	var p := _player()
	var strike := PackedStringArray(["Ability", "Shadow", "Melee"])
	var frost := PackedStringArray(["Frost", "Spell", "Projectile"])
	assert_true(DecayKit.shadow_spell(SHADOW))
	assert_false(DecayKit.shadow_spell(strike), "a weapon ability is not a spell")
	assert_false(DecayKit.shadow_spell(frost))
	assert_eq(DecayKit.decay_feed_pct("blight", SHADOW, false, false), 100.0, "all of Blight's own damage")
	# Erode (Beckon) is the spell that builds it: all of its damage too.
	assert_eq(Balance.ERODE_FEED_PCT, 100.0)
	assert_eq(DecayKit.decay_feed_pct("erode", Abilities.tags_of("erode"), false, false), 100.0, "all of Erode's")
	assert_contains(str(Abilities.get_resource("erode").description), "{b:ERODE_FEED_PCT}")
	for id in ["gnaw", "pall", "hush", "corruption"]:
		assert_eq(DecayKit.decay_feed_pct(id, Abilities.tags_of(id), false, false), 50.0, "%s: half of what it deals" % id)
	# Never a tick, a proc, or Decay's own damage.
	assert_eq(DecayKit.decay_feed_pct("erode", SHADOW, false, true), 0.0, "damage over time does not feed it")
	assert_eq(DecayKit.decay_feed_pct("erode", SHADOW, true, false), 0.0, "a proc does not feed it")
	assert_eq(DecayKit.decay_feed_pct(DecayKit.DECAY_HIT_ID, PackedStringArray(DecayKit.DECAY_TAGS), false, true), 0.0, "its own ticks")
	assert_eq(DecayKit.decay_feed_pct("calldue", SHADOW, false, false), 0.0, "taking it out does not put it back")
	# Other builds get nothing for free ...
	assert_eq(DecayKit.decay_feed_pct("shadowstrike", strike, false, false), 0.0)
	assert_eq(DecayKit.decay_feed_pct("frostbolt", frost, false, false), 0.0)
	# ... only through the talent Tainted Steel and the Rune of Rot.
	assert_eq(DecayKit.decay_feed_pct("shadowstrike", strike, false, false, 30.0, 15.0), 30.0, "Tainted Steel: Shadow abilities")
	assert_eq(DecayKit.decay_feed_pct("frostbolt", frost, false, false, 30.0, 15.0), 15.0, "Rune of Rot: other books' spells")
	assert_eq(DecayKit.decay_feed_pct("froststrike", PackedStringArray(["Ability", "Melee"]), false, false, 30.0, 15.0), 0.0,
		"another book's ability feeds nothing")
	assert_eq(DecayKit.decay_feed_pct("gnaw", SHADOW, false, false, 30.0, 15.0), 50.0, "the talents change nothing for Shadow spells")
	assert_eq(DecayKit.decay_feed_pct("erode", SHADOW, false, false, 30.0, 15.0), 100.0)

func test_only_a_closed_decay_ends_with_a_last_drop() -> void:
	var p := _player()
	assert_true(DecayKit.decay_last_drop(99.0, false, 100.0), "closed and under one standard hit: the next tick deals all of it")
	assert_false(DecayKit.decay_last_drop(100.0, false, 100.0))
	assert_false(DecayKit.decay_last_drop(5.0, true, 100.0), "an open one never ends that way: a fresh Blight stays")
	assert_true(DecayKit.decay_last_drop(0.0, false, 100.0), "an empty closed one just goes")
	# So a tick is never less than 8% of a standard hit.
	assert_eq(DecayKit.decay_tick(Balance.DECAY_LAST_DROP * 100.0), 8.0)

func test_call_due() -> void:
	var p := _player()
	assert_eq(Balance.CALL_DUE_BONUS_PCT, 25.0)
	assert_eq(DecayKit.call_due_damage(1000.0), 1250.0, "all of it, and a quarter more")
	assert_eq(DecayKit.call_due_damage(0.0), 0.0)
	assert_contains(str(Abilities.get_resource("calldue").description), "cannot critically strike")
	assert_false(Abilities.has_scaling("calldue"), "its damage is the Decay: nothing of its own to scale")

func test_spill_copies_and_merges() -> void:
	var p := _player()
	assert_eq(Balance.SPILL_PCT, 50.0)
	assert_eq(Balance.SPILL_TARGETS, 4)
	assert_eq(Balance.SPILL_RADIUS, 8.0)
	assert_eq(DecayKit.spill_amount(600.0), 300.0)
	assert_eq(DecayKit.spill_error(0.0, 3), DecayKit.DECAY_ERROR)
	assert_ne(DecayKit.spill_error(600.0, 0), "", "nobody to copy it onto")
	assert_eq(DecayKit.spill_error(600.0, 1), "")
	# A copy (and what a dead enemy leaves) is added to my Decay there, and keeps the longer open time.
	assert_eq(DecayKit.decay_merge(200.0, 50.0, 300.0, 58.0), [500.0, 58.0])
	assert_eq(DecayKit.decay_merge(200.0, 60.0, 300.0, 58.0), [500.0, 60.0], "never closes one that was open for longer")
	assert_eq(DecayKit.decay_merge(0.0, 0.0, 300.0, 58.0), [300.0, 58.0], "onto an enemy without any")

func test_take_it_back_and_bottomless() -> void:
	var p := _player()
	assert_eq(Balance.TAKE_IT_BACK_PCT, 30.0)
	assert_eq(Balance.TAKE_IT_BACK_TIME, 8.0)
	assert_eq(DecayKit.take_back_amount(1000.0), 300.0)
	assert_eq(Balance.BOTTOMLESS_TIME, 8.0)
	for id in ["takeitback", "bottomless", "spill"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)
	for id in ["blight", "erode", "gnaw", "pall", "hush"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)

func test_hush_is_an_interrupt() -> void:
	var p := _player()
	assert_eq(float(Balance.INTERRUPT_LOCKOUT.get("hush", 0.0)), 3.0, "3 s lockout")
	assert_true(Abilities.is_interrupt("hush"))
	assert_true(Abilities.get_resource("hush").tags.has("Interrupt"))
	assert_false(p.on_gcd("hush"), "off the global cooldown")
	assert_true(float(Abilities.get_resource("hush").cooldown) >= Balance.INTERRUPT_SHARED_COOLDOWN)
	assert_true(Abilities.tooltip("hush").contains(Abilities.interrupt_note()))
	assert_eq(Balance.HUSH_DECAY, 1.0)
	assert_eq(DecayKit.hush_decay(460.0), 460.0, "a standard spell hit's worth when it stops a cast")

## The editor keeps the effect files it loaded when it started. This brings its
## copies of the two debuffs up to date with their files (in place: everything
## that holds them sees it), so a text change is tested without a restart.
func _refresh_effects() -> void:
	for id in ["decay", "decay_closed"]:
		ResourceLoader.load("res://data/effects/%s.tres" % id, "", ResourceLoader.CACHE_MODE_REPLACE)

func test_the_debuff_shows_the_amount_and_the_open_time() -> void:
	_refresh_effects()
	Balance.apply_effects()
	var open: Resource = Effects.get_effect("decay")
	var closed: Resource = Effects.get_effect("decay_closed")
	assert_true(open != null and closed != null)
	assert_eq(str(open.display_name), "Breach", "the name it has in the game (its id keeps the first one)")
	assert_eq(str(closed.display_name), "Closed Breach")
	assert_eq(float(open.duration), Balance.DECAY_OPEN_TIME, "the open one lasts as long as it is open")
	for fx in [open, closed]:
		assert_true(bool(fx.is_debuff))
		assert_true(bool(fx.per_caster), "own only: every caster has their own")
		assert_eq(float(fx.tick_damage), 0.0, "its caster deals the damage, not the effect")
		assert_true(fx.tags.has("DoT"))
		assert_true(int(fx.max_stacks) >= 1000000, "room for the amount")
		assert_eq(TextFill.leftover(TextFill.effect(fx)), "")
	# What makes the icon show a number and no clock (read from the files, so this
	# holds even while the editor still has the old script loaded).
	var f_open := _fields("res://data/effects/decay.tres")
	var f_closed := _fields("res://data/effects/decay_closed.tres")
	assert_eq(str(f_open.get("stacks_are_amount", "")), "true")
	assert_eq(str(f_closed.get("stacks_are_amount", "")), "true")
	assert_eq(str(f_closed.get("show_time", "")), "false", "a closed Decay has no clock")
	assert_false(f_open.has("show_time"), "an open one shows its open time")
	var script_text := FileAccess.get_file_as_string("res://scripts/data/status_effect_data.gd")
	assert_contains(script_text, "@export var stacks_are_amount: bool = false")
	assert_contains(script_text, "@export var show_time: bool = true")
	# The number as an icon shows it.
	assert_eq(StatusIcons.compact(850), "850")
	assert_eq(StatusIcons.compact(1240), "1.2k")
	assert_eq(StatusIcons.compact(34500), "34k")
	assert_eq(StatusIcons.compact(1500000), "1.5m")
	assert_eq(Details.spell_name(DecayKit.DECAY_HIT_ID), "Breach (Periodic)", "its ticks have their own line on the meter")

func test_decay_counts_as_my_damage_over_time() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	assert_false(st.has_dot_from(me))
	st.apply(Effects.get_effect("decay"), me)
	assert_true(st.has_dot_from(me), "Feed the Flames counts it")
	assert_false(st.has_dot_from(ally), "mine only")
	assert_true(st.has_from("decay", me))
	assert_false(st.has_from("decay", ally))
	# The amount rides on its stack count.
	assert_true(st.set_stacks_from("decay", me, 1240))
	st.apply(Effects.get_effect("decay"), ally)
	assert_eq(st.effects.size(), 2, "the ally's is a copy of its own")
	var rows: Array = st.list()
	assert_eq(rows.size(), 2)
	var mine: Dictionary = rows[0] if int(rows[0]["stacks"]) == 1240 else rows[1]
	assert_eq(int(mine["stacks"]), 1240)
	assert_true(rows[0].has("amount") and rows[0].has("timeless") and rows[0].has("mine"))
	# Reapplying it (Blight again) keeps the amount.
	st.apply(Effects.get_effect("decay"), me)
	assert_eq(int(st.effects[StatusContainer.key_for(Effects.get_effect("decay"), me)]["stacks"]), 1240)

func test_decay_is_a_keyword() -> void:
	assert_true(Keywords.KEYWORDS.has("decay"))
	var entry: Dictionary = Keywords.KEYWORDS["decay"]
	assert_eq(entry["forms"], ["Breach", "Breaches"])
	assert_eq(_typed_number(str(entry["text"])), "", "no number typed into it")
	var text := Keywords.keyword_text("decay")
	assert_eq(TextFill.leftover(text), "")
	assert_false(text.contains("?"), text)
	assert_contains(text, "%s%%" % TextFill.num(Balance.DECAY_TICK_PCT))
	assert_contains(text, Abilities.ability_name("blight"))
	assert_true(Keywords.mentions(str(Abilities.tooltip("erode"))).has("k:decay"))
	assert_true(Keywords.keywords_of("a:calldue").has("decay"), "searching for decay finds what works with it")
	# {ds:..}: a coefficient as the real damage of a spell hit.
	assert_eq(TextFill.constants("{ds:DECAY_LAST_DROP}"),
		str(Abilities.fmt_amount(Abilities.coef_damage(Balance.DECAY_LAST_DROP, PackedStringArray(["Spell"])))))

func test_tainted_steel_for_shadow_weapon_builds() -> void:
	# [key, name, slot, values]
	var want := [
		["shadow_tainted_steel", "Baited Steel", "shadow_r8c1", [10.0, 20.0, 30.0]],
	]
	for row in want:
		var id := Talents.id_for_key(str(row[0]))
		assert_eq(id, str(row[2]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), 3)
		assert_eq(t.get("values", []), row[3])
		assert_eq(Talents.required_ability(id), "", "a Breach talent: it keys off the Breach, not one ability")
		assert_eq(Talents.group_of(id), "The Breach")
		assert_true(bool(t.get("implemented", false)))
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "")
		assert_false(tip.contains("?"), tip)
		assert_eq(_typed_number(str(t.get("desc", ""))), "")
	for id in Talents.in_tree("shadow"):
		var placeholder := bool(Talents.get_talent(id).get("placeholder", true))
		assert_eq(TalentIcons.has_icon(id), not placeholder, "%s: designed talents have an icon, empty ones don't" % id)
	# Everything Rots is no talent any more (it is the Rune of Rot).
	assert_eq(Talents.id_for_key("shadow_everything_rots"), "")
	assert_false(TalentIcons.ICONED.has("shadow_everything_rots"))
	# No ability gates it: it does its part wherever a Breach of mine is open.
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	pd.talents = {Talents.id_for_key("shadow_tainted_steel"): 3}
	assert_eq(pd.talent_value("shadow_tainted_steel"), 30.0)
	pd.free()

func test_rune_of_rot() -> void:
	assert_true(Runes.PATHS.has("rot") and Runes.ALL.has("rot"), "registered")
	assert_eq(Runes.rarity("rot"), Runes.RARE)
	assert_eq(Runes.max_copies("rot"), 3, "up to three can be equipped")
	assert_eq(Runes.check_limits(["rot", "rot", "rot"]), "")
	assert_ne(Runes.check_limits(["rot", "rot", "rot", "rot"]), "", "a fourth is refused")
	assert_eq(Balance.ROT_RUNE_PCT, 5.0)
	var text := Runes.description("rot")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_false(text.contains("?"), text)
	assert_contains(text, "%s%%" % TextFill.num(Balance.ROT_RUNE_PCT))
	assert_eq(_typed_number(str(Runes.get_resource("rot").description)), "")
	# Each copy adds as much: what the talent's three ranks gave.
	var p := _player()
	assert_eq(DecayKit.rot_rune_pct(0), 0.0)
	assert_eq(DecayKit.rot_rune_pct(1), 5.0)
	assert_eq(DecayKit.rot_rune_pct(2), 10.0)
	assert_eq(DecayKit.rot_rune_pct(3), 15.0)
	assert_eq(DecayKit.rot_rune_pct(5), 15.0, "never more than three count")
	var frost := PackedStringArray(["Frost", "Spell", "Projectile"])
	assert_eq(DecayKit.decay_feed_pct("frostbolt", frost, false, false, 0.0, DecayKit.rot_rune_pct(2)), 10.0)
	assert_eq(DecayKit.decay_feed_pct("gnaw", SHADOW, false, false, 0.0, DecayKit.rot_rune_pct(3)), 50.0, "nothing changes for Shadow spells")
	var has_count := false
	for m in (load("res://scripts/rune_listener.gd") as GDScript).get_script_method_list():
		has_count = has_count or str(m["name"]) == "rune_count"
	assert_true(has_count, "the rune listener counts the copies equipped")

## Rune of the Long Fall (Epic): when half of what is left in the Breach would
## kill the enemy, all of it is dealt at once.
func test_rune_of_the_long_fall() -> void:
	assert_true(Runes.PATHS.has("long_fall") and Runes.ALL.has("long_fall"), "registered")
	assert_eq(Runes.rarity("long_fall"), Runes.EPIC)
	assert_eq(Runes.rune_name("long_fall"), "Rune of the Long Fall")
	assert_eq(Balance.LONG_FALL_PCT, 50.0)
	var text := Runes.description("long_fall")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_false(text.contains("?"), text)
	assert_contains(text, "%s%%" % TextFill.num(Balance.LONG_FALL_PCT))
	assert_eq(_typed_number(str(Runes.get_resource("long_fall").description)), "")
	var p := _player()
	assert_true(DecayKit.long_fall_applies(1000.0, 500.0), "half of it covers the enemy's health")
	assert_true(DecayKit.long_fall_applies(1000.0, 120.0))
	assert_false(DecayKit.long_fall_applies(1000.0, 501.0), "not quite")
	assert_false(DecayKit.long_fall_applies(0.0, 10.0), "no Breach")
	assert_false(DecayKit.long_fall_applies(1000.0, 0.0), "an enemy that is already dead")
	# It is a hit, dealt like every other one (the enemy takes the damage and may
	# survive it): a rune's, with its own line on the meter, and it feeds nothing.
	assert_eq(DecayKit.LONG_FALL_HIT_ID, "rune_long_fall")
	assert_eq(Details.spell_name(DecayKit.LONG_FALL_HIT_ID), "Rune of the Long Fall")
	assert_eq(DecayKit.decay_feed_pct(DecayKit.LONG_FALL_HIT_ID, SHADOW, true, false), 0.0)
	var src := PlayerSource.text()
	assert_contains(src, "_decay_hit(foe, all, LONG_FALL_HIT_ID, false, [], 0.0, true)")

func test_many_hands_is_the_ground_spell() -> void:
	# (It keeps the ability id of its first name.)
	var r: Resource = ResourceLoader.load("res://data/abilities/pall.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(str(r.display_name), "Many Hands")
	assert_eq(str(r.id), "pall")
	assert_false(RegEx.create_from_string("\\b(Pall|Smother|Smothers)\\b").search(str(r.description)) != null, "the old names are gone from its text")

## The theme: a Breach, a hole under the enemy that demons claw at its feet
## through (so it is open or closed). The ids, the constants and the code keep
## the first names; nothing the player reads does.
func test_the_breach_theme() -> void:
	var names := {"blight": "Break Ground", "erode": "Beckon", "calldue": "Call Due", "gnaw": "Gnaw",
		"spill": "Widen", "pall": "Many Hands", "hush": "Hush", "takeitback": "Take It Back", "bottomless": "Bottomless"}
	for id in names:
		assert_eq(Abilities.ability_name(id), str(names[id]))
	assert_eq(Runes.rune_name("open_wound"), "Rune of the Trapdoor")
	assert_eq(Runes.rune_name("rot"), "Rune of Invitation")
	_refresh_effects()
	Balance.apply_effects()
	var texts: Array[String] = []
	for id in NEW:
		texts.append(Abilities.ability_name(id) + ": " + Abilities.tooltip(id))
	for id in ["decay", "decay_closed"]:
		texts.append(str(Effects.get_effect(id).display_name) + ": " + TextFill.effect(Effects.get_effect(id)))
	for id in ["open_wound", "rot", "long_fall"]:
		texts.append(Runes.rune_name(id) + ": " + Runes.description(id))
	for id in Talents.in_tree("shadow"):
		if not bool(Talents.get_talent(id).get("placeholder", true)):
			texts.append(str(Talents.get_talent(id).get("name", "")) + ": " + Talents.tooltip(id, 1) + " " + Talents.capstone_text(id))
	texts.append(Keywords.keyword_text("decay"))
	texts.append(str(DecayKit.DECAY_ERROR))
	var old := RegEx.create_from_string("\\b(Decay|Blight|Blights|Erode|Erodes|Sink In|Spill|Spills|Smother|Smothers|Pall|Rot|Rots|Seep|Tainted|Open Wound|last drop)\\b")
	for text in texts:
		var m := old.search(text)
		assert_true(m == null, "\"%s\" is still in: %s" % [m.get_string() if m else "", text.left(100)])
	# Everything that works with it says so by name.
	for id in ["blight", "erode", "calldue", "gnaw", "spill", "hush", "takeitback", "bottomless"]:
		assert_contains(Abilities.tooltip(id), "Breach")
	for id in ["open_wound", "rot", "long_fall"]:
		assert_contains(Runes.description(id), "Breach")
	# The words it uses elsewhere in the game stay free: the dungeons' gates and
	# exit portal, Collapse's rift, the dungeon called the Pit.
	for text in texts:
		assert_true(RegEx.create_from_string("(?i)\\b(gate|portal|rift|pit)\\b").search(text) == null, text.left(100))

func test_rune_of_the_open_wound() -> void:
	assert_true(Runes.PATHS.has("open_wound") and Runes.ALL.has("open_wound"), "registered")
	assert_eq(Runes.rarity("open_wound"), Runes.RARE)
	assert_eq(Runes.max_copies("open_wound"), 1)
	assert_eq(Balance.OPEN_WOUND_COOLDOWN, 15.0)
	assert_eq(Balance.OPEN_WOUND_OPEN_TIME, 8.0)
	var text := Runes.description("open_wound")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_false(text.contains("?"), text)
	assert_contains(text, Abilities.ability_name("blight"))
	assert_contains(text, "instant")
	assert_eq(_typed_number(str(Runes.get_resource("open_wound").description)), "")
	var p := _player()
	assert_eq(DecayKit.blight_open_time(false), 15.0)
	assert_eq(DecayKit.blight_open_time(true), 8.0, "with the rune it opens Decay for less time")

## Usher In ("sinkin") and Gloom Bolt ("shadowbolt") were removed. No list has
## them, nobody starts with them, and a saved bar or draft that had them drops
## them when it is loaded (SaveSystem keeps only what Abilities knows).
func test_usher_in_and_gloom_bolt_are_gone() -> void:
	for id in ["sinkin", "shadowbolt"]:
		assert_false(Abilities.PATHS.has(id), "%s is no ability" % id)
		assert_true(Abilities.get_resource(id) == null)
		assert_false(Abilities.ALL.has(id))
		assert_false(Abilities.DRAFT_POOL.has(id))
		assert_false(Abilities.BASE.has(id), "nobody starts with %s" % id)
		assert_false(Abilities.CATEGORY_OF.has(id))
		assert_false(Abilities.ICON_FORM.has(id))
		assert_false(SkillCards.ALL.has(id))
		assert_false(Balance.ABILITIES.has(id))
		assert_false(_player().ENEMY_BOLTS.has(id))
		assert_false(PlayerDataScript.default_action_bar().has(id), "a new character's bar does not have %s" % id)
	for name in ["Usher In", "Gloom Bolt"]:
		for id in Abilities.PATHS:
			assert_ne(Abilities.ability_name(id), name)
			assert_false(Abilities.tooltip(id).contains(name), "%s still speaks of %s" % [id, name])
		for id in Talents.in_tree("shadow"):
			assert_false(Talents.tooltip(id, 1).contains(name), "%s still speaks of %s" % [id, name])
	# The talent that was about Usher In went with it.
	assert_eq(Talents.id_for_key("shadow_loose_grains"), "")
	assert_false(TalentIcons.ICONED.has("shadow_loose_grains"))
	var bar := PlayerDataScript.default_action_bar()
	assert_eq([bar[0], bar[1], bar[2], bar[3], bar[4]], ["frostbolt", "fireball", "lightningbolt", "psalm", ""])
