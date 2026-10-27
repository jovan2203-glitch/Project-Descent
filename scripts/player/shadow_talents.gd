extends "res://scripts/player/player_kit.gd"
class_name ShadowTalentsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "shadow_talents".
# --- Shadow: the open talents ---------------------------------------------------------------
# Talents of the Shadow book that work with every book's spells and abilities:
# Slow Death (my damage over time hits harder), Wasting (it ticks more often:
# the StatusContainer asks dot_speed_mult, Decay asks decay_interval), Finish It
# (more damage to enemies low on health), Spite (taking damage boosts my next
# spell or ability), Carrion (an enemy dying with my damage over time on it
# gives mana back) and Inevitable (more damage to enemies I have been on for a
# while). Finish It, Spite and Inevitable are % modifiers, so they never touch
# Decay's own damage (that is exact); Slow Death and Wasting do count for it.
# Numbers: balance.gd and talents.gd.

const SPITE_FX := "spite"
var _spite_id := ""            # the spell / ability that is using Spite's boost up
var _spite_until := 0.0        # ... and until when its hits still get it
var _first_hit := {}           # enemy instance id -> time of my first damage to it (Inevitable)

## How many times as often my damage over time ticks with `wasting_pct` % from
## Wasting on top of `base` (what something else already does for it).
static func dot_speed_with(base: float, wasting_pct: float) -> float:
	return base * (1.0 + maxf(wasting_pct, 0.0) / 100.0)

## Finish It: is an enemy with this health low enough?
static func finish_it_applies(health: float, max_health: float) -> bool:
	return max_health > 0.0 and health / max_health * 100.0 < Balance.FINISH_IT_HEALTH_PCT

## Inevitable: have I been on an enemy I first damaged at `first_hit` (a time; 0 =
## never) for long enough at `now`?
static func inevitable_applies(first_hit: float, now: float) -> bool:
	return first_hit > 0.0 and now - first_hit > Balance.INEVITABLE_TIME

## Carrion: the mana `pct` % of a mana pool of `max_mana` is.
static func carrion_mana(max_mana: float, pct: float) -> float:
	return maxf(max_mana, 0.0) * maxf(pct, 0.0) / 100.0

## Deep Call: a Shadow spell of mine that hurts (not a heal; its cast time is what it cuts).
static func deep_call_spell(tags: PackedStringArray) -> bool:
	return DecayKit.shadow_spell(tags) and not tags.has("Heal")

## Hungry Dark: does a hit get it? A Shadow spell's own hit (no tick, no proc) on an
## enemy whose Breach of mine is open.
static func hungry_dark_applies(tags: PackedStringArray, is_proc: bool, is_dot: bool, breach_open: bool) -> bool:
	return breach_open and DecayKit.shadow_spell(tags) and not is_proc and not is_dot

## Blood Up: does a hit get it? The own hit of a Shadow ability that costs Fury,
## while my Hounds are Roused.
static func blood_up_applies(tags: PackedStringArray, spends_fury: bool, is_proc: bool, roused: bool) -> bool:
	return roused and spends_fury and tags.has("Shadow") and tags.has("Ability") and not is_proc

## Snarl: Fury a Shadow ability `id` builds, `amount` with `pct` % more.
static func snarl_fury(id: String, amount: float, pct: float) -> float:
	var tags := Abilities.tags_of(id)
	if pct <= 0.0 or Abilities.resource_of(id) != "fury" or not (tags.has("Shadow") and tags.has("Ability")):
		return amount
	return amount * (1.0 + pct / 100.0)

const ILL_WILL_LABEL := "Ill Will"

## A hit of mine that just rolled a critical strike (CombatSystem.deal asks,
## for every hit, exact ones like my Breach's ticks too): [percent, label] it
## gets on top, or [] for none. Ill Will: crits of my damage over time.
func crit_hit_bonus(info: RefCounted) -> Array:
	return ill_will_bonus(bool(info.is_dot), player._talent("shadow_ill_will"))

static func ill_will_bonus(is_dot: bool, pct: float) -> Array:
	return [pct, ILL_WILL_LABEL] if is_dot and pct > 0.0 else []

## A hit of mine, before its damage is worked out (_on_damage_modify): Slow
## Death, Finish It, Inevitable, Hungry Dark, Blood Up, Spite.
func _shadow_talents_modify(info: RefCounted, id: String) -> void:
	# Slow Death: my damage over time hits harder.
	if bool(info.is_dot):
		var slow := player._talent("shadow_slow_death")
		if slow > 0.0:
			info.add_bonus(slow, "Slow Death")
	var foe: Variant = info.target
	if foe != null and is_instance_valid(foe) and foe is Node:
		var hp: Variant = foe.get("health")
		var max_hp: Variant = foe.get("max_health")
		if hp != null and max_hp != null:
			# Finish It: enemies low on health.
			var finish := player._talent("shadow_finish_it")
			if finish > 0.0 and finish_it_applies(float(hp), float(max_hp)):
				info.add_bonus(finish, "Finish It")
			# (An enemy back at full health starts over for Inevitable: it ran home and healed.)
			if float(hp) >= float(max_hp):
				_first_hit.erase((foe as Node).get_instance_id())
		# Inevitable: enemies I have been on for a while.
		var inevitable := player._talent("shadow_inevitable")
		if inevitable > 0.0 and inevitable_applies(float(_first_hit.get((foe as Node).get_instance_id(), 0.0)), player.decay._decay_now()):
			info.add_bonus(inevitable, "Inevitable")
		# Hungry Dark: my Shadow spells on an enemy whose Breach of mine is open.
		var hungry := player._talent("shadow_hungry_dark")
		if hungry > 0.0 and hungry_dark_applies(info.tags, bool(info.is_proc), bool(info.is_dot), player.decay.decay_open_on(foe)):
			info.add_bonus(hungry, "Hungry Dark")
		# Still Wet's capstone: my own direct hits also hit an enemy I Laid Open
		# harder (the Hounds' bites have Open Up's own bonus).
		if not bool(info.is_proc) and not bool(info.is_dot) and player.frost_melee._capstone("shadow_still_wet"):
			var wet: Node = (foe as Node).get_node_or_null("Status")
			if HoundsKit.still_wet_applies(true, wet != null and wet.has_from(HoundsKit.LAID_OPEN_FX, player), false, false):
				info.add_bonus(Balance.STILL_WET_PCT, HoundsKit.STILL_WET_LABEL)
	# Blood Up: my Shadow abilities that spend Fury, while my Hounds are Roused.
	var blood := player._talent("shadow_blood_up")
	if blood > 0.0 and blood_up_applies(info.tags, Abilities.resource_of(id) == "fury" and float(Abilities.cost_of(id)) > 0.0,
			bool(info.is_proc), player.status != null and player.status.has(HoundsKit.ROUSED_FX)):
		info.add_bonus(blood, "Blood Up")
	_spite_hit(info, id)

## Remember when I first damaged `foe` (Inevitable counts from then).
func _note_first_hit(foe: Node) -> void:
	var key := foe.get_instance_id()
	if _first_hit.has(key):
		return
	if _first_hit.size() >= 64:
		_first_hit.clear()   # (a long run: forget the old ones rather than keep every enemy ever hit)
	_first_hit[key] = player.decay._decay_now()

## Something damaged me (_on_hit_taken). Spite: my next spell or ability hits harder.
func _spite_on_hit_taken(info: RefCounted) -> void:
	if int(info.amount) <= 0 or info.avoided() or player._talent("shadow_spite") <= 0.0:
		return
	if player.status.has(SPITE_FX) and player.status.remaining_of(SPITE_FX) > Balance.SPITE_TIME - 0.5:
		return   # (it was just renewed: a pack hitting me doesn't rebuild it on every blow)
	var fx := StatusContainer.make_buff(SPITE_FX, "Spite", SPITE_FX, 0.0, Balance.SPITE_TIME, 1, Abilities.color_of(DecayKit.BLIGHT_ID))
	fx.stat_modifiers = {}
	fx.description = "Your next spell or ability deals more damage."
	player.status.apply(fx, player)

## A hit of mine, before its damage is worked out. Spite: the first spell or
## ability I hit with uses the boost, and every hit of that one use gets it
## (SPITE_HITS seconds: it may hit several enemies). Never an auto-attack, a
## proc or damage over time.
func _spite_hit(info: RefCounted, id: String) -> void:
	if not ArcaneOpenTalentsKit.echoes(info.tags, bool(info.is_proc), bool(info.is_dot), Abilities.PATHS.has(id)):
		return
	var now := player.decay._decay_now()
	if player.status != null and player.status.has(SPITE_FX):
		player.status.remove(SPITE_FX)
		_spite_id = id
		_spite_until = now + Balance.SPITE_HITS
	elif id != _spite_id or now > _spite_until:
		return
	var pct := player._talent("shadow_spite")
	if pct > 0.0:
		info.add_bonus(pct, "Spite")

## An enemy died (SignalBus.enemy_died). Carrion: if it carried one of my damage
## over time effects (it noted who had one as it died), I get some mana back.
func _on_enemy_died_shadow(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var key := enemy.get_instance_id()
	var by_me: bool = enemy.has_method("killed_by_me") and bool(enemy.killed_by_me())
	var damaged := _first_hit.has(key) or by_me
	var dragged := float(player.hounds._drag_watch.get(key, 0.0))
	_first_hit.erase(key)
	player.hounds._drag_watch.erase(key)
	if player.is_dead():
		return
	# Take It With You's capstone: Drag Down killed it, so my next pair arrives Roused.
	if HoundsKit.drag_kill_counts(player.hounds._hound_now(), dragged, by_me) and player.frost_melee._capstone("shadow_take_it_with_you"):
		player.hounds._hounds_roused_next = true
	# Feeding Frenzy: an enemy I damaged died.
	var frenzy := player._talent("shadow_feeding_frenzy")
	if frenzy > 0.0 and damaged:
		player.add_buff(HoundsKit.FEEDING_FRENZY_FX, Stats.HASTE, frenzy, Balance.FEEDING_FRENZY_TIME, 1, "Feeding Frenzy")
	var pct := player._talent("shadow_carrion")
	if pct <= 0.0:
		return
	var owners: Variant = enemy.get("dot_owners_at_death")
	if owners is Dictionary and (owners as Dictionary).has(player.get_instance_id()):
		player._gain("mana", carrion_mana(player.resource_max("mana"), pct))

