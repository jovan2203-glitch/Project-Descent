extends Node

# Balance simulator: an APPROXIMATE damage / healing estimate for every spec in
# Abilities.SPECS at level 50, with no gear and with a full epic set, written to
# docs/BALANCE_REPORT.md. It uses the game's own formulas statically (no scene,
# no player): a hit is coefficient x (Stats.level_hit + Spell/Attack Power bonus),
# x (1 + crit chance); haste shortens casts, the GCD and DoT ticks. A 3-minute
# fight on a fake clock: each GCD it presses the button that does the most per
# second of casting among those ready and affordable (a DoT only when it isn't
# already up), plus weapon auto-attacks for weapon specs. Fury decays as in game.
# NOT counted: talents, runes, items' equip effects, procs, buffs between
# abilities, movement, AoE. Spec-specific payoffs: tools/balance_sim_specs.gd.
#   godot --headless --path . res://tools/balance_sim.tscn
# (tests/test_balance_sim.gd runs simulate() for every spec.)

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Items = preload("res://scripts/items.gd")
const SPECS_INFO = preload("res://tools/balance_sim_specs.gd")

const LEVEL := 50
const FIGHT := 180.0
const REPORT_PATH := "res://docs/BALANCE_REPORT.md"

## Stat totals of the two profiles (flat, before what the primaries give).
## Geared = a level 50 epic set (scripts/core/item_db.gd budgets: 87.5 per flat
## roll, ~497 Critical Strike Rating and ~3.3% Haste per roll) plus 49 attribute points.
const PROFILES := {
	"no gear": {"caster": {}, "physical": {}},
	"geared": {
		"caster": {"intellect": 1500.0, "spell_power": 700.0, "crit_rating": 1000.0, "haste": 6.6, "constitution": 600.0},
		"physical": {"strength": 750.0, "agility": 750.0, "attack_power": 700.0, "crit_rating": 1000.0, "haste": 6.6, "constitution": 600.0},
	},
}
## The weapon a spec of that kind uses (scripts/items.gd ids).
const WEAPONS := {"melee": "sword", "ranged": "bow"}

## Targets from CLAUDE.md "Balance targets".
const TARGET_HIT := 500.0          # level 50, no gear: about this much per ability use
const TARGET_DPS_GEARED := 2000.0  # max level geared DPS
const TARGET_TANK_SHARE := [0.3, 0.4]   # a tank at optimal play: this share of TARGET_DPS_GEARED
## A spec with this many abilities or fewer is incomplete: marked in the report and
## left out of every average and calculation (spec_averages).
const INCOMPLETE_MAX_ABILITIES := 1
const TARGET_TANK_THREAT := [1.3, 1.7]  # ... and this many times its threat (a big spike can still take aggro)

func _ready() -> void:
	var text := report()
	print(text)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		print("Written to %s" % REPORT_PATH)
	get_tree().quit()

# --- One spec ------------------------------------------------------------------------------

## Simulate `spec` (its ability ids) as `role` with the `profile` ("no gear" / "geared").
## `spec_name` picks up its overrides in balance_sim_specs.gd FIGHTS. `extra`: more buttons
## (its book's Utility) that don't decide its gear or weapon.
## Returns {"dps", "hps", "self_hps", "avg_hit", "sources": {name: total}, "idle", "starved",
## "unsimulated": [ability names the sim can't value]}. "idle" = time with nothing to press,
## "starved" = the part of it where a button was off cooldown but unaffordable.
static func simulate(ids: Array, role: String, profile: String, spec_name := "", extra: Array = []) -> Dictionary:
	var fights: Dictionary = SPECS_INFO.FIGHTS.get(spec_name, {})
	var kind: String = fights.get("kind", spec_kind(ids))
	var weapon: String = fights.get("weapon", spec_weapon(ids))
	var totals: Dictionary = PROFILES[profile][kind]
	var stat_of := func(s: String) -> float: return Stats.from_totals(s, totals)
	var haste := Stats.haste_mult(float(stat_of.call(Stats.HASTE)))
	var w := Items.get_item(WEAPONS.get(weapon, ""))
	var max_hp := Stats.player_base_health(LEVEL) + float(stat_of.call(Stats.MAX_HEALTH))
	var buttons := []
	var unsimulated := PackedStringArray()
	for id in ids + extra:
		var b := button(str(id), w, stat_of, haste, max_hp)
		if not b.is_empty():
			buttons.append(b)
		elif Abilities.get_resource(str(id)) != null:
			unsimulated.append(Abilities.ability_name(str(id)))
	var sources := {}
	var dmg_total := 0.0
	var threat_total := 0.0   # damage x each hit's threat multiplier (auto-attacks 1x)
	var heal_total := 0.0
	var self_heal := 0.0
	var uses := 0
	var dmg_uses_total := 0.0
	var ready_at := {}
	var dot_until := {}
	var mana_max := 10.0 + float(stat_of.call(Stats.INTELLECT)) * 4.0 * Stats.POINT_VALUE / Stats.mana_unit(LEVEL)
	var res := {"mana": mana_max, "energy": Balance.RESOURCE_MAX, "fury": 0.0, "venom": 0.0}
	# Weapon auto-attacks (weapon specs): damage, and the Fury each swing gives.
	var swing_every := 0.0
	var swing_dmg := 0.0
	if not w.is_empty() and weapon != "":
		swing_every = float(w.get("attack_interval", 1.0)) / haste
		var auto_tags := PackedStringArray(["AutoAttack"])
		swing_dmg = float(w.get("damage", 0.0)) * Balance.AUTO_ATTACK_MULT * (Stats.level_hit(LEVEL) + Stats.power_bonus(auto_tags, stat_of)) \
			* (1.0 + minf(Stats.crit_chance(auto_tags, stat_of), 100.0) / 100.0)
	var next_swing := 0.0
	var t := 0.0
	var idle := 0.0
	var starved := 0.0
	var venom_spec := ids.has("venomburst")
	# Steady Flame's Fury (FireFuryKit): non-crit Fire spells build it from crit chance,
	# crits Vent part of it, Vent Flames spends it all; none is lost while casting.
	var fury_caster := ids.has("ventflames")
	var fire_crit := minf(Stats.crit_chance(PackedStringArray(["Fire", "Spell"]), stat_of), 100.0) / 100.0
	while t < FIGHT:
		# Auto-attacks up to now.
		while swing_every > 0.0 and next_swing <= t:
			dmg_total += swing_dmg
			threat_total += swing_dmg
			sources["Auto Attack"] = float(sources.get("Auto Attack", 0.0)) + swing_dmg
			res["fury"] = minf(float(res["fury"]) + Balance.AUTO_ATTACK_FURY, Balance.RESOURCE_MAX)
			next_swing += swing_every
		var pick := _best(buttons, role, t, res, ready_at, dot_until)
		var step := 0.1
		if pick.is_empty():
			idle += step
			if _any_unaffordable(buttons, t, res, ready_at, dot_until):
				starved += step
		else:
			var id: String = pick["id"]
			var fury_before := float(res["fury"])
			_pay(pick, res)
			ready_at[id] = t + float(pick["cooldown"])
			if float(pick["dot_time"]) > 0.0:
				dot_until[id] = t + float(pick["dot_time"])
			step = float(pick["exec"])
			var d := float(pick["dmg"])
			if fury_caster and Abilities.tags_of(id).has("Fire") and Abilities.tags_of(id).has("Spell"):
				d = _fire_fury(id, d, fury_before, fire_crit, res)
			var h := float(pick["heal"])
			dmg_total += d
			threat_total += d * float(pick["threat"])
			heal_total += h
			self_heal += float(pick["self_heal"])
			if d > 0.0:
				uses += 1
				dmg_uses_total += d
			var name := Abilities.ability_name(id)
			sources[name] = float(sources.get(name, 0.0)) + (d if role != "healer" else h)
		# Resources come back over the step.
		res["mana"] = minf(float(res["mana"]) + Balance.MANA_REGEN * step, mana_max)
		res["energy"] = minf(float(res["energy"]) + Balance.ENERGY_REGEN * step, Balance.RESOURCE_MAX)
		if not (fury_caster and not pick.is_empty()):
			res["fury"] = maxf(float(res["fury"]) - Balance.FURY_DECAY * step, 0.0)
		if venom_spec and _all_poisons_up(dot_until, t):
			res["venom"] = minf(float(res["venom"]) + Balance.VENOM_PER_TICK * 3.0 * haste * step, Balance.VENOM_MAX)
		t += step
	# The tank rule (Abilities.role_damage_mult): a tank's damage, all of it.
	var dm := Abilities.role_damage_mult(role)
	dmg_total *= dm
	threat_total *= dm * (Balance.TANK_THREAT_MULT if role == "tank" else 1.0)
	dmg_uses_total *= dm
	if role != "healer":
		for k in sources:
			sources[k] = float(sources[k]) * dm
	return {"dps": dmg_total / FIGHT, "tps": threat_total / FIGHT, "hps": heal_total / FIGHT, "self_hps": self_heal / FIGHT,
		"avg_hit": dmg_uses_total / maxf(uses, 1), "sources": sources, "idle": idle / FIGHT, "starved": starved / FIGHT,
		"unsimulated": unsimulated}

## Steady Flame: one press of Fire spell `id` (damage `d` at the usual crit odds) with
## `fury` held before it; updates res["fury"] by the expected gain and Venting and
## returns its damage. Vent Flames always crits and scales on what it spent.
static func _fire_fury(id: String, d: float, fury: float, c: float, res: Dictionary) -> float:
	var vent := c * Balance.FIRE_FURY_VENT_PCT / 100.0   # expected share Vented per hit that can crit
	if id == "ventflames":
		res["fury"] = 0.0
		return d / (1.0 + c) * 2.0 * FireFuryKit.vent_coef(1.0, fury)
	if NEVER_CRIT.has(id):
		return d   # (button() already left its crit out)
	var hits := Balance.EMBER_VOLLEY_HITS if id == "embervolley" else 1
	var f := float(res["fury"])
	for i in hits:
		if FireFuryKit.builds_fury(id):
			f += (1.0 - c) * FireFuryKit.fury_gain(c * 100.0, id == "embervolley", 0.0, false)
		f *= 1.0 - vent
	res["fury"] = clampf(f, 0.0, Balance.RESOURCE_MAX)
	return d

## Hits that never crit (Player.adjust_crit).
const NEVER_CRIT := ["stoke", "kilnblast", "anvil", "quench", "forgeblow"]

## What one press of `id` is worth, or {} if it does no damage and no healing.
static func button(id: String, w: Dictionary, stat_of: Callable, haste: float, max_hp: float) -> Dictionary:
	var r := Abilities.get_resource(id)
	if r == null:
		return {}
	var o: Dictionary = SPECS_INFO.PAYOFF.get(id, {})
	if bool(o.get("skip", false)):
		return {}
	var tags := PackedStringArray(r.tags)
	var unit := Stats.level_hit(LEVEL)
	var crit := 1.0 if NEVER_CRIT.has(id) else 1.0 + minf(Stats.crit_chance(tags, stat_of), 100.0) / 100.0
	var power := Stats.power_bonus(tags, stat_of)
	var coef := float(o.get("coef", -2.0))
	if coef == -2.0:
		coef = Abilities.hit_base(id, w)
	if coef < 0.0:
		return {}   # needs a weapon this spec doesn't use
	var dot := float(o.get("dot", 0.0))
	var dot_time := float(o.get("dot_time", 0.0))
	var fx := Abilities.dot_effect(id)
	if dot <= 0.0 and fx != null:
		dot_time = float(fx.duration)
		dot = float(fx.tick_damage) * dot_time / maxf(float(fx.tick_interval), 0.05)
	var heal := float(o.get("heal", Balance.HEALS.get(id, 0.0)))
	var heal_power := Stats.power_bonus(PackedStringArray(["Spell"]), stat_of)
	var dmg := (coef + dot * haste) * (unit + power) * crit
	var healed := heal * (unit + heal_power)
	var self_heal := max_hp * float(o.get("self_heal_pct", 0.0)) / 100.0
	if dmg <= 0.0 and healed <= 0.0 and self_heal <= 0.0:
		return {}
	var cast := Abilities.base_cast_time(r) / haste
	var gcd := 0.0 if Abilities.OFF_GCD.has(id) else maxf(Balance.GCD_BASE / Stats.haste_mult(float(stat_of.call(Stats.HASTE)) * Balance.GCD_HASTE_SHARE), Balance.GCD_MIN)
	var res_name := Abilities.resource_of(id)
	var cost := Abilities.cost_of(id)
	if id == "ventflames":
		cost = Balance.VENT_FURY_MIN   # (it spends all of it: _fire_fury)
	if SPECS_INFO.VENOM_COSTS.has(id):
		res_name = "venom"
		cost = float(SPECS_INFO.VENOM_COSTS[id])
	return {"id": id, "dmg": dmg, "heal": healed, "self_heal": self_heal, "exec": maxf(maxf(cast, gcd), 0.1),
		"cooldown": Abilities.cooldown_of(r), "res": res_name, "cost": cost,
		"gen": float(Abilities.generated_of(id)), "threat": float(r.threat_multiplier) if r.get("threat_multiplier") != null else 1.0, "dot_time": dot_time if dot > 0.0 and coef <= 0.0 else 0.0, "last": float(o.get("last", 1.0))}

## The ready, affordable button that does the most per second of casting (a pure DoT only when it's down).
static func _best(buttons: Array, role: String, t: float, res: Dictionary, ready_at: Dictionary, dot_until: Dictionary) -> Dictionary:
	var best := {}
	var best_v := 0.0
	for b in buttons:
		var id: String = b["id"]
		if float(ready_at.get(id, 0.0)) > t + 0.001:
			continue
		if t < FIGHT * (1.0 - float(b.get("last", 1.0))):
			continue   # (an execute: only near the end)
		if float(b["dot_time"]) > 0.0 and float(dot_until.get(id, 0.0)) > t:
			continue
		if b["res"] != "" and float(b["cost"]) > float(res.get(b["res"], 0.0)) + 0.0001:
			continue
		var worth := float(b["heal"]) if role == "healer" else float(b["dmg"])
		if id == "ventflames":
			worth = FireFuryKit.vent_coef(worth, float(res.get("fury", 0.0)))   # (worth more the fuller the bar)
		if role == "tank":
			worth += float(b["self_heal"]) * 0.5
		var v := worth / float(b["exec"])
		if v > best_v:
			best_v = v
			best = b
	return best

## A button that is off cooldown (and usable now) but costs more than you have.
static func _any_unaffordable(buttons: Array, t: float, res: Dictionary, ready_at: Dictionary, dot_until: Dictionary) -> bool:
	for b in buttons:
		if float(ready_at.get(b["id"], 0.0)) > t + 0.001 or t < FIGHT * (1.0 - float(b.get("last", 1.0))):
			continue
		if float(b["dot_time"]) > 0.0 and float(dot_until.get(b["id"], 0.0)) > t:
			continue
		if b["res"] != "" and float(b["cost"]) > float(res.get(b["res"], 0.0)) + 0.0001:
			return true
	return false

static func _pay(b: Dictionary, res: Dictionary) -> void:
	var r: String = b["res"]
	if r != "":
		res[r] = maxf(float(res.get(r, 0.0)) - float(b["cost"]), 0.0)
	if float(b["gen"]) > 0.0:
		var key := "fury" if r == "" or r == "fury" else r
		res[key] = minf(float(res.get(key, 0.0)) + float(b["gen"]), Balance.RESOURCE_MAX)

static func _all_poisons_up(dot_until: Dictionary, t: float) -> bool:
	for id in ["adderarrow", "asparrow", "kraitarrow"]:
		if float(dot_until.get(id, 0.0)) <= t:
			return false
	return true

## "caster" when most of the spec's abilities are spells, else "physical".
static func spec_kind(ids: Array) -> String:
	var spells := 0
	for id in ids:
		if Abilities.tags_of(str(id)).has("Spell"):
			spells += 1
	return "caster" if spells * 2 >= ids.size() else "physical"

## "ranged", "melee" or "" (no weapon abilities): the weapon the spec fights with.
static func spec_weapon(ids: Array) -> String:
	var melee := 0
	var ranged := 0
	for id in ids:
		var r := Abilities.get_resource(str(id))
		if r == null:
			continue
		match int(r.weapon_requirement):
			1:
				melee += 1
			2:
				ranged += 1
	if ranged == 0 and melee == 0:
		return ""
	return "ranged" if ranged >= melee else "melee"

# --- The report --------------------------------------------------------------------------

static func report() -> String:
	var lines := PackedStringArray()
	lines.append("# Balance report (approximate)")
	lines.append("")
	lines.append("Level %d, a %d-second single-target fight. Generated by tools/balance_sim.gd. Not counted: talents, runes, items' equip effects, procs, AoE, movement. Geared = a full level 50 epic set. Targets (CLAUDE.md): about %d per ability use with no gear, about %d DPS geared; tanks (who deal %d%% of their damage) %d-%d DPS geared, with %d-%d threat per second (TPS: damage x threat; a DPS makes 1x)." \
		% [LEVEL, int(FIGHT), int(TARGET_HIT), int(TARGET_DPS_GEARED), int(Balance.TANK_DAMAGE_PCT),
		int(TARGET_DPS_GEARED * float(TARGET_TANK_SHARE[0])), int(TARGET_DPS_GEARED * float(TARGET_TANK_SHARE[1])),
		int(TARGET_DPS_GEARED * float(TARGET_TANK_THREAT[0])), int(TARGET_DPS_GEARED * float(TARGET_TANK_THREAT[1]))])
	lines.append("")
	lines.append("Idle = time with nothing to press: \"waiting on cooldowns\" when every button was on cooldown, \"resource-starved\" when one was ready but unaffordable. Not simulated = buttons with no damage or healing the sim can value (shields, mitigation, utility).")
	lines.append("")
	lines.append("| Book | Spec | Role | Avg use (no gear) | No gear | Geared | Top sources (geared) | Flags | Not simulated |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	var rows := []   # [role, geared result, complete?]
	for book in Abilities.SPECS:
		var utility := utility_of(book)
		for spec in Abilities.SPECS[book]:
			var name: String = spec[0]
			var role: String = SPECS_INFO.ROLES.get(name, "dps")
			if role == "utility":
				continue   # (simulated as part of every spec of its book, below)
			var ids: Array = spec[1]
			var bare := simulate(ids, role, "no gear", name, utility)
			var full := simulate(ids, role, "geared", name, utility)
			var flags := _flags(bare, full, role)
			if is_incomplete(ids):
				flags = PackedStringArray(["INCOMPLETE (%d ability, not in averages)" % ids.size()]) + flags
			rows.append([role, full, not is_incomplete(ids)])
			lines.append("| %s | %s | %s | %d | %s | %s | %s | %s | %s |" % [book.capitalize(), name, role, int(bare["avg_hit"]),
				_rate(bare, role), _rate(full, role), _top(full["sources"]), ", ".join(flags),
				", ".join(full["unsimulated"])])
	lines.append("")
	lines.append("## Averages (geared, complete specs only)")
	lines.append("")
	for role in ["dps", "tank", "healer"]:
		var a := spec_averages(rows, role)
		if int(a["count"]) == 0:
			continue
		var key := "hps" if role == "healer" else "dps"
		var line := "- %s: average %d %s, median %d (%d specs; %d incomplete left out)" % [{"dps": "DPS", "tank": "Tanks", "healer": "Healers"}[role], int(a["avg"]), key.to_upper(),
			int(a["median"]), int(a["count"]), int(a["left_out"])]
		if role == "tank":
			line += ", average %d TPS" % int(a["avg_tps"])
		lines.append(line)
	return "\n".join(lines) + "\n"

## Too few abilities to judge (INCOMPLETE_MAX_ABILITIES): never counted in averages.
static func is_incomplete(ids: Array) -> bool:
	return ids.size() <= INCOMPLETE_MAX_ABILITIES

## Average and median of `role`'s geared DPS (HPS for healers) over `rows`
## ([role, geared result, complete?]), incomplete specs left out.
static func spec_averages(rows: Array, role: String) -> Dictionary:
	var key := "hps" if role == "healer" else "dps"
	var vals: Array[float] = []
	var tps := 0.0
	var left_out := 0
	for r in rows:
		if r[0] != role:
			continue
		if not bool(r[2]):
			left_out += 1
			continue
		vals.append(float(r[1][key]))
		tps += float(r[1].get("tps", 0.0))
	vals.sort()
	var n := vals.size()
	var total := 0.0
	for v in vals:
		total += v
	var median := 0.0
	if n > 0:
		median = vals[n / 2] if n % 2 == 1 else (vals[n / 2 - 1] + vals[n / 2]) / 2.0
	return {"count": n, "left_out": left_out, "avg": total / maxf(n, 1), "median": median, "avg_tps": tps / maxf(n, 1)}

## A book's "Utility" divider (its ids; [] if it has none).
static func utility_of(book: String) -> Array:
	for spec in Abilities.SPECS[book]:
		if SPECS_INFO.ROLES.get(spec[0], "dps") == "utility":
			return spec[1]
	return []

static func _rate(r: Dictionary, role: String) -> String:
	match role:
		"healer":
			return "%d HPS" % int(r["hps"])
		"tank":
			return "%d DPS, %d TPS, %d self-HPS" % [int(r["dps"]), int(r["tps"]), int(r["self_hps"] + r["hps"])]
	return "%d DPS" % int(r["dps"])

static func _top(sources: Dictionary) -> String:
	var keys := sources.keys()
	keys.sort_custom(func(a, b): return float(sources[a]) > float(sources[b]))
	var total := 0.0
	for k in keys:
		total += float(sources[k])
	var out := PackedStringArray()
	for k in keys.slice(0, 3):
		out.append("%s %d%%" % [k, int(round(float(sources[k]) / maxf(total, 1.0) * 100.0))])
	return ", ".join(out)

static func _flags(bare: Dictionary, full: Dictionary, role: String) -> PackedStringArray:
	var out := PackedStringArray()
	if role == "dps":
		if float(full["dps"]) > TARGET_DPS_GEARED * 1.25:
			out.append("geared DPS high")
		elif float(full["dps"]) < TARGET_DPS_GEARED * 0.75:
			out.append("geared DPS low")
	if role == "tank":
		if float(full["dps"]) > TARGET_DPS_GEARED * float(TARGET_TANK_SHARE[1]):
			out.append("tank DPS high")
		elif float(full["dps"]) < TARGET_DPS_GEARED * float(TARGET_TANK_SHARE[0]):
			out.append("tank DPS low")
		if float(full["tps"]) > TARGET_DPS_GEARED * float(TARGET_TANK_THREAT[1]):
			out.append("threat high (DPS can't pull)")
		elif float(full["tps"]) < TARGET_DPS_GEARED * float(TARGET_TANK_THREAT[0]):
			out.append("threat low")
	if role == "dps" and float(bare["avg_hit"]) > 0.0:
		if float(bare["avg_hit"]) > TARGET_HIT * 1.6:
			out.append("hits big")
		elif float(bare["avg_hit"]) < TARGET_HIT * 0.5:
			out.append("hits small")
	var idle := float(full["idle"])
	if idle > 0.25:
		var starved := float(full["starved"])
		var why := "resource-starved" if starved >= idle * 0.5 else "waiting on cooldowns"
		out.append("idle %d%% (%s)" % [int(idle * 100.0), why])
	return out
