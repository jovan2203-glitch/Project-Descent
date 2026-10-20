extends RefCounted

# What the balance simulator (tools/balance_sim.gd) needs to know per spec that
# the ability data alone doesn't say: its role, and the payoff of abilities whose
# real value is worked out in player.gd from stacks / patches / Venom.
# Keep it short: one line per spec, overrides only where the data is wrong.

## Spec name (Abilities.SPECS) -> "dps", "tank", "healer" or "utility" (every book's
## "Utility" divider: no damage or healing to simulate, left out of the report).
const ROLES := {
	"Steady Flame": "dps", "Slagforged": "tank", "Forge Heat": "dps", "Pitch and Cinder": "dps",
	"Hard Winter": "dps", "Cold Comfort": "tank", "Frostbitten Steel": "dps", "Winter Hunt": "dps",
	"Live Current": "dps", "Stormdancer": "dps", "Lightning Rod": "tank", "Stormstring": "dps",
	"Clockwork": "dps", "Hall of Mirrors": "tank", "Second Act": "dps", "Aetherstring": "dps",
	"The Breach": "dps", "Pack of Two": "dps", "Strings Attached": "healer", "Nightstring": "dps",
	"Thornweaver": "dps", "Shepherd": "healer", "Colossus": "tank", "Venomstring": "dps",
	"Choir of One": "healer", "Censer Bearer": "tank", "Line of Light": "healer", "Lightstring": "dps",
	"The Wheel": "dps", "Brawler": "tank", "Rogue": "dps",
	"Utility": "utility",
}

## Spec name -> how it fights, where its abilities' tags say otherwise:
##   "kind": "caster" / "physical" (which gear profile), "weapon": "melee" / "ranged" / "" (auto-attacks).
const FIGHTS := {}

## Ability id -> what one use is really worth, where its data doesn't say it:
##   "coef": direct damage (coefficient), "dot": damage over time in all, "dot_time": its seconds,
##   "heal": heal (old Heal x REFERENCE_HEAL units, like Balance.HEALS),
##   "self_heal_pct": % of max health healed on yourself, "skip": not a damage / heal button.
##   "last": usable only in this last share of the fight (an execute below 20% health).
const PAYOFF := {
	# Nature caster: finishers at an average of 3 patches; Thornburst on the target once.
	"mossback": {"coef": 0.6 + 0.6 * 3},
	"chokingvipers": {"coef": 0.0, "dot": 0.4 + 0.4 * 3, "dot_time": 3.0},
	"thornshot": {"coef": 1.0 + 0.4},   # (Thornburst hits each enemy once)
	# Nature healer: rooted creatures with ~2 Blossoms; Fawn with its bounces.
	"fawn": {"heal": 2.2 * (1.0 + 0.8 + 0.64 + 0.512)},
	"rootguard": {"heal": 1.76 + 0.88 * 2},
	"heartwoodelk": {"heal": (1.1 + 0.66 * 2) * 5.0},
	"wildherd": {"heal": 2.2 * (1.0 + 0.8 + 0.64 + 0.512) * 5.0},
	"owl": {"coef": 0.5, "heal": 2.2},
	# Nature tank: Sap healing is a separate source (self_heal), Heartsap at 5 Sap.
	"heartsap": {"self_heal_pct": 20.0},
	"stomp": {"coef": 0.8, "dot": 0.6, "dot_time": 6.0},
	"awaken": {"skip": true},
	# Nature archer: the poisons, and Venom Burst on a Steeped target with ~8 s of each left.
	"adderarrow": {"coef": 0.0, "dot": 2.4, "dot_time": 12.0},
	"asparrow": {"coef": 0.0, "dot": 1.2, "dot_time": 12.0},
	"kraitarrow": {"coef": 0.0, "dot": 0.8, "dot_time": 12.0},
	"venomburst": {"coef": (2.4 + 1.2 + 0.8) * (8.0 / 12.0) * 1.3 * 1.6},
	"spittingvolley": {"coef": 0.0, "dot": 2.4, "dot_time": 12.0},
	"bloatarrow": {"skip": true},
	"coilback": {"skip": true},
	"venomsurge": {"skip": true},
	# Martial tank: the Brawler. A strike every 1.0 s (the sim's GCD is 1.5 s: x1.5), each
	# with a third of an average chain move (~0.65); the moves have no buttons. One More
	# repeats an average move.
	"punch": {"coef": (0.3 + 0.65 / 3.0) * 1.5},
	"brawlkick": {"coef": (0.3 + 0.65 / 3.0) * 1.5},
	"elbow": {"coef": (0.3 + 0.65 / 3.0) * 1.5},
	"onemore": {"coef": 0.65},
	"catch": {"skip": true}, "toughitout": {"skip": true}, "comeon": {"skip": true}, "fightingstyle": {"skip": true},
	"rapidfists": {"skip": true}, "haymaker": {"skip": true}, "sweep": {"skip": true}, "roundhouse": {"skip": true},
	"clinch": {"skip": true}, "shakeoff": {"skip": true}, "turnitaround": {"skip": true}, "throw": {"skip": true},
	"takedown": {"skip": true},
	# Martial DPS: the Rogue. About half the fight is Kill windows (forms hit ~1.8x the
	# builder) and Flow averages ~3%: each builder is worth ~1.45x itself, plus the stuck
	# daggers it throws or rips out. The Kill forms have no buttons; Go In and the rest
	# only move damage around.
	"cut": {"coef": 0.55 * 1.45 + 0.1},
	"twinstab": {"coef": 1.0 * 1.45 + 0.5},
	"dartin": {"coef": 0.5 * 1.45 + 0.25},
	"kickoff": {"coef": 0.4 * 1.45 + 0.45},
	"whirl": {"coef": 0.35 * 1.45},
	"snatch": {"coef": 0.6},
	"goin": {"skip": true}, "hityourstride": {"skip": true}, "rollwithit": {"skip": true}, "closeitout": {"skip": true},
	"gut": {"skip": true}, "throughandthrough": {"skip": true}, "redwhirl": {"skip": true}, "backflip": {"skip": true},
	"drivethrough": {"skip": true},
	# Holy tank: Pour Out at 100 Incense; Absolve at 40.
	"pourout": {"coef": 0.03 * 100.0},
	"absolve": {"heal": 0.05 * 40.0 * 2.2},
}

## Abilities paid with something the data doesn't price (Venom): id -> its cost.
const VENOM_COSTS := {"venomburst": 50.0, "spittingvolley": 30.0, "bloatarrow": 40.0}
