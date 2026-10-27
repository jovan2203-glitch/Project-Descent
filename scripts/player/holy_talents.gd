extends "res://scripts/player/player_kit.gd"
class_name HolyTalentsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "holy_talents".
# --- Holy: the open talents and the bottom row ------------------------------------------------
# Open (useful to anyone): Grace (my heals on others: _others_heal_mult), Steadfast
# (Block: PlayerData), Burnished (my Holy damage), Overflowing (overhealing becomes
# a shield), Penitent (a big hit makes my next heal on myself stronger: also
# heal_taken_mult), Zeal (faster after a long cooldown), Watchful Eye (StringsKit._heal_coef),
# Second Breath, Candlelight (healing an ally makes my next damage stronger) and First
# Light (the start of a fight). The spec talents that change hits and heals: Censer's
# Weight (and its capstone), Heavy Smoke, Cloying Smoke and Full Censer (the tank);
# Sunsteel, Burnished, Glimmering, Gilt Tips and Sundown (the archer); Radiance,
# Aftershine and Bright Shards (the healers). Numbers: talents.gd and balance.gd.

const OVERFLOWING_FX := "overflowing"
const PENITENT_FX := "penitent"
const ZEAL_FX := "zeal"
const CANDLELIGHT_FX := "candlelight"
var _combat_start := -INF      # when I last entered combat (First Light)
var _aftershine := {}          # ally instance id -> until: a shattering prism of mine healed them (Aftershine)
var _candle_id := ""           # the spell / ability that is using Candlelight's boost up ...
var _candle_until := 0.0       # ... and until when its hits still get it
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

## Glimmering: does a hit of `id` count? An instant bow shot's own hit (no auto-shot).
static func glimmering_applies(id: String, tags: PackedStringArray, is_proc: bool, is_dot: bool) -> bool:
	var r := Abilities.get_resource(id)
	return r != null and id != "auto_ranged" and tags.has("Ranged") and tags.has("Ability") and not is_proc and not is_dot and float(r.cast_time) <= 0.0

## First Light: is it still the start of the fight, `since` seconds in?
static func first_light_on(since: float) -> bool:
	return since >= 0.0 and since <= Balance.FIRST_LIGHT_TIME

## Burnished, Censer's Weight, Sunsteel and the other Holy talents that change my
## outgoing hits (_on_damage_modify).
func _holy_talents_outgoing(info: RefCounted) -> void:
	var burn := player._talent("holy_burnished")
	if burn > 0.0 and str(info.damage_type) == "holy":
		info.add_bonus(burn, "Burnished")
	var id := str(info.ability_id)
	var proc := bool(info.is_proc)
	var dot := bool(info.is_dot)
	var censer := CenserKit.CENSER_IDS.has(id) or CENSER_PROCS.has(id)
	var weight := player._talent("holy_censers_weight")
	if weight > 0.0 and censer:
		info.add_bonus(weight, "Censer's Weight")
		if player.frost_melee._capstone("holy_censers_weight") and player.censer.incense() >= Balance.INCENSE_MAX:
			info.add_bonus(Balance.CENSERS_WEIGHT_FULL_PCT, "Censer's Weight")   # its capstone: a full censer
	var smoke := player._talent("holy_heavy_smoke")
	if smoke > 0.0 and id == CenserKit.INCENSE_AURA_ID:
		info.add_bonus(smoke, "Heavy Smoke")
	var cloying := player._talent("holy_cloying_smoke")
	if cloying > 0.0 and CenserKit.CENSER_IDS.has(id):
		info.threat_multiplier *= 1.0 + cloying / 100.0   # (the procs get it in CenserKit._censer_proc_hit)
	var glimmer := player._talent("holy_glimmering")
	if glimmer > 0.0 and glimmering_applies(id, info.tags, proc, dot):
		info.add_bonus(glimmer, "Glimmering")
	var gilt := player._talent("holy_gilt_tips")
	if gilt > 0.0 and id == "auto_ranged":
		info.add_bonus(gilt, "Gilt Tips")
	var sundown := player._talent("holy_sundown")
	if sundown > 0.0 and NatureTalentsOpenKit.bow_shot(id, info.tags, dot) and info.target != null and is_instance_valid(info.target):
		if NatureTalentsOpenKit.below(float(info.target.get("health")), float(info.target.get("max_health")), Balance.SUNDOWN_HEALTH_PCT):
			info.add_bonus(sundown, "Sundown")
	var steel := player._talent("holy_sunsteel")
	if steel > 0.0 and (LightstringKit.LIGHTSTRING_INSTANTS.has(id) or id == LightstringKit.REFRACTING_SHOT_ID or LIGHTSTRING_PROCS.has(id)):
		info.add_bonus(steel, "Sunsteel")
	var first := player._talent("holy_first_light")
	if first > 0.0 and player.in_combat and first_light_on(_now() - _combat_start):
		info.add_bonus(first, "First Light")
	_candlelight_hit(info, id)

## A hit on me, before its damage is worked out: Full Censer.
func _holy_talents_incoming(info: RefCounted) -> void:
	var full := player._talent("holy_full_censer")
	if full > 0.0 and not player.censer.censer_raised() and player.censer.incense() >= Balance.FULL_CENSER_INCENSE:
		info.add_bonus(-full, "Full Censer")

## What a heal of mine (`id`, on `tgt`) is multiplied by: Aftershine, First Light
## (StringsKit._heal_coef asks).
func heal_mult(tgt: Variant, _id: String) -> float:
	var m := 1.0
	if tgt != null and is_instance_valid(tgt) and tgt is Node and float(_aftershine.get((tgt as Node).get_instance_id(), 0.0)) > _now():
		m *= 1.0 + player._talent("holy_aftershine") / 100.0
	var first := player._talent("holy_first_light")
	if first > 0.0 and player.in_combat and first_light_on(_now() - _combat_start):
		m *= 1.0 + first / 100.0
	return m

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Combat started (Player): First Light counts from now.
func _on_combat_start() -> void:
	_combat_start = _now()

## Aftershine: a shattering prism of mine just healed `who`.
func aftershine(who: Variant) -> void:
	if player._talent("holy_aftershine") <= 0.0 or who == null or not is_instance_valid(who) or not (who is Node):
		return
	if _aftershine.size() > 32:
		_aftershine.clear()
	_aftershine[(who as Node).get_instance_id()] = _now() + Balance.AFTERSHINE_TIME

## Bright Shards: a prism of mine shattered, so I get some mana back.
func bright_shards() -> void:
	var pct := player._talent("holy_bright_shards")
	if pct > 0.0:
		player._gain("mana", player.resource_max("mana") * pct / 100.0)

## A heal of mine landed (SignalBus.heal_done). Candlelight: one on an ally makes
## my next damaging spell or ability stronger.
func _on_heal_done_holy(source: Node, healed: Node, amount: int, _effective: int, _id: String, _crit: bool) -> void:
	if amount <= 0 or not is_same(source, player) or healed == null or is_same(healed, player) or player.status == null:
		return
	if player._talent("holy_candlelight") <= 0.0:
		return
	var fx := StatusContainer.make_buff(CANDLELIGHT_FX, "Candlelight", CANDLELIGHT_FX, 0.0, Balance.CANDLELIGHT_TIME, 1, HymnsKit.HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Your next spell or ability that deals damage deals more."
	player.status.apply(fx, player)

## Candlelight: the first spell or ability I hit with uses the boost, and every hit
## of that one use gets it (CANDLELIGHT_HITS seconds). Never an auto-attack, a proc or a tick.
func _candlelight_hit(info: RefCounted, id: String) -> void:
	if not ArcaneOpenTalentsKit.echoes(info.tags, bool(info.is_proc), bool(info.is_dot), Abilities.PATHS.has(id)):
		return
	var now := _now()
	if player.status != null and player.status.has(CANDLELIGHT_FX):
		player.status.remove(CANDLELIGHT_FX)
		_candle_id = id
		_candle_until = now + Balance.CANDLELIGHT_HITS
	elif id != _candle_id or now > _candle_until:
		return
	var pct := player._talent("holy_candlelight")
	if pct > 0.0:
		info.add_bonus(pct, "Candlelight")

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
	return Balance.PRISM_MAX + (1 if player.frost_melee._has_rune(FOURTH_FACET_RUNE) else 0)

## Was `who` hit in the last `window` seconds? Me: what I took; a party member's
## puppet: when its health last dropped (RemotePlayer.hurt_at). (Watchful Eye.)
func hit_recently(who: Variant, window: float) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	if is_same(who, player):
		return player.arcane_tank.damage_taken_recently(window) > 0
	var at: Variant = (who as Node).get("hurt_at")
	return at != null and Time.get_ticks_msec() / 1000.0 - float(at) <= window

