extends "res://scripts/player/player_kit.gd"
class_name WildPageKit

# Hooked up from player.gd through its var "wild_page".
# --- Rune of the Wild Page (Legendary): a random page of the book ---------------------
# With the rune on my gear, each spell or ability of mine that goes off has a chance
# to cast a random damaging ability of the same book (any of them, learned or not) at
# my target, for free: exactly what casting it does (its hit, DoT, Chill, ground
# spell, summon...), but it costs nothing, uses up no stacks, needs no weapon or
# range, never casts or channels (a channel goes out as a quick burst) and leaves its
# own cooldown and the global cooldown as they were. Once every WILD_PAGE_COOLDOWN at
# most. Everything it does is an echo: its own meter line per ability, "<name> (Wild
# Page)" (Details). The numbers are in balance.gd.

const Categories = preload("res://scripts/categories.gd")
const WILD_PAGE_RUNE := "wild_page"
## Meter lines of echoed abilities: "<ability id>@wild_page" (Details.ECHO_SUFFIX).
const WILD_PAGE_NAME := "Wild Page"
## Abilities with these tags heal, shield or revive: they are never a page.
const NO_HIT_TAGS := ["Heal", "Shield", "Resurrect", "Revive", "Trinket"]
## Instant abilities aimed at a spot (their circle's click): cast at the target's feet.
const PLACED_INSTANTS := ["cinderrain", "decoy", "mossback", "chokingvipers"]
## Tries per page torn: a page whose ability can't go off now (Return Stroke with no
## parry...) gives way to another.
const TRIES := 3
var _ready_at := 0.0   # seconds: when it can tear a page again
var _queued := ""      # the ability that tore a page, cast next frame ("" = none)
var _went_off := false

## The abilities of `book` a page can be torn from: every one with a direct hit
## (coefficient above 0), except `used` itself. Weapon abilities count with `weapon`
## (or the starter weapon they need).
static func pool(book: String, used: String, weapon: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if book == "" or book == Categories.RUNE:
		return out
	for id in Abilities.in_category(book):
		if id == used or Abilities.is_trinket_slot(id):
			continue
		var tags := Abilities.tags_of(id)
		var heals := false
		for t in NO_HIT_TAGS:
			if tags.has(t):
				heals = true
		if not heals and echo_coef(id, weapon) > 0.0:
			out.append(id)
	return out

## One hit of `id` (coefficient), with `weapon` or the starter weapon it needs.
static func echo_coef(id: String, weapon: Dictionary) -> float:
	var c := Abilities.hit_base(id, weapon)
	if c < 0.0:
		c = Abilities.hit_base(id, Abilities.basic_weapon(id))
	return c

## Does this use tear a page? `roll` 0-100, `now` / `ready_at` in seconds.
static func tears(roll: float, now: float, ready_at: float) -> bool:
	return now >= ready_at and roll < Balance.WILD_PAGE_CHANCE

## How a free cast of `id` goes off: "placed" (an instant aimed at a spot), "burst"
## (a channel), "land" (a cast: straight to what it does when it lands) or "use"
## (an instant ability).
static func echo_kind(id: String) -> String:
	if PLACED_INSTANTS.has(id):
		return "placed"
	var res := Abilities.get_resource(id)
	if res == null:
		return ""
	if int(res.cast_type) == 2:   # CHANNEL
		return "burst"
	if int(res.cast_type) == 1 or int(res.cast_type) == 3 or Player.ENEMY_BOLTS.has(id) or Player.SUPPORT_CASTS.has(id):
		return "land"
	return "use"

## A spell or ability of mine went off (cast_finished): maybe tear a page. It is cast
## next frame (this signal comes in the middle of my own cast landing).
func _on_cast_finished(id: String) -> void:
	if player.echoing():
		_went_off = true   # (a free cast went off; free casts never tear pages)
		return
	if _queued != "" or not player.frost_melee._has_rune(WILD_PAGE_RUNE):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not tears(randf() * 100.0, now, _ready_at):
		return
	_ready_at = now + Balance.WILD_PAGE_COOLDOWN
	_queued = id

## Every frame: cast the page torn last frame.
func _tick_wild_page() -> void:
	if _queued == "":
		return
	var used := _queued
	_queued = ""
	var foe: Node = player.target
	if player.is_dead() or foe == null or not is_instance_valid(foe) or not foe.is_in_group("enemies") \
			or not foe.has_method("is_alive") or not foe.is_alive():
		return
	var page := pool(Abilities.category_of(used), used, Abilities.equipped_weapon())
	page.shuffle()
	var tries := 0
	for id in page:
		if player.casting and player.current_spell == id:
			continue   # (the one I am casting or channeling right now)
		if echo(id, foe as Node3D):
			return
		tries += 1
		if tries >= TRIES:
			return

## Cast `id` at `foe` for free (see the top of this file). True if it went off.
func echo(id: String, foe: Node3D) -> bool:
	var kind := echo_kind(id)
	if kind == "" or foe == null or not is_instance_valid(foe):
		return false
	var saved := _save(id)
	player.pstate = Player.PState.IDLE   # (set straight: my own cast is put back after)
	player.current_spell = ""
	player.target = foe
	player.cast_point = foe.global_position
	player._cast_target = foe
	player._cast_kind = "enemy"
	player.gcd_left = 0.0
	player.cooldowns[id] = 0.0
	_went_off = false
	player._echo_depth += 1
	match kind:
		"placed":
			match id:
				FireBowKit.CINDER_RAIN_ID: player.fire_bow._start_cinder_rain(foe.global_position)
				ArcaneTankKit.DECOY_ID: player.arcane_tank._start_decoy(foe.global_position)
				_: player.weaver._start_finisher(id, foe.global_position)
		"burst":
			if id == ArcaneCasterKit.SIGIL_DARTS_ID:
				player.arcane_caster._start_sigil_darts()
			elif id == "embervolley":
				player.fire_caster._start_ember_volley()
		"land":
			player._bus().cast_finished.emit(id)   # (as when a cast finishes: talents that count casts)
			player._land_spell(id)
		_:
			player._use_drafted(id)
	player._echo_depth -= 1
	_restore(saved, id)
	return _went_off

## What a free cast must leave as it was: my own cast, aim, target, resources, the
## global cooldown and the page's own cooldown.
func _save(id: String) -> Dictionary:
	return {"pstate": player.pstate, "spell": player.current_spell, "state": player.current_state,
		"timer": player.cast_timer, "duration": player.cast_duration, "name": player.cast_name,
		"channel": player.cast_is_channel, "target": player.target, "point": player.cast_point,
		"cast_target": player._cast_target, "cast_kind": player._cast_kind,
		"gcd_left": player.gcd_left, "gcd_total": player.gcd_total, "queued": player._queued,
		"queued_at": player._queued_at, "resources": player.resources.duplicate(),
		"had_cd": player.cooldowns.has(id), "cd": float(player.cooldowns.get(id, 0.0)),
		"yaw": player.rotation.y,
		"instinct": player.frost_bow._instinct_cast, "conc": player.fire_cooldowns._conc_cast,
		"cinder": player.fire_cooldowns._cinder_cast, "flicker": player.storm_arrow_kit._flicker_cast,
		"overture": player.storm_arrow_kit._overture_cast, "bottled": player.bottled_kit._bottled_cast,
		"unwind": player.arcane_talents._unwind_cast, "glint": player.arcane_caster._glint_cast,
		"volley": player.fire_caster._volley_left, "darts": player.arcane_caster._darts_left}

func _restore(s: Dictionary, id: String) -> void:
	player.pstate = int(s["pstate"])
	player.current_spell = str(s["spell"])
	player.current_state = str(s["state"])
	player.cast_timer = float(s["timer"])
	player.cast_duration = float(s["duration"])
	player.cast_name = str(s["name"])
	player.cast_is_channel = bool(s["channel"])
	player.target = s["target"] if is_instance_valid(s["target"]) else null
	player.cast_point = s["point"]
	player._cast_target = s["cast_target"] if is_instance_valid(s["cast_target"]) else null
	player._cast_kind = str(s["cast_kind"])
	player.gcd_left = float(s["gcd_left"])
	player.gcd_total = float(s["gcd_total"])
	player._queued = str(s["queued"])
	player._queued_at = float(s["queued_at"])
	player.resources = s["resources"]
	if bool(s["had_cd"]):
		player.cooldowns[id] = float(s["cd"])
	else:
		player.cooldowns.erase(id)
	player.rotation.y = float(s["yaw"])
	player.frost_bow._instinct_cast = bool(s["instinct"])
	player.fire_cooldowns._conc_cast = bool(s["conc"])
	player.fire_cooldowns._cinder_cast = bool(s["cinder"])
	player.storm_arrow_kit._flicker_cast = bool(s["flicker"])
	player.storm_arrow_kit._overture_cast = bool(s["overture"])
	player.bottled_kit._bottled_cast = bool(s["bottled"])
	player.arcane_talents._unwind_cast = bool(s["unwind"])
	player.arcane_caster._glint_cast = bool(s["glint"])
	player.fire_caster._volley_left = int(s["volley"])
	player.arcane_caster._darts_left = int(s["darts"])
