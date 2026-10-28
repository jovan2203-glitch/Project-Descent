extends CanvasLayer

# Details (autoload "Details"): a WoW "Details!"-style damage / healing meter
# for the whole party.
#
# Recording: every fight is a "segment". One starts when you enter combat (or
# the moment anyone in the party hits / heals something) and ends when combat
# ends (outside combat: after IDLE_END quiet seconds). Per segment it keeps,
# per PLAYER and per spell: total, hits, crits, lowest / highest hit and crit,
# overheal; and every buff YOU had: applications, longest duration, total
# uptime, highest stacks. The last MAX_SEGMENTS fights are kept.
#
# Party: every machine records its own player's hits / heals and sends them to
# the rest of the party (Net.send_meter, batched a few times a second), so
# everyone sees everyone's numbers and per-spell breakdowns. Solo it's just you.
#
# UI (only while a player is in the scene):
#   - Meter (top right, drag it by its title): one bar per player, DPS / HPS
#     buttons top right, fight picker. Toggle: K (rebindable "Details").
#   - Breakdown window (click a player's bar or "Breakdown"): Damage, Healing
#     and Buffs tabs with the full per-spell / per-buff numbers of the player
#     picked at the top.

const UI = preload("res://scripts/ui_kit.gd")
const Abilities = preload("res://scripts/abilities.gd")

const MAX_SEGMENTS := 12
## Outside combat, a segment ends after this many seconds without hits / heals.
const IDLE_END := 4.0
## A hit this soon after a fight ended (a last DoT tick) still counts for it.
const REOPEN_WINDOW := 2.0
const METER_BARS := 5          # party of up to 5
const METER_WIDTH := 290.0
## Own hits / heals are sent to the party this often (seconds).
const SEND_INTERVAL := 0.3

signal updated

var segments: Array = []        # oldest first
var current: Dictionary = {}    # the running segment ({} = none)
var mode := "damage"            # meter mode: "damage" (DPS) / "healing" (HPS)
var meter_enabled := true       # K toggles; remembered while the game runs
var _view: Dictionary = {}      # the segment being shown ({} = latest)
var _sel_member := -1           # breakdown: whose spells (-1 = you)

## The breakdown window's layer: above the HUD, with the in-game windows (game_ui.gd).
const WINDOW_LAYER := 20
var _win_layer: CanvasLayer

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus := get_node("/root/SignalBus")
	bus.damage_dealt.connect(_on_damage)
	bus.heal_done.connect(_on_heal)
	bus.combat_state_changed.connect(_on_combat_changed)
	_win_layer = CanvasLayer.new()
	_win_layer.layer = WINDOW_LAYER
	add_child(_win_layer)
	_build_meter()
	_build_window()
	UISkin.skin_window(_meter)
	UISkin.skin_window(_window)

# --- Players --------------------------------------------------------------------------

func _net() -> Node:
	return get_node_or_null("/root/Net")

## Your member id (0 when not in a party).
func my_key() -> int:
	var net := _net()
	return int(net.my_id()) if net and net.online else 0

func player_name(member: int) -> String:
	if member == my_key():
		var online := get_node_or_null("/root/Online")
		var n := str(online.get("my_name")) if online and online.get("my_name") != null else ""
		return n if n != "" and n != "<null>" else "You"
	var net := _net()
	return str(net.member_name(member)) if net else "?"

## A player's tables inside a segment (created on first use).
func _pdata(seg: Dictionary, member: int) -> Dictionary:
	var players: Dictionary = seg["players"]
	if not players.has(member):
		players[member] = {"member": member, "name": player_name(member), "damage": {}, "healing": {},
			"dmg_total": 0, "heal_total": 0, "overheal": 0}
	return players[member]

# --- Recording ------------------------------------------------------------------------

var _player_cache: Node = null

func _player() -> Node:
	if _player_cache == null or not is_instance_valid(_player_cache) or not _player_cache.is_inside_tree():
		_player_cache = get_tree().get_first_node_in_group("player")
	return _player_cache

func _new_segment() -> Dictionary:
	var t := _now()
	return {"start": t, "end": t, "last": t, "active": true, "number": _next_number(),
		"players": {}, "buffs": {}}

var _counter := 0

func _next_number() -> int:
	_counter += 1
	return _counter

## Begin recording (no-op while a fight is already running).
func _begin() -> void:
	if not current.is_empty():
		return
	# A stray hit right after a fight (last DoT tick) belongs to that fight.
	if not segments.is_empty():
		var last: Dictionary = segments.back()
		if _now() - float(last["end"]) <= REOPEN_WINDOW:
			last["active"] = true
			current = last
			_view = {}
			_open_active_buffs()
			_refresh_segment_pickers()
			return
	current = _new_segment()
	segments.append(current)
	while segments.size() > MAX_SEGMENTS:
		segments.pop_front()
	_view = {}   # follow the new fight
	_open_active_buffs()
	_refresh_segment_pickers()

func _end() -> void:
	if current.is_empty():
		return
	var t := _now()
	_close_all_buffs(t)
	current["end"] = t
	current["active"] = false
	current = {}
	_refresh_segment_pickers()
	updated.emit()

func _touch() -> void:
	_begin()
	current["last"] = _now()

func _on_combat_changed(in_combat: bool) -> void:
	if in_combat:
		_begin()
	else:
		_end()

## Clear every recorded fight (training room "Reset").
func reset() -> void:
	current = {}
	segments.clear()
	_view = {}
	_outbox.clear()
	_refresh_segment_pickers()
	_refresh()

func _on_damage(info: RefCounted) -> void:
	var p := _player()
	var src: Node = info.source
	if p == null or src == null or not is_instance_valid(src):
		return
	if src != p:
		_on_remote_tick(src, info)
		return
	var tgt: Node = info.target
	if info.amount <= 0 or tgt == null or not is_instance_valid(tgt) or tgt == p:
		return
	for row in split_hit(info):
		_record(my_key(), 0, str(row[0]), int(row[1]), bool(row[2]), 0)
		_outbox.append([0, str(row[0]), int(row[1]), bool(row[2]), 0])

# --- Added damage gets its own line -----------------------------------------------------
# Whatever ADDS damage to a hit (a talent, a buff, a rune, a debuff on the target:
# Heat, Shatterpoint, Bitter Cold, Smoldering Focus, Stormfire, Rime Shell...) is
# taken out of that hit's line and shown on a line of its own, named after what
# added it. The hit's own line keeps what it would have done without it. Hits
# that are extra hits to begin with (Afterglow, Slag Shatter, rune and item
# procs) already carry their own name.

## Suffix of the line of an ability the Rune of the Wild Page cast for free ("fireball@wild_page").
const ECHO_SUFFIX := "@wild_page"
const ECHO_NAME := "Wild Page"
## Prefix of a meter line that holds damage ADDED to other hits ("bonus:Heat").
const BONUS_PREFIX := "bonus:"
## Modifiers that are not something the player brought: they stay in the hit.
const BONUS_IGNORED := ["Shield", "Dungeon"]

## The meter rows of one hit: [[line id, amount, crit], ...]. The first row is
## the hit itself; each further row is what one modifier added to it.
static func split_hit(info: RefCounted) -> Array:
	var amount := int(info.amount)
	var id := str(info.ability_id)
	if bool(info.get("echo")):
		id += ECHO_SUFFIX   # a free cast of the Rune of the Wild Page: "<name> (Wild Page)"
	var parts: Variant = info.get("bonus_parts")
	return split_amount(id, amount, bool(info.crit), parts if parts is Array else [])

## split_hit as plain maths. `parts` = [[modifier name, percent], ...]: the
## percents were added together (a hit with +20% and +30% dealt 150%), so each
## modifier's share of the final amount is its percent / (100 + all bonuses).
static func split_amount(id: String, amount: int, crit: bool, parts: Array) -> Array:
	var added := {}   # modifier name -> percent
	var plus := 0.0
	for p in parts:
		if not (p is Array) or p.size() < 2 or float(p[1]) <= 0.0:
			continue
		var name := bonus_name(str(p[0]))
		if name == "" or BONUS_IGNORED.has(name):
			continue
		added[name] = float(added.get(name, 0.0)) + float(p[1])
		plus += float(p[1])
	if added.is_empty() or amount <= 0:
		return [[id, amount, crit]]
	var rows: Array = [[id, amount, crit]]
	var left := amount
	for name in added:
		var share := int(round(amount * float(added[name]) / (100.0 + plus)))
		share = clampi(share, 0, left)
		if share <= 0:
			continue
		left -= share
		rows.append([BONUS_PREFIX + str(name), share, crit])
	rows[0][1] = left
	return rows

static var _stack_suffix: RegEx

## "Stormfire x3" -> "Stormfire" (a modifier's label without its stack count).
static func bonus_name(label: String) -> String:
	if _stack_suffix == null:
		_stack_suffix = RegEx.create_from_string(" x\\d+$")
	return _stack_suffix.sub(label, "").strip_edges()

func _on_heal(source: Node, _target: Node, amount: int, effective: int, ability_id: String, crit: bool) -> void:
	var p := _player()
	if p == null or source == null or not is_instance_valid(source) or source != p or amount <= 0:
		return
	var over := maxi(amount - effective, 0)
	var id := ability_id if ability_id != "" else "heal_other"
	_record(my_key(), 1, id, amount, crit, over)
	_outbox.append([1, id, amount, crit, over])

## One hit (kind 0) or heal (kind 1) by `member` into the running fight.
## The whole run's totals per player (the menu's last-run summary): member ->
## {"name", "damage", "healing"}. Cleared when a run starts (GameManager).
var run_totals := {}

func reset_run() -> void:
	run_totals = {}

func _record(member: int, kind: int, id: String, amount: int, crit: bool, over: int) -> void:
	_touch()
	if not run_totals.has(member):
		run_totals[member] = {"name": player_name(member), "damage": 0, "healing": 0}
	run_totals[member]["damage" if kind == 0 else "healing"] += amount if kind == 0 else amount - over
	var pd := _pdata(current, member)
	if kind == 0:
		_add(pd["damage"], id, amount, crit, 0)
		pd["dmg_total"] = int(pd["dmg_total"]) + amount
	else:
		_add(pd["healing"], id, amount, crit, over)
		pd["heal_total"] = int(pd["heal_total"]) + (amount - over)
		pd["overheal"] = int(pd["overheal"]) + over

# --- Party sync -----------------------------------------------------------------------

var _outbox: Array = []   # own events not sent yet: [kind, id, amount, crit, overheal]
var _send_t := 0.0

func _flush_outbox(delta: float) -> void:
	_send_t -= delta
	if _send_t > 0.0 or _outbox.is_empty():
		return
	_send_t = SEND_INTERVAL
	var net := _net()
	if net and net.has_method("send_meter"):
		net.send_meter(_outbox)
	_outbox = []

## Net: hits / heals another party member made (see _outbox for the rows).
func add_remote(member: int, events: Array) -> void:
	if _player() == null or member == my_key():
		return
	for e in events:
		if e is Array and e.size() >= 5:
			_record(member, int(e[0]), str(e[1]), int(e[2]), bool(e[3]), int(e[4]))

## Host: DoT ticks / bursts of a party member's effects happen only here (the host
## runs every enemy's status effects), so their owner never sees them. Record them
## and forward them to the whole party (owner included).
func _on_remote_tick(src: Node, info: RefCounted) -> void:
	var net := _net()
	if net == null or not net.is_host() or not src.is_in_group("remote_player"):
		return
	var id := str(info.ability_id)
	if not (id.begins_with("dot_") or id.begins_with("burst_")):
		return   # direct hits are reported by their owner
	if int(info.amount) <= 0:
		return
	var member := int(src.get("member_id"))
	var sent: Array = []
	for part in split_hit(info):
		_record(member, 0, str(part[0]), int(part[1]), bool(part[2]), 0)
		sent.append([0, str(part[0]), int(part[1]), bool(part[2]), 0])
	if net.has_method("send_meter_for"):
		net.send_meter_for(member, sent)

## Net (from the host): hits of `member` that only the host saw (DoT ticks),
## recorded even when `member` is you.
func add_forwarded(member: int, events: Array) -> void:
	if _player() == null:
		return
	for e in events:
		if e is Array and e.size() >= 5:
			_record(member, int(e[0]), str(e[1]), int(e[2]), bool(e[3]), int(e[4]))

## One hit / heal of `amount` into a per-spell table.
func _add(table: Dictionary, id: String, amount: int, crit: bool, overheal: int) -> void:
	if not table.has(id):
		table[id] = {"id": id, "name": spell_name(id), "color": spell_color(id), "total": 0, "hits": 0,
			"crits": 0, "min": 0, "max": 0, "cmin": 0, "cmax": 0, "overheal": 0}
	var r: Dictionary = table[id]
	r["total"] = int(r["total"]) + amount - overheal   # healing counts what actually landed
	r["overheal"] = int(r["overheal"]) + overheal
	r["hits"] = int(r["hits"]) + 1
	if crit:
		r["crits"] = int(r["crits"]) + 1
		r["cmin"] = amount if int(r["cmin"]) == 0 else mini(int(r["cmin"]), amount)
		r["cmax"] = maxi(int(r["cmax"]), amount)
	else:
		r["min"] = amount if int(r["min"]) == 0 else mini(int(r["min"]), amount)
		r["max"] = maxi(int(r["max"]), amount)
	r["raw"] = int(r.get("raw", 0)) + amount   # for the average hit size

# --- Buff tracking (yours; polled every frame while a fight is running) ------------

func _player_buffs() -> Dictionary:
	var out := {}   # id -> {"res", "stacks"}
	var p := _player()
	var st: Node = p.get_node_or_null("Status") if p else null
	if st == null or not ("effects" in st):
		return out
	for k in st.effects:
		var e: Dictionary = st.effects[k]
		var res: Resource = e.get("res")
		if res == null or bool(res.is_debuff):
			continue
		var id := str(res.id)
		var stacks := int(e.get("stacks", 1))
		if not out.has(id) or stacks > int(out[id]["stacks"]):
			out[id] = {"res": res, "stacks": stacks}
	return out

func _open_active_buffs() -> void:
	_track_buffs(_now())

func _track_buffs(t: float) -> void:
	if current.is_empty():
		return
	var active := _player_buffs()
	var table: Dictionary = current["buffs"]
	for id in active:
		var res: Resource = active[id]["res"]
		if not table.has(id):
			table[id] = {"id": id, "name": str(res.display_name), "color": res.color, "apps": 0,
				"uptime": 0.0, "since": -1.0, "longest": 0.0, "max_stacks": 1}
		var b: Dictionary = table[id]
		b["max_stacks"] = maxi(int(b["max_stacks"]), int(active[id]["stacks"]))
		if float(b["since"]) < 0.0:
			b["since"] = t
			b["apps"] = int(b["apps"]) + 1
	for id in table:
		var b: Dictionary = table[id]
		if float(b["since"]) >= 0.0 and not active.has(id):
			_close_buff(b, t)

func _close_buff(b: Dictionary, t: float) -> void:
	var dur := maxf(t - float(b["since"]), 0.0)
	b["uptime"] = float(b["uptime"]) + dur
	b["longest"] = maxf(float(b["longest"]), dur)
	b["since"] = -1.0

func _close_all_buffs(t: float) -> void:
	for id in current.get("buffs", {}):
		var b: Dictionary = current["buffs"][id]
		if float(b["since"]) >= 0.0:
			_close_buff(b, t)

## Seconds of buff `b` so far (includes the running application).
func _buff_uptime(b: Dictionary, seg: Dictionary) -> float:
	var up := float(b["uptime"])
	if bool(seg["active"]) and float(b["since"]) >= 0.0:
		up += _now() - float(b["since"])
	return up

func _buff_longest(b: Dictionary, seg: Dictionary) -> float:
	var l := float(b["longest"])
	if bool(seg["active"]) and float(b["since"]) >= 0.0:
		l = maxf(l, _now() - float(b["since"]))
	return l

var _refresh_timer := 0.0

func _process(delta: float) -> void:
	_flush_outbox(delta)
	var p := _player()
	var has_player := p != null
	_meter.visible = has_player and meter_enabled
	_follow_dock()
	if not has_player:
		_window.visible = false
		if not current.is_empty():
			_end()   # left the dungeon / training room mid-fight
		return
	if not current.is_empty():
		_track_buffs(_now())
		var in_combat: bool = p.has_method("is_in_combat") and p.is_in_combat()
		if not in_combat and _now() - float(current["last"]) > IDLE_END:
			_end()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_refresh()

# --- Queries --------------------------------------------------------------------------

## Segment on screen: the one picked, else the running / latest fight.
func shown_segment() -> Dictionary:
	if not _view.is_empty() and segments.has(_view):
		return _view
	if not current.is_empty():
		return current
	return segments.back() if not segments.is_empty() else {}

func duration(seg: Dictionary) -> float:
	if seg.is_empty():
		return 0.0
	var stop: float = _now() if bool(seg["active"]) else float(seg["end"])
	return maxf(stop - float(seg["start"]), 1.0)

## A player's total damage / healing in a segment.
func player_total(pd: Dictionary, kind: String) -> int:
	return int(pd["dmg_total"]) if kind == "damage" else int(pd["heal_total"])

## Players of a segment, biggest damage / healing first (only those with any).
func player_rows(seg: Dictionary, kind: String) -> Array:
	if seg.is_empty():
		return []
	var out: Array = []
	for pd in (seg["players"] as Dictionary).values():
		if player_total(pd, kind) > 0:
			out.append(pd)
	out.sort_custom(func(a, b): return player_total(a, kind) > player_total(b, kind))
	return out

## Whole party's total.
func total(seg: Dictionary, kind: String) -> int:
	var t := 0
	if not seg.is_empty():
		for pd in (seg["players"] as Dictionary).values():
			t += player_total(pd, kind)
	return t

## Per-spell rows of one player (biggest first).
func rows(seg: Dictionary, kind: String, member: int) -> Array:
	if seg.is_empty() or not (seg["players"] as Dictionary).has(member):
		return []
	var out: Array = (seg["players"][member][kind] as Dictionary).values()
	out.sort_custom(func(a, b): return int(a["total"]) > int(b["total"]))
	return out

## Bar colour of a player: the colour of their biggest spell (their element).
func player_color(pd: Dictionary, kind: String) -> Color:
	var best: Dictionary = {}
	for r in (pd[kind] as Dictionary).values():
		if best.is_empty() or int(r["total"]) > int(best["total"]):
			best = r
	return best["color"] if not best.is_empty() else Color(0.6, 0.6, 0.65)

## Hits from talents / runes that aren't abilities: their exact in-game names.
## Every hit is named after the thing that caused it - never after a different
## spell (a Frozen enemy shattering is "Frozen Shatter", not "Rime Shell").
const HIT_NAMES := {
	"frozen_shatter": "Frozen Shatter",
	"hoar_blade": "Hoar Blade",   # (Frost DPS: the Rune of the Hoar Blade)
	"splittingarrow": "Splitting Arrow",   # (Frost archer talent: an arrow into a Frozen enemy splinters)
	"coldretort": "Cold Retort",   # (Frost tank talent: a Layer breaking hits the attacker)
	"hoarcoat": "Hoar Coat",   # (Frost tank talent: Layers gained heal you)
	"rimetips": "Rime Tips",
	"red_edge": "Red Edge",   # (Fire DPS: its extra Fire damage on auto-attacks)
	"pitch_ignite": "Ignite",   # (Fire archer: Pitch bursting)
	"hot_shafts": "Hot Shafts",   # (Fire archer talent: Fire damage on auto-shots)
	"overheat": "Overheat",   # (Fire melee talent: a White-band Spark burning the enemies around)
	"afterglow": "Afterglow",
	"slag_shatter": "Slag Shatter",
	"dot_smoldering_debris": "Smoldering Debris",
	"dot_blowback": "Blowback",
	"slag_mending": "Slag Mending",
	"splintering": "Splintering",
	"permafrost": "Permafrost",
	"deepfreeze": "Deep Freeze",
	"icefloe": "Ice Floe",
	"lifesteal": "Lifesteal",
	"overload": "Overload",
	"earth_return": "Earth Return",
	"parting_spark": "Parting Spark",
	"sparkingswings": "Sparking Swings",   # (Lightning melee talent: a zap on an auto-attack)
	"sparkguard": "Spark Guard",   # (Lightning tank talent: a parry zaps the attacker)
	"draw_down": "Draw Down",   # (Lightning tank talent: Energy spent heals you)
	"lightning_rod": "Grounded Arrow",
	"afterimage": "Afterimage",
	"chain_reaction": "Chain Reaction",
	"reflection_shatter": "Reflection Shatter",
	"head_count": "Head Count",
	"silvered": "Silvered",
	"echo": "Echo",
	"spillover": "Spillover",
	"mirror_finish": "Mirror Finish",
	"full_house": "Full House",
	"hound_bite": "Hound Bite",
	"hound_lunge": "Hound Lunge",
	"hound_drag": "Drag Down",
	"stand_over": "Stand Over",
	"string_share": "Shared along the Strings",
	"crossed_strings": "Crossed Strings",
	"fair_trade": "Fair Trade",
	"first_stitch": "First Stitch",
	"long_drop": "Long Drop",
	"benediction": "Benediction",
	"chorale": "Chorale",
	"chorus_splash": "Chorus",
	"antiphon_self": "Antiphon",
	"resounding": "Resounding",
	"incense_aura": "Incense",
	"light_mote": "Light Mote",
	"bright_burst": "Bright Burst",
	"prism_shatter": "Prism Shatter",
	"refraction": "Refraction",
	"thornburst": "Thornburst",
	"owlstrike": "Owl's Strike",
	"rimeshards": "Rime Shards",
	"runoff": "Runoff",
	"splinterheal": "Splinterheal",
	"evergreen": "Evergreen",
	"food_chain": "Food Chain",
	"turned_aside": "Turned Aside",
	"catchyourbreath": "Catch Your Breath",
	"getup": "Get Up",
	"secondarrow": "Second Arrow",
	"stomproots": "Stomp Roots",
	"giantsslam": "Giant's Slam",
	"sap": "Sap",
	"axecleave": "Axe Cleave",
	"secondhit": "Second Hit",
	"reversal": "Reversal",
	"rippedout": "Ripped Out",   # (Martial DPS: daggers ripped out)
	"oiljar": "Oil Jar",   # (Martial DPS: Snatch)
	"venomburst_splash": "Venom Burst",
	"volley_arrow": "Spectrum Volley",
	"auto_melee": "Auto Attack",
	"auto_ranged": "Auto Shot",
}

## Display name for a combat log id ("fireball" -> "Firebolt", "dot_burning" -> "Burning (Periodic)").
## Also used by the Logs tab (GameLog), so both always agree.
static func spell_name(id: String) -> String:
	if id.ends_with(ECHO_SUFFIX):
		return "%s (%s)" % [spell_name(id.trim_suffix(ECHO_SUFFIX)), ECHO_NAME]
	var name := line_name(id)
	var from := source_of(id, name)
	return name if from == "" else "%s (%s)" % [name, from]

## A line's own name, without where it came from.
static func line_name(id: String) -> String:
	if id == "heal_other":
		return "Healing"
	if HIT_NAMES.has(id):
		return HIT_NAMES[id]
	if id.begins_with(BONUS_PREFIX):
		return id.substr(BONUS_PREFIX.length())   # damage a talent / buff / rune added to other hits
	if id.begins_with("rune_"):
		return load("res://scripts/runes.gd").rune_name(id.trim_prefix("rune_"))
	if id.begins_with("item_"):
		return item_effect_name(id.trim_prefix("item_"))
	var n := Abilities.ability_name(id)
	if n != "":
		return n
	for prefix in ["dot_", "burst_"]:
		if id.begins_with(prefix):
			var eid := id.substr(prefix.length())
			var path := "res://data/effects/%s.tres" % eid
			var ename := eid.capitalize()
			if ResourceLoader.exists(path):
				var r: Resource = load(path)
				if r and r.get("display_name"):
					ename = str(r.display_name)
			else:
				var an := Abilities.ability_name(eid)
				if an != "":
					ename = an
			return ename + (" (Periodic)" if prefix == "dot_" else " (Burst)")
	return id.capitalize() if id != "" else "Other"

## Name of an item's Equip: / Use: effect by its id ("frost_shard" -> "Shattering Cold").
static func item_effect_name(effect_id: String) -> String:
	var Items = load("res://scripts/items.gd")
	for item in Items.ALL:
		for eff in [Items.equip_effect_of(item), Items.use_effect_of(item)]:
			if eff != null and str(eff.id) == effect_id:
				return str(eff.display_name)
	return effect_id.capitalize()

# --- Where added damage came from: in brackets after its line's name ---------------------
# A line of damage a talent, rune, item or trinket brought shows its source:
# "Splitting Arrow (Talent)" when the talent has the line's name, "Hoar Blade (Rune
# of the Hoar Blade)", "Storm Charm (Brass Storm Charm)". A spec's own mechanics
# (Frozen Shatter, Heat, the Hounds...) and abilities have none.

## Bonus lines named after a buff that isn't called what its talent / rune is.
const BONUS_SOURCES := {"Dusk": "rune:dusk_till_dawn", "Dawn": "rune:dusk_till_dawn", "Static": "rune:overload"}

static var _talent_names := {}   # talent name -> true (built once)
static var _rune_names := {}     # "Hoar Blade" / "Rune of the Hoar Blade" -> rune id

## What brought line `id` (named `name`) in, for its brackets ("" = nothing to say).
static func source_of(id: String, name: String) -> String:
	if id.begins_with("rune_"):
		return ""   # (already named "Rune of ...")
	if id.begins_with("item_"):
		var item := item_of_effect(id.trim_prefix("item_"))
		var item_name := str(load("res://scripts/items.gd").item_name(item)) if item != "" else ""
		if item_name != "" and item_name != name:
			return item_name
		return "Trinket" if item != "" and str(load("res://scripts/items.gd").get_item(item).get("slot", "")).begins_with("Trinket") else "Item"
	var base := id.trim_prefix(BONUS_PREFIX)
	for prefix in ["dot_", "burst_"]:
		base = base.trim_prefix(prefix)
	if Abilities.CATEGORY_OF.has(base) or id in ["auto_melee", "auto_ranged", "heal_other"]:
		return ""   # an ability's own damage
	var label := name.trim_suffix(" (Periodic)").trim_suffix(" (Burst)")
	if id.begins_with(BONUS_PREFIX) and BONUS_SOURCES.has(label):
		return _rune_or_talent(str(BONUS_SOURCES[label]), label)
	_build_source_names()
	if _talent_names.has(label):
		return "Talent"
	if _rune_names.has(label):
		var full: String = load("res://scripts/runes.gd").rune_name(str(_rune_names[label]))
		return "Rune" if full == label else full
	if id == "lifesteal":
		return "Item"   # (a stat that comes on gear)
	return ""

static func _rune_or_talent(src: String, label: String) -> String:
	if src.begins_with("rune:"):
		var full: String = load("res://scripts/runes.gd").rune_name(src.trim_prefix("rune:"))
		return "Rune" if full == label else full
	return "Talent"

static func _build_source_names() -> void:
	if not _talent_names.is_empty():
		return
	var Talents = load("res://scripts/talents.gd")
	for tid in Talents.db():
		var t: Dictionary = Talents.get_talent(tid)
		if not bool(t.get("placeholder", false)):
			_talent_names[str(t.get("name", ""))] = true
	var Runes = load("res://scripts/runes.gd")
	for rid in Runes.ALL:
		_rune_names[Runes.rune_name(rid)] = rid
		_rune_names[Runes.short_name(rid).trim_prefix("the ")] = rid

## The item whose equip or use effect is `effect_id` ("" if none).
static func item_of_effect(effect_id: String) -> String:
	var Items = load("res://scripts/items.gd")
	for item in Items.ALL:
		for eff in [Items.equip_effect_of(item), Items.use_effect_of(item)]:
			if eff != null and str(eff.id) == effect_id:
				return str(item)
	return ""

static func spell_color(id: String) -> Color:
	var base := id.trim_suffix(ECHO_SUFFIX)
	for prefix in ["dot_", "burst_"]:
		if base.begins_with(prefix):
			base = base.substr(prefix.length())
	if Abilities.CATEGORY_OF.has(base):
		return Abilities.color_of(base)
	match base:
		"auto_melee", "auto_ranged":
			return Color(0.75, 0.72, 0.66)
		"burning", "afterglow", "slag_mending", "slag_shatter", "smoldering_debris", "blowback", "red_edge", "pitch_ignite", "hot_shafts", "overheat":
			return Abilities.color_of("fireball")
		"chilled", "frozen", "frozen_shatter", "splintering", "permafrost", "deepfreeze", "icefloe", "rimeshards", "runoff", "splinterheal", "hoar_blade", "splittingarrow", "coldretort", "hoarcoat", "rimetips":
			return Abilities.color_of("frostbolt")
		"overload", "earth_return", "parting_spark", "lightning_rod", "spillover", "sparkingswings", "sparkguard", "draw_down":
			return Abilities.color_of("lightningbolt")
		"afterimage", "chain_reaction", "reflection_shatter", "head_count", "silvered", "echo", "mirror_finish", "full_house":
			return Abilities.color_of("blink")
		"thornburst":
			return Abilities.color_of("thornshot")   # (Nature caster)
		"owlstrike", "evergreen", "food_chain":
			return Abilities.color_of("owl")   # (Nature healer)
		"venomburst_splash":
			return Abilities.color_of("venomburst")   # (Nature archer)
		"stomproots", "giantsslam", "sap":
			return Abilities.color_of("stomp")   # (Nature tank)
		"axecleave":
			return Abilities.WheelIcons.AXE   # (Martial warrior: the Greataxe's rider)
		"secondhit":
			return Abilities.WheelIcons.HALBERD   # (the Halberd's rider)
		"reversal":
			return Abilities.BrawlerIcons.KICK   # (Martial tank: Throw on a boss)
		"rippedout":
			return Abilities.RogueIcons.STEEL   # (Martial DPS: daggers ripped out)
		"oiljar":
			return Color(1.0, 0.5, 0.15)   # (Martial DPS: Snatch)
		"getup":
			return Abilities.BrawlerIcons.ELBOW   # (Martial tank: Get Up)
		"secondarrow":
			return Color(0.85, 0.8, 0.65)   # (Martial archer: Second Arrow)
		"catchyourbreath":
			return Color(0.55, 1.0, 0.6)   # (Martial, open talent)
		"poisoned":
			return Color(0.45, 0.85, 0.3)
		"lifesteal":
			return Color(0.85, 0.25, 0.35)   # (blood red, a little pink)
		"corrupted", "decay":
			return Abilities.color_of("corruption")
		"hound_bite", "hound_lunge", "hound_drag", "stand_over":
			return Color(0.8, 0.16, 0.3)   # the Hounds' red (Shadow melee)
		"benediction", "chorale", "chorus_splash", "resounding", "antiphon_self", "incense_aura", "light_mote", "bright_burst", "prism_shatter", "refraction", "volley_arrow", "turned_aside":
			return Color(1.0, 0.88, 0.45)  # holy light (Holy healer: the Hymns)
		"string_share", "crossed_strings", "first_stitch", "long_drop", "fair_trade":
			return Color(0.93, 0.86, 1.0)  # the Strings' pale thread (Shadow healer)
	return Color(0.7, 0.7, 0.75)

static func fmt(v: float) -> String:
	var i := int(round(v))
	if absi(i) >= 1000000:
		return "%.2fM" % (i / 1000000.0)
	if absi(i) >= 10000:
		return "%.1fk" % (i / 1000.0)
	return _commas(i)

static func _commas(i: int) -> String:
	var s := str(absi(i))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if i < 0 else "") + s + out

static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [floori(s / 60.0), s % 60]

func _segment_label(seg: Dictionary) -> String:
	if bool(seg["active"]):
		return "Current fight (%s)" % fmt_time(duration(seg))
	return "Fight %d  -  %s" % [int(seg["number"]), fmt_time(duration(seg))]

# --- Input ----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _player() == null:
		return
	if InputMap.has_action("open_details") and event.is_action_pressed("open_details"):
		get_viewport().set_input_as_handled()
		meter_enabled = not meter_enabled
		if not meter_enabled:
			_window.visible = false
	elif event.keycode == KEY_ESCAPE and _window.visible:
		get_viewport().set_input_as_handled()
		_window.visible = false

## Bottom-left bar button.
func toggle_meter() -> void:
	meter_enabled = not meter_enabled
	if not meter_enabled:
		_window.visible = false

## Open the breakdown window (optionally on a tab, for a party member).
func open_breakdown(tab: String = "", member: int = -1) -> void:
	_sel_member = member
	_window.visible = true
	_window.move_to_front()
	match tab:
		"damage": _tabs.current_tab = 0
		"healing": _tabs.current_tab = 1
		"buffs": _tabs.current_tab = 2
	_refresh_player_picker()
	_refresh()

# --- Meter ----------------------------------------------------------------------------

var _meter: PanelContainer
var _meter_title: Label
var _dps_btn: Button
var _hps_btn: Button
var _meter_pick: OptionButton
var _meter_summary: Label
var _bar_rows: Array[Control] = []

func _set_mode(m: String) -> void:
	mode = m
	_dps_btn.set_pressed_no_signal(mode == "damage")
	_hps_btn.set_pressed_no_signal(mode == "healing")
	_refresh()

func _small_toggle(text: String, tip: String) -> Button:
	var b := UI.button(text, 11, Vector2(38, 22))
	b.toggle_mode = true
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b

func _build_meter() -> void:
	_meter = PanelContainer.new()
	_meter.custom_minimum_size = Vector2(METER_WIDTH, 0)
	_meter.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.035, 0.05, 0.82), UI.BORDER, 1, 6))
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.offset_left = -METER_WIDTH - 16.0
	_meter.offset_right = -16.0
	_meter.offset_top = 226.0   # under the minimap
	add_child(_meter)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_meter.add_child(v)

	# Title (drag handle) on the left, small mode / breakdown / close buttons on the right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_MOVE
	head.tooltip_text = "Drag to move"
	_drag_by(head, _meter)
	v.add_child(head)
	_meter_title = UI.label("Damage Done", 14, UI.ACCENT)
	_meter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_meter_title)
	_dps_btn = _small_toggle("DPS", "Damage done (damage per second)")
	_dps_btn.pressed.connect(_set_mode.bind("damage"))
	head.add_child(_dps_btn)
	_hps_btn = _small_toggle("HPS", "Healing done (healing per second)")
	_hps_btn.pressed.connect(_set_mode.bind("healing"))
	head.add_child(_hps_btn)
	var more := UI.button("Info", 11, Vector2(36, 22))
	more.tooltip_text = "Breakdown: per-spell numbers and buff uptime"
	more.focus_mode = Control.FOCUS_NONE
	more.pressed.connect(func(): open_breakdown(mode))
	head.add_child(more)
	var close := UI.button("X", 11, Vector2(22, 22))
	close.tooltip_text = "Hide (K)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle_meter)
	head.add_child(close)
	_dps_btn.set_pressed_no_signal(mode == "damage")
	_hps_btn.set_pressed_no_signal(mode == "healing")

	_meter_pick = _segment_picker()
	_meter_pick.add_theme_font_size_override("font_size", 12)
	_meter_pick.custom_minimum_size = Vector2(0, 24)
	v.add_child(_meter_pick)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	v.add_child(bars)
	for i in METER_BARS:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 22)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.draw.connect(_draw_bar.bind(row))
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and row.has_meta("row"):
				open_breakdown(mode, int(row.get_meta("row")["member"])))
		bars.add_child(row)
		_bar_rows.append(row)

	_meter_summary = UI.label("", 12, UI.TEXT_DIM)
	v.add_child(_meter_summary)
	get_node("/root/Settings").register_hud(_meter)

## The in-game UI's meter panel holds the meter (scripts/ui/hud/meter_panel.gd):
## the meter stays mine (it outlives every scene) but covers `holder` exactly,
## flat, and can't be dragged. undock() lets it float again.
var _dock: Control

func dock_into(holder: Control) -> void:
	if _dock == holder:
		return
	_dock = holder
	_meter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_meter.add_theme_stylebox_override("panel", UISkin.backdrop(-1.0, 4))
	_meter.set_meta("docked", true)
	_follow_dock()

func undock() -> void:
	if _dock == null:
		return
	_dock = null
	_meter.set_meta("docked", false)
	_meter.add_theme_stylebox_override("panel", UISkin.backdrop(0.82, 6))
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.offset_left = -METER_WIDTH - 16.0
	_meter.offset_right = -16.0
	_meter.offset_top = 226.0
	_meter.offset_bottom = 226.0
	_meter.custom_minimum_size = Vector2(METER_WIDTH, 0)
	_meter.modulate.a = get_node("/root/Settings").hud_alpha_of(_meter)

## Docked: on the panel's spot, its size, its opacity.
func _follow_dock() -> void:
	if _dock == null:
		return
	if not is_instance_valid(_dock) or not _dock.is_inside_tree():
		undock()   # (the scene with the panel is gone)
		return
	var r := _dock.get_global_rect()
	if _meter.global_position != r.position:
		_meter.global_position = r.position
	var want := Vector2(r.size.x, maxf(r.size.y, _meter.get_combined_minimum_size().y))
	if _meter.size != want:
		_meter.custom_minimum_size = Vector2(r.size.x, 0)
		_meter.size = want
	var a := _dock.modulate.a * (_dock.get_parent() as CanvasItem).modulate.a if _dock.get_parent() is CanvasItem else _dock.modulate.a
	_meter.modulate.a = a
	_meter.visible = _meter.visible and _dock.is_visible_in_tree()

## The meter's smallest height (a docking panel is never shorter).
func meter_min_height() -> float:
	return _meter.get_combined_minimum_size().y

func _draw_bar(row: Control) -> void:
	if not row.has_meta("row"):
		return
	var frac := float(row.get_meta("frac", 0.0))
	var s := row.size
	var col: Color = row.get_meta("color", Color(0.6, 0.6, 0.65))
	row.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.04), true)
	row.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x * clampf(frac, 0.0, 1.0), s.y)), Color(col.darkened(0.3), 0.9), true)
	var f := ThemeDB.fallback_font
	var fs := 13
	var y := s.y / 2.0 + fs * 0.35
	var left := str(row.get_meta("left", ""))
	var right := str(row.get_meta("right", ""))
	var rw := f.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var name_w := s.x - rw - 16.0
	row.draw_string_outline(f, Vector2(5, y), left, HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, 3, Color(0, 0, 0, 0.9))
	row.draw_string(f, Vector2(5, y), left, HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, Color.WHITE)
	row.draw_string_outline(f, Vector2(s.x - rw - 5, y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
	row.draw_string(f, Vector2(s.x - rw - 5, y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.95, 0.95))

func _refresh_meter() -> void:
	var seg := shown_segment()
	_meter_title.text = "Damage Done" if mode == "damage" else "Healing Done"
	var dur := duration(seg)
	var tot := total(seg, mode)
	var per := "DPS" if mode == "damage" else "HPS"
	var ps := player_rows(seg, mode)
	if seg.is_empty():
		_meter_summary.text = "No fights yet - hit something to start."
	elif ps.is_empty():
		_meter_summary.text = "No %s yet this fight." % ("damage" if mode == "damage" else "healing")
	else:
		_meter_summary.text = "Party %s %s  •  %s  •  %s" % [per, fmt(tot / dur), fmt(tot), fmt_time(dur)]
	var top := float(player_total(ps[0], mode)) if not ps.is_empty() else 1.0
	for i in _bar_rows.size():
		var row := _bar_rows[i]
		if i < ps.size():
			var pd: Dictionary = ps[i]
			var amount := float(player_total(pd, mode))
			var nm := player_name(int(pd["member"]))
			row.visible = true
			row.set_meta("row", pd)
			row.set_meta("frac", amount / maxf(top, 1.0))
			row.set_meta("color", player_color(pd, mode))
			row.set_meta("left", "%d. %s" % [i + 1, nm])
			row.set_meta("right", "%s (%s, %.1f%%)" % [fmt(amount), fmt(amount / dur),
				100.0 * amount / maxf(float(tot), 1.0)])
			row.tooltip_text = "%s: %s %s, %s per second\nClick for the per-spell breakdown" % [
				nm, fmt(amount), "damage" if mode == "damage" else "healing", fmt(amount / dur)]
		else:
			row.visible = false
			row.remove_meta("row")
		row.queue_redraw()
	# Docked, the panel sets its size: shrinking it here would make it jump
	# for a frame every refresh (_follow_dock puts it back the next one).
	if _dock == null:
		_meter.reset_size()

# --- Segment pickers (meter + window) --------------------------------------------------

var _pickers: Array[OptionButton] = []

func _segment_picker() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.item_selected.connect(func(i: int):
		var seg_i := o.get_item_id(i)
		if seg_i < 0 or seg_i >= segments.size():
			_view = {}
		else:
			_view = segments[seg_i]
			if _view == current:
				_view = {}   # "current" keeps following new fights
		_refresh_segment_pickers()
		_refresh_player_picker()
		_refresh())
	_pickers.append(o)
	return o

func _refresh_segment_pickers() -> void:
	var shown := shown_segment()
	for o in _pickers:
		o.clear()
		if segments.is_empty():
			o.add_item("No fights yet", -1)
			o.select(0)
			continue
		var sel := 0
		var idx := 0
		for i in range(segments.size() - 1, -1, -1):   # newest first
			o.add_item(_segment_label(segments[i]), i)
			if segments[i] == shown:
				sel = idx
			idx += 1
		o.select(sel)

func _update_picker_labels() -> void:
	# Keep the running fight's timer ticking in the dropdowns.
	for o in _pickers:
		for i in o.item_count:
			var seg_i := o.get_item_id(i)
			if seg_i >= 0 and seg_i < segments.size() and bool(segments[seg_i]["active"]):
				o.set_item_text(i, _segment_label(segments[seg_i]))

# --- Breakdown window -------------------------------------------------------------------

var _window: PanelContainer
var _tabs: TabContainer
var _win_summary: Label
var _player_pick: OptionButton
var _grids := {}   # "damage" / "healing" / "buffs" -> GridContainer

const SPELL_COLS := ["Spell", "Amount", "%", "Per sec", "Hits", "Average", "Lowest", "Highest",
	"Crit %", "Lowest crit", "Highest crit"]
const HEAL_EXTRA_COLS := ["Overheal"]
const BUFF_COLS := ["Buff", "Applied", "Avg duration", "Longest", "Uptime", "Uptime %", "Max stacks"]

## Whose numbers the breakdown shows.
func _shown_member() -> int:
	return my_key() if _sel_member < 0 else _sel_member

func _build_window() -> void:
	_window = PanelContainer.new()
	_window.visible = false
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	_window.add_theme_stylebox_override("panel", sb)
	_window.custom_minimum_size = Vector2(900, 440)
	_window.position = Vector2(120, 90)
	_win_layer.add_child(_window)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_window.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_drag_by(head, _window)
	v.add_child(head)
	var t := UI.label("Details - Breakdown", 18, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_player_pick = OptionButton.new()
	_player_pick.focus_mode = Control.FOCUS_NONE
	_player_pick.custom_minimum_size = Vector2(170, 28)
	_player_pick.tooltip_text = "Whose spells to show"
	_player_pick.item_selected.connect(func(i: int):
		var m := _player_pick.get_item_id(i)
		_sel_member = -1 if m == my_key() else m
		_refresh())
	head.add_child(_player_pick)
	var pick := _segment_picker()
	pick.custom_minimum_size = Vector2(230, 28)
	head.add_child(pick)
	var close := UI.button("X", 14, Vector2(28, 28))
	close.pressed.connect(func(): _window.visible = false)
	head.add_child(close)

	_win_summary = UI.label("", 14, Color(0.9, 0.9, 0.93))
	v.add_child(_win_summary)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.custom_minimum_size = Vector2(0, 340)
	_tabs.tab_changed.connect(func(_i): _refresh())
	v.add_child(_tabs)
	for tab in [["Damage", "damage", SPELL_COLS], ["Healing", "healing", SPELL_COLS + HEAL_EXTRA_COLS],
			["Buffs", "buffs", BUFF_COLS]]:
		var scroll := ScrollContainer.new()
		scroll.name = tab[0]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_tabs.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = (tab[2] as Array).size()
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 3)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		_grids[tab[1]] = grid
		grid.set_meta("cols", tab[2])
	var note := UI.label("Lowest / Highest are normal hits; crits have their own columns. Healing counts health actually restored (overheal shown separately). Buffs are tracked for your own character only.", 11, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(860, 0)
	v.add_child(note)
	get_node("/root/Settings").register_hud(_window)
	_refresh_segment_pickers()
	_refresh_player_picker()

## Player dropdown: you + everyone who did something in the fight shown.
func _refresh_player_picker() -> void:
	if _player_pick == null:
		return
	var seg := shown_segment()
	var ids: Array = [my_key()]
	if not seg.is_empty():
		for m in (seg["players"] as Dictionary).keys():
			if not ids.has(int(m)):
				ids.append(int(m))
	var want := _shown_member()
	_player_pick.clear()
	var sel := 0
	for i in ids.size():
		var m := int(ids[i])
		_player_pick.add_item(player_name(m) + (" (you)" if m == my_key() and player_name(m) != "You" else ""), m)
		if m == want:
			sel = i
	_player_pick.select(sel)

func _refresh_window() -> void:
	var seg := shown_segment()
	var dur := duration(seg)
	var member := _shown_member()
	var pd: Dictionary = seg["players"].get(member, {}) if not seg.is_empty() else {}
	var n_players := (seg["players"] as Dictionary).size() if not seg.is_empty() else 0
	if not seg.is_empty() and not (seg["players"] as Dictionary).has(my_key()):
		n_players += 1
	if _player_pick.item_count != maxi(n_players, 1) or _player_pick.get_selected_id() != member:
		_refresh_player_picker()
	if seg.is_empty():
		_win_summary.text = "No fights recorded yet."
	else:
		var dmg := float(pd.get("dmg_total", 0))
		var heal := float(pd.get("heal_total", 0))
		_win_summary.text = "%s   •   %s   •   Damage %s  (%s DPS)   •   Healing %s  (%s HPS, %s overheal)" % [
			_segment_label(seg), player_name(member), fmt(dmg), fmt(dmg / dur),
			fmt(heal), fmt(heal / dur), fmt(float(pd.get("overheal", 0)))]
	match _tabs.current_tab:
		0: _fill_spells(_grids["damage"], seg, "damage", dur, member)
		1: _fill_spells(_grids["healing"], seg, "healing", dur, member)
		2: _fill_buffs(_grids["buffs"], seg, dur)

func _cell(grid: GridContainer, text: String, col: Color = Color(0.9, 0.9, 0.92), size: int = 13) -> Label:
	var l := UI.label(text, size, col)
	grid.add_child(l)
	return l

func _header(grid: GridContainer) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for h in grid.get_meta("cols"):
		_cell(grid, str(h), UISkin.accent(), 13)

func _fill_spells(grid: GridContainer, seg: Dictionary, kind: String, dur: float, member: int) -> void:
	_header(grid)
	var rs := rows(seg, kind, member)
	var pd: Dictionary = seg["players"].get(member, {}) if not seg.is_empty() else {}
	var tot := maxf(float(player_total(pd, kind)) if not pd.is_empty() else 0.0, 1.0)
	if rs.is_empty():
		_cell(grid, "Nothing yet" if kind == "damage" else "No healing yet", UI.TEXT_DIM)
		for i in grid.columns - 1:
			_cell(grid, "")
		return
	for r in rs:
		var hits := int(r["hits"])
		var crits := int(r["crits"])
		var raw := float(r.get("raw", r["total"]))
		var name_l := _cell(grid, str(r["name"]), (r["color"] as Color).lightened(0.35))
		name_l.custom_minimum_size = Vector2(150, 0)
		_cell(grid, fmt(float(r["total"])))
		_cell(grid, "%.1f%%" % (100.0 * float(r["total"]) / tot))
		_cell(grid, fmt(float(r["total"]) / dur))
		_cell(grid, str(hits))
		_cell(grid, _commas(int(round(raw / maxf(hits, 1)))))
		_cell(grid, _commas(int(r["min"])) if hits - crits > 0 else "—")
		_cell(grid, _commas(int(r["max"])) if hits - crits > 0 else "—")
		_cell(grid, "%.1f%%" % (100.0 * crits / maxf(hits, 1)), Color(1.0, 0.85, 0.35) if crits > 0 else Color(0.9, 0.9, 0.92))
		_cell(grid, _commas(int(r["cmin"])) if crits > 0 else "—")
		_cell(grid, _commas(int(r["cmax"])) if crits > 0 else "—")
		if kind == "healing":
			var over := int(r["overheal"])
			_cell(grid, "%s (%d%%)" % [fmt(over), int(round(100.0 * over / maxf(raw, 1.0)))] if over > 0 else "0")

func _fill_buffs(grid: GridContainer, seg: Dictionary, dur: float) -> void:
	_header(grid)
	if _shown_member() != my_key():
		_cell(grid, "Buff uptime is only tracked for your own character", UI.TEXT_DIM)
		for i in grid.columns - 1:
			_cell(grid, "")
		return
	if seg.is_empty() or (seg["buffs"] as Dictionary).is_empty():
		_cell(grid, "No buffs during this fight", UI.TEXT_DIM)
		for i in grid.columns - 1:
			_cell(grid, "")
		return
	var list: Array = (seg["buffs"] as Dictionary).values()
	list.sort_custom(func(a, b): return _buff_uptime(a, seg) > _buff_uptime(b, seg))
	for b in list:
		var up := _buff_uptime(b, seg)
		var apps := maxi(int(b["apps"]), 1)
		var name_l := _cell(grid, str(b["name"]), (b["color"] as Color).lightened(0.3))
		name_l.custom_minimum_size = Vector2(150, 0)
		_cell(grid, str(int(b["apps"])))
		_cell(grid, "%.1f s" % (up / apps))
		_cell(grid, "%.1f s" % _buff_longest(b, seg))
		_cell(grid, "%.1f s" % up)
		var pct := 100.0 * up / maxf(dur, 0.001)
		_cell(grid, "%.1f%%" % minf(pct, 100.0), Color(0.55, 1.0, 0.55) if pct >= 80.0 else Color(0.9, 0.9, 0.92))
		_cell(grid, str(int(b["max_stacks"])))

func _refresh() -> void:
	if _meter == null or _meter_summary == null or _window == null:
		return   # still being built
	_update_picker_labels()
	if _meter.visible:
		_refresh_meter()
	if _window.visible:
		_refresh_window()

# --- Helpers ----------------------------------------------------------------------------

## Drag `panel` around by `handle` (kept on screen).
func _drag_by(handle: Control, panel: Control) -> void:
	handle.gui_input.connect(func(ev: InputEvent):
		if panel.get_meta("docked", false):
			return   # (docked in the meter panel: Move UI moves it)
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			panel.set_meta("dragging", ev.pressed)
			if ev.pressed:
				panel.move_to_front()
				# Switch from anchored to free positioning on the first drag.
				var p := panel.global_position
				panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
				panel.global_position = p
		elif ev is InputEventMouseMotion and panel.get_meta("dragging", false):
			var vp := panel.get_viewport_rect().size
			panel.position = (panel.position + ev.relative).clamp(Vector2.ZERO, (vp - panel.size).max(Vector2.ZERO)))
