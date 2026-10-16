extends "res://scripts/player/player_kit.gd"
class_name LightningMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "lightning_melee".
# --- Lightning melee ------------------------------------------------------------------------
# The Energy bar with a weapon. Charged Edge and Whiplash give Energy; Arc
# Cleave, Cadence, Twin Current, Static Step and Reflex Arc spend it; Overdrive
# only lasts while the bar is kept low; Faraday Guard takes hits out of it.
# Polar Strike is taught by the Rune of Polarity. Numbers are in balance.gd.

const OVERDRIVE_ID := "overdrive"
const OVERDRIVE_FX := "overdrive"
const TWIN_CURRENT_ID := "twincurrent"
const TWIN_CURRENT_FX := "twin_current"
const STATIC_STEP_ID := "staticstep"
const STATIC_STEP_FX := "static_step"
const BACK_CURRENT_ID := "backcurrent"
const BACK_CURRENT_FX := "back_current"
const CADENCE_ID := "cadence"
const CADENCE_FX := "cadence"
const SPLIT_SECOND_ID := "splitsecond"
const SPLIT_SECOND_FX := "split_second"
const WHIPLASH_ID := "whiplash"
const FARADAY_ID := "faradayguard"
const FARADAY_FX := "faraday_guard"
const REFLEX_ID := "reflexarc"
const REFLEX_FX := "reflex_arc"
const POLAR_ID := "polarstrike"
const POLARITY_FX := "polarity"
## Names of the modifiers these put on a hit (the damage meter's lines, and how
## _on_hit_taken knows a hit on me was changed by them).
const STATIC_STEP_LABEL := "Static Step"
const POLARITY_LABEL := "Polarity"
const FARADAY_LABEL := "Faraday Guard"
const REFLEX_LABEL := "Reflex Arc"
## A modifier this size takes a hit down to nothing.
const AVOID_PCT := 1000.0
## Instant abilities taught by runes (used like the drafted ones).
const RUNE_INSTANTS := [POLAR_ID]
const LASH = preload("res://scripts/lash.gd")
var _polar_positive := false   # the charge my last Polar Strike left
var _charges_used := {}        # "your next weapon ability" buffs used this frame (gone at its end)

## A buff of this kit: no stats of its own, a marker with a text.
func _melee_buff(fx_id: String, ability_id: String, time: float, text: String, stacks: int = 1) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, Abilities.ability_name(ability_id), fx_id, 0.0, time, stacks,
		Abilities.color_of(ability_id))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = text
	return fx

## Is this a melee attack (what Reflex Arc avoids and Back-Current answers)?
## Never damage over time.
static func is_melee_attack(tags: PackedStringArray, is_dot: bool) -> bool:
	return not is_dot and tags.has("Melee")

## The percent a modifier named `label` put on a hit (0 if it carries none).
static func bonus_named(parts: Array, label: String) -> float:
	var total := 0.0
	for p in parts:
		if p is Array and p.size() >= 2 and str(p[0]) == label:
			total += float(p[1])
	return total

## Arc Cleave: everything around me is hit; more than AOE_TARGET_CAP enemies
## share that many hits' damage.
func _arc_cleave(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(str(res.id))
	var hit := player._enemies_within(float(res.radius))
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, str(res.id))
	for i in 2:
		player._slash_effect(col)
	player._ring_effect(float(res.radius), col)

# Overdrive: faster auto-attacks that zap and give Energy, for as long as the
# Energy is spent again. It cannot start above the limit and ends above it.

## Energy above which Overdrive cannot be used and ends: a share of the bar
## (`max_energy`: bigger with Deep Reserves).
static func overdrive_limit(max_energy: float = Balance.RESOURCE_MAX) -> float:
	return max_energy * Balance.OVERDRIVE_ENERGY_LIMIT_PCT / 100.0

## Does Overdrive allow this much Energy? (Exactly the limit is fine.)
static func overdrive_holds(energy: float, max_energy: float = Balance.RESOURCE_MAX) -> bool:
	return energy <= overdrive_limit(max_energy) + 0.0001

# Lightning talents (the numbers per rank are in talents.gd).

## Energy per second at `base`, regenerating `pct`% faster (Quick Charge).
static func energy_regen(base: float, pct: float) -> float:
	return base * (1.0 + maxf(pct, 0.0) / 100.0)

## Running on Empty: does this hit of mine get it? Lightning damage of a spell or
## an ability, while I hold less than RUNNING_ON_EMPTY_ENERGY Energy.
static func running_on_empty(damage_type: String, tags: PackedStringArray, energy: float) -> bool:
	return damage_type == "lightning" and (tags.has("Spell") or tags.has("Ability")) \
		and energy < Balance.RUNNING_ON_EMPTY_ENERGY

## Running Start: did a Static Step of `metres` carry me far enough?
static func running_start_applies(metres: float) -> bool:
	return metres >= Balance.RUNNING_START_DISTANCE - 0.001

## Seconds Redline adds to an Overdrive it already made `added` seconds longer,
## at `per` seconds a spender: never past REDLINE_MAX in total.
static func redline_add(per: float, added: float) -> float:
	return clampf(per, 0.0, maxf(Balance.REDLINE_MAX - added, 0.0))

var _overdrive_added := 0.0    # seconds Redline has added to the running Overdrive
var _cadence_third := false    # the hits being dealt are Cadence's third strike (Third Beat)

## Redline: an ability of mine just spent Energy. With Overdrive up it lasts longer.
func _redline() -> void:
	var per := player._talent("lightning_redline")
	if per <= 0.0 or player.status == null or not player.status.has(OVERDRIVE_FX):
		return
	var add := redline_add(per, _overdrive_added)
	if add <= 0.0:
		return
	_overdrive_added += add
	player.status.set_remaining(OVERDRIVE_FX, player.status.remaining_of(OVERDRIVE_FX) + add)

## Seconds between the auto-attacks of a weapon with `interval`, at `haste`
## (haste_mult), with Overdrive up or not.
## `attack_speed_pct` = % faster from attack speed buffs (Tempo), on top of both.
static func auto_interval(interval: float, haste: float, overdriven: bool, attack_speed_pct: float = 0.0) -> float:
	var speed := maxf(haste, 0.01)
	if overdriven:
		speed *= 1.0 + Balance.OVERDRIVE_SPEED_PCT / 100.0
	speed *= 1.0 + maxf(attack_speed_pct, 0.0) / 100.0
	return interval / speed

func overdrive_active() -> bool:
	return player.status != null and player.status.has(OVERDRIVE_FX)

func _start_overdrive() -> void:
	var col := Abilities.color_of(OVERDRIVE_ID)
	_overdrive_added = 0.0
	player.status.apply(_melee_buff(OVERDRIVE_FX, OVERDRIVE_ID, Balance.OVERDRIVE_TIME,
		"Your auto-attacks are %s%% faster; each one that lands zaps the target and gives you %s Energy. Ends the moment you have more than %s Energy." % [
			Stats.num(Balance.OVERDRIVE_SPEED_PCT), Stats.num(Balance.OVERDRIVE_ENERGY), Stats.num(overdrive_limit(player.resource_max("energy")))]), player)
	player._slash_effect(col)
	player._ring_effect(1.2, col)

## Every frame: Overdrive ends the moment I hold more Energy than it allows.
func _tick_overdrive() -> void:
	if player.status != null and player.status.has(OVERDRIVE_FX) \
			and not overdrive_holds(float(player.resources["energy"]), player.resource_max("energy")):
		player.status.remove(OVERDRIVE_FX)

## Lightning damage Twin Current adds to an auto-attack that dealt `amount`.
static func twin_current_damage(amount: int) -> float:
	return maxf(float(amount) * Balance.TWIN_CURRENT_PCT / 100.0, 0.0)

## Twin Current: a fresh set of charges (never more than TWIN_CURRENT_HITS).
func _start_twin_current() -> void:
	var col := Abilities.color_of(TWIN_CURRENT_ID)
	player.status.remove(TWIN_CURRENT_FX)
	player.status.apply(_melee_buff(TWIN_CURRENT_FX, TWIN_CURRENT_ID, Balance.TWIN_CURRENT_TIME,
		"Your next auto-attacks hit a second time for %s%% of their damage as Lightning damage, one stack each." % Stats.num(Balance.TWIN_CURRENT_PCT),
		Balance.TWIN_CURRENT_HITS), player)
	player.status.set_stacks(TWIN_CURRENT_FX, Balance.TWIN_CURRENT_HITS)
	for i in 2:
		player._slash_effect(col)

## An auto-attack of mine landed (SignalBus.damage_dealt). Twin Current repeats
## part of it: an exact share of the swing (its crit is already in it), dealt
## as a proc so it feeds nothing else. Overdrive zaps the target and gives Energy.
func _on_auto_landed(info: RefCounted) -> void:
	if player.status == null or int(info.amount) <= 0:
		return
	var foe: Node = info.target
	var charged := player._talent("lightning_charged_strikes")   # Charged Strikes: every auto-attack gives Energy
	if charged > 0.0:
		player._gain("energy", charged)
	if player.status.has(TWIN_CURRENT_FX):
		# Hot Wire: a chance the echo doesn't use up a charge.
		if randf() * 100.0 >= player._talent("lightning_hot_wire"):
			player.status.spend_stacks(TWIN_CURRENT_FX, 1)
		if foe.is_alive():
			var extra := DamageInfo.make(player, foe, 1.0, TWIN_CURRENT_ID)
			extra.unit = twin_current_damage(int(info.amount))
			extra.exact = true
			extra.add_power = false
			extra.can_crit = false
			extra.can_block = false
			extra.is_proc = true
			extra.damage_type = "lightning"
			extra.tags = PackedStringArray(["Lightning", "Melee"])
			player._combat().deal(extra)
	if player.status.has(OVERDRIVE_FX):
		if is_instance_valid(foe) and foe.is_alive():
			player.deal_damage(foe, float(Abilities.get_resource(OVERDRIVE_ID).damage), OVERDRIVE_ID, true)
		player._gain("energy", Balance.OVERDRIVE_ENERGY)

## Metres Static Step travels toward a target `gap` metres away (edge to edge):
## it stops well inside the weapon's `reach`, and never goes backwards.
static func static_step_travel(gap: float, reach: float) -> float:
	return maxf(gap - reach * 0.5, 0.0)

## Static Step: a dash to my target (it stops short of walls, like Blink), and
## my next weapon ability hits harder.
func _static_step(w: Dictionary) -> void:
	var col := Abilities.color_of(STATIC_STEP_ID)
	if player.status.has(BottledLightningKit.WHIP_CRACK_FX):
		player.status.remove(BottledLightningKit.WHIP_CRACK_FX)   # Whip Crack: that was the cheaper one (it was paid for already)
	var from := player.global_position
	if player._has_valid_target():
		var gap := Vector2(player.target.global_position.x - from.x, player.target.global_position.z - from.z).length() \
			- Combat.hitbox_radius(player.target) - Combat.hitbox_radius(player)
		var want := static_step_travel(gap, float(w.get("attack_range", 1.5)))
		var dist := minf(player._dash_distance(want), want) if want > 0.0 else 0.0
		if dist > 0.0:
			var to := from + player._flat_forward() * dist
			# Up or down a slope with the target: as far along the climb as along the dash.
			to.y = from.y + (Combat.feet_y(player.target) - Combat.feet_y(player)) * dist / want + 0.05
			player.global_position = to
			if running_start_applies(dist):
				player._gain("energy", player._talent("lightning_running_start"))   # Running Start: a long dash gives Energy
	player._ring_effect(0.8, col, from)
	player._ring_effect(0.8, col)
	LASH.spawn(player.get_tree().current_scene, from + Vector3(0, 0.3, 0), player.global_position + Vector3(0, 0.3, 0), col)
	player.status.apply(_melee_buff(STATIC_STEP_FX, STATIC_STEP_ID, Balance.STATIC_STEP_TIME,
		"Your next weapon ability deals %s%% more damage." % Stats.num(Balance.STATIC_STEP_PCT)), player)

## Is this hit of mine a weapon ability's own hit? (What Static Step and Polar
## Strike empower: not auto-attacks, not procs, not damage over time.)
static func is_weapon_ability_hit(id: String, is_proc: bool, is_dot: bool) -> bool:
	return not is_proc and not is_dot and not id.begins_with("auto_") and Abilities.uses_weapon(id)

## Does Polar Strike's charge empower ability `id`? Any weapon ability but Polar Strike itself.
static func polarity_applies(id: String) -> bool:
	return id != POLAR_ID

## A hit of mine is being worked out (_on_damage_modify): Static Step and the
## charge of Polar Strike make my next weapon ability hit harder. Every hit of
## that ability landing this frame gets it (an AoE uses it once).
func _empower_weapon_ability(info: RefCounted, id: String) -> void:
	if player.status == null or not is_weapon_ability_hit(id, bool(info.is_proc), bool(info.is_dot)):
		return
	if player.status.has(STATIC_STEP_FX):
		info.add_bonus(Balance.STATIC_STEP_PCT, STATIC_STEP_LABEL)
		_use_charge(STATIC_STEP_FX)
	if polarity_applies(id) and player.status.has(POLARITY_FX):
		info.add_bonus(Balance.POLARITY_PCT, POLARITY_LABEL)
		_use_charge(POLARITY_FX)

## A "your next weapon ability" buff was used: it is gone at the end of the frame.
func _use_charge(fx_id: String) -> void:
	if _charges_used.has(fx_id):
		return
	if _charges_used.is_empty():
		_drop_used_charges.call_deferred()
	_charges_used[fx_id] = true

func _drop_used_charges() -> void:
	for fx_id in _charges_used:
		if player.status != null:
			player.status.remove(str(fx_id))
	_charges_used.clear()

func _start_back_current() -> void:
	var col := Abilities.color_of(BACK_CURRENT_ID)
	player.status.apply(_melee_buff(BACK_CURRENT_FX, BACK_CURRENT_ID, Balance.BACK_CURRENT_TIME,
		"Every melee hit you take zaps the attacker and gives you %s Energy." % Stats.num(Balance.BACK_CURRENT_ENERGY)), player)
	player._ring_effect(1.3, col)

## Which press of Cadence comes next (0 = the first) after `stacks` presses.
static func cadence_step(stacks: int) -> int:
	return clampi(stacks, 0, Balance.CADENCE_MULTS.size() - 1)

## Weapon damage multiplier of that press.
static func cadence_mult(step: int) -> float:
	return float(Balance.CADENCE_MULTS[clampi(step, 0, Balance.CADENCE_MULTS.size() - 1)])

## Cadence: each press in time hits harder; the last also hits everything
## around me (more than AOE_TARGET_CAP enemies share that many hits' damage),
## then the count starts over.
func _cadence(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(CADENCE_ID)
	var last := Balance.CADENCE_MULTS.size() - 1
	var step := cadence_step(int(player.status.stacks_of(CADENCE_FX)))
	var coef := float(w.get("damage", 0.0)) * cadence_mult(step) + float(res.damage)
	if step < last:
		player.status.apply(_melee_buff(CADENCE_FX, CADENCE_ID, Balance.CADENCE_WINDOW,
			"Your next Cadence hits harder. The count is lost after %s sec." % Stats.num(Balance.CADENCE_WINDOW), last), player)
		player.deal_damage(player.target, coef, CADENCE_ID)
		player._slash_effect(col)
		return
	player.status.remove(CADENCE_FX)
	var hit := player._enemies_within(float(res.radius))
	if not hit.has(player.target):
		hit.append(player.target)   # in weapon reach, but outside the burst's
	var share := Balance.aoe_share(hit.size())
	_cadence_third = true   # Third Beat: these hits are the third strike (_on_damage_modify)
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef * share, CADENCE_ID)
	_cadence_third = false
	if player._capstone("lightning_third_beat"):
		player._gain("energy", Balance.THIRD_BEAT_ENERGY)
	for i in 2:
		player._slash_effect(col)
	player._ring_effect(float(res.radius), col)

## A global cooldown of `gcd` seconds with Split Second up: shorter, but never
## below SPLIT_SECOND_MIN_GCD (and never longer than it already was).
static func split_second_gcd(gcd: float) -> float:
	return maxf(gcd - Balance.SPLIT_SECOND_GCD, minf(gcd, Balance.SPLIT_SECOND_MIN_GCD))

func _start_split_second() -> void:
	var col := Abilities.color_of(SPLIT_SECOND_ID)
	player.status.apply(_melee_buff(SPLIT_SECOND_FX, SPLIT_SECOND_ID, Balance.SPLIT_SECOND_TIME,
		"Your global cooldown is %s sec shorter." % Stats.num(Balance.SPLIT_SECOND_GCD)), player)
	player._ring_effect(1.0, col)
	player._ring_effect(0.6, Color(0.95, 0.95, 1.0))

## Whiplash: an instant hit from afar, drawn as a line of lightning.
func _whiplash(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(WHIPLASH_ID)
	var from := player._muzzle()
	LASH.spawn(player.get_tree().current_scene, from, player.target.global_position + Vector3(0, 0.3, 0), col)
	player._net_fx("lash", from, player.target, {"c": col})
	player._slash_effect(col)
	var away := Vector2(player.target.global_position.x - player.global_position.x, player.target.global_position.z - player.global_position.z).length()
	if player.deal_damage(player.target, player._weapon_hit(w, res), WHIPLASH_ID) > 0 and BottledLightningKit.whip_crack_applies(away):
		player.bottled_kit._whip_crack()   # Whip Crack: a long lash readies a cheaper Static Step

## Energy Faraday Guard pays for `spared` damage at `max_hp` max health.
static func faraday_energy(spared: float, max_hp: float) -> float:
	if max_hp <= 0.0 or Balance.FARADAY_GUARD_HEALTH_PCT <= 0.0:
		return 0.0
	return maxf(spared, 0.0) / max_hp * 100.0 / Balance.FARADAY_GUARD_HEALTH_PCT * Balance.FARADAY_GUARD_ENERGY

func _start_faraday_guard() -> void:
	var col := Abilities.color_of(FARADAY_ID)
	player.status.apply(_melee_buff(FARADAY_FX, FARADAY_ID, Balance.FARADAY_GUARD_TIME,
		"You take %s%% less damage; your Energy pays for it instead. Ends if you run out of Energy." % Stats.num(Balance.FARADAY_GUARD_PCT)), player)
	player._ring_effect(1.4, col)
	player._ring_effect(0.9, Color(0.95, 0.95, 1.0))

func _start_reflex_arc() -> void:
	var col := Abilities.color_of(REFLEX_ID)
	player.status.apply(_melee_buff(REFLEX_FX, REFLEX_ID, Balance.REFLEX_ARC_TIME,
		"The next melee attack against you is avoided, counting as both a parry and a block, and you strike back."), player)
	player._slash_effect(col)
	player._ring_effect(1.0, col)

## A hit on me is being worked out (_on_damage_modify). Reflex Arc turns the next
## melee attack into nothing (its effects too); Faraday Guard takes a share off
## every hit while I have Energy to pay for it (_melee_kit_hit_taken does the rest).
func _guard_incoming(info: RefCounted) -> void:
	if player.status == null:
		return
	if player.status.has(REFLEX_FX) and is_melee_attack(info.tags, bool(info.is_dot)):
		info.add_bonus(-AVOID_PCT, REFLEX_LABEL)
		info.effects = []
		info.force_parry_block = true   # it counts as a parry AND a block (CombatSystem.force_avoid)
		return
	if player.status.has(FARADAY_FX) and float(player.resources["energy"]) > 0.0:
		info.add_bonus(-Balance.FARADAY_GUARD_PCT, FARADAY_LABEL)

## Something hit me (_on_hit_taken): Reflex Arc's strike back, Faraday Guard's
## bill, Back-Current's zap.
func _melee_kit_hit_taken(info: RefCounted) -> void:
	var foe: Variant = info.source
	var foe_ok: bool = foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_in_group("enemies") and foe.is_alive()
	# Reflex Arc: that attack did nothing. The strike back is the ability's own hit.
	if bonus_named(info.bonus_parts, REFLEX_LABEL) != 0.0:
		player.status.remove(REFLEX_FX)
		var col := Abilities.color_of(REFLEX_ID)   # (CombatSystem already showed "Parry")
		var w := player._weapon()
		if foe_ok and w.get("weapon", "") == "melee":
			var at: Vector3 = foe.global_position
			player.deal_damage(foe, player._weapon_hit(w, Abilities.get_resource(REFLEX_ID)), REFLEX_ID)
			player._slash_effect(col)
			player._ring_effect(0.7, col, at)
		return
	# Faraday Guard: what it spared me comes out of my Energy; at none it ends.
	var spared_pct := -bonus_named(info.bonus_parts, FARADAY_LABEL)
	if spared_pct > 0.0 and not info.blocked and int(info.amount) > 0:
		var spared := Player.heat_sink_stored(float(info.amount), float(info.bonus_pct), spared_pct)
		player.resources["energy"] = maxf(float(player.resources["energy"]) - faraday_energy(spared, float(player.max_health)), 0.0)
		if float(player.resources["energy"]) <= 0.0:
			player.status.remove(FARADAY_FX)
	# Back-Current: a melee hit that landed gives Energy and zaps whoever dealt it.
	if player.status.has(BACK_CURRENT_FX) and not info.blocked and int(info.amount) > 0 \
			and is_melee_attack(info.tags, bool(info.is_dot)):
		player._gain("energy", Balance.BACK_CURRENT_ENERGY)
		if foe_ok:
			player.deal_damage(foe, float(Abilities.get_resource(BACK_CURRENT_ID).damage), BACK_CURRENT_ID, true)

## Polar Strike (Rune of Polarity): the hit, then my charge flips. The charge
## empowers my next OTHER weapon ability; another Polar Strike only flips it.
func _polar_strike(w: Dictionary, res: Resource) -> void:
	player.deal_damage(player.target, player._weapon_hit(w, res), POLAR_ID)
	_polar_positive = not _polar_positive
	var fx := _melee_buff(POLARITY_FX, POLAR_ID, Balance.POLARITY_TIME,
		"Your next weapon ability other than %s deals %s%% more damage." % [Abilities.ability_name(POLAR_ID), Stats.num(Balance.POLARITY_PCT)])
	fx.display_name = "Positive Charge" if _polar_positive else "Negative Charge"
	fx.color = Color(0.6, 0.9, 1.0) if _polar_positive else Color(1.0, 0.5, 0.4)
	player.status.remove(POLARITY_FX)   # (a fresh buff: its name and colour follow the charge)
	player.status.apply(fx, player)
	for i in 2:
		player._slash_effect(fx.color)

