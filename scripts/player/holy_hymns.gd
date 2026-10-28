extends "res://scripts/player/player_kit.gd"
class_name HymnsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "hymns".
# --- Holy healer: the Hymns ----------------------------------------------------------------------
# I sing one of three Hymns (none until I first sing one):
#   Mercy   my heals on a single ally heal MERCY_HEAL_PCT % more.
#   Chorus  those heals (not Refrain's ticks) also heal up to CHORUS_SPLASH_TARGETS
#           allies near their target, for a share (its own meter line).
#   Vigil   allies near me take less damage (a buff renewed every VIGIL_TELL_EVERY),
#           and my heals leave a small shield on whoever they heal.
# My Holy healer abilities give Verses (VERSE_GAINS; VERSE_MAX at most, more are
# wasted). Each Verse remembers the Hymn it suits: single-target heals Mercy, heals
# on many Chorus, shields and less damage taken Vigil. Singing another Hymn:
#   with VERSE_MAX Verses  the Hymn I enter booms (Benediction, Chorale, Bulwark of
#                          Song), stronger for each spent Verse that suits it, and
#                          every Verse is spent. When my last three booms were the
#                          three Hymns, the third is a Full Choir: stronger, and
#                          FULL_CHOIR_REFUND Verses come back.
#   with fewer             they are lost (Key Change keeps some, Rest keeps all).
#   from no Hymn yet       nothing is lost (but VERSE_MAX still booms).
# Out of combat the Verses fade, one every VERSE_DRAIN_EVERY seconds.
# Everything is decided here, on the healer's machine. A party member hears of it
# through Net.support_ally: "heal" (like every heal), "hymn_dr" (less damage taken:
# Vigil, Steady Voice, Bulwark of Song) and "hymn_ward" (a shield: Shelter, Vigil's);
# standing in my Vigil they answer "vigil_hit" when a big hit lands (Watchful). The
# ring around me is scripts/hymn_ring.gd (only a picture); the party sees it through
# the "hymn" and "hymn_boom" fx. Numbers: balance.gd (VERSE_*, MERCY_*, ...).
# Talents here: Mercy's Ear, Many Voices, Watchful (Verses now and then), Key Change,
# Held Note (keeping Verses), Long Note, Rising Voice, Mercy Seat and Radiance's
# capstone (the booms), Full Voice (Full Choir), Long Echo (Reprise), Breath
# Between (mana from booms), Tender Mercy (Mercy), Choir Loft and Swelling Chorus
# (Chorus), Night Watch and Warded Song (Vigil), Open Doors (Shelter).

const HYMN_RING = preload("res://scripts/hymn_ring.gd")
const HIGH_NOTE_ID := "highnote"
const SING_IDS := {"singmercy": "mercy", "singchorus": "chorus", "singvigil": "vigil"}
const HYMN_NAMES := {"mercy": "Mercy", "chorus": "Chorus", "vigil": "Vigil"}
const BOOM_NAMES := {"mercy": "Benediction", "chorus": "Chorale", "vigil": "Bulwark of Song"}
## Meter / log ids (Details.HIT_NAMES) of the booms' heals, Chorus's splash and the rune's hit.
const BOOM_IDS := {"mercy": "benediction", "chorus": "chorale", "vigil": "bulwark_of_song"}
const CHORUS_SPLASH_ID := "chorus_splash"
const ANTIPHON_SELF_ID := "antiphon_self"   # Antiphon's heal on me (shown as Antiphon)
const RESOUNDING_ID := "resounding"
const RESOUNDING_RUNE := "resounding"
const OVERTURE_RUNE := "overture"
## What each ability gives (balance.gd).
const VERSE_GAINS := Balance.VERSE_GAINS
## Heals on a single ally: Mercy makes them stronger, Chorus splashes them (not Refrain's ticks).
const HYMN_SINGLE_HEALS := ["psalm", "outpour", "lift", "refrain", "antiphon"]
const CHORUS_SPLASHES := ["psalm", "outpour", "lift", "antiphon"]
## My heals that leave Vigil's shield, and that Mercy's Ear listens to.
const HYMN_HEALS := ["psalm", "outpour", "lift", "refrain", "antiphon", "canticle", "exultation", "highnote",
	"benediction", "chorale"]
## The kit's instant abilities (Psalm, Outpour, Canticle and Exultation are cast: SUPPORT_CASTS; High Note is a bolt).
const HYMN_INSTANTS := ["lift", "refrain", "antiphon", "shelter", "steadyvoice", "reprise", "swell", "rest", "lastverse",
	"singmercy", "singchorus", "singvigil"]
## Buffs (StatusEffect ids). The ones that take damage off are sent to party members as "hymn_dr".
const VIGIL_FX := "vigil"
const STEADY_VOICE_FX := "steady_voice"
const BULWARK_SONG_FX := "bulwark_of_song"
const REST_FX := "rest"
const SWELL_FX := "swell"
const OVERTURE_FX := "overture"
const SHELTER_FX := "shelter"
const VIGIL_WARD_FX := "vigil_ward"
const HYMN_DR_NAMES := {VIGIL_FX: "Vigil", STEADY_VOICE_FX: "Steady Voice", BULWARK_SONG_FX: "Bulwark of Song", REST_FX: "Rest",
	"full_bloom": "Full Bloom", "canopy": "Canopy"}   # (Full Bloom, Canopy: the Nature healer's, same path)
const HYMN_WARD_NAMES := {SHELTER_FX: "Shelter", VIGIL_WARD_FX: "Vigil's Ward", PrismsKit.PRISM_WARD_FX: "Prism Ward", HolyTalentsKit.OVERFLOWING_FX: "Overflowing"}   # (the Prisms' shield uses the same path)
const HOLY_LIGHT := Color(1.0, 0.88, 0.45)

var hymn := ""              # the Hymn I sing ("" = none yet)
var verses: Array = []      # my Verses, oldest first: each is the Hymn it suits
var _booms: Array = []      # the Hymns of my booms since the last Full Choir
var _last_boom := {}        # {"hymn", "matches", "full", "at"}: what Reprise repeats
var _verse_drain_at := 0.0
var _vigil_told := 0.0
var _refrains := {}         # target instance id -> {"node", "until", "next", "per"}
var _talent_verse_at := {}  # talent key -> when it last gave me a Verse
var _vigil_from := {}       # caster instance id -> {"from": Node, "until": time}: whose Vigil I stand in

# The rules, as plain functions (tests/test_hymns.gd).

## `have` Verses plus `n` that suit `kind`: none past VERSE_MAX.
static func verses_after_gain(have: Array, kind: String, n: int) -> Array:
	var out := have.duplicate()
	for i in maxi(n, 0):
		if out.size() >= Balance.VERSE_MAX:
			break
		out.append(kind)
	return out

## Singing a Hymn with `count` Verses: [does the Hymn I enter boom, how many Verses I keep].
## `from` = the Hymn I sang until now ("" = none); `kept` = Key Change's; `resting` = Rest.
static func sing_outcome(count: int, from: String, kept: int, resting: bool) -> Array:
	if count >= Balance.VERSE_MAX:
		return [true, 0]
	if from == "" or resting:
		return [false, maxi(count, 0)]
	return [false, clampi(kept, 0, maxi(count, 0))]

## How many of the `spent` Verses suit the Hymn `boom` (each makes the boom stronger).
static func matching_verses(spent: Array, boom: String) -> int:
	var n := 0
	for v in spent:
		if str(v) == boom:
			n += 1
	return n

## A boom's strength with `matches` Verses that suit it (`full`: a Full Choir).
static func boom_mult(matches: int, full: bool) -> float:
	var m := 1.0 + Balance.BOOM_MATCH_PCT * clampi(matches, 0, Balance.VERSE_MAX) / 100.0
	return m * (1.0 + Balance.FULL_CHOIR_PCT / 100.0 if full else 1.0)

## Bulwark of Song's seconds: longer for each Verse that suits it instead of stronger.
static func bulwark_song_time(matches: int, full: bool) -> float:
	var t := Balance.BULWARK_SONG_TIME + Balance.BULWARK_SONG_MATCH_TIME * clampi(matches, 0, Balance.VERSE_MAX)
	return t * (1.0 + Balance.FULL_CHOIR_PCT / 100.0 if full else 1.0)

## Is the newest of these booms (oldest first) a Full Choir: the last three were the three Hymns?
static func is_full_choir(booms: Array) -> bool:
	if booms.size() < 3:
		return false
	var last := booms.slice(booms.size() - 3)
	return last.has("mercy") and last.has("chorus") and last.has("vigil")

## Seconds between two Verses fading out of combat (`held`: Held Note's, if longer).
static func verse_drain_every(held: float) -> float:
	return maxf(Balance.VERSE_DRAIN_EVERY, held)

## The share (%) Reprise repeats a boom at (`call`: Long Echo's, if set).
static func reprise_pct(call: float) -> float:
	return call if call > 0.0 else Balance.REPRISE_PCT

## Radiance's capstone: how much stronger a boom is when all `matches` of its spent
## Verses suit it (`capstone`: it is on).
static func radiance_boost(matches: int, capstone: bool) -> float:
	return 1.0 + Balance.RADIANCE_MATCH_PCT / 100.0 if capstone and matches >= Balance.VERSE_MAX else 1.0

## Can Reprise be used `since` seconds after the last boom, with `count` Verses?
static func reprise_ready(since: float, count: int) -> bool:
	return since >= 0.0 and since <= Balance.REPRISE_WINDOW and count >= Balance.REPRISE_COST

## The share (0-1) of health someone at `hp` of `max_hp` has.
static func health_share(hp: float, max_hp: float) -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0

# Gaining and spending Verses.

## `n` Verses that suit `kind` (Swell: more, whatever gives them).
func _add_verses(kind: String, n: int) -> void:
	var extra: int = Balance.SWELL_EXTRA if player.status != null and player.status.has(SWELL_FX) else 0
	verses = verses_after_gain(verses, kind if kind != "" else "mercy", n + extra)

## Ability `id` was used: its Verses.
func _gain_verses(id: String) -> void:
	var g: Array = VERSE_GAINS.get(id, [])
	if g.is_empty():
		return
	var kind := str(g[1]) if str(g[1]) != "" else hymn
	_add_verses(kind, int(g[0]))

## The healer talents that give a Verse now and then (Mercy's Ear, Many Voices,
## Watchful): their value is the seconds between two of them.
func _talent_verse(key: String, kind: String) -> void:
	var every := player._talent(key)
	if every <= 0.0:
		return
	var now := player.strings._str_now()
	if now - float(_talent_verse_at.get(key, -INF)) < every:
		return
	_talent_verse_at[key] = now
	_add_verses(kind, 1)

func _tick_hymns() -> void:
	var now := player.strings._str_now()
	if player.is_dead():
		verses.clear()
		_refrains.clear()
		return
	# Out of combat the Verses fade.
	var drain := verse_drain_every(player._talent("holy_held_note"))   # (Held Note)
	if verses.is_empty() or player.is_in_combat():
		_verse_drain_at = now + drain
	elif now >= _verse_drain_at:
		verses.pop_front()
		_verse_drain_at = now + drain
	# Vigil: allies near me take less damage (renewed while they stay near).
	if hymn == "vigil" and now >= _vigil_told:
		_vigil_told = now + Balance.VIGIL_TELL_EVERY
		for a in player.fire_cooldowns._allies_within(Balance.VIGIL_RADIUS):
			_hymn_dr(a, VIGIL_FX, Balance.VIGIL_DR_PCT + player._talent("holy_night_watch"), Balance.VIGIL_BUFF_TIME)   # + Night Watch
	_tick_refrains(now)
	for key in _vigil_from.keys():
		if now > float(_vigil_from[key]["until"]):
			_vigil_from.erase(key)

# Singing, and the booms.

## Sing Mercy / Chorus / Vigil: enter that Hymn (booming with a full set of Verses).
func _sing(to: String) -> void:
	var resting: bool = player.status != null and player.status.has(REST_FX)
	var outcome := sing_outcome(verses.size(), hymn, int(round(player._talent("holy_key_change"))), resting)
	var spent := verses.duplicate()
	hymn = to
	if bool(outcome[0]):
		verses.clear()
		_boom(to, spent)
	else:
		var kept := int(outcome[1])
		verses = verses.slice(verses.size() - kept) if kept > 0 else []
	_vigil_told = 0.0   # (Vigil: at once)
	_show_hymn()

func _boom(h: String, spent: Array) -> void:
	_booms.append(h)
	var full := is_full_choir(_booms)
	if full:
		_booms.clear()   # (the next Full Choir needs three new booms)
	var matches := matching_verses(spent, h)
	_last_boom = {"hymn": h, "matches": matches, "full": full, "at": player.strings._str_now()}
	_do_boom(h, matches, full, 1.0, radiance_boost(matches, player.frost_melee._capstone("holy_radiance")))   # (Radiance's capstone)
	var breath := player._talent("holy_breath_between")
	if breath > 0.0:
		player._gain("mana", player.resource_max("mana") * breath / 100.0)   # Breath Between
	if full:
		_add_verses(h, Balance.FULL_CHOIR_REFUND + int(round(player._talent("holy_full_voice"))))   # + Full Voice
		player._combat().float_text(player, "Full Choir", Abilities.HYMN_COLORS[h], false)
	if player.frost_melee._has_rune(OVERTURE_RUNE) and player.status != null:
		player.status.apply(make_overture_fx(), player)

## A boom of Hymn `h` (`scale` < 1: Reprise's repeat of it; `boost`: Radiance's
## capstone, stronger or, for Bulwark of Song, longer).
func _do_boom(h: String, matches: int, full: bool, scale: float, boost: float = 1.0) -> void:
	var rising := 1.0 + player._talent("holy_rising_voice") / 100.0   # Rising Voice
	var mult := boom_mult(matches, full) * scale * rising * boost
	var at := player.global_position
	match h:
		"mercy":
			# My friendly target if Psalm could reach it (range, line of sight), else me.
			var pick: Variant = player._pick_support_target("psalm")[0]
			var who: Node3D = pick if pick != null else player
			var seat := 1.0
			if NatureTalentsOpenKit.below(float(who.get("health")), float(who.get("max_health")), Balance.MERCY_SEAT_HEALTH_PCT):
				seat += player._talent("holy_mercy_seat") / 100.0   # Mercy Seat
			player.strings._heal_coef(who, Balance.BENEDICTION_HEAL * mult * seat, BOOM_IDS[h])
			at = who.global_position
		"chorus":
			for a in player.fire_cooldowns._allies_within(Balance.CHORALE_RADIUS):
				player.strings._heal_coef(a, Balance.CHORALE_HEAL * mult, BOOM_IDS[h])
		"vigil":
			var t := (bulwark_song_time(matches, full) + player._talent("holy_long_note")) * boost   # + Long Note
			for a in player.fire_cooldowns._allies_within(Balance.BULWARK_SONG_RADIUS):
				_hymn_dr(a, BULWARK_SONG_FX, Balance.BULWARK_SONG_PCT * scale * rising, t)
	# Rune of Resounding: the boom strikes the enemies around it as well.
	if player.frost_melee._has_rune(RESOUNDING_RUNE):
		var foes := player._enemies_near(at, Balance.RESOUNDING_RADIUS)
		var share := Balance.aoe_share(foes.size())
		for e in foes:
			player.deal_damage(e, Balance.RESOUNDING_DAMAGE * scale * share, RESOUNDING_ID, true, "holy", PackedStringArray(["Holy", "Spell"]))
	if player.is_inside_tree():
		HYMN_RING.boom(player.get_tree().current_scene, at, Abilities.HYMN_COLORS[h])
	player._net_fx("hymn_boom", at, null, {"h": h})
	player._combat().float_text(player, BOOM_NAMES[h], Abilities.HYMN_COLORS[h], false)

## The ring around me shows my Hymn (and the party sees it).
func _show_hymn() -> void:
	if player.is_inside_tree():
		HYMN_RING.show_on(player, hymn)
	player._net_fx("hymn", player.global_position, null, {"h": hymn})

# The abilities.

## "Can I use it right now?" for the kit's instants (before paying).
func _hymn_precheck(id: String) -> String:
	if SING_IDS.has(id):
		return "You are already singing %s" % HYMN_NAMES[SING_IDS[id]] if hymn == SING_IDS[id] else ""
	match id:
		"lift", "refrain", "antiphon", "shelter":
			var pick := player._pick_support_target(id)
			if pick[0] == null:
				return str(pick[1])
		"reprise":
			if _last_boom.is_empty() or not reprise_ready(player.strings._str_now() - float(_last_boom["at"]), Balance.REPRISE_COST):
				return "You have not boomed in the last %s sec" % Stats.num(Balance.REPRISE_WINDOW)
			if verses.size() < Balance.REPRISE_COST:
				return "Not enough Verses"
		"lastverse":
			if verses.size() < Balance.VERSE_MAX:
				return "Not enough Verses"
			if player.strings._fallen_ally(float(Abilities.get_resource(id).cast_range)) == null:
				return "No downed ally in range"
			var rez_err := player.rez_kit.combat_rez_error()
			if rez_err != "":
				return rez_err
	return ""

func _hymn_use(id: String, res: Resource) -> void:
	if SING_IDS.has(id):
		_sing(SING_IDS[id])
		return
	match id:
		"lift":
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				player.strings._heal_coef(who, _hymn_heal_coef(id), id)
				player._ring_effect(0.8, HOLY_LIGHT, who.global_position)
		"refrain":
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				_start_refrain(who)
		"antiphon":
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				var amount := player.strings._heal_coef(who, _hymn_heal_coef(id), id)
				if not is_same(who, player):
					player.strings._heal_exact(player, int(round(amount * Balance.ANTIPHON_SELF_PCT / 100.0)), ANTIPHON_SELF_ID)   # (its own id: no second splash or ward)
				player._ring_effect(0.8, HOLY_LIGHT, who.global_position)
		"shelter":
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				var coef := float(Abilities.HEALS[id]) * (1.0 + player._talent("holy_open_doors") / 100.0)   # Open Doors
				_hymn_ward(who, SHELTER_FX, player._combat().heal_amount(player, coef, id), Balance.SHELTER_TIME)
				player._ring_effect(1.0, HOLY_LIGHT, who.global_position)
		"steadyvoice":
			for a in player.fire_cooldowns._allies_within(float(res.radius)):
				_hymn_dr(a, STEADY_VOICE_FX, Balance.STEADY_VOICE_PCT, Balance.STEADY_VOICE_TIME)
			player._ring_effect(float(res.radius), Abilities.HYMN_COLORS["vigil"])
		"reprise":
			verses = verses.slice(0, verses.size() - Balance.REPRISE_COST)
			_do_boom(str(_last_boom["hymn"]), int(_last_boom["matches"]), bool(_last_boom["full"]), reprise_pct(player._talent("holy_long_echo")) / 100.0)   # (Long Echo)
		"swell":
			player.status.apply(make_swell_fx(), player)
		"rest":
			player.status.apply(make_hymn_dr_fx(REST_FX, Balance.REST_PCT, Balance.REST_TIME), player)
			player.status.set_remaining(REST_FX, Balance.REST_TIME)
		"lastverse":
			var ally := player.strings._fallen_ally(float(res.cast_range))
			if ally and player._net():
				player._net().revive_ally(ally, player)
				player.rez_kit.spend_combat_rez()
				player._ring_effect(1.4, HOLY_LIGHT, ally.global_position)
			verses.clear()
	_gain_verses(id)

## A heal of the kit, as a coefficient: Mercy makes the ones on a single ally stronger.
func _hymn_heal_coef(id: String) -> float:
	var coef := float(Abilities.HEALS.get(id, 0.0))
	if hymn == "mercy" and HYMN_SINGLE_HEALS.has(id):
		coef *= 1.0 + Balance.MERCY_HEAL_PCT / 100.0
		coef *= 1.0 + player._talent("holy_tender_mercy") / 100.0   # Tender Mercy
	return coef

## Psalm, Outpour, Canticle and Exultation finished casting (_release_support).
func _hymn_cast_heal(spell: String, tgt: Variant, kind: String) -> void:
	match spell:
		"psalm", "outpour":
			var who: Variant = tgt if kind == "ally" and tgt != null and is_instance_valid(tgt) else player
			player.strings._heal_coef(who, _hymn_heal_coef(spell), spell)
			player._ring_effect(1.2, HOLY_LIGHT, (who as Node3D).global_position)
		"canticle":
			# The injured allies near me, lowest health first.
			var hurt: Array = player.fire_cooldowns._allies_within(float(Abilities.get_resource(spell).radius)).filter(func(a):
				return _health_share_of(a) < 1.0)
			hurt.sort_custom(func(a, b): return _health_share_of(a) < _health_share_of(b))
			hurt = hurt.slice(0, Balance.CANTICLE_TARGETS)
			for a in hurt:
				player.strings._heal_coef(a, _hymn_heal_coef(spell), spell)
				player._ring_effect(0.7, HOLY_LIGHT, (a as Node3D).global_position)
			if hurt.size() >= Balance.MANY_VOICES_ALLIES:
				_talent_verse("holy_many_voices", "chorus")   # Many Voices
		"exultation":
			var all := player.fire_cooldowns._allies_within(float(Abilities.get_resource(spell).radius))
			for a in all:
				player.strings._heal_coef(a, _hymn_heal_coef(spell), spell)
			player._ring_effect(float(Abilities.get_resource(spell).radius), HOLY_LIGHT)
			if all.size() >= Balance.MANY_VOICES_ALLIES:
				_talent_verse("holy_many_voices", "chorus")   # Many Voices
	_gain_verses(spell)

func _health_share_of(a: Variant) -> float:
	if a == null or not is_instance_valid(a):
		return 1.0
	return health_share(float(a.get("health")), float(a.get("max_health")))

# Refrain: a heal over time I keep track of (it heals through _heal_coef, so a
# party member is healed on their own machine like any other heal of mine).

func _start_refrain(who: Node3D) -> void:
	var now := player.strings._str_now()
	var per := _hymn_heal_coef("refrain") * Balance.REFRAIN_TICK / Balance.REFRAIN_TIME
	_refrains[who.get_instance_id()] = {"node": who, "until": now + Balance.REFRAIN_TIME,
		"next": now + Balance.REFRAIN_TICK / maxf(player.haste_mult(), 0.1), "per": per}
	player._ring_effect(0.8, HOLY_LIGHT, who.global_position)

func _tick_refrains(now: float) -> void:
	for key in _refrains.keys():
		var e: Dictionary = _refrains[key]
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who) or not who.is_alive():
			_refrains.erase(key)
			continue
		# Every tick due by now, the one that falls on its last moment included.
		while now >= float(e["next"]) and float(e["next"]) <= float(e["until"]) + 0.001:
			e["next"] = float(e["next"]) + Balance.REFRAIN_TICK / maxf(player.haste_mult(), 0.1)
			player.strings._heal_coef(who, float(e["per"]), "refrain")
		if float(e["next"]) > float(e["until"]) + 0.001:
			_refrains.erase(key)

# What my heals do on top (SignalBus.heal_done hears every heal).

func _on_heal_done_hymns(source: Node, healed: Node, amount: int, effective: int, id: String, _crit: bool) -> void:
	if amount <= 0 or not is_same(source, player) or healed == null or not is_instance_valid(healed):
		return
	if not HYMN_HEALS.has(id):
		return
	# Mercy's Ear: healing an ally who is low gives a Mercy Verse now and then.
	var before := _health_share_of(healed)
	if is_same(healed, player) or healed.is_in_group("friendly"):
		before = health_share(float(healed.get("health")) - effective, float(healed.get("max_health")))   # (already healed here)
	if before * 100.0 < Balance.MERCYS_EAR_HEALTH_PCT:
		_talent_verse("holy_mercys_ear", "mercy")
	match hymn:
		"chorus":
			if CHORUS_SPLASHES.has(id):
				_chorus_splash(healed as Node3D, amount)
		"vigil":
			_hymn_ward(healed as Node3D, VIGIL_WARD_FX, int(round(amount * Balance.VIGIL_WARD_PCT / 100.0
				* (1.0 + player._talent("holy_warded_song") / 100.0))), Balance.VIGIL_WARD_TIME)   # + Warded Song

## Chorus: up to CHORUS_SPLASH_TARGETS other allies near the one I healed get a share.
func _chorus_splash(healed: Node3D, amount: int) -> void:
	if healed == null:
		return
	var near: Array = []
	for a in player.fire_cooldowns._allies_within(INF):
		if not is_same(a, healed) and (a as Node3D).global_position.distance_to(healed.global_position) <= Balance.CHORUS_SPLASH_RADIUS:
			near.append(a)
	near.sort_custom(func(a, b): return healed.global_position.distance_squared_to(a.global_position) \
		< healed.global_position.distance_squared_to(b.global_position))
	near = near.slice(0, Balance.CHORUS_SPLASH_TARGETS + int(round(player._talent("holy_choir_loft"))))   # + Choir Loft
	var share := int(round(amount * Balance.CHORUS_SPLASH_PCT / 100.0 * (1.0 + player._talent("holy_swelling_chorus") / 100.0)))   # + Swelling Chorus
	for a in near:
		player.strings._heal_exact(a, share, CHORUS_SPLASH_ID)
	if near.size() + 1 >= Balance.MANY_VOICES_ALLIES:
		_talent_verse("holy_many_voices", "chorus")   # Many Voices (the splash counts)

## High Note landed: my lowest-health ally near me is healed for a share of its damage.
func _on_damage_dealt_holy(info: RefCounted) -> void:
	if info.source != player or info.ability_id != HIGH_NOTE_ID or int(info.amount) <= 0 or info.is_proc:
		return
	var allies := player.fire_cooldowns._allies_within(Balance.HIGH_NOTE_REACH)
	if allies.is_empty():
		return
	var shares: Array = allies.map(func(a): return _health_share_of(a))
	var who: Node3D = allies[FireCooldownsKit.lowest_share(shares)]
	player.strings._heal_exact(who, int(round(float(info.amount) * Balance.HIGH_NOTE_HEAL_PCT / 100.0)), HIGH_NOTE_ID)

# Effects on allies: less damage taken, and shields.

## `who` takes `pct` % less damage for `time` sec (buff `fx_id`), on whichever machine they live.
func _hymn_dr(who: Variant, fx_id: String, pct: float, time: float) -> void:
	if who == null or not is_instance_valid(who) or pct <= 0.0 or time <= 0.0:
		return
	if is_same(who, player):
		receive_hymn_dr(player, fx_id, pct, time)
	elif (who as Node).is_in_group("friendly"):
		var st: Node = (who as Node).get_node_or_null("Status")
		if st:
			st.apply(make_hymn_dr_fx(fx_id, pct, time), player)
			st.set_remaining(fx_id, time)
	elif player._net():
		player._net().support_ally(who, player, "hymn_dr", {"id": fx_id, "pct": pct, "time": time})

## A shield of `amount` (buff `fx_id`) on `who`, for `time` sec.
func _hymn_ward(who: Variant, fx_id: String, amount: int, time: float) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0:
		return
	if HYMN_WARD_NAMES.has(fx_id):
		amount = int(round(float(amount) * (1.0 + player._talent("holy_sheltering_light") / 100.0)))   # Sheltering Light
	if is_same(who, player):
		_hymn_ward_on(player.status, player, fx_id, amount, time)
	elif (who as Node).is_in_group("friendly"):
		_hymn_ward_on((who as Node).get_node_or_null("Status"), player, fx_id, amount, time)
	elif player._net():
		player._net().support_ally(who, player, "hymn_ward", {"id": fx_id, "amount": amount, "time": time})
	if fx_id == SHELTER_FX:
		player._combat().float_text(who, "%s (%d)" % [HYMN_WARD_NAMES[fx_id], amount], HOLY_LIGHT, false)

func _hymn_ward_on(st: Node, from: Node, fx_id: String, amount: int, time: float) -> void:
	if st == null or amount <= 0:
		return
	# A new one never shrinks the shield already there: Vigil's adds to it, Shelter keeps the bigger.
	var left: int = st.absorb_left(fx_id) if st.has(fx_id) else 0
	amount = left + amount if fx_id == VIGIL_WARD_FX else maxi(left, amount)
	st.apply(make_hymn_ward_fx(fx_id, time), from)
	st.set_remaining(fx_id, time)
	st.set_absorb(fx_id, amount)

## Less damage taken from a healer's Hymns lands on me (`from`: whose).
func receive_hymn_dr(from: Node, fx_id: String, pct: float, time: float) -> void:
	if player.status == null or player.is_dead() or not HYMN_DR_NAMES.has(fx_id):
		return
	player.status.apply(make_hymn_dr_fx(fx_id, pct, time), from)
	player.status.set_remaining(fx_id, time)
	if fx_id == VIGIL_FX and from != null and is_instance_valid(from):
		_vigil_from[from.get_instance_id()] = {"from": from, "until": player.strings._str_now() + time}

## Watchful: a big hit on me while I stand in a healer's Vigil gives them a Vigil Verse.
func _vigil_taken(info: RefCounted) -> void:
	if _vigil_from.is_empty() or int(info.amount) <= 0 or info.avoided():
		return
	if float(info.amount) * 100.0 < float(player.max_health) * Balance.WATCHFUL_HIT_PCT:
		return
	for key in _vigil_from:
		var from: Variant = _vigil_from[key]["from"]
		if from == null or not is_instance_valid(from):
			continue
		if is_same(from, player):
			_talent_verse("holy_watchful", "vigil")
		elif player._net():
			player._net().support_ally(from, player, "vigil_hit", {})

# The buffs.

static func make_hymn_dr_fx(fx_id: String, pct: float, time: float) -> Resource:
	var color: Color = Abilities.HYMN_COLORS["vigil"] if fx_id != REST_FX else HOLY_LIGHT
	var nature := fx_id == ShepherdKit.FULL_BLOOM_FX or fx_id == ShepherdKit.CANOPY_FX
	if nature:
		color = ShepherdKit.BLOSSOM_COLOR
	var fx := StatusContainer.make_buff(fx_id, str(HYMN_DR_NAMES.get(fx_id, fx_id)), fx_id, 0.0, time, 1, color)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature" if nature else "Holy", "Defensive"])
	fx.damage_mod_pct = -absf(pct)
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(absf(pct))
	return fx

static func make_hymn_ward_fx(fx_id: String, time: float) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, str(HYMN_WARD_NAMES.get(fx_id, fx_id)), fx_id, 0.0, time, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy", "Defensive"])
	fx.description = "A shield of holy light absorbs damage."
	return fx

static func make_swell_fx() -> Resource:
	var fx := StatusContainer.make_buff(SWELL_FX, "Swell", SWELL_FX, 0.0, Balance.SWELL_TIME, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Everything that gives you Verses gives %d more." % Balance.SWELL_EXTRA
	return fx

static func make_overture_fx() -> Resource:
	var fx := StatusContainer.make_buff(OVERTURE_FX, "Overture", OVERTURE_FX, 0.0, Balance.OVERTURE_TIME, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Your next spell with a cast time is instant."
	return fx

## Rune of the Overture: is my next cast of `spell` instant?
func overture_ready(spell: String) -> bool:
	if player.status == null or not player.status.has(OVERTURE_FX):
		return false
	var r := Abilities.get_resource(spell)
	return r != null and int(r.cast_type) == 1 and float(r.cast_time) > 0.0

## The Verses shown on a button (Sing, Reprise, Last Verse).
func verses_text(id: String) -> String:
	if SING_IDS.has(id) or id == "reprise" or id == "lastverse":
		return str(verses.size())
	return ""


func tracker_values() -> Dictionary:
	return {"verses": {"value": verses.size(), "max": Balance.VERSE_MAX}}
