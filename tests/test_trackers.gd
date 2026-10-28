@tool
extends McpTestSuite

# Trackers (scripts/ui/trackers/): player-built aura bars, cooldown icons and
# alerts. Triggers read effects, cooldowns, resources / spec values, events,
# equipped items and states; load rules, conditions and groups; saved and
# shared data is checked; every spec value comes from one generic hook.

func suite_name() -> String:
	return "trackers"

## A stand-in player: a Status child with a list, cooldowns, health, resources.
class FakeStatus extends Node:
	var rows: Array = []
	func list() -> Array:
		return rows

class FakePlayer extends Node:
	var acted := ""
	func tracker_actions() -> Dictionary:
		return {"poke": "Poke"}
	func tracker_action(id: String) -> void:
		acted = id
	var health := 300
	var max_health := 1000
	var cds := {"frostbolt": 4.0}
	var values := {"venom": {"value": 40.0, "max": 100.0}, "flowing": true,
		"held": {"value": 1, "max": 1, "icon": "frostbolt", "name": "Frost Bolt"},
		"pips": {"value": 2, "max": 6, "name": "Mercy", "colors": [Color.RED, Color.BLUE]}}
	func cooldown_left(id: String) -> float:
		return float(cds.get(id, 0.0))
	func cooldown_total(_id: String) -> float:
		return 8.0
	func charges_text(_id: String) -> String:
		return ""
	func resource_points(_r: String) -> int:
		return 3
	func resource_max(_r: String) -> int:
		return 10
	func tracker_values() -> Dictionary:
		return values
	func is_in_combat() -> bool:
		return true

func _player() -> FakePlayer:
	var p: FakePlayer = track(FakePlayer.new())
	var st := FakeStatus.new()
	st.name = "Status"
	st.rows = [{"id": "frostbite", "name": "Frostbite", "stacks": 3, "remaining": 5.0, "debuff": false, "mine": true, "color": Color.CYAN}]
	p.add_child(st)
	return p

func test_effect_trigger() -> void:
	var ctx := {"player": _player()}
	var tr := Trackers.default_trigger("effect")
	tr["id"] = "frostbite"
	var st := Trackers.eval_trigger(tr, ctx)
	assert_true(st["active"])
	assert_eq(int(st["stacks"]), 3)
	assert_eq(float(st["time"]), 5.0)
	tr["stacks"] = 4.0
	assert_false(Trackers.eval_trigger(tr, ctx)["active"], "needs 4 stacks")
	tr["missing"] = true
	assert_true(Trackers.eval_trigger(tr, ctx)["active"], "missing: shows while it isn't there")
	tr = Trackers.default_trigger("effect")
	tr["id"] = "nothing"
	assert_false(Trackers.eval_trigger(tr, ctx)["active"], "an unknown id doesn't crash or show")

func test_cooldown_trigger() -> void:
	var ctx := {"player": _player()}
	var tr := Trackers.default_trigger("cooldown")
	tr["id"] = "frostbolt"
	assert_false(Trackers.eval_trigger(tr, ctx)["active"], "on cooldown: not ready")
	tr["show"] = "cooldown"
	var st := Trackers.eval_trigger(tr, ctx)
	assert_true(st["active"])
	assert_eq(float(st["time"]), 4.0)
	assert_eq(float(st["duration"]), 8.0)

func test_resource_and_spec_value_triggers() -> void:
	var ctx := {"player": _player()}
	var tr := Trackers.default_trigger("resource")   # health <= 35%
	assert_true(Trackers.eval_trigger(tr, ctx)["active"], "30% health")
	tr["res"] = "venom"
	tr["op"] = ">="
	tr["value"] = 50.0
	tr["percent"] = false
	assert_false(Trackers.eval_trigger(tr, ctx)["active"], "40 Venom")
	tr["value"] = 40.0
	var st := Trackers.eval_trigger(tr, ctx)
	assert_true(st["active"])
	assert_eq(float(st["max"]), 100.0)

func test_event_trigger() -> void:
	var tr := Trackers.default_trigger("event")
	tr["event"] = "crit"
	tr["id"] = "frostbolt"
	var key := Trackers.event_key("crit", "frostbolt")
	assert_true(Trackers.eval_trigger(tr, {"events": {key: 10.0}, "now": 11.0})["active"], "1 s after")
	assert_false(Trackers.eval_trigger(tr, {"events": {key: 10.0}, "now": 14.0})["active"], "over after 3 s")
	assert_false(Trackers.eval_trigger(tr, {"events": {"crit": 10.0}, "now": 11.0})["active"], "another ability's crit")

func test_state_trigger_and_combine() -> void:
	var ctx := {"player": _player()}
	var t := Trackers.make_tracker("x", "icon", [Trackers.default_trigger("state"), Trackers.default_trigger("resource")])
	assert_true(Trackers.eval_tracker(t, ctx)["active"])
	t["triggers"][1]["value"] = 10.0   # health <= 10%: off
	t["combine"] = "all"
	assert_false(Trackers.eval_tracker(t, ctx)["active"], "all: every trigger must be on")
	t["combine"] = "any"
	assert_true(Trackers.eval_tracker(t, ctx)["active"])

func test_load_rules() -> void:
	var t := Trackers.make_tracker("x", "icon", [])
	assert_true(Trackers.loaded(t, {}))
	t["load"]["combat"] = "in"
	assert_false(Trackers.loaded(t, {"combat": false}))
	assert_true(Trackers.loaded(t, {"combat": true}))
	t["load"]["role"] = "healer"
	assert_false(Trackers.loaded(t, {"combat": true, "role": "dps"}))
	t["enabled"] = false
	assert_false(Trackers.loaded(t, {"combat": true, "role": "healer"}))

func test_conditions() -> void:
	var t := Trackers.make_tracker("x", "bar", [])
	t["conditions"] = [{"check": "time", "op": "<=", "value": 3.0, "set": "color", "to": Color.RED},
		{"check": "stacks", "op": ">=", "value": 5.0, "set": "glow", "to": true}]
	var mods := Trackers.apply_conditions(t, {"time": 2.0, "stacks": 1})
	assert_eq(mods.get("color"), Color.RED)
	assert_false(mods.has("glow"))

func test_text_tokens() -> void:
	var st := {"name": "Frostbite", "stacks": 3, "time": 5.0, "value": 40.0, "max": 100.0}
	assert_eq(Trackers.format_text("%name %stacks %time %percent%", st), "Frostbite 3 5 40%")

func test_clean_and_export_round_trip() -> void:
	var g := Trackers.make_group("Aura Bars")
	var t := Trackers.make_tracker("Proc", "bar", [Trackers.default_trigger("effect")], g["id"])
	t["display"]["width"] = 99999
	t["triggers"].append({"type": "bogus"})
	var c := Trackers.clean(t)
	assert_eq(int(c["display"]["width"]), 800, "clamped")
	assert_eq(c["triggers"].size(), 1, "an unknown trigger type is dropped")
	var back := Trackers.parse_export(Trackers.export_items([g, t]))
	assert_eq(back.size(), 2)
	assert_ne(back[0]["id"], g["id"], "imports get new ids")
	assert_eq(back[1]["group"], back[0]["id"], "a tracker follows its group to the new id")
	assert_true(Trackers.parse_export("nope").is_empty())

func test_default_groups_and_templates_are_clean() -> void:
	for role in ["tank", "healer", "dps"]:
		for t in Trackers.default_groups(role):
			assert_false(Trackers.clean(t).is_empty(), "%s default: %s" % [role, t["name"]])
	for tpl in Trackers.templates():
		var t: Dictionary = (tpl[2] as Callable).call()
		assert_eq(Trackers.clean(t)["display"]["type"], t["display"]["type"], "template %s" % tpl[0])

func test_spec_values_carry_icon_name_and_colors() -> void:
	var ctx := {"player": _player()}
	var st := Trackers.eval_trigger(_res("held", 1.0), ctx)
	assert_true(st["active"])
	assert_eq(str(st["icon"]), "frostbolt", "a spec value can give the icon (the held weapon)")
	assert_eq(str(st["name"]), "Frost Bolt")
	st = Trackers.eval_trigger(_res("pips", 0.0), ctx)
	assert_eq((st["colors"] as Array).size(), 2, "and a colour per pip")
	assert_true(Trackers.eval_trigger(_res("flowing", 1.0), ctx)["active"], "a true / false value is 1 / 0")
	# A precomputed values dictionary (the engine's, once a sweep) wins over asking the player.
	assert_false(Trackers.eval_trigger(_res("flowing", 1.0), {"player": _player(), "values": {}})["active"])

func _res(res: String, at: float) -> Dictionary:
	var tr := Trackers.default_trigger("resource")
	tr["res"] = res
	tr["op"] = ">="
	tr["value"] = at
	tr["percent"] = false
	return tr

func test_texts_read_any_trigger() -> void:
	var ctx := {"player": _player()}
	var t := Trackers.make_tracker("x", "icon", [_res("venom", 0.0), _res("pips", 0.0)])
	var st := Trackers.eval_tracker(t, ctx)
	assert_eq(Trackers.format_text("%value / %2.value of %2.max (%2.name)", st), "40 / 2 of 6 (Mercy)")
	assert_eq(Trackers.num_text(1.5), "1.5", "small numbers keep a decimal")
	assert_eq(Trackers.num_text(40.7), "40")

func test_conditions_on_another_trigger() -> void:
	var ctx := {"player": _player()}
	var t := Trackers.make_tracker("x", "bar", [_res("venom", 0.0), _res("flowing", 1.0)])
	t["conditions"] = [{"trigger": 2, "check": "active", "op": ">=", "value": 1.0, "set": "text2_color", "to": Color.GREEN},
		{"trigger": 1, "check": "value", "op": ">", "value": 50.0, "set": "text", "to": "full"}]
	var mods := Trackers.apply_conditions(t, Trackers.eval_tracker(t, ctx))
	assert_eq(mods.get("text2_color"), Color.GREEN, "trigger 2 is on")
	assert_false(mods.has("text"), "40 Venom isn't past 50")
	assert_eq(int(Trackers.clean(t)["conditions"][0]["trigger"]), 2, "the trigger number is kept")

func test_load_by_abilities_on_bars() -> void:
	var t := Trackers.make_tracker("x", "icon", [])
	t["load"]["bars"] = "adderarrow, asparrow"
	assert_false(Trackers.loaded(t, {"bars": ["adderarrow"]}), "all: both needed")
	assert_true(Trackers.loaded(t, {"bars": ["asparrow", "adderarrow", "x"]}))
	t["load"]["bars_mode"] = "any"
	assert_true(Trackers.loaded(t, {"bars": ["adderarrow"]}))
	assert_false(Trackers.loaded(t, {"bars": []}))

func test_new_display_fields_survive_clean() -> void:
	var t := Trackers.make_tracker("x", "pips", [])
	t["display"]["text2"] = "%name"
	t["display"]["text2_color"] = Color.RED
	t["display"]["show_missing"] = true
	t["display"]["click"] = "poke"
	var c := Trackers.clean(t)
	assert_eq(str(c["display"]["type"]), "pips")
	assert_eq(str(c["display"]["text2"]), "%name")
	assert_eq(c["display"]["text2_color"], Color.RED)
	assert_true(bool(c["display"]["show_missing"]))
	assert_eq(str(c["display"]["click"]), "poke")
	var g := Trackers.make_group("g")
	g["align"] = "center"
	assert_eq(str(Trackers.clean(g)["align"]), "center")
	# An old save without the new fields gets their defaults.
	var old := {"id": "t_old", "kind": "tracker", "name": "Old", "display": {"type": "icon"}, "load": {"spec": ""}}
	var co := Trackers.clean(old)
	assert_eq(str(co["display"]["text2"]), "")
	assert_eq(str(co["load"]["bars_mode"]), "all")

func test_spec_sets_are_plain_trackers() -> void:
	# The spec displays are ordinary trackers: clean as-is, export and import, unique ids.
	var ids := {}
	for sp in Trackers.spec_sets():
		var items: Array = sp[3]
		assert_false(items.is_empty(), sp[1])
		for it in items:
			assert_false(ids.has(it["id"]), "unique id %s" % it["id"])
			ids[it["id"]] = true
			var c := Trackers.clean(it)
			assert_eq(var_to_str(c), var_to_str(it), "%s / %s is clean as it is" % [sp[1], it["name"]])
			if str(it["kind"]) == "tracker":
				assert_true(str(it["load"]["bars"]) != "", "%s loads only with its abilities on the bars" % it["name"])
				for f in ["text", "text2"]:
					assert_false(str(it["display"][f]).contains("%%%d." % ((it["triggers"] as Array).size() + 1)), "no text reads a missing trigger")
		assert_eq(Trackers.parse_export(Trackers.export_items(items)).size(), items.size(), "%s exports whole" % sp[1])
		assert_true(UIConfig.preset_spot("tracker:" + str(sp[0])).size() > 0, "%s has a spot" % sp[1])
	# Every spec value they read is one a component gives.
	var player_src := PlayerSource.text()
	for k in ["\"venom_flow\"", "\"wheel_%d\"", "\"chain_%d\"", "\"overcut_\"", "\"cut_\"", "\"colors\"", "\"ice_shards_recharge\"",
			"\"bruise\"", "\"glaze\"", "\"ice_layers\"", "\"sap\"", "\"incense\"", "\"reflections\"", "\"traces\"", "\"heat\"",
			"\"slag\"", "\"flow\""]:
		assert_contains(player_src, k)

func test_builtins_are_given_once() -> void:
	var s := FakeSettings.new()
	track(s)
	assert_true(Trackers.give_builtins(s))
	for sp in Trackers.spec_sets():
		assert_true(s.trackers.has(sp[0]), "%s is in the list like any tracker" % sp[1])
	assert_false(s.trackers.has("aura_bars"), "the role's groups wait for the UI setup")
	s.trackers.erase("spec_venom")
	s.ui_installed = true
	assert_true(Trackers.give_builtins(s))
	assert_true(s.trackers.has("aura_bars"), "after the setup: the role's groups")
	assert_false(s.trackers.has("spec_venom"), "a deleted spec set stays deleted")
	assert_false(Trackers.give_builtins(s), "nothing new the next time")

class FakeSettings extends Node:
	var trackers := {}
	var tracker_builtins: Array = []
	var ui_installed := false
	var saves := 0
	func save() -> void:
		saves += 1

func test_spec_values_come_from_components() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "func tracker_values() -> Dictionary:")
	assert_contains(src, "out.merge(c.tracker_values(), true)")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player/player_kit.gd"), "func tracker_values() -> Dictionary:")
	assert_contains(src, "func tracker_actions() -> Dictionary:")
	assert_contains(src, "out.merge(c.tracker_actions(), true)")
	assert_contains(src, "if c is PlayerKit and c.tracker_action(id):")

func test_ids_show_in_tooltips() -> void:
	var tip := FileAccess.get_file_as_string("res://scripts/ui/item_tooltip.gd")
	assert_contains(tip, "Abilities.tooltip_bbcode(id, detailed) + id_line(id)")
	assert_contains(tip, "id_line(Items.base_id(item))")
	assert_contains(FileAccess.get_file_as_string("res://scripts/ui/status_icons.gd"), "\"\\nID: %s\" % e[\"id\"]")
	assert_true(Trackers.all_ids().size() > 50, "the ID picker lists abilities, items and effects")
