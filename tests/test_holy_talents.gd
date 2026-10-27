@tool
extends McpTestSuite

# The Holy tree's older talents: the open ones (Grace, Steadfast, Overflowing,
# Penitent, Zeal, Watchful Eye, Second Breath), Burnished, Long Note and the 5-rank
# Censer's Weight, Sunsteel and Radiance. Rules: holy_talents.gd; Steadfast in
# PlayerData. The tree itself and the newer talents: tests/test_holy_tree.gd.

const Talents = preload("res://scripts/talents.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")

func suite_name() -> String:
	return "holy_talents"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func test_overflowing() -> void:
	var p := _p()
	assert_eq(HolyTalentsKit.overflowing_shield(100, 20.0, 1000), 20, "20% of the overhealing")
	assert_eq(HolyTalentsKit.overflowing_shield(5000, 30.0, 1000), 100, "never more than 10% of their max health")
	assert_eq(HolyTalentsKit.overflowing_shield(0, 30.0, 1000), 0, "no overhealing, no shield")
	assert_eq(HolyTalentsKit.overflowing_shield(-50, 30.0, 1000), 0)
	assert_contains(PlayerSource.text(), "_overflowing(tgt, amount, id)")

func test_penitent_and_zeal() -> void:
	var p := _p()
	assert_true(HolyTalentsKit.penitent_hit(150, 1000), "15% of max health")
	assert_false(HolyTalentsKit.penitent_hit(149, 1000))
	assert_false(HolyTalentsKit.penitent_hit(500, 0))
	assert_true(HolyTalentsKit.zeal_counts(30.0), "a 30 sec cooldown counts")
	assert_false(HolyTalentsKit.zeal_counts(29.9))

func test_radiance_counts_holy_heals() -> void:
	var p := _p()
	for id in ["psalm", "outpour", "gleam", "brightlance", "absolve", "benediction", "prism_shatter", "light_mote"]:
		assert_true(HolyTalentsKit.is_holy_heal(id), "%s is a Holy heal" % id)
	for id in ["dewfall", "patchup", "lifesteal"]:
		assert_false(HolyTalentsKit.is_holy_heal(id), "%s is not" % id)

func test_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "_holy_talents_outgoing(info)   # Burnished, Censer's Weight, Sunsteel")
	assert_contains(src, "var grace := 1.0 + _talent(\"holy_grace\") / 100.0 if other else 1.0")
	assert_contains(src, "_penitent_hit(info)")
	assert_contains(src, "_bus().cast_finished.connect(_zeal_on_cast)")
	assert_contains(src, "bulwark_song_time(matches, full) + _talent(\"holy_long_note\")")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player_data.gd"), "talent_value(\"holy_steadfast\")")
	assert_contains(Abilities.tooltip("singvigil"), "less damage for")

# --- Shared by several specs -------------------------------------------------------------------

func test_single_ability_talents_need_it() -> void:
	var req := {"holy_heavy_chain": "censerswing", "holy_absolution": "absolve", "holy_unbroken": "unfallen",
		"holy_steady_aim": "refractingshot", "holy_swelling_chorus": "singchorus", "holy_quick_lance": "brightlance",
		"holy_full_quiver": "prismarrow", "holy_wide_break": "prismbreaker", "holy_steady_ray": "mendingray"}
	for key in req:
		assert_eq(str(Talents.get_talent(Talents.id_for_key(key)).get("requires", "")), str(req[key]), "%s requires its ability" % key)
	# The casts get shorter in the tooltip too.
	assert_contains(FileAccess.get_file_as_string("res://scripts/abilities.gd"), "t = maxf(t - talent(\"holy_steady_aim\"), 0.2)")
	assert_eq(Abilities.COOLDOWN_TALENTS.get("prismarrow", ""), "holy_full_quiver")
	assert_false(Abilities.COOLDOWN_TALENTS.has("lastverse"), "Last Rites was folded into Last Verse")

func test_second_breath() -> void:
	var p := _p()
	assert_true(HolyTalentsKit.second_breath(200, 1000, 400), "20% to 60%: a save")
	assert_false(HolyTalentsKit.second_breath(300, 1000, 400), "it has to start below 30%")
	assert_false(HolyTalentsKit.second_breath(200, 1000, 250), "and end above 50%")
	assert_false(HolyTalentsKit.second_breath(0, 0, 100))

func test_shared_hooks() -> void:
	var src := PlayerSource.text()
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
	assert_contains(PlayerSource.text(),
		"return Balance.PRISM_MAX + (1 if _has_rune(FOURTH_FACET_RUNE) else 0)")

func test_watchful_eye() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "if not is_same(tgt, self) and hit_recently(tgt, Balance.WATCHFUL_EYE_WINDOW):")
	assert_contains(FileAccess.get_file_as_string("res://scripts/net/remote_player.gd"), "hurt_at = Time.get_ticks_msec() / 1000.0")
	# A puppet hit just now counts; one hit long ago doesn't.
	var pl: Node = track(_p().new())
	var puppet: Node = track(Node.new())
	var stand_in := GDScript.new()
	stand_in.source_code = "@tool\nextends Node\nvar hurt_at := -100.0\n"
	stand_in.reload()
	puppet.set_script(stand_in)   # (a puppet: only what Watchful Eye reads)
	puppet.set("hurt_at", Time.get_ticks_msec() / 1000.0)
	assert_true(pl.hit_recently(puppet, Balance.WATCHFUL_EYE_WINDOW))
	puppet.set("hurt_at", -100.0)
	assert_false(pl.hit_recently(puppet, Balance.WATCHFUL_EYE_WINDOW))
