extends SceneTree

## Dev check for patch updates (not exported). Rebuilds a release's .pck from an
## older one with patcher.gd and checks it matches byte for byte, then checks
## GitHub Range requests work the way launcher.gd's _fetch_range uses them.
##   godot --headless --path launcher -s res://tools/patch_test.gd -- OLD.pck NEW.pck [asset URL]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- OLD.pck NEW.pck [release asset URL]")
		quit(2)
		return
	var ok := _rebuild(args[0], args[1])
	if ok and args.size() > 2:
		ok = await _range(args[2])
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _rebuild(old_path: String, new_path: String) -> bool:
	var local := Patcher.read_local(old_path)
	var f := FileAccess.open(new_path, FileAccess.READ)
	if local.is_empty() or f == null:
		print("can't read the packs")
		return false
	var size := f.get_length()
	var header := f.get_buffer(mini(Patcher.HEADER_FETCH, size))
	var remote := Patcher.parse_header(header)
	f.seek(remote.dir_offset)
	var dir := f.get_buffer(size - remote.dir_offset)
	remote["entries"] = Patcher.parse_dir(dir)
	var plan := Patcher.plan(local, remote)
	# Stand-ins for the Range downloads: slices of the new pack.
	var tmp := OS.get_user_data_dir().path_join("patch_test")
	DirAccess.make_dir_recursive_absolute(tmp)
	var parts: Array = []
	for i in plan.ranges.size():
		var r: Dictionary = plan.ranges[i]
		f.seek(r.start)
		var p := tmp.path_join("part%d.bin" % i)
		FileAccess.open(p, FileAccess.WRITE).store_buffer(f.get_buffer(r.end - r.start))
		parts.append(p)
	f.close()
	var out := tmp.path_join("rebuilt.pck")
	var err := Patcher.rebuild(out, header, remote, dir, plan, old_path, parts, FileAccess.get_sha256(new_path))
	var changed: int = plan.sources.filter(func(s): return s.has("range")).size()
	print("files %d, changed %d, ranges %d, download %.2f MB of %.2f MB" % [remote.entries.size(), changed,
		plan.ranges.size(), plan.bytes / 1048576.0, size / 1048576.0])
	print("rebuild: ", "matches the new pack" if err == "" else err)
	for p in parts:
		DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(out)
	return err == ""


func _range(url: String) -> bool:
	await process_frame   # root joins the tree after _initialize
	var hop: Array = await _http_get(url, PackedStringArray(), 0)
	var target := url
	for h in hop[2]:
		if h.to_lower().begins_with("location:"):
			target = h.substr(9).strip_edges()
	print("redirect: result %d, HTTP %d, resolved %s" % [hop[0], hop[1], target != url])
	var r: Array = await _http_get(target, PackedStringArray(["Range: bytes=0-3"]), 10)
	var body: PackedByteArray = r[3]
	print("range: result %d, HTTP %d, %d bytes %s" % [r[0], r[1], body.size(), body.hex_encode()])
	return r[1] == 206 and body.size() == 4


func _http_get(url: String, extra: PackedStringArray, redirects: int) -> Array:
	var req := HTTPRequest.new()
	req.accept_gzip = false
	req.max_redirects = redirects
	req.timeout = 20.0
	root.add_child(req)
	req.request(url, PackedStringArray(["User-Agent: ProjectDescentLauncher"]) + extra)
	var res: Array = await req.request_completed
	req.queue_free()
	return res
