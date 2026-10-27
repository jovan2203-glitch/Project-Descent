class_name Patcher
extends RefCounted

## Patch updates: rebuilds the new release's .pck from the installed one plus
## only the files that changed, downloaded with HTTP Range requests.
##
## A Godot .pck (format 3+) is: a header, the files (zero padding between them
## for alignment), then a directory at dir_offset listing every file's offset,
## size and MD5. Files whose MD5 the installed pack already has are copied from
## it; the rest are fetched from the release's raw .pck. The result must match
## the release manifest's SHA-256 byte for byte, else the caller falls back to
## the full zip.

const MAGIC := 0x43504447                 # "GDPC"
const FLAG_DIR_ENCRYPTED := 1
const FLAG_REL_FILEBASE := 2
const FLAG_SPARSE_BUNDLE := 4
const FILE_ENCRYPTED := 1
const HEADER_FETCH := 4096                # bytes fetched to read the remote header
const MERGE_GAP := 256 * 1024             # nearby changed files share one request
const CHUNK := 1 << 20


## {version, file_base, dir_offset} or {} if this isn't a pack we can patch.
static func parse_header(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 48:
		return {}
	var s := StreamPeerBuffer.new()
	s.data_array = bytes
	if s.get_u32() != MAGIC:
		return {}
	var version := s.get_u32()
	s.get_u32(); s.get_u32(); s.get_u32()   # engine major / minor / patch
	var flags := s.get_u32()
	if version < 3 or flags & (FLAG_DIR_ENCRYPTED | FLAG_SPARSE_BUNDLE) or not flags & FLAG_REL_FILEBASE:
		return {}
	var file_base := s.get_u64()
	var dir_offset := s.get_u64()
	return {"version": version, "file_base": file_base, "dir_offset": dir_offset}


## Entries {path, offset, size, md5} (offset relative to file_base), or [] if unreadable.
static func parse_dir(bytes: PackedByteArray) -> Array:
	var s := StreamPeerBuffer.new()
	s.data_array = bytes
	if bytes.size() < 4:
		return []
	var count := s.get_u32()
	var out: Array = []
	for i in count:
		if s.get_available_bytes() < 4:
			return []
		var n := s.get_u32()
		if s.get_available_bytes() < n + 36:
			return []
		var path: String = s.get_data(n)[1].get_string_from_utf8()
		var offset := s.get_u64()
		var size := s.get_u64()
		var md5: PackedByteArray = s.get_data(16)[1]
		if s.get_u32() & FILE_ENCRYPTED:
			return []
		out.append({"path": path, "offset": offset, "size": size, "md5": md5.hex_encode()})
	return out


## Reads an installed pack: {file_base, dir_offset, entries} or {}.
static func read_local(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var head := parse_header(f.get_buffer(mini(HEADER_FETCH, f.get_length())))
	if head.is_empty() or head.dir_offset >= f.get_length():
		return {}
	f.seek(head.dir_offset)
	var entries := parse_dir(f.get_buffer(f.get_length() - head.dir_offset))
	if entries.is_empty():
		return {}
	head["entries"] = entries
	return head


## Works out what to download. remote = {file_base, dir_offset, entries}.
## Returns {ranges: [{start, end}], bytes, sources}: sources[i] says where remote
## entry i comes from ({local: abs offset} or {range: index, at: offset in it}).
static func plan(local: Dictionary, remote: Dictionary) -> Dictionary:
	var have := {}
	for e in local.entries:
		have[e.md5 + ":" + str(e.size)] = local.file_base + e.offset
	var need: Array = []   # [abs start, abs end, entry index]
	var sources: Array = []
	sources.resize(remote.entries.size())
	for i in remote.entries.size():
		var e: Dictionary = remote.entries[i]
		var key: String = e.md5 + ":" + str(e.size)
		if have.has(key):
			sources[i] = {"local": have[key]}
		elif e.size > 0:
			var start: int = remote.file_base + e.offset
			need.append([start, start + e.size, i])
		else:
			sources[i] = {"local": 0}
	need.sort_custom(func(a, b): return a[0] < b[0])
	var ranges: Array = []
	var total := 0
	for n in need:
		if ranges.is_empty() or n[0] - ranges[-1].end > MERGE_GAP:
			ranges.append({"start": n[0], "end": n[1]})
		else:
			ranges[-1].end = maxi(ranges[-1].end, n[1])
		sources[n[2]] = {"range": ranges.size() - 1, "at": n[0] - ranges[-1].start}
	for r in ranges:
		total += r.end - r.start
	return {"ranges": ranges, "bytes": total, "sources": sources}


## Writes the new pack to out_path. range_files[i] holds the bytes of plan.ranges[i].
## progress is called (done, total) from this thread; returns "" or an error.
static func rebuild(out_path: String, header: PackedByteArray, remote: Dictionary, dir_bytes: PackedByteArray,
		patch: Dictionary, local_path: String, range_files: Array, expected_sha256: String,
		progress: Callable = Callable()) -> String:
	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		return "Couldn't write %s." % out_path
	var local := FileAccess.open(local_path, FileAccess.READ)
	var ranges: Array = []
	for p in range_files:
		var rf := FileAccess.open(p, FileAccess.READ)
		if rf == null:
			return "A downloaded part is missing."
		ranges.append(rf)
	var sha := HashingContext.new()
	sha.start(HashingContext.HASH_SHA256)
	var w := {"out": out, "sha": sha, "pos": 0}
	_put(w, header.slice(0, remote.file_base))
	var order: Array = range(remote.entries.size())
	order.sort_custom(func(a, b): return remote.entries[a].offset < remote.entries[b].offset)
	for k in order.size():
		var i: int = order[k]
		var e: Dictionary = remote.entries[i]
		var at: int = remote.file_base + e.offset
		if at < w.pos:
			return "The new pack has overlapping files."
		_zeros(w, at - w.pos)
		var src: Dictionary = patch.sources[i]
		if src.has("range"):
			var rf: FileAccess = ranges[src.range]
			rf.seek(src.at)
			_copy(w, rf, e.size)
		else:
			if local == null:
				return "The installed pack can't be read."
			local.seek(src.local)
			_copy(w, local, e.size)
		if progress.is_valid() and k % 32 == 0:
			progress.call(k + 1, order.size())
	if remote.dir_offset < w.pos:
		return "The new pack's directory overlaps its files."
	_zeros(w, remote.dir_offset - w.pos)
	_put(w, dir_bytes)
	out.close()
	if sha.finish().hex_encode() != expected_sha256.to_lower():
		return "The patched game files didn't match the release."
	return ""


static func _put(w: Dictionary, bytes: PackedByteArray) -> void:
	w.out.store_buffer(bytes)
	w.sha.update(bytes)
	w.pos += bytes.size()


static func _zeros(w: Dictionary, n: int) -> void:
	while n > 0:
		var buf := PackedByteArray()
		buf.resize(mini(n, CHUNK))
		_put(w, buf)
		n -= buf.size()


static func _copy(w: Dictionary, from: FileAccess, n: int) -> void:
	while n > 0:
		var buf := from.get_buffer(mini(n, CHUNK))
		if buf.is_empty():
			return
		_put(w, buf)
		n -= buf.size()
