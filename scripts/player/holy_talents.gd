extends "res://scripts/player/player_kit.gd"
class_name HolyTalentsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "holy_talents".
# --- Holy: the open talents and the bottom row ------------------------------------------------
# Open (useful to anyone): Grace (my heals on others: _others_heal_mult), Steadfast
# (Block: PlayerData), Burnished (my Holy damage), Overflowing (overhealing becomes
# a shield), Penitent (a big hit makes my next heal on myself stronger: also
# heal_taken_mult), Zeal (faster after a long cooldown). The bottom row: Censer's
# Weight (the tank), Sunsteel (the archer), Radiance (both healers). Long Note is
# in _do_boom. Numbers: talents.gd and balance.gd.

const OVERFLOWING_FX := "overflowing"
const PENITENT_FX := "penitent"
const ZEAL_FX := "zeal"
## Holy heals that aren't an ability of the book (Radiance counts them too).
const HOLY_HEAL_PROCS := ["benediction", "chorale", "chorus_splash", "antiphon_self", "prism_shatter", "light_mote"]
## The tank's and the archer's procs (Censer's Weight, Sunsteel count them too).
const CENSER_PROCS := ["incense_aura", "bright_burst"]
const LIGHTSTRING_PROCS := ["refraction", "volley_arrow"]

## Radiance: what a heal of `id` of mine is multiplied by (Holy heals only).
func _holy_heal_mult(id: String) -> float:
	var r := player._talent("holy_radiance")
	if r <= 0.0 or id == "":
		return 1.0
	return 1.0 + r / 100.0 if is_holy_heal(id) else 1.0

## Is `id` a Holy heal (an ability of the Holy book, or one of its heal procs)?
static func is_holy_heal(id: String) -> bool:
	return HOLY_HEAL_PROCS.has(id) or Abilities.category_of(id) == "holy"

## Burnished, Censer's Weight, Sunsteel: my outgoing hits (_on_damage_modify).
func _holy_talents_outgoing(info: RefCounted) -> void:
	var burn := player._talent("holy_burnished")
	if burn > 0.0 and str(info.damage_type) == "holy":
		info.add_bonus(burn, "Burnished")
	var id := str(info.ability_id)
	var weight := player._talent("holy_censers_weight")
	if weight > 0.0 and (CenserKit.CENSER_IDS.has(id) or CENSER_PROCS.has(id)):
		info.add_bonus(weight, "Censer's Weight")
	if player._talent("holy_glimmering") > 0.0 and id == LightstringKit.GLIMMER_SHOT_ID:
		info.add_bonus(player._talent("holy_glimmering"), "Glimmering")
	var steel := player._talent("holy_sunsteel")
	if steel > 0.0 and (LightstringKit.LIGHTSTRING_INSTANTS.has(id) or id == LightstringKit.REFRACTING_SHOT_ID or LIGHTSTRING_PROCS.has(id)):
		info.add_bonus(steel, "Sunsteel")

## Overflowing: the shield from `over` overhealing (`pct` %), never more than
## OVERFLOWING_CAP_PCT % of `max_hp`.
static func overflowing_shield(over: int, pct: float, max_hp: int) -> int:
	if over <= 0 or pct <= 0.0:
		return 0
	var cap := int(floor(float(maxi(max_hp, 0)) * Balance.OVERFLOWING_CAP_PCT / 100.0))
	return mini(int(round(float(over) * pct / 100.0)), cap)

## A heal of `amount` of mine is about to land on `tgt`: what it overheals
## becomes a shield (not from lifesteal, nor from a shield of its own).
func _overflowing(tgt: Variant, amount: int, id: String) -> void:
	var pct := player._talent("holy_overflowing")
	if pct <= 0.0 or id == "lifesteal":
		return
	var h: Variant = (tgt as Node).get("health")
	var mh: Variant = (tgt as Node).get("max_health")
	if h == null or mh == null:
		return
	var over := amount - maxi(int(mh) - int(h), 0)
	var shield := overflowing_shield(over, pct, int(mh))
	if shield > 0:
		player.hymns._hymn_ward(tgt, OVERFLOWING_FX, shield, Balance.OVERFLOWING_TIME)

## Penitent: is a hit of `amount` big enough (vs `max_hp`)?
static func penitent_hit(amount: int, max_hp: int) -> bool:
	return max_hp > 0 and float(amount) >= float(max_hp) * Balance.PENITENT_HIT_PCT / 100.0

## Penitent: a big hit (not a damage over time tick) readies my next heal on myself.
func _penitent_hit(info: RefCounted) -> void:
	if player._talent("holy_penitent") <= 0.0 or bool(info.is_dot) or not penitent_hit(int(info.amount), player.max_health):
		return
	var fx := StatusContainer.make_buff(PENITENT_FX, "Penitent", Stats.BLOCK, 0.0, Balance.PENITENT_TIME, 1, HymnsKit.HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Your next heal on yourself is stronger."
	player.status.apply(fx, player)

## Zeal: does using ability `id` (cooldown `cd`) count? A cooldown of ZEAL_COOLDOWN or more.
static func zeal_counts(cd: float) -> bool:
	return cd >= Balance.ZEAL_COOLDOWN

func _zeal_on_cast(id: Variant) -> void:
	var pct := player._talent("holy_zeal")
	if pct <= 0.0 or player.status == null or player.is_dead():
		return
	var res := Abilities.get_resource(str(id))
	if res == null or not zeal_counts(Abilities.cooldown_of(res)):
		return
	player.status.apply(StatusContainer.make_buff(ZEAL_FX, "Zeal", Stats.MOVE_SPEED, pct, Balance.ZEAL_TIME, 1, HymnsKit.HOLY_LIGHT), player)

# --- Holy: talents shared by several specs ----------------------------------------------------
# Clear Mind (resource_cost) and Sheltering Light (_hymn_ward) for both healers,
# Second Breath (here) for both healers, Long Glass (here) for both prism specs,
# and the Rune of the Fourth Facet (Epic: one more prism).

const FOURTH_FACET_RUNE := "fourth_facet"

## Second Breath: does a heal of `amount` on someone at `h` of `mh` health lift
## them from below SECOND_BREATH_LOW_PCT % to above SECOND_BREATH_HIGH_PCT %?
static func second_breath(h: int, mh: int, amount: int) -> bool:
	if mh <= 0 or amount <= 0:
		return false
	var before := float(h) / float(mh) * 100.0
	var after := float(mini(h + amount, mh)) / float(mh) * 100.0
	return before < Balance.SECOND_BREATH_LOW_PCT and after > Balance.SECOND_BREATH_HIGH_PCT

## A heal of `amount` of mine is about to land on `tgt`: a big save gives me mana back.
func _second_breath(tgt: Variant, amount: int, id: String) -> void:
	var pct := player._talent("holy_second_breath")
	if pct <= 0.0 or id == "" or id == "lifesteal":
		return
	var h: Variant = (tgt as Node).get("health")
	var mh: Variant = (tgt as Node).get("max_health")
	if h == null or mh == null or not second_breath(int(h), int(mh), amount):
		return
	player._gain("mana", player.resource_max("mana") * pct / 100.0)

## How long a prism lasts (+ Long Glass).
func _prism_time() -> float:
	return Balance.PRISM_TIME + player._talent("holy_long_glass")

## How many prisms I can have (Rune of the Fourth Facet: one more).
func _prism_max() -> int:
	return Balance.PRISM_MAX + (1 if player._has_rune(FOURTH_FACET_RUNE) else 0)

## Was `who` hit in the last `window` seconds? Me: what I took; a party member's
## puppet: when its health last dropped (RemotePlayer.hurt_at). (Watchful Eye.)
func hit_recently(who: Variant, window: float) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	if is_same(who, player):
		return player.damage_taken_recently(window) > 0
	var at: Variant = (who as Node).get("hurt_at")
	return at != null and Time.get_ticks_msec() / 1000.0 - float(at) <= window

