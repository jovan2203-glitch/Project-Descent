extends RefCounted

# Talent trees: one per category (see categories.gd), ROWS rows each.
# Rows unlock GLOBALLY: once POINTS_TO_UNLOCK_NEXT points are spent in row N of
# ANY tree (summed across all trees), row N+1 opens in EVERY tree. So you can
# put 3 points into Fire's first row and then take a second-row Frost talent.
# Usage: const Talents = preload("res://scripts/talents.gd")
#
# Talent ids are "<category>_<key>" (e.g. "fire_kindling").
# A talent may carry "stats" (per rank, added to the player's stats). Talents
# without an effect yet have "implemented": false and show that in the tooltip.

const Categories = preload("res://scripts/categories.gd")

const ROWS := 5
const POINTS_TO_UNLOCK_NEXT := 3
const POINTS_AT_LEVEL_1 := 3
const POINTS_PER_LEVEL := 1

## Talent points available at a player level (3 at level 1, +1 per level).
static func points_for_level(level: int) -> int:
	return POINTS_AT_LEVEL_1 + (maxi(level, 1) - 1) * POINTS_PER_LEVEL

# Tree data: category -> rows (top to bottom) -> [key, name, max_rank, description].
# None of these do anything yet (placeholders for the talent pass).
const TREES := {
	"fire": [
		[["kindling", "Kindling", 3, "+4% Fire damage per rank."],
			["smoldering_touch", "Smoldering Touch", 3, "Melee hits have a 5% chance per rank to ignite the target."],
			["heat_wave", "Heat Wave", 2, "+5% cast speed for Fire spells per rank."]],
		[["ignite", "Ignite", 3, "Burn effects deal +10% damage per rank."],
			["flame_reach", "Flame Reach", 2, "+2 m range on Fire spells per rank."],
			["cauterize", "Cauterize", 2, "Heal 1 health per rank when you kill a burning enemy."]],
		[["combustion", "Combustion", 3, "Fire critical hits deal +8% damage per rank."],
			["pyromaniac", "Pyromaniac", 2, "Killing a burning enemy restores 1 mana per rank."],
			["scorched_earth", "Scorched Earth", 3, "Fire area spells leave burning ground for +1 s per rank."]],
		[["inferno", "Inferno", 2, "When a burning enemy dies, the burn spreads to 1 nearby enemy per rank."],
			["molten_core", "Molten Core", 2, "+3% crit chance with Fire spells per rank."]],
		[["phoenix_heart", "Phoenix Heart", 1, "Once per floor, fatal damage instead revives you at 30% health in a burst of flame."]],
	],
	"frost": [
		[["winters_chill", "Winter's Chill", 3, "+4% Frost damage per rank."],
			["ice_veins", "Ice Veins", 3, "+5% cast speed for Frost spells per rank."],
			["permafrost", "Permafrost", 2, "Your slows last +0.5 s per rank."]],
		[["shatter", "Shatter", 3, "+5% crit chance against slowed or frozen enemies per rank."],
			["frozen_armor", "Frozen Armor", 2, "+1 Armor per rank while above 50% health."],
			["arctic_reach", "Arctic Reach", 2, "+2 m range on Frost spells per rank."]],
		[["brittle_ice", "Brittle Ice", 3, "Frozen enemies take +4% damage per rank."],
			["cold_snap", "Cold Snap", 2, "Frost spell cooldowns are 10% shorter per rank."],
			["glacial_spike", "Glacial Spike", 3, "Frost Bolt has a 5% chance per rank to freeze its target."]],
		[["deep_freeze", "Deep Freeze", 2, "Freeze effects last +1 s per rank."],
			["ice_floes", "Ice Floes", 2, "Move 10% faster per rank while channeling Frost spells."]],
		[["absolute_zero", "Absolute Zero", 1, "Enemies that stay in your Blizzard for 3 s are frozen solid."]],
	],
	"lightning": [
		[["static_charge", "Static Charge", 3, "+4% Lightning damage per rank."],
			["quickened", "Quickened", 3, "+3% Move Speed per rank."],
			["conductive", "Conductive", 2, "Your hits make enemies take +3% Lightning damage per rank."]],
		[["chain_reaction", "Chain Reaction", 3, "Lightning spells have a 10% chance per rank to jump to another enemy."],
			["overload", "Overload", 2, "+5% crit chance with Lightning spells per rank."],
			["capacitor", "Capacitor", 2, "Every 5th spell cast restores 1 mana per rank."]],
		[["thunderclap", "Thunderclap", 3, "Lightning crits stun the target for 0.3 s per rank."],
			["surge", "Surge", 2, "+6% cast speed per rank."],
			["grounding", "Grounding", 2, "+1 Armor per rank against spells."]],
		[["storm_caller", "Storm Caller", 2, "Lightning area effects are 15% larger per rank."],
			["arc_flash", "Arc Flash", 2, "Blink leaves a shock behind that deals 2 damage per rank."]],
		[["eye_of_the_storm", "Eye of the Storm", 1, "While at full mana, your Lightning spells always chain."]],
	],
	"arcane": [
		[["arcane_focus", "Arcane Focus", 3, "+4% Arcane damage per rank."],
			["mana_font", "Mana Font", 3, "Mana regenerates 10% faster per rank."],
			["spell_echo", "Spell Echo", 2, "5% chance per rank for an Arcane spell to cost no mana."]],
		[["missile_barrage", "Missile Barrage", 3, "Arcane Missiles have a 10% chance per rank to fire a 4th missile."],
			["displacement", "Displacement", 2, "Blink cooldown is 2 s shorter per rank."],
			["arcane_shield", "Arcane Shield", 2, "+1 Armor per rank while above 50% mana."]],
		[["presence_of_mind", "Presence of Mind", 3, "Arcane crits restore 1 mana per rank."],
			["spellblade", "Spellblade", 2, "Arcane Strike and Arcane Shot deal +1 damage per rank."],
			["slow_time", "Slow Time", 2, "Arcane hits slow the target by 10% per rank for 2 s."]],
		[["arcane_power", "Arcane Power", 2, "+10% damage per rank for 5 s after using Blink."],
			["resonance", "Resonance", 2, "Arcane Explosion is 20% larger per rank."]],
		[["time_warp", "Time Warp", 1, "Once per floor, all your cooldowns are reset when you drop below 25% health."]],
	],
	"shadow": [
		[["dark_pact", "Dark Pact", 3, "+4% Shadow damage per rank."],
			["siphon", "Siphon", 3, "Shadow hits have a 5% chance per rank to heal you for 1."],
			["dread", "Dread", 2, "Weakened enemies deal 1 less damage per rank (min 1)."]],
		[["creeping_death", "Creeping Death", 3, "Corruption lasts +2 s per rank."],
			["umbral_armor", "Umbral Armor", 2, "+1 Armor per rank."],
			["night_eyes", "Night Eyes", 2, "+3% crit chance with Shadow abilities per rank."]],
		[["soul_harvest", "Soul Harvest", 3, "Killing an enemy restores 1 mana per rank."],
			["malice", "Malice", 2, "+10% damage per rank against Corrupted enemies."],
			["shadow_veil", "Shadow Veil", 2, "Enemies notice you from 10% shorter range per rank."]],
		[["contagion", "Contagion", 2, "When a Corrupted enemy dies, Corruption spreads to 1 nearby enemy per rank."],
			["vampiric_touch", "Vampiric Touch", 2, "Shadow Strike heals for +1 per rank."]],
		[["void_form", "Void Form", 1, "Below 30% health, your Shadow abilities cost nothing and heal you for half their damage."]],
	],
	"nature": [
		[["thorns", "Thorns", 3, "Deal 1 damage per rank back to melee attackers."],
			["verdant_growth", "Verdant Growth", 3, "+1 Max Health per rank."],
			["wild_bloom", "Wild Bloom", 2, "+5% healing received per rank."]],
		[["entangle", "Entangle", 3, "Nature hits root the target for 0.2 s per rank."],
			["venom", "Venom", 2, "Poison effects deal +10% damage per rank."],
			["barkskin", "Barkskin", 2, "+1 Armor per rank."]],
		[["regrowth", "Regrowth", 3, "Regenerate 1 health every 10 / 8 / 6 s."],
			["spore_cloud", "Spore Cloud", 2, "Poisoned enemies release a toxic cloud on death (+1 m radius per rank)."],
			["symbiosis", "Symbiosis", 2, "+3% Move Speed per rank."]],
		[["overgrowth", "Overgrowth", 2, "Roots spread to 1 nearby enemy per rank."],
			["natures_grasp", "Nature's Grasp", 2, "+5% crit chance against rooted enemies per rank."]],
		[["heart_of_the_forest", "Heart of the Forest", 1, "Healing you receive also heals nearby allies for 50%."]],
	],
	"holy": [
		[["devotion", "Devotion", 3, "+1 Max Health per rank."],
			["radiance", "Radiance", 3, "+4% Holy damage per rank."],
			["blessed_hands", "Blessed Hands", 2, "+5% healing done per rank."]],
		[["smite", "Smite", 3, "+5% damage against undead per rank."],
			["aegis", "Aegis", 2, "Every 20 s, the next hit on you is reduced by 1 per rank."],
			["purity", "Purity", 2, "Debuffs on you last 10% shorter per rank."]],
		[["consecration", "Consecration", 3, "Holy area effects last +1 s per rank."],
			["mercy", "Mercy", 2, "Critical hits heal you for 1 health per rank."],
			["zeal", "Zeal", 2, "+4% cast speed per rank."]],
		[["beacon", "Beacon", 2, "Heals you cast on allies also heal you for 10% per rank."],
			["retribution", "Retribution", 2, "When you block, deal 2 Holy damage per rank to the attacker."]],
		[["martyrs_grace", "Martyr's Grace", 1, "Once per floor, an ally who would die is saved at 1 health."]],
	],
	"warrior": [
		[["toughness", "Toughness", 3, "+1 Max Health per rank."],
			["weapon_mastery", "Weapon Mastery", 3, "+2% melee crit chance per rank."],
			["battle_rage", "Battle Rage", 2, "Melee hits generate +1 rage every 3 hits per rank."]],
		[["iron_skin", "Iron Skin", 3, "+1 Armor per rank."],
			["cleave", "Cleave", 2, "Melee hits also strike 1 nearby enemy for 30% damage per rank."],
			["bloodlust", "Bloodlust", 2, "Heal 1 health per rank on kill."]],
		[["unstoppable", "Unstoppable", 2, "Slows on you are 20% weaker per rank."],
			["deep_wounds", "Deep Wounds", 3, "Melee crits make the target bleed (+1 damage per rank)."],
			["shield_wall", "Shield Wall", 2, "+10% block chance per rank while below 30% health."]],
		[["juggernaut", "Juggernaut", 2, "+2 Armor per rank."],
			["rampage", "Rampage", 2, "Kills grant +5% damage per rank for 5 s (stacks)."]],
		[["titans_grip", "Titan's Grip", 1, "Two-handed weapons no longer lock your Off Hand."]],
	],
	"rogue": [
		[["nimble", "Nimble", 3, "+3% Move Speed per rank."],
			["keen_edge", "Keen Edge", 3, "+2% crit chance per rank."],
			["opportunist", "Opportunist", 2, "+10% damage per rank against enemies not attacking you."]],
		[["evasion", "Evasion", 3, "+3% chance per rank to dodge an attack."],
			["poisoned_blades", "Poisoned Blades", 2, "Melee hits apply a weak poison (+1 damage per rank)."],
			["swiftness", "Swiftness", 2, "Energy regenerates 10% faster per rank."]],
		[["backstab", "Backstab", 3, "+8% damage per rank when hitting enemies from behind."],
			["shadowstep", "Shadowstep", 2, "Blink cooldown is 2 s shorter per rank."],
			["cheap_tricks", "Cheap Tricks", 2, "Crits slow the target by 10% per rank for 2 s."]],
		[["lethality", "Lethality", 2, "Critical hits deal +10% damage per rank."],
			["vanish", "Vanish", 2, "Enemies notice you from 15% shorter range per rank."]],
		[["death_mark", "Death Mark", 1, "After you crit a target, it takes +20% damage from you for 8 s."]],
	],
	"ranger": [
		[["steady_aim", "Steady Aim", 3, "+2% crit chance with bows per rank."],
			["fleet_foot", "Fleet Foot", 3, "+3% Move Speed per rank."],
			["long_draw", "Long Draw", 2, "+2 m bow range per rank."]],
		[["trapper", "Trapper", 3, "Traps arm 20% faster per rank."],
			["barbed_arrows", "Barbed Arrows", 2, "Arrows make the target bleed (+1 damage per rank)."],
			["eagle_eye", "Eagle Eye", 2, "+5% damage per rank against distant enemies."]],
		[["volley", "Volley", 3, "Multi-Shot deals +10% damage per rank."],
			["camouflage", "Camouflage", 2, "Standing still for 2 s makes your next shot deal +15% damage per rank."],
			["hunters_mark", "Hunter's Mark", 2, "Your target takes +3% damage per rank from your party."]],
		[["piercing_shots", "Piercing Shots", 2, "Arrows pass through 1 extra enemy per rank."],
			["toxicology", "Toxicology", 2, "Poison Arrow lasts +2 s per rank."]],
		[["rain_of_arrows", "Rain of Arrows", 1, "Every 10th arrow calls down a volley on the target's area."]],
	],
}

static var _db := {}
static var _rows_cache := {}   # "cat:row" -> Array[String]

## Flat view: id -> {name, category, tier (row index), max_rank, desc, stats, implemented}.
static func db() -> Dictionary:
	if _db.is_empty():
		for cat in TREES:
			var rows: Array = TREES[cat]
			for r in rows.size():
				var ids: Array[String] = []
				for t in rows[r]:
					var id := "%s_%s" % [cat, t[0]]
					_db[id] = {"name": t[1], "category": cat, "tier": r, "max_rank": int(t[2]),
						"desc": t[3], "stats": {}, "implemented": false}
					ids.append(id)
				_rows_cache["%s:%d" % [cat, r]] = ids
	return _db

static func get_talent(id: String) -> Dictionary:
	return db().get(id, {})

static func exists(id: String) -> bool:
	return db().has(id)

## Row index (0 = top) of a talent.
static func tier_of(id: String) -> int:
	return int(get_talent(id).get("tier", 0))

static func category_of(id: String) -> String:
	return str(get_talent(id).get("category", ""))

## Talent ids in one row of one category's tree (left to right).
static func in_row(category: String, row: int) -> Array[String]:
	db()
	var out: Array[String] = []
	out.assign(_rows_cache.get("%s:%d" % [category, row], []))
	return out

## Every talent id in one category's tree.
static func in_tree(category: String) -> Array[String]:
	var out: Array[String] = []
	for r in ROWS:
		out.append_array(in_row(category, r))
	return out

static func tooltip(id: String, rank: int) -> String:
	var t := get_talent(id)
	if t.is_empty():
		return ""
	var lines: Array[String] = [
		"%s  (%s, row %d)" % [t["name"], Categories.cat_name(t["category"]), int(t["tier"]) + 1],
		str(t["desc"]),
		"Rank %d / %d" % [rank, int(t["max_rank"])],
	]
	if not t.get("implemented", false):
		lines.append("(Not implemented yet: has no effect)")
	return "\n".join(lines)
