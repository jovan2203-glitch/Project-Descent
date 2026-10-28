@tool
extends McpTestSuite

# The in-game UI's options and role layouts (scripts/ui/ui_config.gd): every
# option has a sane default, every role layout puts the core pieces on screen
# without covering each other, and a profile survives export / import.

func suite_name() -> String:
	return "ui_config"

func test_every_option_has_a_valid_default() -> void:
	var schema := UIConfig.schema()
	assert_true(schema.has("general") and schema.has("player_frame") and schema.has("action_bar_4"))
	for elem in schema:
		for o in schema[elem]["options"]:
			var d: Variant = o["default"]
			assert_eq(UIConfig.coerce(o, d), d, "%s.%s: its default is in range" % [elem, o["id"]])
			if o["type"] == "int" or o["type"] == "float":
				assert_true(float(o["min"]) <= float(d) and float(d) <= float(o["max"]), "%s.%s in its range" % [elem, o["id"]])
			if o["type"] == "enum":
				assert_eq((o["values"] as Array).size(), (o["names"] as Array).size(), "%s.%s: a name per value" % [elem, o["id"]])

func test_role_overrides_are_real_options() -> void:
	for role in UIConfig.PRESETS:
		for elem in UIConfig.PRESETS[role]["overrides"]:
			for opt in UIConfig.PRESETS[role]["overrides"][elem]:
				var o := UIConfig.option(elem, opt)
				assert_false(o.is_empty(), "%s: %s.%s exists" % [role, elem, opt])
				var v: Variant = UIConfig.PRESETS[role]["overrides"][elem][opt]
				assert_eq(UIConfig.coerce(o, v), v, "%s: %s.%s in range" % [role, elem, opt])
	assert_eq(UIConfig.default_of("party_frames", "grow", "healer"), "right", "healers get a row of party frames")
	assert_eq(UIConfig.default_of("party_frames", "grow", "tank"), "down")

## Roughly how big an element is with a role's values (what Move UI places).
func _size(key: String, role: String) -> Vector2:
	var v := func(elem: String, opt: String) -> float: return float(UIConfig.default_of(elem, opt, role))
	match key:
		"action_bar", "extra_bar_1", "extra_bar_2", "extra_bar_3":
			var elem := "action_bar_1" if key == "action_bar" else "action_bar_%d" % (int(key.right(1)) + 1)
			var n: float = v.call(elem, "buttons")
			var per: float = minf(v.call(elem, "per_row"), n)
			var rows := ceilf(n / per)
			var s: float = v.call(elem, "size")
			var g: float = v.call(elem, "spacing")
			return Vector2(4 + per * s + (per - 1) * g, 4 + rows * s + (rows - 1) * g)
		"player_frame":
			return Vector2(v.call(key, "width"), v.call(key, "health_height") + v.call(key, "power_height") + 4)
		"target_frame":
			return Vector2(v.call(key, "width"), v.call(key, "health_height") + v.call(key, "power_height") + v.call(key, "cast_height") + 5)
		"cast_bar", "xp_bar":
			return Vector2(v.call(key, "width"), v.call(key, "height") + 2)
		"chat":
			return Vector2(v.call("chat_panel", "width"), v.call("chat_panel", "height") + 22)
		"meter":
			return Vector2(v.call("meter_panel", "width"), maxf(v.call("meter_panel", "height"), 206.0) + 22)
		"minimap":
			return Vector2(v.call(key, "size"), v.call(key, "size"))
		"party_frames":
			var w: float = v.call(key, "width")
			var h: float = v.call(key, "height")
			var g: float = v.call(key, "spacing")
			if str(UIConfig.default_of(key, "grow", role)) == "right":
				return Vector2(5 * (w + g) - g, h)
			return Vector2(w, 5 * (h + g) - g)
		"buffs", "debuffs":
			var s: float = v.call(key, "size")
			return Vector2(v.call(key, "per_row") * (s + 3), 2 * (s + 14))
	return Vector2.ZERO

func test_every_role_layout_fits_without_overlaps() -> void:
	var core := ["action_bar", "extra_bar_1", "extra_bar_2", "xp_bar", "player_frame", "target_frame", "cast_bar",
		"chat", "meter", "minimap", "party_frames", "buffs", "debuffs"]
	for role in UIConfig.ROLES:
		for screen in [Vector2(1152, 648), Vector2(2560, 1440)]:
			var rects := {}
			for key in core:
				if key.begins_with("extra_bar_") and not bool(UIConfig.default_of("action_bar_%d" % (int(key.right(1)) + 1), "enabled", role)):
					continue
				var spot := UIConfig.preset_spot(key, role)
				assert_false(spot.is_empty(), "%s places %s" % [role, key])
				var sz := _size(key, role)
				var a := Vector2(float(spot["ax"]), float(spot["ay"]))
				var pos: Vector2 = a * screen - a * sz + Vector2(float(spot["x"]), float(spot["y"]))
				var r := Rect2(pos, sz)
				assert_true(Rect2(Vector2.ZERO, screen).encloses(r), "%s at %s: %s on screen (%s)" % [role, screen, key, r])
				rects[key] = r
			for k1 in rects:
				for k2 in rects:
					if str(k1) < str(k2):
						assert_false((rects[k1] as Rect2).intersects(rects[k2]), "%s at %s: %s and %s don't overlap" % [role, screen, k1, k2])

func test_clean_profile_keeps_only_known_values() -> void:
	var p := UIConfig.clean_profile({"player_frame": {"width": 99999, "bogus": 1, "text": "percent"},
		"nope": {"width": 1}, "general": {"accent": "red"}})
	assert_eq(int(p["player_frame"]["width"]), int(UIConfig.option("player_frame", "width")["max"]), "clamped")
	assert_false(p["player_frame"].has("bogus"))
	assert_eq(p["player_frame"]["text"], "percent")
	assert_false(p.has("nope"))
	assert_eq(p["general"]["accent"], UIConfig.option("general", "accent")["default"], "a colour must be a colour")

func test_export_import_round_trip() -> void:
	var data := {"role": "healer", "profile": {"cast_bar": {"width": 300}}, "layout": {"cast_bar": {"ax": 0.5, "ay": 1.0, "x": 10.0, "y": -40.0}}}
	var line := UIConfig.EXPORT_PREFIX + Marshalls.utf8_to_base64(var_to_str(data))
	var back := UIConfig.parse_export(line)
	assert_eq(back["role"], "healer")
	assert_eq(int(back["profile"]["cast_bar"]["width"]), 300)
	assert_eq(float(back["layout"]["cast_bar"]["x"]), 10.0)
	assert_true(UIConfig.parse_export("hello").is_empty(), "not an export")
	assert_true(UIConfig.parse_export(UIConfig.EXPORT_PREFIX + "!!!").is_empty(), "garbage")

func test_texts() -> void:
	assert_eq(UISkin.value_text("value", 1200, 2000), "1200 / 2000")
	assert_eq(UISkin.value_text("percent", 1200, 2000), "60%")
	assert_eq(UISkin.value_text("deficit", 1200, 2000), "-800")
	assert_eq(UISkin.value_text("deficit", 2000, 2000), "")
	assert_eq(UISkin.short(12345), "12.3k")
	assert_eq(UISkin.time_text(75.0), "2m")
	assert_eq(UISkin.time_text(1.24), "1.2")

func test_setup_and_profile_are_saved() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/settings.gd")
	assert_contains(src, "cfg.set_value(\"ui\", \"installed\", ui_installed)")
	assert_contains(src, "cfg.set_value(\"ui_profile\", elem, ui_profile[elem])")
	assert_contains(src, "cfg.set_value(\"trackers\", id, trackers[id])")
	assert_contains(FileAccess.get_file_as_string("res://scripts/game_ui.gd"), "UIInstaller.open_if_new")

func test_every_hud_element_has_options() -> void:
	var hud := HudSource.text()
	var re := RegEx.create_from_string("(?m)^\\tkey = \"([a-z_0-9]+)\"")
	for m in re.search_all(hud):
		assert_true(UIConfig.schema().has(m.get_string(1)), "%s has a UI Options page" % m.get_string(1))

func test_hud_and_windows_build() -> void:
	# Smoke test: the HUD with every element (no player), UI Options on every page,
	# the setup on every step and the Trackers editor build without errors.
	var tree := Engine.get_main_loop() as SceneTree
	if tree.root.get_node_or_null("Settings") == null:
		return   # (no autoloads in this run)
	var host: Node = tree.current_scene
	var hud: CanvasLayer = load("res://scripts/hud.gd").new()
	host.add_child(hud)
	assert_true(hud.element("player_frame") != null and hud.element("action_bar_4") != null and hud.element("debuffs") != null)
	for e in hud.elements():
		e.apply_config()
		e.slow_update()
		assert_true(e.size.x > 0.0 or not e.enabled(), "%s has a size" % e.key)
	var opts := UIOptions.new()
	opts.win = _window(host)
	opts.win.add_child(opts)
	opts._build()
	for elem in UIConfig.schema():
		opts.show_page(elem)
	var inst := UIInstaller.new()
	inst.win = _window(host)
	inst.win.add_child(inst)
	inst._build()
	for i in UIInstaller.STEPS.size():
		inst._show(i)
	var ed := TrackerEditor.new()
	ed.win = _window(host)
	ed.win.add_child(ed)
	ed._build()
	for w in [opts.win, inst.win, ed.win]:
		w.free()
	hud.free()

func _window(host: Node) -> UIWindow:
	var w := UIWindow.new()
	w._build("Test", Vector2(800, 500))
	host.add_child(w)
	return w
