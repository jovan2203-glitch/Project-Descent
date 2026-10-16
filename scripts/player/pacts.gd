extends "res://scripts/player/player_kit.gd"
class_name PactsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "pacts_kit".
# --- Pacts -----------------------------------------------------------------------------------
# One Pact for the dungeon (scripts/pacts.gd says what each is and changes; the
# choice is PlayerData.pact). Here its bonus and drawback are applied and its
# vow is watched. All of it is this machine's own player: nothing is sent.
#   stats           _raw_stat adds Pacts.stat_mod (Haste, crit, movement, max health and mana)
#   damage          _on_damage_modify -> _pact_outgoing / _pact_incoming (labelled: the meter shows it)
#   cooldowns       _tick_cooldowns x Pacts.cooldown_rate
#   costs           resource_cost x _pact_cost_mult
#   resources       _gain x Pacts.resource_gain_mult
#   healing         heal_taken_mult (CombatSystem.heal asks whoever is healed), _pact_heal_mult on what I cast
#   out of combat   _tick_pact drains the Restless; _tick_health_regen stops for them
# The vows: _go_down and _die (Unbowed), take_damage -> _pact_on_damage (Thin
# Line, Sidestep), use_ability -> _pact_purist_blocks and cast_finished ->
# _pact_on_ability (Purist), heal_done -> _pact_on_heal (Fast), my hits and heals
# -> _pact_acted (Relentless), _tick_pact (Relentless, Restless, Reservoir, and
# every PACT_POLL seconds the party: Shepherd, Vanguard).
# _break_pact ends it for the run (PlayerData.pact_broken): the bonus turns round.

const PACTS = preload("res://scripts/pacts.gd")
const PACT_FX := "pact"       # the buff that shows it (it changes nothing itself)
const PACT_POLL := 0.25       # seconds between looks at the party and at who the enemies are on

var _pact_now := ""           # the Pact that counts right now ("" = none), worked out once a frame
var _pact_now_broken := false
var _pact_frame := -1
var _pact_idle := 0.0         # Relentless: seconds in combat since I last hit an enemy or healed an ally
var _pact_rest := 0.0         # Restless: seconds out of combat
var _pact_fought := false     # ... which only count once I have been in a fight
var _pact_cleared := false    # ... and stop when the dungeon is cleared
var _pact_bleed := 0.0        # ... health lost out of combat that is not a whole point yet
var _pact_poll_at := 0.0
var _pact_downed := {}        # Shepherd: party member instance id -> were they down at the last look
var _pact_on_me := {}         # Vanguard: enemy instance id -> it was attacking me at the last look
var _pact_warned := ""        # Purist: the ability I was warned about ...
var _pact_warned_at := 0.0    # ... and when
var _pact_shown := ""         # what the buff shows ("" = nothing)

func _pact_sync() -> void:
	var frame := Engine.get_process_frames()
	if frame == _pact_frame:
		return
	_pact_frame = frame
	var pd := player.get_node_or_null("/root/PlayerData")
	var id := str(pd.pact) if pd else ""
	if id != "" and PACTS.party_only(id):
		var net := player._net()
		if net == null or not net.with_others():
			id = ""   # a party Pact does nothing alone: no bonus, no drawback, no vow
	_pact_now = id if PACTS.exists(id) else ""
	_pact_now_broken = _pact_now != "" and bool(pd.pact_broken)

## The Pact I hold that counts right now ("" = none).
func pact_id() -> String:
	_pact_sync()
	return _pact_now

func pact_broken() -> bool:
	_pact_sync()
	return _pact_now_broken

func _pact_book() -> String:
	var pd := player.get_node_or_null("/root/PlayerData")
	return str(pd.pact_book) if pd else ""

func _pact_stat(key: String) -> float:
	var id := pact_id()
	return PACTS.stat_mod(id, _pact_now_broken, key) if id != "" else 0.0

## A hit I deal (_on_damage_modify).
func _pact_outgoing(info: RefCounted) -> void:
	var id := pact_id()
	if id == "":
		return
	var pct := PACTS.damage_dealt_pct(id, _pact_now_broken)
	if pct != 0.0:
		info.add_bonus(pct, PACTS.pact_name(id))

## A hit I take (_on_damage_modify).
func _pact_incoming(info: RefCounted) -> void:
	var id := pact_id()
	if id == "":
		return
	var pct := PACTS.damage_taken_pct(id, _pact_now_broken)
	if pct != 0.0:
		info.add_bonus(pct, PACTS.pact_name(id))

func _pact_cost_mult(res: String) -> float:
	var id := pact_id()
	return PACTS.cost_mult(id, _pact_now_broken, res) if id != "" else 1.0

## What the heals I cast are multiplied by.
func _pact_heal_mult() -> float:
	var id := pact_id()
	return PACTS.heal_done_mult(id, _pact_now_broken) if id != "" else 1.0

## What a heal landing on me is multiplied by (CombatSystem.heal asks).
func heal_taken_mult(source: Node, _ability_id: String = "") -> float:
	var id := pact_id()
	var mult := PACTS.heal_taken_mult(id, _pact_now_broken, is_same(source, player)) if id != "" else 1.0
	# Penitent (an open Holy talent): my next heal on myself after a big hit is stronger (and that uses it up).
	if is_same(source, player) and player.status != null and player.status.has(HolyTalentsKit.PENITENT_FX):
		player.status.remove(HolyTalentsKit.PENITENT_FX)
		mult *= 1.0 + player._talent("holy_penitent") / 100.0
	return mult

## The vow was broken: the Pact works against me until the dungeon ends.
func _break_pact(why: String) -> void:
	var id := pact_id()
	if id == "" or _pact_now_broken:
		return
	_pact_frame = -1
	_pact_shown = ""   # (the buff is drawn again, as broken)
	player.get_node("/root/PlayerData").break_pact()   # (its `changed` re-derives my stats: _on_stats_changed)
	player._combat().float_text(player, "%s is broken!" % PACTS.pact_name(id), PACTS.COLOR, true)
	player._error("%s is broken" % PACTS.pact_name(id))
	var gl := player.get_node_or_null("/root/GameLog")
	if gl:
		gl.event("%s is broken: %s. Until the dungeon ends: %s" % [PACTS.pact_name(id), why, PACTS.text(id, "broken")],
			Color(1.0, 0.45, 0.5))

## Unbowed: I went down, or died.
func _pact_on_down() -> void:
	if PACTS.breaks_on_down(pact_id()):
		_break_pact("you went down")

## A hit of `amount` just landed on me (take_damage; my health is already lower).
func _pact_on_damage(amount: int) -> void:
	var id := pact_id()
	if id == "" or _pact_now_broken or not PACTS.breaks_on_hit(id, amount, player.health, player.max_health):
		return
	_break_pact("you dropped below %s%% health" % Stats.num(Balance.PACT_THIN_LINE_FLOOR) if id == PACTS.THIN_LINE
		else "one hit took more than %s%% of your health" % Stats.num(Balance.PACT_SIDESTEP_HIT))

## Purist: would using ability `id` break the Pact? The first press only warns;
## pressing it again within PACT_PURIST_CONFIRM seconds goes through.
func _pact_purist_blocks(id: String) -> bool:
	var pact := pact_id()
	if pact == "" or _pact_now_broken or not Abilities.PATHS.has(id):
		return false
	if not PACTS.breaks_on_ability(pact, Abilities.category_of(id), _pact_book(), Abilities.is_trinket_slot(id)):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _pact_warned == id and now - _pact_warned_at <= Balance.PACT_PURIST_CONFIRM:
		return false
	_pact_warned = id
	_pact_warned_at = now
	player._error("%s would break %s. Use it again to do it anyway." % [Abilities.ability_name(id), PACTS.pact_name(pact)])
	return true

## Purist: an ability of mine went off (SignalBus.cast_finished: instants, and casts as they finish).
func _pact_on_ability(id: String) -> void:
	var pact := pact_id()
	if pact == "" or _pact_now_broken or not Abilities.PATHS.has(id):
		return
	if PACTS.breaks_on_ability(pact, Abilities.category_of(id), _pact_book(), Abilities.is_trinket_slot(id)):
		_break_pact("you used %s" % Abilities.ability_name(id))

## A heal of mine landed (_on_heal_done_strings). Fast: on me, from a spell or an
## ability. Relentless: on someone else counts as doing something.
func _pact_on_heal(healed: Node, id: String) -> void:
	if healed != null and not is_same(healed, player):
		_pact_idle = 0.0
		return
	var pact := pact_id()
	if pact != "" and not _pact_now_broken and PACTS.breaks_on_self_heal(pact, Abilities.PATHS.has(id)):
		_break_pact("you healed yourself with %s" % Abilities.ability_name(id))

## Relentless: a hit of mine landed on an enemy (_on_damage_dealt_shadow, which
## sees every one; damage over time does not count).
func _pact_acted(info: RefCounted) -> void:
	if not bool(info.is_dot):
		_pact_idle = 0.0

## Every frame: the buff that shows the Pact, the vows that are about time, the
## Restless losing health out of combat, and a look at the party now and then.
func _tick_pact(delta: float) -> void:
	var id := pact_id()
	if id == "":
		_pact_show("")
		return
	_pact_show(id + ("!" if _pact_now_broken else ""))
	if player.is_dead():
		_pact_on_me.clear()   # (dead or down: nothing is counted, and enemies may go where they like)
		return
	if player.in_combat:
		_pact_fought = true
		_pact_rest = 0.0
		_pact_idle += delta
	else:
		_pact_idle = 0.0
		if _pact_fought and not _pact_cleared:
			_pact_rest += delta
			_pact_bleed_tick(id, delta)
	if _pact_now_broken:
		return
	if PACTS.breaks_on_idle(id, _pact_idle):
		_break_pact("%s sec in combat without hitting an enemy or healing an ally" % Stats.num(Balance.PACT_RELENTLESS_IDLE))
	elif PACTS.breaks_on_rest(id, _pact_rest):
		_break_pact("%s sec out of combat" % Stats.num(Balance.PACT_RESTLESS_IDLE))
	elif PACTS.breaks_on_mana(id, float(player.resources.get("mana", 0.0)), player.resource_max("mana")):
		_break_pact("you dropped below %s%% mana" % Stats.num(Balance.PACT_RESERVOIR_FLOOR))
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _pact_poll_at:
		_pact_poll_at = now + PACT_POLL
		_pact_watch_party(id)

## The Restless: health drains out of combat (never the last point), kept or broken.
func _pact_bleed_tick(id: String, delta: float) -> void:
	var pct := PACTS.bleed_pct(id)
	if pct <= 0.0 or player.health <= 1:
		_pact_bleed = 0.0
		return
	_pact_bleed += float(player.max_health) * pct / 100.0 * delta
	if _pact_bleed < 1.0:
		return
	var lost := mini(int(_pact_bleed), player.health - 1)
	_pact_bleed -= int(_pact_bleed)
	if lost > 0:
		player.health -= lost
		player.health_changed.emit(player.health, player.max_health)
		player._bus().player_health_changed.emit(player.health, player.max_health)

## Shepherd: did a party member just go down near me? Vanguard: did an enemy
## that was on me turn on one of them?
func _pact_watch_party(id: String) -> void:
	if id == PACTS.SHEPHERD:
		for p in player.get_tree().get_nodes_in_group("remote_player"):
			if not (p is Node3D):
				continue
			var key: int = p.get_instance_id()
			var down: bool = not p.is_alive()
			var was: Variant = _pact_downed.get(key)
			_pact_downed[key] = down
			if was != null and down and not bool(was) and PACTS.breaks_on_ally_down(id, player._flat_dist_to(p.global_position)):
				_break_pact("a party member went down near you")
				return
	elif id == PACTS.VANGUARD:
		var mine := {}
		for e in player.get_tree().get_nodes_in_group("enemies"):
			if not e.has_method("threat_state_for") or not e.is_alive():
				continue
			var key: int = e.get_instance_id()
			if int(e.threat_state_for(player)) == 2:
				mine[key] = true
			elif _pact_on_me.has(key) and _pact_enemy_on_ally(e) and PACTS.breaks_on_lost_enemy(id):
				_break_pact("an enemy left you for a party member")
				return
		_pact_on_me = mine

## Is enemy `e` attacking another player of my party right now? (On a party
## member's machine the host says who it is on; a decoy or a dummy is nobody.)
func _pact_enemy_on_ally(e: Node) -> bool:
	var net := player._net()
	if net == null:
		return false
	if net.is_client():
		var on: Variant = e.get("_net_threat")
		var member := int(on) if on != null else 0
		return member != 0 and member != int(net.my_id()) and net.members.has(member)
	var top: Variant = e.top_threat() if e.has_method("top_threat") else null
	return top != null and is_instance_valid(top) and (top as Node).is_in_group("remote_player")

## Keep the buff that shows the Pact (`key`: the Pact id, with "!" once broken;
## "" = none). Death clears every buff: it is put back when I am up again.
func _pact_show(key: String) -> void:
	if player.status == null:
		return
	if key == "":
		if _pact_shown != "":
			player.status.remove(PACT_FX)
			_pact_shown = ""
		return
	if (key == _pact_shown and player.status.has(PACT_FX)) or player.is_dead():
		return
	var id := pact_id()
	player.status.remove(PACT_FX)
	var fx := StatusContainer.make_buff(PACT_FX, PACTS.title(id, _pact_book()) + (" (broken)" if _pact_now_broken else ""), PACT_FX,
		0.0, 1.0e7, 1, PACTS.BROKEN_COLOR if _pact_now_broken else PACTS.COLOR)
	fx.stat_modifiers = {}
	fx.is_debuff = _pact_now_broken
	fx.show_time = false   # (it lasts for the whole dungeon)
	fx.description = PACTS.status_text(id, _pact_now_broken)
	player.status.apply(fx, player)
	_pact_shown = key

