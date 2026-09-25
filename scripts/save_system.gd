extends Node

# Persistent profile storage (autoload "SaveSystem").
# Writes the player's profile to user://profile.cfg (ConfigFile).
#   - Loads once at startup (after PlayerData / GameManager exist).
#   - Autosaves ~0.5 s after any PlayerData change (debounced).
#   - Saves when returning to the menu and when the game window closes.
# Display options are saved separately by Settings (user://settings.cfg).
#
# Safety:
#   - Versioned: every save stores meta/version. Older saves are upgraded step by
#     step by _migrate() (v1 -> v2 -> ...), so adding features never wipes profiles.
#   - Atomic write: save to profile.cfg.tmp, verify it reads back, keep the old
#     file as profile.cfg.bak, then swap the tmp file in. A crash mid-save can
#     never leave a half-written profile.
#   - Fallback load: if profile.cfg is missing/corrupt, profile.cfg.bak is used.
#   - Validation: unknown items, runes, runes, abilities and talents (e.g. ones
#     removed from the game) are dropped instead of breaking the UI.

const PATH := "user://profile.cfg"
const TMP_PATH := "user://profile.cfg.tmp"
const BAK_PATH := "user://profile.cfg.bak"
const VERSION := 4
const AUTOSAVE_DELAY := 0.5

const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Runes = preload("res://scripts/runes.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")

var _dirty := false
var _timer := 0.0
var _loading := false
var last_load_source := ""   # "main", "backup" or "" (fresh profile)

func _ready() -> void:
	# Autoloads are added in order; wait a frame so PlayerData/GameManager are ready.
	await get_tree().process_frame
	load_profile()
	_pd().changed.connect(_mark_dirty)
	get_node("/root/SignalBus").game_state_changed.connect(func(_s): save_profile())
	get_tree().auto_accept_quit = false   # let us save before quitting

func _pd() -> Node:
	return get_node("/root/PlayerData")

func _gm() -> Node:
	return get_node("/root/GameManager")

func _mark_dirty() -> void:
	if _loading:
		return
	_dirty = true
	_timer = AUTOSAVE_DELAY

func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer -= delta
	if _timer <= 0.0:
		save_profile()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile()
		get_tree().quit()

# --- Save ------------------------------------------------------------------------

func _build_config() -> ConfigFile:
	var pd := _pd()
	var gm := _gm()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "saved_at", Time.get_datetime_string_from_system())

	cfg.set_value("items", "inventory", Array(pd.inventory))
	cfg.set_value("items", "equipment", pd.equipment)
	cfg.set_value("items", "bank", Array(pd.bank))
	# Item instance records, only for items that still exist.
	cfg.set_value("items", "instances", ItemDB.serialize(pd.all_item_ids()))

	cfg.set_value("progress", "level", pd.level)
	cfg.set_value("progress", "xp", pd.xp)
	cfg.set_value("progress", "learned_abilities", Array(pd.learned_abilities))
	cfg.set_value("progress", "equipped_cards", Array(pd.equipped_cards))
	cfg.set_value("progress", "owned_cards", Array(pd.owned_cards))
	cfg.set_value("progress", "level_lock", pd.level_lock)
	cfg.set_value("progress", "draft_boons", pd.draft_boons)
	cfg.set_value("progress", "pending_drafts", Array(pd.pending_drafts))
	cfg.set_value("progress", "card_reoffer", pd.card_reoffer)

	cfg.set_value("abilities", "action_bar", Array(pd.action_bar))

	cfg.set_value("runes", "known", Array(pd.known_runes))
	cfg.set_value("talents", "ranks", pd.talents)
	cfg.set_value("progress", "attribute_points", pd.attribute_points)
	cfg.set_value("progress", "checkpoints", pd.checkpoints)

	cfg.set_value("stats", "kills", gm.kills)
	cfg.set_value("stats", "deaths", gm.deaths)
	cfg.set_value("stats", "play_time", gm.play_time)
	return cfg

func save_profile() -> Error:
	var cfg := _build_config()
	# 1. Write the temp file.
	var err := cfg.save(TMP_PATH)
	if err != OK:
		_log(2, "could not write temp save (%s)" % error_string(err))
		return err
	# 2. Verify it reads back before trusting it.
	var check := ConfigFile.new()
	if check.load(TMP_PATH) != OK or int(check.get_value("meta", "version", -1)) != VERSION:
		_log(2, "temp save failed verification; keeping previous profile")
		return ERR_FILE_CORRUPT
	# 3. Keep the current profile as a backup.
	var main_abs := ProjectSettings.globalize_path(PATH)
	var tmp_abs := ProjectSettings.globalize_path(TMP_PATH)
	var bak_abs := ProjectSettings.globalize_path(BAK_PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(main_abs, bak_abs)
	# 4. Swap the temp file in.
	err = DirAccess.rename_absolute(tmp_abs, main_abs)
	if err != OK and FileAccess.file_exists(PATH):
		# Some platforms won't rename over an existing file: remove, then retry.
		DirAccess.remove_absolute(main_abs)
		err = DirAccess.rename_absolute(tmp_abs, main_abs)
	if err != OK:
		_log(3, "could not replace profile (%s)" % error_string(err))
		return err
	_dirty = false
	return OK

# --- Load ------------------------------------------------------------------------

func load_profile() -> bool:
	var cfg := ConfigFile.new()
	last_load_source = ""
	if FileAccess.file_exists(PATH) and cfg.load(PATH) == OK:
		last_load_source = "main"
	else:
		cfg = ConfigFile.new()
		if FileAccess.file_exists(BAK_PATH) and cfg.load(BAK_PATH) == OK:
			last_load_source = "backup"
			if FileAccess.file_exists(PATH):
				_log(2, "profile was unreadable, restored from backup")
		else:
			return false   # first run (or nothing readable): keep defaults

	var version := int(cfg.get_value("meta", "version", 1))
	ItemDB.load_records(cfg.get_value("items", "instances", {}))
	if version > VERSION:
		_log(2, "profile is from a newer version (%d > %d); loading what we can" % [version, VERSION])
	elif version < VERSION:
		_migrate(cfg, version)

	var pd := _pd()
	var gm := _gm()
	_loading = true

	_load_items(pd.inventory, cfg.get_value("items", "inventory", []), pd.INVENTORY_SIZE)
	_load_items(pd.bank, cfg.get_value("items", "bank", []), pd.BANK_SIZE)
	pd.equipment = _valid_equipment(cfg.get_value("items", "equipment", {}))

	_load_abilities(pd.action_bar, cfg.get_value("abilities", "action_bar", []), pd.ACTION_SLOTS)

	var known: Variant = cfg.get_value("runes", "known", Array(pd.known_runes))
	var runes: Array = []
	if known is Array:
		for r in known:
			if Runes.get_resource(str(r)) != null and not runes.has(str(r)):
				runes.append(str(r))
	pd.known_runes.assign(runes)

	pd.level = clampi(int(cfg.get_value("progress", "level", 1)), 1, pd.MAX_LEVEL)
	pd.xp = clampi(int(cfg.get_value("progress", "xp", 0)), 0, maxi(pd.xp_to_next(pd.level) - 1, 0))
	var learned: Array[String] = []
	var saved_learned: Variant = cfg.get_value("progress", "learned_abilities", [])
	if saved_learned is Array:
		for a in saved_learned:
			if Abilities.DRAFT_POOL.has(str(a)) and not learned.has(str(a)):
				learned.append(str(a))
	pd.learned_abilities = learned
	var owned: Array[String] = []
	var saved_owned: Variant = cfg.get_value("progress", "owned_cards", [])
	if saved_owned is Array:
		for c in saved_owned:
			if SkillCards.exists(str(c)) and not owned.has(str(c)):
				owned.append(str(c))
	pd.owned_cards = owned
	var lock := int(cfg.get_value("progress", "level_lock", 0))
	pd.level_lock = lock if lock > 0 and lock % pd.LEVEL_LOCK_STEP == 0 and lock <= pd.MAX_LEVEL else 0
	var cards: Array[String] = []
	var saved_cards: Variant = cfg.get_value("progress", "equipped_cards", [])
	if saved_cards is Array:
		for c in saved_cards:
			if owned.has(str(c)) and not cards.has(str(c)) and cards.size() < SkillCards.MAX_EQUIPPED:
				cards.append(str(c))
	pd.equipped_cards = cards
	var boons: Variant = cfg.get_value("progress", "draft_boons", {})
	pd.draft_boons = {}
	if boons is Dictionary:
		for s in boons:
			if Items.STAT_LABELS.has(str(s)):
				pd.draft_boons[str(s)] = float(boons[s])
	var pending: Array[int] = []
	var saved_pending: Variant = cfg.get_value("progress", "pending_drafts", [])
	if saved_pending is Array:
		for lv in saved_pending:
			# Odd levels are Skill Card re-offers (a skipped guaranteed card).
			if int(lv) >= 2 and int(lv) <= pd.level and not pending.has(int(lv)):
				pending.append(int(lv))
	pd.pending_drafts = pending
	pd.card_reoffer = bool(cfg.get_value("progress", "card_reoffer", false))

	pd.talents = _valid_talents(cfg.get_value("talents", "ranks", {}))
	if not pd.validate_talents():
		_log(1, "Talent points exceeded level %d budget: talents were refunded" % pd.level)
	pd.attribute_points = {}
	var attrs: Variant = cfg.get_value("progress", "attribute_points", {})
	if attrs is Dictionary:
		for s in attrs:
			if pd.ATTRIBUTE_VALUES.has(str(s)) and int(attrs[s]) > 0:
				pd.attribute_points[str(s)] = int(attrs[s])
	pd.checkpoints = {}
	var cps: Variant = cfg.get_value("progress", "checkpoints", {})
	if cps is Dictionary:
		for path in cps:
			if pd.is_checkpoint_floor(int(cps[path])):
				pd.checkpoints[str(path)] = int(cps[path])
	if not pd.validate_attributes():
		_log(1, "Attribute points exceeded level %d budget: they were refunded" % pd.level)

	gm.kills = maxi(int(cfg.get_value("stats", "kills", 0)), 0)
	gm.deaths = maxi(int(cfg.get_value("stats", "deaths", 0)), 0)
	gm.play_time = maxf(float(cfg.get_value("stats", "play_time", 0.0)), 0.0)

	pd.changed.emit()
	_loading = false
	_dirty = false
	if version != VERSION or last_load_source == "backup":
		save_profile.call_deferred()   # write the upgraded / recovered profile back
	return true

# --- Migrations ------------------------------------------------------------------
# Each step upgrades a save by exactly one version. Never edit an old step once
# shipped; add a new one and bump VERSION.

func _migrate(cfg: ConfigFile, from_version: int) -> void:
	var v := from_version
	while v < VERSION:
		match v:
			1:
				_migrate_1_to_2(cfg)
			2:
				_migrate_2_to_3(cfg)
			3:
				_migrate_3_to_4(cfg)
		v += 1
		cfg.set_value("meta", "version", v)

# v1 -> v2: runes used to be stored per gear slot ("runes/on_gear"); they now live
# on the item itself as "item|rune".
func _migrate_1_to_2(cfg: ConfigFile) -> void:
	var legacy: Variant = cfg.get_value("runes", "on_gear", {})
	var equipment: Variant = cfg.get_value("items", "equipment", {})
	if legacy is Dictionary and equipment is Dictionary:
		for slot in legacy:
			var it: String = str(equipment.get(str(slot), ""))
			if it != "" and Items.rune_of(it) == "":
				equipment[str(slot)] = Items.with_rune(it, str(legacy[slot]))
		cfg.set_value("items", "equipment", equipment)
	if cfg.has_section_key("runes", "on_gear"):
		cfg.erase_section_key("runes", "on_gear")

# v2 -> v3: items become instances with their own records ("sword|frost" ->
# "#<id>" + record), and levels exist. Talent points now come from level, so the
# old flat 10 points are kept by starting at the level that covers what was spent.
func _migrate_2_to_3(cfg: ConfigFile) -> void:
	for key in ["inventory", "bank"]:
		var arr: Variant = cfg.get_value("items", key, [])
		if arr is Array:
			for i in arr.size():
				if arr[i] != null and str(arr[i]) != "":
					arr[i] = ItemDB.from_legacy(str(arr[i]))
			cfg.set_value("items", key, arr)
	var eq: Variant = cfg.get_value("items", "equipment", {})
	if eq is Dictionary:
		for slot in eq:
			eq[slot] = ItemDB.from_legacy(str(eq[slot]))
		cfg.set_value("items", "equipment", eq)
	var spent := 0
	var ranks: Variant = cfg.get_value("talents", "ranks", {})
	if ranks is Dictionary:
		for id in ranks:
			spent += maxi(int(ranks[id]), 0)
	var lv := 1
	while Talents.points_for_level(lv) < spent and lv < 20:
		lv += 1
	cfg.set_value("progress", "level", lv)
	cfg.set_value("progress", "xp", 0)
	_log(1, "Migrated profile to v3 (item instances); starting level %d" % lv)

# v3 -> v4: roguelike. Skill Cards must now be found (chests); the cards that
# were equipped become the starting collection. No level lock.
func _migrate_3_to_4(cfg: ConfigFile) -> void:
	cfg.set_value("progress", "owned_cards", cfg.get_value("progress", "equipped_cards", []))
	cfg.set_value("progress", "level_lock", 0)
	_log(1, "Migrated profile to v4 (Skill Card collection)")

# --- Validation --------------------------------------------------------------------

# Slot value -> valid item instance id (or "").
#   - instance ids must have a record with a known base item
#   - old "base|rune" strings (v2 saves) become new instances
#   - unknown runes are stripped
func _clean_item(v: Variant) -> String:
	if v == null:
		return ""
	var s := str(v)
	if s == "":
		return ""
	if not ItemDB.is_instance_id(s):
		if not Items.exists(s):
			return ""
		s = ItemDB.from_legacy(s)
	if not Items.exists(s):
		ItemDB.destroy(s)
		return ""
	var rec := ItemDB.get_record(s)
	rec["runes"] = Array(rec.get("runes", [])).filter(func(e): return Runes.get_resource(str(e)) != null)
	return s

func _log(level: int, text: String) -> void:
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.log_line(level, "save", text)
	elif level >= 2:
		push_warning("SaveSystem: " + text)

func _load_items(target: Array[String], saved: Variant, size: int) -> void:
	var src: Array = saved if saved is Array else []
	for i in size:
		target[i] = _clean_item(src[i]) if i < src.size() else ""

func _load_abilities(target: Array[String], saved: Variant, size: int) -> void:
	var src: Array = saved if saved is Array else []
	for i in size:
		var id := str(src[i]) if i < src.size() and src[i] != null else ""
		target[i] = id if id != "" and Abilities.get_resource(id) != null else ""

func _valid_equipment(saved: Variant) -> Dictionary:
	var out := {}
	if saved is Dictionary:
		for slot in saved:
			var it := _clean_item(saved[slot])
			if it != "":
				out[str(slot)] = it
	return out

func _valid_talents(saved: Variant) -> Dictionary:
	var out := {}
	if saved is Dictionary:
		for id in saved:
			var t := Talents.get_talent(str(id))
			if t.is_empty():
				continue
			var rank := clampi(int(saved[id]), 0, int(t.get("max_rank", 1)))
			if rank > 0:
				out[str(id)] = rank
	return out

func delete_profile() -> void:
	for p in [PATH, TMP_PATH, BAK_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
