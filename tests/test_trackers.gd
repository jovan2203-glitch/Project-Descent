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
	var health := 300
	var max_health := 1000
	var cds := {"frostbolt": 4.0}
	var values := {"venom": {"value": 40.0, "max": 100.0}}
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

func test_spec_values_come_from_components() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "func tracker_values() -> Dictionary:")
	assert_contains(src, "out.merge(c.tracker_values(), true)")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player/player_kit.gd"), "func tracker_values() -> Dictionary:")

func test_ids_show_in_tooltips() -> void:
	var tip := FileAccess.get_file_as_string("res://scripts/ui/item_tooltip.gd")
	assert_contains(tip, "Abilities.tooltip_bbcode(id, detailed) + id_line(id)")
	assert_contains(tip, "id_line(Items.base_id(item))")
	assert_contains(FileAccess.get_file_as_string("res://scripts/ui/status_icons.gd"), "\"\\nID: %s\" % e[\"id\"]")
	assert_true(Trackers.all_ids().size() > 50, "the ID picker lists abilities, items and effects")
