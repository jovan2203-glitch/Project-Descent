extends "res://scripts/player/player_kit.gd"
class_name ShepherdKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "shepherd".
# --- Nature healer: the Shepherd ----------------------------------------------------------------
# The Weaver's healing twin: creatures woven of vines or grown from the ground,
# each here for one heal (the picture: scripts/nature_creature.gd). Woven ones
# (Fawn, Owl) leave Blossoms on the allies they heal, two when the heal is more
# than the ally was missing; rooted ones (Rootguard, Heartwood Elk) use up the
# Blossoms on their allies and heal or shield more for each. Dewfall is the
# filler (stronger on an ally with Blossoms, uses none). Wild Herd sends a Fawn
# at each of the lowest-health allies.
# Everything is decided here, on the healer's machine: who holds how many
# Blossoms, every heal. A party member is told through Net.support_ally (their
# StringsKit.receive_support): the Blossom buff, the Owl watching them, Rootguard's
# shield; they answer "owl_hit" (they were hit: the owl dives) and
# "rootguard_broke" (the shield was used up). A friendly dummy is handled here.
# Own only: only my rooted creatures use my Blossoms. Numbers: balance.gd
# (BLOSSOM_*, FAWN_*, ...; heals in HEALS); the talent: Running Herd.

const DEWFALL_ID := "dewfall"
const FAWN_ID := "fawn"
const ROOTGUARD_ID := "rootguard"
const OWL_ID := "owl"
const ELK_ID := "heartwoodelk"
const WILD_HERD_ID := "wildherd"
## The instants of the kit (_use_drafted -> _shepherd_use). Dewfall and Fawn are cast: SUPPORT_CASTS.
const SHEPHERD_INSTANTS := [ROOTGUARD_ID, OWL_ID, ELK_ID, WILD_HERD_ID]
## Meter / log id of the owl's strike (its own line: Details.HIT_NAMES).
const OWL_STRIKE_ID := "owlstrike"
const OWL_STRIKE_TAGS := ["Nature", "Spell"]
const BLOSSOM_FX := "blossom"       # on an ally: my Blossoms (per caster, stacks = how many)
const OWL_FX := "owl_watch"         # on an ally: my owl watching over them
const ROOTGUARD_FX := "rootguard"   # on an ally: Rootguard's shield
const FULL_BLOOM_FX := "full_bloom" # less damage taken (through the Hymns' path: HYMN_DR_NAMES)
const BLOSSOM_COLOR := Color(1.0, 0.62, 0.82)

var _blossoms := {}   # ally instance id -> {"who", "n", "until"}
var _owls := {}       # ally instance id -> {"who", "until"}: my owls watching
var _fawns := 0       # Fawns sent (Running Herd's capstone: every second one)
var _blossom_fx: Resource = null
# The other end: owls somebody (I, or a party member) has watching over me.
var _owl_from := {}   # caster instance id -> {"from", "until"}

# Rules as static functions (tests/test_nature.gd).

## `have` Blossoms and `k` more: never past BLOSSOM_MAX.
static func blossom_add(have: int, k: int) -> int:
	return clampi(have + maxi(k, 0), 0, Balance.BLOSSOM_MAX)

## Dewfall's heal multiplier on an ally with `n` Blossoms.
static func dewfall_mult(n: int) -> float:
	return 1.0 + Balance.DEWFALL_PER_BLOSSOM / 100.0 * maxi(n, 0)

## Is a heal of `amount` more than the `missing` health (the ally gets an extra Blossom)?
static func overheals(amount: int, missing: int) -> bool:
	return amount > maxi(missing, 0)

## Fawn's next ally: the lowest health share among those not `taken` yet (-1 = none).
static func fawn_pick(shares: Array, taken: Array) -> int:
	var best := -1
	var best_f := INF
	for i in shares.size():
		if i < taken.size() and bool(taken[i]):
			continue
		if float(shares[i]) < best_f:
			best_f = float(shares[i])
			best = i
	return best

## How many times a Fawn bounces: the `nth` one sent, with Running Herd's capstone or not.
static func fawn_bounces(nth: int, capstone: bool) -> int:
	return Balance.FAWN_BOUNCES + (Balance.RUNNING_HERD_EXTRA if capstone and nth > 0 and nth % 2 == 0 else 0)

## My Blossoms on `who` (0 when they ran out).
func blossoms_on(who: Variant) -> int:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who) or not (who is Node):
		return 0
	var e: Variant = _blossoms.get((who as Node).get_instance_id())
	return int(e["n"]) if e != null and float(e["until"]) > player.strings._str_now() else 0

## `k` more Blossoms on `who` (their time starts over).
func _add_blossom(who: Node3D, k: int) -> void:
	if who == null or not is_instance_valid(who) or k <= 0:
		return
	var n := blossom_add(blossoms_on(who), k)
	_blossoms[who.get_instance_id()] = {"who": who, "n": n, "until": player.strings._str_now() + Balance.BLOSSOM_TIME}
	_show_blossoms(who, n, Balance.BLOSSOM_TIME)

## Use up my Blossoms on `who`: how many there were.
func _take_blossoms(who: Node3D) -> int:
	var n := blossoms_on(who)
	if who != null and is_instance_valid(who):
		_blossoms.erase(who.get_instance_id())
		if n > 0:
			_show_blossoms(who, 0, 0.0)
	return n

## The Blossom buff on `who`, on whichever machine they live.
func _show_blossoms(who: Node3D, n: int, time: float) -> void:
	if is_same(who, player):
		_blossoms_shown(player.status, player, n, time)
	elif who.is_in_group("friendly"):
		_blossoms_shown(who.get_node_or_null("Status"), player, n, time)
	elif player._net():
		player._net().support_ally(who, player, "blossom", {"n": n, "t": time})

func _blossoms_shown(st: Node, from: Node, n: int, time: float) -> void:
	if st == null:
		return
	if n <= 0 or time <= 0.0:
		st.remove_from(BLOSSOM_FX, from)
		return
	if _blossom_fx == null:
		_blossom_fx = make_blossom_fx()
	if not st.has_from(BLOSSOM_FX, from):
		st.apply(_blossom_fx, from)
	st.set_stacks_from(BLOSSOM_FX, from, n)
	st.set_remaining_from(BLOSSOM_FX, from, time)

static func make_blossom_fx() -> Resource:
	var fx := StatusContainer.make_buff(BLOSSOM_FX, "Blossom", BLOSSOM_FX, 0.0, Balance.BLOSSOM_TIME, Balance.BLOSSOM_MAX, BLOSSOM_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 0   # (its stacks and time are set by the healer)
	fx.per_caster = true
	fx.tags = PackedStringArray(["Nature"])
	fx.description = "Flowers a healer's woven creatures left. Their rooted creatures use them up and heal or shield you more for each."
	return fx

static func make_owl_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(OWL_FX, "Owl", OWL_FX, 0.0, time, 1, BLOSSOM_COLOR)
	fx.stat_modifiers = {}
	fx.per_caster = true
	fx.tags = PackedStringArray(["Nature"])
	fx.description = "An owl watches over you. The first time you are hit, it dives to heal you."
	return fx

static func make_rootguard_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(ROOTGUARD_FX, "Rootguard", ROOTGUARD_FX, 0.0, time, 1, BLOSSOM_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature", "Defensive"])
	fx.description = "Roots wrapped around you absorb damage."
	return fx

func _tick_shepherd() -> void:
	if _blossoms.is_empty() and _owls.is_empty():
		return
	var now := player.strings._str_now()
	for key in _blossoms.keys():
		var e: Dictionary = _blossoms[key]
		if float(e["until"]) <= now or not is_instance_valid(e["who"]):
			_blossoms.erase(key)   # (the buff on them runs out by itself)
	for key in _owls.keys():
		var e: Dictionary = _owls[key]
		if float(e["until"]) <= now:
			_owls.erase(key)
			var who: Variant = e["who"]
			if who != null and is_instance_valid(who) and who.is_alive() and not player.is_dead():
				_add_blossom(who, 1)   # nothing hit them: it lands and leaves a Blossom

## Why a Shepherd instant can't be used right now ("" = it can).
func _shepherd_precheck(id: String) -> String:
	if id == OWL_ID or id == ROOTGUARD_ID:
		var pick := player._pick_support_target(id)
		if pick[0] == null:
			return str(pick[1]) if str(pick[1]) != "" else "No target"
	return ""

func _shepherd_use(id: String, res: Resource) -> void:
	match id:
		OWL_ID:
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				_owl(who)
		ROOTGUARD_ID:
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				_rootguard(who)
		ELK_ID:
			_heartwood_elk(float(res.radius))
		WILD_HERD_ID:
			_wild_herd(float(res.radius))

## Dewfall's or Fawn's cast finished (from _release_support).
func _shepherd_cast_heal(spell: String, tgt: Variant, _kind: String) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var who: Node3D = tgt
	if spell == DEWFALL_ID:
		player.strings._heal_coef(who, float(Abilities.HEALS[DEWFALL_ID]) * dewfall_mult(blossoms_on(who)), DEWFALL_ID)
		player._ring_effect(0.9, BLOSSOM_COLOR, who.global_position)
	else:
		_fawn(who, FAWN_ID, player._muzzle() if player.is_inside_tree() else player.global_position)

## A woven creature's heal of `coef` on `who`: a Blossom, two if it overheals.
func _woven_heal(who: Node3D, coef: float, id: String) -> void:
	var h: Variant = who.get("health")
	var mh: Variant = who.get("max_health")
	var missing := int(mh) - int(h) if h != null and mh != null else 1 << 30
	var amount := player.strings._heal_coef(who, coef, id)
	_add_blossom(who, 2 if overheals(amount, missing) else 1)

# Fawn: a chain from ally to ally.

func _fawn(first: Node3D, id: String, from_pos: Vector3) -> void:
	_fawns += 1
	var hops := fawn_bounces(_fawns, player._capstone("nature_running_herd"))   # Running Herd's capstone
	var coef := float(Abilities.HEALS[FAWN_ID]) * (1.0 + player._talent("nature_running_herd") / 100.0)   # Running Herd
	_fawn_hop(first, from_pos, coef, hops, [], id)

## The fawn leaps from `from_pos` to `who`, heals them, then on to the next ally (`left` more).
func _fawn_hop(who: Node3D, from_pos: Vector3, coef: float, left: int, healed: Array, id: String) -> void:
	player.weaver._creature("fawn", from_pos, who.global_position + Vector3(0, 0.5, 0))
	player.weaver._after(Balance.WOVEN_STRIKE_DELAY, func():
		if player.is_dead() or not is_instance_valid(who) or not who.is_alive():
			return
		_woven_heal(who, coef, id)
		healed.append(who)
		if left <= 0:
			return
		var near := player.prism_kit._allies_near(who.global_position, Balance.FAWN_REACH)
		var shares: Array = near.map(func(a): return player.hymns._health_share_of(a))
		var taken: Array = near.map(func(a): return healed.has(a))
		var i := fawn_pick(shares, taken)
		if i >= 0:
			_fawn_hop(near[i], who.global_position + Vector3(0, 0.5, 0), coef * Balance.FAWN_FALLOFF, left - 1, healed, id))

## Wild Herd: a Fawn at each of the lowest-health allies within `radius` of me.
func _wild_herd(radius: float) -> void:
	var allies := player._allies_within(radius)
	allies.sort_custom(func(a, b): return player.hymns._health_share_of(a) < player.hymns._health_share_of(b))
	var from := player._muzzle() if player.is_inside_tree() else player.global_position
	for i in mini(allies.size(), Balance.WILD_HERD_FAWNS):
		_fawn(allies[i], WILD_HERD_ID, from)

# Owl: watches an ally, dives when they are hit.

func _owl(who: Node3D) -> void:
	_owls[who.get_instance_id()] = {"who": who, "until": player.strings._str_now() + Balance.OWL_TIME}
	if is_same(who, player):
		_owl_watched(player, Balance.OWL_TIME)
	elif who.is_in_group("friendly"):
		var st: Node = who.get_node_or_null("Status")
		if st:
			st.apply(make_owl_fx(Balance.OWL_TIME), player)
	elif player._net():
		player._net().support_ally(who, player, "owl", {"t": Balance.OWL_TIME})
	player._ring_effect(1.0, BLOSSOM_COLOR, who.global_position)

## An owl of `from`'s watches over me for `time` sec.
func _owl_watched(from: Node, time: float) -> void:
	if from == null or not is_instance_valid(from) or player.status == null or player.is_dead():
		return
	_owl_from[from.get_instance_id()] = {"from": from, "until": player.strings._str_now() + time}
	player.status.apply(make_owl_fx(time), from)
	player.status.set_remaining_from(OWL_FX, from, time)

## A hit on me (_on_hit_taken): every owl watching over me dives.
func _owl_taken(info: RefCounted) -> void:
	if _owl_from.is_empty() or info.avoided():
		return
	var now := player.strings._str_now()
	for key in _owl_from.keys():
		var from: Variant = _owl_from[key]["from"]
		var live := float(_owl_from[key]["until"]) > now
		_owl_from.erase(key)
		if from == null or not is_instance_valid(from):
			continue
		player.status.remove_from(OWL_FX, from)
		if not live:
			continue
		if is_same(from, player):
			_owl_dive(player, info.source)
		elif player._net():
			player._net().support_ally(from, player, "owl_hit", {})

## My owl over `who` dives: it heals them and strikes `attacker` (or the nearest enemy to them).
func _owl_dive(who: Node3D, attacker: Variant = null) -> void:
	if who == null or not is_instance_valid(who) or not _owls.has(who.get_instance_id()):
		return
	_owls.erase(who.get_instance_id())
	if player.is_dead() or not who.is_alive():
		return
	player.weaver._creature("owl", who.global_position + Vector3(0, 4.0, 0), who.global_position + Vector3(0, 1.0, 0))
	player.weaver._after(Balance.WOVEN_STRIKE_DELAY, func():
		if player.is_dead() or not is_instance_valid(who) or not who.is_alive():
			return
		_woven_heal(who, float(Abilities.HEALS[OWL_ID]), OWL_ID)
		var foe: Variant = attacker if attacker != null and is_instance_valid(attacker) and (attacker as Node).is_in_group("enemies") \
			and attacker.is_alive() and _flat_dist(who.global_position, attacker.global_position) <= Balance.OWL_REACH else _nearest_enemy_to(who.global_position, Balance.OWL_REACH)
		if foe != null:
			player.deal_damage(foe, float(Abilities.get_resource(OWL_ID).damage), OWL_STRIKE_ID, true, "nature", PackedStringArray(OWL_STRIKE_TAGS)))

func _nearest_enemy_to(point: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e in player._enemies_near(point, radius):
		var d := _flat_dist(point, (e as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Rootguard: a shield of roots.

func _rootguard(who: Node3D) -> void:
	var n := _take_blossoms(who)
	var coef := WeaverKit.rooted_coef(float(Abilities.HEALS[ROOTGUARD_ID]), Balance.ROOTGUARD_PER_BLOSSOM, n)
	var amount := int(round(player._combat().heal_amount(player, coef, ROOTGUARD_ID) * player.absorb_mult()))   # (Rime Ward: bigger shields)
	player.weaver._creature("roots", player.weaver._ground_under(who), who.global_position)
	if is_same(who, player):
		_rootguard_on(player.status, player, amount, Balance.ROOTGUARD_TIME, func(): _rootguard_broke(player))
	elif who.is_in_group("friendly"):
		_rootguard_on(who.get_node_or_null("Status"), player, amount, Balance.ROOTGUARD_TIME, func(): _rootguard_broke(who))
	elif player._net():
		player._net().support_ally(who, player, "rootguard", {"amount": amount, "time": Balance.ROOTGUARD_TIME})
	player._combat().float_text(who, "%s (%d)" % [Abilities.ability_name(ROOTGUARD_ID), amount], BLOSSOM_COLOR, false)

## Rootguard's shield of `amount` (from `from`) on whoever owns Status `st`; `on_break` when used up.
func _rootguard_on(st: Node, from: Node, amount: int, time: float, on_break: Callable) -> void:
	if st == null or amount <= 0:
		return
	st.apply(make_rootguard_fx(time), from)
	st.set_remaining(ROOTGUARD_FX, time)
	st.set_absorb(ROOTGUARD_FX, amount, on_break)

## My Rootguard on `who` was used up: a Blossom on every ally near them.
func _rootguard_broke(who: Variant) -> void:
	if who == null or not is_instance_valid(who) or player.is_dead():
		return
	for a in player.prism_kit._allies_near((who as Node3D).global_position, Balance.ROOTGUARD_SPREAD):
		_add_blossom(a, 1)

# Heartwood Elk: heals every ally near me, more for their Blossoms.

func _heartwood_elk(radius: float) -> void:
	var allies := player._allies_within(radius)
	var share := Balance.aoe_share(allies.size())
	var feet := player.weaver._ground_under(player)
	player.weaver._creature("elk", feet + player.global_transform.basis.z * 1.5, feet)
	player.weaver._after(Balance.ROOTED_STRIKE_DELAY, func():
		if player.is_dead():
			return
		for a in allies:
			if not is_instance_valid(a) or not a.is_alive():
				continue
			var n := _take_blossoms(a)
			player.strings._heal_coef(a, WeaverKit.rooted_coef(float(Abilities.HEALS[ELK_ID]), Balance.ELK_PER_BLOSSOM, n) * share, ELK_ID)
			if n >= Balance.BLOSSOM_MAX:
				player.hymns._hymn_dr(a, FULL_BLOOM_FX, Balance.FULL_BLOOM_PCT, Balance.FULL_BLOOM_TIME)   # Full Bloom
		player._ring_effect(radius, BLOSSOM_COLOR))

