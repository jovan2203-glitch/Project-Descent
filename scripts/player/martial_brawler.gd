extends "res://scripts/player/player_kit.gd"
class_name BrawlerKit

# Hooked up from player.gd through its var "brawler".
# --- Martial tank: the Brawler --------------------------------------------------------
# A pugilist. Two systems:
#   Bruise   while I am in Put 'Em Up (the stance), part of every hit I take
#            (BRUISE_PCT) is not dealt now but over BRUISE_TIME
#            (Player.take_damage -> bruise_take); its ticks give Fury. The stance
#            costs PUT_EM_UP_PCT of all my non-Physical damage (outgoing_mult).
#   Chain    Punch, Kick and Elbow (Abilities.BRAWLER_STRIKES, a short GCD) go into a
#            chain of CHAIN_LENGTH; when the last lands, a move goes off on top of it
#            (chain_move: the last strike picks it, three different make the strong
#            one). Catch starts a chain of its own: usable only while my target shows
#            a melee tell at me (enemy.gd "Melee tells"), the hit it catches lands in
#            full (no Bruise), and the chain it starts ends in a Catch move.
# One More repeats my last move; Tough It Out pauses Bruise; Come On taunts;
# Fighting Style only changes how my strikes look (PlayerData.bare_hands);
# Put 'Em Up is saved too (PlayerData.put_em_up).
# None of it works with a shield (AbilityData.forbids_shield).
# The kit is out while one of its buttons is on my bars. Everything runs on my
# machine; the party sees the orbs ("brawler" fx, scripts/brawler_orbs.gd).
# Numbers: balance.gd (BRUISE_*, CHAIN_*, STRIKE_GCD and the moves').

const ORBS = preload("res://scripts/brawler_orbs.gd")
const BrawlerIcons = preload("res://scripts/ui/brawler_icons.gd")
const Effects = preload("res://scripts/core/effects.gd")
const BRUISE_FX := "bruise"
const CLINCH_FX := "clinch"
const TOUGH_FX := "toughitout"
const STANCE_FX := "putemup"
const KICKED_DOWN_FX := "kicked_down"
const TAKEN_DOWN_FX := "taken_down"
const REVERSAL_ID := "reversal"          # Throw on a boss (its own meter line: Details.HIT_NAMES)
const CATCH_ID := "catch"
const GET_UP_ID := "getup"               # Get Up's heal (its own meter line: Details.HIT_NAMES)
const BRAWLER_TAGS := ["Ability", "Physical", "Melee"]
## The buttons (the moves have none).
const BUTTONS := ["punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle", "putemup"]
const TELL_EVERY := 3.0                  # seconds between telling the party what my orbs show

var _chain: Array[String] = []
var _chain_at := 0.0
var _bruise := 0.0          # damage still to come
var _bruise_left := 0.0     # seconds it is spread over
var _bruise_tick := 0.0
var _bruise_carry := 0.0    # fractions of a point not dealt yet
var _ticking := false
var _bruise_fx: Resource = null
var _catch_enemy: Node = null     # whose coming hit I am catching
var _catch_until := 0.0
var _landing_caught := false      # the hit landing right now is the caught one
var _caught_enemy: Node = null    # the chain's caught hit: from whom ...
var _caught_amount := 0           # ... and how much it dealt
var _clinched: Node = null
var _clinch_until := 0.0
var _tough_until := 0.0
var _last_move := ""              # One More repeats it ...
var _last_caught_enemy: Node = null   # ... with its caught hit
var _last_caught_amount := 0
var _was_in_combat := false
var _ground_more := 0.0           # Ground Game: seconds on the knockdown being applied now
var _shown := ""
var _told := 0.0

# Rules as static functions (tests/test_brawler.gd).

## The chain after `input` goes in. Catch always starts a new one; a full one starts over.
static func chain_after(chain: Array, input: String) -> Array[String]:
	var out: Array[String] = []
	if input != CATCH_ID and chain.size() < Balance.CHAIN_LENGTH:
		for x in chain:
			out.append(str(x))
	out.append(input)
	return out

## Are the inputs all different?
static func all_different(chain: Array) -> bool:
	var seen := {}
	for x in chain:
		seen[str(x)] = true
	return seen.size() == chain.size()

## The move a full `chain` makes ("" if it isn't full). The last strike picks it;
## three different strikes make the strong one; a chain started by Catch makes a Catch move.
static func chain_move(chain: Array) -> String:
	if chain.size() < Balance.CHAIN_LENGTH:
		return ""
	var last := str(chain[chain.size() - 1])
	if str(chain[0]) == CATCH_ID:
		return str(Abilities.BRAWLER_CATCH_MOVES.get(last, ""))
	if not Abilities.BRAWLER_MOVES.has(last):
		return ""
	return str(Abilities.BRAWLER_MOVES[last][1 if all_different(chain) else 0])

## The move `strike` would finish with `chain` in (shown on the buttons; "" if it doesn't finish one).
static func would_finish(chain: Array, strike: String) -> String:
	if chain.size() != Balance.CHAIN_LENGTH - 1 or strike == CATCH_ID:
		return ""
	return chain_move(chain_after(chain, strike))

## A hit of `amount`: [dealt now, into Bruise] (`pct`: the share that goes in; Soak It Up raises it).
static func bruise_split(amount: int, pct: float = Balance.BRUISE_PCT) -> Array:
	var later := int(round(float(amount) * clampf(pct, 0.0, 100.0) / 100.0))
	return [amount - later, later]

## % of my Bruise Shake Off clears (`capstone`: Soak It Up's).
static func shake_off_pct(capstone: bool) -> float:
	return Balance.SOAK_IT_UP_SHAKE_OFF if capstone else Balance.SHAKE_OFF_PCT

## A Bruise tick of `amount` after Scar Tissue (`pct` % less).
static func scarred(amount: float, pct: float) -> float:
	return amount * clampf(1.0 - pct / 100.0, 0.0, 1.0)

## Damage one Bruise tick deals with `total` left over `left` seconds.
static func bruise_per_tick(total: float, left: float) -> float:
	return total * Balance.BRUISE_TICK / maxf(left, Balance.BRUISE_TICK)

## Put 'Em Up: what my damage of `damage_type` is multiplied by (`on`: in the stance).
static func stance_mult(damage_type: String, on: bool) -> float:
	if not on or damage_type == "physical":
		return 1.0
	return clampf(1.0 - Balance.PUT_EM_UP_PCT / 100.0, 0.0, 1.0)

## Fury a Bruise tick of `amount` gives, with `max_health` (`tough`: Tough It Out).
static func bruise_fury(amount: float, max_health: float, tough: bool) -> float:
	var f := amount / maxf(max_health / 100.0, 1.0) * Balance.BRUISE_FURY
	return f * (Balance.TOUGH_IT_OUT_FURY if tough else 1.0)

## The strikes' global cooldown from the normal one (Haste counts the same).
static func strike_gcd(gcd_total: float) -> float:
	return gcd_total * Balance.STRIKE_GCD / Balance.GCD_BASE

## Fury One More needs on top of its cost to repeat `move`.
static func one_more_extra(move: String) -> float:
	return Balance.HAYMAKER_FURY if move == "haymaker" else 0.0

## Is `id` on the strikes' short GCD?
static func short_gcd(id: String) -> bool:
	return Abilities.BRAWLER_STRIKES.has(id) or id == CATCH_ID

# --- State ----------------------------------------------------------------------------

## Is the Brawler out? (Punch learned and one of its buttons on my bars, macros counted.)
func is_out() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null or not pd.has_ability("punch"):
		return false
	for slot_id in pd.action_bar:
		var id := Macros.link_of(str(slot_id)) if Macros.is_macro(str(slot_id)) else str(slot_id)
		if BUTTONS.has(id):
			return true
	return false

func chain() -> Array[String]:
	return _chain

func bruise() -> float:
	return _bruise

## Am I in Put 'Em Up? (Saved on PlayerData; counts only while the Brawler is out.)
func in_stance() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	return pd != null and bool(pd.put_em_up) and is_out()

## CombatSystem: what my outgoing hit of `info` is multiplied by (Put 'Em Up).
func outgoing_mult(info: RefCounted) -> float:
	return stance_mult(str(info.damage_type), in_stance())

func bare_hands() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	return pd != null and bool(pd.bare_hands)

## Can my target's coming hit be caught right now?
func catchable() -> bool:
	if not player._has_valid_target() or not player.target.has_method("melee_tell_at"):
		return false
	return bool(player.target.melee_tell_at(player))

## The name of the move strike `id` would finish now ("" if none): the bar shows it.
func finish_label(id: String) -> String:
	var move := would_finish(_chain, id)
	return Abilities.ability_name(move) if move != "" else ""

# --- Using it -------------------------------------------------------------------------

## Why a Brawler ability can't be used right now ("" = it can).
func _brawler_precheck(id: String) -> String:
	if Abilities.is_chain_move(id):
		return "Made by your Chain: not used on its own"
	match id:
		CATCH_ID:
			if not catchable():
				return "Your target shows no melee tell at you"
		"onemore":
			if _last_move == "":
				return "Your Chain hasn't made a move yet"
			var need := float(Abilities.cost_of("onemore")) + one_more_extra(_last_move)
			if float(player.resources.get("fury", 0.0)) < need:
				return "Not enough Fury"
	return ""

## Can `id` be used now (the bar dims it if not)? Only the Brawler's own conditions.
func usable_now(id: String) -> bool:
	if not Abilities.BRAWLER_IDS.has(id):
		return true
	return _brawler_precheck(id) == ""

## One of the Brawler's buttons (paid for and put on cooldown by _use_drafted).
func _brawler_use(id: String, res: Resource) -> void:
	match id:
		"punch", "brawlkick", "elbow":
			if player._has_valid_target():
				player.deal_damage(player.target, float(res.damage), id)
				_strike_look(id)
			player._gain("fury", player._talent("martial_quick_feet"))   # Quick Feet
			_add_input(id)
		CATCH_ID:
			var foe: Node = player.target
			_catch_enemy = foe
			_catch_until = (float(foe.melee_tell_end(player)) if foe.has_method("melee_tell_end") else _now()) + Balance.CATCH_GRACE
			_caught_enemy = foe
			_caught_amount = 0
			player._ring_effect(0.6, BrawlerIcons.CATCH, player.global_position + player._flat_forward() * 0.6)
			_add_input(CATCH_ID)
		"onemore":
			_do_move(_last_move, true)
		"toughitout":
			_tough_it_out()
		"comeon":
			if player._has_valid_target():
				player._net_taunt(player.target, Balance.COME_ON_TAUNT)
				player._ring_effect(1.0, BrawlerIcons.WRAP, player.target.global_position)
		"fightingstyle":
			var pd := player.get_node_or_null("/root/PlayerData")
			if pd:
				pd.bare_hands = not bool(pd.bare_hands)
			_shown = "?"   # (shows again)
			_sync()
		"putemup":
			var pd := player.get_node_or_null("/root/PlayerData")
			if pd:
				pd.put_em_up = not bool(pd.put_em_up)
			_show_stance()

## A strike's look: Armed swings the weapon, Bare Hands throws a wrapped fist.
func _strike_look(id: String) -> void:
	var col: Color = BrawlerIcons.COLORS.get(id, BrawlerIcons.WRAP)
	if bare_hands() and player._has_valid_target():
		player._ring_effect(0.35, col, player.target.global_position + Vector3(0, 1.0, 0))
	else:
		player._slash_effect(col)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Something went into the chain: when it is full, its move goes off.
func _add_input(input: String) -> void:
	_chain = chain_after(_chain, input)
	_chain_at = _now()
	if _chain.size() >= Balance.CHAIN_LENGTH:
		var full := _chain.duplicate()
		var move := chain_move(full)
		_chain = []
		var gold: bool = full[0] != CATCH_ID and all_different(full)
		if player.is_inside_tree():
			ORBS.burst(player, full, gold)
			player._net_fx("brawler_burst", player.global_position, null, {"i": full, "g": gold})
		_do_move(move, false)
	_sync()

## A chain move (`again`: One More, with the last move's caught hit).
func _do_move(move: String, again: bool) -> void:
	if move == "":
		return
	var foe: Node = player.target if player._has_valid_target() else null
	var caught := _last_caught_amount if again else _caught_amount
	var from: Node = _last_caught_enemy if again else _caught_enemy
	if Abilities.BRAWLER_CATCH_MOVES.values().has(move) and foe == null and from != null and is_instance_valid(from) and from.is_alive():
		foe = from   # (a Catch move goes into the enemy I caught if I have no target)
	var res := Abilities.get_resource(move)
	var done := move
	match move:
		"rapidfists":
			_hit(foe, float(res.damage), move)
		"haymaker":
			if float(player.resources.get("fury", 0.0)) >= Balance.HAYMAKER_FURY:
				player._gain("fury", -Balance.HAYMAKER_FURY)
				_hit(foe, float(res.damage), move)
				player._ring_effect(1.2, BrawlerIcons.GOLD, foe.global_position if foe else Vector3.INF)
				_clear_bruise(player._talent("martial_last_laugh"))   # Last Laugh
			else:
				done = "rapidfists"   # no Fury for it
				_hit(foe, float(Abilities.get_resource("rapidfists").damage), "rapidfists")
		"sweep", "roundhouse":
			var reach := float(res.radius) + Abilities.radius_bonus(move)   # + Wide Stance
			var foes: Array = player._enemies_within(reach)
			var share := Balance.aoe_share(foes.size())
			var landed := 0
			for e in foes:
				if player.deal_damage(e, float(res.damage) * share, move) > 0:
					landed += 1
				if move == "roundhouse":
					_knock(e, KICKED_DOWN_FX, move)
			player._gain("fury", crowd_work_fury(landed, player._talent("martial_crowd_work")))   # Crowd Work
			player._ring_effect(reach, BrawlerIcons.KICK)
		"clinch":
			if foe:
				_clinched = foe
				var hold := Balance.CLINCH_TIME + player._talent("martial_tight_clinch")   # + Tight Clinch
				_clinch_until = _now() + hold
				_buff(CLINCH_FX, Abilities.ability_name("clinch"), hold, BrawlerIcons.ELBOW,
					"You have an enemy tied up: you take %s%% less damage from it." % Stats.num(Balance.CLINCH_PCT))
		"shakeoff":
			_bruise *= 1.0 - shake_off_pct(player.frost_melee._capstone("martial_soak_it_up")) / 100.0   # (Soak It Up's capstone)
			player._ring_effect(1.5, BrawlerIcons.ELBOW)
			_show_bruise()
			player._gain("fury", player._talent("martial_back_up"))   # Back Up
			var heal := float(player.max_health) * player._talent("martial_get_up") / 100.0   # Get Up
			if heal >= 1.0:
				player.strings._heal_exact(player, int(round(heal)), GET_UP_ID)
		"turnitaround":
			if foe and caught > 0:
				var info = player._combat().ability_hit_info(player, foe, 1.0, move)
				info.unit = float(caught) * Balance.TURN_IT_AROUND_PCT / 100.0 * Abilities.hit_damage_mult(move) \
					* (1.0 + player._talent("martial_counter_puncher") / 100.0)   # (exact: the tank rule and Counter Puncher by hand)
				info.exact = true
				info.add_power = false
				info.can_block = false
				player._combat().deal(info)
		"throw":
			_throw(foe, res)
		"takedown":
			if foe:
				if str(foe.get("rank")) == "boss":
					_bruise = maxf(_bruise - float(caught), 0.0)   # a boss can't be put down
					_show_bruise()
				else:
					_knock(foe, TAKEN_DOWN_FX, move)
	if not again:
		_last_move = done
		_last_caught_enemy = _caught_enemy
		_last_caught_amount = _caught_amount

func _hit(foe: Node, coef: float, id: String) -> void:
	if foe != null:
		player.deal_damage(foe, coef, id)

## Knock `e` down (never a boss). Ground Game keeps Throw's and Takedown's down longer.
func _knock(e: Node, fx_id: String, from_id: String) -> void:
	if e == null or not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
		return
	_ground_more = player._talent("martial_ground_game") if (from_id == "throw" or from_id == "takedown") else 0.0
	player.fire_caster._apply_effect_hit(e, Effects.get_effect(fx_id), from_id, PackedStringArray(BRAWLER_TAGS), "physical")
	_ground_more = 0.0

## Extra seconds on an effect I am applying right now (Player.effect_duration_bonus): Ground Game.
func duration_bonus(_res: Resource) -> float:
	return _ground_more

## Last Laugh: clear `pct` % of my Bruise.
func _clear_bruise(pct: float) -> void:
	if pct <= 0.0 or _bruise <= 0.0:
		return
	_bruise *= 1.0 - clampf(pct, 0.0, 100.0) / 100.0
	_show_bruise()

## Crowd Work: Fury a Sweep / Roundhouse that hit `hit` enemies gives at `per` each.
static func crowd_work_fury(hit: int, per: float) -> float:
	return float(clampi(hit, 0, Balance.CROWD_WORK_MAX)) * maxf(per, 0.0)

## Hardened: does a Bruise of `bruise` count with `max_health`?
static func hardened_on(bruise: float, max_health: float) -> bool:
	return max_health > 0.0 and bruise / max_health * 100.0 > Balance.HARDENED_BRUISE_PCT

## Throw: the caught enemy flies away from me and knocks down where it lands. A boss: Reversal.
func _throw(foe: Node, res: Resource) -> void:
	if foe == null:
		return
	if str(foe.get("rank")) == "boss":
		player.deal_damage(foe, Balance.REVERSAL_COEF, REVERSAL_ID, false, "physical", PackedStringArray(BRAWLER_TAGS))
		return
	player.deal_damage(foe, float(res.damage), "throw")
	var dir: Vector3 = foe.global_position - player.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -player._flat_forward()
	var reach := Balance.THROW_DISTANCE
	var from: Vector3 = foe.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		reach = maxf(from.distance_to(hit.position) - 0.6, 0.0)   # walls stop it
	var to: Vector3 = foe.global_position + dir * reach
	var net := player._net()
	if net:
		net.drag(foe, to, Balance.THROW_TIME)
	elif foe.has_method("drag_to"):
		foe.drag_to(to, Balance.THROW_TIME)
	player.weaver._after(Balance.THROW_TIME, func():
		if player.is_dead():
			return
		_knock(foe, KICKED_DOWN_FX, "throw")
		for e in player._enemies_near(to, Balance.THROW_SPLASH, foe):
			_knock(e, KICKED_DOWN_FX, "throw")
		player._ring_effect(Balance.THROW_SPLASH, BrawlerIcons.KICK, to))

func _tough_it_out() -> void:
	_tough_until = _now() + Balance.TOUGH_IT_OUT_TIME
	_buff(TOUGH_FX, Abilities.ability_name("toughitout"), Balance.TOUGH_IT_OUT_TIME, BrawlerIcons.GOLD,
		"Your Bruise deals no damage and gives more Fury.")

func _buff(fx_id: String, title: String, time: float, col: Color, text: String) -> void:
	if player.status == null:
		return
	var fx := StatusContainer.make_buff(fx_id, title, fx_id, 0.0, time, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical", "Defensive"])
	fx.description = text
	player.status.apply(fx, player)
	player.status.set_remaining(fx_id, time)

# --- Taking hits ----------------------------------------------------------------------

## A hit is about to land on me (CombatSystem, before take_damage): is it the caught one?
func before_hit_lands(info: RefCounted) -> void:
	_landing_caught = false
	if _catch_enemy == null or not is_instance_valid(_catch_enemy) or info.source != _catch_enemy:
		return
	if bool(info.is_dot) or not PackedStringArray(info.tags).has("Melee") or _now() > _catch_until:
		return
	_landing_caught = true
	_catch_enemy = null

## How much less I take from `info` (Clinch, Iron Chin, Hardened): [percent, label] or [].
func incoming_bonus(info: RefCounted) -> Array:
	var pct := 0.0
	var label := ""
	var clinching := _clinched != null and is_instance_valid(_clinched) and _now() < _clinch_until
	if clinching and info.source == _clinched:
		pct += Balance.CLINCH_PCT
		label = Abilities.ability_name("clinch")
	if clinching:
		pct += player._talent("martial_iron_chin")   # Iron Chin: from every enemy while I clinch one
	if is_out() and hardened_on(_bruise, float(player.max_health)):
		pct += player._talent("martial_hardened")    # Hardened: while my Bruise is big
	if pct <= 0.0:
		return []
	return [-pct, label if label != "" else "Brawler"]

## take_damage: what of `amount` lands now; the rest goes into Bruise. The caught hit
## lands in full, and so do Bruise's own ticks.
func bruise_take(amount: int) -> int:
	if _ticking or amount <= 0 or not in_stance():
		_landing_caught = false
		return amount
	var pct := Balance.BRUISE_PCT + player._talent("martial_soak_it_up")   # + Soak It Up
	if _landing_caught:
		_landing_caught = false
		_caught_amount = amount   # (the whole hit: Turn It Around and Takedown count all of it)
		pct = player._talent("martial_soft_catch")   # Soft Catch: part of it still goes into Bruise
		if pct <= 0.0:
			return amount
	var split := bruise_split(amount, pct)
	if int(split[1]) > 0:
		_bruise += float(split[1])
		_bruise_left = Balance.BRUISE_TIME + player._talent("martial_slow_burn")   # + Slow Burn
		if _bruise_tick <= 0.0:
			_bruise_tick = Balance.BRUISE_TICK
		_show_bruise()
	return int(split[0])

func _show_bruise() -> void:
	if player.status == null:
		return
	if _bruise < 1.0:
		player.status.remove(BRUISE_FX)
		return
	if _bruise_fx == null:
		_bruise_fx = StatusContainer.make_buff(BRUISE_FX, "Bruise", Stats.BLOCK, 0.0, 3600.0, 999999, Color(0.6, 0.35, 0.7))
		_bruise_fx.stat_modifiers = {}
		_bruise_fx.tags = PackedStringArray(["Physical"])
		_bruise_fx.description = "Damage you took that still hurts: it is dealt to you over the next few seconds."
	if not player.status.has(BRUISE_FX):
		player.status.apply(_bruise_fx, player)
	var n := int(ceil(_bruise))
	if player.status.stacks_of(BRUISE_FX) != n:
		player.status.set_stacks(BRUISE_FX, n)

## The stance's buff: shown while I am in it.
func _show_stance() -> void:
	var on := in_stance() and not player.is_dead()
	if player.status == null or on == player.status.has(STANCE_FX):
		return
	if not on:
		player.status.remove(STANCE_FX)
		return
	var fx := StatusContainer.make_buff(STANCE_FX, Abilities.ability_name("putemup"), STANCE_FX, 0.0, 3600.0, 1, BrawlerIcons.WRAP)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical", "Defensive"])
	fx.description = "You take hits with Bruise. Your damage that is not Physical is %s%% lower." % Stats.num(Balance.PUT_EM_UP_PCT)
	player.status.apply(fx, player)
	player.status.set_remaining(STANCE_FX, 3600.0)

# --- Every frame ----------------------------------------------------------------------

func _tick_brawler(delta: float) -> void:
	var now := _now()
	if player.is_dead():
		_bruise = 0.0
		_chain = []
	var fighting: bool = player.is_in_combat()
	if _was_in_combat and not fighting:
		_chain = []   # leaving combat: the chain is gone (Bruise still runs out)
	_was_in_combat = fighting
	if not _chain.is_empty() and now - _chain_at > Balance.CHAIN_TIMEOUT:
		_chain = []
	if _catch_enemy != null and now > _catch_until:
		_catch_enemy = null   # the caught hit never came: the chain goes on with nothing caught
	if _bruise > 0.0:
		_bruise_tick -= delta
		while _bruise_tick <= 0.0 and _bruise > 0.0:
			_bruise_tick += Balance.BRUISE_TICK
			_tick_bruise()
		_show_bruise()
	_show_stance()
	_sync()
	if now - _told >= TELL_EVERY and _shown != "":
		_tell()

func _tick_bruise() -> void:
	var amt := minf(bruise_per_tick(_bruise, _bruise_left), _bruise)
	_bruise -= amt
	_bruise_left = maxf(_bruise_left - Balance.BRUISE_TICK, Balance.BRUISE_TICK)
	if _bruise < 0.5:
		amt += _bruise
		_bruise = 0.0
	var tough := _now() < _tough_until
	player._gain("fury", bruise_fury(amt, float(player.max_health), tough) * (1.0 + player._talent("martial_calluses") / 100.0))   # + Calluses
	if tough:
		return   # Tough It Out: it doesn't hurt
	_bruise_carry += scarred(amt, player._talent("martial_scar_tissue"))   # Scar Tissue
	var whole := int(floor(_bruise_carry))
	if whole <= 0:
		return
	_bruise_carry -= float(whole)
	_ticking = true
	player.take_damage(whole)
	_ticking = false

## The picture shows the chain, and the party is told when it changes.
func _sync() -> void:
	var want := ""
	if is_out() and not player.is_dead():
		want = "%s|%s" % [",".join(_chain), str(bare_hands())]
	if want == _shown:
		return
	_shown = want
	if player.is_inside_tree():
		ORBS.show_on(player, _chain, bare_hands(), want != "")
	_tell()

func _tell() -> void:
	_told = _now()
	player._net_fx("brawler", player.global_position, null, {"i": _chain if _shown != "" else [], "b": bare_hands(), "o": _shown != ""})

func tracker_values() -> Dictionary:
	var out := {"chain": {"value": _chain.size(), "max": Balance.CHAIN_LENGTH}, "bruise": {"value": _bruise, "max": float(player.max_health)}}
	for i in Balance.CHAIN_LENGTH:   # each input so far, its strike's icon
		var id := _chain[i] if i < _chain.size() else ""
		out["chain_%d" % (i + 1)] = {"value": 1 if id != "" else 0, "max": 1, "icon": id,
			"name": Abilities.ability_name(id) if id != "" else ""}
	return out
