@tool
extends McpTestSuite

# Frost talents (rows 5-9, capstones) and the Frost / Menace runes.

const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const Shields = preload("res://scripts/core/shields.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")

const NEW_KEYS := ["frost_clean_break", "frost_piercing_cold", "frost_dot_duration",
	"frost_cold_snap", "frost_splinter", "frost_shardstorm", "frost_shield_armor",
	"frost_slow_threat", "frost_slow_dr", "frost_glacial_heart", "frost_deep_freeze",
	"frost_ice_floe", "frost_shatterpoint", "frost_instinct"]

func suite_name() -> String:
	return "frost_talents"

func test_new_talents_sit_in_layout_slots() -> void:
	for key in NEW_KEYS:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "talent key %s has a slot in the Frost layout" % key)
		var t := Talents.get_talent(id)
		assert_false(bool(t.get("placeholder", true)), "%s is a real talent" % key)
		assert_eq(Array(t.get("values", [])).size(), int(t["max_rank"]), "%s has one value per rank" % key)

func test_splintering_cold_links() -> void:
	var src := Talents.id_for_key("frost_shard_proc")
	assert_eq(src, "frost_r3c4")
	# Ice Shards run down the middle: Splintering Cold -> Shardstorm -> Splintering.
	var storm := Talents.id_for_key("frost_shardstorm")
	assert_true(Talents.targets_of(src).has(storm), "links to Shardstorm")
	assert_true(Talents.targets_of(storm).has(Talents.id_for_key("frost_splinter")), "Shardstorm links to Splintering")
	assert_eq(storm, "frost_r6c4", "Shardstorm under Splintering Cold")
	assert_eq(Talents.id_for_key("frost_splinter"), "frost_r7c4", "Splintering under Shardstorm")
	assert_eq(Talents.id_for_key("frost_shield_armor"), "frost_r4c7", "Hardened Frost on the right edge, under Rime Ward")
	assert_eq(Talents.id_for_key("frost_discipline"), "frost_r2c2", "Cold Discipline in row 2")
	assert_eq(Talents.links_in_tree("frost").size(), 6, "six lines drawn in the Frost book")

func test_links_dont_skip_rows() -> void:
	var PD = load("res://scripts/player_data.gd")
	var ranks := {"frost_r1c3": 3, "frost_r2c2": 3, "frost_r3c4": 3,
		Talents.id_for_key("frost_shardstorm"): 2, Talents.id_for_key("frost_splinter"): 1}
	assert_true(PD.talents_valid(ranks), "maxed Splintering Cold opens Shardstorm, and maxed Shardstorm opens Splintering")
	ranks[Talents.id_for_key("frost_piercing_cold")] = 1   # row 6, next to Shardstorm, not linked
	assert_false(PD.talents_valid(ranks), "points in link-opened talents don't open their rows")

func test_talent_icons() -> void:
	const TalentIcons = preload("res://scripts/talent_icons.gd")
	for key in TalentIcons.ICONED:
		assert_ne(Talents.id_for_key(key), "", "icon key %s is a real talent" % key)
	for id in Talents.in_tree("frost"):
		var placeholder := bool(Talents.get_talent(id).get("placeholder", true))
		assert_eq(TalentIcons.has_icon(id), not placeholder, "%s: designed talents have an icon, empty ones don't" % id)
	assert_eq(Talents.id_for_key("frost_glacial_heart"), "frost_r10c3", "Glacial Heart in the bottom row")
	assert_eq(Talents.id_for_key("frost_deep_freeze"), "frost_r10c5", "Deep Freeze in the bottom row")

func test_capstones() -> void:
	for key in ["frost_glacial_heart", "frost_deep_freeze"]:
		assert_true(Talents.has_capstone(Talents.id_for_key(key)), "%s has a capstone" % key)
	assert_false(Talents.has_capstone(Talents.id_for_key("frost_haste")), "ordinary talents have none")
	var id := Talents.id_for_key("frost_deep_freeze")
	assert_contains(Talents.tooltip(id, 1), "Capstone (at rank 5)")
	assert_contains(Talents.tooltip(id, 5), "Capstone (active)")

func test_every_rune_loads() -> void:
	for id in Runes.ALL:
		assert_true(Runes.PATHS.has(id), "%s has a path" % id)
		var r: Resource = ResourceLoader.load(Runes.PATHS[id], "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_true(r != null, "%s loads" % id)
		if r:
			assert_eq(str(r.id), id, "%s id matches" % id)
	assert_eq(Runes.ALL.size(), Runes.PATHS.size(), "ALL and PATHS list the same runes")

func test_menace_runes() -> void:
	for dtype in ["physical", "fire", "frost", "lightning", "arcane", "shadow", "nature", "holy"]:
		var r: Resource = ResourceLoader.load("res://data/runes/menace_%s.tres" % dtype, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_eq(float(r.get("threat_bonus_pct")), 30.0, "menace_%s: +30%% threat" % dtype)
		assert_eq(int(r.trigger), 6, "menace_%s is PASSIVE" % dtype)
		assert_true(PackedStringArray(r.get("required_damage_types")).has(dtype), "menace_%s matches %s" % [dtype, dtype])
		assert_eq(Runes.rarity("menace_" + dtype), Runes.COMMON, "menace_%s is common" % dtype)
	for id in ["permafrost", "cold_precision", "frozen_aegis", "everlasting_rime"]:
		assert_eq(Runes.rarity(id), Runes.EPIC, "%s is epic" % id)

func test_only_one_menace_rune() -> void:
	assert_eq(Runes.check_limits(["menace_frost", "", "frost"]), "", "one Menace rune is fine")
	assert_ne(Runes.check_limits(["menace_frost", "menace_frost"]), "", "not two of the same")
	assert_ne(Runes.check_limits(["menace_frost", "menace_fire"]), "", "not two different ones either")
	assert_eq(Runes.max_copies("menace_holy"), 1)

## (Status containers can't run in the editor - non-tool scripts - so only the
## effect data is checked here; stacking to the cap is in Shields.add_aegis.)
func test_frozen_aegis_effect() -> void:
	var fx := Shields.aegis_fx(4.0)
	assert_eq(str(fx.id), Shields.AEGIS_ID)
	assert_eq(float(fx.stat_modifiers.get("armor%", 0.0)), 4.0, "Hardened Frost armor")
	assert_false(Shields.aegis_fx(0.0).stat_modifiers.has("armor%"), "no talent: no armor")

func test_hardened_frost_rime_shell() -> void:
	var plain := Shields.rime_shell_fx(0.0)
	assert_false(plain.stat_modifiers.has("armor%"), "no talent: the normal Rime Shell")
	var hardened := Shields.rime_shell_fx(6.0)
	assert_eq(float(hardened.stat_modifiers.get("armor%", 0.0)), 6.0)
	assert_eq(str(hardened.id), "rime_shell", "same effect id, so Shattering Wave etc. still find it")
