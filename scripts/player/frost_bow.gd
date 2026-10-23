extends "res://scripts/player/player_kit.gd"
class_name FrostBowKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frost_bow".
# --- Frost, the bow ---------------------------------------------------------------------
# Shatter Shot, Glacial Draw, Rimefletch, Coldmark and Icy Retreat. Everything
# that asks about a Freeze, a Chill, a root or a mark asks about MINE (has_from).

const SHATTER_SHOT_ID := "shattershot"
const GLACIAL_DRAW_ID := "glacialdraw"
const RIMEFLETCH_ID := "rimefletch"
const COLDMARK_ID := "coldmark"
## The mark Coldmark leaves on its target (data/effects).
const COLDMARK_FX := "coldmarked"
const ICY_RETREAT_ID := "icyretreat"
const ICE_PATCH = preload("res://scripts/ice_patch.gd")
var _shatter_shot_frozen := false   # the Shatter Shot being worked out hit a target I had Frozen
var _ice_patch_seen := {}           # enemies (instance ids) my current ice has Chilled already (Black Ice rolls once each)

## Have I Frozen `tgt` (own only: a party member's Freeze is not mine)?
func _frozen_by_me(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from("frozen", player)

## Shatter Shot's hit is being worked out (_on_damage_modify): it hits a target I
## have Frozen harder, and remembers that for when it lands (_shatter_shot_landed).
func _shatter_shot_modify(info: RefCounted) -> void:
	_shatter_shot_frozen = not bool(info.is_proc) and _frozen_by_me(info.target)
	if _shatter_shot_frozen:
		info.add_bonus(Balance.SHATTER_SHOT_FROZEN_PCT, "Shatter Shot")

## Damage (coefficient) the burst deals to each of `count` other enemies: more
## than AOE_TARGET_CAP of them share that many hits.
static func shatter_shot_burst(count: int) -> float:
	return float(Abilities.EXTRA_HITS[SHATTER_SHOT_ID]) * Balance.aoe_share(count)

## Shatter Shot landed on `enemy` (which stood at `at`). If it broke my Freeze,
## the target thaws and the ice bursts over the other enemies around it (procs:
## the burst feeds nothing else).
func _shatter_shot_landed(enemy: Node, at: Vector3) -> void:
	if not _shatter_shot_frozen:
		return
	_shatter_shot_frozen = false
	if is_instance_valid(enemy):
		player.frost_more._end_freeze(enemy)
	# Clean Shatter: breaking my Freeze gives Energy back and shortens the cooldown.
	var refund := player._talent("frost_clean_shatter")
	if refund > 0.0:
		player._gain("energy", refund)
		player.cooldowns[SHATTER_SHOT_ID] = clean_shatter_cooldown(float(player.cooldowns.get(SHATTER_SHOT_ID, 0.0)),
			player._talent("frost_clean_shatter", "values2"))
	var r := float(Abilities.get_resource(SHATTER_SHOT_ID).radius)
	var others := player._enemies_near(at, r, enemy)
	var coef := shatter_shot_burst(others.size())
	for e in others:
		player.deal_damage(e, coef, SHATTER_SHOT_ID, true)
	player._ring_effect(r, Abilities.color_of(SHATTER_SHOT_ID), at)
	player._ring_effect(r * 0.5, Color(0.95, 0.97, 1.0), at)

## Is Glacial Draw instant on `tgt`: rooted by MY Icepin, or Frozen by me?
func glacial_draw_instant(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	return player.frost_runes._icepin_root_on(tgt) or _frozen_by_me(tgt)

## Glacial Draw: a cast with the bow, or no cast at all on a target that can't
## get away (glacial_draw_instant). Paid for, and on cooldown, when the arrow leaves.
func _start_glacial_draw() -> void:
	var id := GLACIAL_DRAW_ID
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
	if glacial_draw_instant(player.target):
		if not player._pay(id):
			return
		_loose_glacial_draw()
		player._bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	player._begin_spell(id, Abilities.ability_name(id), float(Abilities.get_resource(id).cast_time))

## Glacial Draw's arrow leaves the bow (its cast finished, or it was instant).
func _loose_glacial_draw() -> void:
	var id := GLACIAL_DRAW_ID
	var res := Abilities.get_resource(id)
	var w := player._weapon()
	if w.get("weapon", "") != "ranged":
		player._error("Requires a bow")
		return
	if not player._has_valid_target():
		return
	var sight_err := player._target_error(player.target)
	if sight_err != "":
		player._error(sight_err)
		return
	player.cooldowns[id] = Abilities.cooldown_of(res)
	var dir := player.target.global_position - player.global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	ARROW.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, player._weapon_hit(w, res), id)

## Rimefletch: a fresh set of charges (never more than RIMEFLETCH_SHOTS).
func _start_rimefletch() -> void:
	var col := Abilities.color_of(RIMEFLETCH_ID)
	var fx := StatusContainer.make_buff(RIMEFLETCH_ID, Abilities.ability_name(RIMEFLETCH_ID), RIMEFLETCH_ID, 0.0,
		Balance.RIMEFLETCH_TIME, Balance.RIMEFLETCH_SHOTS, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Frost"])
	fx.description = "Your next auto-shots deal %s%% more damage, as Frost damage, and Chill the target, one stack each." % Stats.num(Balance.RIMEFLETCH_PCT)
	player.status.remove(RIMEFLETCH_ID)
	if player.status.apply(fx, player):
		player.status.set_stacks(RIMEFLETCH_ID, Balance.RIMEFLETCH_SHOTS)
	player._ring_effect(1.0, col)

## Frost damage Rimefletch adds to an auto-shot that dealt `amount`.
static func rimefletch_damage(amount: int) -> float:
	return maxf(float(amount) * Balance.RIMEFLETCH_PCT / 100.0, 0.0)

## Does a Rimefletch shot Freeze (true) or Chill (false) its target? It Freezes
## a target that already carries MY Chill (or my Freeze, which is a Chill and more).
static func rimefletch_freezes(chilled_by_me: bool, frozen_by_me: bool) -> bool:
	return chilled_by_me or frozen_by_me

## One of my hits landed (_on_damage_dealt_frost). An auto-shot with Rimefletch
## up uses a charge: an exact share of the shot again as Frost damage (its crit is
## already in it), dealt as a proc so it feeds nothing else, carrying the Chill
## or the Freeze.
func _rimefletch_shot(info: RefCounted) -> void:
	if player.status == null or str(info.ability_id) != "auto_ranged" or not player.status.has(RIMEFLETCH_ID):
		return
	player.status.spend_stacks(RIMEFLETCH_ID, 1)
	var foe: Node = info.target
	if not is_instance_valid(foe) or not foe.is_alive():
		return
	var st: Node = foe.get_node_or_null("Status")
	var freeze: bool = st != null and rimefletch_freezes(st.has_from("chilled", player), st.has_from("frozen", player))
	var extra := DamageInfo.make(player, foe, 1.0, RIMEFLETCH_ID)
	extra.unit = rimefletch_damage(int(info.amount))
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "frost"
	extra.tags = PackedStringArray(["Ability", "Frost", "Ranged"])
	var fx: Resource = FrostMeleeKit.FROZEN_FX if freeze else FrostRunesKit.CHILLED_FX
	extra.effects.append(fx)
	player._combat().deal(extra)
	# Cold Harvest: a shot that Freezes (also a Chill that Deepwinter turns into one) gives Energy.
	if str(player.frost_more.effect_override(fx).id) == "frozen":
		var harvest := player._talent("frost_cold_harvest")
		if harvest > 0.0:
			player._gain("energy", harvest)

## Coldmark: my mark goes on the target (a hit with no damage carrying the mark,
## its on-hit effect, so in a party it reaches the host).
func _coldmark(tgt: Node) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	player.deal_damage(tgt, 0.0, COLDMARK_ID, true)
	if tgt is Node3D:
		player._ring_effect(0.9, Abilities.color_of(COLDMARK_ID), (tgt as Node3D).global_position)

## Is `id` an arrow ability: a bow ability that looses an arrow (not an auto-shot)?
static func is_arrow_ability(id: String) -> bool:
	if id.begins_with("auto_"):
		return false   # auto-shots are arrows, but not abilities
	var r := Abilities.get_resource(id)
	return r != null and int(r.weapon_requirement) == 2 and r.tags.has("Projectile")

## One of my hits landed (_on_damage_dealt_frost). An arrow ability hitting a
## target that carries MY Coldmark gives an Ice Shard charge. Procs and periodic
## damage are not arrows.
func _coldmark_arrow(info: RefCounted) -> void:
	if bool(info.is_proc) or bool(info.is_dot) or not is_arrow_ability(str(info.ability_id)):
		return
	var st: Node = info.target.get_node_or_null("Status")
	if st != null and st.has_from(COLDMARK_FX, player):
		player.ice_shards_kit.gain_ice_shard()

## Icy Retreat: a leap backward (it stops short of walls). The ground I left is
## ice for a while, and Frost Arrow is ready again.
func _icy_retreat(res: Resource) -> void:
	var col := Abilities.color_of(ICY_RETREAT_ID)
	var from := player.global_position
	var back := -player._flat_forward()
	player.global_position += back * player._dash_distance(Balance.ICY_RETREAT_DISTANCE, back)
	var r := float(res.radius)
	_ice_patch_seen.clear()   # a new sheet of ice: Black Ice rolls again for everyone
	ICE_PATCH.spawn(player.get_tree().current_scene, from, r, Balance.ICY_RETREAT_TIME, Balance.ICY_RETREAT_TICK, _ice_patch_chill)
	player._net_fx("icepatch", from, null, {"r": r, "time": Balance.ICY_RETREAT_TIME})   # the party sees the ice
	player.cooldowns.erase("frostarrow")
	player._ring_effect(0.8, col, from)
	player._ring_effect(0.8, col)

## An enemy is standing on my ice: it is Chilled (a Freeze during Deepwinter).
## Black Ice: the first Chill the ice puts on each enemy may be a Freeze instead.
func _ice_patch_chill(e: Node) -> void:
	var key := e.get_instance_id()
	var first := not _ice_patch_seen.has(key)
	_ice_patch_seen[key] = true
	var freeze := first and randf() * 100.0 < player._talent("frost_black_ice")
	player.frost_more._chill(e, ICY_RETREAT_ID, PackedStringArray(["Ability", "Frost"]), freeze)

## Have I Chilled `tgt` (own only)?
func _chilled_by_me(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from("chilled", player)

## Thin Ice: Glacial Draw's cast time on a target I have Chilled, `less` seconds
## shorter (never under 0.2 s). Unchanged on anything else.
static func thin_ice_cast(cast: float, less: float, chilled: bool) -> float:
	return maxf(cast - maxf(less, 0.0), 0.2) if chilled else cast

## Clean Shatter: what is left of Shatter Shot's cooldown with `off` seconds taken away.
static func clean_shatter_cooldown(left: float, off: float) -> float:
	return maxf(left - maxf(off, 0.0), 0.0)

# --- Frozen Instinct: freezes can make the next Frost spell with a cast time instant and free

const INSTINCT_ID := "frozen_instinct"
var _instinct_cast := false   # the current cast is the instant Frozen Instinct one

## Can Frozen Instinct make spell `id` instant and free (a Frost spell with a cast time)?
static func instinct_applies(id: String) -> bool:
	var res := Abilities.get_resource(id)
	return res != null and float(res.cast_time) > 0.0 and FrostTalentsKit.is_frost_spell(res.tags)

func _grant_frozen_instinct() -> void:
	if player.status == null or player.is_dead():
		return
	var fx := StatusContainer.make_buff(INSTINCT_ID, "Frozen Instinct", INSTINCT_ID, 0.0,
		Balance.FROZEN_INSTINCT_TIME, 1, Color(0.6, 0.9, 1.0))
	fx.stat_modifiers = {}
	fx.description = "Your next Frost spell with a cast time is instant and free."
	player.status.apply(fx, player)

## Is the next Frost spell with a cast time instant and free?
func frozen_instinct_ready() -> bool:
	return player.status != null and player.status.has(INSTINCT_ID)


