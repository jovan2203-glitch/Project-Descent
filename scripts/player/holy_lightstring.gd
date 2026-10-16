extends "res://scripts/player/player_kit.gd"
class_name LightstringKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "lightstring".
# --- Holy archer: Lightstring -----------------------------------------------------------------
# A bow and Energy. It shares my prisms with the second healer, but by colour:
# Prism Arrow plants GOLD prisms, and only arrows use those (heals use only the
# white ones; light never moves between the colours; PRISM_MAX counts both).
# Every shot is a line from me to the enemy. Each gold prism on it fires a
# refracted arrow at another enemy near it (none: the shot is stronger instead)
# and stores part of the shot's damage as light; my auto-shots do this too, more
# weakly. Sunlit Arrow drains that light as damage, Prism Breaker shatters a gold
# prism into the enemies around it, Step of Light takes me to a prism, and
# Spectrum Volley makes the gold prisms shoot by themselves. Numbers are in
# balance.gd; the talents (Wide Fan, Split Light, Bright Quiver, Deep Burn,
# Swift Light, Long Volley) in talents.gd.

const PRISM_ARROW_ID := "prismarrow"
const GLIMMER_SHOT_ID := "glimmershot"
const REFRACTING_SHOT_ID := "refractingshot"
const SUNLIT_ARROW_ID := "sunlitarrow"
const PRISM_BREAKER_ID := "prismbreaker"
const STEP_OF_LIGHT_ID := "stepoflight"
const SPECTRUM_VOLLEY_ID := "spectrumvolley"
## The instants of the kit (_use_drafted -> _lightstring_use).
const LIGHTSTRING_INSTANTS := [GLIMMER_SHOT_ID, SUNLIT_ARROW_ID, PRISM_BREAKER_ID, STEP_OF_LIGHT_ID, SPECTRUM_VOLLEY_ID]
## Meter / log ids of a refracted arrow and a Spectrum Volley arrow (own lines: Details.HIT_NAMES).
const REFRACTION_ID := "refraction"
const VOLLEY_ARROW_ID := "volley_arrow"
const VOLLEY_FX := "spectrum_volley"
const LIGHTSTRING_TAGS := ["Holy", "Ability", "Ranged", "Projectile"]

var _prism_arrows := Balance.PRISM_ARROW_CHARGES   # Prism Arrow's charges ...
var _prism_arrow_recharge := 0.0                    # ... and seconds until the next one (0 = all there)
var _volley_next := 0.0

## The enemy (index into `spots`) a prism at `prism` refracts at: the closest one
## within `radius` that isn't the shot's own target (`skip`), -1 = none.
static func refract_target(prism: Vector3, spots: Array, skip: int, radius: float) -> int:
	var best := -1
	var best_d := INF
	for i in spots.size():
		if i == skip:
			continue
		var s: Vector3 = spots[i]
		var d := Vector2(s.x - prism.x, s.z - prism.z).length()
		if d <= radius and d < best_d:
			best_d = d
			best = i
	return best

## A gold prism's light after a shot of `coef` passes through it (charging `pct` %).
static func gold_charged(light: float, coef: float, pct: float, cap: float) -> float:
	return minf(maxf(light, 0.0) + maxf(coef, 0.0) * maxf(pct, 0.0) / 100.0, cap)

## Sunlit Arrow's bonus damage (coefficient) for the light it drains (`deep` = Deep Burn's %).
static func sunlit_bonus(lights: Array, deep: float) -> float:
	var total := 0.0
	for l in lights:
		total += maxf(float(l), 0.0)
	return total * Balance.SUNLIT_DRAIN * (1.0 + maxf(deep, 0.0) / 100.0)

## Prism Breaker's damage (coefficient) for a gold prism holding `light`.
static func breaker_damage(light: float) -> float:
	return Balance.BREAKER_DAMAGE + maxf(light, 0.0) * Balance.BREAKER_LIGHT

## A Spectrum Volley arrow's damage (coefficient) from a gold prism holding `light`.
static func volley_damage(light: float) -> float:
	return Balance.VOLLEY_DAMAGE + maxf(light, 0.0) * Balance.VOLLEY_LIGHT

## A shot from me at `tgt` carrying `coef`: every gold prism on its line refracts
## (`refract` % of the shot, at another enemy near it) or focuses (the shot is
## stronger), and stores `charge` % of it as light. `drain` (Sunlit Arrow): the
## light is taken as bonus damage instead. Returns {"mult", "bonus"}.
func _arrow_line(tgt: Node3D, coef: float, refract: float, charge: float, drain: bool = false) -> Dictionary:
	var out := {"mult": 1.0, "bonus": 0.0}
	if tgt == null or not is_instance_valid(tgt) or player.prism_kit.prisms_of("gold") <= 0:
		return out
	var from := player.global_position
	var to := tgt.global_position
	var cap := player.prism_kit._my_prism_cap()
	var reach := Balance.REFRACT_RADIUS + player._talent("holy_wide_fan")   # + Wide Fan
	var split := 1.0 + player._talent("holy_split_light") / 100.0          # + Split Light
	var drained := []
	var changed := false
	for p in player.prism_kit._prisms:
		if str(p.get("kind", "white")) != "gold" or not PrismsKit.on_beam(from, to, p["pos"], Balance.PRISM_BEAM_WIDTH):
			continue
		changed = true
		var at: Vector3 = p["pos"]
		var near := player._enemies_near(at, reach, tgt)
		if not near.is_empty() and refract > 0.0:
			var other: Node3D = near[0]
			ARROW.spawn(player.get_tree().current_scene, at + Vector3(0, Balance.PRISM_HOVER, 0), other, player,
				coef * refract / 100.0 * split, REFRACTION_ID)
		else:
			out["mult"] = float(out["mult"]) + Balance.REFRACT_FOCUS_PCT / 100.0
		if drain:
			drained.append(float(p["light"]))
			p["light"] = float(p["light"]) * (Balance.DEEP_BURN_KEEP_PCT / 100.0 if player.frost_melee._capstone("holy_deep_burn") else 0.0)
		else:
			p["light"] = gold_charged(float(p["light"]), coef, charge, cap)
	if drain:
		out["bonus"] = sunlit_bonus(drained, player._talent("holy_deep_burn"))   # + Deep Burn
	if changed:
		player.prism_kit._sync_prisms()
	return out

## A bow shot of the kit at my target: the line, then the arrow.
func _lightstring_shot(id: String, refract: float, drain: bool = false) -> void:
	if not player._has_valid_target():
		return
	var w := player._weapon()
	var coef := player._weapon_hit(w, Abilities.get_resource(id))
	var line := _arrow_line(player.target, coef, refract, Balance.GOLD_CHARGE_PCT, drain)
	var dir := player.target.global_position - player.global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, coef * float(line["mult"]) + float(line["bonus"]), id)

## Why a Lightstring ability can't be used right now ("" = it can).
func _lightstring_precheck(id: String) -> String:
	match id:
		PRISM_BREAKER_ID:
			if player.prism_kit.prisms_of("gold") <= 0:
				return "You have no gold prisms"
		STEP_OF_LIGHT_ID:
			if player.prism_kit._prisms.is_empty():
				return "You have no prisms"
			var i := player.prism_kit._target_prism("")
			var p: Vector3 = player.prism_kit._prisms[i]["pos"]
			if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > float(Abilities.get_resource(id).cast_range):
				return "Out of range"
		SPECTRUM_VOLLEY_ID:
			if player.prism_kit.prisms_of("gold") <= 0:
				return "You have no gold prisms"
	return ""

## One of the kit's instants (paid for and put on cooldown by _use_drafted).
func _lightstring_use(id: String, _res: Resource) -> void:
	match id:
		GLIMMER_SHOT_ID:
			_lightstring_shot(id, Balance.REFRACT_PCT)
		SUNLIT_ARROW_ID:
			_lightstring_shot(id, Balance.REFRACT_PCT, true)
		PRISM_BREAKER_ID:
			var i := player.prism_kit._target_prism("gold")
			if i >= 0:
				_break_prism(i)
		STEP_OF_LIGHT_ID:
			var i := player.prism_kit._target_prism("")
			if i >= 0:
				var p: Vector3 = player.prism_kit._prisms[i]["pos"]
				var back := Vector3(player.global_position.x - p.x, 0.0, player.global_position.z - p.z)
				back = back.normalized() if back.length() > 0.01 else Vector3.BACK
				var from := player.global_position
				var land := p + back * Balance.STEP_OF_LIGHT_OFFSET
				player.global_position = Vector3(land.x, player.global_position.y, land.z)
				player._ring_effect(0.8, PrismsKit.PRISM.GOLD, from)
				player._ring_effect(0.8, PrismsKit.PRISM.GOLD)
		SPECTRUM_VOLLEY_ID:
			var fx := StatusContainer.make_buff(VOLLEY_FX, Abilities.ability_name(id), Stats.BLOCK, 0.0,
				Balance.VOLLEY_TIME + player._talent("holy_long_volley"), 1, PrismsKit.PRISM.GOLD)   # + Long Volley
			fx.stat_modifiers = {}
			fx.tags = PackedStringArray(["Holy"])
			fx.description = "Your gold prisms shoot the enemies near them."
			player.status.apply(fx, player)
			_volley_next = Time.get_ticks_msec() / 1000.0

## Prism Breaker: the gold prism at index `i` shatters into the enemies around it.
func _break_prism(i: int) -> void:
	var p: Dictionary = player.prism_kit._prisms[i]
	player.prism_kit._prisms.remove_at(i)
	var at: Vector3 = p["pos"]
	PrismsKit.LIGHT_BEAM.flash(player.get_tree().current_scene, player._muzzle(), at + Vector3(0, Balance.PRISM_HOVER, 0), PrismsKit.PRISM.GOLD)
	var reach := Balance.BREAKER_RADIUS + player._talent("holy_wide_break")   # + Wide Break
	var foes := player._enemies_near(at, reach)
	var coef := breaker_damage(float(p["light"])) * Balance.aoe_share(foes.size())
	for e in foes:
		player.deal_damage(e, coef, PRISM_BREAKER_ID)
	PrismsKit.PRISM.shatter(player.get_tree(), "me:" + str(p["key"]))
	player._net_fx("prism_burst", at, null, {"k": str(p["key"])})
	player._ring_effect(reach, PrismsKit.PRISM.GOLD, at)
	if str(p["key"]) == player.prism_kit.prism_target:
		player.prism_kit.prism_target = ""
	player.prism_kit._sync_prisms()

## Refracting Shot: a bow cast (like Glacial Draw).
func _start_refracting_shot() -> void:
	var id := REFRACTING_SHOT_ID
	if player.casting:
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
	if not player.can_afford(id, true):
		return
	player._begin_spell(id, Abilities.ability_name(id), float(Abilities.get_resource(id).cast_time))

## Refracting Shot's arrow leaves the bow.
func _loose_refracting_shot() -> void:
	player.cooldowns[REFRACTING_SHOT_ID] = Abilities.cooldown_of(Abilities.get_resource(REFRACTING_SHOT_ID))
	if player._weapon().get("weapon", "") != "ranged":
		player._error("Requires a bow")
		return
	_lightstring_shot(REFRACTING_SHOT_ID, Balance.REFRACTING_SHOT_PCT)

## An auto-shot at `enemy` worth `coef`: through my gold prisms, weakly. Returns
## how much stronger it is (focused prisms).
func _auto_shot_line(enemy: Node3D, coef: float) -> float:
	if player.prism_kit.prisms_of("gold") <= 0:
		return 1.0
	var charge := Balance.AUTO_SHOT_CHARGE_PCT * (1.0 + player._talent("holy_bright_quiver") / 100.0)   # + Bright Quiver
	return float(_arrow_line(enemy, coef, Balance.AUTO_SHOT_REFRACT_PCT, charge)["mult"])

## Prism Arrow's charges.
func _prism_arrow_used() -> void:
	_prism_arrows = maxi(_prism_arrows - 1, 0)
	var cd := Abilities.cooldown_of(Abilities.get_resource(PRISM_ARROW_ID))
	if _prism_arrow_recharge <= 0.0:
		_prism_arrow_recharge = cd
	if _prism_arrows <= 0:
		player.cooldowns[PRISM_ARROW_ID] = _prism_arrow_recharge
	else:
		player.cooldowns.erase(PRISM_ARROW_ID)

## Every frame: Prism Arrow recharging, Spectrum Volley shooting.
func _tick_lightstring(delta: float) -> void:
	if _prism_arrow_recharge > 0.0:
		_prism_arrow_recharge -= delta
		if _prism_arrow_recharge <= 0.0:
			_prism_arrows = mini(_prism_arrows + 1, Balance.PRISM_ARROW_CHARGES)
			_prism_arrow_recharge = Abilities.cooldown_of(Abilities.get_resource(PRISM_ARROW_ID)) \
				if _prism_arrows < Balance.PRISM_ARROW_CHARGES else 0.0
	if player.status == null or not player.status.has(VOLLEY_FX):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _volley_next:
		return
	_volley_next = now + Balance.VOLLEY_EVERY
	for p in player.prism_kit._prisms:
		if str(p.get("kind", "white")) != "gold":
			continue
		var at: Vector3 = p["pos"]
		var near := player._enemies_near(at, Balance.VOLLEY_RADIUS)
		if near.is_empty():
			continue
		ARROW.spawn(player.get_tree().current_scene, at + Vector3(0, Balance.PRISM_HOVER, 0), near[0], player,
			volley_damage(float(p["light"])), VOLLEY_ARROW_ID)

