extends RefCounted

# Naming layer: EVERY player-visible name for dungeons, biomes, enemies, bosses,
# boss abilities, modifiers and objectives lives in this one table.
# Data files (data/dungeons/*.tres) only store keys like "boss_crypt_1".
# When the lore arrives, rewrite the text here - nothing else has to change.
#
#   Names.t("dng_crypt")          -> "The Crypt"
#   Names.t("missing_key")        -> "missing_key" (so a typo is easy to spot)

const TEXT := {
	# --- Dungeons ---------------------------------------------------------------
	"dng_crypt": "The Crypt",
	"dng_crypt_desc": "Long, narrow halls packed with the restless dead. They come in swarms: bring AoE.",
	"dng_warren": "The Warren",
	"dng_warren_desc": "A maze of tunnels full of goblin casters and archers. Use corners to break line of sight, and interrupt the casts.",
	"dng_fort": "The Fort",
	"dng_fort_desc": "A ruined fort. Clear three wings to open the keep. Shieldbearers block from the front, and medics heal: kill them first.",
	"dng_pit": "The Pit",
	"dng_pit_desc": "A frozen shaft that goes down and down. Every level ends in an arena where the waves don't stop.",
	"dng_legacy_crypt": "Old Crypt (legacy)",
	"dng_legacy_crypt_desc": "The old endless-floor crypt. Kept for testing; not in the random pool.",
	"dng_random": "Random Dungeon",
	"dng_random_desc": "Queue up and get sent into a random dungeon. Enemies match your party's level.",

	# --- Biome kits -------------------------------------------------------------
	"biome_stone_crypt": "Stone Crypt",
	"biome_cave": "Cave",
	"biome_ruined_fort": "Ruined Fort",
	"biome_frozen_hall": "Frozen Hall",

	# --- Roles (gameplay archetypes) ---------------------------------------------
	"role_brute": "Brute",
	"role_swarmer": "Swarmer",
	"role_caster": "Caster",
	"role_archer": "Archer",
	"role_defender": "Defender",
	"role_support": "Support",
	"role_summoner": "Summoner",
	"role_elite": "Elite",
	"role_boss": "Boss",

	# --- Enemy skins (what a role is called in a dungeon) --------------------------
	"crypt_swarmer": "Shambling Corpse",
	"crypt_brute": "Bloated Ghoul",
	"crypt_caster": "Grave Whisperer",
	"crypt_summoner": "Bone Caller",
	"warren_swarmer": "Warren Runt",
	"warren_archer": "Tunnel Sniper",
	"warren_caster": "Warren Hexer",
	"warren_support": "Mossmender",
	"fort_defender": "Shieldbearer",
	"fort_support": "Field Medic",
	"fort_brute": "Siege Brute",
	"fort_archer": "Rampart Archer",
	"fort_swarmer": "Fort Scrapper",
	"pit_swarmer": "Frostbitten Husk",
	"pit_brute": "Ice-Bound Hulk",
	"pit_caster": "Rime Caller",
	"pit_archer": "Pit Stalker",
	"pit_summoner": "Deep Summoner",
	"pit_defender": "Glacier Guard",

	# --- Bosses -------------------------------------------------------------------
	"boss_crypt_1": "The Gravekeeper",
	"boss_crypt_2": "Mother of Maggots",
	"boss_crypt_3": "Choirmaster Veyl",
	"boss_crypt_4": "The Hollow King",
	"boss_warren_1": "Skitterfang",
	"boss_warren_2": "Hexmother Grizzle",
	"boss_warren_3": "Warlord Gnash",
	"boss_fort_1": "Captain Brask",
	"boss_fort_2": "Sister Mercy",
	"boss_fort_3": "Old Rampart",
	"boss_fort_4": "Warden Kael",
	"boss_pit_1": "Rimefang",
	"boss_pit_2": "Glacia the Shatterer",
	"boss_pit_3": "Summoner Morrow",
	"boss_pit_4": "The Maw Below",

	# --- Boss / role abilities ------------------------------------------------------
	"ab_grave_slam": "Grave Slam",
	"ab_call_dead": "Call the Dead",
	"ab_burrowing_swarm": "Burrowing Swarm",
	"ab_brood": "Brood",
	"ab_wail": "Wail",
	"ab_dirge": "Dirge",
	"ab_bone_eruption": "Bone Eruption",
	"ab_grave_rush": "Grave Rush",
	"ab_raise_dead": "Raise Dead",
	"ab_hollow_crown": "Hollow Crown",
	"ab_arrow_storm": "Arrow Storm",
	"ab_pounce": "Pounce",
	"ab_hex_blast": "Hex Blast",
	"ab_call_hexers": "Call the Hexers",
	"ab_cleave": "Cleave",
	"ab_bull_rush": "Bull Rush",
	"ab_call_snipers": "Call the Snipers",
	"ab_shield_bash": "Shield Bash",
	"ab_charge": "Charge",
	"ab_mend": "Mend",
	"ab_call_guards": "Call the Guards",
	"ab_holy_nova": "Holy Nova",
	"ab_artillery": "Artillery",
	"ab_ground_pound": "Ground Pound",
	"ab_call_garrison": "Call the Garrison",
	"ab_ring_of_steel": "Ring of Steel",
	"ab_frost_nova": "Frostburst",
	"ab_ice_lunge": "Ice Lunge",
	"ab_shatter": "Shatter",
	"ab_glacial_ring": "Glacial Ring",
	"ab_call_the_deep": "Call the Deep",
	"ab_deep_freeze": "Deep Freeze",
	"ab_devour": "Devour",
	"ab_hailstorm": "Hailstorm",
	"ab_shadow_bolt": "Gloom Bolt",
	"ab_firebolt": "Firebolt",
	"ab_frostbolt": "Frost Bolt",
	"ab_summon": "Summon",
	"ab_enrage": "Enrage",

	# --- Modifiers --------------------------------------------------------------------
	"mod_frost_touched": "Frost-Touched",
	"mod_frost_touched_desc": "Enemies take 50% more Frost damage but 50% less Fire damage.",
	"mod_volatile": "Volatile",
	"mod_volatile_desc": "Elites explode when they die. Get out of the circle.",
	"mod_bloodthirst": "Bloodthirst",
	"mod_bloodthirst_desc": "Healing is reduced by 40%, but Lifesteal is doubled.",
	"mod_darkness": "Darkness",
	"mod_darkness_desc": "The dungeon is pitch black. You can only see a short way around you.",
	"mod_frenzy": "Frenzy",
	"mod_frenzy_desc": "Enemies enrage below 30% health: they hit harder and attack faster.",

	# --- Objectives (per section) --------------------------------------------------
	"obj_reach_exit": "Reach the boss",
	"obj_clear_pct": "Slay %d%% of the enemies",
	"obj_key_elites": "Slay the Keybearers",
	"obj_survive_waves": "Survive the waves",
	"obj_defend": "Hold the circle",
	"obj_timed_escape": "Reach the boss in time",
	"obj_wing_bosses": "Defeat the wing bosses",
	"obj_boss": "Defeat %s",
	"obj_exit": "Escape through the portal",
	"keybearer": "Keybearer",
}

static func t(key: String) -> String:
	return str(TEXT.get(key, key))

static func has(key: String) -> bool:
	return TEXT.has(key)
