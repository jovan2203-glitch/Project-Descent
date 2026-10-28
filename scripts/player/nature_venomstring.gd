extends "res://scripts/player/player_kit.gd"
class_name VenomstringKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "venomstring".
# --- Nature archer: Venomstring --------------------------------------------------------------
# Three poison arrows (Adder, Asp, Krait), each a poison of my own on the enemy
# (my tick list here, like Choking Vipers: own only, hasted, crits). While all
# three are on enemies somewhere I have Venom Flow and every tick gives Venom
# (a bar of my own, not a resource of the action bar: the HUD's Venom bar (scripts/ui/hud/venom_bar.gd) shows it
# while the three arrows are on the bars). Two different poisons on one
# enemy make all of mine on it stronger; all three (Steeped) more. Venom pays for
# Venom Burst (the target explodes with what its poisons have left), Spitting
# Volley (Adder Venom all around the target) and Bloat Arrow (copies its poisons
# to the enemies near it). A poisoned enemy that dies passes my poisons on to
# the nearest enemy. Fang Arrow is the filler (my poisons on it last longer),
# Coil Back the escape (a thorn trap), Venom Surge the big cooldown.
# The arrows look like any arrow with a woven snake coiled around the shaft
# (arrow.gd); nothing of it sits on the enemies. Numbers: balance.gd (VENOM_*,
# POISON_*, ADDER_*, ...). Talents: Lingering Venom (Venom Burst), Long Fangs
# (Fang Arrow), Hungry Venom and Fresh Host (poisons jumping on a death), Spring
# Trap (Coil Back's trap), Soaked Through (Steeped), Double Dose (two poisons),
# Slow Acting and Quick Venom (the poisons' time and ticks), First Bite (the first
# poison on an enemy), Swollen (copied poisons), Full Glands and Spare Venom
# (Venom), Dripping Tips (auto-shots). Their hit bonuses (Virulent, Final Bite,
# Running Venom, Dragging Feet, Full Brew): nature_talents_open.gd.

const FANG_ARROW_ID := "fangarrow"
const ADDER_ARROW_ID := "adderarrow"
const ASP_ARROW_ID := "asparrow"
const KRAIT_ARROW_ID := "kraitarrow"
const VENOM_BURST_ID := "venomburst"
const SPITTING_VOLLEY_ID := "spittingvolley"
const BLOAT_ARROW_ID := "bloatarrow"
const COIL_BACK_ID := "coilback"
const VENOM_SURGE_ID := "venomsurge"
## The instants of the kit (_use_drafted -> _venom_use). Adder Arrow is a bow cast.
const VENOM_INSTANTS := [FANG_ARROW_ID, ASP_ARROW_ID, KRAIT_ARROW_ID, VENOM_BURST_ID, SPITTING_VOLLEY_ID,
	BLOAT_ARROW_ID, COIL_BACK_ID, VENOM_SURGE_ID]
## The arrows that carry a poison: they put it on, they don't hit (deal_damage -> _poison_landed).
const POISON_ARROWS := [ADDER_ARROW_ID, ASP_ARROW_ID, KRAIT_ARROW_ID]
## Each poison: the arrow it comes from (its meter line) and its colour.
const POISON_OF := {ADDER_ARROW_ID: "adder", ASP_ARROW_ID: "asp", KRAIT_ARROW_ID: "krait"}
const POISON_COLORS := {"adder": Color(0.4, 0.95, 0.3), "asp": Color(1.0, 0.85, 0.25), "krait": Color(0.92, 0.95, 1.0)}
const VENOM_BURST_SPLASH_ID := "venomburst_splash"   # its own meter line (Details.HIT_NAMES)
const POISON_TAGS := ["Ability", "Nature", "DoT"]
const VENOM_FLOW_FX := "venom_flow"
const VENOM_SURGE_FX := "venom_surge"
const ASP_VENOM_FX := preload("res://data/effects/asp_venom.tres")
const COILED_FX := preload("res://data/effects/coiled.tres")

var _venom := 0.0
var _poisons := []      # [{"target", "pos", "kind", "coef", "until", "next"}]: my poisons on enemies
var _bloats := []       # [{"target", "pos", "at"}]: Bloat Arrows about to burst
var _coil_traps := []   # [{"pos", "until"}]
var _venom_flow_fx: Resource = null

# Rules as static functions (tests/test_nature.gd).

## The poison `kind`'s whole damage (coefficient) over POISON_TIME.
static func poison_total(kind: String) -> float:
	match kind:
		"adder":
			return Balance.ADDER_DAMAGE
		"asp":
			return Balance.ASP_DAMAGE
		"krait":
			return Balance.KRAIT_DAMAGE
	return 0.0

## How much more my poisons on an enemy deal, with `kinds` different ones of mine on it.
## (`soaked`: Soaked Through, % more on Steeped; `double`: Double Dose, % more with two.)
static func poison_mult(kinds: int, soaked: float = 0.0, double: float = 0.0) -> float:
	if kinds >= 3:
		return 1.0 + (Balance.STEEPED_PCT + maxf(soaked, 0.0)) / 100.0
	if kinds == 2:
		return 1.0 + (Balance.TWO_POISONS_PCT + maxf(double, 0.0)) / 100.0
	return 1.0

## Venom one tick of my poisons gives during Venom Flow (`glands`: Full Glands;
## `steeped_extra`: Soaked Through's capstone, on a Steeped enemy).
static func venom_per_tick(glands: float, steeped_extra: float) -> float:
	return Balance.VENOM_PER_TICK + maxf(glands, 0.0) + maxf(steeped_extra, 0.0)

## Seconds a poison lasts when it goes on (`slow`: Slow Acting's).
static func poison_life(slow: float) -> float:
	return Balance.POISON_TIME + maxf(slow, 0.0)

## Venom Flow: all three kinds among `kinds` (or Venom Surge).
static func venom_flowing(kinds: Array, surge: bool) -> bool:
	return surge or (kinds.has("adder") and kinds.has("asp") and kinds.has("krait"))

## Venom Burst's damage from `left` (the damage the poisons on the target have left)
## with `kinds` different poisons (`more_pct`: Lingering Venom).
static func burst_damage(left: float, kinds: int, more_pct: float) -> float:
	return maxf(left, 0.0) * (1.0 + Balance.BURST_PER_POISON / 100.0 * float(maxi(kinds, 0))) * (1.0 + more_pct / 100.0)

## Seconds between two ticks of a poison (`krait`: my Krait Venom is on that enemy and
## this isn't it; `quick`: Quick Venom, % more often).
static func poison_every(haste: float, krait: bool, quick: float = 0.0) -> float:
	return Balance.POISON_TICK / maxf(haste, 0.01) / ((1.0 + Balance.KRAIT_HASTE / 100.0) if krait else 1.0) / (1.0 + maxf(quick, 0.0) / 100.0)

## Index of the nearest of `spots` within `reach` of `from` (-1 = none).
static func nearest_within(from: Vector3, spots: Array, reach: float) -> int:
	var best := -1
	var best_d := INF
	for i in spots.size():
		var s: Vector3 = spots[i]
		var d := Vector2(s.x - from.x, s.z - from.z).length()
		if d <= reach and d < best_d:
			best_d = d
			best = i
	return best

func venom() -> float:
	return _venom

func venom_flow() -> bool:
	return venom_flowing(_kinds_anywhere(), _surging())

## Venom Flow is on right now (it needs a poison of mine somewhere: Running Venom).
func venom_flowing_now() -> bool:
	return not _poisons.is_empty() and venom_flow()

## The multiplier of my poisons on `e` (`kinds` of them there): Soaked Through, Double Dose.
func _poison_mult_on(kinds: int) -> float:
	return poison_mult(kinds, player._talent("nature_soaked_through"), player._talent("nature_double_dose"))

func _surging() -> bool:
	return player.status != null and player.status.has(VENOM_SURGE_FX)

func _gain_venom(n: float) -> void:
	_venom = clampf(_venom + n, 0.0, Balance.VENOM_MAX)

## The kinds of my poisons on `e` (each once).
func poisons_on(e: Node) -> Array:
	var out := []
	for p in _poisons:
		if is_same(p["target"], e) and not out.has(p["kind"]):
			out.append(p["kind"])
	return out

func _kinds_anywhere() -> Array:
	var out := []
	for p in _poisons:
		if is_instance_valid(p["target"]) and not out.has(p["kind"]):
			out.append(p["kind"])
	return out

## My poison `kind` lands on `e`, `strength` times as strong (Spitting Volley's split,
## Venom Surge). A new one replaces mine of that kind there.
func _apply_poison(e: Node, kind: String, strength: float = 1.0, until: float = -1.0) -> void:
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _surging():
		strength *= Balance.SURGE_MULT
	if poisons_on(e).is_empty():
		strength *= 1.0 + player._talent("nature_first_bite") / 100.0   # First Bite: the first of mine on it
	var base_ticks := maxf(Balance.POISON_TIME / Balance.POISON_TICK, 1.0)
	for i in range(_poisons.size() - 1, -1, -1):
		if is_same(_poisons[i]["target"], e) and _poisons[i]["kind"] == kind:
			_poisons.remove_at(i)
	var p := {"target": e, "pos": (e as Node3D).global_position, "kind": kind,
		"coef": poison_total(kind) / base_ticks * strength,
		"until": until if until > now else now + poison_life(player._talent("nature_slow_acting")), "next": 0.0}   # (+ Slow Acting)
	p["next"] = now + _poison_every_for(p)
	_poisons.append(p)
	if kind == "asp":
		player._combat().apply_effect(player, e, ASP_VENOM_FX, ASP_ARROW_ID, PackedStringArray(POISON_TAGS))
	player._ring_effect(0.5, POISON_COLORS[kind], (e as Node3D).global_position)

func _poison_every_for(p: Dictionary) -> float:
	var krait: bool = p["kind"] != "krait" and poisons_on(p["target"]).has("krait")
	return poison_every(player.haste_mult(), krait, player._talent("nature_quick_venom"))   # + Quick Venom

## A poison arrow reached `enemy` (from deal_damage: it carries a poison, not a hit).
func _poison_landed(enemy: Node, id: String, strength: float) -> void:
	_apply_poison(enemy, str(POISON_OF[id]), strength if strength > 0.0 else 1.0)

## Fang Arrow landed: my poisons on the target last longer.
func _fang_landed(enemy: Node) -> void:
	for p in _poisons:
		if is_same(p["target"], enemy):
			p["until"] = float(p["until"]) + Balance.FANG_EXTEND + player._talent("nature_long_fangs")   # + Long Fangs

## Every frame: poison ticks, spreading, Venom Flow, Bloat Arrows, Coil Back's traps.
func _tick_venom(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _poisons.is_empty():
		_tick_poisons(now)
	if not _bloats.is_empty():
		_tick_bloats(now)
	if not _coil_traps.is_empty():
		_tick_coil_traps(now)
	if _venom > 0.0 and not player.is_in_combat():
		_venom = maxf(_venom - Balance.VENOM_DRAIN * delta, 0.0)
	_sync_venom_flow()

func _tick_poisons(now: float) -> void:
	var flowing := venom_flow()
	for i in range(_poisons.size() - 1, -1, -1):
		if i >= _poisons.size():
			continue
		var p: Dictionary = _poisons[i]
		var e: Variant = p["target"]
		if float(p["until"]) <= now:
			_poisons.remove_at(i)
			continue
		if e == null or not is_instance_valid(e) or not e.is_alive():
			_poisons.remove_at(i)
			_spread_poison(p, now)
			continue
		p["pos"] = (e as Node3D).global_position
		if now < float(p["next"]):
			continue
		p["next"] = now + _poison_every_for(p)
		var kinds := poisons_on(e).size()
		var coef := float(p["coef"]) * _poison_mult_on(kinds)   # + Soaked Through, Double Dose
		var id: String = POISON_OF.find_key(p["kind"])
		var info = player._combat().ability_hit_info(player, e, coef, id, true, "nature", PackedStringArray(POISON_TAGS))
		info.is_dot = true
		player._combat().deal(info)
		if flowing:
			var steeped_extra := Balance.SOAKED_THROUGH_VENOM if kinds >= 3 and player.frost_melee._capstone("nature_soaked_through") else 0.0
			_gain_venom(venom_per_tick(player._talent("nature_full_glands"), steeped_extra))   # + Full Glands, Soaked Through's capstone
		player._ring_effect(0.35, POISON_COLORS[p["kind"]], p["pos"])   # a drip

## A poisoned enemy died: the poison `p` jumps to the nearest enemy near it, with its time left.
func _spread_poison(p: Dictionary, now: float) -> void:
	var reach := maxf(Balance.POISON_SPREAD, player._talent("nature_hungry_venom"))   # Hungry Venom: further
	var foes := player._enemies_near(p["pos"], reach)
	var spots: Array = foes.map(func(f): return (f as Node3D).global_position)
	var i := nearest_within(p["pos"], spots, reach)
	if i < 0 or float(p["until"]) <= now:
		return
	_copy_poison(p, foes[i], player._talent("nature_hungry_venom", "values2"), 0.0, player._talent("nature_fresh_host"))   # (+ Fresh Host)

## Hungry Venom: a jumping poison's damage (coefficient per tick) with `pct` % more,
## once (`jumped`: it already got it on an earlier jump).
static func hungry_coef(coef: float, pct: float, jumped: bool) -> float:
	return coef if jumped or pct <= 0.0 else coef * (1.0 + pct / 100.0)

## The Venom Flow buff on me while it flows.
func _sync_venom_flow() -> void:
	if player.status == null:
		return
	var on := not _poisons.is_empty() and venom_flow()
	if on == player.status.has(VENOM_FLOW_FX):
		return
	if not on:
		player.status.remove(VENOM_FLOW_FX)
		return
	if _venom_flow_fx == null:
		_venom_flow_fx = StatusContainer.make_buff(VENOM_FLOW_FX, "Venom Flow", VENOM_FLOW_FX, 0.0, 3600.0, 1, POISON_COLORS["adder"])
		_venom_flow_fx.stat_modifiers = {}
		_venom_flow_fx.show_time = false
		_venom_flow_fx.tags = PackedStringArray(["Nature"])
		_venom_flow_fx.description = "All three of your poisons are on enemies: their ticks fill your Venom."
	player.status.apply(_venom_flow_fx, player)

## Venom an ability costs right now.
func venom_cost(id: String) -> float:
	match id:
		VENOM_BURST_ID:
			return Balance.VENOM_BURST_COST
		SPITTING_VOLLEY_ID:
			return 0.0 if _surging() else Balance.VOLLEY_VENOM_COST
		BLOAT_ARROW_ID:
			return Balance.BLOAT_COST
	return 0.0

## Why a Venomstring ability can't be used right now ("" = it can).
func _venom_precheck(id: String) -> String:
	if _venom < venom_cost(id):
		return "Not enough Venom"
	if (id == VENOM_BURST_ID or id == BLOAT_ARROW_ID) and (not player._has_valid_target() or poisons_on(player.target).is_empty()):
		return "Your target has none of your poisons"
	return ""

## One of the kit's instants (put on cooldown by _use_drafted; Venom is paid here).
func _venom_use(id: String, res: Resource, w: Dictionary) -> void:
	var spent := venom_cost(id)
	_venom -= spent
	if spent > 0.0 and WeaverKit.rolls(player._talent("nature_spare_venom"), randf() * 100.0):
		_gain_venom(spent / 2.0)   # Spare Venom: half of it back
	match id:
		FANG_ARROW_ID:
			if player._has_valid_target():
				ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, player._weapon_hit(w, res), id)
				_fang_ready()
		ASP_ARROW_ID, KRAIT_ARROW_ID:
			if player._has_valid_target():
				ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, 1.0, id)
		VENOM_BURST_ID:
			_venom_burst(player.target)
		SPITTING_VOLLEY_ID:
			_spitting_volley(player.target)
		BLOAT_ARROW_ID:
			ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, null, 0.0, BLOAT_ARROW_ID)   # (only a picture: the burst does the work)
			_bloats.append({"target": player.target, "pos": player.target.global_position, "at": Time.get_ticks_msec() / 1000.0 + Balance.BLOAT_DELAY})
			player._ring_effect(1.0, POISON_COLORS["adder"], player.target.global_position)
		COIL_BACK_ID:
			_coil_back()
		ADDER_ARROW_ID:
			player.status.remove(FANG_READY_FX)   # (only reached with Fang Arrow's buff: an instant Adder Arrow)
			_loose_adder_arrow()
		VENOM_SURGE_ID:
			var fx := StatusContainer.make_buff(VENOM_SURGE_FX, Abilities.ability_name(id), VENOM_SURGE_FX, 0.0, Balance.SURGE_TIME, 1, POISON_COLORS["adder"])
			fx.stat_modifiers = {}
			fx.tags = PackedStringArray(["Nature"])
			fx.description = "Your poisons go on at double strength, Venom Flow stays on, and Spitting Volley costs no Venom."
			player.status.apply(fx, player)
			player._ring_effect(1.6, POISON_COLORS["adder"])

# Adder Arrow: a bow cast like Refracting Shot (Fang Arrow makes the next one instant).

const FANG_READY_FX := "fang_ready"

func _fang_ready() -> void:
	var fx := StatusContainer.make_buff(FANG_READY_FX, "Fang", FANG_READY_FX, 0.0, Balance.POISON_TIME, 1, POISON_COLORS["adder"])
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature"])
	fx.description = "Your next Adder Arrow is instant."
	player.status.apply(fx, player)

func _start_adder_arrow() -> void:
	var id := ADDER_ARROW_ID
	if player.casting:
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
	if player.status != null and player.status.has(FANG_READY_FX):
		player._use_drafted(id)   # Fang Arrow: this one is instant
		return
	player._begin_spell(id, Abilities.ability_name(id), float(Abilities.get_resource(id).cast_time))

## Adder Arrow's arrow leaves the bow.
func _loose_adder_arrow() -> void:
	if player._weapon().get("weapon", "") != "ranged" or not player._has_valid_target():
		return
	var dir := player.target.global_position - player.global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, 1.0, ADDER_ARROW_ID)

## Venom Burst: `foe` explodes with what my poisons on it have left.
func _venom_burst(foe: Node3D) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var kinds := poisons_on(foe)
	var steeped := kinds.size() >= 3
	var left := 0.0
	var keep := player.frost_melee._capstone("nature_lingering_venom")
	for i in range(_poisons.size() - 1, -1, -1):
		var p: Dictionary = _poisons[i]
		if not is_same(p["target"], foe):
			continue
		var every := _poison_every_for(p)
		left += float(p["coef"]) * _poison_mult_on(kinds.size()) * maxf(float(p["until"]) - now, 0.0) / every
		if keep and randf() * 100.0 < Balance.LINGERING_VENOM_KEEP:
			continue   # Lingering Venom's capstone: this one stays
		_poisons.remove_at(i)
	var total := burst_damage(left, kinds.size(), player._talent("nature_lingering_venom"))   # + Lingering Venom
	player.deal_damage(foe, total, VENOM_BURST_ID)
	var near := player._enemies_near(foe.global_position, Balance.BURST_RADIUS, foe)
	var share := Balance.aoe_share(near.size())
	for e in near:
		player.deal_damage(e, total * Balance.BURST_SPLASH_PCT / 100.0 * share, VENOM_BURST_SPLASH_ID, true, "nature", PackedStringArray(POISON_TAGS))
	if steeped:
		_gain_venom(Balance.BURST_STEEPED_REFUND)
	player._ring_effect(Balance.BURST_RADIUS, POISON_COLORS["adder"], foe.global_position)
	player._ring_effect(Balance.BURST_RADIUS * 0.5, Color(0.75, 1.0, 0.5), foe.global_position)
	player._ring_effect(1.2, Color(1, 1, 1), foe.global_position)

## Spitting Volley: arrows rain around `foe`, Adder Venom on every enemy there (split past the AoE cap).
func _spitting_volley(foe: Node3D) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var foes := player._enemies_near(foe.global_position, Balance.SPIT_RADIUS)
	var share := Balance.aoe_share(foes.size())
	for e in foes:
		ARROW.spawn(player.get_tree().current_scene, player._muzzle(), e, player, share, ADDER_ARROW_ID)
	player._ring_effect(Balance.SPIT_RADIUS, POISON_COLORS["adder"], foe.global_position)

func _tick_bloats(now: float) -> void:
	for i in range(_bloats.size() - 1, -1, -1):
		var b: Dictionary = _bloats[i]
		var e: Variant = b["target"]
		if e != null and is_instance_valid(e):
			b["pos"] = (e as Node3D).global_position
		if now < float(b["at"]):
			continue
		_bloats.remove_at(i)
		_bloat_burst(e, b["pos"], now)

## A Bloat Arrow's target bursts: my poisons on it are copied to the enemies around it.
func _bloat_burst(e: Variant, at: Vector3, now: float) -> void:
	var mine := []
	for p in _poisons:
		if is_same(p["target"], e):
			mine.append(p)
	for f in player._enemies_near(at, Balance.BLOAT_RADIUS):
		if is_same(f, e):
			continue
		for p in mine:
			_copy_poison(p, f, 0.0, player._talent("nature_swollen"))   # (+ Swollen)
	player._ring_effect(Balance.BLOAT_RADIUS, POISON_COLORS["adder"], at)
	player._ring_effect(Balance.BLOAT_RADIUS * 0.4, POISON_COLORS["asp"], at)

## My poison `p` (its strength and time left) also on `to`, unless it has a longer
## one of mine of that kind. `hungry_pct`: Hungry Venom, on a jump; `swollen_pct`:
## Swollen, on a copy; `fresh`: Fresh Host's seconds, on a jump.
func _copy_poison(p: Dictionary, to: Node, hungry_pct: float = 0.0, swollen_pct: float = 0.0, fresh: float = 0.0) -> void:
	for q in _poisons:
		if is_same(q["target"], to) and q["kind"] == p["kind"] and float(q["until"]) >= float(p["until"]):
			return
	for j in range(_poisons.size() - 1, -1, -1):
		if is_same(_poisons[j]["target"], to) and _poisons[j]["kind"] == p["kind"]:
			_poisons.remove_at(j)
	var c := p.duplicate()
	if hungry_pct > 0.0:
		c["coef"] = hungry_coef(float(p["coef"]), hungry_pct, bool(p.get("jumped", false)))
		c["jumped"] = true
	if swollen_pct > 0.0:
		c["coef"] = float(c["coef"]) * (1.0 + swollen_pct / 100.0)
	if fresh > 0.0:
		c["until"] = float(c["until"]) + fresh
	c["target"] = to
	c["pos"] = (to as Node3D).global_position
	_poisons.append(c)
	if c["kind"] == "asp":
		player._combat().apply_effect(player, to, ASP_VENOM_FX, ASP_ARROW_ID, PackedStringArray(POISON_TAGS))
	player._ring_effect(0.6, POISON_COLORS[c["kind"]], c["pos"])

## Coil Back: I leap back and leave a thorn trap where I stood.
func _coil_back() -> void:
	var from := player.global_position
	var back := -player._flat_forward()
	player.global_position += back * player._dash_distance(Balance.COIL_BACK_DISTANCE, back)
	_coil_traps.append({"pos": from, "until": Time.get_ticks_msec() / 1000.0 + Balance.COIL_TRAP_TIME})
	player.weaver._creature("roots", Vector3(from.x, Combat.feet_y(player), from.z), from)
	player._ring_effect(Balance.COIL_TRAP_RADIUS, POISON_COLORS["asp"], from)

## An auto-shot of mine landed on `tgt` (Player._on_hit_talents). Dripping Tips: it
## may make my poisons on it last longer.
func dripping_tips(tgt: Node) -> void:
	if not WeaverKit.rolls(player._talent("nature_dripping_tips"), randf() * 100.0):
		return
	for p in _poisons:
		if is_same(p["target"], tgt):
			p["until"] = float(p["until"]) + Balance.DRIPPING_TIPS_TIME

func _tick_coil_traps(now: float) -> void:
	for i in range(_coil_traps.size() - 1, -1, -1):
		var t: Dictionary = _coil_traps[i]
		if float(t["until"]) <= now:
			_coil_traps.remove_at(i)
			continue
		var near := player._enemies_near(t["pos"], Balance.COIL_TRAP_RADIUS)
		if near.is_empty():
			continue
		_coil_traps.remove_at(i)
		# Spring Trap: it catches more than one of the enemies there.
		for e in near.slice(0, maxi(int(round(player._talent("nature_spring_trap"))), 1)):
			player.weaver._creature("viper", Vector3(e.global_position.x, Combat.feet_y(e), e.global_position.z), e.global_position)
			player._combat().apply_effect(player, e, COILED_FX, COIL_BACK_ID, PackedStringArray(POISON_TAGS))
			player.nature_open.firm_hold_fury()   # Firm Hold: a hold of mine went on
			_apply_poison(e, "asp")

func tracker_values() -> Dictionary:
	return {"venom": {"value": _venom, "max": Balance.VENOM_MAX}}
