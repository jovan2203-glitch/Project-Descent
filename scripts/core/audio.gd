extends Node

# Barebones audio manager (autoload "Audio").
#   - Buses: Master / Music / SFX (volumes in Settings > Audio).
#   - Listens on the SignalBus and plays a named sound for game events.
#   - Sounds are optional files: drop e.g. res://audio/sfx/hit.ogg in and it plays;
#     missing files are silently skipped (so the game runs with no audio at all).
#
#   Audio.play_sfx("hit")            Audio.play_music("dungeon")
#
# Sound names used: cast_start, cast, hit, crit, hurt, block, enemy_death,
# loot, death, level_up, error, proc.  Music: menu, dungeon.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const VOICES := 8

var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache := {}          # path key -> AudioStream or null (missing)
var _current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/settings.gd").ensure_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(func(): if _music.stream: _music.play())   # loop
	_connect.call_deferred()

func _connect() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus == null:
		return
	bus.cast_started.connect(func(_id, _d): play_sfx("cast_start"))
	bus.cast_finished.connect(func(_id): play_sfx("cast"))
	bus.damage_dealt.connect(_on_damage)
	bus.enemy_died.connect(func(_e): play_sfx("enemy_death"))
	bus.item_looted.connect(func(_id): play_sfx("loot"))
	bus.player_died.connect(func(): play_sfx("death"))
	bus.level_up.connect(func(_lv): play_sfx("level_up"))
	bus.action_error.connect(func(_m): play_sfx("error"))
	bus.rune_triggered.connect(func(_e): play_sfx("proc"))
	bus.game_state_changed.connect(func(s): play_music("menu" if s == 0 else "dungeon"))

func _on_damage(info: RefCounted) -> void:
	var tgt: Node = info.target
	if info.blocked:
		play_sfx("block")
	elif tgt and is_instance_valid(tgt) and tgt.is_in_group("player"):
		play_sfx("hurt")
	else:
		play_sfx("crit" if info.crit else "hit")

func play_sfx(sound: String, pitch_jitter: float = 0.06) -> void:
	var stream := _find(SFX_DIR, sound)
	if stream == null:
		return
	var voice: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			voice = v
			break
	if voice == null:
		voice = _voices[0]   # all busy: steal the oldest
		_voices.push_back(_voices.pop_front())
	voice.stream = stream
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()

func play_music(track: String) -> void:
	if track == _current_music:
		return
	_current_music = track
	var stream := _find(MUSIC_DIR, track)
	_music.stop()
	_music.stream = stream
	if stream:
		_music.play()

func _find(dir: String, sound: String) -> AudioStream:
	var key := dir + sound
	if _cache.has(key):
		return _cache[key]
	var found: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [dir, sound, ext]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_cache[key] = found
	return found
