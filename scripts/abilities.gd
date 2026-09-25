extends RefCounted

# Ability database + shared action-slot UI (icons, tooltips).
# Usage: const Abilities = preload("res://scripts/abilities.gd")

const UI = preload("res://scripts/ui_kit.gd")

# Order here = order shown in the "unplaced abilities" list.
# Registry backed by AbilityData resources in res://data/abilities/.
const PATHS := {
	"frostbolt": "res://data/abilities/frostbolt.tres",
	"blizzard": "res://data/abilities/blizzard.tres",
	"rayoffrost": "res://data/abilities/rayoffrost.tres",
	"slam": "res://data/abilities/slam.tres",
	"execute": "res://data/abilities/execute.tres",
	"steadyshot": "res://data/abilities/steadyshot.tres",
	"auto_melee": "res://data/abilities/auto_melee.tres",
	"auto_ranged": "res://data/abilities/auto_ranged.tres",
	# Draftable (learned through the level-up draft)
	"icelance": "res://data/abilities/icelance.tres",
	"frostnova": "res://data/abilities/frostnova.tres",
	"icebarrier": "res://data/abilities/icebarrier.tres",
	"blink": "res://data/abilities/blink.tres",
	"whirlwind": "res://data/abilities/whirlwind.tres",
	"battleshout": "res://data/abilities/battleshout.tres",
	"multishot": "res://data/abilities/multishot.tres",
	"poisonarrow": "res://data/abilities/poisonarrow.tres",
	"secondwind": "res://data/abilities/secondwind.tres",
	"fireball": "res://data/abilities/fireball.tres",
	"searingstrike": "res://data/abilities/searingstrike.tres",
	"flamingarrow": "res://data/abilities/flamingarrow.tres",
	"flamenova": "res://data/abilities/flamenova.tres",
	"chainlightning": "res://data/abilities/chainlightning.tres",
	"thunderstrike": "res://data/abilities/thunderstrike.tres",
	"stormarrow": "res://data/abilities/stormarrow.tres",
	"arcanemissiles": "res://data/abilities/arcanemissiles.tres",
	"arcanestrike": "res://data/abilities/arcanestrike.tres",
	"arcaneshot": "res://data/abilities/arcaneshot.tres",
	"arcaneexplosion": "res://data/abilities/arcaneexplosion.tres",
	"shadowbolt": "res://data/abilities/shadowbolt.tres",
	"corruption": "res://data/abilities/corruption.tres",
	"shadowstrike": "res://data/abilities/shadowstrike.tres",
	"shadowarrow": "res://data/abilities/shadowarrow.tres",
	"holylight": "res://data/abilities/holylight.tres",
	"smite": "res://data/abilities/smite.tres",
	"crusaderstrike": "res://data/abilities/crusaderstrike.tres",
	"radiantarrow": "res://data/abilities/radiantarrow.tres",
	"froststrike": "res://data/abilities/froststrike.tres",
	"frostarrow": "res://data/abilities/frostarrow.tres",
	"wrath": "res://data/abilities/wrath.tres",
	"insectswarm": "res://data/abilities/insectswarm.tres",
	"entanglingroots": "res://data/abilities/entanglingroots.tres",
	"regrowth": "res://data/abilities/regrowth.tres",
	"sinisterstrike": "res://data/abilities/sinisterstrike.tres",
	"rupture": "res://data/abilities/rupture.tres",
	"fanofknives": "res://data/abilities/fanofknives.tres",
	"eviscerate": "res://data/abilities/eviscerate.tres",
	# Shield abilities (warrior-style, holy & lightning books)
	"shieldofdawn": "res://data/abilities/shieldofdawn.tres",
	"sacredbulwark": "res://data/abilities/sacredbulwark.tres",
	"stormshield": "res://data/abilities/stormshield.tres",
	"thunderaegis": "res://data/abilities/thunderaegis.tres",
	# Action-bar buttons that fire the Use: effect of the equipped trinkets
	"trinket_1": "res://data/abilities/trinket_1.tres",
	"trinket_2": "res://data/abilities/trinket_2.tres",
}
## Always available (everything the player had before the draft existed).
const BASE := ["frostbolt", "blizzard", "rayoffrost", "slam", "execute", "steadyshot",
	"trinket_1", "trinket_2"]
## Trinket bar buttons -> the equipment slot whose Use: effect they fire.
const TRINKET_SLOTS := {"trinket_1": "Trinket 1", "trinket_2": "Trinket 2"}

static func is_trinket_slot(id: String) -> bool:
	return TRINKET_SLOTS.has(id)
## Offered by the level-up draft; learned permanently when picked.
const DRAFT_POOL := ["icelance", "frostnova", "icebarrier", "blink", "whirlwind",
	"battleshout", "multishot", "poisonarrow", "secondwind",
	"fireball", "searingstrike", "flamingarrow", "flamenova",
	"chainlightning", "thunderstrike", "stormarrow",
	"arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion",
	"shadowbolt", "corruption", "shadowstrike", "shadowarrow",
	"holylight", "smite", "crusaderstrike", "radiantarrow",
	"froststrike", "frostarrow",
	"wrath", "insectswarm", "entanglingroots", "regrowth",
	"sinisterstrike", "rupture", "fanofknives", "eviscerate",
	"shieldofdawn", "sacredbulwark", "stormshield", "thunderaegis"]
# Every ability that can go on the action bar (order = list order).
const ALL := ["frostbolt", "blizzard", "rayoffrost", "icelance", "frostnova", "icebarrier",
	"froststrike", "frostarrow",
	"fireball", "searingstrike", "flamingarrow", "flamenova",
	"chainlightning", "thunderstrike", "stormarrow", "stormshield", "thunderaegis",
	"blink", "arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion",
	"shadowbolt", "corruption", "shadowstrike", "shadowarrow",
	"wrath", "insectswarm", "entanglingroots", "regrowth",
	"holylight", "smite", "crusaderstrike", "radiantarrow", "shieldofdawn", "sacredbulwark",
	"slam", "execute", "whirlwind", "battleshout", "secondwind",
	"sinisterstrike", "rupture", "fanofknives", "eviscerate",
	"steadyshot", "multishot", "poisonarrow",
	"trinket_1", "trinket_2"]
## Category (book) each ability belongs to — see categories.gd.
const CATEGORY_OF := {
	"frostbolt": "frost", "blizzard": "frost", "rayoffrost": "frost", "icelance": "frost",
	"frostnova": "frost", "icebarrier": "frost", "froststrike": "frost", "frostarrow": "frost",
	"fireball": "fire", "searingstrike": "fire", "flamingarrow": "fire", "flamenova": "fire",
	"chainlightning": "lightning", "thunderstrike": "lightning", "stormarrow": "lightning",
	"blink": "arcane", "arcanemissiles": "arcane", "arcanestrike": "arcane", "arcaneshot": "arcane",
	"arcaneexplosion": "arcane",
	"shadowbolt": "shadow", "corruption": "shadow", "shadowstrike": "shadow", "shadowarrow": "shadow",
	"holylight": "holy", "smite": "holy", "crusaderstrike": "holy", "radiantarrow": "holy",
	"slam": "warrior", "execute": "warrior", "whirlwind": "warrior", "battleshout": "warrior",
	"secondwind": "warrior",
	"steadyshot": "ranger", "multishot": "ranger", "poisonarrow": "ranger",
	"wrath": "nature", "insectswarm": "nature", "entanglingroots": "nature", "regrowth": "nature",
	"sinisterstrike": "rogue", "rupture": "rogue", "fanofknives": "rogue", "eviscerate": "rogue",
	"shieldofdawn": "holy", "sacredbulwark": "holy", "stormshield": "lightning", "thunderaegis": "lightning",
}

## Icon shape for abilities without a hand-drawn icon (drawn in the book's color).
const ICON_FORM := {
	"fireball": "orb", "searingstrike": "blade", "flamingarrow": "arrow", "flamenova": "nova",
	"chainlightning": "zap", "thunderstrike": "blade", "stormarrow": "arrow",
	"arcanemissiles": "missiles", "arcanestrike": "blade", "arcaneshot": "arrow", "arcaneexplosion": "nova",
	"shadowbolt": "orb", "corruption": "swirl", "shadowstrike": "blade", "shadowarrow": "arrow",
	"holylight": "cross", "smite": "orb", "crusaderstrike": "blade", "radiantarrow": "arrow",
	"froststrike": "blade", "frostarrow": "arrow",
	"wrath": "orb", "insectswarm": "missiles", "entanglingroots": "swirl", "regrowth": "cross",
	"sinisterstrike": "blade", "rupture": "blade", "fanofknives": "nova", "eviscerate": "blade",
	"shieldofdawn": "shield", "sacredbulwark": "shield", "stormshield": "shield", "thunderaegis": "shield_nova",
}

const Categories = preload("res://scripts/categories.gd")

static func category_of(id: String) -> String:
	return str(CATEGORY_OF.get(id, ""))

## The ability's book color (projectiles, swings, icons).
static func color_of(id: String) -> Color:
	return Categories.color(category_of(id))

## Abilities in a category, in ALL order.
static func in_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		if CATEGORY_OF.get(id, "") == category:
			out.append(id)
	return out

const RESOURCE_NAMES := ["", "mana", "energy", "rage"]
const CAST_LABELS := ["Instant", "Cast", "Channeled", "Cast"]

static var _res_cache := {}
static var _db_cache := {}

static func get_resource(id: String) -> Resource:
	if not PATHS.has(id):
		return null
	if not _res_cache.has(id):
		_res_cache[id] = load(PATHS[id])
	return _res_cache[id]

static func tags_of(id: String) -> PackedStringArray:
	var r := get_resource(id)
	return r.tags if r else PackedStringArray()

# Dictionary view: name, needs_target, resource, cost, generates, cooldown, tip, tags.
static func db() -> Dictionary:
	if _db_cache.is_empty():
		for id in PATHS:
			var r := get_resource(id)
			_db_cache[id] = {
				"name": r.display_name, "needs_target": r.requires_target,
				"resource": RESOURCE_NAMES[r.resource_type], "cost": r.resource_cost,
				"generates": r.resource_generated, "cooldown": r.cooldown,
				"tags": r.tags, "tip": _build_tip(r),
			}
	return _db_cache

static func info(id: String) -> Dictionary:
	return db().get(id, {})

## Seconds for tooltips: "0.83", "1.5", "2".
static func secs(v: float) -> String:
	var t := "%.2f" % v
	while t.contains(".") and (t.ends_with("0") or t.ends_with(".")):
		t = t.substr(0, t.length() - 1)
	return t

## Current haste as a speed multiplier (1.2 = 20% haste) for live tooltips.
static func live_haste() -> float:
	return Stats.haste_mult(float(stat_source().call(Stats.HASTE)))

static func _build_tip(r: Resource, desc: String = "", haste: float = 1.0) -> String:
	var lines: Array[String] = [r.display_name, desc if desc != "" else fill(str(r.id), r.description, Callable(), {})]
	var bits: Array[String] = []
	var res: String = RESOURCE_NAMES[r.resource_type]
	if r.resource_cost > 0:
		bits.append("%d %s" % [r.resource_cost, res.capitalize()])
	if r.resource_generated > 0:
		bits.append("Generates %d %s" % [r.resource_generated, res.capitalize()])
	if r.cast_type == 0:
		bits.append("Instant")
	elif r.cast_type == 2:
		bits.append("Channeled %s s" % secs(r.cast_time / haste))
	else:
		bits.append("Cast time: %s s%s" % [secs(r.cast_time / haste), " (can move)" if r.can_move_while_casting else ""])
	if r.cooldown > 0.0:
		bits.append("%s s cooldown" % secs(r.cooldown))
	lines.append("  •  ".join(bits))
	var req: Array[String] = []
	if r.weapon_requirement == 1:
		req.append("a melee weapon")
	elif r.weapon_requirement == 2:
		req.append("a bow")
	if r.get("requires_shield"):
		req.append("a shield")
	if r.requires_target:
		req.append("a target")
	if not req.is_empty():
		lines.append("Requires " + _join_and(req))
	lines.append("Tags: " + ", ".join(r.tags))
	return "\n".join(lines)

## "a, b and c"
static func _join_and(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]

## Is a shield equipped in the Off Hand?
static func has_shield_equipped() -> bool:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	if pd == null:
		return false
	return Items.item_type(str(pd.equipment.get("Off Hand", ""))) == "shield"

## Tooltip of a trinket bar button: the equipped trinket's Use: effect.
static func _trinket_tooltip(id: String) -> String:
	var slot: String = TRINKET_SLOTS[id]
	var dim := Color(0.62, 0.62, 0.68)
	var lines: Array[String] = ["[font_size=16]%s[/font_size]" % _c(Color(0.3, 0.95, 0.55), "Use %s" % slot)]
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	var item: String = str(pd.equipment.get(slot, "")) if pd else ""
	if item == "":
		lines.append(_c(dim, "Nothing equipped in %s." % slot))
	else:
		lines.append(_c(Items.rarity_color(item), Items.item_name(item)))
		var use := Items.use_effect_of(item)
		if use:
			lines.append(Items.effect_text(item, use))
			lines.append(_c(dim, "%s s cooldown" % Stats.num(float(use.internal_cooldown))))
		else:
			lines.append(_c(dim, "This trinket has no Use: effect (its Equip: effect works on its own)."))
	lines.append(_c(dim, "Fires the Use: effect of whatever trinket is in %s." % slot))
	return "\n".join(lines)

static func resource_of(id: String) -> String:
	return info(id).get("resource", "")

static func cost_of(id: String) -> int:
	return int(info(id).get("cost", 0))

static func ability_name(id: String) -> String:
	return info(id).get("name", "")

## Plain-text tooltip with live numbers (current stats and weapon).
static func tooltip(id: String) -> String:
	var r := get_resource(id)
	if r == null:
		return ""
	return _build_tip(r, fill(id, r.description, Callable(), {}), live_haste())

# --- Live numbers --------------------------------------------------------------------
# Ability descriptions are templates, filled with the same maths the combat
# pipeline uses (base + Spell/Attack Power bonus), from your current stats and
# weapon, before crits / modifiers / resistances:
#   {hit}   one hit of the ability           {dot}   one tick of its DoT
#   {heal}  its heal                         {flat1} an extra 1-damage hit
#                                                    (chain jumps, splash)

const Stats = preload("res://scripts/core/stats.gd")
const Items = preload("res://scripts/items.gd")
## Heal amounts before power (player.gd uses these).
const HEALS := {"secondwind": 4, "holylight": 5, "regrowth": 4, "shieldofdawn": 2}
const NUM_COLOR := Color(1.0, 0.92, 0.6)

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## Final stats for tooltips: the player in game (includes buffs), otherwise
## gear + talents + level from PlayerData.
static func stat_source() -> Callable:
	var tree := _tree()
	if tree and tree.root:
		var p := tree.get_first_node_in_group("player")
		if p and p.has_method("get_stat"):
			return func(s): return float(p.get_stat(s))
		var pd := tree.root.get_node_or_null("PlayerData")
		if pd:
			var totals: Dictionary = pd.total_stats()
			return func(s): return Stats.from_totals(s, totals)
	return func(s): return Stats.from_totals(s, {})

static func equipped_weapon() -> Dictionary:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	if pd == null:
		return {}
	return Items.get_item(str(pd.equipment.get("Main Hand", "")))

static func uses_weapon(id: String) -> bool:
	var r := get_resource(id)
	return r != null and float(r.weapon_damage_multiplier) > 0.0

## Damage of one hit before power, like player.gd: weapon abilities do weapon
## damage x multiplier (at least 1) + flat damage. -1 = needs a weapon.
static func hit_base(id: String, w: Dictionary) -> int:
	var r := get_resource(id)
	if r == null:
		return 0
	if uses_weapon(id):
		if not w.has("weapon"):
			return -1
		return maxi(int(round(float(w.get("damage", 1)) * float(r.weapon_damage_multiplier))), 1) + int(r.damage)
	return int(r.damage)

## The DoT this ability applies (null if none).
static func dot_effect(id: String) -> Resource:
	var r := get_resource(id)
	var fx: Resource = r.on_hit_effect if r else null
	return fx if fx and int(fx.tick_damage) > 0 else null

static func dot_share(fx: Resource) -> float:
	var s := float(fx.dot_power_share)
	return Stats.DOT_POWER_SHARE if s < 0.0 else s

static func dot_tags(id: String) -> PackedStringArray:
	var t := PackedStringArray(tags_of(id))
	if not t.has("DoT"):
		t.append("DoT")
	return t

## Average damage of one DoT tick (power share included).
static func dot_tick(id: String, stat_of: Callable) -> float:
	var fx := dot_effect(id)
	if fx == null:
		return 0.0
	return float(fx.tick_damage) + Stats.power_bonus(dot_tags(id), stat_of) * dot_share(fx)

## Damage rolls round a fraction up or down at random (2.4 -> 2 or 3),
## so show "2-3" for those and a single number otherwise.
static func fmt_amount(v: float) -> String:
	v = maxf(v, 0.0)
	var lo := floori(v)
	if v - lo < 0.05:
		return str(lo)
	if ceili(v) - v < 0.05:
		return str(ceili(v))
	return "%d-%d" % [lo, lo + 1]

## Fill a description template. `bb` = highlight numbers with BBCode.
static func fill(id: String, text: String, stat_of: Callable, w: Dictionary, bb: bool = false) -> String:
	if not text.contains("{"):
		return text
	if not stat_of.is_valid():
		stat_of = stat_source()
		w = equipped_weapon()
	var power := Stats.power_bonus(tags_of(id), stat_of)
	var base := hit_base(id, w)
	var nums := {
		"hit": "?" if base < 0 else fmt_amount(base + power),   # ? = no weapon equipped
		"dot": fmt_amount(dot_tick(id, stat_of)),
		"heal": fmt_amount(float(HEALS.get(id, 0)) + power),
		"flat1": fmt_amount(1.0 + power),
	}
	for k in nums:
		var v: String = nums[k]
		if bb:
			v = "[color=#%s]%s[/color]" % [NUM_COLOR.to_html(false), v]
		text = text.replace("{%s}" % k, v)
	return text

static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]

static func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

## Rich tooltip (BBCode). `detailed` (Shift) adds the full breakdown: every
## number's source, Spell / Attack Power scaling, crit, haste, DoT maths.
static func tooltip_bbcode(id: String, detailed: bool = false) -> String:
	var r := get_resource(id)
	if r == null:
		return ""
	if is_trinket_slot(id):
		return _trinket_tooltip(id)
	var dim := Color(0.62, 0.62, 0.68)
	var stat_of := stat_source()
	var w := equipped_weapon()
	var tags := tags_of(id)
	var kind := Stats.kind_of(tags)
	var col := color_of(id).lightened(0.35) if CATEGORY_OF.has(id) else Color.WHITE
	var lines: Array[String] = []
	lines.append("[font_size=16]%s[/font_size]" % _c(col, r.display_name))
	var cat := category_of(id)
	lines.append(_c(dim, "%s %s" % [Categories.cat_name(cat) if cat != "" else "", "Spell" if kind == "Spell" else "Ability"]).strip_edges())
	lines.append(fill(id, r.description, stat_of, w, true))

	# Cost / cast / cooldown line.
	var haste := Stats.haste_mult(float(stat_of.call(Stats.HASTE)))
	var res: String = RESOURCE_NAMES[r.resource_type]
	var bits: Array[String] = []
	if r.resource_cost > 0:
		bits.append("%d %s" % [r.resource_cost, res.capitalize()])
	if r.resource_generated > 0:
		bits.append("Generates %d %s" % [r.resource_generated, res.capitalize()])
	if r.cast_type == 0:
		bits.append("Instant")
	elif r.cast_type == 2:
		bits.append("Channeled %s s" % secs(r.cast_time / haste))
	else:
		bits.append("%s s cast%s" % [secs(r.cast_time / haste), " (can move)" if r.can_move_while_casting else ""])
	if r.cooldown > 0.0:
		bits.append("%s s cooldown" % Stats.num(r.cooldown))
	lines.append(_c(dim, "  •  ".join(bits)))
	var req: Array[String] = []
	if r.weapon_requirement == 1:
		req.append("a melee weapon")
	elif r.weapon_requirement == 2:
		req.append("a bow")
	if r.get("requires_shield"):
		req.append("a shield")
	if r.requires_target:
		req.append("a target")
	if not req.is_empty():
		var missing: bool = (r.weapon_requirement == 1 and w.get("weapon", "") != "melee") \
			or (r.weapon_requirement == 2 and w.get("weapon", "") != "ranged") \
			or (bool(r.get("requires_shield")) and not has_shield_equipped())
		lines.append(_c(Color(1, 0.4, 0.35) if missing else dim, "Requires " + _join_and(req)))

	if not detailed:
		lines.append(_c(dim, "[font_size=11]Hold Shift for details[/font_size]"))
		return "\n".join(lines)

	# --- Details -------------------------------------------------------------
	var gold := Color(0.95, 0.75, 0.35)
	var sp := float(stat_of.call(Stats.SPELL_POWER))
	var ap := float(stat_of.call(Stats.ATTACK_POWER))
	var coef: Dictionary = Stats.POWER.get(kind, {})
	var sp_c := float(coef.get(Stats.SPELL_POWER, 0.0))
	var ap_c := float(coef.get(Stats.ATTACK_POWER, 0.0))
	var power := sp * sp_c + ap * ap_c
	lines.append("")
	lines.append(_c(gold, "Scaling"))
	lines.append("%s of Spell Power + %s of Attack Power per hit" % [_pct(sp_c), _pct(ap_c)])
	lines.append(_c(dim, "  Spell Power %s x %s = +%s" % [Stats.num(sp), _pct(sp_c), "%.1f" % (sp * sp_c)]))
	lines.append(_c(dim, "  Attack Power %s x %s = +%s" % [Stats.num(ap), _pct(ap_c), "%.1f" % (ap * ap_c)]))

	var base := hit_base(id, w)
	if base != 0:
		lines.append("")
		lines.append(_c(gold, "Hit damage"))
		if base < 0:
			lines.append(_c(Color(1, 0.4, 0.35), "Equip a weapon: %sx weapon damage%s" % [
				Stats.num(float(r.weapon_damage_multiplier)), " + %d" % r.damage if r.damage > 0 else ""]))
		else:
			if uses_weapon(id):
				var wd := int(w.get("damage", 1))
				var from_w := maxi(int(round(wd * float(r.weapon_damage_multiplier))), 1)
				lines.append(_c(dim, "  Weapon: %d (%s) x %s = %d" % [wd, str(w.get("name", "weapon")), Stats.num(float(r.weapon_damage_multiplier)), from_w]))
				if r.damage > 0:
					lines.append(_c(dim, "  Flat bonus: +%d" % r.damage))
			else:
				lines.append(_c(dim, "  Base: %d" % base))
			lines.append(_c(dim, "  Power: +%.1f" % power))
			lines.append("  = %s damage per hit" % _c(NUM_COLOR, fmt_amount(base + power)))
			if r.tick_interval > 0.0 and r.cast_type == 2:
				var ticks := int(round(r.cast_time / r.tick_interval))
				lines.append(_c(dim, "  %d ticks over the channel (every %.2f s with haste) = %s total" % [
					ticks, r.tick_interval / haste, fmt_amount((base + power) * ticks)]))
	var crit := Stats.crit_chance(tags, stat_of)
	if base != 0 or dot_effect(id) != null:
		lines.append(_c(dim, "  Crit chance: %s%% for double damage" % Stats.num(crit)))
		if r.damage_type != &"":
			lines.append(_c(dim, "  Damage type: %s" % str(r.damage_type).capitalize()))

	var fx := dot_effect(id)
	if fx:
		var share := dot_share(fx)
		var dot_power := Stats.power_bonus(dot_tags(id), stat_of) * share
		var tick := float(fx.tick_interval) / (haste if bool(fx.dot_hasted) else 1.0)
		var ticks := int(floor(float(fx.duration) / maxf(tick, 0.01)))
		lines.append("")
		lines.append(_c(gold, "%s (damage over time)" % str(fx.display_name)))
		lines.append(_c(dim, "  Base tick: %d" % int(fx.tick_damage)))
		lines.append(_c(dim, "  Power: %s of the hit's power bonus = +%.1f" % [_pct(share), dot_power]))
		lines.append("  = %s damage every %.2f s for %s s" % [_c(NUM_COLOR, fmt_amount(dot_tick(id, stat_of))), tick, Stats.num(float(fx.duration))])
		lines.append(_c(dim, "  ~%d ticks = %s total%s%s" % [ticks, fmt_amount(dot_tick(id, stat_of) * ticks),
			"  •  faster with haste" if bool(fx.dot_hasted) else "",
			"  •  can crit" if bool(fx.dot_can_crit) else "  •  can't crit"]))

	if HEALS.has(id):
		lines.append("")
		lines.append(_c(gold, "Healing"))
		lines.append(_c(dim, "  Base: %d  •  Power: +%.1f" % [int(HEALS[id]), power]))
		lines.append("  = %s health" % _c(NUM_COLOR, fmt_amount(float(HEALS[id]) + power)))

	var eff: Resource = r.on_hit_effect
	if eff and fx == null:
		lines.append("")
		var e_lines: Array[String] = []
		for s in eff.stat_modifiers:
			e_lines.append(Stats.bonus_line(str(s), float(eff.stat_modifiers[s])))
		if float(eff.damage_mod_pct) != 0.0:
			e_lines.append("%s%s%% damage %s" % ["+" if eff.damage_mod_pct > 0 else "", Stats.num(float(eff.damage_mod_pct)),
				"taken" if eff.modifies_incoming else "dealt"])
		if eff.root:
			e_lines.append("can't move")
		if eff.stun:
			e_lines.append("stunned")
		lines.append("%s %s" % [_c(gold, "Applies %s:" % str(eff.display_name)),
			_c(dim, "%s for %s s" % [", ".join(e_lines), Stats.num(float(eff.duration))])])

	var extra: Array[String] = []
	if r.radius > 0.0:
		extra.append("Radius %s m" % Stats.num(float(r.radius)))
	if r.requires_target and r.weapon_requirement == 0 and r.cast_range > 0.0:
		extra.append("Range %s m" % Stats.num(float(r.cast_range)))
	elif r.weapon_requirement != 0 and w.has("attack_range"):
		extra.append("Weapon range %s m" % str(w["attack_range"]))
	if haste > 1.0:
		extra.append("Haste %s%%" % Stats.num((haste - 1.0) * 100.0))
	if not extra.is_empty():
		lines.append("")
		lines.append(_c(dim, "  •  ".join(extra)))
	lines.append(_c(dim, "Tags: " + ", ".join(tags)))
	return "\n".join(lines)

# An action-bar style slot. Show an ability in it with set_slot_ability().
static func make_slot(size: float = 52.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.BORDER, 2, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.1, 0.13, 0.95), UI.ACCENT, 2, 6))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.1, 0.14, 0.2, 0.95), UI.ACCENT, 3, 6))
	var icon := Control.new()
	icon.name = "AbilityIcon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): draw_icon(icon, str(icon.get_meta("ability_id", ""))))
	b.add_child(icon)
	return b

static func set_slot_ability(b: Button, id: String) -> void:
	var icon: Control = b.get_node("AbilityIcon")
	icon.set_meta("ability_id", id)
	icon.queue_redraw()
	# Rich live tooltip via the ItemTooltip autoload (Shift = detailed breakdown).
	if id != "":
		b.tooltip_text = ""
		b.set_meta("tip_ability", id)
	else:
		b.tooltip_text = "Empty"
		b.remove_meta("tip_ability")

static func draw_icon(c: Control, id: String) -> void:
	if id == "":
		return
	var s := c.size
	var mid := s / 2.0
	var pad := 5.0
	var k: float = min(s.x, s.y) / 52.0
	var bg := Color(0.08, 0.16, 0.26)
	if CATEGORY_OF.has(id):
		bg = color_of(id).darkened(0.75)
	if id == "secondwind":
		bg = Color(0.1, 0.2, 0.12)
	c.draw_rect(Rect2(Vector2(pad, pad), s - Vector2(pad, pad) * 2), bg, true)
	if ICON_FORM.has(id):
		_draw_form(c, str(ICON_FORM[id]), color_of(id), mid, k, pad)
		return
	match id:
		"trinket_1", "trinket_2":
			# Gem on a chain + the slot number
			var gold := Color(0.95, 0.75, 0.35)
			c.draw_arc(mid + Vector2(0, -6) * k, 9.0 * k, PI * 1.1, PI * 1.9, 10, gold, 1.8 * k, true)
			var gem := PackedVector2Array([mid + Vector2(0, -6) * k, mid + Vector2(9, 3) * k,
				mid + Vector2(0, 15) * k, mid + Vector2(-9, 3) * k])
			c.draw_colored_polygon(gem, Color(0.3, 0.95, 0.55))
			gem.append(gem[0])
			c.draw_polyline(gem, gold, 1.8 * k, true)
			c.draw_circle(mid + Vector2(-2, 1) * k, 2.2 * k, Color(0.9, 1, 0.95))
			var f := ThemeDB.fallback_font
			var n := "1" if id == "trinket_1" else "2"
			c.draw_string_outline(f, Vector2(s.x - pad - 11 * k, s.y - pad - 3 * k), n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), 3, Color.BLACK)
			c.draw_string(f, Vector2(s.x - pad - 11 * k, s.y - pad - 3 * k), n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), gold)
		"frostbolt":
			var dir := Vector2(-1, 1).normalized()
			var o := mid + Vector2(3, -3) * k
			for i in range(3, 0, -1):
				c.draw_circle(o + dir * i * 6.0 * k, (7.0 - i * 1.5) * k, Color(0.4, 0.8, 1.0, 0.25 + 0.1 * (3 - i)))
			c.draw_circle(o, 10.0 * k, Color(0.45, 0.85, 1.0))
			c.draw_circle(o, 5.5 * k, Color(0.9, 0.98, 1.0))
		"blizzard":
			var col := Color(0.75, 0.95, 1.0)
			var r := 15.0 * k
			for i in 3:
				var a := i * PI / 3.0
				var v := Vector2(cos(a), sin(a)) * r
				c.draw_line(mid - v, mid + v, col, 2.5 * k, true)
				for sgn: float in [-1.0, 1.0]:
					var tip: Vector2 = mid + v * sgn * 0.6
					var n: Vector2 = Vector2(cos(a + 0.6), sin(a + 0.6)) * 5.0 * k * sgn
					var n2: Vector2 = Vector2(cos(a - 0.6), sin(a - 0.6)) * 5.0 * k * sgn
					c.draw_line(tip, tip + n, col, 1.8 * k, true)
					c.draw_line(tip, tip + n2, col, 1.8 * k, true)
			c.draw_circle(mid, 3.0 * k, Color(1, 1, 1))
		"rayoffrost":
			var a := Vector2(pad + 5, s.y - pad - 5)
			var b := Vector2(s.x - pad - 5, pad + 5)
			c.draw_line(a, b, Color(0.3, 0.7, 1.0, 0.35), 10.0 * k, true)
			c.draw_line(a, b, Color(0.5, 0.88, 1.0, 0.7), 5.0 * k, true)
			c.draw_line(a, b, Color(0.92, 0.99, 1.0), 2.0 * k, true)
			c.draw_circle(b, 5.0 * k, Color(0.85, 0.97, 1.0))
			c.draw_circle(a, 3.5 * k, Color(0.6, 0.9, 1.0))
		"slam":
			# Impact burst with a sword coming down
			var hit := mid + Vector2(0, 8) * k
			for i in 8:
				var ang := TAU * i / 8.0
				c.draw_line(hit + Vector2(cos(ang), sin(ang)) * 5.0 * k, hit + Vector2(cos(ang), sin(ang)) * 12.0 * k, Color(1.0, 0.7, 0.3), 2.0 * k, true)
			c.draw_line(mid + Vector2(-12, -14) * k, hit, Color(0.9, 0.9, 0.95), 4.0 * k, true)
			c.draw_line(mid + Vector2(-16, -10) * k, mid + Vector2(-8, -18) * k, Color(0.85, 0.7, 0.3), 3.0 * k, true)
			c.draw_circle(hit, 4.0 * k, Color(1, 0.9, 0.6))
		"execute":
			# Heavy blade chopping down with a red slash
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(14, -14) * k, Color(0.9, 0.15, 0.1, 0.6), 7.0 * k, true)
			c.draw_line(mid + Vector2(-6, 10) * k, mid + Vector2(10, -10) * k, Color(0.92, 0.92, 0.96), 6.0 * k, true)
			c.draw_line(mid + Vector2(-12, 4) * k, mid + Vector2(-2, 14) * k, Color(0.85, 0.7, 0.3), 3.5 * k, true)
			c.draw_line(mid + Vector2(-7, 9) * k, mid + Vector2(-14, 16) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			for i in 3:
				c.draw_circle(mid + Vector2(8 + i * 3, 4 + i * 4) * k, (2.2 - i * 0.5) * k, Color(0.85, 0.1, 0.08))
		"steadyshot":
			# Crosshair with an arrow
			var col := Color(0.8, 0.95, 0.6)
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, col, 1.5 * k, true)
			c.draw_line(mid + Vector2(0, -17) * k, mid + Vector2(0, -8) * k, col, 1.5 * k)
			c.draw_line(mid + Vector2(0, 8) * k, mid + Vector2(0, 17) * k, col, 1.5 * k)
			c.draw_line(mid + Vector2(-17, 0) * k, mid + Vector2(-8, 0) * k, col, 1.5 * k)
			c.draw_line(mid + Vector2(8, 0) * k, mid + Vector2(17, 0) * k, col, 1.5 * k)
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(3, -3) * k, Color(0.75, 0.55, 0.35), 2.5 * k, true)
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(6, -6) * k, mid + Vector2(-1, -4) * k, mid + Vector2(4, 1) * k]), Color(0.9, 0.9, 0.95))
		"icelance":
			# Long thin shard
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(15, -15) * k, mid + Vector2(-9, 5) * k,
				mid + Vector2(-13, 13) * k, mid + Vector2(-5, 9) * k]), Color(0.6, 0.92, 1.0))
			c.draw_line(mid + Vector2(13, -13) * k, mid + Vector2(-9, 9) * k, Color(0.95, 1, 1), 1.5 * k, true)
		"frostnova":
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 5.0 * k, mid + Vector2(cos(a), sin(a)) * 16.0 * k, Color(0.6, 0.9, 1.0), 2.5 * k, true)
			c.draw_arc(mid, 11.0 * k, 0, TAU, 24, Color(0.85, 0.97, 1.0, 0.8), 1.5 * k, true)
			c.draw_circle(mid, 4.0 * k, Color(0.9, 0.98, 1.0))
		"icebarrier":
			var sh := PackedVector2Array([mid + Vector2(0, -16) * k, mid + Vector2(13, -10) * k, mid + Vector2(11, 6) * k,
				mid + Vector2(0, 16) * k, mid + Vector2(-11, 6) * k, mid + Vector2(-13, -10) * k])
			c.draw_colored_polygon(sh, Color(0.35, 0.7, 0.95, 0.85))
			sh.append(sh[0])
			c.draw_polyline(sh, Color(0.85, 0.97, 1.0), 2.0 * k, true)
		"blink":
			c.draw_arc(mid + Vector2(-5, 0) * k, 9.0 * k, 0, TAU, 20, Color(0.75, 0.5, 1.0), 2.0 * k, true)
			c.draw_circle(mid + Vector2(8, 0) * k, 5.0 * k, Color(0.9, 0.75, 1.0))
			for i in 3:
				c.draw_line(mid + Vector2(-2 + i * 3, -6 + i * 6) * k, mid + Vector2(4 + i * 3, -6 + i * 6) * k, Color(0.8, 0.6, 1, 0.7), 1.5 * k)
		"whirlwind":
			for i in 3:
				c.draw_arc(mid, (6.0 + i * 4.5) * k, i * 1.4, i * 1.4 + 4.0, 16, Color(0.95, 0.9, 0.85, 0.9 - i * 0.2), 2.5 * k, true)
			c.draw_line(mid + Vector2(-3, 3) * k, mid + Vector2(12, -12) * k, Color(0.9, 0.9, 0.95), 3.0 * k, true)
		"battleshout":
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-12, -5) * k, mid + Vector2(-4, -5) * k,
				mid + Vector2(6, -13) * k, mid + Vector2(6, 13) * k, mid + Vector2(-4, 5) * k, mid + Vector2(-12, 5) * k]), Color(0.9, 0.55, 0.3))
			for i in 3:
				c.draw_arc(mid + Vector2(6, 0) * k, (6.0 + i * 4.0) * k, -0.7, 0.7, 8, Color(1, 0.8, 0.5, 0.8 - i * 0.2), 1.8 * k, true)
		"multishot":
			for off in [-9.0, 0.0, 9.0]:
				c.draw_line(mid + Vector2(-13, 6 + off * 0.5) * k, mid + Vector2(10, -6 + off) * k, Color(0.75, 0.55, 0.35), 2.0 * k, true)
				c.draw_circle(mid + Vector2(11, -6 + off) * k, 2.5 * k, Color(0.9, 0.9, 0.95))
		"poisonarrow":
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(8, -8) * k, Color(0.75, 0.55, 0.35), 2.5 * k, true)
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(13, -13) * k, mid + Vector2(5, -10) * k, mid + Vector2(10, -5) * k]), Color(0.5, 0.95, 0.3))
			for p in [Vector2(-4, -8), Vector2(2, 6), Vector2(8, 2)]:
				c.draw_circle(mid + p * k, 2.2 * k, Color(0.5, 0.95, 0.3, 0.85))
		"secondwind":
			c.draw_rect(Rect2(mid + Vector2(-4, -13) * k, Vector2(8, 26) * k), Color(0.45, 1.0, 0.5), true)
			c.draw_rect(Rect2(mid + Vector2(-13, -4) * k, Vector2(26, 8) * k), Color(0.45, 1.0, 0.5), true)

# Generic icon shapes, tinted with the ability's book color.
static func _draw_form(c: Control, form: String, col: Color, mid: Vector2, k: float, pad: float) -> void:
	var light := col.lightened(0.5)
	var s := c.size
	match form:
		"orb":
			var dir := Vector2(-1, 1).normalized()
			var o := mid + Vector2(3, -3) * k
			for i in range(3, 0, -1):
				c.draw_circle(o + dir * i * 6.0 * k, (7.0 - i * 1.5) * k, Color(col, 0.25 + 0.1 * (3 - i)))
			c.draw_circle(o, 10.0 * k, col)
			c.draw_circle(o, 5.5 * k, light)
		"missiles":
			for p in [Vector2(-9, 8), Vector2(0, -1), Vector2(9, -10)]:
				c.draw_line(mid + (p + Vector2(-7, 7)) * k, mid + p * k, Color(col, 0.5), 3.0 * k, true)
				c.draw_circle(mid + p * k, 4.5 * k, col)
				c.draw_circle(mid + p * k, 2.2 * k, light)
		"zap":
			var pts := PackedVector2Array([Vector2(-14, -14), Vector2(-2, -4), Vector2(-7, 1),
				Vector2(5, 9), Vector2(1, 12), Vector2(14, 16)])
			for i in pts.size():
				pts[i] = mid + pts[i] * k
			c.draw_polyline(pts, Color(col, 0.45), 6.0 * k, true)
			c.draw_polyline(pts, light, 2.2 * k, true)
		"blade":
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(14, -14) * k, Color(col, 0.55), 7.0 * k, true)
			c.draw_line(mid + Vector2(-6, 10) * k, mid + Vector2(12, -12) * k, Color(0.92, 0.92, 0.96), 4.0 * k, true)
			c.draw_line(mid + Vector2(-12, 4) * k, mid + Vector2(-2, 14) * k, col, 3.5 * k, true)
			c.draw_line(mid + Vector2(-7, 9) * k, mid + Vector2(-14, 16) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
		"arrow":
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(8, -8) * k, Color(0.75, 0.55, 0.35), 2.5 * k, true)
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(14, -14) * k, mid + Vector2(5, -11) * k,
				mid + Vector2(11, -5) * k]), light)
			c.draw_circle(mid + Vector2(10, -10) * k, 6.0 * k, Color(col, 0.35))
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-17, 8) * k, col, 2.0 * k, true)
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-8, 17) * k, col, 2.0 * k, true)
		"nova":
			for i in 10:
				var a := TAU * i / 10.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 6.0 * k, mid + Vector2(cos(a), sin(a)) * 17.0 * k, col, 2.5 * k, true)
			c.draw_arc(mid, 12.0 * k, 0, TAU, 24, Color(light, 0.8), 1.5 * k, true)
			c.draw_circle(mid, 4.5 * k, light)
		"swirl":
			for i in 3:
				c.draw_arc(mid, (5.0 + i * 5.0) * k, i * 2.1, i * 2.1 + 4.2, 16, Color(col, 0.95 - i * 0.2), 3.0 * k, true)
			c.draw_circle(mid, 3.0 * k, light)
		"shield", "shield_nova":
			if form == "shield_nova":
				for i in 10:
					var a := TAU * i / 10.0
					c.draw_line(mid + Vector2(cos(a), sin(a)) * 12.0 * k, mid + Vector2(cos(a), sin(a)) * 18.0 * k, light, 2.0 * k, true)
			var sh := PackedVector2Array([mid + Vector2(0, -14) * k, mid + Vector2(12, -9) * k, mid + Vector2(10, 5) * k,
				mid + Vector2(0, 14) * k, mid + Vector2(-10, 5) * k, mid + Vector2(-12, -9) * k])
			c.draw_colored_polygon(sh, col.darkened(0.2))
			sh.append(sh[0])
			c.draw_polyline(sh, light, 2.0 * k, true)
			# Emblem (the book color already tells holy from lightning)
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(0, 8) * k, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(-6, -2) * k, mid + Vector2(6, -2) * k, light, 2.2 * k, true)
		"cross":
			c.draw_circle(mid, 15.0 * k, Color(col, 0.25))
			c.draw_rect(Rect2(mid + Vector2(-4, -13) * k, Vector2(8, 26) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-13, -4) * k, Vector2(26, 8) * k), light, true)
		_:
			c.draw_rect(Rect2(Vector2(pad, pad) * 2, s - Vector2(pad, pad) * 4), col, true)
