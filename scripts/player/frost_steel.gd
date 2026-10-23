extends "res://scripts/player/player_kit.gd"
class_name FrostSteelKit

# Hooked up from player.gd through its var "frost_steel".
# --- Frost DPS: Frostbitten Steel (a two-handed melee weapon, Fury) ----------------------
# Chill, Freeze, break. Glaze (a buff on me, up to GLAZE_MAX) is built by my Frost
# hits on a target I had already Chilled or Frozen: Winter's Bite (frost_runes.
# _winters_bite calls _bite_landed), Hoarcleave, Bitter Edge and Rime Edge's extra
# hit (frost_more). The finishers spend all of it: Icebreaker (frost_more.
# _icebreaker) and Calving. Bitter Edge only cuts a target I have Frozen and
# Freezes it again; Black Frost makes every Winter's Bite Freeze.
# "Chilled or Frozen by me" is read BEFORE the hit (its own Chill doesn't count).
# Numbers: balance.gd (GLAZE_*, WINTERS_BITE_GLAZE, HOARCLEAVE_*, RIME_EDGE_GLAZE_CHANCE,
# ICEBREAKER_PCT_PER_GLAZE, BITTER_EDGE_GLAZE, CALVING_*, BLACK_FROST_TIME). Talents:
# Cold Sweep (Hoarcleave), Ice Fall (Calving), Biting Hold (Bitter Edge), Long Dark
# (Black Frost), Long Glaze and Glinting Rime (Glaze itself). Runes: the Hoar Blade
# (auto-attacks at full Glaze) and the Lone Floe (Calving on one target).

const HOARCLEAVE_ID := "hoarcleave"
const CALVING_ID := "calving"
const BITTER_EDGE_ID := "bitteredge"
const BLACK_FROST_ID := "blackfrost"
const STEEL_IDS := [HOARCLEAVE_ID, CALVING_ID, BITTER_EDGE_ID, BLACK_FROST_ID]
## The ones with a rule of their own about when they can be used (_steel_precheck).
const STEEL_PRECHECKS := [CALVING_ID, BITTER_EDGE_ID]
const GLAZE_FX := "glaze"
const BLACK_FROST_FX := "black_frost"
const HOAR_BLADE_RUNE := "hoar_blade"
const HOAR_BLADE_ID := "hoar_blade"   # its hit (own meter line: Details.HIT_NAMES)
const LONE_FLOE_RUNE := "lone_floe"
const GLAZE_COLOR := Color(0.78, 0.95, 1.0)
const FROST_MELEE_TAGS := ["Ability", "Frost", "Melee"]

var _glaze_fx: Resource
var _spending := 0   # Glaze the finisher being dealt right now spent (Glinting Rime reads it)

# Rules as static functions (tests/test_frost_melee.gd).

## `have` Glaze and `more`: never past GLAZE_MAX.
static func glaze_after(have: int, more: int) -> int:
	return clampi(have + maxi(more, 0), 0, Balance.GLAZE_MAX)

## A finisher's damage multiplier for `glaze` spent at `pct` % each.
static func glaze_mult(glaze: int, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 * clampi(glaze, 0, Balance.GLAZE_MAX)

## Glaze a Hoarcleave gives when `cold` of the enemies it hit were already Chilled or Frozen by me.
static func hoarcleave_glaze(cold: int) -> int:
	return clampi(cold * Balance.HOARCLEAVE_GLAZE, 0, Balance.HOARCLEAVE_MAX_GLAZE)

## Ice Fall: Calving's multiplier on its target when it hits `others` other enemies (`pct` % each).
static func ice_fall_mult(others: int, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 * clampi(others, 0, Balance.ICE_FALL_MAX_OTHERS)

## Glinting Rime: % crit chance my Frost abilities get from `glaze` (`per`: % each).
static func glinting_crit(glaze: int, per: float) -> float:
	return maxf(per, 0.0) * clampi(glaze, 0, Balance.GLAZE_MAX)

## How much Glaze I have.
func glaze() -> int:
	return player.status.stacks_of(GLAZE_FX) if player.status != null else 0

func black_frost_on() -> bool:
	return player.status != null and player.status.has(BLACK_FROST_FX)

## Is `foe` Chilled or Frozen by me (my own application, not an ally's)?
func cold_on(foe: Variant) -> bool:
	if foe == null or not is_instance_valid(foe) or not (foe is Node):
		return false
	var st: Node = foe.get_node_or_null("Status")
	return st != null and (st.has_from("chilled", player) or st.has_from("frozen", player))

## Gain `more` Glaze; its time starts over (Long Glaze: longer; Glaze Hunger: maybe one more).
func _gain_glaze(more: int) -> void:
	if player.status == null or more <= 0 or player.is_dead():
		return
	if randf() * 100.0 < player._talent("frost_glaze_hunger"):
		more += 1
	var want := glaze_after(glaze(), more)
	# Quick Rime: each stack is a little attack speed (the effect is rebuilt when its rank changes).
	var quick := player._talent("frost_quick_rime")
	if _glaze_fx == null or not is_equal_approx(float(_glaze_fx.stat_modifiers.get(LightningTankKit.ATTACK_SPEED, 0.0)), quick):
		_glaze_fx = StatusContainer.make_buff(GLAZE_FX, "Glaze", GLAZE_FX, 0.0, Balance.GLAZE_TIME, Balance.GLAZE_MAX, GLAZE_COLOR)
		_glaze_fx.stat_modifiers = {LightningTankKit.ATTACK_SPEED: quick} if quick > 0.0 else {}
		_glaze_fx.tags = PackedStringArray(["Frost"])
		_glaze_fx.description = "Rime on your blade. Icebreaker and Calving spend all of it for more damage."
	if not player.status.apply(_glaze_fx, player):
		return
	if player.status.stacks_of(GLAZE_FX) != want:
		player.status.set_stacks(GLAZE_FX, want)
	player.status.set_remaining(GLAZE_FX, Balance.GLAZE_TIME + player._talent("frost_long_glaze"))   # + Long Glaze

## A finisher uses up all my Glaze. Returns how much there was (Hard Glaze: Fury for
## each; Thaw Strike's cheaper finisher is spent).
func _spend_glaze() -> int:
	var n := glaze()
	if n > 0:
		player.status.remove(GLAZE_FX)
		player._gain("fury", player._talent("frost_hard_glaze") * n)
	player.frost_talents._finisher_used()
	return n

## After a finisher that spent `spent` Glaze landed on `foe` (`was_frozen`: I had it
## Frozen before the blow): Clean Break gives Fury back, Frost Heave may Freeze it.
func _finisher_landed(foe: Variant, spent: int, was_frozen: bool) -> void:
	if was_frozen:
		var back := player._talent("frost_clean_break")
		if back > 0.0:
			player._gain("fury", back)
	if spent >= Balance.GLAZE_MAX and foe != null and is_instance_valid(foe) and foe.is_alive() \
			and randf() * 100.0 < player._talent("frost_frost_heave"):
		player.frost_runes._apply_freeze(foe, PackedStringArray(FROST_MELEE_TAGS))

## Winter's Bite landed (frost_runes._winters_bite): Glaze if the target was already cold.
func _bite_landed(was_cold: bool) -> void:
	if was_cold:
		_gain_glaze(Balance.WINTERS_BITE_GLAZE)

## Rime Edge's extra hit (frost_more._rime_edge_on_hit), on a target that was already Chilled.
func _rime_edge_glaze(was_cold: bool) -> void:
	if was_cold and randf() * 100.0 < Balance.RIME_EDGE_GLAZE_CHANCE:
		_gain_glaze(Balance.RIME_EDGE_GLAZE)

## Why a Frostbitten Steel ability can't be used right now ("" = it can).
func _steel_precheck(id: String) -> String:
	match id:
		CALVING_ID:
			if glaze() <= 0:
				return "You have no Glaze"
		BITTER_EDGE_ID:
			if not player._has_valid_target():
				return "No target"
			var st: Node = player.target.get_node_or_null("Status")
			if st == null or not st.has_from("frozen", player):
				return "The target is not Frozen by you"
	return ""

## One of Frostbitten Steel's abilities (paid for and put on cooldown by _use_drafted).
func _steel_use(id: String, res: Resource, w: Dictionary) -> void:
	match id:
		HOARCLEAVE_ID:
			_hoarcleave(w, res)
		CALVING_ID:
			_calving(w, res)
		BITTER_EDGE_ID:
			_bitter_edge(w, res)
		BLACK_FROST_ID:
			var fx := StatusContainer.make_buff(BLACK_FROST_FX, Abilities.ability_name(BLACK_FROST_ID), BLACK_FROST_FX, 0.0,
				Balance.BLACK_FROST_TIME + player._talent("frost_long_dark"), 1, Abilities.color_of(BLACK_FROST_ID))   # + Long Dark
			fx.stat_modifiers = {}
			fx.description = "Every %s Freezes its target." % Abilities.ability_name("froststrike")
			player.status.apply(fx, player)
			player._ring_effect(1.4, Abilities.color_of(BLACK_FROST_ID))
			player._ring_effect(0.8, Color(0.05, 0.08, 0.16))

## My target and the enemies within `radius` of it (the target first).
func _around_target(radius: float) -> Array:
	if not player._has_valid_target():
		return []
	var foe: Node3D = player.target
	if radius <= 0.0:
		return [foe]
	return [foe] + player._enemies_near(foe.global_position, radius, foe)

## Hoarcleave: the target and the enemies around it, each Chilled (Cold Sweep: an
## enemy I had already Chilled may be Frozen instead); Glaze for the cold ones.
func _hoarcleave(w: Dictionary, res: Resource) -> void:
	var hit := _around_target(Balance.HOARCLEAVE_RADIUS)
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	var sweep := player._talent("frost_cold_sweep")
	var cold := 0
	for e in hit:
		var was_cold := cold_on(e)
		var info = player._combat().ability_hit_info(player, e, coef, HOARCLEAVE_ID)
		if was_cold and sweep > 0.0 and randf() * 100.0 < sweep:
			info.effects = [FrostMeleeKit.FROZEN_FX]   # Cold Sweep: a Freeze instead of its Chill
		player._combat().deal(info)
		if was_cold and not info.avoided():
			cold += 1
	for i in 2:
		player._slash_effect(Abilities.color_of(HOARCLEAVE_ID))
	if not hit.is_empty():
		player._ring_effect(Balance.HOARCLEAVE_RADIUS, Abilities.color_of(HOARCLEAVE_ID), (hit[0] as Node3D).global_position)
	_gain_glaze(hoarcleave_glaze(cold))

## Calving: spends all my Glaze on the target and the enemies around it (Lone Floe:
## on the target alone, harder; Ice Fall: harder on the target for each other one).
func _calving(w: Dictionary, res: Resource) -> void:
	var lone := player.frost_melee._has_rune(LONE_FLOE_RUNE)
	var hit := _around_target(0.0 if lone else Balance.CALVING_RADIUS)
	if hit.is_empty():
		return
	var was_frozen: bool = player.frost_talents.frozen_by_me(hit[0])
	var spent := _spend_glaze()
	var coef := player._weapon_hit(w, res) * glaze_mult(spent, Balance.CALVING_PCT_PER_GLAZE) * Balance.aoe_share(hit.size())
	if lone:
		coef *= 1.0 + Balance.LONE_FLOE_PCT / 100.0
	var at: Vector3 = (hit[0] as Node3D).global_position
	_spending = spent
	for i in hit.size():
		var mult := ice_fall_mult(hit.size() - 1, player._talent("frost_ice_fall")) if i == 0 else 1.0   # + Ice Fall
		player.deal_damage(hit[i], coef * mult, CALVING_ID)
	_spending = 0
	_finisher_landed(hit[0], spent, was_frozen)   # Clean Break, Frost Heave
	player._slash_effect(Abilities.color_of(CALVING_ID))
	player._ring_effect(1.0 if lone else Balance.CALVING_RADIUS, Abilities.color_of(CALVING_ID), at)
	player._ring_effect(0.6, Color(0.95, 0.97, 1.0), at)

## Bitter Edge: a quick cut at a target I have Frozen (its on-hit effect Freezes it again).
func _bitter_edge(w: Dictionary, res: Resource) -> void:
	if not player._has_valid_target():
		return
	player.deal_damage(player.target, player._weapon_hit(w, res), BITTER_EDGE_ID)
	player._slash_effect(Abilities.color_of(BITTER_EDGE_ID))
	_gain_glaze(Balance.BITTER_EDGE_GLAZE + int(round(player._talent("frost_biting_hold"))))   # + Biting Hold

## Icebreaker spends my Glaze (frost_more._icebreaker): the multiplier it hits with,
## and `_spending` holds the count while the hit is worked out.
func _icebreaker_glaze() -> float:
	_spending = _spend_glaze()
	return glaze_mult(_spending, Balance.ICEBREAKER_PCT_PER_GLAZE)

func _icebreaker_done() -> void:
	_spending = 0

## Player.adjust_crit: Glinting Rime. My Frost abilities crit more for each Glaze I
## hold (or the finisher being dealt spent); at full rank an Icebreaker that spends
## all GLAZE_MAX is a sure crit.
func adjust_crit(info: RefCounted, chance: float) -> float:
	var per := player._talent("frost_glinting_rime")
	if per <= 0.0 or info.is_dot or info.is_proc:
		return chance
	var tags: PackedStringArray = info.tags
	if not (tags.has("Ability") and tags.has("Frost")):
		return chance
	var n := maxi(glaze(), _spending)
	chance += glinting_crit(n, per)
	if str(info.ability_id) == "icebreaker" and _spending >= Balance.GLAZE_MAX and player.frost_melee._capstone("frost_glinting_rime"):
		chance += 100.0
	return chance

## Rune of the Hoar Blade: an auto-attack of mine landed while I hold all my Glaze.
func _hoar_blade_on_hit(info: RefCounted) -> void:
	if str(info.ability_id) != "auto_melee" or info.is_proc or int(info.amount) <= 0:
		return
	if glaze() < Balance.GLAZE_MAX or not player.frost_melee._has_rune(HOAR_BLADE_RUNE):
		return
	var foe: Variant = info.target
	if foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return
	player.deal_damage(foe, Balance.HOAR_BLADE_DAMAGE, HOAR_BLADE_ID, true, "frost", PackedStringArray(FROST_MELEE_TAGS))
