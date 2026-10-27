extends Control

## Project: Descent launcher — a small, separate Godot project. Open the
## "launcher" folder as its own project in Godot; the game project skips this
## folder because of its .gdignore file.
##
## Skyrim-style: pick display / graphics options before the game starts, and it
## keeps the game up to date from GitHub Releases.
##
## Install layout (what players / testers get):
##     ProjectDescentLauncher.exe
##     game/                    <- downloaded and replaced by the launcher
##         ProjectDescent.exe
##         ProjectDescent.pck
##         version.txt          <- release tag of the installed build
##
## Publishing a new build: tools/release.sh X.Y.Z in the game project. GitHub
## Actions attaches the zip, every build file on its own and manifest.json
## (name, size, SHA-256 of each file). Every launcher sees the new tag on its
## next start and offers UPDATE.
##
## Updates: a fresh install downloads the zip. An installed game is patched
## (patcher.gd): only build files whose SHA-256 changed are downloaded, and the
## .pck is rebuilt from the installed one plus just the files inside it that
## changed. If patching fails for any reason, the full zip is used instead.
##
## Options are written straight into the game's own settings file
## (%APPDATA%/ProjectDescent/settings.cfg), so they are the same
## values the in-game Settings menu shows. Other sections (keybinds, audio,
## interface) are left untouched.

# --- Configuration --------------------------------------------------------------------

const REPO := "jovan2203-glitch/Project-Descent"
const GAME_DIR_NAME := "game"
const GAME_EXE := "ProjectDescent.exe"          # any other .exe in game/ is used as a fallback
const ASSET_SUFFIX := "-windows.zip"           # preferred release asset; else the first .zip
const VERSION_FILE := "version.txt"
const MANIFEST := "manifest.json"
const PATCH_DIR := ".patch"                    # inside game/; staging for patch updates
## Must match the game's application/config/custom_user_dir_name — the game
## saves to %APPDATA%/<this>/ (its user:// folder).
const GAME_USER_DIR := "ProjectDescent"
const USER_AGENT := "User-Agent: ProjectDescentLauncher"

# Mirrors scripts/settings.gd in the game — keep the order the same (indices are saved).
const WINDOW_MODES := ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"]
const RESOLUTIONS := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_OPTIONS := [30, 60, 120, 144, 0]   # 0 = unlimited
const QUALITY_LEVELS := ["Low", "Medium", "High"]
const RENDER_SCALES := [0.5, 0.67, 0.77, 0.85, 1.0]

# --- Look -----------------------------------------------------------------------------

const ACCENT := Color("7fc8ff")
const TEXT := Color("e6edf3")
const DIM := Color("8b949e")
const ERROR_COLOR := Color("ff8a7a")

enum State { CHECKING, INSTALL, UPDATE, PLAY, BUSY, RETRY }

var _state := State.CHECKING
var _install_dir := ""
var _game_dir := ""
var _local_version := ""
var _latest := {}          # tag, title, notes, url, size
var _http: HTTPRequest
var _dl_http: HTTPRequest
var _thread: Thread
var _fallback_state := State.INSTALL   # where to go back to if an update fails
var _patch := {}           # patch plan for the latest release; empty = use the zip
var _dl_base := 0          # bytes already downloaded by earlier requests of this update
var _dl_total := 0         # bytes this update downloads (0 = take it from the request)

# Settings (same meaning as the game's Settings autoload).
var _cfg := ConfigFile.new()
var window_mode := 0
var resolution := 0
var vsync := true
var max_fps := 1
var quality := 1
var render_scale := 4
var _graphics_touched := false   # don't override the game's first-run auto-detect

# UI
var _main_btn: Button
var _options_btn: Button
var _panel_title: Label
var _notes: RichTextLabel
var _options: Control
var _status: Label
var _version_lbl: Label
var _progress: ProgressBar


func _ready() -> void:
	get_window().title = "Project: Descent"
	_install_dir = _resolve_install_dir()
	_game_dir = _install_dir.path_join(GAME_DIR_NAME)
	_local_version = _read_local_version()
	_load_settings()
	_build_ui()
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_release_info)
	_check_for_updates()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _resolve_install_dir() -> String:
	if OS.has_feature("editor"):
		# Running from the editor: use a throwaway install folder next to the project.
		var dir := ProjectSettings.globalize_path("res://").path_join("_test_install")
		DirAccess.make_dir_recursive_absolute(dir)
		if not FileAccess.file_exists(dir.path_join(".gdignore")):
			FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)
		return dir
	return OS.get_executable_path().get_base_dir()


func _find_game_exe() -> String:
	var p := _game_dir.path_join(GAME_EXE)
	if FileAccess.file_exists(p):
		return p
	var d := DirAccess.open(_game_dir)
	if d:
		for f in d.get_files():
			if f.get_extension().to_lower() == "exe" and not f.to_lower().contains("console"):
				return _game_dir.path_join(f)
	return ""


func _is_installed() -> bool:
	return _find_game_exe() != ""


func _read_local_version() -> String:
	if not _is_installed():
		return ""
	var path := _game_dir.path_join(VERSION_FILE)
	if not FileAccess.file_exists(path):
		return "unknown"
	return FileAccess.get_file_as_string(path).strip_edges()


# --- Update check -------------------------------------------------------------------------

func _check_for_updates() -> void:
	_set_state(State.CHECKING)
	_set_status("Checking for updates…", DIM)
	var url := "https://api.github.com/repos/%s/releases/latest" % REPO
	var err := _http.request(url, [USER_AGENT, "Accept: application/vnd.github+json"])
	if err != OK:
		_on_check_failed("Couldn't start the update check (error %d)." % err)


func _on_release_info(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_on_check_failed("Can't reach the update server — check your internet connection.")
		return
	if code == 404:
		_on_check_failed("No published release found (or the GitHub repository is private).")
		return
	if code != 200:
		_on_check_failed("Update server answered with HTTP %d." % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_on_check_failed("Couldn't read the release info.")
		return
	var asset := _pick_asset(data.get("assets", []))
	var tag := str(data.get("tag_name", ""))
	if asset.is_empty():
		_on_check_failed("Release %s has no .zip build attached." % tag)
		return
	var title := str(data.get("name", ""))
	var notes: Variant = data.get("body", "")
	_latest = {
		"tag": tag,
		"title": title if title != "" else tag,
		"notes": notes if notes is String else "",
		"url": str(asset.get("browser_download_url", "")),
		"size": int(asset.get("size", 0)),
	}
	_show_notes()
	if not _is_installed():
		_set_state(State.INSTALL)
		_set_status("Ready to install %s (%s)." % [tag, _mb(_latest.size)], TEXT)
	elif _local_version != tag:
		_set_status("Update available: %s → %s. Checking what changed…" % [_local_version, tag], ACCENT)
		_patch = await _plan_patch(data.get("assets", []))
		var size: int = _patch.bytes if not _patch.is_empty() else _latest.size
		_set_state(State.UPDATE)
		_set_status("Update available: %s → %s (%s)." % [_local_version, tag, _mb(size)], ACCENT)
	else:
		_set_state(State.PLAY)
		_set_status("Up to date.", DIM)


func _pick_asset(assets: Variant) -> Dictionary:
	if not assets is Array:
		return {}
	var first_zip := {}
	for a in assets:
		if not a is Dictionary:
			continue
		var n := str(a.get("name", "")).to_lower()
		if n.ends_with(ASSET_SUFFIX):
			return a
		if first_zip.is_empty() and n.ends_with(".zip"):
			first_zip = a
	return first_zip


func _on_check_failed(msg: String) -> void:
	if _is_installed():
		_set_state(State.PLAY)
		_set_status(msg + " You can still play the installed version.", ERROR_COLOR)
	else:
		_set_state(State.RETRY)
		_set_status(msg, ERROR_COLOR)
	if _latest.is_empty():
		_notes.text = "[color=#8b949e]Patch notes will appear here once the launcher can reach GitHub.[/color]"


# --- Download + install -------------------------------------------------------------------

func _download() -> void:
	_fallback_state = _state
	if DirAccess.make_dir_recursive_absolute(_install_dir) != OK:
		_set_status("Can't write to %s — move the launcher to a folder you own." % _install_dir, ERROR_COLOR)
		return
	_set_state(State.BUSY)
	_dl_base = 0
	_dl_total = 0
	var zip_path := _install_dir.path_join("update.zip")
	_dl_http = HTTPRequest.new()
	_dl_http.download_file = zip_path
	_dl_http.download_chunk_size = 1 << 20
	_dl_http.max_redirects = 10
	add_child(_dl_http)
	_dl_http.request_completed.connect(_on_download_done.bind(zip_path))
	var err := _dl_http.request(str(_latest.url), [USER_AGENT])
	if err != OK:
		_fail_update("Couldn't start the download (error %d)." % err, zip_path)


func _process(_delta: float) -> void:
	if _state != State.BUSY or _dl_http == null:
		return
	var total := _dl_total if _dl_total > 0 else _dl_http.get_body_size()
	if total <= 0:
		total = int(_latest.get("size", 0))
	var got := _dl_base + _dl_http.get_downloaded_bytes()
	if total > 0:
		_progress.value = got * 100.0 / total
	_set_status("Downloading %s…  %s / %s" % [_latest.tag, _mb(got), _mb(total)], TEXT)


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, zip_path: String) -> void:
	_dl_http.queue_free()
	_dl_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail_update("Download failed (result %d, HTTP %d)." % [result, code], zip_path)
		return
	_progress.value = 0
	_set_status("Installing %s…" % _latest.tag, TEXT)
	_thread = Thread.new()
	_thread.start(_extract.bind(zip_path))


## Runs on a worker thread. UI updates go through call_deferred.
func _extract(zip_path: String) -> void:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		_on_extract_done.call_deferred("The downloaded file isn't a valid zip.", zip_path)
		return
	var files := zip.get_files()
	var prefix := _common_root(files)
	_remove_dir(_game_dir)
	DirAccess.make_dir_recursive_absolute(_game_dir)
	for i in files.size():
		var entry: String = files[i]
		var rel := entry.replace("\\", "/").substr(prefix.length())
		if rel == "" or rel.contains(".."):
			continue
		var out := _game_dir.path_join(rel)
		if rel.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var fa := FileAccess.open(out, FileAccess.WRITE)
		if fa == null:
			zip.close()
			_on_extract_done.call_deferred("Couldn't write %s — is the game still running?" % rel, zip_path)
			return
		fa.store_buffer(zip.read_file(entry))
		fa.close()
		_on_extract_progress.call_deferred(i + 1, files.size())
	zip.close()
	_on_extract_done.call_deferred("", zip_path)


func _on_extract_progress(done: int, total: int) -> void:
	_progress.value = done * 100.0 / total
	_set_status("Installing %s…  %d / %d files" % [_latest.tag, done, total], TEXT)


func _on_extract_done(error: String, zip_path: String) -> void:
	_thread.wait_to_finish()
	_thread = null
	if error != "":
		_fail_update(error, zip_path)
		return
	DirAccess.remove_absolute(zip_path)
	if not _is_installed():
		_fail_update("The build didn't contain a game .exe.", "")
		return
	_finish_install()


func _finish_install() -> void:
	var f := FileAccess.open(_game_dir.path_join(VERSION_FILE), FileAccess.WRITE)
	if f:
		f.store_string(str(_latest.tag))
		f.close()
	_local_version = str(_latest.tag)
	_patch = {}
	_set_state(State.PLAY)
	_set_status("Installed %s. Have fun!" % _latest.tag, ACCENT)


func _fail_update(msg: String, zip_path: String) -> void:
	if zip_path != "":
		DirAccess.remove_absolute(zip_path)
	_local_version = _read_local_version()
	var st := _fallback_state if _is_installed() or _fallback_state == State.INSTALL else State.INSTALL
	_set_state(st)
	_set_status(msg, ERROR_COLOR)


## "Build/ProjectDescent.exe", "Build/x.pck" -> "Build/" (zips made by zipping a folder).
func _common_root(files: PackedStringArray) -> String:
	if files.is_empty():
		return ""
	var first := files[0].replace("\\", "/")
	var slash := first.find("/")
	if slash == -1:
		return ""
	var p := first.substr(0, slash + 1)
	for f in files:
		if not f.replace("\\", "/").begins_with(p):
			return ""
	return p


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_remove_dir(path.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


# --- Patch updates (see patcher.gd) ----------------------------------------------------------

## What the latest release needs downloaded, or {} to use the zip:
## {files: name -> {size, sha256, url}, whole: [names], pck: {...} or {}, bytes}.
func _plan_patch(assets: Variant) -> Dictionary:
	var urls := {}
	if assets is Array:
		for a in assets:
			if a is Dictionary:
				urls[str(a.get("name", ""))] = str(a.get("browser_download_url", ""))
	if not urls.has(MANIFEST):
		return {}
	var m := await _fetch(urls[MANIFEST])
	if not m.ok:
		return {}
	var manifest: Variant = JSON.parse_string(m.body.get_string_from_utf8())
	if not manifest is Dictionary or not manifest.get("files") is Array:
		return {}
	var files := {}
	for f in manifest.files:
		var n := str(f.get("name", "")) if f is Dictionary else ""
		if n == "" or n == VERSION_FILE or n.begins_with(".") or n.contains("/") or n.contains("\\") or not urls.has(n):
			return {}
		files[n] = {"size": int(f.get("size", 0)), "sha256": str(f.get("sha256", "")).to_lower(), "url": urls[n]}
	var pck_name := GAME_EXE.get_basename() + ".pck"
	if not files.has(pck_name):
		return {}
	var local_sha: Dictionary = await _in_thread(_hash_local.bind(files.keys()))
	var p := {"files": files, "whole": [], "pck": {}, "bytes": 0}
	for n in files:
		if local_sha.get(n, "") == files[n].sha256:
			continue
		if n == pck_name:
			p.pck = await _plan_pck(files[n])
			if not p.pck.is_empty():
				p.bytes += p.pck.plan.bytes
				continue
		p.whole.append(n)
		p.bytes += files[n].size
	return p


## SHA-256 of each named file in game/ ("" if missing). Runs on a worker thread.
func _hash_local(names: Array) -> Dictionary:
	var out := {}
	for n in names:
		var path := _game_dir.path_join(n)
		out[n] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	return out


## Plans rebuilding the .pck: reads the installed pack's directory and the new
## one's header + directory (two small Range requests). {} if it can't patch.
func _plan_pck(info: Dictionary) -> Dictionary:
	var local_path := _game_dir.path_join(GAME_EXE.get_basename() + ".pck")
	var local := Patcher.read_local(local_path)
	if local.is_empty():
		return {}
	var h := await _fetch_range(info.url, 0, mini(Patcher.HEADER_FETCH, info.size))
	if not h.ok:
		return {}
	var remote := Patcher.parse_header(h.body)
	if remote.is_empty() or remote.dir_offset >= info.size:
		return {}
	var d := await _fetch_range(info.url, remote.dir_offset, info.size)
	if not d.ok:
		return {}
	remote["entries"] = Patcher.parse_dir(d.body)
	if remote.entries.is_empty():
		return {}
	return {"remote": remote, "header": h.body, "dir": d.body, "plan": Patcher.plan(local, remote),
		"local": local_path, "url": info.url, "sha256": info.sha256}


func _apply_patch() -> void:
	_fallback_state = _state
	_set_state(State.BUSY)
	var staging := _game_dir.path_join(PATCH_DIR)
	_remove_dir(staging)
	DirAccess.make_dir_recursive_absolute(staging)
	_dl_base = 0
	_dl_total = _patch.bytes
	var err := ""
	for n in _patch.whole:
		var f: Dictionary = _patch.files[n]
		var r := await _fetch(f.url, PackedStringArray(), staging.path_join(n))
		if not r.ok or FileAccess.get_sha256(staging.path_join(n)) != f.sha256:
			err = "Download of %s failed." % n
			break
		_dl_base += f.size
	var pck: Dictionary = _patch.pck
	var pck_name := GAME_EXE.get_basename() + ".pck"
	if err == "" and not pck.is_empty():
		var parts: Array = []
		for i in pck.plan.ranges.size():
			var rg: Dictionary = pck.plan.ranges[i]
			var part := staging.path_join("part%d.bin" % i)
			var r := await _fetch_range(pck.url, rg.start, rg.end, part)
			if not r.ok or FileAccess.get_size(part) != rg.end - rg.start:
				err = "Download of the game data failed."
				break
			parts.append(part)
			_dl_base += rg.end - rg.start
		if err == "":
			_progress.value = 0
			_set_status("Patching %s…" % _latest.tag, TEXT)
			var report := func(done: int, total: int) -> void:
				_on_patch_progress.call_deferred(done, total)
			err = await _in_thread(Patcher.rebuild.bind(staging.path_join(pck_name), pck.header, pck.remote,
				pck.dir, pck.plan, pck.local, parts, pck.sha256, report))
	if err == "":
		var moved: Array = _patch.whole.duplicate()
		if not pck.is_empty():
			moved.append(pck_name)
		for n in moved:
			if DirAccess.rename_absolute(staging.path_join(n), _game_dir.path_join(n)) != OK:
				err = "Couldn't replace %s — is the game still running?" % n
				break
	if err != "":
		_remove_dir(staging)
		# Anything that went wrong: the full zip still works.
		_patch = {}
		_set_state(_fallback_state)
		_set_status(err + " Downloading the full game instead…", ERROR_COLOR)
		_download()
		return
	_remove_dir(staging)
	for f in DirAccess.get_files_at(_game_dir):
		if f != VERSION_FILE and not _patch.files.has(f):
			DirAccess.remove_absolute(_game_dir.path_join(f))
	_finish_install()


func _on_patch_progress(done: int, total: int) -> void:
	_progress.value = done * 100.0 / total
	_set_status("Patching %s…  %d / %d files" % [_latest.tag, done, total], TEXT)


## One HTTP request; to_file streams the body to disk. {ok, result, code, headers, body}.
func _fetch(url: String, extra: PackedStringArray = PackedStringArray(), to_file := "", redirects := 10) -> Dictionary:
	var req := HTTPRequest.new()
	req.accept_gzip = false
	req.max_redirects = redirects
	req.timeout = 0.0 if to_file != "" else 20.0
	req.download_chunk_size = 1 << 20
	req.download_file = to_file
	add_child(req)
	_dl_http = req
	var r := {"ok": false, "result": -1, "code": 0, "headers": PackedStringArray(), "body": PackedByteArray()}
	if req.request(url, PackedStringArray([USER_AGENT]) + extra) == OK:
		var res: Array = await req.request_completed
		r.merge({"result": res[0], "code": res[1], "headers": res[2], "body": res[3]}, true)
		r.ok = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200
	if _dl_http == req:
		_dl_http = null
	req.queue_free()
	return r


## Bytes [start, end) of a release asset. GitHub's asset link redirects to a
## short-lived signed storage URL, so it is resolved fresh for every range.
func _fetch_range(url: String, start: int, end: int, to_file := "") -> Dictionary:
	var target := url
	var hop := await _fetch(url, PackedStringArray(), "", 0)
	for h in hop.headers:
		if h.to_lower().begins_with("location:"):
			target = h.substr(9).strip_edges()
	var r := await _fetch(target, PackedStringArray(["Range: bytes=%d-%d" % [start, end - 1]]), to_file)
	r.ok = r.result == HTTPRequest.RESULT_SUCCESS and r.code == 206
	return r


func _in_thread(job: Callable) -> Variant:
	_thread = Thread.new()
	_thread.start(job)
	while _thread.is_alive():
		await get_tree().process_frame
	var out: Variant = _thread.wait_to_finish()
	_thread = null
	return out


# --- Launch ---------------------------------------------------------------------------

func _launch() -> void:
	var exe := _find_game_exe()
	if exe == "":
		_set_state(State.INSTALL)
		_set_status("Game files are missing — install again.", ERROR_COLOR)
		return
	if OS.create_process(exe, []) == -1:
		_set_status("Couldn't start the game.", ERROR_COLOR)
		return
	get_tree().quit()


func _on_main_pressed() -> void:
	if _state == State.UPDATE and not _patch.is_empty():
		_apply_patch()
		return
	match _state:
		State.INSTALL, State.UPDATE:
			_download()
		State.PLAY:
			_launch()
		State.RETRY:
			_check_for_updates()


# --- Settings file (shared with the game) ---------------------------------------------------

func _settings_path() -> String:
	return OS.get_data_dir().path_join(GAME_USER_DIR).path_join("settings.cfg")


func _load_settings() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(_settings_path())   # missing file = defaults
	window_mode = clampi(int(_cfg.get_value("display", "window_mode", window_mode)), 0, WINDOW_MODES.size() - 1)
	resolution = clampi(int(_cfg.get_value("display", "resolution", resolution)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(_cfg.get_value("display", "vsync", vsync))
	max_fps = clampi(int(_cfg.get_value("display", "max_fps", max_fps)), 0, FPS_OPTIONS.size() - 1)
	_graphics_touched = _cfg.has_section_key("graphics", "quality")
	quality = clampi(int(_cfg.get_value("graphics", "quality", quality)), 0, QUALITY_LEVELS.size() - 1)
	render_scale = clampi(int(_cfg.get_value("graphics", "render_scale", render_scale)), 0, RENDER_SCALES.size() - 1)


func _save_settings() -> void:
	_cfg.set_value("display", "window_mode", window_mode)
	_cfg.set_value("display", "resolution", resolution)
	_cfg.set_value("display", "vsync", vsync)
	_cfg.set_value("display", "max_fps", max_fps)
	if _graphics_touched:
		_cfg.set_value("graphics", "quality", quality)
		_cfg.set_value("graphics", "render_scale", render_scale)
	var path := _settings_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if _cfg.save(path) != OK:
		_set_status("Couldn't save options to %s." % path, ERROR_COLOR)


# --- UI ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("1a2433"))
	grad.set_color(1, Color("07090d"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 28)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(main)

	# Left column: title + buttons.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)
	var t1 := _label("PROJECT:", 42, TEXT)
	t1.add_theme_constant_override("line_spacing", -8)
	left.add_child(t1)
	left.add_child(_label("DESCENT", 42, ACCENT))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_main_btn = _button("", 24, true)
	_main_btn.pressed.connect(_on_main_pressed)
	left.add_child(_main_btn)
	_options_btn = _button("OPTIONS", 18)
	_options_btn.pressed.connect(_toggle_options)
	left.add_child(_options_btn)
	var quit := _button("QUIT", 18)
	quit.pressed.connect(get_tree().quit)
	left.add_child(quit)

	# Right panel: patch notes / options.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := _box(Color(0.05, 0.07, 0.1, 0.85), Color(ACCENT, 0.25))
	ps.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	main.add_child(panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	panel.add_child(right)
	_panel_title = _label("PATCH NOTES", 15, ACCENT)
	right.add_child(_panel_title)
	right.add_child(HSeparator.new())
	_notes = RichTextLabel.new()
	_notes.bbcode_enabled = true
	_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.add_theme_color_override("default_color", TEXT)
	_notes.add_theme_font_size_override("normal_font_size", 15)
	_notes.add_theme_font_size_override("bold_font_size", 15)
	_notes.text = "[color=#8b949e]Loading patch notes…[/color]"
	right.add_child(_notes)
	_options = _build_options()
	_options.visible = false
	_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_options)

	# Bottom: status, version, progress.
	var bottom := HBoxContainer.new()
	root_v.add_child(bottom)
	_status = _label("", 14, DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(_status)
	_version_lbl = _label("", 13, DIM)
	bottom.add_child(_version_lbl)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 8
	_progress.show_percentage = false
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(1, 1, 1, 0.08)
	pbg.set_corner_radius_all(4)
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = ACCENT
	pfill.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("background", pbg)
	_progress.add_theme_stylebox_override("fill", pfill)
	root_v.add_child(_progress)
	_set_state(State.CHECKING)


func _build_options() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	var mode_opt := _option(WINDOW_MODES, window_mode)
	var res_labels: Array = []
	for r in RESOLUTIONS:
		res_labels.append("%d x %d" % [r.x, r.y])
	var res_opt := _option(res_labels, resolution)
	res_opt.disabled = window_mode != 0
	mode_opt.item_selected.connect(func(i: int):
		window_mode = i
		res_opt.disabled = i != 0
		_save_settings())
	res_opt.item_selected.connect(func(i: int):
		resolution = i
		_save_settings())
	_row(grid, "Window mode", mode_opt)
	_row(grid, "Resolution", res_opt)

	var vs := CheckButton.new()
	vs.focus_mode = Control.FOCUS_NONE
	vs.button_pressed = vsync
	vs.toggled.connect(func(on: bool):
		vsync = on
		_save_settings())
	_row(grid, "VSync", vs)

	var fps_labels: Array = []
	for f in FPS_OPTIONS:
		fps_labels.append("Unlimited" if f == 0 else str(f))
	var fps_opt := _option(fps_labels, max_fps)
	fps_opt.item_selected.connect(func(i: int):
		max_fps = i
		_save_settings())
	_row(grid, "Max FPS", fps_opt)

	var q_opt := _option(QUALITY_LEVELS, quality)
	q_opt.item_selected.connect(func(i: int):
		quality = i
		_graphics_touched = true
		_save_settings())
	_row(grid, "Graphics quality", q_opt)

	var scale_labels: Array = []
	for rs in RENDER_SCALES:
		scale_labels.append("%d%%" % int(round(rs * 100.0)))
	var scale_opt := _option(scale_labels, render_scale)
	scale_opt.item_selected.connect(func(i: int):
		render_scale = i
		_graphics_touched = true
		_save_settings())
	_row(grid, "Render scale", scale_opt)

	var note := _label("Saved instantly. These are the same settings as the in-game Settings menu; keybinds, audio and interface size are set in-game.", 13, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	return v


func _toggle_options() -> void:
	_options.visible = not _options.visible
	_notes.visible = not _options.visible
	_panel_title.text = "OPTIONS" if _options.visible else "PATCH NOTES"
	_options_btn.text = "PATCH NOTES" if _options.visible else "OPTIONS"


func _set_state(s: State) -> void:
	_state = s
	_main_btn.disabled = s == State.CHECKING or s == State.BUSY
	match s:
		State.CHECKING: _main_btn.text = "CHECKING…"
		State.INSTALL: _main_btn.text = "INSTALL"
		State.UPDATE: _main_btn.text = "UPDATE"
		State.PLAY: _main_btn.text = "PLAY"
		State.BUSY: _main_btn.text = "UPDATING…"
		State.RETRY: _main_btn.text = "RETRY"
	_progress.visible = s == State.BUSY
	if s == State.BUSY:
		_progress.value = 0
	var parts := PackedStringArray()
	parts.append("Installed: %s" % (_local_version if _local_version != "" else "—"))
	if not _latest.is_empty():
		parts.append("Latest: %s" % _latest.tag)
	_version_lbl.text = "   ·   ".join(parts)


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _show_notes() -> void:
	var head := "[font_size=24][b]%s[/b][/font_size]\n\n" % _esc(str(_latest.title))
	_notes.text = head + _md_to_bbcode(str(_latest.notes))


## Enough Markdown for GitHub release notes: headings, bullets, **bold**.
func _md_to_bbcode(md: String) -> String:
	if md.strip_edges() == "":
		return "[color=#8b949e]No patch notes for this release.[/color]"
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var out := PackedStringArray()
	for raw in md.replace("\r", "").split("\n"):
		var line := bold.sub(_esc(raw), "[b]$1[/b]", true)
		var s := line.strip_edges(true, false)
		if s.begins_with("#"):
			var txt := s.lstrip("#").strip_edges()
			out.append("[font_size=18][b][color=#7fc8ff]%s[/color][/b][/font_size]" % txt)
		elif s.begins_with("- ") or s.begins_with("* "):
			var depth := int((line.length() - s.length()) / 2.0)
			out.append("   ".repeat(depth + 1) + "•  " + s.substr(2))
		else:
			out.append(line)
	return "\n".join(out)


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _button(text: String, font_size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58 if primary else 42)
	b.add_theme_font_size_override("font_size", font_size)
	var base := ACCENT.darkened(0.6) if primary else Color(1, 1, 1, 0.06)
	var border := ACCENT if primary else Color(1, 1, 1, 0.15)
	b.add_theme_stylebox_override("normal", _box(base, border))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15), border.lightened(0.25)))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.2), border))
	b.add_theme_stylebox_override("disabled", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DIM)
	return b


func _option(labels: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(230, 34)
	for l in labels:
		o.add_item(str(l))
	o.select(selected)
	return o


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var l := _label(text, 15, TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	grid.add_child(control)
