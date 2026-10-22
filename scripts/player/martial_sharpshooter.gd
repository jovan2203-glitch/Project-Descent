extends "res://scripts/player/player_kit.gd"
class_name SharpshooterKit

# Hooked up from player.gd through its var "sharp".
# --- Martial archer: Sharpshooter ------------------------------------------------------
# No resource: the cooldowns are the resource (docs/design/martial.md).
#   Cuts     each engine shot's hit brings others back sooner (Abilities.SHARP_LINKS):
#            Quick Shot -> Pierce -> Spread -> Heavy Draw -> (Quick Shot reset, the rest
#            cut); Follow Up cuts whichever shot I used just before it. A crit makes its
#            cuts full resets.
#   Overcut  a cut (or reset) on a shot that is already ready charges it instead:
#            OVERCUT_PCT% more damage per second, up to OVERCUT_MAX seconds. Firing the
#            shot spends it. So holding a shot can beat firing it, but a held shot feeds
#            nothing and the engine starves.
#   Streak   +1 per engine shot used, STREAK_PCT% more damage each. Loose halves it;
#            STREAK_HOLD sec without a shot and it's lost. At STREAK_MAX Heavy Draw is
#            instant and a sure crit (so its cuts are all resets).
#   Breathe  the next cut within BREATHE_TIME is a full reset. Fast Hands: cuts doubled.
# Everything runs on my machine (cooldowns are mine); the party sees the Streak and a
# gold bowstring (scripts/sharpshooter_fx.gd, Net fx "sharpshooter").
# Numbers: balance.gd (SHARP_*, OVERCUT_*, STREAK_*, BREATHE_*, FAST_HANDS_*).

const SharpFx = preload("res://scripts/sharpshooter_fx.gd")
const SharpIcons = preload("res://scripts/ui/sharpshooter_icons.gd")
const QUICK_SHOT_ID := "quickshot"
const PIERCE_ID := "pierce"
const SPREAD_ID := "spread"
const HEAVY_DRAW_ID := "heavydraw"
const FOLLOW_UP_ID := "followup"
const LOOSE_ID := "loose"
const BREATHE_ID := "breathe"
const FAST_HANDS_ID := "fasthands"
const SECOND_ARROW_ID := "secondarrow"   # Second Arrow (talent): its own meter line (Details.HIT_NAMES)
const STREAK_FX := "sharp_streak"
const BREATHE_FX := "sharp_breathe"
const FAST_FX := "sharp_fast_hands"
const TELL_EVERY := 3.0              # seconds between telling the party what my quiver shows
## Overcut that lights the bowstring gold for the party (seconds on one shot).
const GOLD_AT := 6.25

var _overcut := {}                   # shot id -> seconds of Overcut on it
var _streak := 0
var _streak_at := 0.0                # my last Sharpshooter shot
var _last_engine := ""               # the engine shot used last (Follow Up cuts it)
var _follow_target := ""             # ... the one my Follow Up in flight cuts
var _breathe_until := 0.0
var _fast_until := 0.0
var _pierce_hits := 0                # enemies my last Pierce hit (its cut grows per enemy)
var _sure_heavy := false             # a Heavy Draw at full Streak is in flight: sure crit
var _ready_for := {}                 # Waiting Game: shot id -> seconds it has stayed ready
var _was_in_combat := false
var _shown := ""
var _told := 0.0

# Rules as static functions (tests/test_sharpshooter.gd).

## A cut of `cut` seconds on a shot with `left` seconds of cooldown: what is left of the
## cooldown, and the Overcut it makes (whatever would have gone below 0).
static func cut_result(left: float, cut: float) -> Dictionary:
	var l := maxf(left, 0.0)
	var c := maxf(cut, 0.0)
	return {"left": maxf(l - c, 0.0), "overcut": maxf(c - l, 0.0)}

## A full reset of a shot with `left` seconds of cooldown (`full` = its whole cooldown):
## ready at once; one that was ready already gets its whole cooldown as Overcut.
static func reset_result(left: float, full: float) -> Dictionary:
	return {"left": 0.0, "overcut": 0.0 if left > 0.0 else maxf(full, 0.0)}

## Overcut after adding `add` seconds to `have` (capped at `most`; Deep Hold raises it).
static func overcut_after(have: float, add: float, most: float = Balance.OVERCUT_MAX) -> float:
	return clampf(have + maxf(add, 0.0), 0.0, most)

## % more damage a shot deals for `sec` seconds of Overcut (`per`: % a second; Patience
## raises it; `most`: the cap, Deep Hold).
static func overcut_bonus(sec: float, per: float = Balance.OVERCUT_PCT, most: float = Balance.OVERCUT_MAX) -> float:
	return clampf(sec, 0.0, most) * per

## Long Range: % more damage at `dist` metres, `per` % for every LONG_RANGE_STEP past LONG_RANGE_FROM.
static func long_range_pct(dist: float, per: float) -> float:
	if dist <= Balance.LONG_RANGE_FROM:
		return 0.0
	return floorf((dist - Balance.LONG_RANGE_FROM) / Balance.LONG_RANGE_STEP) * maxf(per, 0.0)

## Seconds Pierce takes off Spread for hitting `hits` enemies.
static func pierce_cut(hits: int) -> float:
	if hits <= 0:
		return 0.0
	return minf(Balance.SHARP_PIERCE_CUT_FIRST + float(hits - 1) * Balance.SHARP_PIERCE_CUT_PER, Balance.SHARP_PIERCE_CUT_MAX)

## Streak after using `id`. Loose takes away a `loose_part`-th of it, rounded up (half;
## Easy Release: a third or a quarter).
static func streak_after(streak: int, id: String, loose_part: int = 2, most: int = Balance.STREAK_MAX) -> int:
	if id == LOOSE_ID:
		var part := maxi(loose_part, 2)
		return streak - (streak + part - 1) / part
	if Abilities.SHARP_ENGINE.has(id):
		return mini(streak + 1, most)
	return streak

## How much longer cuts are (Fast Hands).
static func cut_mult(fast: bool) -> float:
	return Balance.FAST_HANDS_MULT if fast else 1.0

## Is `point` on Pierce's line: from `from` along `dir` (flat, normalised), `length` long,
## `width` wide, with `pad` (the enemy's hitbox) added?
static func on_line(from: Vector3, dir: Vector3, length: float, width: float, point: Vector3, pad: float = 0.0) -> bool:
	var to := Vector2(point.x - from.x, point.z - from.z)
	var d := Vector2(dir.x, dir.z)
	if d.length() < 0.001:
		return false
	d = d.normalized()
	var along := to.dot(d)
	if along < -pad or along > length + pad:
		return false
	return absf(to.cross(d)) <= width * 0.5 + pad

## The enemies Spread's arrows go to: `foes` (target first) cycled over `arrows`.
static func spread_order(foes: Array, arrows: int) -> Array:
	var out := []
	if foes.is_empty():
		return out
	for i in arrows:
		out.append(foes[i % foes.size()])
	return out

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func streak() -> int:
	return _streak

## Seconds of Overcut on shot `id`.
func overcut_of(id: String) -> float:
	return float(_overcut.get(id, 0.0))

func fast_hands() -> bool:
	return _fast_until > _now()

func breathe_armed() -> bool:
	return _breathe_until > _now()

## Overcut's % a second with my talents (Patience).
func overcut_per() -> float:
	return Balance.OVERCUT_PCT + player._talent("martial_patience")

## Most Overcut one shot holds (+ Deep Hold).
func overcut_max() -> float:
	return Balance.OVERCUT_MAX + player._talent("martial_deep_hold")

## Most Streak I can build (+ Long Streak).
func streak_max() -> int:
	return Balance.STREAK_MAX + int(round(player._talent("martial_long_streak")))

## Spread's arrows with my talents (Extra Arrows).
func spread_arrows() -> int:
	return Balance.SHARP_SPREAD_ARROWS + int(round(player._talent("martial_extra_arrows")))

## Seconds Heavy Draw takes off my other shots (Full Draw's capstone).
func heavy_cut() -> float:
	return Balance.FULL_DRAW_CUT if player.frost_melee._capstone("martial_full_draw") else Balance.SHARP_HEAVY_CUT

## Is the Sharpshooter out (one of its engine shots on my bars)? The HUD shows its strip.
func is_out() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for slot_id in pd.action_bar:
		var id := Macros.link_of(str(slot_id)) if Macros.is_macro(str(slot_id)) else str(slot_id)
		if Abilities.SHARP_ENGINE.has(id) and pd.has_ability(id):
			return true
	return false

## Bar text: the Overcut on an engine shot ("+40%").
func charges_text(id: String) -> String:
	var sec := overcut_of(id)
	return "+%d%%" % int(round(overcut_bonus(sec, overcut_per(), overcut_max()))) if sec > 0.0 and Abilities.SHARP_ENGINE.has(id) else ""

## The seconds shot `src` would take off each shot it feeds if it hit now (no crit):
## {target: seconds} (the HUD's ticks). Heavy Draw's reset shows as the full cooldown.
func cut_preview(src: String) -> Dictionary:
	var out := {}
	var m := cut_mult(fast_hands())
	match src:
		QUICK_SHOT_ID:
			out[PIERCE_ID] = Balance.SHARP_QUICK_CUT * m
		PIERCE_ID:
			out[SPREAD_ID] = pierce_cut(1) * m
		SPREAD_ID:
			out[HEAVY_DRAW_ID] = Balance.SHARP_SPREAD_CUT * float(spread_arrows()) * m
		HEAVY_DRAW_ID:
			for t in Abilities.SHARP_LINKS[HEAVY_DRAW_ID]:
				out[t] = Abilities.cooldown_of(Abilities.get_resource(t)) if t == QUICK_SHOT_ID else heavy_cut() * m
		FOLLOW_UP_ID:
			if _last_engine != "":
				out[_last_engine] = Balance.SHARP_FOLLOW_CUT * float(Balance.SHARP_FOLLOW_HITS) * m
	return out

# --- Using it -------------------------------------------------------------------------

## Why a Sharpshooter ability can't be used right now ("" = it can).
func _sharp_precheck(_id: String) -> String:
	return ""   # (a bow and a target are checked by _use_drafted)

## One of the Sharpshooter's abilities (put on cooldown by _use_drafted).
func _sharp_use(id: String, res: Resource) -> void:
	var foe: Node3D = player.target if player._has_valid_target() else null
	var coef := float(res.damage) * _spend_overcut(id)
	match id:
		QUICK_SHOT_ID, LOOSE_ID:
			if foe:
				_shot(foe, coef, id)
		HEAVY_DRAW_ID:
			if foe:
				_sure_heavy = _streak >= Balance.STREAK_MAX
				_shot(foe, coef, id)
		PIERCE_ID:
			if foe:
				_pierce(foe, coef)
		SPREAD_ID:
			if foe:
				for e in spread_order(_spread_targets(foe), spread_arrows()):   # (+ Extra Arrows)
					_shot(e, coef, id)
		FOLLOW_UP_ID:
			if foe:
				_follow_target = _last_engine
				_shot(foe, coef, id)
				for i in range(1, Balance.SHARP_FOLLOW_HITS):
					player.get_tree().create_timer(Balance.SHARP_FOLLOW_GAP * i).timeout.connect(func():
						if is_instance_valid(foe) and foe.is_alive() and is_instance_valid(player):
							_shot(foe, coef, id))
		BREATHE_ID:
			_breathe_until = _now() + Balance.BREATHE_TIME
			_buff(BREATHE_FX, Abilities.ability_name(id), Balance.BREATHE_TIME, SharpIcons.REFILL,
				"The next time one of your shots brings another back sooner, that shot is ready at once.")
		FAST_HANDS_ID:
			_fast_until = _now() + Balance.FAST_HANDS_TIME
			_buff(FAST_FX, Abilities.ability_name(id), Balance.FAST_HANDS_TIME, SharpIcons.GOLD,
				"Your shots bring each other back %s times as much." % Stats.num(Balance.FAST_HANDS_MULT))
	_used(id)

## Heavy Draw pressed: a bow cast (instant at full Streak).
func _start_heavy_draw() -> void:
	var id := HEAVY_DRAW_ID
	if player.casting:
		return
	if _streak >= Balance.STREAK_MAX:
		player._use_drafted(id)   # instant: the usual checks, cooldown and _sharp_use
		return
	if player.cooldown_left(id) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return
	var w := player._weapon()
	if w.get("weapon", "") != "ranged":
		player._error("Requires a bow")
		return
	if not player._has_valid_target():
		player._error("No target")
		return
	if not player._in_weapon_range(player.target, float(w["attack_range"])):
		player._error("Target out of range")
		return
	var sight_err := player._target_error(player.target)
	if sight_err != "":
		player._error(sight_err)
		return
	player._begin_spell(id, Abilities.ability_name(id), float(Abilities.get_resource(id).cast_time))

## Heavy Draw's arrow leaves the bow (its cast finished).
func _loose_heavy_draw() -> void:
	var res := Abilities.get_resource(HEAVY_DRAW_ID)
	player.cooldowns[HEAVY_DRAW_ID] = Abilities.cooldown_of(res)
	if player._weapon().get("weapon", "") != "ranged":
		player._error("Requires a bow")
		return
	_sharp_use(HEAVY_DRAW_ID, res)

## A shot was used: Streak, and what Follow Up will cut next.
func _used(id: String) -> void:
	if id == BREATHE_ID or id == FAST_HANDS_ID:
		_sync()
		return
	_streak_at = _now()
	_set_streak(streak_after(_streak, id, maxi(int(round(player._talent("martial_easy_release"))), 2), streak_max()))   # (Easy Release, Long Streak)
	if Abilities.SHARP_ENGINE.has(id):
		_last_engine = id
	_sync()

## The damage multiplier of shot `id`'s Overcut; firing it spends it.
func _spend_overcut(id: String) -> float:
	var sec := overcut_of(id)
	if sec <= 0.0:
		return 1.0
	_overcut.erase(id)
	if sec >= Balance.CLEAN_RELEASE_OVERCUT:
		_set_streak(_streak + int(round(player._talent("martial_clean_release"))))   # Clean Release
	return 1.0 + overcut_bonus(sec, overcut_per(), overcut_max()) / 100.0

func _face(at: Vector3) -> void:
	var dir := at - player.global_position
	if Vector2(dir.x, dir.z).length() > 0.01:
		player.rotation.y = atan2(-dir.x, -dir.z)

## An arrow of mine at `foe` (its hit comes back through damage_dealt).
func _shot(foe: Node3D, coef: float, id: String) -> void:
	_face(foe.global_position)
	ARROW.spawn(player.get_tree().current_scene, player._muzzle(), foe, player, coef, id)

## Pierce: every enemy on the line through my target (split past the cap), hit at once;
## one arrow flies the whole line (a picture: the hits are already in).
func _pierce(foe: Node3D, coef: float) -> void:
	var from := player.global_position
	var dir := foe.global_position - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else player._flat_forward()
	var length := float(player._weapon().get("attack_range", 30.0))
	var hit := [foe]
	for e in player._enemies_near(from, length):
		if e != foe and player.can_see(e) and on_line(from, dir, length, Balance.SHARP_PIERCE_WIDTH + player._talent("martial_broadhead"), e.global_position, Combat.hitbox_radius(e)):
			hit.append(e)
	var share := Balance.aoe_share(hit.size())
	_face(foe.global_position)
	_pierce_hits = 0
	var last: Node3D = foe
	for e in hit:
		player.deal_damage(e, coef * share, PIERCE_ID)
		if from.distance_squared_to(e.global_position) > from.distance_squared_to(last.global_position):
			last = e
	if player.is_inside_tree():
		ARROW.spawn(player.get_tree().current_scene, player._muzzle(), last, null, 0.0, PIERCE_ID)
		player._net_fx("arrow", player._muzzle(), last)

## Spread's enemies: my target, then the closest others in front of me in range.
func _spread_targets(foe: Node3D) -> Array:
	var out: Array = [foe]
	var fwd := foe.global_position - player.global_position
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else player._flat_forward()
	var reach := float(player._weapon().get("attack_range", 30.0))
	for e in player._enemies_near(player.global_position, reach):
		if out.size() >= spread_arrows():
			break
		if out.has(e) or not player.can_see(e):
			continue
		if WheelKit.in_arc(player.global_position, fwd, e.global_position, Balance.SHARP_SPREAD_ARC):
			out.append(e)
	return out

# --- Cuts -----------------------------------------------------------------------------

## SignalBus.damage_dealt: my engine shots' hits bring the shots they feed back sooner.
func _on_damage_dealt_sharp(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or int(info.amount) <= 0:
		return
	if bool(info.is_dot) or bool(info.is_proc):
		return
	var id := str(info.ability_id)
	if not Abilities.SHARP_ENGINE.has(id):
		return
	var crit := bool(info.crit)
	match id:
		QUICK_SHOT_ID:
			_cut(PIERCE_ID, Balance.SHARP_QUICK_CUT, crit)
		PIERCE_ID:
			_pierce_hits += 1
			_cut(SPREAD_ID, pierce_cut(_pierce_hits) - pierce_cut(_pierce_hits - 1), crit)
		SPREAD_ID:
			_cut(HEAVY_DRAW_ID, Balance.SHARP_SPREAD_CUT, crit)
		HEAVY_DRAW_ID:
			_sure_heavy = false
			_cut(QUICK_SHOT_ID, 0.0, true)
			for t in Abilities.SHARP_LINKS[HEAVY_DRAW_ID]:
				if t != QUICK_SHOT_ID:
					_cut(str(t), heavy_cut(), crit)
		FOLLOW_UP_ID:
			if _follow_target != "":
				_cut(_follow_target, Balance.SHARP_FOLLOW_CUT, crit)
	var lucky := player._talent("martial_lucky_shot")
	if crit and lucky > 0.0:
		for t in Abilities.SHARP_ENGINE:
			if t != id:
				_cut(str(t), lucky, false, false)   # Lucky Shot (it doesn't spend Breathe)
	var second := player._talent("martial_second_arrow")
	if second > 0.0 and info.target != null and is_instance_valid(info.target) and randf() * 100.0 < second:
		player.deal_damage(info.target, float(info.base) * Balance.SECOND_ARROW_PCT / 100.0, SECOND_ARROW_ID, true,
			"physical", PackedStringArray(info.tags))   # Second Arrow (a proc: it feeds nothing)
	_sync()

## Hard Target: is `e` above HARD_TARGET_HEALTH % health?
static func hard_target(e: Object) -> bool:
	var hp: Variant = e.get("health")
	var most: Variant = e.get("max_health")
	if hp == null or most == null or float(most) <= 0.0:
		return false
	return float(hp) / float(most) * 100.0 > Balance.HARD_TARGET_HEALTH

## Bring shot `id` back `sec` seconds sooner (`reset`: at once). Past ready, it's Overcut.
## An armed Breathe makes this cut a reset. Shots I haven't learned aren't touched.
func _cut(id: String, sec: float, reset: bool, use_breathe: bool = true) -> void:
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd and not pd.has_ability(id):
		return
	if not reset and use_breathe and breathe_armed():
		reset = true
		_breathe_until = 0.0
		if player.status:
			player.status.remove(BREATHE_FX)
	var left := float(player.cooldowns.get(id, 0.0))
	var longer := 1.0 + player._talent("martial_quick_release") / 100.0   # Quick Release
	var r := reset_result(left, Abilities.cooldown_of(Abilities.get_resource(id))) if reset \
		else cut_result(left, sec * cut_mult(fast_hands()) * longer)
	if reset and use_breathe and randf() * 100.0 < player._talent("martial_run_it_back"):
		var nxt: Array = Abilities.SHARP_LINKS.get(id, [])
		if not nxt.is_empty():
			_cut(str(nxt[0]), Balance.RUN_IT_BACK_CUT, false, false)   # Run It Back
	if float(r["left"]) <= 0.0:
		player.cooldowns.erase(id)
	else:
		player.cooldowns[id] = float(r["left"])
	if float(r["overcut"]) > 0.0:
		_overcut[id] = overcut_after(overcut_of(id), float(r["overcut"]), overcut_max())

## A Heavy Draw at full Streak is a sure crit (Player.adjust_crit); Keen Eye: my shots crit more.
func adjust_crit(info: RefCounted, chance: float) -> float:
	var id := str(info.ability_id)
	if Abilities.SHARP_ENGINE.has(id) or id == LOOSE_ID:
		chance += player._talent("martial_keen_eye")
	if not _sure_heavy or info.is_dot or info.is_proc or id != HEAVY_DRAW_ID:
		return chance
	return chance + 100.0

## SignalBus.damage_modify: my Streak makes my hits harder (+ On a Roll); my shots get
## Long Range, Hard Target and Hold Steady.
func _on_damage_modify(info: RefCounted) -> void:
	if info.source != player:
		return
	if _streak > 0:
		info.add_bonus((Balance.STREAK_PCT + player._talent("martial_on_a_roll")) * float(_streak), "Streak")
	var id := str(info.ability_id)
	if not (Abilities.SHARP_ENGINE.has(id) or id == LOOSE_ID) or bool(info.is_dot):
		return
	var tgt: Variant = info.target
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node3D):
		return
	var far := long_range_pct(player.global_position.distance_to((tgt as Node3D).global_position), player._talent("martial_long_range"))
	if far > 0.0:
		info.add_bonus(far, "Long Range")
	var hard := player._talent("martial_hard_target")
	if hard > 0.0 and hard_target(tgt):
		info.add_bonus(hard, "Hard Target")
	var steady := player._talent("martial_hold_steady")
	if steady > 0.0:
		for other in _overcut:
			if str(other) != id and float(_overcut[other]) >= Balance.HOLD_STEADY_OVERCUT:
				info.add_bonus(steady, "Hold Steady")
				break

# --- Streak ---------------------------------------------------------------------------

func _set_streak(n: int) -> void:
	_streak = clampi(n, 0, streak_max())
	if player.status == null:
		return
	if _streak <= 0:
		player.status.remove(STREAK_FX)
		return
	if not player.status.has(STREAK_FX):
		var fx := StatusContainer.make_buff(STREAK_FX, "Streak", STREAK_FX, 0.0, 3600.0, Balance.STREAK_MAX + 2, SharpIcons.GOLD)   # (+2: Long Streak)
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Physical"])
		fx.description = "You deal %s%% more damage per stack. Loose halves it." % Stats.num(Balance.STREAK_PCT)
		player.status.apply(fx, player)
	if player.status.stacks_of(STREAK_FX) != _streak:
		player.status.set_stacks(STREAK_FX, _streak)

func _buff(fx_id: String, title: String, time: float, col: Color, text: String) -> void:
	if player.status == null:
		return
	var fx := StatusContainer.make_buff(fx_id, title, fx_id, 0.0, time, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical"])
	fx.description = text
	player.status.apply(fx, player)
	player.status.set_remaining(fx_id, time)

# --- Every frame ----------------------------------------------------------------------

func _tick_sharp(_delta: float) -> void:
	var now := _now()
	var fighting: bool = player.is_in_combat()
	if player.is_dead() or (_was_in_combat and not fighting):
		_overcut.clear()   # (no carrying a charged shot into the next pull)
		_last_engine = ""
		if _streak > 0:
			_set_streak(0)
	_was_in_combat = fighting
	if _streak > 0 and now - _streak_at > Balance.STREAK_HOLD + player._talent("martial_no_letup"):   # + No Letup
		_set_streak(0)
	_waiting_game(_delta, fighting)
	_sync()
	if now - _told >= TELL_EVERY and _shown != "":
		_tell()

## Waiting Game: a shot that stays ready in a fight gains Overcut every WAITING_GAME_TIME.
func _waiting_game(delta: float, fighting: bool) -> void:
	var add := player._talent("martial_waiting_game")
	if add <= 0.0 or not fighting or player.is_dead() or not is_out():
		_ready_for.clear()
		return
	var pd := player.get_node_or_null("/root/PlayerData")
	for id in Abilities.SHARP_ENGINE:
		if (pd and not pd.has_ability(id)) or float(player.cooldowns.get(id, 0.0)) > 0.0:
			_ready_for.erase(id)
			continue
		var t := float(_ready_for.get(id, 0.0)) + delta
		if t >= Balance.WAITING_GAME_TIME:
			t -= Balance.WAITING_GAME_TIME
			_overcut[id] = overcut_after(overcut_of(id), add, overcut_max())
		_ready_for[id] = t

## What the party sees: my Streak in the quiver, and a gold bowstring while a held shot
## has a lot of Overcut. Told when it changes.
func _gold() -> bool:
	for id in _overcut:
		if float(_overcut[id]) >= GOLD_AT:
			return true
	return false

func _sync() -> void:
	var want := "%d|%s" % [_streak, str(_gold())] if (_streak > 0 or _gold()) and not player.is_dead() else ""
	if want == _shown:
		return
	_shown = want
	if player.is_inside_tree():
		SharpFx.show_streak(player, _streak if want != "" else 0, streak_max(), _gold() and want != "")
	_tell()

func _tell() -> void:
	_told = _now()
	player._net_fx("sharpshooter", player.global_position, null, {"s": _streak if _shown != "" else 0, "g": _gold() and _shown != ""})
