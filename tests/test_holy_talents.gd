@tool
extends McpTestSuite

# The Holy tree's open talents (Grace, Burnished, Steadfast, Overflowing,
# Penitent, Zeal), Long Note (Hymns) and the bottom row's 5-rank talents
# (Censer's Weight, Sunsteel, Radiance). Rules: player.gd, "Holy: the open
# talents and the bottom row"; Steadfast in PlayerData.

const Talents = preload("res://scripts/talents.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")

const NEW := {"r1c1": "holy_grace", "r1c7": "holy_burnished", "r2c4": "holy_steadfast", "r3c1": "holy_long_note",
	"r3c7": "holy_overflowing", "r9c1": "holy_penitent", "r9c7": "holy_zeal",
	"r10c3": "holy_censers_weight", "r10c4": "holy_sunsteel", "r10c5": "holy_radiance",
	"r2c2": "holy_clear_mind", "r2c6": "holy_sheltering_light", "r5c4": "holy_long_glass", "r10c6": "holy_second_breath",
	"r4c1": "holy_heavy_chain", "r5c1": "holy_absolution", "r10c2": "holy_unbroken", "r3c4": "holy_glimmering",
	"r7c4": "holy_steady_aim", "r4c7": "holy_swelling_chorus", "r5c7": "holy_quick_lance",
	"r8c4": "holy_full_quiver", "r9c4": "holy_wide_break", "r6c1": "holy_watchful_eye", "r6c7": "holy_last_rites",
	"r7c3": "holy_bright_motes", "r7c5": "holy_steady_ray"}

func suite_name() -> String:
	return "holy_talents"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func test_placement() -> void:
	for slot in NEW:
		var id := "holy_%s" % slot
		var t := Talents.get_talent(id)
		assert_false(bool(t.get("placeholder", true)), "%s is a real talent" % id)
		assert_eq(Talents.id_for_key(str(NEW[slot])), id, "%s sits in %s" % [NEW[slot], slot])
		var text := Talents.description(id)
		assert_false(text.contains("{b:"), "%s: its numbers are filled in" % id)
	# The bottom row: three 5-rank talents.
	for slot in ["r10c3", "r10c4", "r10c5"]:
		assert_eq(int(Talents.get_talent("holy_%s" % slot)["max_rank"]), 5, "%s has 5 ranks" % slot)
	# Every old talent kept its place (no save migration).
	assert_eq(Talents.id_for_key("holy_key_change"), "holy_r2c1")
	assert_eq(Talents.id_for_key("holy_mote_magnet"), "holy_r3c3")
	assert_eq(Talents.id_for_key("holy_clear_glass"), "holy_r3c5")
	assert_eq(Talents.id_for_key("holy_long_volley"), "holy_r9c5")

func test_overflowing() -> void:
	var p := _p()
	assert_eq(p.overflowing_shield(100, 20.0, 1000), 20, "20% of the overhealing")
	assert_eq(p.overflowing_shield(5000, 30.0, 1000), 100, "never more than 10% of their max health")
	assert_eq(p.overflowing_shield(0, 30.0, 1000), 0, "no overhealing, no shield")
	assert_eq(p.overflowing_shield(-50, 30.0, 1000), 0)
	assert_contains(FileAccess.get_file_as_string("res://scripts/player.gd"), "_overflowing(tgt, amount, id)")

func test_penitent_and_zeal() -> void:
	var p := _p()
	assert_true(p.penitent_hit(150, 1000), "15% of max health")
	assert_false(p.penitent_hit(149, 1000))
	assert_false(p.penitent_hit(500, 0))
	assert_true(p.zeal_counts(30.0), "a 30 sec cooldown counts")
	assert_false(p.zeal_counts(29.9))

func test_radiance_counts_holy_heals() -> void:
	var p := _p()
	for id in ["psalm", "outpour", "gleam", "brightlance", "absolve", "benediction", "prism_shatter", "light_mote"]:
		assert_true(p.is_holy_heal(id), "%s is a Holy heal" % id)
	for id in ["secondwind", "patchup", "lifesteal"]:
		assert_false(p.is_holy_heal(id), "%s is not" % id)

func test_hooks_are_in_place() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	assert_contains(src, "_holy_talents_outgoing(info)   # Burnished, Censer's Weight, Sunsteel")
	assert_contains(src, "var grace := 1.0 + _talent(\"holy_grace\") / 100.0 if other else 1.0")
	assert_contains(src, "_penitent_hit(info)")
	assert_contains(src, "_bus().cast_finished.connect(_zeal_on_cast)")
	assert_contains(src, "bulwark_song_time(matches, full) + _talent(\"holy_long_note\")")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player_data.gd"), "talent_value(\"holy_steadfast\")")
	assert_contains(Abilities.tooltip("singvigil"), "less damage for")

# --- Shared by several specs -------------------------------------------------------------------

func test_no_empty_slots() -> void:
	for id in Talents.in_tree("holy"):
		assert_false(bool(Talents.get_talent(id).get("placeholder", false)), "%s is filled" % id)
	# Single-ability talents need their ability.
	var req := {"holy_heavy_chain": "censerswing", "holy_absolution": "absolve", "holy_unbroken": "unfallen",
		"holy_glimmering": "glimmershot", "holy_steady_aim": "refractingshot", "holy_swelling_chorus": "singchorus",
		"holy_quick_lance": "brightlance"}
	for key in req:
		assert_eq(str(Talents.get_talent(Talents.id_for_key(key)).get("requires", "")), str(req[key]), "%s requires its ability" % key)
	# The casts get shorter in the tooltip too.
	assert_contains(FileAccess.get_file_as_string("res://scripts/abilities.gd"), "t = maxf(t - talent(\"holy_steady_aim\"), 0.2)")

func test_second_breath() -> void:
	var p := _p()
	assert_true(p.second_breath(200, 1000, 400), "20% to 60%: a save")
	assert_false(p.second_breath(300, 1000, 400), "it has to start below 30%")
	assert_false(p.second_breath(200, 1000, 250), "and end above 50%")
	assert_false(p.second_breath(0, 0, 100))

func test_shared_hooks() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	assert_contains(src, "if is_holy_heal(id):\n\t\tcost *= 1.0 - _talent(\"holy_clear_mind\") / 100.0")
	assert_contains(src, "amount = int(round(float(amount) * (1.0 + _talent(\"holy_sheltering_light\") / 100.0)))")
	assert_contains(src, "_second_breath(tgt, amount, id)")
	assert_contains(src, "return Balance.PRISM_TIME + _talent(\"holy_long_glass\")")
	assert_contains(src, "while _prisms.size() > _prism_max():")
	# The test_pacts line stays untouched.
	assert_contains(src, "cost *= mana_unit() * _pact_cost_mult(\"mana\")")

func test_fourth_facet_rune() -> void:
	const Runes = preload("res://scripts/runes.gd")
	assert_true(Runes.ALL.has("fourth_facet"))
	assert_eq(Runes.rarity_name("fourth_facet"), "Epic")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player.gd"),
		"return Balance.PRISM_MAX + (1 if _has_rune(FOURTH_FACET_RUNE) else 0)")

# --- The tree is full ------------------------------------------------------------------------

func test_the_tree_is_full() -> void:
	assert_eq(Talents.in_tree("holy").size(), Talents.ROWS * Talents.MAX_PER_ROW, "every slot of a full tree")
	var req := {"holy_full_quiver": "prismarrow", "holy_wide_break": "prismbreaker", "holy_last_rites": "lastverse",
		"holy_bright_motes": "censerswing", "holy_steady_ray": "mendingray"}
	for key in req:
		assert_eq(str(Talents.get_talent(Talents.id_for_key(key)).get("requires", "")), str(req[key]), "%s requires its ability" % key)
	assert_eq(Abilities.COOLDOWN_TALENTS.get("prismarrow", ""), "holy_full_quiver")
	assert_eq(Abilities.COOLDOWN_TALENTS.get("lastverse", ""), "holy_last_rites")

func test_watchful_eye() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player.gd")
	assert_contains(src, "if not is_same(tgt, self) and hit_recently(tgt, Balance.WATCHFUL_EYE_WINDOW):")
	assert_contains(FileAccess.get_file_as_string("res://scripts/net/remote_player.gd"), "hurt_at = Time.get_ticks_msec() / 1000.0")
	# A puppet hit just now counts; one hit long ago doesn't.
	var pl: Node = track(_p().new())
	var puppet: Node = track(Node.new())
	var stand_in := GDScript.new()
	stand_in.source_code = "extends Node\nvar hurt_at := -100.0\n"
	stand_in.reload()
	puppet.set_script(stand_in)   # (a puppet: only what Watchful Eye reads)
	puppet.set("hurt_at", Time.get_ticks_msec() / 1000.0)
	assert_true(pl.hit_recently(puppet, Balance.WATCHFUL_EYE_WINDOW))
	puppet.set("hurt_at", -100.0)
	assert_false(pl.hit_recently(puppet, Balance.WATCHFUL_EYE_WINDOW))
