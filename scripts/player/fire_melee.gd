extends "res://scripts/player/player_kit.gd"
class_name FireMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_melee".
# --- Heat (Fire melee) ------------------------------------------------------------------------
# Every melee hit of mine (auto-attacks and abilities; not procs, not ticks) on a
# target carrying MY Burning or Blaze builds a stack of Heat: once per swing,
# however many enemies it hit. Searing Strike builds SEARING_STRIKE_HEAT (Kindling
# may add one more). Each stack makes my Fire ABILITIES (not spells) hit harder. A
# new stack restarts the HEAT_TIME timer; when that runs out all of it is lost.
# Flare spends some, Quench removes it all for bonus damage. Only my own burns
# count: another player's never builds my Heat.
# Sparks: while I hold Heat my melee hits can't crit; one that would have is a
# Spark and gives one Heat more. Heat bands: Red (1-4), Orange (5-8) and White
# (9-10); each ability does something more in Orange and in White (Blast Furnace:
# White whatever the Heat).

const HEAT_ID := "heat"
const AFTERGLOW_ID := "afterglow"
const FOLD_STEEL_ID := "foldsteel"
const RED_EDGE_ID := "rededge"
const BLAST_FURNACE_ID := "blastfurnace"
const RED_EDGE_HIT_ID := "red_edge"   # meter / log id of Red Edge's extra Fire damage
const OVERHEAT_ID := "overheat"   # meter / log id of the Overheat talent's burn
const MELEE_IDS := ["searingstrike", "quench", "flare", FOLD_STEEL_ID, RED_EDGE_ID, BLAST_FURNACE_ID]
enum Band { NONE, RED, ORANGE, WHITE }
const HEAT_BAND_COLORS := [Color(0.5, 0.5, 0.5), Color(1.0, 0.3, 0.2), Color(1.0, 0.6, 0.15), Color(1.0, 0.95, 0.75)]   # (trackers: one per Band)
var _heat_fx: Resource
var _heat_last := ""   # "<ability>@<frame>" of the last swing that built Heat
var last_heat_spent := 0   # Heat the Quench or Flare being dealt right now spent (Hard Quench)

func heat_stacks() -> int:
	return int(player.status.stacks_of(HEAT_ID)) if player.status else 0

## The Heat band `stacks` Heat is in.
static func band_of(stacks: int) -> int:
	if stacks >= Balance.HEAT_BAND_WHITE:
		return Band.WHITE
	if stacks >= Balance.HEAT_BAND_ORANGE:
		return Band.ORANGE
	return Band.RED if stacks > 0 else Band.NONE

## My Heat band right now (Blast Furnace: always White).
func band() -> int:
	if player.status and player.status.has(BLAST_FURNACE_ID):
		return Band.WHITE
	return band_of(heat_stacks())

## Heat `id` needs right now: Flare is free in the White band.
func heat_needed_now(id: String) -> int:
	if id == "flare" and band() == Band.WHITE:
		return 0
	return heat_needed(id)

## Hits Fold Steel strikes in band `b`.
static func fold_hits(b: int) -> int:
	return Balance.FOLD_STEEL_HITS_ORANGE if b >= Band.ORANGE else Balance.FOLD_STEEL_HITS

## Sparks: while I hold Heat (or in Blast Furnace) my melee hits don't crit; one
## that would have is marked as a Spark (more Heat in _heat_on_hit). During Red
## Edge in the White band every auto-swing is a Spark.
func adjust_crit(info: RefCounted, chance: float) -> float:
	if info.is_dot or info.is_proc or not info.tags.has("Melee"):
		return chance
	if heat_stacks() <= 0 and band() != Band.WHITE:
		return chance
	var sure: bool = str(info.ability_id) == "auto_melee" and player.status.has(RED_EDGE_ID) and band() == Band.WHITE
	if sure or randf() * 100.0 < chance:
		info.set_meta("spark", true)
	return 0.0

## Is this hit of mine a Spark?
static func is_spark(info: RefCounted) -> bool:
	return info.has_meta("spark") and bool(info.get_meta("spark"))

## Heat an ability needs to be used (Quench, Flare); 0 for everything else.
static func heat_needed(id: String) -> int:
	match id:
		"quench":
			return Balance.QUENCH_MIN_HEAT
		"flare":
			return Balance.FLARE_HEAT_COST
	return 0

## Heat one swing of `ability_id` builds on a target with my Immolate (before Kindling).
static func heat_from(ability_id: String) -> int:
	if heat_needed(ability_id) > 0:
		return 0   # the Heat spenders build none
	return Balance.SEARING_STRIKE_HEAT if ability_id == "searingstrike" else 1

## White Heat (Fire talent): % more Fire damage my abilities deal while my Heat
## is in band `b`, at `pct` per its rank. Only in the White band.
static func white_heat_bonus(b: int, pct: float) -> float:
	return pct if b == Band.WHITE else 0.0

## Quench's damage coefficient with `heat` stacks removed.
static func quench_coef(base: float, heat: int) -> float:
	return base * (1.0 + Balance.QUENCH_PCT_PER_HEAT / 100.0 * maxi(heat, 0))

## An Immolate with `left` seconds to go, fed `add` more: never above its base duration.
static func tinder_time(left: float, add: float, base: float) -> float:
	return minf(left + add, maxf(base, left))

## Fire damage Afterglow adds to an auto-attack that dealt `amount`.
static func afterglow_damage(amount: int, pct: float) -> float:
	return maxf(float(amount) * pct / 100.0, 0.0)

## Colour of a weapon swing at `stacks` Heat: steel, then orange, white-hot at the cap.
static func heat_tint(stacks: int) -> Color:
	var cold := Color(0.9, 0.95, 1.0)
	if stacks <= 0:
		return cold
	var t := clampf(float(stacks) / float(maxi(Balance.HEAT_MAX_STACKS, 1)), 0.0, 1.0)
	if t < 0.7:
		return cold.lerp(Color(1.0, 0.5, 0.12), t / 0.7)
	return Color(1.0, 0.5, 0.12).lerp(Color(1.0, 0.95, 0.7), (t - 0.7) / 0.3)

## The Heat buff: a stacking % bonus to Fire damage dealt by abilities.
## `time` = seconds without a new stack before it is lost (Slow Cooling makes it
## longer); `pct` = the bonus per stack (Molten Edge makes it bigger).
static func make_heat_fx(time: float = Balance.HEAT_TIME, pct: float = Balance.HEAT_DAMAGE_PCT) -> Resource:
	var fx := StatusContainer.make_buff(HEAT_ID, "Heat", HEAT_ID, 0.0,
		time, Balance.HEAT_MAX_STACKS, Color(1.0, 0.55, 0.15))
	fx.stat_modifiers = {}
	fx.damage_mod_pct = pct
	fx.mod_damage_types = PackedStringArray(["fire"])
	fx.mod_required_tags = PackedStringArray(["Ability"])
	fx.mod_affects_dots = true   # an ability's burn (Searing Strike's Burning) counts too
	fx.description = "Your abilities deal %s%% more Fire damage per stack. All Heat is lost after %s sec without gaining a stack." % [
		Stats.num(pct), Stats.num(time)]
	return fx

func _heat_stack_fx() -> Resource:
	var time := Balance.HEAT_TIME + player._talent("fire_slow_cooling")   # Slow Cooling
	var pct := Balance.HEAT_DAMAGE_PCT + player._talent("fire_molten_edge")   # Molten Edge
	if _heat_fx == null or not is_equal_approx(float(_heat_fx.duration), time) or not is_equal_approx(float(_heat_fx.damage_mod_pct), pct):
		_heat_fx = make_heat_fx(time, pct)
	return _heat_fx

## Steady Arm: how fast the cooldown of `id` recovers (my melee abilities, in the
## Orange or White band).
func cooldown_rate(id: String) -> float:
	var arm := player._talent("fire_steady_arm")
	if arm <= 0.0 or band() < Band.ORANGE:
		return 1.0
	var tags := Abilities.tags_of(id)
	return 1.0 + arm / 100.0 if tags.has("Melee") and tags.has("Ability") else 1.0

## A Spark of mine landed: Quick Forge (Fire ability cooldowns) and Overheat (in
## White, part of it burns the enemies around the target, its own line).
func _spark_landed(info: RefCounted) -> void:
	var forge := player._talent("fire_quick_forge")
	if forge > 0.0:
		for cd_id in player.cooldowns.keys():
			if Abilities.category_of(str(cd_id)) == "fire" and Abilities.tags_of(str(cd_id)).has("Ability"):
				player.cooldowns[cd_id] = float(player.cooldowns[cd_id]) - forge
	var over := player._talent("fire_overheat")
	if over <= 0.0 or band() != Band.WHITE or not is_instance_valid(info.target):
		return
	var near: Array = player._enemies_near((info.target as Node3D).global_position, Balance.OVERHEAT_RADIUS, info.target)
	var each := float(info.amount) * over / 100.0
	for e in near:
		if not is_instance_valid(e) or not e.is_alive() or each <= 0.0:
			continue
		var extra := DamageInfo.make(player, e, 1.0, OVERHEAT_ID)
		extra.unit = each
		extra.exact = true
		extra.add_power = false
		extra.can_crit = false
		extra.can_block = false
		extra.is_proc = true
		extra.damage_type = "fire"
		extra.tags = PackedStringArray(["Fire", "Melee"])
		player._combat().deal(extra)

## Add `n` stacks of Heat (every stack restarts its timer, also at the cap).
func gain_heat(n: int) -> void:
	for i in maxi(n, 0):
		player.status.apply(_heat_stack_fx(), player)

## Does `tgt` carry my Burning or my Blaze (what Heat is built on)?
func _burning_mine(tgt: Node) -> bool:
	var st: Node = tgt.get_node_or_null("Status") if tgt != null and is_instance_valid(tgt) else null
	return st != null and (st.has_from("burning", player) or st.has_from("immolate", player))

## A hit of mine landed: melee swings on a target with my Burning or Blaze build
## Heat (during Red Edge my auto-swings build it on anything); a Spark one more.
func _heat_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee"):
		return
	if is_spark(info):
		_spark_landed(info)
	var id := str(info.ability_id)
	var gain := heat_from(id)
	if gain <= 0 or info.target == null or not is_instance_valid(info.target):
		return
	var red_edge: bool = id == "auto_melee" and player.status.has(RED_EDGE_ID)
	if not red_edge and not _burning_mine(info.target):
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if key == _heat_last:
		return   # the same swing hitting another enemy
	_heat_last = key
	if is_spark(info):
		gain += 1   # a Spark
		if randf() * 100.0 < player._talent("fire_bright_sparks"):
			gain += 1   # Bright Sparks
	elif info.crit:
		gain += int(round(player._talent("fire_cold_steel", "values2")))   # Cold Steel (a crit means no Heat was held)
	gain_heat(gain)
	if red_edge and band() >= Band.ORANGE:
		_red_edge_hit(info.target)

## Spread my Burning onto `e` (no damage: just Searing Strike's on-hit effect).
func _spread_burning(e: Node) -> void:
	if is_instance_valid(e) and e.is_alive():
		player.deal_damage(e, 0.0, "searingstrike", true)

## Searing Strike. Orange: its Burning also goes on the nearest other enemy.
## White: it gives Fury back. (The band is the one before its own Heat.)
func _searing_strike(w: Dictionary, res: Resource) -> void:
	var b: int = band()
	var tgt: Node3D = player.target
	player.deal_damage(tgt, player._weapon_hit(w, res), "searingstrike")
	if b >= Band.ORANGE and is_instance_valid(tgt):
		var near: Array = player._enemies_near(tgt.global_position, Balance.SEARING_SPREAD_RADIUS, tgt)
		if not near.is_empty():
			_spread_burning(near[0])
	if b == Band.WHITE:
		player._gain("fury", Balance.SEARING_WHITE_FURY)
	player._slash_effect(heat_tint(heat_stacks()))
	player._slash_effect(Abilities.color_of("searingstrike"))

## Quench: every stack of Heat goes into this one hit. The Heat is gone before
## it lands, so the hit gets no Heat bonus of its own; it never crits
## (adjust_crit). White: part of it also hits the enemies around the target.
func _quench(w: Dictionary, res: Resource) -> void:
	var b: int = band()
	var heat: int = heat_stacks()
	var tgt: Node3D = player.target
	player.status.remove(HEAT_ID)
	var coef: float = quench_coef(player._weapon_hit(w, res), heat)
	last_heat_spent = heat   # (Hard Quench)
	player.deal_damage(tgt, coef, "quench")
	if b == Band.WHITE and is_instance_valid(tgt):
		var near: Array = player._enemies_near(tgt.global_position, Balance.QUENCH_WHITE_RADIUS, tgt)
		var share: float = Balance.aoe_share(near.size())
		for e in near:
			if is_instance_valid(e) and e.is_alive():
				player.deal_damage(e, coef * Balance.QUENCH_WHITE_SPLASH_PCT / 100.0 * share, "quench")
		player._ring_effect(Balance.QUENCH_WHITE_RADIUS, Color(1.0, 0.95, 0.7), tgt.global_position)
	last_heat_spent = 0
	gain_heat(int(round(player._talent("fire_banked_fire"))))   # Banked Fire
	_heat_spent_fury()
	player._slash_effect(Color(1.0, 0.9, 0.4))
	player._slash_effect(Abilities.color_of("quench"))
	if is_instance_valid(tgt):
		player._ring_effect(0.8, Color(0.85, 0.93, 1.0), tgt.global_position)   # steam
	if player._talent("fire_afterglow") > 0.0:
		_start_afterglow()

## Fold Steel: quick hits one after another, each its own swing (its own crit
## roll, so its own Spark, and its own Heat). Orange: one more hit. White: each
## hit also splashes the enemies around the target.
func _fold_steel(w: Dictionary, res: Resource) -> void:
	var b: int = band()
	var tgt: Node3D = player.target
	var coef: float = player._weapon_hit(w, res)
	for i in fold_hits(b) + int(round(player._talent("fire_fold_again"))):   # + Fold Again
		if i == 0:
			_fold_hit(tgt, coef, b == Band.WHITE)
		else:
			player.echo_timer(Balance.FOLD_STEEL_GAP * i).timeout.connect(_fold_hit.bind(tgt, coef, b == Band.WHITE))

func _fold_hit(tgt: Node3D, coef: float, splash: bool) -> void:
	if player.is_dead() or tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	player.deal_damage(tgt, coef, FOLD_STEEL_ID)
	player._slash_effect(heat_tint(heat_stacks()))
	if not splash:
		return
	var near: Array = player._enemies_near(tgt.global_position, Balance.FOLD_STEEL_SPLASH_RADIUS, tgt)
	var share: float = Balance.aoe_share(near.size())
	for e in near:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef * Balance.FOLD_STEEL_SPLASH_PCT / 100.0 * share, FOLD_STEEL_ID)

## Red Edge in the Orange band and up: an auto-swing also deals Fire damage (its
## own meter line). A proc: it builds no Heat and feeds nothing else.
func _red_edge_hit(tgt: Node) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var extra := DamageInfo.make(player, tgt, player._weapon_hit(player._weapon(), Abilities.get_resource(RED_EDGE_ID)), RED_EDGE_HIT_ID)
	extra.is_proc = true
	extra.damage_type = "fire"
	extra.tags = PackedStringArray(["Ability", "Fire", "Melee"])
	player._combat().deal(extra)

## Red Edge and Blast Furnace (paid for and put on cooldown by _use_drafted).
func _melee_buff(id: String) -> void:
	var fx: Resource
	if id == RED_EDGE_ID:
		fx = StatusContainer.make_buff(RED_EDGE_ID, Abilities.ability_name(id), RED_EDGE_ID, 0.0, Balance.RED_EDGE_TIME, 1, Abilities.color_of(id))
		fx.description = "Your auto-attacks build Heat on any target. Orange band: they also deal Fire damage. White band: every one is a Spark."
	else:
		fx = StatusContainer.make_buff(BLAST_FURNACE_ID, Abilities.ability_name(id), BLAST_FURNACE_ID, 0.0,
			Balance.BLAST_FURNACE_TIME + player._talent("fire_long_blast"), 1, Abilities.color_of(id))   # + Long Blast
		fx.description = "Your abilities count as the White band whatever your Heat, and your Heat does not fade."
	fx.stat_modifiers = {}
	player.status.apply(fx, player)
	player._ring_effect(1.3, Abilities.color_of(id))

## One of Forge Heat's abilities (paid for and put on cooldown by _use_drafted).
func _melee_use(id: String, res: Resource, w: Dictionary) -> void:
	match id:
		"searingstrike":
			_searing_strike(w, res)
		"quench":
			_quench(w, res)
		"flare":
			_flare(w, res)
		FOLD_STEEL_ID:
			_fold_steel(w, res)
		RED_EDGE_ID, BLAST_FURNACE_ID:
			_melee_buff(id)

## Blast Furnace: Heat doesn't fade while it lasts.
func _tick_heat() -> void:
	if player.status and player.status.has(BLAST_FURNACE_ID) and player.status.has(HEAT_ID):
		player.status.set_remaining(HEAT_ID, maxf(player.status.remaining_of(HEAT_ID), float(_heat_stack_fx().duration)))

## Flare: a sweep in front of me. Its Heat is spent first (what is left still
## boosts it; none in the White band). Everything in the arc is hit - more than
## AOE_TARGET_CAP enemies share that many hits' damage - and my target's Burning
## goes onto every enemy hit that doesn't carry mine yet (it never refreshes one that does).
## Orange and up: it hits harder.
func _flare(w: Dictionary, res: Resource) -> void:
	var b: int = band()
	if b != Band.WHITE:
		player.status.spend_stacks(HEAT_ID, Balance.FLARE_HEAT_COST)
		last_heat_spent = Balance.FLARE_HEAT_COST   # (Hard Quench)
	var has_target := player._has_valid_target()
	var spread: bool = has_target and _burning_mine(player.target)
	var arc := Balance.FLARE_ARC + player._talent("fire_wide_flare")   # + Wide Flare
	var hit := player.fire_tank._enemies_in_cone(float(res.radius), arc)
	if has_target and not hit.has(player.target):
		hit.append(player.target)   # in weapon reach, but outside the sweep's
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	if b >= Band.ORANGE:
		coef *= 1.0 + Balance.FLARE_ORANGE_PCT / 100.0
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var est: Node = e.get_node_or_null("Status")
		var had: bool = est != null and est.has_from("burning", player)
		player.deal_damage(e, coef, "flare")
		if spread and not had:
			_spread_burning(e)
	last_heat_spent = 0
	if b != Band.WHITE:
		_heat_spent_fury()
	for i in 2:
		player._slash_effect(Abilities.color_of("flare"))
	player._cone_effect(float(res.radius), arc * 0.5, Abilities.color_of("flare"))

## Fed Furnace: an ability that spent Heat gives Fury.
func _heat_spent_fury() -> void:
	var fed := player._talent("fire_fed_furnace")
	if fed > 0.0:
		player._gain("fury", fed)

## Fresh Tinder: my Burning on `tgt` lasts longer, up to its full duration.
## The tick timer is left alone, so it simply gets more ticks.
func _feed_burning(tgt: Node) -> void:
	var st: Node = tgt.get_node_or_null("Status") if tgt != null and is_instance_valid(tgt) else null
	if st == null or not st.has_from("burning", player):
		return
	var fx: Resource = Abilities.get_resource("searingstrike").on_hit_effect
	if fx == null:
		return
	var left: float = st.remaining_from("burning", player)
	var fed := tinder_time(left, Balance.FRESH_TINDER_SECONDS, float(fx.duration) + player.effect_duration_bonus(fx))   # full duration incl. Long Burn
	if fed <= left + 0.001:
		return   # already at its full duration
	var net := player._net()
	if net:
		net.set_effect_remaining(tgt, player, "burning", fed)   # the host owns enemy effects in a party
	else:
		st.set_remaining_from("burning", player, fed)

## Afterglow talent: Quench leaves the weapon glowing for a few seconds.
func _start_afterglow() -> void:
	var fx := StatusContainer.make_buff(AFTERGLOW_ID, "Afterglow", AFTERGLOW_ID, 0.0,
		Balance.AFTERGLOW_TIME, 1, Color(1.0, 0.75, 0.3))
	fx.stat_modifiers = {}
	fx.description = "Your auto-attacks also deal %s%% of their damage as Fire damage." % Stats.num(player._talent("fire_afterglow"))
	player.status.apply(fx, player)

## An auto-attack of mine landed during Afterglow: part of it again, as Fire
## damage. An exact share of the swing (its crit is already in it), dealt as a
## proc: it builds no Heat and feeds nothing else.
func _afterglow_on_hit(info: RefCounted) -> void:
	if str(info.ability_id) != "auto_melee" or int(info.amount) <= 0 or not player.status.has(AFTERGLOW_ID):
		return
	var extra_dmg := afterglow_damage(int(info.amount), player._talent("fire_afterglow"))
	if extra_dmg <= 0.0 or info.target == null or not is_instance_valid(info.target) or not info.target.is_alive():
		return
	var extra := DamageInfo.make(player, info.target, 1.0, AFTERGLOW_ID)
	extra.unit = extra_dmg
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "fire"
	extra.tags = PackedStringArray(["Fire", "Melee"])
	player._combat().deal(extra)

## Heat as pips, each in its band's colour (all white during Blast Furnace).
func tracker_values() -> Dictionary:
	var white := band() == Band.WHITE
	var colors: Array = []
	for i in range(1, Balance.HEAT_MAX_STACKS + 1):
		colors.append(HEAT_BAND_COLORS[Band.WHITE if white else band_of(i)])
	return {"heat": {"value": heat_stacks(), "max": Balance.HEAT_MAX_STACKS, "colors": colors}}
