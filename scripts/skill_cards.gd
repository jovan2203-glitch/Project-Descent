extends RefCounted

# Skill Card registry (SkillCardData resources in res://data/skill_cards/).
# Usage: const SkillCards = preload("res://scripts/skill_cards.gd")
#
# A card id is the ability id it grants. Equip up to MAX_EQUIPPED cards in the
# main menu's Abilities & Talents tab: when you reach a card's unlock level, the
# level-up draft is guaranteed to offer that card's ability.

const DIR := "res://data/skill_cards/"
const MAX_EQUIPPED := 5
const ALL := ["frostnova", "icebarrier", "blink",
	"rimeshell", "meltwater", "rimeveil", "breaktheice", "frostlattice", "rimefall", "frosttide", "stillwater", "springthaw", "shatteringwave", "flashfreeze", "hoarfrost", "shatteringslam", "rimeslash", "iceshards",
	"searingstrike", "flamingarrow", "flamenova", "ventflames", "coolhead", "furnacebreath", "slagskin", "stoke", "embervolley", "immolate", "walloffire",
	"kilnblast",
	"brand", "anvil", "cinderstep", "cinderguard", "crucible", "heatsink", "quench", "flare",
	"pitcharrow", "cinderrain", "cinderwing",
	"redhotrivet", "forgeblow", "moltenshell", "foldsteel", "rededge", "blastfurnace", "coalshot", "touchoff", "brushfire",
	"chainlightning", "thunderstrike", "stormarrow",
	"discharge", "groundout", "balllightning", "groundingsurge",
	"forkedbolt", "arcflash", "livewire", "jolt", "thunderhead", "flicker", "capacitor",
	"chargededge", "whiplash", "arccleave", "cadence", "twincurrent", "staticstep", "backcurrent", "overdrive",
	"reflexarc", "faradayguard", "splitsecond",
	"arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion",
	"unravel", "glint", "scatter", "countdown", "collapse", "intervalward", "convergence", "mirrorsigil", "rewind", "lapse",
	"doubleup", "ripple", "missedbeat", "fullset", "standin", "tradeplaces", "decoy", "crowdofone",
	"swiftcut", "deepcut", "encore", "latecut", "widecut", "doubletime",
	"corruption", "shadowstrike", "shadowarrow",
	"blight", "erode", "gnaw", "calldue", "spill", "pall", "hush", "takeitback", "bottomless",
	"sic", "openup", "bothatonce", "runthemdown", "guarddogs", "bringitdown", "offthechain",
	"puppetstring", "patchup", "hoist", "tug", "catscradle", "wrench", "pulltaut", "cuppedhands", "stringup", "restring",
	"knot", "tangle", "yank", "doublethread", "behinditsback", "slack", "stillstanding", "cutthestrings", "notfinished", "backonyourfeet",
	"singmercy", "singchorus", "singvigil", "outpour", "lift", "refrain", "canticle", "exultation", "antiphon", "shelter",
	"steadyvoice", "highnote", "reprise", "swell", "rest", "lastverse", "hymnofwaking",
	"censerswing", "hallowedarc", "beckon", "pourout", "absolve", "aureole", "gatherthelight", "raisethecenser", "unfallen",
	"setprism", "moveprism", "mendingray", "brightlance", "gleam", "prismward", "piercinglight", "realign", "shatterprism", "shatterall", "infuse", "kaleidoscope", "relight",
	"prismarrow", "glimmershot", "refractingshot", "sunlitarrow", "prismbreaker", "stepoflight", "spectrumvolley",
	"froststrike", "frostarrow",
	"coldspike", "sleetwave", "deepwinter", "rimelock", "snowward", "winterhide", "rimeedge", "icebreaker", "icepin",
	"coldshoulder", "rimequake", "hailcoat", "hardrime", "glacialbulwark", "hoarcleave", "calving", "bitteredge", "blackfrost",
	"shattershot", "glacialdraw", "rimefletch", "coldmark", "icyretreat",
	"thornshot", "briartiger", "mossback", "thornwing", "chokingvipers", "greenwoodstag",
	"dewfall", "fawn", "rootguard", "owl", "heartwoodelk", "wildherd", "returntobloom",
	"rootsnare", "deeproots", "sporesleep", "leafcloak", "coolingslag", "bellows", "staticsnare", "stormfront", "fixedpoint", "bindingring", "circleofsilence", "holyground", "climbthestring",
	"vinefist", "grasp", "stomp", "giantshands", "heartsap", "awaken",
	"fangarrow", "adderarrow", "asparrow", "kraitarrow", "venomburst", "spittingvolley", "bloatarrow", "coilback", "venomsurge",
	"stormshield", "thunderaegis",
	"returnstroke", "shockring", "crossguard", "drawthestorm", "reelin", "recharge",
	"wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul",
	"punch", "catch", "comeon", "toughitout", "onemore",
	"cut", "whirl", "dartin", "kickoff", "twinstab", "closeitout", "rollwithit", "hityourstride", "snatch",
	"pintheshadow", "overtheshoulder", "playdead", "stonethrow",
	"quickshot", "pierce", "spread", "heavydraw", "followup", "breathe", "fasthands",
	"counterspell"]

static var _cache := {}

static func exists(id: String) -> bool:
	return ALL.has(id)

static func get_resource(id: String) -> Resource:
	if not ALL.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(DIR + id + ".tres")
	return _cache[id]

## Ability id the card grants ("" if unknown).
static func ability_of(id: String) -> String:
	var c := get_resource(id)
	return str(c.ability.id) if c and c.ability else ""

## Level at which the card guarantees its ability in the draft (0 = never).
static func level_of(id: String) -> int:
	var c := get_resource(id)
	if c == null or int(c.unlock_trigger) != 1:   # 1 = PLAYER_LEVEL
		return 0
	return int(c.unlock_level)

static func tooltip(id: String) -> String:
	var Abilities = load("res://scripts/abilities.gd")
	var aid := ability_of(id)
	return "%s — Skill Card\nWhile equipped: from level %d, every ability draft offers %s until you learn it.\n\n%s" % [
		Abilities.ability_name(aid), level_of(id), Abilities.ability_name(aid), Abilities.tooltip(aid)]
