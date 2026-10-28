extends RefCounted

# What the balance simulator (tools/balance_sim.gd) needs to know per spec that
# the ability data alone doesn't say: its role, and the payoff of abilities whose
# real value is worked out in player.gd from stacks / patches / Venom.
# Keep it short: one line per spec, overrides only where the data is wrong.

## Spec name (Abilities.SPECS) -> "dps", "tank", "healer" or "utility" (every book's
## "Utility" divider: no damage or healing to simulate, left out of the report).
## The game's own table: Abilities.SPEC_ROLES.
const ROLES := preload("res://scripts/abilities.gd").SPEC_ROLES
const B = preload("res://scripts/balance.gd")

## Spec name -> how it fights, where its abilities' tags say otherwise:
##   "kind": "caster" / "physical" (which gear profile), "weapon": "melee" / "ranged" / "" (auto-attacks).
const FIGHTS := {}

## Line of Light: prisms an average beam heal passes at optimal play, and what that
## makes of the heal (stronger for each, plus the light each stores, healed back on a shatter).
const PRISMS_ON_A_BEAM := 1.5
const PRISM_BEAM := (1.0 + B.PRISM_AMPLIFY_PCT / 100.0 * PRISMS_ON_A_BEAM) * (1.0 + B.PRISM_CHARGE_PCT / 100.0 * PRISMS_ON_A_BEAM)

## Ability id -> what one use is really worth, where its data doesn't say it:
##   "coef": direct damage (coefficient), "mult" / "plus": its own hit times this / plus this,
##   "dot": damage over time in all, "dot_time": its seconds,
##   "heal": heal (old Heal x REFERENCE_HEAL units, like Balance.HEALS),
##   "self_heal_pct": % of max health healed on yourself, "skip": not a damage / heal button.
##   "last": usable only in this last share of the fight (an execute below 20% health).
##   "every": at most once per this many seconds (a limit the data doesn't hold: a parry, one per ally).
const PAYOFF := {
	# Frost DPS: Frostbitten Steel (the sim's sword, 0.45). ~3 Glaze on each finisher; about
	# 2 Icebreakers in 5 land on a target Frozen by the 3rd Winter's Bite; Bitter Edge only
	# has a Frozen target about 40% of the time.
	"icebreaker": {"coef": 0.45 * (0.6 * 2.68 + 0.4 * 3.35) * (1.0 + 0.05 * 3.0)},
	"calving": {"coef": 0.45 * 1.34 * (1.0 + 0.15 * 3.0)},
	"bitteredge": {"coef": 0.45 * 1.07 * 0.4},
	"blackfrost": {"skip": true},
	# Frost tank: Glacier Wall. ~3 Ice Layers held for Rimequake and spent by Shattering Slam.
	"shatteringslam": {"coef": 0.45 * 1.9 + 0.2 * 3.0},
	"rimequake": {"coef": 0.65 * (1.0 + 0.1 * 3.0)},
	"coldshoulder": {"skip": true}, "hailcoat": {"skip": true}, "hardrime": {"skip": true}, "glacialbulwark": {"skip": true},
	# Fire DPS: Forge Heat. Fold Steel ~3.5 hits (Orange half the time); Red Edge ~4 swings in Orange; Blast Furnace is a cooldown.
	"foldsteel": {"coef": 0.64 * 3.5},
	"rededge": {"coef": 0.32 * 4.0 * 0.5},
	"blastfurnace": {"skip": true},
	# Fire archer: Pitch and Cinder. Touch Off Ignites ~3 layers at +50%; Brushfire is a cooldown.
	"touchoff": {"coef": 0.15 * 3.0 * 1.5},
	"brushfire": {"skip": true},
	# Fire tank: Slagforged. Forge Blow shatters ~5 Slag (0.25 each); Rivet and Molten Shell are utility.
	"forgeblow": {"coef": 0.25 * 5.0},
	"redhotrivet": {"skip": true}, "moltenshell": {"skip": true},
	# Nature caster: finishers at an average of 3 patches; Thornburst on the target once.
	"mossback": {"coef": B.ABILITIES["mossback"]["damage"] + B.MOSSBACK_PER_PATCH * 3},
	"chokingvipers": {"coef": 0.0, "dot": 0.4 + 0.4 * 3, "dot_time": 3.0},
	"thornshot": {"coef": B.ABILITIES["thornshot"]["damage"] + 0.4},   # (Thornburst hits each enemy once)
	# Nature healer: rooted creatures with ~2 Blossoms; Fawn with its bounces.
	"fawn": {"heal": B.HEALS["fawn"] * (1.0 + 0.8 + 0.64 + 0.512)},
	"rootguard": {"heal": B.HEALS["rootguard"] + 0.88 * 2},
	"heartwoodelk": {"heal": (B.HEALS["heartwoodelk"] + 0.66 * 2) * 5.0},
	"wildherd": {"heal": B.HEALS["fawn"] * (1.0 + 0.8 + 0.64 + 0.512) * 5.0},
	"owl": {"coef": 0.5, "heal": B.HEALS["owl"]},
	# Frost healer (Cold Comfort): Rime Veil refills four times over its time (counted as half used up);
	# Rimefall on 5 allies with 2 shells out; Break the Ice on 3 allies from a half-used shell;
	# Stillwater about 30% of a 2.5-Heal-sized health bar; Rime Shell's own shield plus its Rime Shards on 3.
	"rimeveil": {"heal": 0.44 * 5.0 * 0.5},
	"rimefall": {"heal": (0.66 + 0.22 * 2) * 5.0},
	"breaktheice": {"heal": 1.1 * 0.5 * 0.8 * 3.0},
	"stillwater": {"heal": 2.2 * 2.5 * 0.3},
	"frostlattice": {"skip": true}, "frosttide": {"skip": true},
	"rimeshell": {"heal": 1.1 + 1.1 * 0.3 * 3.0},
	# Nature tank: Sap healing is a separate source (self_heal), Heartsap at 5 Sap.
	"heartsap": {"self_heal_pct": 20.0},
	"stomp": {"coef": 0.8, "dot": 0.6, "dot_time": 6.0},
	"awaken": {"skip": true},
	# Nature archer: the poisons, and Venom Burst on a Steeped target with ~8 s of each left.
	"adderarrow": {"coef": 0.0, "dot": B.ADDER_DAMAGE, "dot_time": 12.0},
	"asparrow": {"coef": 0.0, "dot": B.ASP_DAMAGE, "dot_time": 12.0},
	"kraitarrow": {"coef": 0.0, "dot": B.KRAIT_DAMAGE, "dot_time": 12.0},
	"venomburst": {"coef": (B.ADDER_DAMAGE + B.ASP_DAMAGE + B.KRAIT_DAMAGE) * (8.0 / 12.0) * 1.3 * (1.0 + B.BURST_PER_POISON / 100.0 * 3.0)},
	"spittingvolley": {"coef": 0.0, "dot": B.ADDER_DAMAGE, "dot_time": 12.0},
	"bloatarrow": {"skip": true},
	"coilback": {"skip": true},
	"venomsurge": {"skip": true},
	# Martial tank: the Brawler. A strike every 1.0 s (the sim's GCD is 1.5 s: x1.5), each
	# with a third of an average chain move (~0.65); the moves have no buttons. One More
	# repeats an average move.
	"punch": {"coef": (0.27 + 0.65 / 3.0) * 1.5},
	"brawlkick": {"coef": (0.27 + 0.65 / 3.0) * 1.5},
	"elbow": {"coef": (0.27 + 0.65 / 3.0) * 1.5},
	"onemore": {"coef": 0.65},
	"catch": {"skip": true}, "toughitout": {"skip": true}, "comeon": {"skip": true}, "fightingstyle": {"skip": true},
	"rapidfists": {"skip": true}, "haymaker": {"skip": true}, "sweep": {"skip": true}, "roundhouse": {"skip": true},
	"clinch": {"skip": true}, "shakeoff": {"skip": true}, "turnitaround": {"skip": true}, "throw": {"skip": true},
	"takedown": {"skip": true},
	# Martial DPS: the Rogue. About half the fight is Kill windows (forms hit ~1.8x the
	# builder) and Flow averages ~3%: each builder is worth ~1.45x itself, plus the stuck
	# daggers it throws or rips out. The Kill forms have no buttons; Go In and the rest
	# only move damage around.
	"cut": {"coef": 0.62 * 1.45 + 0.1},
	"twinstab": {"coef": 1.12 * 1.45 + 0.5},
	"dartin": {"coef": 0.56 * 1.45 + 0.25},
	"kickoff": {"coef": 0.45 * 1.45 + 0.45},
	"whirl": {"coef": 0.39 * 1.45},
	"snatch": {"coef": 0.6},
	"goin": {"skip": true}, "hityourstride": {"skip": true}, "rollwithit": {"skip": true}, "closeitout": {"skip": true},
	"gut": {"skip": true}, "throughandthrough": {"skip": true}, "redwhirl": {"skip": true}, "backflip": {"skip": true},
	"drivethrough": {"skip": true},
	# Martial archer: Sharpshooter. Base cooldowns fill ~64% of GCDs; the cuts fill ~90%, so
	# each engine shot fires ~1.4x as often (folded in here), with ~20% Overcut and Streak ~6 (+12%).
	# Spread: 3 arrows; Follow Up: 2. Loose fills the gaps.
	"quickshot": {"coef": 0.56 * 1.85},
	"pierce": {"coef": 0.62 * 1.85},
	"spread": {"coef": 0.38 * 3.0 * 1.85},
	"heavydraw": {"coef": 1.62 * 1.85},
	"followup": {"coef": 0.28 * 2.0 * 1.85},
	"loose": {"coef": 0.31 * 1.12},
	"breathe": {"skip": true}, "fasthands": {"skip": true},
	# Holy healer (Choir of One): one Refrain running per ally, 5 allies.
	"refrain": {"every": B.REFRAIN_TIME / 5.0},
	# Shadow healer (Strings Attached): a String heals its whole time on an ally and is back
	# STRING_RECHARGE later, so all of them go out once per (time + recharge).
	"puppetstring": {"heal": B.STRING_HEAL * B.STRING_TIME / B.STRING_TICK,
		"every": (B.STRING_TIME + B.STRING_RECHARGE) / B.STRING_MAX},
	# Lightning tank: Return Stroke opens on a parry (about one every 3 s against one boss).
	"returnstroke": {"every": 3.0},
	# Holy tank: Pour Out at 100 Incense; Absolve at 40.
	"pourout": {"coef": 0.03 * 100.0},
	"absolve": {"heal": 0.05 * 40.0 * 2.2},
	# Arcane DPS (Clockwork): Sigil Darts is ARCANE_MISSILES_COUNT darts; Countdown adds a
	# share of what you deal meanwhile (Unravel back to back).
	"arcanemissiles": {"mult": B.ARCANE_MISSILES_COUNT},
	"countdown": {"plus": B.COUNTDOWN_SHARE_PCT / 100.0 * B.COUNTDOWN_TIME * B.ABILITIES["unravel"]["damage"] / B.ABILITIES["unravel"]["cast_time"]},
	# Arcane melee (Second Act): Late Cut hits twice.
	"latecut": {"mult": 2.0},
	# Shadow melee (Pack of Two): Both At Once adds each Hound's lunge.
	"bothatonce": {"plus": B.HOUND_LUNGE * B.HOUND_COUNT},
	# Holy healer (Line of Light): a beam heal at optimal play passes PRISMS_ON_A_BEAM
	# prisms, each making it stronger and storing a share as light that a shatter heals
	# back later (Shatter Prism / Shatter All themselves are counted here). Infuse fills one.
	"brightlance": {"heal": B.HEALS["brightlance"] * PRISM_BEAM},
	"gleam": {"heal": B.HEALS["gleam"] * PRISM_BEAM},
	"mendingray": {"heal": B.HEALS["mendingray"] * PRISM_BEAM},
	"prismward": {"heal": B.HEALS["prismward"] * PRISM_BEAM},
	"infuse": {"heal": B.PRISM_CAP_HEALS * B.REFERENCE_HEAL},
}

## Abilities paid with something the data doesn't price (Venom): id -> its cost.
const VENOM_COSTS := {"venomburst": 50.0, "spittingvolley": 30.0, "bloatarrow": 40.0}

## Specs the "weak" flag (balance_sim.gd WEAK_SHARE) skips: their buttons are
## alternatives the sim presses side by side but a player never would (The Wheel:
## each weapon's own moves; the Brawler: strikes that only differ in the chain).
## Healers too: their heals answer damage the sim doesn't make.
const NO_WEAK_CHECK := ["The Wheel", "Brawler"]
