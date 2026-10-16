extends "res://scripts/player/player_kit.gd"
class_name ColossusKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "colossus".
# --- Nature tank: the Colossus ---------------------------------------------------------------
# A huge vine giant fights through me, one limb at a time: each ability weaves
# one limb behind me for one strike or block (the picture: scripts/nature_creature.gd),
# then it unravels. Vine Fist (the Rage builder) punches over my shoulder, Grasp's
# hand carries an enemy to my feet, Stomp's foot comes down around me and leaves
# thorny roots, Giant's Hands close around me as a shield that bursts when it
# goes, Heartsap opens the chest behind me to heal, and Awaken raises the whole
# giant for a while.
# Sap (a buff on me) heals me every second while I have it; Vine Fist, Stomp and
# hits on the Hands give it, Heartsap uses it all. Everything is on my own
# machine: the hits are mine, the party sees the limbs faint ("creature" fx).
# Numbers: balance.gd (SAP_*, VINE_FIST_*, STOMP_*, GIANTS_HANDS_*, HEARTSAP_*,
# AWAKEN_*, GRASP_*); the talent: Thick Sap.

const VINE_FIST_ID := "vinefist"
const GRASP_ID := "grasp"
const STOMP_ID := "stomp"
const GIANTS_HANDS_ID := "giantshands"
const HEARTSAP_ID := "heartsap"
const AWAKEN_ID := "awaken"
const COLOSSUS_IDS := [VINE_FIST_ID, GRASP_ID, STOMP_ID, GIANTS_HANDS_ID, HEARTSAP_ID, AWAKEN_ID]
## Meter / log ids of what isn't an ability's own hit (their own lines: Details.HIT_NAMES).
const STOMP_ROOTS_ID := "stomproots"
const GIANTS_SLAM_ID := "giantsslam"
const SAP_HEAL_ID := "sap"
const COLOSSUS_TAGS := ["Ability", "Nature", "Melee"]
const STOMP_ROOTS_TAGS := ["Ability", "Nature", "DoT"]
const SAP_FX := "sap"
const GIANTS_HANDS_FX := "giantshands"
const AWAKEN_FX := "awaken"
const GRASPED_FX := preload("res://data/effects/grasped.tres")
const SAP_COLOR := Color(1.0, 0.72, 0.25)

var _sap_fx: Resource = null
var _sap_next := 0.0         # when Sap next heals me
var _hands_on := false       # Giant's Hands is up (it bursts when it goes)
var _stomp_roots := []       # [{"at", "radius", "coef", "ticks", "next", "every"}]
var _grasped := {}           # enemy instance id -> until: held by my Grasp (Stomp hits them twice as hard)

# Rules as static functions (tests/test_nature.gd).

## `have` Sap and `more`: never past SAP_MAX.
static func sap_after(have: int, more: int) -> int:
	return clampi(have + maxi(more, 0), 0, Balance.SAP_MAX)

## Health `n` Sap heals each second on a character with `max_hp`.
static func sap_heal(max_hp: int, n: int) -> float:
	return float(max_hp) * Balance.SAP_HEAL_PCT / 100.0 * float(clampi(n, 0, Balance.SAP_MAX))

## Heartsap's heal, in % of maximum health, using `n` Sap (`more_pct`: Thick Sap).
static func heartsap_pct(n: int, more_pct: float) -> float:
	return (Balance.HEARTSAP_BASE_PCT + Balance.HEARTSAP_PER_SAP * float(maxi(n, 0))) * (1.0 + more_pct / 100.0)

## Sap a Stomp that hit `hits` enemies gives.
static func stomp_sap(hits: int) -> int:
	return Balance.STOMP_SAP_MANY if hits >= Balance.STOMP_SAP_HITS else (Balance.STOMP_SAP if hits > 0 else 0)

## Giant's Hands' shield on a character with `max_hp` (`awake`: during Awaken; `absorb`: Rime Ward).
static func hands_amount(max_hp: int, awake: bool, absorb: float = 1.0) -> int:
	var pct := Balance.GIANTS_HANDS_PCT * ((1.0 + Balance.AWAKEN_HANDS_PCT / 100.0) if awake else 1.0)
	return int(round(float(max_hp) * pct / 100.0 * absorb))

## How much Sap I have.
func sap() -> int:
	return player.status.stacks_of(SAP_FX) if player.status != null else 0

func awakened() -> bool:
	return player.status != null and player.status.has(AWAKEN_FX)

## Gain `more` Sap (more during Awaken); its time starts over.
func _gain_sap(more: int) -> void:
	if player.status == null or more <= 0 or player.is_dead():
		return
	if awakened():
		more *= Balance.AWAKEN_SAP_MULT
	var want := sap_after(sap(), more)
	if _sap_fx == null:
		_sap_fx = StatusContainer.make_buff(SAP_FX, "Sap", Stats.BLOCK, 0.0, Balance.SAP_TIME, Balance.SAP_MAX, SAP_COLOR)
		_sap_fx.stat_modifiers = {}
		_sap_fx.tags = PackedStringArray(["Nature"])
		_sap_fx.description = "Sap glowing in your bark heals you every second. Heartsap uses it all up."
	if not player.status.apply(_sap_fx, player):
		return
	if player.status.stacks_of(SAP_FX) != want:
		player.status.set_stacks(SAP_FX, want)
	player.status.set_remaining(SAP_FX, Balance.SAP_TIME)

func _tick_colossus() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Sap heals me once a second.
	if player.status != null and player.status.has(SAP_FX) and now >= _sap_next:
		_sap_next = now + 1.0
		if not player.is_dead() and player.health < player.max_health:
			player.heal(sap_heal(player.max_health, sap()), SAP_HEAL_ID)
	# Giant's Hands went (used up or ran out): they burst open.
	if _hands_on and (player.status == null or not player.status.has(GIANTS_HANDS_FX)):
		_hands_on = false
		_hands_burst()
	if not _grasped.is_empty():
		for key in _grasped.keys():
			if float(_grasped[key]) <= now:
				_grasped.erase(key)
	_tick_stomp_roots(now)

## Why a Colossus ability can't be used right now ("" = it can).
func _colossus_precheck(id: String) -> String:
	if id == HEARTSAP_ID and sap() <= 0:
		return "You have no Sap"
	return ""

## One of the Colossus' abilities (paid for and put on cooldown by _use_drafted).
func _colossus_use(id: String, res: Resource) -> void:
	match id:
		VINE_FIST_ID:
			_vine_fist(res)
		GRASP_ID:
			_grasp()
		STOMP_ID:
			_stomp(res)
		GIANTS_HANDS_ID:
			_giants_hands()
		HEARTSAP_ID:
			_heartsap()
		AWAKEN_ID:
			_awaken()

## Behind my shoulder, where the giant's fist comes from.
func _shoulder() -> Vector3:
	return player.global_position + Vector3(0, 2.2, 0) + player.global_transform.basis.z * 0.8

func _vine_fist(res: Resource) -> void:
	if not player._has_valid_target():
		return
	var foe: Node3D = player.target
	var others: Array = player._enemies_near(foe.global_position, Balance.VINE_FIST_REACH, foe).slice(0, Balance.VINE_FIST_EXTRA)
	var awake := awakened()
	player.weaver._creature("fist", _shoulder(), foe.global_position + Vector3(0, 0.8, 0))
	player.weaver._after(Balance.WOVEN_STRIKE_DELAY, func():
		if player.is_dead():
			return
		if is_instance_valid(foe) and foe.is_alive():
			player.deal_damage(foe, float(res.damage), VINE_FIST_ID)
			if awake and is_instance_valid(foe) and foe.is_alive():
				player.deal_damage(foe, float(res.damage), VINE_FIST_ID)   # Awaken: it hits twice
		for o in others:
			if is_instance_valid(o) and o.is_alive():
				player.deal_damage(o, Balance.VINE_FIST_SPLASH, VINE_FIST_ID)
		if awake:
			# ... and slams the ground around me.
			var near := player._enemies_within(Balance.AWAKEN_SLAM_RADIUS)
			var share := Balance.aoe_share(near.size())
			for e in near:
				player.deal_damage(e, Balance.AWAKEN_SLAM * share, GIANTS_SLAM_ID, true, "nature", PackedStringArray(COLOSSUS_TAGS))
			player._ring_effect(Balance.AWAKEN_SLAM_RADIUS, SAP_COLOR)
		_gain_sap(Balance.VINE_FIST_SAP))

## Grasp: a hand rises under my target and drops it at my feet; it must attack me and is held.
func _grasp() -> void:
	if not player._has_valid_target():
		return
	var foe: Node3D = player.target
	player.weaver._creature("hand", player.weaver._ground_under(foe), player.weaver._ground_under(player))
	var gap := Combat.hitbox_radius(foe) + Combat.hitbox_radius(player) + Balance.GRASP_GAP
	var to := LightningTankKit.reel_in_point(player.global_position, foe.global_position, gap)
	to.y = foe.global_position.y + (Combat.feet_y(player) - Combat.feet_y(foe))   # onto my level
	var net := player._net()
	if net:
		net.pull(foe, player, to, Balance.GRASP_TAUNT)
	elif foe.has_method("pull_to"):
		foe.pull_to(player, to, Balance.GRASP_TAUNT, Balance.REEL_IN_DRAG_TIME)
	else:
		player._net_taunt(foe, Balance.GRASP_TAUNT)
	player.weaver._after(Balance.REEL_IN_DRAG_TIME, func():
		if player.is_dead() or not is_instance_valid(foe) or not foe.is_alive():
			return
		player._combat().apply_effect(player, foe, GRASPED_FX, GRASP_ID, PackedStringArray(COLOSSUS_TAGS))
		_grasped[foe.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + Balance.GRASP_HOLD)

## Is `e` held by my Grasp right now?
func grasped(e: Node) -> bool:
	return e != null and is_instance_valid(e) and float(_grasped.get(e.get_instance_id(), 0.0)) > Time.get_ticks_msec() / 1000.0

## Stomp: the foot comes down around me; every enemy there must attack me. Roots stay in the cracks.
func _stomp(res: Resource) -> void:
	var reach := Balance.AWAKEN_STOMP_RADIUS if awakened() else float(res.radius)
	var feet := player.weaver._ground_under(player)
	player.weaver._creature("foot", feet + player.global_transform.basis.z * 0.5, feet - player.global_transform.basis.z * 1.2)
	player.weaver._after(Balance.ROOTED_STRIKE_DELAY, func():
		if player.is_dead():
			return
		var foes := player._enemies_within(reach)
		var share := Balance.aoe_share(foes.size())
		for e in foes:
			var mult := Balance.STOMP_HELD_MULT if grasped(e) else 1.0
			player.deal_damage(e, float(res.damage) * share * mult, STOMP_ID)
			player._net_taunt(e, Balance.STOMP_TAUNT)
		_start_stomp_roots(player.weaver._ground_under(player), reach)
		_gain_sap(stomp_sap(foes.size()))
		player._ring_effect(reach, SAP_COLOR)
		player._ring_effect(reach * 0.5, Color(0.62, 1.0, 0.38)))

func _start_stomp_roots(at: Vector3, radius: float) -> void:
	var base_ticks := maxi(int(round(Balance.STOMP_ROOTS_TIME / Balance.STOMP_ROOTS_TICK)), 1)
	var every := Balance.STOMP_ROOTS_TICK / player.haste_mult()
	_stomp_roots.append({"at": at, "radius": radius, "coef": Balance.STOMP_ROOTS_DAMAGE / base_ticks,
		"ticks": maxi(int(round(Balance.STOMP_ROOTS_TIME / every)), 1), "next": Time.get_ticks_msec() / 1000.0 + every, "every": every})

func _tick_stomp_roots(now: float) -> void:
	for i in range(_stomp_roots.size() - 1, -1, -1):
		var z: Dictionary = _stomp_roots[i]
		if int(z["ticks"]) <= 0 or player.is_dead():
			_stomp_roots.remove_at(i)
			continue
		if now < float(z["next"]):
			continue
		z["ticks"] = int(z["ticks"]) - 1
		z["next"] = float(z["next"]) + float(z["every"])
		var foes := player._enemies_near(z["at"], float(z["radius"]))
		var coef := float(z["coef"]) * Balance.aoe_share(foes.size())
		for e in foes:
			var info = player._combat().ability_hit_info(player, e, coef, STOMP_ROOTS_ID, true, "nature", PackedStringArray(STOMP_ROOTS_TAGS))
			info.is_dot = true
			player._combat().deal(info)

## Giant's Hands: a shield of part of my health; hits on it give Sap, and when it goes it bursts.
func _giants_hands() -> void:
	var amount := hands_amount(player.max_health, awakened(), player.absorb_mult())   # (Rime Ward: bigger shields)
	var fx := StatusContainer.make_buff(GIANTS_HANDS_FX, Abilities.ability_name(GIANTS_HANDS_ID), GIANTS_HANDS_FX, 0.0,
		Balance.GIANTS_HANDS_TIME, 1, SAP_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature", "Defensive"])
	fx.description = "The giant's hands around you absorb damage. Each hit they take gives Sap; when they go, they burst open."
	player.status.apply(fx, player)
	player.status.set_remaining(GIANTS_HANDS_FX, Balance.GIANTS_HANDS_TIME)
	player.status.set_absorb(GIANTS_HANDS_FX, amount)
	_hands_on = true
	var feet := player.weaver._ground_under(player)
	player.weaver._creature("hands", feet, feet - player.global_transform.basis.z)
	player._combat().float_text(player, "%s (%d)" % [Abilities.ability_name(GIANTS_HANDS_ID), amount], SAP_COLOR, false)

func _hands_burst() -> void:
	if player.is_dead():
		return
	var res := Abilities.get_resource(GIANTS_HANDS_ID)
	var reach := float(res.radius)
	var foes := player._enemies_within(reach)
	var share := Balance.aoe_share(foes.size())
	for e in foes:
		player.deal_damage(e, float(res.damage) * share, GIANTS_HANDS_ID)
	player._ring_effect(reach, SAP_COLOR)

## Something hit me (_on_hit_taken): a hit Giant's Hands soaked gives Sap.
func _colossus_hit_taken(info: RefCounted) -> void:
	if _hands_on and int(info.absorbed) > 0 and not bool(info.is_dot):
		_gain_sap(Balance.HANDS_SAP)

## Heartsap: all my Sap at once as a heal.
func _heartsap() -> void:
	var n := sap()
	player.status.remove(SAP_FX)
	player.heal(float(player.max_health) * heartsap_pct(n, player._talent("nature_thick_sap")) / 100.0, HEARTSAP_ID)   # + Thick Sap
	if player.frost_melee._capstone("nature_thick_sap"):
		_gain_sap(Balance.THICK_SAP_KEEP)   # Thick Sap's capstone: some stays
	var feet := player.weaver._ground_under(player)
	player.weaver._creature("chest", feet + player.global_transform.basis.z * 1.4, feet)
	player._ring_effect(1.2, SAP_COLOR)

## Awaken: the whole giant rises behind me for a while.
func _awaken() -> void:
	var fx := StatusContainer.make_buff(AWAKEN_FX, Abilities.ability_name(AWAKEN_ID), AWAKEN_FX, 0.0, Balance.AWAKEN_TIME, 1, SAP_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature", "Defensive"])
	fx.damage_mod_pct = -Balance.AWAKEN_DR_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "The whole giant stands behind you: you take %s%% less damage and your limbs strike harder." % Stats.num(Balance.AWAKEN_DR_PCT)
	player.status.apply(fx, player)
	player.status.set_remaining(AWAKEN_FX, Balance.AWAKEN_TIME)
	if player.is_inside_tree():
		var behind := player.weaver._ground_under(player) + player.global_transform.basis.z * 1.6
		var ahead := player.weaver._ground_under(player) - player.global_transform.basis.z * 2.0
		WeaverKit.NATURE_CREATURE.spawn(player.get_tree().current_scene, "giant", behind, ahead, false, player)
		player._net_fx("creature", behind, null, {"k": "giant", "to": ahead})
	player._ring_effect(2.0, SAP_COLOR)

