extends "res://scripts/player/player_kit.gd"
class_name FrostTalentsKit

# The Frost book's talents of the column-group tree (talents.gd) that change a hit,
# a heal or a shield, or answer a Freeze: damage and threat bonuses on my hits
# (each its own line: info.add_bonus with the talent's name), less damage taken,
# the hits that land (Ice Needles, Shiver, Cold Swing, the bow's), Freezing and
# thawing (frost_melee's scan of my slows calls _on_freeze / _on_thaw), heals and
# shields (Cold Comfort). The rest of the Frost talents live with the rules they
# change, in each spec's component (frost_healer.gd, frost_steel.gd,
# frost_glacier.gd, frost_bow.gd, frost_runes_talents.gd). Hooked up from
# player.gd through its var "frost_talents". Own only: every "Chilled", "Frozen",
# "rooted" or "shield" here is mine.

## Meter / log id of Splitting Arrow's hit and Cold Retort's (Details.HIT_NAMES).
const SPLITTING_ARROW_ID := "splittingarrow"
const COLD_RETORT_ID := "coldretort"
## The finishers of Frostbitten Steel (they spend all the Glaze).
const FINISHERS := ["calving", "icebreaker"]
## Thaw Strike's buff on me: the next finisher costs less Fury.
const THAW_STRIKE_FX := "thaw_strike"

var _cold_well_ready := 0.0
var _meltdown_ready := 0.0
var _shiver_ready := 0.0
var _swings := {}   # Cold Swing: melee ability id -> [frame, enemies hit, paid]

# Rules as static functions (tests/test_frost_tree.gd).

## Is this hit a Frost spell's (not a tick)?
static func is_frost_spell(tags: PackedStringArray) -> bool:
	return tags.has("Frost") and tags.has("Spell")

## Does this hit Freeze its target (one of its effects is Frozen)?
static func freezes(effects: Array) -> bool:
	for e in effects:
		if e != null and str(e.get("id")) == "frozen":
			return true
	return false

## Is spell `id` one of my Frost spells that heal or shield (Cold Hands, Cold Rush)?
static func is_frost_care(id: String) -> bool:
	var t := Abilities.tags_of(id)
	return is_frost_spell(t) and (t.has("Heal") or t.has("Shield") or t.has("Defensive"))

## Cold Front: % more for `cold` enemies I have Chilled or Frozen (`pct` each).
static func cold_front_pct(cold: int, pct: float) -> float:
	return maxf(pct, 0.0) * clampi(cold, 0, Balance.COLD_FRONT_MAX)

## Bitter Hunt: % more for `slows` of mine on the target (`pct` each).
static func bitter_hunt_pct(slows: int, pct: float) -> float:
	return maxf(pct, 0.0) * maxi(slows, 0)

## Is `foe` carrying effect `id` from me?
func _has_mine(foe: Variant, id: String) -> bool:
	if foe == null or not is_instance_valid(foe) or not (foe is Node):
		return false
	var st: Node = foe.get_node_or_null("Status")
	return st != null and st.has_from(id, player)

func frozen_by_me(foe: Variant) -> bool:
	return _has_mine(foe, "frozen")

func chilled_by_me(foe: Variant) -> bool:
	return _has_mine(foe, "chilled")

## Is `foe` held by a root of mine (any effect of mine that roots)?
func rooted_by_me(foe: Variant) -> bool:
	if foe == null or not is_instance_valid(foe) or not (foe is Node):
		return false
	var st: Node = foe.get_node_or_null("Status")
	if st == null:
		return false
	for k in st.effects:
		var res: Resource = st.effects[k]["res"]
		if bool(res.get("root")) and st.has_from(str(res.id), player):
			return true
	return false

## Does anything here need frost_melee's scan of my slows (Freezes and thaws)?
func wants_slow_scan() -> bool:
	for key in ["frost_cold_well", "frost_ice_hunger", "frost_thaw_strike", "frost_cold_front"]:
		if player._talent(key) > 0.0:
			return true
	return false

# --- My hits ------------------------------------------------------------------------------

## A hit of mine, before its damage is worked out (Player._on_damage_modify).
func _frost_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var tags: PackedStringArray = info.tags
	var tgt: Variant = info.target
	var spell := is_frost_spell(tags)
	var frost_ability := tags.has("Frost") and tags.has("Ability")
	var frozen := frozen_by_me(tgt)
	# Hard Winter.
	if spell and frozen:
		_bonus(info, "frost_glass_cold", "Glass Cold")
	if spell and tgt is Node3D:
		var drift := player._talent("frost_snowdrift")
		if drift > 0.0 and player._enemies_near((tgt as Node3D).global_position, Balance.SNOWDRIFT_RADIUS, tgt).size() >= Balance.SNOWDRIFT_CROWD:
			info.add_bonus(drift, "Snowdrift")
	if spell:
		var front := cold_front_pct(player.frost_melee.cold_count(), player._talent("frost_cold_front"))
		if front > 0.0:
			info.add_bonus(front, "Cold Front")
	# Frostbitten Steel.
	if frost_ability and not info.is_dot:
		var sharp := player._talent("frost_sharp_glaze") * maxi(player.frost_steel.glaze(), player.frost_steel._spending)
		if sharp > 0.0:
			info.add_bonus(sharp, "Sharp Glaze")
		if not info.is_proc and freezes(info.effects):
			_bonus(info, "frost_third_bite", "Third Bite")
	if FINISHERS.has(id) and not info.is_proc and (frozen or player.frost_more._icebreaker_on_frozen):
		_bonus(info, "frost_splitting_cold", "Splitting Cold")
	# Glacier Wall.
	var layers: int = player.glacier.layers()
	if layers > 0:
		var press := player._talent("frost_rime_pressure") * layers
		if press > 0.0:
			info.threat_multiplier *= 1.0 + press / 100.0
		if tags.has("Ability") and layers >= player.glacier._cap():
			_bonus(info, "frost_full_strata", "Full Strata")
	# Winter Hunt.
	if FireTalentsKit.is_arrow(id, tags):
		if frozen:
			_bonus(info, "frost_frozen_quarry", "Frozen Quarry")
		if rooted_by_me(tgt):
			_bonus(info, "frost_pinning_frost", "Pinning Frost")
		var slows := int(chilled_by_me(tgt)) + int(frozen) + int(rooted_by_me(tgt))
		var hunt := bitter_hunt_pct(slows, player._talent("frost_bitter_hunt"))
		if hunt > 0.0:
			info.add_bonus(hunt, "Bitter Hunt")
	if id == "auto_ranged":
		if chilled_by_me(tgt):
			_bonus(info, "frost_frost_fletching", "Frost Fletching")
		if frozen:
			_bonus(info, "frost_numb_prey", "Numb Prey")

func _bonus(info: RefCounted, key: String, label: String) -> void:
	var v := player._talent(key)
	if v > 0.0:
		info.add_bonus(v, label)

## A hit on me, before its damage is worked out.
func _frost_talents_incoming(info: RefCounted) -> void:
	# Winter Coat (open): every spell hits me a little less.
	if info.tags.has("Spell"):
		var coat := player._talent("frost_winter_coat")
		if coat > 0.0:
			info.add_bonus(-coat, "Winter Coat")
	# Steady Footing: enough Ice Layers and every hit is a little smaller.
	if player.glacier.layers() >= Balance.STEADY_FOOTING_LAYERS:
		var steady := player._talent("frost_steady_footing")
		if steady > 0.0:
			info.add_bonus(-steady, "Steady Footing")

## [pct, label] for a crit of mine (Player.crit_hit_bonus): Cold Eye.
func crit_hit_bonus(info: RefCounted) -> Array:
	var eye := player._talent("frost_cold_eye")
	if eye > 0.0 and FireTalentsKit.is_arrow(str(info.ability_id), info.tags) and frozen_by_me(info.target):
		return [eye, "Cold Eye"]
	return []

## One of my hits landed (frost_runes._on_damage_dealt_frost).
func _on_hit(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var tags: PackedStringArray = info.tags
	var tgt: Node = info.target
	if bool(info.is_dot) or bool(info.is_proc):
		return
	# Ice Needles: a Frost spell crit may give an Ice Shard charge.
	if info.crit and is_frost_spell(tags) and randf() * 100.0 < player._talent("frost_ice_needles"):
		player.ice_shards_kit.gain_ice_shard()
	# Shiver: a crit on a target I have Frozen may give Glaze, now and then.
	var now := Time.get_ticks_msec() / 1000.0
	if info.crit and now >= _shiver_ready and frozen_by_me(tgt) and randf() * 100.0 < player._talent("frost_shiver"):
		_shiver_ready = now + Balance.SHIVER_EVERY
		player.frost_steel._gain_glaze(1)
	_cold_swing(id, tags)
	# The bow.
	if id == "auto_ranged" and tgt.is_alive() and randf() * 100.0 < player._talent("frost_rime_tips"):
		player.frost_more._chill(tgt, "rimetips", PackedStringArray(["Ability", "Frost", "Ranged"]))   # Rime Tips
	if FrostBowKit.is_arrow_ability(id):
		if chilled_by_me(tgt) and randf() * 100.0 < player._talent("frost_marked_ice"):
			player.ice_shards_kit.gain_ice_shard()   # Marked Ice
		if info.crit:
			var quiver := player._talent("frost_winter_quiver")
			if quiver > 0.0:
				player._gain("energy", quiver)   # Winter Quiver
		_sleet_arrows(id, tgt)
	if FireTalentsKit.is_arrow(id, tags):
		_splitting_arrow(info)

## Cold Swing: a melee ability of mine that hits enough enemies gives Fury (once a use:
## every hit of one use lands in the same frame).
func _cold_swing(id: String, tags: PackedStringArray) -> void:
	var v := player._talent("frost_cold_swing")
	if v <= 0.0 or not (tags.has("Ability") and tags.has("Melee")):
		return
	var frame := Engine.get_process_frames()
	var e: Array = _swings.get(id, [-1, 0, false])
	if int(e[0]) != frame:
		e = [frame, 0, false]
	e[1] = int(e[1]) + 1
	if not bool(e[2]) and int(e[1]) >= Balance.COLD_SWING_HITS:
		e[2] = true
		player._gain("fury", v)
	_swings[id] = e

## Sleet Arrows: an arrow ability that Chills its target Chills the enemies nearest it too.
func _sleet_arrows(id: String, tgt: Node) -> void:
	var n := int(round(player._talent("frost_sleet_arrows")))
	var res := Abilities.get_resource(id)
	if n <= 0 or res == null or res.on_hit_effect == null or str(res.on_hit_effect.id) != "chilled" or not (tgt is Node3D):
		return
	for e in player._enemies_near((tgt as Node3D).global_position, Balance.SLEET_ARROWS_RANGE, tgt).slice(0, n):
		player.frost_more._chill(e, id, PackedStringArray(["Ability", "Frost", "Ranged"]))

## Splitting Arrow: an arrow into a target I have Frozen splinters into another enemy.
func _splitting_arrow(info: RefCounted) -> void:
	var pct := player._talent("frost_splitting_arrow")
	var tgt: Variant = info.target
	if pct <= 0.0 or not (tgt is Node3D) or not frozen_by_me(tgt):
		return
	var others := player._enemies_near((tgt as Node3D).global_position, Balance.SPLITTING_ARROW_RANGE, tgt)
	if others.is_empty():
		return
	var extra := DamageInfo.make(player, others.pick_random(), 1.0, SPLITTING_ARROW_ID)
	extra.unit = float(info.amount) * pct / 100.0
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.is_proc = true
	extra.damage_type = "frost"
	extra.tags = PackedStringArray(["Ability", "Frost", "Ranged"])
	player._combat().deal(extra)

# --- Freezing and thawing (frost_melee._scan_my_slows) -----------------------------------

## I just Froze `enemy`.
func _on_freeze(_enemy: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var well := player._talent("frost_cold_well")
	if well > 0.0 and now >= _cold_well_ready:
		_cold_well_ready = now + Balance.COLD_WELL_EVERY
		player._gain("mana", well * player.mana_unit())   # Cold Well
	var hunger := player._talent("frost_ice_hunger")
	if hunger > 0.0:
		player._gain("energy", hunger)   # Ice Hunger

## A Freeze of mine ended (it ran out or was broken).
func _on_thaw() -> void:
	var v := player._talent("frost_thaw_strike")
	if v <= 0.0 or player.status == null or player.is_dead():
		return
	var fx := StatusContainer.make_buff(THAW_STRIKE_FX, "Thaw Strike", THAW_STRIKE_FX, 0.0, Balance.THAW_STRIKE_TIME, 1,
		Color(0.7, 0.92, 1.0))
	fx.stat_modifiers = {}
	fx.description = "Your next finisher costs %s less Fury." % Stats.num(v)
	player.status.apply(fx, player)

## Thaw Strike: what finisher `id` costs with the buff up (Player.resource_cost).
func finisher_cost(id: String, cost: float) -> float:
	if not FINISHERS.has(id) or player.status == null or not player.status.has(THAW_STRIKE_FX):
		return cost
	return maxf(cost - player._talent("frost_thaw_strike"), 0.0)

## A finisher was used: Thaw Strike's buff is spent.
func _finisher_used() -> void:
	if player.status != null:
		player.status.remove(THAW_STRIKE_FX)

# --- Auto-attacks -------------------------------------------------------------------------

## % faster auto-attacks / auto-shots against `foe` (Swift Ice).
func attack_speed_vs(foe: Variant) -> float:
	var v := player._talent("frost_swift_ice")
	return v if v > 0.0 and chilled_by_me(foe) else 0.0

## Extra Fury an auto-attack on `foe` gives (Rime Grip).
func auto_fury(foe: Variant, ranged: bool) -> float:
	var v := player._talent("frost_rime_grip")
	return v if v > 0.0 and not ranged and chilled_by_me(foe) else 0.0

# --- Heals and shields (Cold Comfort) -----------------------------------------------------

## My heals on `who` (StringsKit._heal_exact): Thaw Water, Ice Bath, Close Weave.
func heal_mult(who: Variant) -> float:
	if who == null or not is_instance_valid(who):
		return 1.0
	var pct := 0.0
	if player.frost_healer.my_thawing_on(who):
		pct += player._talent("frost_thaw_water")
	if player.frost_healer.has_my_frost_shield(who):
		pct += player._talent("frost_ice_bath")
	if player.frost_healer.is_linked(who):
		pct += player._talent("frost_close_weave")
	return 1.0 + pct / 100.0

## My Frost shields on `who` (Rime Shell, Rime Veil, Rimefall, Shard Spray): Frozen
## Hearth, and Last Shelter on an ally low on health.
func shield_mult(who: Variant) -> float:
	var pct := player._talent("frost_frozen_hearth")
	if who != null and is_instance_valid(who) and player.hymns._health_share_of(who) * 100.0 < Balance.LAST_SHELTER_HEALTH:
		pct += player._talent("frost_last_shelter")
	return 1.0 + pct / 100.0

## My Rime Shell on someone broke: Meltdown.
func _shell_broke() -> void:
	var v := player._talent("frost_meltdown")
	var now := Time.get_ticks_msec() / 1000.0
	if v > 0.0 and now >= _meltdown_ready:
		_meltdown_ready = now + Balance.MELTDOWN_EVERY
		player._gain("mana", v * player.mana_unit())

## Cold Rush: seconds off a Frost spell that heals or shields, cast on `who`.
func cold_rush(spell: String, who: Variant) -> float:
	var v := player._talent("frost_cold_rush")
	if v <= 0.0 or not is_frost_care(spell) or who == null or not is_instance_valid(who):
		return 0.0
	return v if player.hymns._health_share_of(who) * 100.0 < Balance.LAST_SHELTER_HEALTH else 0.0
