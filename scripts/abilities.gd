extends RefCounted

# Ability database + shared action-slot UI (icons, tooltips).
# Usage: const Abilities = preload("res://scripts/abilities.gd")

const UI = preload("res://scripts/ui_kit.gd")

# Order here = order shown in the "unplaced abilities" list.
# Registry backed by AbilityData resources in res://data/abilities/.
const PATHS := {
	# Holy healer: the Hymns
	"psalm": "res://data/abilities/psalm.tres",
	"outpour": "res://data/abilities/outpour.tres",
	"lift": "res://data/abilities/lift.tres",
	"refrain": "res://data/abilities/refrain.tres",
	"canticle": "res://data/abilities/canticle.tres",
	"exultation": "res://data/abilities/exultation.tres",
	"antiphon": "res://data/abilities/antiphon.tres",
	"shelter": "res://data/abilities/shelter.tres",
	"steadyvoice": "res://data/abilities/steadyvoice.tres",
	"highnote": "res://data/abilities/highnote.tres",
	"reprise": "res://data/abilities/reprise.tres",
	"swell": "res://data/abilities/swell.tres",
	"rest": "res://data/abilities/rest.tres",
	"lastverse": "res://data/abilities/lastverse.tres",
	"singmercy": "res://data/abilities/singmercy.tres",
	"singchorus": "res://data/abilities/singchorus.tres",
	"singvigil": "res://data/abilities/singvigil.tres",
	# Holy tank: the Censer
	"censerswing": "res://data/abilities/censerswing.tres",
	"hallowedarc": "res://data/abilities/hallowedarc.tres",
	"beckon": "res://data/abilities/beckon.tres",
	"pourout": "res://data/abilities/pourout.tres",
	"absolve": "res://data/abilities/absolve.tres",
	"aureole": "res://data/abilities/aureole.tres",
	"gatherthelight": "res://data/abilities/gatherthelight.tres",
	"raisethecenser": "res://data/abilities/raisethecenser.tres",
	"unfallen": "res://data/abilities/unfallen.tres",
	# Holy healer #2: the Prisms
	"setprism": "res://data/abilities/setprism.tres",
	"moveprism": "res://data/abilities/moveprism.tres",
	"mendingray": "res://data/abilities/mendingray.tres",
	"brightlance": "res://data/abilities/brightlance.tres",
	"gleam": "res://data/abilities/gleam.tres",
	"prismward": "res://data/abilities/prismward.tres",
	"piercinglight": "res://data/abilities/piercinglight.tres",
	"realign": "res://data/abilities/realign.tres",
	"shatterprism": "res://data/abilities/shatterprism.tres",
	"shatterall": "res://data/abilities/shatterall.tres",
	"infuse": "res://data/abilities/infuse.tres",
	"kaleidoscope": "res://data/abilities/kaleidoscope.tres",
	# Holy archer: Lightstring
	"prismarrow": "res://data/abilities/prismarrow.tres",
	"glimmershot": "res://data/abilities/glimmershot.tres",
	"refractingshot": "res://data/abilities/refractingshot.tres",
	"sunlitarrow": "res://data/abilities/sunlitarrow.tres",
	"prismbreaker": "res://data/abilities/prismbreaker.tres",
	"stepoflight": "res://data/abilities/stepoflight.tres",
	"spectrumvolley": "res://data/abilities/spectrumvolley.tres",
	"frostbolt": "res://data/abilities/frostbolt.tres",
	"blizzard": "res://data/abilities/blizzard.tres",
	"auto_melee": "res://data/abilities/auto_melee.tres",
	"auto_ranged": "res://data/abilities/auto_ranged.tres",
	# Draftable (learned through the level-up draft)
	"frostnova": "res://data/abilities/frostnova.tres",
	"icebarrier": "res://data/abilities/icebarrier.tres",
	"blink": "res://data/abilities/blink.tres",
	"fireball": "res://data/abilities/fireball.tres",
	"searingstrike": "res://data/abilities/searingstrike.tres",
	"flamingarrow": "res://data/abilities/flamingarrow.tres",
	"flamenova": "res://data/abilities/flamenova.tres",
	"ventflames": "res://data/abilities/ventflames.tres",
	"coolhead": "res://data/abilities/coolhead.tres",
	"furnacebreath": "res://data/abilities/furnacebreath.tres",
	"slagskin": "res://data/abilities/slagskin.tres",
	"stoke": "res://data/abilities/stoke.tres",
	"embervolley": "res://data/abilities/embervolley.tres",
	"immolate": "res://data/abilities/immolate.tres",
	"walloffire": "res://data/abilities/walloffire.tres",
	"kilnblast": "res://data/abilities/kilnblast.tres",
	"slowfuse": "res://data/abilities/slowfuse.tres",
	"rekindle": "res://data/abilities/rekindle.tres",
	"crucible": "res://data/abilities/crucible.tres",
	"cinderstep": "res://data/abilities/cinderstep.tres",
	"heatsink": "res://data/abilities/heatsink.tres",
	"brand": "res://data/abilities/brand.tres",
	"cinderguard": "res://data/abilities/cinderguard.tres",
	"anvil": "res://data/abilities/anvil.tres",
	"quench": "res://data/abilities/quench.tres",
	"flare": "res://data/abilities/flare.tres",
	"pitcharrow": "res://data/abilities/pitcharrow.tres",
	"cinderrain": "res://data/abilities/cinderrain.tres",
	"cinderwing": "res://data/abilities/cinderwing.tres",
	# Taught by a rune (never drafted)
	"frostfirebolt": "res://data/abilities/frostfirebolt.tres",
	"chainlightning": "res://data/abilities/chainlightning.tres",
	"thunderstrike": "res://data/abilities/thunderstrike.tres",
	"stormarrow": "res://data/abilities/stormarrow.tres",
	"arcanemissiles": "res://data/abilities/arcanemissiles.tres",
	"glint": "res://data/abilities/glint.tres",
	"arcanestrike": "res://data/abilities/arcanestrike.tres",
	"arcaneshot": "res://data/abilities/arcaneshot.tres",
	"arcaneexplosion": "res://data/abilities/arcaneexplosion.tres",
	# Arcane caster: the cooldown kit (draftable)
	"unravel": "res://data/abilities/unravel.tres",
	"countdown": "res://data/abilities/countdown.tres",
	"convergence": "res://data/abilities/convergence.tres",
	"rewind": "res://data/abilities/rewind.tres",
	"lapse": "res://data/abilities/lapse.tres",
	"mirrorsigil": "res://data/abilities/mirrorsigil.tres",
	"collapse": "res://data/abilities/collapse.tres",
	"scatter": "res://data/abilities/scatter.tres",
	"intervalward": "res://data/abilities/intervalward.tres",
	# Arcane tank: a dodge tank with a melee weapon in each hand, on cooldowns
	# alone (draftable). It lives on Reflections: see player.gd, "Arcane tank".
	"doubleup": "res://data/abilities/doubleup.tres",
	"ripple": "res://data/abilities/ripple.tres",
	"fullset": "res://data/abilities/fullset.tres",
	"missedbeat": "res://data/abilities/missedbeat.tres",
	"standin": "res://data/abilities/standin.tres",
	"tradeplaces": "res://data/abilities/tradeplaces.tres",
	"crowdofone": "res://data/abilities/crowdofone.tres",
	"decoy": "res://data/abilities/decoy.tres",
	# Arcane melee: a damage dealer with a melee weapon in each hand, on cooldowns
	# alone (draftable). Its strikes leave Traces and Encore replays them: see
	# player.gd, "Arcane melee".
	"swiftcut": "res://data/abilities/swiftcut.tres",
	"deepcut": "res://data/abilities/deepcut.tres",
	"latecut": "res://data/abilities/latecut.tres",
	"encore": "res://data/abilities/encore.tres",
	"widecut": "res://data/abilities/widecut.tres",
	"doubletime": "res://data/abilities/doubletime.tres",
	# (Gloom Bolt, "shadowbolt", was removed: the Shadow book has no starting bolt.)
	"corruption": "res://data/abilities/corruption.tres",
	"shadowstrike": "res://data/abilities/shadowstrike.tres",
	"shadowarrow": "res://data/abilities/shadowarrow.tres",
	# Shadow melee: the Hounds, two demon dogs that fight beside you, on Fury
	# (draftable). See player.gd, "Shadow melee: the Hounds". Leeching Strike
	# ("shadowstrike") is the kit's seventh ability.
	"sic": "res://data/abilities/sic.tres",
	"openup": "res://data/abilities/openup.tres",
	"bothatonce": "res://data/abilities/bothatonce.tres",
	"runthemdown": "res://data/abilities/runthemdown.tres",
	"guarddogs": "res://data/abilities/guarddogs.tres",
	"offthechain": "res://data/abilities/offthechain.tres",
	"bringitdown": "res://data/abilities/bringitdown.tres",
	# Shadow healer: the Strings. A demon behind you holds allies up on Strings
	# that heal them (draftable). See player.gd, "Shadow healer: the Strings".
	"puppetstring": "res://data/abilities/puppetstring.tres",
	"patchup": "res://data/abilities/patchup.tres",
	"hoist": "res://data/abilities/hoist.tres",
	"tug": "res://data/abilities/tug.tres",
	"catscradle": "res://data/abilities/catscradle.tres",
	"wrench": "res://data/abilities/wrench.tres",
	"pulltaut": "res://data/abilities/pulltaut.tres",
	"cuppedhands": "res://data/abilities/cuppedhands.tres",
	"stringup": "res://data/abilities/stringup.tres",
	"restring": "res://data/abilities/restring.tres",
	"knot": "res://data/abilities/knot.tres",
	"tangle": "res://data/abilities/tangle.tres",
	"yank": "res://data/abilities/yank.tres",
	"doublethread": "res://data/abilities/doublethread.tres",
	"behinditsback": "res://data/abilities/behinditsback.tres",
	"slack": "res://data/abilities/slack.tres",
	"stillstanding": "res://data/abilities/stillstanding.tres",
	"cutthestrings": "res://data/abilities/cutthestrings.tres",
	"notfinished": "res://data/abilities/notfinished.tres",
	# Shadow caster: Decay, a damage over time effect kept as an amount (draftable).
	# Blight opens it, the others feed or use it: see player.gd, "Shadow caster: Decay".
	"blight": "res://data/abilities/blight.tres",
	"erode": "res://data/abilities/erode.tres",
	# (Usher In, "sinkin", was removed.)
	"calldue": "res://data/abilities/calldue.tres",
	"gnaw": "res://data/abilities/gnaw.tres",
	"spill": "res://data/abilities/spill.tres",
	"pall": "res://data/abilities/pall.tres",
	"hush": "res://data/abilities/hush.tres",
	"takeitback": "res://data/abilities/takeitback.tres",
	"bottomless": "res://data/abilities/bottomless.tres",
	"froststrike": "res://data/abilities/froststrike.tres",
	"frostarrow": "res://data/abilities/frostarrow.tres",
	"thornshot": "res://data/abilities/thornshot.tres",
	"briartiger": "res://data/abilities/briartiger.tres",
	"mossback": "res://data/abilities/mossback.tres",
	"thornwing": "res://data/abilities/thornwing.tres",
	"chokingvipers": "res://data/abilities/chokingvipers.tres",
	"greenwoodstag": "res://data/abilities/greenwoodstag.tres",
	# Nature healer: the Shepherd
	"dewfall": "res://data/abilities/dewfall.tres",
	"fawn": "res://data/abilities/fawn.tres",
	"rootguard": "res://data/abilities/rootguard.tres",
	"owl": "res://data/abilities/owl.tres",
	"heartwoodelk": "res://data/abilities/heartwoodelk.tres",
	"wildherd": "res://data/abilities/wildherd.tres",
	# Nature tank: the Colossus
	"vinefist": "res://data/abilities/vinefist.tres",
	"grasp": "res://data/abilities/grasp.tres",
	"stomp": "res://data/abilities/stomp.tres",
	"giantshands": "res://data/abilities/giantshands.tres",
	"heartsap": "res://data/abilities/heartsap.tres",
	"awaken": "res://data/abilities/awaken.tres",
	# Nature archer: Venomstring
	"fangarrow": "res://data/abilities/fangarrow.tres",
	"adderarrow": "res://data/abilities/adderarrow.tres",
	"asparrow": "res://data/abilities/asparrow.tres",
	"kraitarrow": "res://data/abilities/kraitarrow.tres",
	"venomburst": "res://data/abilities/venomburst.tres",
	"spittingvolley": "res://data/abilities/spittingvolley.tres",
	"bloatarrow": "res://data/abilities/bloatarrow.tres",
	"coilback": "res://data/abilities/coilback.tres",
	"venomsurge": "res://data/abilities/venomsurge.tres",
	# Healers' out-of-combat rez (scripts/player/rez.gd)
	"hymnofwaking": "res://data/abilities/hymnofwaking.tres",
	"relight": "res://data/abilities/relight.tres",
	"backonyourfeet": "res://data/abilities/backonyourfeet.tres",
	"returntobloom": "res://data/abilities/returntobloom.tres",
	# Utility: each book's "Utility" divider (scripts/player/utility.gd)
	"rootsnare": "res://data/abilities/rootsnare.tres",
	"deeproots": "res://data/abilities/deeproots.tres",
	"sporesleep": "res://data/abilities/sporesleep.tres",
	"leafcloak": "res://data/abilities/leafcloak.tres",
	"coolingslag": "res://data/abilities/coolingslag.tres",
	"staticsnare": "res://data/abilities/staticsnare.tres",
	"fixedpoint": "res://data/abilities/fixedpoint.tres",
	"bindingring": "res://data/abilities/bindingring.tres",
	"bellows": "res://data/abilities/bellows.tres",
	"stormfront": "res://data/abilities/stormfront.tres",
	"circleofsilence": "res://data/abilities/circleofsilence.tres",
	"climbthestring": "res://data/abilities/climbthestring.tres",
	# Lightning tank: a parry tank with a two-handed weapon (draftable). Stormbreak
	# ("stormshield") and Humming Blade ("thunderaegis") keep the ids they had as
	# the shield abilities Stormshield Slam and Aegis of Thunder.
	"stormshield": "res://data/abilities/stormshield.tres",
	"thunderaegis": "res://data/abilities/thunderaegis.tres",
	"returnstroke": "res://data/abilities/returnstroke.tres",
	"shockring": "res://data/abilities/shockring.tres",
	"crossguard": "res://data/abilities/crossguard.tres",
	"drawthestorm": "res://data/abilities/drawthestorm.tres",
	"reelin": "res://data/abilities/reelin.tres",
	"recharge": "res://data/abilities/recharge.tres",
	# Lightning caster: the Energy kit (draftable)
	"discharge": "res://data/abilities/discharge.tres",
	"balllightning": "res://data/abilities/balllightning.tres",
	"groundout": "res://data/abilities/groundout.tres",
	"groundingsurge": "res://data/abilities/groundingsurge.tres",
	"arcflash": "res://data/abilities/arcflash.tres",
	"livewire": "res://data/abilities/livewire.tres",
	"thunderhead": "res://data/abilities/thunderhead.tres",
	"forkedbolt": "res://data/abilities/forkedbolt.tres",
	"jolt": "res://data/abilities/jolt.tres",
	"flicker": "res://data/abilities/flicker.tres",
	"capacitor": "res://data/abilities/capacitor.tres",
	# Lightning melee: Energy with a weapon (draftable)
	"chargededge": "res://data/abilities/chargededge.tres",
	"arccleave": "res://data/abilities/arccleave.tres",
	"overdrive": "res://data/abilities/overdrive.tres",
	"twincurrent": "res://data/abilities/twincurrent.tres",
	"staticstep": "res://data/abilities/staticstep.tres",
	"backcurrent": "res://data/abilities/backcurrent.tres",
	"cadence": "res://data/abilities/cadence.tres",
	"splitsecond": "res://data/abilities/splitsecond.tres",
	"whiplash": "res://data/abilities/whiplash.tres",
	"faradayguard": "res://data/abilities/faradayguard.tres",
	"reflexarc": "res://data/abilities/reflexarc.tres",
	# Taught by the Rune of Polarity (never drafted)
	"polarstrike": "res://data/abilities/polarstrike.tres",
	# Action-bar buttons that fire the Use: effect of the equipped trinkets
	# Baseline kit for every character (elemental bolts, heal)
	"lightningbolt": "res://data/abilities/lightningbolt.tres",
	# Frost: Rime Shell kit (draftable)
	"rimeshell": "res://data/abilities/rimeshell.tres",
	"meltwater": "res://data/abilities/meltwater.tres",
	"rimeveil": "res://data/abilities/rimeveil.tres",
	"breaktheice": "res://data/abilities/breaktheice.tres",
	"frostlattice": "res://data/abilities/frostlattice.tres",
	"rimefall": "res://data/abilities/rimefall.tres",
	"frosttide": "res://data/abilities/frosttide.tres",
	"stillwater": "res://data/abilities/stillwater.tres",
	"springthaw": "res://data/abilities/springthaw.tres",
	"shatteringwave": "res://data/abilities/shatteringwave.tres",
	"flashfreeze": "res://data/abilities/flashfreeze.tres",
	"hoarfrost": "res://data/abilities/hoarfrost.tres",
	"shatteringslam": "res://data/abilities/shatteringslam.tres",
	"rimeslash": "res://data/abilities/rimeslash.tres",
	"iceshards": "res://data/abilities/iceshards.tres",
	# Frost, second batch (draftable)
	"coldspike": "res://data/abilities/coldspike.tres",
	"sleetwave": "res://data/abilities/sleetwave.tres",
	"deepwinter": "res://data/abilities/deepwinter.tres",
	"rimelock": "res://data/abilities/rimelock.tres",
	"snowward": "res://data/abilities/snowward.tres",
	"winterhide": "res://data/abilities/winterhide.tres",
	"rimeedge": "res://data/abilities/rimeedge.tres",
	"icebreaker": "res://data/abilities/icebreaker.tres",
	"icepin": "res://data/abilities/icepin.tres",
	# Frost tank (Glacier Wall) and Frost DPS (Frostbitten Steel)
	"coldshoulder": "res://data/abilities/coldshoulder.tres",
	"rimequake": "res://data/abilities/rimequake.tres",
	"hailcoat": "res://data/abilities/hailcoat.tres",
	"hardrime": "res://data/abilities/hardrime.tres",
	"glacialbulwark": "res://data/abilities/glacialbulwark.tres",
	"hoarcleave": "res://data/abilities/hoarcleave.tres",
	"calving": "res://data/abilities/calving.tres",
	"bitteredge": "res://data/abilities/bitteredge.tres",
	"blackfrost": "res://data/abilities/blackfrost.tres",
	# Frost, the bow: a finisher, a cast shot, an auto-shot buff, a mark and a leap back
	"shattershot": "res://data/abilities/shattershot.tres",
	"glacialdraw": "res://data/abilities/glacialdraw.tres",
	"rimefletch": "res://data/abilities/rimefletch.tres",
	"coldmark": "res://data/abilities/coldmark.tres",
	"icyretreat": "res://data/abilities/icyretreat.tres",
	"trinket_1": "res://data/abilities/trinket_1.tres",
	"trinket_2": "res://data/abilities/trinket_2.tres",
	# Interrupts (draftable): stop an enemy's cast and lock it out of casting
	"counterspell": "res://data/abilities/counterspell.tres",
	# Martial warrior: the Wheel (four weapons, the four bar buttons, each weapon's four moves)
	"wheelgreataxe": "res://data/abilities/wheelgreataxe.tres",
	"wheelgreatsword": "res://data/abilities/wheelgreatsword.tres",
	"wheelhalberd": "res://data/abilities/wheelhalberd.tres",
	"wheelmaul": "res://data/abilities/wheelmaul.tres",
	"quickswing": "res://data/abilities/quickswing.tres",
	"fullswing": "res://data/abilities/fullswing.tres",
	"weaponart": "res://data/abilities/weaponart.tres",
	"wheelbreak": "res://data/abilities/wheelbreak.tres",
	"hack": "res://data/abilities/hack.tres",
	"chop": "res://data/abilities/chop.tres",
	"rush": "res://data/abilities/rush.tres",
	"shrapnel": "res://data/abilities/shrapnel.tres",
	"slash": "res://data/abilities/slash.tres",
	"lunge": "res://data/abilities/lunge.tres",
	"bladeguard": "res://data/abilities/bladeguard.tres",
	"shardlance": "res://data/abilities/shardlance.tres",
	"jab": "res://data/abilities/jab.tres",
	"hook": "res://data/abilities/hook.tres",
	"dragin": "res://data/abilities/dragin.tres",
	"flyinghead": "res://data/abilities/flyinghead.tres",
	"thud": "res://data/abilities/thud.tres",
	"crush": "res://data/abilities/crush.tres",
	"earthshake": "res://data/abilities/earthshake.tres",
	"faultline": "res://data/abilities/faultline.tres",
	# Martial tank: the Brawler (the strikes, Catch, the chain's moves, the rest)
	"punch": "res://data/abilities/punch.tres",
	"brawlkick": "res://data/abilities/brawlkick.tres",
	"elbow": "res://data/abilities/elbow.tres",
	"catch": "res://data/abilities/catch.tres",
	"rapidfists": "res://data/abilities/rapidfists.tres",
	"haymaker": "res://data/abilities/haymaker.tres",
	"sweep": "res://data/abilities/sweep.tres",
	"roundhouse": "res://data/abilities/roundhouse.tres",
	"clinch": "res://data/abilities/clinch.tres",
	"shakeoff": "res://data/abilities/shakeoff.tres",
	"turnitaround": "res://data/abilities/turnitaround.tres",
	"throw": "res://data/abilities/throw.tres",
	"takedown": "res://data/abilities/takedown.tres",
	"onemore": "res://data/abilities/onemore.tres",
	"toughitout": "res://data/abilities/toughitout.tres",
	"comeon": "res://data/abilities/comeon.tres",
	"fightingstyle": "res://data/abilities/fightingstyle.tres",
	# Martial DPS: the Rogue (the builders, the Kill, the Kill forms) and Martial Utility
	"cut": "res://data/abilities/cut.tres",
	"whirl": "res://data/abilities/whirl.tres",
	"dartin": "res://data/abilities/dartin.tres",
	"kickoff": "res://data/abilities/kickoff.tres",
	"twinstab": "res://data/abilities/twinstab.tres",
	"goin": "res://data/abilities/goin.tres",
	"closeitout": "res://data/abilities/closeitout.tres",
	"hityourstride": "res://data/abilities/hityourstride.tres",
	"rollwithit": "res://data/abilities/rollwithit.tres",
	"snatch": "res://data/abilities/snatch.tres",
	"gut": "res://data/abilities/gut.tres",
	"throughandthrough": "res://data/abilities/throughandthrough.tres",
	"redwhirl": "res://data/abilities/redwhirl.tres",
	"backflip": "res://data/abilities/backflip.tres",
	"drivethrough": "res://data/abilities/drivethrough.tres",
	"pintheshadow": "res://data/abilities/pintheshadow.tres",
	"overtheshoulder": "res://data/abilities/overtheshoulder.tres",
	"playdead": "res://data/abilities/playdead.tres",
	# Martial archer: Sharpshooter (the shots that cut each other's cooldowns)
	"quickshot": "res://data/abilities/quickshot.tres",
	"pierce": "res://data/abilities/pierce.tres",
	"spread": "res://data/abilities/spread.tres",
	"heavydraw": "res://data/abilities/heavydraw.tres",
	"followup": "res://data/abilities/followup.tres",
	"loose": "res://data/abilities/loose.tres",
	"breathe": "res://data/abilities/breathe.tres",
	"fasthands": "res://data/abilities/fasthands.tres",
}
## Always available (everything the player had before the draft existed).
## Includes a basic spell of every element and a heal, so a fresh (level 1 /
## just died) character can always do something. (The Martial basics were wiped with the book.)
const BASE := ["frostbolt", "fireball", "lightningbolt", "psalm",
	"blizzard",
	"trinket_1", "trinket_2"]
## Trinket bar buttons -> the equipment slot whose Use: effect they fire.
const TRINKET_SLOTS := {"trinket_1": "Trinket 1", "trinket_2": "Trinket 2"}

static func is_trinket_slot(id: String) -> bool:
	return TRINKET_SLOTS.has(id)
## Offered by the level-up draft; learned permanently when picked.
const DRAFT_POOL := ["frostnova", "icebarrier", "blink",
	"rimeshell", "meltwater", "rimeveil", "breaktheice", "frostlattice", "rimefall", "frosttide", "stillwater", "springthaw",
	"shatteringwave", "flashfreeze", "hoarfrost", "shatteringslam", "rimeslash", "iceshards",
	"coldspike", "sleetwave", "deepwinter", "rimelock", "snowward", "winterhide", "rimeedge", "icebreaker", "icepin",
	"coldshoulder", "rimequake", "hailcoat", "hardrime", "glacialbulwark", "hoarcleave", "calving", "bitteredge", "blackfrost",
	"shattershot", "glacialdraw", "rimefletch", "coldmark", "icyretreat",
	"searingstrike", "flamingarrow", "flamenova", "ventflames", "coolhead", "furnacebreath", "slagskin",
	"stoke", "embervolley", "immolate", "walloffire",
	"kilnblast", "slowfuse", "rekindle",
	"crucible", "cinderstep", "heatsink", "brand", "cinderguard", "anvil", "quench", "flare",
	"pitcharrow", "cinderrain", "cinderwing",
	"chainlightning", "thunderstrike", "stormarrow",
	"discharge", "balllightning", "groundout", "groundingsurge",
	"arcflash", "livewire", "thunderhead", "forkedbolt", "jolt", "flicker", "capacitor",
	"chargededge", "arccleave", "overdrive", "twincurrent", "staticstep", "backcurrent", "cadence",
	"splitsecond", "whiplash", "faradayguard", "reflexarc",
	"arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion",
	"unravel", "countdown", "convergence", "rewind", "lapse", "mirrorsigil", "collapse", "scatter", "intervalward", "glint",
	"doubleup", "ripple", "fullset", "missedbeat", "standin", "tradeplaces", "crowdofone", "decoy",
	"swiftcut", "deepcut", "latecut", "encore", "widecut", "doubletime",
	"corruption", "shadowstrike", "shadowarrow",
	"blight", "erode", "calldue", "gnaw", "spill", "pall", "hush", "takeitback", "bottomless",
	"sic", "openup", "bothatonce", "runthemdown", "guarddogs", "bringitdown", "offthechain",
	"puppetstring", "patchup", "hoist", "tug", "catscradle", "wrench", "pulltaut", "cuppedhands", "stringup", "restring",
	"knot", "tangle", "yank", "doublethread", "behinditsback", "slack", "stillstanding", "cutthestrings", "notfinished", "backonyourfeet",
	"froststrike", "frostarrow",
	"outpour", "lift", "refrain", "canticle", "exultation", "antiphon", "shelter", "steadyvoice", "highnote",
	"reprise", "swell", "rest", "lastverse", "hymnofwaking", "singmercy", "singchorus", "singvigil",
	"censerswing", "hallowedarc", "beckon", "pourout", "absolve", "aureole", "gatherthelight", "raisethecenser", "unfallen",
	"setprism", "moveprism", "mendingray", "brightlance", "gleam", "prismward", "piercinglight", "realign", "shatterprism", "shatterall", "infuse", "kaleidoscope", "relight",
	"prismarrow", "glimmershot", "refractingshot", "sunlitarrow", "prismbreaker", "stepoflight", "spectrumvolley",
	"thornshot", "briartiger", "mossback", "thornwing", "chokingvipers", "greenwoodstag",
	"dewfall", "fawn", "rootguard", "owl", "heartwoodelk", "wildherd", "returntobloom",
	"rootsnare", "deeproots", "sporesleep", "leafcloak", "coolingslag", "bellows", "staticsnare", "stormfront", "fixedpoint", "bindingring", "circleofsilence", "climbthestring",
	"vinefist", "grasp", "stomp", "giantshands", "heartsap", "awaken",
	"fangarrow", "adderarrow", "asparrow", "kraitarrow", "venomburst", "spittingvolley", "bloatarrow", "coilback", "venomsurge",
	"stormshield", "thunderaegis",
	"returnstroke", "shockring", "crossguard", "drawthestorm", "reelin", "recharge",
	"wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul",
	"punch", "catch", "comeon", "toughitout", "onemore",
	"cut", "whirl", "dartin", "kickoff", "twinstab", "closeitout", "rollwithit", "hityourstride", "snatch",
	"pintheshadow", "overtheshoulder", "playdead",
	"quickshot", "pierce", "spread", "heavydraw", "followup", "breathe", "fasthands",
	"counterspell"]
# Every ability that can go on the action bar (order = list order).
const ALL := ["frostbolt", "blizzard", "frostnova", "icebarrier",
	"rimeshell", "meltwater", "rimeveil", "breaktheice", "frostlattice", "rimefall", "frosttide", "stillwater", "springthaw",
	"shatteringwave", "flashfreeze", "hoarfrost", "shatteringslam", "rimeslash", "iceshards",
	"froststrike", "frostarrow",
	"coldspike", "sleetwave", "deepwinter", "rimelock", "snowward", "winterhide", "rimeedge", "icebreaker", "icepin",
	"coldshoulder", "rimequake", "hailcoat", "hardrime", "glacialbulwark", "hoarcleave", "calving", "bitteredge", "blackfrost",
	"shattershot", "glacialdraw", "rimefletch", "coldmark", "icyretreat",
	"fireball", "searingstrike", "flamingarrow", "flamenova", "ventflames", "coolhead", "furnacebreath", "slagskin",
	"stoke", "embervolley", "immolate", "walloffire",
	"kilnblast", "slowfuse", "rekindle",
	"crucible", "cinderstep", "heatsink", "brand", "cinderguard", "anvil", "quench", "flare",
	"pitcharrow", "cinderrain", "cinderwing",
	"lightningbolt", "chainlightning", "discharge", "balllightning", "groundout", "groundingsurge",
	"forkedbolt", "arcflash", "livewire", "thunderhead", "jolt", "flicker", "capacitor",
	"thunderstrike", "chargededge", "whiplash", "arccleave", "cadence", "twincurrent", "staticstep",
	"backcurrent", "overdrive", "reflexarc", "faradayguard", "splitsecond",
	"stormarrow", "stormshield", "returnstroke", "shockring", "reelin", "thunderaegis", "recharge", "crossguard", "drawthestorm",
	"blink", "arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion", "counterspell",
	"unravel", "glint", "scatter", "countdown", "collapse", "intervalward", "convergence", "mirrorsigil", "rewind", "lapse",
	"doubleup", "ripple", "missedbeat", "fullset", "standin", "tradeplaces", "decoy", "crowdofone",
	"swiftcut", "deepcut", "encore", "latecut", "widecut", "doubletime",
	"corruption",
	"blight", "erode", "gnaw", "calldue", "spill", "pall", "hush", "takeitback", "bottomless",
	"shadowstrike", "sic", "openup", "bothatonce", "runthemdown", "guarddogs", "bringitdown", "offthechain",
	"shadowarrow",
	"puppetstring", "patchup", "hoist", "tug", "catscradle", "wrench", "pulltaut", "cuppedhands", "stringup", "restring",
	"knot", "tangle", "yank", "doublethread", "behinditsback", "slack", "stillstanding", "cutthestrings", "notfinished", "backonyourfeet",
	"thornshot", "briartiger", "mossback", "thornwing", "chokingvipers", "greenwoodstag",
	"dewfall", "fawn", "rootguard", "owl", "heartwoodelk", "wildherd", "returntobloom",
	"rootsnare", "deeproots", "sporesleep", "leafcloak", "coolingslag", "bellows", "staticsnare", "stormfront", "fixedpoint", "bindingring", "circleofsilence", "climbthestring",
	"vinefist", "grasp", "stomp", "giantshands", "heartsap", "awaken",
	"fangarrow", "adderarrow", "asparrow", "kraitarrow", "venomburst", "spittingvolley", "bloatarrow", "coilback", "venomsurge",
	"psalm", "outpour", "lift", "refrain", "canticle", "exultation", "antiphon", "shelter", "steadyvoice", "highnote",
	"singmercy", "singchorus", "singvigil", "reprise", "swell", "rest", "lastverse", "hymnofwaking",
	"censerswing", "hallowedarc", "beckon", "pourout", "absolve", "aureole", "gatherthelight", "raisethecenser", "unfallen",
	"setprism", "moveprism", "mendingray", "brightlance", "gleam", "prismward", "piercinglight", "realign", "shatterprism", "shatterall", "infuse", "kaleidoscope", "relight",
	"prismarrow", "glimmershot", "refractingshot", "sunlitarrow", "prismbreaker", "stepoflight", "spectrumvolley",
	"frostfirebolt", "polarstrike",
	"wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul", "quickswing", "fullswing", "weaponart", "wheelbreak",
	"hack", "chop", "rush", "shrapnel", "slash", "lunge", "bladeguard", "shardlance",
	"jab", "hook", "dragin", "flyinghead", "thud", "crush", "earthshake", "faultline",
	"punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle",
	"rapidfists", "haymaker", "sweep", "roundhouse", "clinch", "shakeoff", "turnitaround", "throw", "takedown",
	"cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride", "rollwithit", "snatch",
	"gut", "throughandthrough", "redwhirl", "backflip", "drivethrough",
	"pintheshadow", "overtheshoulder", "playdead",
	"quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands",
	"trinket_1", "trinket_2"]
## Category (book) each ability belongs to — see categories.gd.
const CATEGORY_OF := {
	"frostbolt": "frost", "blizzard": "frost", "hoarfrost": "frost", "shatteringslam": "frost", "rimeslash": "frost",
	"frostnova": "frost", "icebarrier": "frost", "froststrike": "frost", "frostarrow": "frost",
	"rimeshell": "frost", "shatteringwave": "frost", "flashfreeze": "frost", "iceshards": "frost",
	"meltwater": "frost", "rimeveil": "frost", "breaktheice": "frost", "frostlattice": "frost", "rimefall": "frost", "frosttide": "frost", "stillwater": "frost", "springthaw": "frost",
	"coldspike": "frost", "sleetwave": "frost", "deepwinter": "frost", "rimelock": "frost", "snowward": "frost",
	"winterhide": "frost", "rimeedge": "frost", "icebreaker": "frost", "icepin": "frost",
	"shattershot": "frost", "glacialdraw": "frost", "rimefletch": "frost", "coldmark": "frost", "icyretreat": "frost",
	"coldshoulder": "frost", "rimequake": "frost", "hailcoat": "frost", "hardrime": "frost", "glacialbulwark": "frost", "hoarcleave": "frost", "calving": "frost", "bitteredge": "frost", "blackfrost": "frost",
	"lightningbolt": "lightning",
	"fireball": "fire", "searingstrike": "fire", "flamingarrow": "fire", "flamenova": "fire",
	"ventflames": "fire", "coolhead": "fire", "furnacebreath": "fire", "slagskin": "fire",
	"stoke": "fire", "embervolley": "fire", "immolate": "fire", "walloffire": "fire",
	"kilnblast": "fire", "slowfuse": "fire", "rekindle": "fire",
	"crucible": "fire", "cinderstep": "fire", "heatsink": "fire",
	"brand": "fire", "cinderguard": "fire", "anvil": "fire", "quench": "fire", "flare": "fire",
	"pitcharrow": "fire", "cinderrain": "fire", "cinderwing": "fire",
	"chainlightning": "lightning", "thunderstrike": "lightning", "stormarrow": "lightning",
	"discharge": "lightning", "balllightning": "lightning", "groundout": "lightning", "groundingsurge": "lightning",
	"arcflash": "lightning", "livewire": "lightning", "thunderhead": "lightning", "forkedbolt": "lightning",
	"jolt": "lightning", "flicker": "lightning", "capacitor": "lightning",
	"chargededge": "lightning", "arccleave": "lightning", "overdrive": "lightning", "twincurrent": "lightning",
	"staticstep": "lightning", "backcurrent": "lightning", "cadence": "lightning", "splitsecond": "lightning",
	"whiplash": "lightning", "faradayguard": "lightning", "reflexarc": "lightning",
	"blink": "arcane", "arcanemissiles": "arcane", "arcanestrike": "arcane", "arcaneshot": "arcane",
	"arcaneexplosion": "arcane",
	"unravel": "arcane", "countdown": "arcane", "convergence": "arcane", "rewind": "arcane", "lapse": "arcane",
	"mirrorsigil": "arcane", "collapse": "arcane", "scatter": "arcane", "intervalward": "arcane", "glint": "arcane",
	"doubleup": "arcane", "ripple": "arcane", "fullset": "arcane", "missedbeat": "arcane",
	"standin": "arcane", "tradeplaces": "arcane", "crowdofone": "arcane", "decoy": "arcane",
	"swiftcut": "arcane", "deepcut": "arcane", "latecut": "arcane", "encore": "arcane",
	"widecut": "arcane", "doubletime": "arcane",
	"corruption": "shadow", "shadowstrike": "shadow", "shadowarrow": "shadow",
	"blight": "shadow", "erode": "shadow", "calldue": "shadow", "gnaw": "shadow",
	"spill": "shadow", "pall": "shadow", "hush": "shadow", "takeitback": "shadow", "bottomless": "shadow",
	"sic": "shadow", "openup": "shadow", "bothatonce": "shadow", "runthemdown": "shadow",
	"guarddogs": "shadow", "offthechain": "shadow", "bringitdown": "shadow",
	"puppetstring": "shadow", "patchup": "shadow", "hoist": "shadow", "tug": "shadow", "catscradle": "shadow",
	"wrench": "shadow", "pulltaut": "shadow", "cuppedhands": "shadow", "stringup": "shadow", "restring": "shadow",
	"knot": "shadow", "tangle": "shadow", "yank": "shadow", "doublethread": "shadow", "behinditsback": "shadow",
	"slack": "shadow", "stillstanding": "shadow", "cutthestrings": "shadow", "notfinished": "shadow", "backonyourfeet": "shadow",
	"thornshot": "nature", "briartiger": "nature", "mossback": "nature", "thornwing": "nature", "chokingvipers": "nature", "greenwoodstag": "nature",
	"dewfall": "nature", "fawn": "nature", "rootguard": "nature", "owl": "nature", "heartwoodelk": "nature", "wildherd": "nature", "returntobloom": "nature",
	"vinefist": "nature", "grasp": "nature", "stomp": "nature", "giantshands": "nature", "heartsap": "nature", "awaken": "nature",
	"fangarrow": "nature", "adderarrow": "nature", "asparrow": "nature", "kraitarrow": "nature", "venomburst": "nature",
	"spittingvolley": "nature", "bloatarrow": "nature", "coilback": "nature", "venomsurge": "nature",
	"stormshield": "lightning", "thunderaegis": "lightning",
	"returnstroke": "lightning", "shockring": "lightning", "crossguard": "lightning", "drawthestorm": "lightning",
	"reelin": "lightning", "recharge": "lightning",
	"counterspell": "arcane",
	"psalm": "holy", "outpour": "holy", "lift": "holy", "refrain": "holy", "canticle": "holy", "exultation": "holy",
	"antiphon": "holy", "shelter": "holy", "steadyvoice": "holy", "highnote": "holy", "reprise": "holy", "swell": "holy",
	"rest": "holy", "lastverse": "holy", "hymnofwaking": "holy", "singmercy": "holy", "singchorus": "holy", "singvigil": "holy",
	"censerswing": "holy", "hallowedarc": "holy", "beckon": "holy", "pourout": "holy", "absolve": "holy", "aureole": "holy",
	"gatherthelight": "holy", "raisethecenser": "holy", "unfallen": "holy",
	"setprism": "holy", "moveprism": "holy", "mendingray": "holy", "brightlance": "holy", "gleam": "holy", "prismward": "holy",
	"piercinglight": "holy", "realign": "holy", "shatterprism": "holy", "shatterall": "holy", "infuse": "holy", "kaleidoscope": "holy", "relight": "holy",
	"prismarrow": "holy", "glimmershot": "holy", "refractingshot": "holy", "sunlitarrow": "holy", "prismbreaker": "holy",
	"stepoflight": "holy", "spectrumvolley": "holy",
	"rootsnare": "nature", "deeproots": "nature", "sporesleep": "nature", "leafcloak": "nature",
	"coolingslag": "fire", "bellows": "fire", "staticsnare": "lightning", "stormfront": "lightning", "fixedpoint": "arcane",
	"bindingring": "holy", "circleofsilence": "holy", "climbthestring": "shadow",
	"frostfirebolt": "rune", "polarstrike": "rune",
	"wheelgreataxe": "martial", "wheelgreatsword": "martial", "wheelhalberd": "martial", "wheelmaul": "martial",
	"quickswing": "martial", "fullswing": "martial", "weaponart": "martial", "wheelbreak": "martial",
	"hack": "martial", "chop": "martial", "rush": "martial", "shrapnel": "martial",
	"slash": "martial", "lunge": "martial", "bladeguard": "martial", "shardlance": "martial",
	"jab": "martial", "hook": "martial", "dragin": "martial", "flyinghead": "martial",
	"thud": "martial", "crush": "martial", "earthshake": "martial", "faultline": "martial",
	"punch": "martial", "brawlkick": "martial", "elbow": "martial", "catch": "martial", "onemore": "martial",
	"toughitout": "martial", "comeon": "martial", "fightingstyle": "martial",
	"rapidfists": "martial", "haymaker": "martial", "sweep": "martial", "roundhouse": "martial", "clinch": "martial",
	"shakeoff": "martial", "turnitaround": "martial", "throw": "martial", "takedown": "martial",
	"cut": "martial", "whirl": "martial", "dartin": "martial", "kickoff": "martial", "twinstab": "martial",
	"goin": "martial", "closeitout": "martial", "hityourstride": "martial", "rollwithit": "martial", "snatch": "martial",
	"gut": "martial", "throughandthrough": "martial", "redwhirl": "martial", "backflip": "martial", "drivethrough": "martial",
	"pintheshadow": "martial", "overtheshoulder": "martial", "playdead": "martial",
	"quickshot": "martial", "pierce": "martial", "spread": "martial", "heavydraw": "martial", "followup": "martial", "loose": "martial",
	"breathe": "martial", "fasthands": "martial",
}

## Abilities that ARE other abilities too: whatever names the base ability
## (talents, runes, procs) also applies to these. Frostfire Bolt is both a
## Frost Bolt and a Firebolt.
const COUNTS_AS := {"frostfirebolt": ["frostbolt", "fireball"]}

## Is ability `id` a `base` (the ability itself, or one that counts as it)?
static func is_a(id: String, base: String) -> bool:
	return id == base or (COUNTS_AS.has(id) and (COUNTS_AS[id] as Array).has(base))

## Icon shape for abilities without a hand-drawn icon (drawn in the book's color).
const ICON_FORM := {
	"fireball": "orb", "searingstrike": "blade", "flamingarrow": "arrow", "flamenova": "nova",
	"chainlightning": "zap", "thunderstrike": "blade", "stormarrow": "arrow",
	"arcanemissiles": "missiles", "arcanestrike": "blade", "arcaneshot": "arrow", "arcaneexplosion": "nova",
	"corruption": "swirl", "shadowstrike": "blade", "shadowarrow": "arrow",
	"froststrike": "blade", "frostarrow": "arrow",
	"lightningbolt": "zap",
	"rimeshell": "shield", "shatteringwave": "nova", "flashfreeze": "missiles",
	"hoarfrost": "swirl", "shatteringslam": "blade", "rimeslash": "blade",
	"counterspell": "interrupt",
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

## The healer specs (SPECS names). Every one has an out-of-combat rez (tag
## "Resurrect"); abilities that revive (tags "Revive", "Resurrect") sit only in
## these (CLAUDE.md; tests/test_books.gd).
const HEALER_SPECS := ["Choir of One", "Line of Light", "Strings Attached", "Shepherd", "Cold Comfort"]

## Each spec's role: "dps", "tank", "healer" or "utility" (the balance sim, the
## party frames' role icon). Healers here and in HEALER_SPECS agree (tests/test_books.gd).
const SPEC_ROLES := {
	"Steady Flame": "dps", "Slagforged": "tank", "Forge Heat": "dps", "Pitch and Cinder": "dps",
	"Hard Winter": "dps", "Cold Comfort": "healer", "Frostbitten Steel": "dps", "Glacier Wall": "tank", "Winter Hunt": "dps",
	"Live Current": "dps", "Stormdancer": "dps", "Lightning Rod": "tank", "Stormstring": "dps",
	"Clockwork": "dps", "Hall of Mirrors": "tank", "Second Act": "dps", "Aetherstring": "dps",
	"The Breach": "dps", "Pack of Two": "dps", "Strings Attached": "healer", "Nightstring": "dps",
	"Thornweaver": "dps", "Shepherd": "healer", "Colossus": "tank", "Venomstring": "dps",
	"Choir of One": "healer", "Censer Bearer": "tank", "Line of Light": "healer", "Lightstring": "dps",
	"The Wheel": "dps", "Brawler": "tank", "Rogue": "dps", "Sharpshooter": "dps",
	"Utility": "utility",
}

## The spec an ability sits in ("" if none).
static func spec_of(id: String) -> String:
	for spec in SPECS.get(category_of(id), []):
		if (spec[1] as Array).has(id):
			return str(spec[0])
	return ""

## A player's role from the abilities on their bars: the role with the most of
## them ("Utility" ones don't count; ties: healer, then tank, then dps).
static func role_of_bar(ids: Array) -> String:
	var count := {"healer": 0, "tank": 0, "dps": 0}
	for id in ids:
		var role := str(SPEC_ROLES.get(spec_of(str(id)), ""))
		if count.has(role):
			count[role] += 1
	var best := "dps"
	var most := 0
	for role in ["healer", "tank", "dps"]:   # (in tie order: a later one must have more)
		if int(count[role]) > most:
			most = int(count[role])
			best = role
	return best

## Each book's abilities split by playstyle (visual only): book -> [[spec name, [ids]], ...].
## Books show their specs in this order, each under a divider. Every ability of a
## book sits in exactly one spec (tests/test_books.gd).
## "Utility": crowd control, roots, interrupts, movement, party buffs and self
## defensives that work without the rest of a spec's kit (CLAUDE.md). One stays in
## its spec only if it can't be used without it (needs the spec's resource or
## objects, or a bow).
const SPECS := {
	"fire": [
		["Steady Flame", ["fireball", "flamenova", "ventflames", "coolhead", "stoke", "embervolley",
			"immolate", "walloffire", "kilnblast", "slowfuse", "rekindle", "crucible"]],
		["Slagforged", ["slagskin", "brand", "cinderguard", "anvil"]],
		["Forge Heat", ["searingstrike", "quench", "flare"]],
		["Pitch and Cinder", ["flamingarrow", "pitcharrow", "cinderrain"]],
		["Utility", ["coolingslag", "furnacebreath", "bellows", "cinderstep", "heatsink", "cinderwing"]],
	],
	"frost": [
		["Hard Winter", ["frostbolt", "blizzard", "frostnova", "iceshards", "coldspike", "sleetwave",
			"hoarfrost", "shatteringwave", "deepwinter"]],
		["Cold Comfort", ["rimeshell", "meltwater", "rimeveil", "breaktheice", "frostlattice", "rimefall", "frosttide", "stillwater", "springthaw"]],
		["Frostbitten Steel", ["froststrike", "hoarcleave", "calving", "icebreaker", "rimeedge", "bitteredge", "blackfrost"]],
		["Glacier Wall", ["rimeslash", "shatteringslam", "coldshoulder", "rimequake", "hailcoat", "hardrime", "glacialbulwark"]],
		["Winter Hunt", ["frostarrow", "icepin", "shattershot", "glacialdraw", "rimefletch", "coldmark", "icyretreat"]],
		["Utility", ["rimelock", "flashfreeze", "winterhide", "icebarrier", "snowward"]],
	],
	"lightning": [
		["Live Current", ["lightningbolt", "chainlightning", "forkedbolt", "discharge", "balllightning", "arcflash",
			"livewire", "thunderhead", "groundingsurge", "capacitor"]],
		["Stormdancer", ["chargededge", "whiplash", "arccleave", "cadence", "twincurrent",
			"overdrive", "splitsecond", "backcurrent"]],
		["Lightning Rod", ["stormshield", "thunderaegis", "returnstroke", "shockring", "crossguard", "reflexarc",
			"drawthestorm", "reelin"]],
		["Stormstring", ["stormarrow"]],
		["Utility", ["staticsnare", "jolt", "stormfront", "flicker", "staticstep", "thunderstrike", "faradayguard",
			"groundout", "recharge"]],
	],
	"arcane": [
		["Clockwork", ["arcanemissiles", "unravel", "glint", "scatter", "countdown", "collapse", "convergence",
			"mirrorsigil", "arcaneexplosion", "rewind", "lapse"]],
		["Hall of Mirrors", ["doubleup", "ripple", "missedbeat", "fullset", "standin", "tradeplaces", "decoy", "crowdofone"]],
		["Second Act", ["arcanestrike", "swiftcut", "deepcut", "latecut", "widecut", "encore", "doubletime"]],
		["Aetherstring", ["arcaneshot"]],
		["Utility", ["fixedpoint", "counterspell", "blink", "intervalward"]],
	],
	"shadow": [
		["The Breach", ["blight", "erode", "corruption", "gnaw", "calldue", "spill", "pall", "takeitback", "bottomless"]],
		["Pack of Two", ["sic", "shadowstrike", "openup", "bothatonce", "runthemdown", "guarddogs", "bringitdown", "offthechain"]],
		["Strings Attached", ["puppetstring", "patchup", "hoist", "tug", "catscradle", "wrench", "pulltaut", "cuppedhands",
			"restring", "knot", "yank", "doublethread", "behinditsback", "slack", "stillstanding",
			"cutthestrings", "notfinished", "backonyourfeet"]],
		["Nightstring", ["shadowarrow"]],
		["Utility", ["tangle", "hush", "climbthestring", "stringup"]],
	],
	"nature": [
		["Thornweaver", ["thornshot", "briartiger", "mossback", "thornwing", "chokingvipers", "greenwoodstag"]],
		["Shepherd", ["dewfall", "fawn", "rootguard", "owl", "heartwoodelk", "wildherd", "returntobloom"]],
		["Colossus", ["vinefist", "grasp", "stomp", "giantshands", "heartsap", "awaken"]],
		["Venomstring", ["fangarrow", "adderarrow", "asparrow", "kraitarrow", "venomburst", "spittingvolley", "bloatarrow", "coilback", "venomsurge"]],
		["Utility", ["rootsnare", "deeproots", "sporesleep", "leafcloak"]],
	],
	"holy": [
		["Choir of One", ["singmercy", "singchorus", "singvigil", "psalm", "outpour", "lift", "refrain", "canticle",
			"exultation", "antiphon", "shelter", "highnote", "reprise", "swell", "lastverse", "hymnofwaking"]],
		["Censer Bearer", ["censerswing", "hallowedarc", "beckon", "pourout", "absolve", "aureole", "gatherthelight",
			"raisethecenser"]],
		["Line of Light", ["setprism", "moveprism", "mendingray", "brightlance", "gleam", "prismward", "piercinglight",
			"realign", "shatterprism", "shatterall", "infuse", "kaleidoscope", "relight"]],
		["Lightstring", ["glimmershot", "prismarrow", "refractingshot", "sunlitarrow", "prismbreaker", "stepoflight", "spectrumvolley"]],
		["Utility", ["bindingring", "circleofsilence", "steadyvoice", "rest", "unfallen"]],
	],
	"martial": [
		["The Wheel", ["quickswing", "fullswing", "weaponart", "wheelbreak", "wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul",
			"hack", "chop", "rush", "shrapnel", "slash", "lunge", "bladeguard", "shardlance",
			"jab", "hook", "dragin", "flyinghead", "thud", "crush", "earthshake", "faultline"]],
		["Brawler", ["punch", "brawlkick", "elbow", "catch", "comeon", "toughitout", "onemore", "fightingstyle",
			"rapidfists", "haymaker", "sweep", "roundhouse", "clinch", "shakeoff", "turnitaround", "throw", "takedown"]],
		["Rogue", ["cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride", "rollwithit", "snatch",
			"gut", "throughandthrough", "redwhirl", "backflip", "drivethrough"]],
		["Sharpshooter", ["quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands"]],
		["Utility", ["pintheshadow", "overtheshoulder", "playdead"]],
	],
}

# --- Martial warrior: the Wheel -------------------------------------------------------
# Four weapons ride on the warrior's back in WHEEL_ORDER; the one in front is held.
# The spellbooks list the four WHEEL_SLOTS (Filler, Heavy Filler, Weapon Art,
# Finisher): placeholders that do nothing themselves. On the bar, each one becomes
# the held weapon's move of that kind (WHEEL_FORMS). The weapons are listed too,
# each with a dropdown of its moves (to read; dragging one places its slot).
# Moves and slots are known once a weapon is (PlayerData.has_ability).
# Rules: scripts/player/martial_wheel.gd.

## The order the weapons turn in.
const WHEEL_ORDER := ["wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul"]
## The bar placeholders: Filler, Heavy Filler, Weapon Art, Finisher.
const WHEEL_SLOTS := ["quickswing", "fullswing", "weaponart", "wheelbreak"]
## Each weapon's moves, in WHEEL_SLOTS order.
const WHEEL_FORMS := {
	"wheelgreataxe": ["hack", "chop", "rush", "shrapnel"],
	"wheelgreatsword": ["slash", "lunge", "bladeguard", "shardlance"],
	"wheelhalberd": ["jab", "hook", "dragin", "flyinghead"],
	"wheelmaul": ["thud", "crush", "earthshake", "faultline"],
}

## The weapon a Wheel move belongs to ("" if `id` is not one).
static func wheel_weapon_of(id: String) -> String:
	for weapon in WHEEL_FORMS:
		if (WHEEL_FORMS[weapon] as Array).has(id):
			return weapon
	return ""

## Which bar button a Wheel move is a form of (-1 if `id` is not one).
static func wheel_slot_index(id: String) -> int:
	var weapon := wheel_weapon_of(id)
	return (WHEEL_FORMS[weapon] as Array).find(id) if weapon != "" else WHEEL_SLOTS.find(id)

## What the bar keeps for `id`: a Wheel move goes on as its bar button.
static func bar_id(id: String) -> String:
	return WHEEL_SLOTS[wheel_slot_index(id)] if wheel_weapon_of(id) != "" else id

## Is `id` shown in the spellbooks? (Wheel moves sit under their weapon's dropdown;
## the Brawler's chain moves are made by the chain, shown in its table; the Rogue's Kill
## forms are made by a Kill window, shown in theirs.)
static func listed_in_book(id: String) -> bool:
	return wheel_weapon_of(id) == "" and not is_chain_move(id) and not is_kill_form(id)

# --- Martial tank: the Brawler ---------------------------------------------------------
# Punch, Kick and Elbow go into a chain of Balance.CHAIN_LENGTH; when the last one
# lands, a move goes off on top of it. The strike that ends the chain picks the move
# (BRAWLER_MOVES: [any repeat, all three different]); a chain started by Catch picks
# from BRAWLER_CATCH_MOVES. The moves have no buttons. Rules: scripts/player/martial_brawler.gd.
const BRAWLER_STRIKES := ["punch", "brawlkick", "elbow"]
const BRAWLER_MOVES := {"punch": ["rapidfists", "haymaker"], "brawlkick": ["sweep", "roundhouse"], "elbow": ["clinch", "shakeoff"]}
const BRAWLER_CATCH_MOVES := {"punch": "turnitaround", "brawlkick": "throw", "elbow": "takedown"}
## Every Brawler ability (buttons and moves): none of them works with a shield.
const BRAWLER_IDS := ["punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle",
	"rapidfists", "haymaker", "sweep", "roundhouse", "clinch", "shakeoff", "turnitaround", "throw", "takedown"]

## The Chain's moves as the spellbooks show them: [[heading, [ids]], ...]; the first
## part in pairs (any repeat, three different) for each strike that ends the chain.
static func brawler_move_table() -> Array:
	var pairs: Array[String] = []
	for strike in BRAWLER_STRIKES:
		pairs.append_array(BRAWLER_MOVES[strike])
	var caught: Array[String] = []
	for strike in BRAWLER_STRIKES:
		caught.append(str(BRAWLER_CATCH_MOVES[strike]))
	return [["Chain moves: the last strike picks (right: three different strikes)", pairs],
		["After Catch: the last strike picks", caught]]

## Is `id` one of the Brawler's chain moves (made by the chain, no button)?
static func is_chain_move(id: String) -> bool:
	for strike in BRAWLER_MOVES:
		if (BRAWLER_MOVES[strike] as Array).has(id):
			return true
	return BRAWLER_CATCH_MOVES.values().has(id)

# --- Martial DPS: the Rogue -------------------------------------------------------------
# Rogue hits build Flow; Go In spends it on a Kill window, during which each builder's
# button takes its Kill form (ROGUE_KILL_FORMS). The forms have no buttons of their own:
# the bar shows them in place of their builder. Rules: scripts/player/martial_rogue.gd.
const ROGUE_KILL_FORMS := {"cut": "gut", "twinstab": "throughandthrough", "whirl": "redwhirl",
	"kickoff": "backflip", "dartin": "drivethrough"}
## Every Rogue ability (buttons and Kill forms): each needs a melee weapon in both hands.
const ROGUE_IDS := ["cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride",
	"rollwithit", "snatch", "gut", "throughandthrough", "redwhirl", "backflip", "drivethrough"]
## Martial Utility (any Martial spec; scripts/player/martial_rogue.gd codes them too).
const MARTIAL_UTILITY := ["pintheshadow", "overtheshoulder", "playdead"]

## Is `id` one of the Rogue's Kill forms (made by a Kill window, no button)?
static func is_kill_form(id: String) -> bool:
	return ROGUE_KILL_FORMS.values().has(id)

## The Kill forms as the spellbooks show them: [[heading, [ids]]].
static func rogue_kill_table() -> Array:
	var forms: Array[String] = []
	for b in ROGUE_KILL_FORMS:
		forms.append(str(ROGUE_KILL_FORMS[b]))
	return [["Kill forms: what your builders become in a Kill window", forms]]

# --- Martial archer: Sharpshooter -------------------------------------------------------
# No resource: each shot's hit brings others back sooner (SHARP_LINKS); a cut on a shot
# that is already ready becomes Overcut on it. Rules: scripts/player/martial_sharpshooter.gd.
## The shots that cut, and that Streak counts (Loose, Breathe and Fast Hands don't).
const SHARP_ENGINE := ["quickshot", "pierce", "spread", "heavydraw", "followup"]
## Every Sharpshooter ability: each needs a bow.
const SHARP_IDS := ["quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands"]
## Shot -> the shots its hits bring back sooner (Heavy Draw resets Quick Shot; Follow Up
## cuts whichever shot you used just before it, so it has none here).
const SHARP_LINKS := {"quickshot": ["pierce"], "pierce": ["spread"], "spread": ["heavydraw"],
	"heavydraw": ["quickshot", "pierce", "spread", "followup"], "followup": []}

## Buttons that come with another ability's Skill Card instead of their own card
## (PlayerData.has_ability), and are used like drafted ones.
const BROUGHT_BUTTONS := {"goin": "cut", "brawlkick": "punch", "elbow": "punch", "fightingstyle": "punch",
	"loose": "quickshot"}

## A book's specs holding only the abilities `keep` accepts (all if not given),
## empty ones dropped: [[spec name, [ids]], ...]. Abilities of the book that no
## spec lists (a book without specs, e.g. Rune Spells) come last under "".
static func specs_in(category: String, keep: Callable = Callable()) -> Array:
	var out: Array = []
	var placed := {}
	for spec in SPECS.get(category, []):
		var ids: Array[String] = []
		for id in spec[1]:
			placed[id] = true
			if CATEGORY_OF.get(id, "") == category and (not keep.is_valid() or keep.call(id)):
				ids.append(id)
		if not ids.is_empty():
			out.append([spec[0], ids])
	var rest: Array[String] = []
	for id in in_category(category):
		if not placed.has(id) and (not keep.is_valid() or keep.call(id)):
			rest.append(id)
	if not rest.is_empty():
		out.append(["", rest])
	return out

const RESOURCE_NAMES := ["", "mana", "energy", "fury"]
## Abilities that spend ALL your Energy (their tooltips say so; player.gd spends it).
const SPENDS_ALL := ["discharge", "groundout", "recharge"]
## Abilities that skip the global cooldown without being an interrupt or a trinket.
const OFF_GCD := ["groundingsurge", "capacitor", "returnstroke", "rimefletch", "rewind", "lapse", "scatter",
	"missedbeat", "tradeplaces", "doubletime", "offthechain", "doublethread", "restring", "behinditsback", "swell",
	"aureole", "gatherthelight", "unfallen", "setprism", "moveprism", "shatterall", "prismarrow", "stepoflight",
	"fightingstyle", "goin", "hityourstride", "rollwithit", "playdead", "breathe", "fasthands",
	"coldshoulder", "glacialbulwark", "bitteredge"]
## Melee-weapon abilities used from their own range (cast_range) instead of the
## weapon's reach: Static Step dashes in, Whiplash lashes from afar.
const LONG_REACH := ["staticstep", "whiplash", "reelin", "beckon", "raisethecenser", "dragin", "comeon",
	"cut", "gut", "whirl", "redwhirl", "dartin", "drivethrough", "pintheshadow", "overtheshoulder", "coldshoulder"]

## Does ability `id` have to be within the equipped weapon's reach of its target?
static func uses_weapon_reach(id: String) -> bool:
	var r := get_resource(id)
	return r != null and int(r.weapon_requirement) != 0 and not LONG_REACH.has(id)
const CAST_LABELS := ["Instant", "Cast", "Channeled", "Cast"]
## Spells with a cast time that are instant when they go on an ally or you (Rime Shell).
const INSTANT_ON_ALLIES := ["rimeshell"]

static var _res_cache := {}
static var _db_cache := {}

static func get_resource(id: String) -> Resource:
	if not PATHS.has(id):
		return null
	if not _res_cache.has(id):
		var r: Resource = load(PATHS[id])
		Balance.apply_ability(id, r)   # numbers come from balance.gd
		_res_cache[id] = r
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
				"tags": r.tags, "tip": "",
			}
		# The plain tips come second: building one asks for costs, which reads
		# this table (filling them in the loop above recursed without end when
		# the table was first built with a player in the scene).
		for id in PATHS:
			_db_cache[id]["tip"] = _build_tip(get_resource(id))
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

## Cost shown in tooltips: mana is on the health scale (cost points x 10% of base
## mana, with your talent discounts when you're in game); energy / fury are points.
## How many patches of mulch I have (Nature caster; 0 out of game).
static func mulch_count() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var p: Node = tree.get_first_node_in_group("player") if tree else null
	return (p.mulch() as Array).size() if p and p.has_method("mulch") else 0

static func cost_amount(r: Resource) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var p: Node = tree.get_first_node_in_group("player") if tree else null
	# In game the player knows the real cost (talent discounts on any resource).
	if p and p.has_method("resource_cost"):
		return int(round(float(p.resource_cost(str(r.id)))))
	if RESOURCE_NAMES[r.resource_type] != "mana":
		return int(round(r.resource_cost))
	return int(round(float(r.resource_cost) * Stats.mana_unit(Stats._player_level())))

static func _build_tip(r: Resource, desc: String = "", haste: float = 1.0) -> String:
	var lines: Array[String] = [r.display_name, desc if desc != "" else fill(str(r.id), r.description, Callable(), {})]
	var bits: Array[String] = []
	var res: String = RESOURCE_NAMES[r.resource_type]
	if r.resource_cost > 0:
		bits.append("%d %s" % [cost_amount(r), res.capitalize()])
	if r.resource_generated > 0:
		bits.append("Generates %d %s" % [generated_of(str(r.id)), res.capitalize()])
	if SPENDS_ALL.has(str(r.id)):
		bits.append("All %s" % res.capitalize())
	if r.cast_type == 0:
		bits.append("Instant")
	elif r.cast_type == 2:
		bits.append("Channeled %s s" % secs(r.cast_time / haste))
	else:
		bits.append("Cast time: %s s%s%s" % [secs(base_cast_time(r) / haste), " (can move)" if r.can_move_while_casting else "",
			" (instant on allies)" if INSTANT_ON_ALLIES.has(str(r.id)) else ""])
	if r.cooldown > 0.0:
		bits.append("%s s cooldown" % secs(cooldown_of(r)))
	lines.append("  •  ".join(bits))
	var req: Array[String] = []
	if weapon_need(r) != "":
		req.append(weapon_need(r))
	if r.get("requires_shield"):
		req.append("a shield")
	if r.get("requires_off_hand"):
		req.append("an off hand")
	if r.requires_target:
		req.append("a target")
	if not req.is_empty():
		lines.append("Requires " + _join_and(req))
	if r.get("forbids_shield"):
		lines.append(NO_SHIELD_LINE)
	if is_interrupt(str(r.id)):
		lines.append(interrupt_note())
	lines.append("Tags: " + ", ".join(r.tags))
	return "\n".join(lines)

## Is this one of the interrupts? They all share one cooldown (player.gd, interrupt_cooldowns).
static func is_interrupt(id: String) -> bool:
	return Balance.INTERRUPT_LOCKOUT.has(id)

## The line every interrupt's tooltip carries about that shared cooldown.
static func interrupt_note() -> String:
	return "Using any interrupt puts your other interrupts on a %s sec cooldown." % Stats.num(Balance.INTERRUPT_SHARED_COOLDOWN)

## "a, b and c"
static func _join_and(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]

## "a melee weapon" / "a two-handed melee weapon" / "a melee weapon in each hand"
## / "a bow": the weapon ability `r` needs, for its "Requires ..." line ("" if it
## needs none).
static func weapon_need(r: Resource) -> String:
	if bool(r.get("requires_dual_wield")):
		return DUAL_WIELD_NEED
	var two := "two-handed " if bool(r.get("requires_two_hand")) else ""
	if int(r.weapon_requirement) == 1:
		return "a %smelee weapon" % two
	if int(r.weapon_requirement) == 2:
		return "a bow"
	return "a two-handed weapon" if two != "" else ""

## Is a two-handed weapon equipped in the Main Hand?
static func has_two_hander_equipped() -> bool:
	return bool(equipped_weapon().get("locks_offhand", false))

## What a dual-wield ability needs, as its "Requires ..." line says it (the
## Arcane tank: a one-handed melee weapon in the Main Hand and in the Off Hand).
const DUAL_WIELD_NEED := "a melee weapon in each hand"
## The line an ability that can't be used with a shield carries (the Brawler, Martial tank).
const NO_SHIELD_LINE := "Requires no shield"

## The one-handed melee weapon equipped in the Off Hand ({} if there is none):
## the second weapon a dual-wield ability strikes with.
static func offhand_weapon() -> Dictionary:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	if pd == null:
		return {}
	var item := str(pd.equipment.get("Off Hand", ""))
	return Items.get_item(item) if Items.is_one_handed_melee(item) else {}

## The Off Hand weapon a tooltip counts: the one equipped, or a basic dagger when
## that hand holds no weapon (so the tooltip still has a number to show).
static func offhand_for_tooltip() -> Dictionary:
	var off := offhand_weapon()
	return off if not off.is_empty() else Items.get_item("dagger")

## Weapon damage (coefficient) a dual-wield ability strikes with: the Main Hand
## weapon `w` and the Off Hand weapon together.
static func dual_wield_damage(w: Dictionary) -> float:
	return float(w.get("damage", 0.0)) + float(offhand_for_tooltip().get("damage", 0.0))

## Is a one-handed melee weapon equipped in the Main Hand and another in the Off Hand?
static func has_dual_wield_equipped() -> bool:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return pd != null and pd.has_method("has_dual_wield") and bool(pd.has_dual_wield())

## Is a shield equipped in the Off Hand?
static func has_shield_equipped() -> bool:
	return offhand_type() == "shield"

## Is an off hand item (tome, wand, lantern...; not a weapon or shield) in the Off Hand?
static func has_off_hand_item_equipped() -> bool:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return pd != null and Items.is_off_hand_item(str(pd.equipment.get("Off Hand", "")))

## item_type of the Off Hand item ("shield", "tome", "wand", "lantern", "dagger"...), "" if empty.
static func offhand_type() -> String:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	if pd == null:
		return ""
	return Items.item_type(str(pd.equipment.get("Off Hand", "")))

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

## Resource ability `id` gives when used.
static func generated_of(id: String) -> int:
	var r := get_resource(id)
	if r == null:
		return 0
	return int(r.resource_generated)

## Base cost (Mana in points, which may be fractions; Energy / Fury whole).
static func cost_of(id: String) -> float:
	return float(info(id).get("cost", 0.0))

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
const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")
## Heal / absorb coefficients (1.0 = a standard hit's worth of health; player.gd uses these).
const HEALS := Balance.HEALS
## Secondary hits ({flat1} in descriptions): chain jumps, splash, retaliation.
const EXTRA_HITS := Balance.EXTRA_HITS
## Shatter damage (Rime Shell breaking, Frozen shattering): a Frost Bolt's worth.
const SHATTER_COEF := Balance.SHATTER_COEF
## Shatters hit this many enemies at full damage; beyond that the damage is
## shared (each takes AOE_CAP / targets of it).
const SHATTER_AOE_CAP := Balance.AOE_TARGET_CAP

const TextFill = preload("res://scripts/core/text_fill.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Macros = preload("res://scripts/core/macros.gd")
const WheelIcons = preload("res://scripts/ui/wheel_icons.gd")
const BrawlerIcons = preload("res://scripts/ui/brawler_icons.gd")
const RogueIcons = preload("res://scripts/ui/rogue_icons.gd")
const SharpshooterIcons = preload("res://scripts/ui/sharpshooter_icons.gd")
## Talents that widen an ability: [talent key, metres of RADIUS per point of the
## talent's value]. Deep Crucible gives width, so half of it is radius.
const RADIUS_TALENTS := {"crucible": ["fire_deep_crucible", 0.5], "ripple": ["arcane_wide_rings", 1.0], "hallowedarc": ["holy_wide_arc", 1.0],
	"sweep": ["martial_wide_stance", 1.0], "roundhouse": ["martial_wide_stance", 1.0]}

## Metres your talents add to ability `id`'s radius (the game and its {radius} / {width} use this).
static func radius_bonus(id: String) -> float:
	if not RADIUS_TALENTS.has(id):
		return 0.0
	return talent(str(RADIUS_TALENTS[id][0])) * float(RADIUS_TALENTS[id][1])
## Abilities whose shield Rime Ward makes bigger ({heal} / {ward}).
## (Ice Layers count too: Rime Ward makes each bigger, see {layer_pct}.)
const SHIELD_ABILITIES := ["rimeshell", "snowward", "intervalward", "rootguard", "giantshands", "rimeveil", "rimefall"]

## % of maximum health one Ice Layer absorbs (Frost tank), with Rime Ward's `absorb_pct`
## and Deep Strata's `strata_pct`. The game (GlacierKit) and the tooltips share this.
static func ice_layer_pct(absorb_pct: float, strata_pct: float) -> float:
	return Balance.ICE_LAYER_PCT * (1.0 + maxf(absorb_pct, 0.0) / 100.0) * (1.0 + maxf(strata_pct, 0.0) / 100.0)

## A talent's number at the rank the player has (0 without it, or outside the game).
static func talent(key: String, field: String = "values") -> float:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return float(pd.talent_value(key, field)) if pd and pd.has_method("talent_value") else 0.0

## Is talent `key`'s capstone on (it is at max rank)?
static func capstone(key: String) -> bool:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return pd != null and pd.has_method("talent_capstone") and bool(pd.talent_capstone(key))

## Is a talent's capstone active for the player (false outside the game)?
static func talent_capstone(key: String) -> bool:
	var tree := _tree()
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return pd != null and pd.has_method("talent_capstone") and bool(pd.talent_capstone(key))

## Seconds a caster's talents add to status effect `res` when they apply it.
## `talent_of` = func(key, field) -> float. The player (StatusContainer asks it)
## and the tooltips share this, so both always agree.
static func effect_time_bonus(res: Resource, talent_of: Callable) -> float:
	if res == null:
		return 0.0
	var id := str(res.get("id"))
	var bonus := 0.0
	if id == "hoarfrost":
		bonus += float(talent_of.call("frost_hoarfrost", "values2"))   # Deep Hoarfrost
	if id == "immolate":
		bonus += float(talent_of.call("fire_long_burn", "values"))     # Long Burn
	if id == "frozen":
		bonus += float(talent_of.call("frost_hard_freeze", "values"))  # Hard Freeze
	if id == "grasped":
		bonus += float(talent_of.call("nature_firm_hold", "values"))   # Firm Hold
	if id == "pinned_shadow":
		bonus += float(talent_of.call("martial_pinned_down", "values2"))   # Pinned Down
	# Shadow melee (the Hounds): Open Up's mark, Roused and Off the Chain.
	if id == "laid_open":
		bonus += float(talent_of.call("shadow_still_wet", "values"))       # Still Wet
	if id == "roused":
		bonus += float(talent_of.call("shadow_worked_up", "values"))       # Worked Up
	if id == "off_the_chain":
		bonus += float(talent_of.call("shadow_slipped_leash", "values"))   # Slipped Leash
	# Left Hanging (Shadow, open): every stun and root I apply lasts longer.
	if res.get("stun") == true or res.get("root") == true:
		var d: Variant = res.get("duration")
		bonus += (float(d) if d != null else 0.0) * float(talent_of.call("shadow_left_hanging", "values")) / 100.0
	# Lingering Frost: every Frost damage-over-time effect lasts longer.
	var tick: Variant = res.get("tick_damage")
	if tick != null and float(tick) > 0.0 and str(res.get("damage_type")) == "frost":
		bonus += float(talent_of.call("frost_dot_duration", "values"))
	return bonus

## % more damage a Martial talent gives every hit of ability `id` (the hits get it as a
## bonus of their own, MartialTalentsKit; the tooltips show it in {hit}).
## `talent_of` = func(key, field) -> float.
static func martial_hit_pct(id: String, talent_of: Callable) -> float:
	var key := martial_hit_talent(id)
	return float(talent_of.call(key, "values")) if key != "" else 0.0

## The Martial talent that makes every hit of `id` stronger ("" if none).
static func martial_hit_talent(id: String) -> String:
	if ["shrapnel", "shardlance", "flyinghead", "faultline"].has(id):
		return "martial_hard_break"   # Hard Break: the Wheel's finishers
	if is_kill_form(id):
		return "martial_clean_kill"   # Clean Kill: the Rogue's Kill forms
	if id == "haymaker":
		return "martial_knockout"     # Knockout
	if id == "heavydraw":
		return "martial_full_draw"    # Full Draw
	return ""

## Heals over time: heals (by their meter / log id) that come a little at a time,
## every second or so (Green Thumb heals them more; keyword "heals over time").
const HEAL_OVER_TIME_IDS := ["sap", "evergreen", "puppetstring", "refrain", "catchyourbreath"]

## Talents that shorten an ability's cooldown: ability id -> talent key (its
## value = seconds taken off).
const COOLDOWN_TALENTS := {"realign": "holy_quick_realign", "prismarrow": "holy_full_quiver"}

## Ability `r`'s cooldown in seconds with your talents (the game and the
## tooltips both use this). Quick Realign shortens Realign's.
static func cooldown_of(r: Resource) -> float:
	if r == null:
		return 0.0
	var cd := float(r.cooldown)
	var key := str(COOLDOWN_TALENTS.get(str(r.id), ""))
	if key != "" and cd > 0.0:
		cd = maxf(cd - talent(key), 1.0)
	if str(r.id) == "shelter" and capstone("holy_open_doors"):
		cd = minf(cd, Balance.OPEN_DOORS_COOLDOWN)   # Open Doors (capstone)
	return cd

## Seconds ability `r` takes to cast before Haste (Quickened Frost shortens Frost Bolts).
static func base_cast_time(r: Resource) -> float:
	var t := float(r.cast_time)
	if is_a(str(r.id), "frostbolt"):
		t = maxf(t - talent("frost_bolt_cast"), 0.2)
	elif str(r.id) == "lightningbolt":
		t = maxf(t - talent("lightning_quick_fuse"), 0.2)   # Quick Fuse
	elif str(r.id) == "refractingshot":
		t = maxf(t - talent("holy_steady_aim"), 0.2)   # Steady Aim
	elif str(r.id) == "brightlance":
		t = maxf(t - talent("holy_quick_lance"), 0.2)   # Quick Lance
	return t

## Real damage of a hit of coefficient `coef` carrying `tags` (before crits,
## modifiers and resistances), with your current stats. Talent texts use it.
static func coef_damage(coef: float, tags: PackedStringArray) -> float:
	return coef * (unit() + Stats.power_bonus(tags, stat_source()))

## Burst coefficient when the ability's effect runs out (Hoarfrost).
static func _expire_coef(id: String) -> float:
	var r := get_resource(id)
	var fx: Resource = r.on_hit_effect if r else null
	var v = fx.get("expire_damage") if fx else null
	return float(v) if v != null else 0.0

## Real damage of a 1.0 coefficient at your level (before power).
static func unit() -> float:
	return Stats.level_hit(Stats._player_level())
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

## The starter weapon an ability needs (bow for ranged abilities, sword for
## melee), for showing its damage when you have no fitting weapon equipped.
static func basic_weapon(id: String) -> Dictionary:
	var r := get_resource(id)
	if r == null:
		return {}
	if int(r.weapon_requirement) == 2:
		return Items.get_item("bow")
	return Items.get_item("greatsword" if bool(r.get("requires_two_hand")) else "sword")

static func uses_weapon(id: String) -> bool:
	var r := get_resource(id)
	return r != null and float(r.weapon_damage_multiplier) > 0.0

## Damage coefficient of one hit, like player.gd: weapon abilities do weapon
## damage x multiplier + the ability's own coefficient. -1 = needs a weapon.
static func hit_base(id: String, w: Dictionary) -> float:
	var r := get_resource(id)
	if r == null:
		return 0.0
	if uses_weapon(id):
		if not w.has("weapon"):
			return -1.0
		# (A dual-wield ability strikes with both weapons: Double Up, Missed Beat.)
		var weapon_damage := dual_wield_damage(w) if bool(r.get("requires_dual_wield")) else float(w.get("damage", 0.0))
		return weapon_damage * float(r.weapon_damage_multiplier) + float(r.damage)
	return float(r.damage)

## The DoT this ability applies (null if none).
static func dot_effect(id: String) -> Resource:
	var r := get_resource(id)
	var fx: Resource = r.on_hit_effect if r else null
	return fx if fx and float(fx.tick_damage) > 0.0 else null

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
	return float(fx.tick_damage) * (unit() + Stats.power_bonus(dot_tags(id), stat_of) * dot_share(fx))

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
	var per := unit() + Stats.power_bonus(tags_of(id), stat_of)   # real damage of a 1.0 coefficient
	var base := hit_base(id, w)
	if base < 0:
		base = hit_base(id, basic_weapon(id))   # no fitting weapon equipped: show it with a basic one
	var fr := get_resource(id)
	var fx_res: Resource = fr.on_hit_effect if fr else null
	var tags := tags_of(id)
	var level := Stats._player_level()
	var flat := Stats.flat_unit(level)
	var talent_of := func(key: String, field: String) -> float: return talent(key, field)
	# What your talents change about the numbers a description quotes.
	var radius := (float(fr.radius) if fr else 0.0) + radius_bonus(id)   # Deep Crucible
	var absorb := 1.0 + talent("frost_absorb") / 100.0 if SHIELD_ABILITIES.has(id) else 1.0   # Rime Ward
	if id == "mendingray":
		absorb *= 1.0 + talent("holy_steady_ray") / 100.0                                # Steady Ray (its heal)
	if id == "shelter" or id == "prismward":
		absorb *= 1.0 + talent("holy_sheltering_light") / 100.0                           # Sheltering Light
	if id == "shelter":
		absorb *= 1.0 + talent("holy_open_doors") / 100.0                                 # Open Doors
	if id == "rootguard":
		absorb *= 1.0 + talent("nature_old_bark") / 100.0                                 # Old Bark
	var rich := 1.0 + talent("nature_rich_soil") / 100.0                                      # Rich Soil (each patch's share)
	var shatter_mult := 1.0 + talent("frost_shatterpoint") / 100.0                            # Shatterpoint
	var hit_coef := base
	if id == "rimeedge":
		hit_coef += talent("frost_honed_rime")                # Honed Rime
	elif id == "cinderguard":
		hit_coef *= 1.0 + talent("fire_hot_iron") / 100.0     # Hot Iron (the burn on a block)
	elif id == "returnstroke":
		hit_coef *= 1.0 + talent("lightning_counter_charge") / 100.0   # Counter-Charge
	elif id == "missedbeat":
		hit_coef *= 1.0 + talent("arcane_on_the_beat") / 100.0   # On the Beat
	elif id == "rimeshell" or id == "shatteringwave":
		hit_coef *= shatter_mult                              # (their {hit} is the shatter)
	hit_coef *= 1.0 + martial_hit_pct(id, talent_of) / 100.0  # Martial: Hard Break, Clean Kill, Knockout, Full Draw
	var dot_mult := 1.0 + talent("frost_hoarfrost") / 100.0 if id == "hoarfrost" else 1.0    # Deep Hoarfrost
	var slow_mult := 1.0   # (no talent strengthens slows right now)
	var shatter := (SHATTER_COEF * unit() + SHATTER_COEF * Stats.power_bonus(PackedStringArray(["Frost", "Spell"]), stat_of)) * shatter_mult
	# Cadence: one press's weapon damage (with a basic weapon if none is equipped).
	var cad_weapon: Dictionary = w if w.has("weapon") else basic_weapon(id)
	var cad := float(cad_weapon.get("damage", 0.0)) * per
	var energy_max := Balance.RESOURCE_MAX + talent("lightning_deep_reserves")   # Deep Reserves: a bigger bar to spend
	var nums := {
		"cad1": fmt_amount(cad * float(Balance.CADENCE_MULTS[0])),
		"cad2": fmt_amount(cad * float(Balance.CADENCE_MULTS[1])),
		"cad3": fmt_amount(cad * float(Balance.CADENCE_MULTS[2]) * (1.0 + talent("lightning_third_beat") / 100.0)),   # Third Beat
		"hit": "?" if base < 0 else fmt_amount(hit_coef * per),
		"half": "?" if base < 0 else fmt_amount(base * per * 0.5),
		"dot": fmt_amount(dot_tick(id, stat_of) * dot_mult),
		"heal": fmt_amount(float(HEALS.get(id, 0.0)) * per * absorb),
		"flat1": fmt_amount(float(EXTRA_HITS.get(id, 0.0)) * per),
		"shatter": fmt_amount(shatter),
		"shatter_frozen": fmt_amount(shatter * Balance.FROZEN_SHATTER_MULT),
		"burst": fmt_amount(_expire_coef(id) * per * dot_mult),
		"slag": fmt_amount(Balance.SLAG_ARMOR * flat * (1.0 + talent("fire_thick_slag") / 100.0)),   # Thick Slag
		# Heat (Fire melee): its numbers straight from balance.gd.
		"heat_max": str(Balance.HEAT_MAX_STACKS),
		"heat_pct": Stats.num(Balance.HEAT_DAMAGE_PCT),
		"heat_time": TextFill.num(Balance.HEAT_TIME + talent("fire_forge_heat")),   # Forge Heat
		"searing_heat": str(Balance.SEARING_STRIKE_HEAT),
		"quench_pct": Stats.num(Balance.QUENCH_PCT_PER_HEAT),
		"quench_min": str(Balance.QUENCH_MIN_HEAT),
		"quench_max": "?" if base < 0 else fmt_amount(base * per * (1.0 + Balance.QUENCH_PCT_PER_HEAT / 100.0 * Balance.HEAT_MAX_STACKS)),
		"flare_cost": str(Balance.FLARE_HEAT_COST),
		# Lightning caster (Energy): a returning leap, and what spending Energy buys.
		"arc_return": fmt_amount(float(EXTRA_HITS.get("chainlightning", 0.0)) * Balance.LEAPING_ARC_RETURN_PCT / 100.0 * per),
		"fork_solo": fmt_amount(Balance.FORKED_BOLT_SOLO * per),
		# Shadow caster: what Hush adds to an open Decay when it interrupts a cast.
		"hush_add": fmt_amount(Balance.HUSH_DECAY * per),
		"discharge_per": fmt_amount(Balance.DISCHARGE_PER_STEP * per),
		"discharge_max": fmt_amount(Balance.DISCHARGE_PER_STEP * energy_max / Balance.ENERGY_STEP * per),
		"ground_per": fmt_amount(Balance.GROUND_OUT_PER_STEP * per * (1.0 + talent("frost_absorb") / 100.0)),   # Rime Ward
		"ground_max": fmt_amount(Balance.GROUND_OUT_PER_STEP * energy_max / Balance.ENERGY_STEP * per * (1.0 + talent("frost_absorb") / 100.0)),
		# Lightning tank: Energy a parry gives during Humming Blade.
		"humming_energy": TextFill.num(Balance.HUMMING_BLADE_ENERGY + talent("lightning_closed_circuit")),   # Closed Circuit
		"ball_energy": TextFill.num(Balance.BALL_LIGHTNING_ENERGY + talent("lightning_tight_coil")),         # Tight Coil
		"recharge_max": TextFill.num(Balance.RECHARGE_PCT_PER_STEP * energy_max / Balance.ENERGY_STEP),       # % of max health at a full bar
		# Fire bow and the phoenix.
		"pitch_pct": Stats.num(Balance.PITCH_TICK_SPEED_PCT),
		"rain_time": Stats.num(Balance.CINDER_RAIN_TIME),
		"rain_tick": secs(Balance.CINDER_RAIN_TICK),
		"phoenix_casts": str(Balance.PHOENIX_CASTS),
		"phoenix_interval": secs(Balance.PHOENIX_INTERVAL),
		"phoenix_range": Stats.num(Balance.PHOENIX_RANGE),
		# The ability's own data (with your talents where they change it).
		"radius": TextFill.num(radius),
		"width": TextFill.num(radius * 2.0),
		"range": TextFill.num(float(fr.cast_range)) if fr else "?",
		"cast": TextFill.num(float(fr.cast_time)) if fr else "?",
		"threat": TextFill.num(float(fr.get("threat_multiplier"))) if fr and fr.get("threat_multiplier") != null else "1",
		"lockout": TextFill.num(float(Balance.INTERRUPT_LOCKOUT.get(id, 0.0))),
		# Its on-hit effect.
		"fx_time": TextFill.num(float(fx_res.duration) + effect_time_bonus(fx_res, talent_of)) if fx_res else "?",
		"fx_slow": TextFill.effect_number(fx_res, "slow", slow_mult),
		"fx_pct": TextFill.effect_number(fx_res, "pct"),
		"fx_every": TextFill.effect_number(fx_res, "every"),
		# Numbers a talent adds to.
		"kiln_pct": TextFill.num(Balance.KILN_BLAST_IMMOLATE_PCT + talent("fire_stoked_kiln")),          # Stoked Kiln
		"cold_pct": TextFill.num(Balance.COLDSPIKE_FROZEN_PCT + talent("frost_piercing_cold")),          # Piercing Cold
		"brand_pct": TextFill.num(Balance.BRAND_PCT + talent("fire_deep_brand")),                        # Deep Brand
		"crucible_time": TextFill.num(Balance.CRUCIBLE_TIME + talent("fire_deep_crucible", "values2")),  # Deep Crucible
		"darts": str(Balance.ARCANE_MISSILES_COUNT + int(round(talent("arcane_seventh_sigil")))),         # Seventh Sigil
		"mirror_pct": TextFill.num(Balance.MIRROR_SIGIL_PCT + talent("arcane_polished_glass")),          # Polished Glass
		"collapse_pull": TextFill.num(Balance.COLLAPSE_PULL),
		"blink_dist": TextFill.num(Balance.BLINK_DISTANCE + talent("arcane_long_step")),                 # Long Step
		"flicker_dist": TextFill.num(Balance.FLICKER_DISTANCE + talent("arcane_long_step")),
		"glint_time": TextFill.num(Balance.GLINT_TIME + talent("arcane_keep_moving")),                   # Keep Moving
		"encore_pct": TextFill.num(Balance.ENCORE_PCT + talent("arcane_standing_ovation")),              # Standing Ovation
		"call_due_pct": TextFill.num(Balance.CALL_DUE_BONUS_PCT + talent("shadow_interest")),            # Interest
		"bottomless_time": TextFill.num(Balance.BOTTOMLESS_TIME + talent("shadow_no_floor")),            # No Floor
		"spill_pct": TextFill.num(Balance.SPILL_PCT + talent("shadow_running_over")),                    # Running Over
		"chain_time": TextFill.num(Balance.OFF_THE_CHAIN_TIME + talent("shadow_slipped_leash")),         # Slipped Leash
		"late_cut_delay": TextFill.num(maxf(Balance.LATE_CUT_DELAY - talent("arcane_no_loose_ends"), 0.1)),   # No Loose Ends
		"double_time": TextFill.num(Balance.DOUBLE_TIME_TIME + talent("arcane_dress_rehearsal")),        # Dress Rehearsal
		"decoy_time": TextFill.num(Balance.DECOY_TIME + talent("arcane_good_likeness")),                 # Good Likeness
		"ripple_enemies": str(Balance.WIDE_RINGS_ENEMIES if talent_capstone("arcane_wide_rings")         # Wide Rings' capstone
			else Balance.RIPPLE_REFLECTION_ENEMIES),
		# Buffs in flat units, and other sizes worked out from balance.gd.
		"barrier_armor": fmt_amount(Balance.ICE_BARRIER_ARMOR * flat),
		"heat_sink_max": "?" if base < 0 else fmt_amount(base * per * (1.0 + Balance.HEAT_SINK_BONUS)),
		"arcane_mana": str(int(round(Balance.ARCANE_STRIKE_MANA * Stats.mana_unit(level)))),
		"slack_mana": str(int(round(Balance.SLACK_MANA * Stats.mana_unit(level)))),   # Slack: mana back per String out
		"slack_time": TextFill.num(maxf(Balance.SLACK_TIME - talent("shadow_give_and_take"), 0.0)),      # Give and Take
		"string_time": TextFill.num(Balance.STRING_TIME + talent("shadow_long_thread")),                 # Long Thread
		"tug_time": TextFill.num(Balance.TUG_TIME + talent("shadow_hard_pull")),                         # Hard Pull
		"run_down_targets": str(Balance.RUN_DOWN_TARGETS + int(round(talent("shadow_wide_pack")))),      # Wide Pack
		# Frost, second batch.
		# Holy healer: the booms Sing Mercy and Sing Chorus describe.
		"benediction": fmt_amount(Balance.BENEDICTION_HEAL * per),
		"verses": str(int((Balance.VERSE_GAINS.get(id, [0]) as Array)[0])),   # the Verses it gives
		"chorale": fmt_amount(Balance.CHORALE_HEAL * per),
		"bulwark_time": TextFill.num(Balance.BULWARK_SONG_TIME + talent("holy_long_note")),   # Long Note
		"prism_time": TextFill.num(Balance.PRISM_TIME + talent("holy_long_glass")),   # Long Glass
		# Holy tank: the Censer (per stack of Incense, and a mote's heal).
		"pour_full": fmt_amount(Balance.POUR_OUT_PER_STACK * Balance.INCENSE_MAX * per * (1.0 + talent("holy_deep_pour") / 100.0)),   # Deep Pour
		"pour_motes": TextFill.num(Balance.DEEP_POUR_MOTE_PCT if talent_capstone("holy_deep_pour") else Balance.MOTE_SPEND_PCT),
		"absolve_full": fmt_amount(Balance.ABSOLVE_PER_STACK * Balance.ABSOLVE_MAX * Balance.REFERENCE_HEAL * per * (1.0 + talent("holy_absolution") / 100.0)),   # Absolution
		# Nature caster: the finishers with the mulch I have now, and with a full set.
		"mulch_now": str(mulch_count()),
		"mossback_now": fmt_amount((Balance.ABILITIES["mossback"]["damage"] + Balance.MOSSBACK_PER_PATCH * rich * mulch_count()) * per),
		"mossback_full": fmt_amount((Balance.ABILITIES["mossback"]["damage"] + Balance.MOSSBACK_PER_PATCH * rich * Balance.MULCH_MAX) * per),
		"vipers_now": fmt_amount((Balance.ABILITIES["chokingvipers"]["damage"] + Balance.VIPERS_PER_PATCH * rich * mulch_count()) * per),
		"vipers_full": fmt_amount((Balance.ABILITIES["chokingvipers"]["damage"] + Balance.VIPERS_PER_PATCH * rich * Balance.MULCH_MAX) * per),
		"thornshot_every": TextFill.ordinal(Balance.COMPOST_PATCH_EVERY if talent("nature_compost") > 0.0 else Balance.THORNSHOT_PATCH_EVERY),   # Compost
		"thornburst_dmg": fmt_amount(Balance.THORNBURST_DAMAGE * (1.0 + talent("nature_bramble_burst") / 100.0) * per),   # Bramble Burst
		"thornburst_radius": TextFill.num(Balance.BRAMBLE_BURST_RADIUS if talent_capstone("nature_bramble_burst") else Balance.THORNBURST_RADIUS),   # its capstone
		# Nature healer: the Shepherd.
		"dewfall_per": TextFill.num(talent("nature_morning_dew") if talent("nature_morning_dew") > 0.0 else Balance.DEWFALL_PER_BLOSSOM),   # Morning Dew
		"fawn_less": TextFill.num((1.0 - Balance.FAWN_FALLOFF) * 100.0),
		# Nature tank: the Colossus.
		"vine_fist_extra": str(Balance.VINE_FIST_EXTRA + int(round(talent("nature_broad_fist")))),   # Broad Fist
		"grasp_hold": TextFill.num(Balance.GRASP_HOLD + talent("nature_firm_hold")),   # Firm Hold
		"stomp_roots_time": TextFill.num(Balance.STOMP_ROOTS_TIME + talent("nature_spreading_roots")),   # Spreading Roots
		"awaken_time": TextFill.num(Balance.AWAKEN_TIME + talent("nature_wide_awake")),   # Wide Awake
		# Nature archer: Venomstring.
		"fang_extend": TextFill.num(Balance.FANG_EXTEND + talent("nature_long_fangs")),   # Long Fangs
		# Martial: what its talents change.
		"halberd_again": TextFill.num(Balance.HALBERD_AGAIN_PCT + talent("martial_twice_over")),   # Twice Over
		"axe_cleave_targets": str(1 + int(round(talent("martial_wide_cleave")))),   # Wide Cleave
		"clinch_time": TextFill.num(Balance.CLINCH_TIME + talent("martial_tight_clinch")),   # Tight Clinch
		"shake_off_pct": TextFill.num(Balance.SOAK_IT_UP_SHAKE_OFF if talent_capstone("martial_soak_it_up") else Balance.SHAKE_OFF_PCT),   # Soak It Up's capstone
		"pin_hits": str(Balance.PIN_SHADOW_HITS + int(round(talent("martial_pinned_down")))),   # Pinned Down
		"pin_time": TextFill.num(Balance.PIN_SHADOW_TIME + talent("martial_pinned_down", "values2")),
		"spread_arrows": str(Balance.SHARP_SPREAD_ARROWS + int(round(talent("martial_extra_arrows")))),   # Extra Arrows
		"heavy_cut": TextFill.num(Balance.FULL_DRAW_CUT if talent_capstone("martial_full_draw") else Balance.SHARP_HEAVY_CUT),   # Full Draw's capstone
		"loose_takes": "halves your Streak" if talent("martial_easy_release") <= 0.0
			else "takes away a %s of your Streak" % ("third" if int(round(talent("martial_easy_release"))) == 3 else "quarter"),   # Easy Release
		"rootguard_per": fmt_amount(Balance.ROOTGUARD_PER_BLOSSOM * per * absorb),
		"lattice_links": str(Balance.LATTICE_LINKS + int(round(talent("frost_wide_lattice")))),   # Wide Lattice
		"elk_per": fmt_amount(Balance.ELK_PER_BLOSSOM * per),
		"swing_incense": str(Balance.CENSER_SWING_INCENSE + int(round(talent("holy_heavy_chain")))),   # Heavy Chain
		"unfallen_time": TextFill.num(Balance.UNFALLEN_TIME + talent("holy_unbroken")),   # Unbroken
		"chorus_pct": TextFill.num(Balance.CHORUS_SPLASH_PCT * (1.0 + talent("holy_swelling_chorus") / 100.0)),   # Swelling Chorus
		"mote_heal": fmt_amount(Balance.MOTE_HEAL_SHARE * Balance.REFERENCE_HEAL * per),
		# Holy healer #2: a shattering prism (Wide Burst, Prismatic Burst).
		"shatter_radius": TextFill.num(Balance.PRISM_SHATTER_RADIUS + talent("holy_wide_burst")),
		"shatter_dmg": fmt_amount(Balance.PRISM_SHATTER_DAMAGE * per * (1.0 + talent("holy_prismatic_burst") / 100.0)),
		# Holy archer: the light a full prism holds, as damage (Deep Burn).
		"sunlit_full": fmt_amount(Balance.PRISM_CAP_HEALS * Balance.REFERENCE_HEAL * Balance.SUNLIT_DRAIN * per * (1.0 + talent("holy_deep_burn") / 100.0)),
		"breaker_dmg": fmt_amount(Balance.BREAKER_DAMAGE * per),
		"breaker_radius": TextFill.num(Balance.BREAKER_RADIUS + talent("holy_wide_break")),   # Wide Break
		"breaker_full": fmt_amount((Balance.BREAKER_DAMAGE + Balance.PRISM_CAP_HEALS * Balance.REFERENCE_HEAL * Balance.BREAKER_LIGHT) * per),
		"volley_dmg": fmt_amount(Balance.VOLLEY_DAMAGE * per),
		"winter_time": Stats.num(Balance.DEEPWINTER_TIME),
		"ward": fmt_amount(Balance.REFERENCE_HEAL * Balance.SNOW_WARD_SHARE * per * absorb),
		"ward_time": Stats.num(Balance.SNOW_WARD_TIME),
		"hide_time": Stats.num(Balance.WINTER_HIDE_TIME),
		"hide_pct": Stats.num(Balance.WINTER_HIDE_PCT),
		"edge_time": Stats.num(Balance.RIME_EDGE_TIME),
		"ice_frozen": "?" if base < 0 or fr == null or float(fr.weapon_damage_multiplier) <= 0.0 \
			else fmt_amount(base * per * Balance.ICEBREAKER_FROZEN_MULT / float(fr.weapon_damage_multiplier)),
		# Frost tank (Ice Layers) and Frost DPS (Glaze), with the talents that change them.
		"layer_pct": TextFill.num(ice_layer_pct(talent("frost_absorb"), talent("frost_deep_strata"))),   # Rime Ward, Deep Strata
		"slam_layer": fmt_amount(Balance.SHATTER_SLAM_PER_LAYER * per * (1.0 + talent("frost_packed_ice") / 100.0)),   # Packed Ice
		"quake_pct": TextFill.num(Balance.RIMEQUAKE_PCT_PER_LAYER + talent("frost_deep_tremor")),   # Deep Tremor
		"bitter_glaze": str(Balance.BITTER_EDGE_GLAZE + int(round(talent("frost_biting_hold")))),   # Biting Hold
		"glacial_time": TextFill.num(Balance.GLACIAL_BULWARK_TIME + talent("frost_old_ice")),   # Old Ice
		"blackfrost_time": TextFill.num(Balance.BLACK_FROST_TIME + talent("frost_long_dark")),   # Long Dark
	}
	var paint := func(v: String) -> String:
		return "[color=#%s]%s[/color]" % [NUM_COLOR.to_html(false), v] if bb else v
	for k in nums:
		text = text.replace("{%s}" % k, str(paint.call(str(nums[k]))))
	return TextFill.constants(text, paint)

static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]

static func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

## Does ability `id` have any number worked out from a coefficient and your
## Spell / Attack Power: damage, a damage-over-time effect, healing or a shield?
## Pure utility (Blink, a taunt, an interrupt, an armor buff, Grounding Surge)
## has none, so its detailed tooltip shows no Scaling section.
static func has_scaling(id: String) -> bool:
	var r := get_resource(id)
	if r == null:
		return false
	if float(r.damage) != 0.0 or float(r.weapon_damage_multiplier) != 0.0:
		return true
	if HEALS.has(id) or EXTRA_HITS.has(id) or dot_effect(id) != null:
		return true
	var text := str(r.description)
	if text.contains("{h:"):
		return true   # a shield worth a share of your Heal spell
	# Anything else the description quotes from your power (Discharge, Ground Out,
	# Snow Ward...): it reads differently with no power than with a lot of it.
	var none := func(_s: String) -> float: return 0.0
	var lots := func(s: String) -> float: return 1000.0 if s == Stats.SPELL_POWER or s == Stats.ATTACK_POWER else 0.0
	var w := equipped_weapon()
	return fill(id, text, none, w) != fill(id, text, lots, w)

## Rich tooltip (BBCode). `detailed` (Shift) adds the full breakdown: every
## number's source, Spell / Attack Power scaling, crit, haste, DoT maths.
static func tooltip_bbcode(id: String, detailed: bool = false) -> String:
	if Macros.is_macro(id):
		return Macros.tooltip_bbcode(id, detailed)
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
	lines.append(_c(dim, "%s %s" % [Categories.kind_name(cat) if cat != "" else "", "Spell" if kind == "Spell" else "Ability"]).strip_edges())
	# Keywords and names (Chilled, Frozen, other abilities) in orange.
	lines.append(Keywords.paint(fill(id, r.description, stat_of, w, true)))
	var teacher: String = Runes.rune_for_spell(id)
	if teacher != "":
		lines.append(_c(Runes.rarity_color(teacher), "Taught by the %s while it is on your gear." % Runes.rune_name(teacher)))

	# Cost / cast / cooldown line.
	var haste := Stats.haste_mult(float(stat_of.call(Stats.HASTE)))
	var res: String = RESOURCE_NAMES[r.resource_type]
	var bits: Array[String] = []
	if r.resource_cost > 0:
		bits.append("%d %s" % [cost_amount(r), res.capitalize()])
	if r.resource_generated > 0:
		bits.append("Generates %d %s" % [generated_of(str(r.id)), res.capitalize()])
	if SPENDS_ALL.has(str(r.id)):
		bits.append("All %s" % res.capitalize())
	if r.cast_type == 0:
		bits.append("Instant")
	elif r.cast_type == 2:
		bits.append("Channeled %s s" % secs(r.cast_time / haste))
	else:
		bits.append("%s s cast%s%s" % [secs(base_cast_time(r) / haste), " (can move)" if r.can_move_while_casting else "",
			" (instant on allies)" if INSTANT_ON_ALLIES.has(id) else ""])
	if r.cooldown > 0.0:
		bits.append("%s s cooldown" % Stats.num(cooldown_of(r)))
	if WHEEL_ORDER.has(id):
		bits = ["Rides on your Wheel: not used on its own"]   # (a weapon: its moves are the buttons)
	lines.append(_c(dim, "  •  ".join(bits)))
	var req: Array[String] = []
	if weapon_need(r) != "":
		req.append(weapon_need(r))
	if r.get("requires_shield"):
		req.append("a shield")
	if r.get("requires_off_hand"):
		req.append("an off hand")
	if r.requires_target:
		req.append("a target")
	if not req.is_empty():
		var missing: bool = (r.weapon_requirement == 1 and w.get("weapon", "") != "melee") \
			or (r.weapon_requirement == 2 and w.get("weapon", "") != "ranged") \
			or (bool(r.get("requires_two_hand")) and not has_two_hander_equipped()) \
			or (bool(r.get("requires_dual_wield")) and not has_dual_wield_equipped()) \
			or (bool(r.get("requires_shield")) and not has_shield_equipped()) \
			or (bool(r.get("requires_off_hand")) and not has_off_hand_item_equipped())
		lines.append(_c(Color(1, 0.4, 0.35) if missing else dim, "Requires " + _join_and(req)))
	if r.get("forbids_shield"):
		lines.append(_c(Color(1, 0.4, 0.35) if has_shield_equipped() else dim, NO_SHIELD_LINE))
	if is_interrupt(id):
		lines.append(_c(dim, interrupt_note()))

	if not detailed:
		lines.append(_c(dim, "[font_size=11]Hold Shift for details[/font_size]"))
		return "\n".join(lines)
	# Shift also explains every keyword / named thing the description mentions
	# (added at the very bottom, under the numbers).
	var explained := Keywords.explain(fill(id, r.description, stat_of, w, false), "a:" + id)

	# --- Details -------------------------------------------------------------
	var gold := Color(0.95, 0.75, 0.35)
	var sp := float(stat_of.call(Stats.SPELL_POWER))
	var ap := float(stat_of.call(Stats.ATTACK_POWER))
	var coef: Dictionary = Stats.POWER.get(kind, {})
	var sp_c := float(coef.get(Stats.SPELL_POWER, 0.0))
	var ap_c := float(coef.get(Stats.ATTACK_POWER, 0.0))
	var power := sp * sp_c + ap * ap_c
	var u := unit()
	# Only for abilities with a number to scale: pure utility (Blink, a taunt, an
	# armor buff, Grounding Surge) has no damage, healing or shield to work out.
	if has_scaling(id):
		lines.append("")
		lines.append(_c(gold, "Scaling"))
		lines.append("coefficient x (level %d base %s + %s of Spell Power + %s of Attack Power)" % [
			Stats._player_level(), Stats.num(u), _pct(sp_c), _pct(ap_c)])
		lines.append(_c(dim, "  Spell Power %s x %s = +%s" % [Stats.num(sp), _pct(sp_c), "%.1f" % (sp * sp_c)]))
		lines.append(_c(dim, "  Attack Power %s x %s = +%s" % [Stats.num(ap), _pct(ap_c), "%.1f" % (ap * ap_c)]))
		lines.append(_c(dim, "  = %s per 1.0 coefficient" % Stats.num(roundf(u + power))))
		var tm := float(r.get("threat_multiplier")) if r.get("threat_multiplier") != null else 1.0
		if tm != 1.0:
			lines.append(_c(dim, "  Threat: %sx damage" % Stats.num(tm)))

	var base := hit_base(id, w)
	var per := u + power
	if base != 0.0:
		lines.append("")
		lines.append(_c(gold, "Hit damage"))
		if base < 0.0:
			lines.append(_c(Color(1, 0.4, 0.35), "Equip a weapon: %sx weapon damage%s" % [
				Stats.num(float(r.weapon_damage_multiplier)), " + %s" % Stats.num(float(r.damage)) if r.damage > 0 else ""]))
		else:
			if uses_weapon(id):
				var wd := float(w.get("damage", 0.0))
				lines.append(_c(dim, "  Weapon: %s (%s) x %s" % [Stats.num(wd), str(w.get("name", "weapon")), Stats.num(float(r.weapon_damage_multiplier))]))
				if bool(r.get("requires_dual_wield")):   # it strikes with the Off Hand weapon too
					var off := offhand_for_tooltip()
					lines.append(_c(dim, "  Off Hand: %s (%s) x %s" % [Stats.num(float(off.get("damage", 0.0))), str(off.get("name", "weapon")),
						Stats.num(float(r.weapon_damage_multiplier))]))
				if r.damage > 0:
					lines.append(_c(dim, "  Flat bonus: +%s" % Stats.num(float(r.damage))))
			lines.append(_c(dim, "  Coefficient: %s" % ("%.2f" % base)))
			lines.append("  = %s damage per hit" % _c(NUM_COLOR, fmt_amount(base * per)))
			if r.tick_interval > 0.0 and r.cast_type == 2:
				var ticks := int(round(r.cast_time / r.tick_interval))
				lines.append(_c(dim, "  %d ticks over the channel (every %.2f s with haste) = %s total" % [
					ticks, r.tick_interval / haste, fmt_amount(base * per * ticks)]))
	var crit := Stats.crit_chance(tags, stat_of)
	if base != 0.0 or dot_effect(id) != null:
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
		lines.append(_c(dim, "  Tick coefficient: %s" % ("%.2f" % float(fx.tick_damage))))
		lines.append(_c(dim, "  Power: %s of the hit's power bonus = +%.1f" % [_pct(share), dot_power]))
		lines.append("  = %s damage every %.2f s for %s s" % [_c(NUM_COLOR, fmt_amount(dot_tick(id, stat_of))), tick, Stats.num(float(fx.duration))])
		lines.append(_c(dim, "  ~%d ticks = %s total%s%s" % [ticks, fmt_amount(dot_tick(id, stat_of) * ticks),
			"  •  faster with haste" if bool(fx.dot_hasted) else "",
			"  •  can crit" if bool(fx.dot_can_crit) else "  •  can't crit"]))

	if HEALS.has(id):
		lines.append("")
		lines.append(_c(gold, "Healing"))
		lines.append(_c(dim, "  Coefficient: %s  •  per 1.0: %s" % ["%.2f" % float(HEALS[id]), Stats.num(roundf(per))]))
		lines.append("  = %s %s" % [_c(NUM_COLOR, fmt_amount(float(HEALS[id]) * per)), "absorbed" if id == "rimeshell" or id == "intervalward" else "health"])

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
	if r.requires_target and not uses_weapon_reach(id) and r.cast_range > 0.0:
		extra.append("Range %s m" % Stats.num(float(r.cast_range)))
	elif r.weapon_requirement != 0 and w.has("attack_range"):
		extra.append("Weapon range %s m" % str(w["attack_range"]))
	if haste > 1.0:
		extra.append("Haste %s%%" % Stats.num((haste - 1.0) * 100.0))
	if not extra.is_empty():
		lines.append("")
		lines.append(_c(dim, "  •  ".join(extra)))
	lines.append(_c(dim, "Tags: " + ", ".join(tags)))
	if not explained.is_empty():
		lines.append("")
		lines.append(_c(gold, "Keywords"))
		for e in explained:
			lines.append(e)
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
	if Macros.is_macro(id):
		Macros.draw_icon(c, id)
		return
	var s := c.size
	var mid := s / 2.0
	var pad := 5.0
	var k: float = min(s.x, s.y) / 52.0
	var bg := Color(0.08, 0.16, 0.26)
	if CATEGORY_OF.has(id):
		bg = color_of(id).darkened(0.75)
	c.draw_rect(Rect2(Vector2(pad, pad), s - Vector2(pad, pad) * 2), bg, true)
	if _draw_unique(c, id, color_of(id), mid, k):
		return
	if ICON_FORM.has(id):
		_draw_form(c, str(ICON_FORM[id]), color_of(id), mid, k, pad)
		return
	match id:
		"trinket_1", "trinket_2":
			var gold := Color(0.95, 0.75, 0.35)
			var f := ThemeDB.fallback_font
			var n := "1" if id == "trinket_1" else "2"
			# The trinket you are wearing there: its own picture (+ the slot number).
			var tree := _tree()
			var tpd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
			var worn: String = str(tpd.equipment.get(TRINKET_SLOTS[id], "")) if tpd else ""
			if worn != "":
				UI.draw_item_icon(c, worn, false)
				c.draw_string_outline(f, Vector2(s.x - pad - 11 * k, s.y - pad - 3 * k), n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), 3, Color.BLACK)
				c.draw_string(f, Vector2(s.x - pad - 11 * k, s.y - pad - 3 * k), n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), gold)
				return
			# Nothing there: a gem on a chain + the slot number
			c.draw_arc(mid + Vector2(0, -6) * k, 9.0 * k, PI * 1.1, PI * 1.9, 10, gold, 1.8 * k, true)
			var gem := PackedVector2Array([mid + Vector2(0, -6) * k, mid + Vector2(9, 3) * k,
				mid + Vector2(0, 15) * k, mid + Vector2(-9, 3) * k])
			c.draw_colored_polygon(gem, Color(0.3, 0.95, 0.55))
			gem.append(gem[0])
			c.draw_polyline(gem, gold, 1.8 * k, true)
			c.draw_circle(mid + Vector2(-2, 1) * k, 2.2 * k, Color(0.9, 1, 0.95))
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
# Generic icon shapes, tinted with the ability's book color.
# (Fallback only: every current ability has its own icon in _draw_unique.)
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
		"interrupt":
			# Broken spell: a circle with a slash through it.
			c.draw_circle(mid, 13.0 * k, Color(col, 0.3))
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, light, 2.5 * k, true)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(9, -9) * k, light, 3.5 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 17.0 * k, 1.8 * k, col)
		_:
			c.draw_rect(Rect2(Vector2(pad, pad) * 2, s - Vector2(pad, pad) * 4), col, true)

# --- Unique ability icons -----------------------------------------------------------
# Every ability has its own picture (no two share an icon). Drawn in the
# ability's book color on its dark book background. Returns false for ids that
# have no unique icon here (they use the custom icons in draw_icon or a form).

## Holy healer: the colour of each Hymn, and of the Verses that match it
## (the ring around the healer, the Verse pips, the Sing icons).
const HYMN_COLORS := {"mercy": Color(1.0, 0.8, 0.3), "chorus": Color(0.95, 0.95, 1.0), "vigil": Color(0.45, 0.7, 1.0)}

## A musical note (an eighth note) with its head at `at`.
## A small censer (Holy tank icons): a round body under a domed lid, glowing.
static func _censer(c: Control, at: Vector2, k: float, body: Color, glow: Color) -> void:
	c.draw_circle(at, 9.0 * k, Color(glow, 0.25))
	c.draw_circle(at + Vector2(0, 1.5) * k, 5.5 * k, body.darkened(0.15))
	c.draw_arc(at + Vector2(0, -1) * k, 5.0 * k, PI, TAU, 10, body.lightened(0.3), 2.0 * k, true)
	c.draw_circle(at + Vector2(0, 1.5) * k, 2.2 * k, glow)

## A small prism (Holy healer #2 icons): a crystal, two triangles point to point.
static func _prism(c: Control, at: Vector2, k: float, body: Color, edge: Color) -> void:
	var top := PackedVector2Array([at + Vector2(0, -12) * k, at + Vector2(7, 0) * k, at + Vector2(-7, 0) * k])
	var bottom := PackedVector2Array([at + Vector2(-7, 0) * k, at + Vector2(7, 0) * k, at + Vector2(0, 9) * k])
	c.draw_colored_polygon(top, body)
	c.draw_colored_polygon(bottom, body.darkened(0.15))
	c.draw_line(at + Vector2(0, -12) * k, at + Vector2(0, 9) * k, edge, 1.2 * k, true)

static func _note(c: Control, at: Vector2, k: float, color: Color) -> void:
	c.draw_set_transform(at, -0.35, Vector2(1.3, 1.0))
	c.draw_circle(Vector2.ZERO, 3.5 * k, color)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_line(at + Vector2(3.6, -1) * k, at + Vector2(3.6, -14) * k, color, 1.8 * k, true)
	c.draw_line(at + Vector2(3.6, -14) * k, at + Vector2(8.5, -9) * k, color, 1.8 * k, true)

static func _pts(mid: Vector2, k: float, raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in raw:
		out.append(mid + (v as Vector2) * k)
	return out

## Plain arrow shaft + fletching, pointing to the top right (tip drawn by the caller at ~(11, -11)).
static func _arrow_shaft(c: Control, mid: Vector2, k: float, fletch: Color) -> void:
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(9, -9) * k, Color(0.75, 0.55, 0.35), 2.5 * k, true)
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-17, 8) * k, fletch, 2.0 * k, true)
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-8, 17) * k, fletch, 2.0 * k, true)

## Sword pointing to the top right; `glow` behind the blade.
static func _sword(c: Control, mid: Vector2, k: float, glow: Color) -> void:
	c.draw_line(mid + Vector2(-8, 8) * k, mid + Vector2(13, -13) * k, Color(glow, 0.5), 7.0 * k, true)
	c.draw_line(mid + Vector2(-6, 6) * k, mid + Vector2(12, -12) * k, Color(0.92, 0.92, 0.96), 3.5 * k, true)
	c.draw_line(mid + Vector2(-11, 1) * k, mid + Vector2(-1, 11) * k, glow, 3.0 * k, true)
	c.draw_line(mid + Vector2(-6, 6) * k, mid + Vector2(-13, 13) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)

## A hole in the ground seen at a slant (`half` wide and high from its middle):
## black inside, with a rim. (The Shadow caster's Breach: scripts/breach_fx.gd is the real one.)
static func _hole(c: Control, at: Vector2, half: Vector2, rim: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * half.x, sin(a) * half.y))
	c.draw_colored_polygon(pts, Color(0.05, 0.02, 0.09))
	pts.append(pts[0])
	c.draw_polyline(pts, rim, w, true)

## A clawing hand on an arm, from `base` along `dir` (a unit vector), `length`
## long in all: the arm, the palm, and four fingers that spread and hook.
static func _claw(c: Control, base: Vector2, dir: Vector2, length: float, arm: Color, nails: Color, w: float) -> void:
	var palm := base + dir * length * 0.66
	c.draw_line(base, palm, arm, w * 1.5, true)
	c.draw_circle(palm, w * 1.25, arm)
	for i in 4:
		var spread := (i - 1.5) * 0.4
		var finger := dir.rotated(spread)
		var knuckle := palm + finger * length * 0.2
		c.draw_line(palm, knuckle, arm, w * 0.8, true)
		c.draw_line(knuckle, knuckle + finger.rotated(-spread * 1.6) * length * 0.16, nails, w * 0.75, true)

static func _star(c: Control, at: Vector2, r: float, col: Color, points: int = 4) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := PI * i / points - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.35
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)

static func _flame(c: Control, at: Vector2, s: float, outer: Color, inner: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12) * s, at + Vector2(6, -2) * s, at + Vector2(5, 6) * s,
		at + Vector2(0, 9) * s, at + Vector2(-5, 6) * s, at + Vector2(-6, -2) * s, at + Vector2(-2, -5) * s]), outer)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4) * s, at + Vector2(3, 2) * s, at + Vector2(0, 7) * s,
		at + Vector2(-3, 2) * s]), inner)

static func _zigzag(c: Control, mid: Vector2, k: float, raw: Array, col: Color, w: float) -> void:
	c.draw_polyline(_pts(mid, k, raw), col, w * k, true)

## A small standing figure (head and body) with its feet at `at`: the Arcane
## tank and its Reflections.
static func _figure(c: Control, at: Vector2, s: float, col: Color) -> void:
	c.draw_circle(at + Vector2(0, -17) * s, 3.6 * s, col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-5.5, -12) * s, at + Vector2(5.5, -12) * s,
		at + Vector2(3.5, 0) * s, at + Vector2(-3.5, 0) * s]), col)

## The red of a Hound's hide (Shadow melee; scripts/hound.gd is the real one).
const HOUND_RED := Color(0.82, 0.16, 0.22)

## A Hound's head from the side, looking right (`flip` -1: looking left): red
## hide, a horn swept back, teeth, one burning eye. `open` (0-1) = how far its
## jaws are apart.
static func _hound_head(c: Control, at: Vector2, s: float, horn: Color, eye: Color, open: float = 0.6, flip: float = 1.0) -> void:
	var f := Vector2(flip, 1.0) * s
	var drop := 1.5 + 6.0 * clampf(open, 0.0, 1.0)
	# The lower jaw, behind the rest.
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 3) * f, at + Vector2(2, 2.5) * f,
		at + Vector2(11.5, 1.5 + drop) * f, at + Vector2(9.5, 3.8 + drop) * f, at + Vector2(-5, 8.5) * f]), HOUND_RED.darkened(0.3))
	# The horn.
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-5, -7) * f, at + Vector2(0.5, -8.5) * f, at + Vector2(-11, -17) * f]), horn)
	# Skull and muzzle.
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -5) * f, at + Vector2(-3, -9.5) * f, at + Vector2(5, -6) * f,
		at + Vector2(13.5, -2.5) * f, at + Vector2(13.5, 0.8) * f, at + Vector2(2, 2.2) * f, at + Vector2(-9, 5) * f]), HOUND_RED)
	# Teeth, hanging from the upper jaw.
	for i in 3:
		var x := 5.0 + i * 3.1
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(x - 1.2, 1.3) * f, at + Vector2(x + 1.2, 1.0) * f,
			at + Vector2(x, 4.6) * f]), Color(0.97, 0.95, 1.0))
	c.draw_circle(at + Vector2(3.2, -4.2) * f, 1.8 * s, eye)
	c.draw_circle(at + Vector2(13.0, -1.2) * f, 1.1 * s, HOUND_RED.darkened(0.55))

## The pale thread of a puppet String (Shadow healer; scripts/puppeteer.gd draws the real ones).
const STRING_PALE := Color(0.93, 0.86, 1.0)
const HEAL_GREEN := Color(0.45, 1.0, 0.45)

## A puppet String from `a` down to `b`, with the knot it ends in.
static func _thread(c: Control, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	c.draw_line(a, b, col, w, true)
	c.draw_circle(b, w * 1.1, col)

## A demon's hand seen from the front, reaching down from `at` (its wrist): a
## palm and four clawed fingers. `s` = its size, `flip` -1 mirrors it.
static func _demon_hand(c: Control, at: Vector2, s: float, hide: Color, nail: Color, flip: float = 1.0) -> void:
	var f := Vector2(flip, 1.0) * s
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -3) * f, at + Vector2(4, -3) * f, at + Vector2(5.5, 4) * f,
		at + Vector2(-5.5, 4) * f]), hide)
	for i in 4:
		var x := -4.5 + i * 3.0
		c.draw_line(at + Vector2(x, 3.5) * f, at + Vector2(x * 1.25, 9.0) * f, hide, 2.0 * s, true)
		c.draw_line(at + Vector2(x * 1.25, 9.0) * f, at + Vector2(x * 1.3, 11.5) * f, nail, 1.4 * s, true)

## A plus sign `r` from its middle to the end of an arm.
static func _plus(c: Control, at: Vector2, r: float, col: Color, w: float) -> void:
	c.draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, w, true)
	c.draw_line(at - Vector2(0, r), at + Vector2(0, r), col, w, true)

static func _draw_unique(c: Control, id: String, col: Color, mid: Vector2, k: float) -> bool:
	var light := col.lightened(0.5)
	var white := Color(0.95, 0.95, 1.0)
	match id:
		# --- Holy healer: the Hymns ---
		"psalm":
			# An open book with a note rising off its pages.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-15, -2), Vector2(-1, 2), Vector2(-1, 14), Vector2(-15, 10)]), light)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(15, -2), Vector2(1, 2), Vector2(1, 14), Vector2(15, 10)]), white)
			_note(c, mid + Vector2(2, -10) * k, k, col)
		"outpour":
			# A tipped vessel pouring a stream of light.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, -14), Vector2(0, -8), Vector2(-4, 2), Vector2(-16, -4)]), col.darkened(0.1))
			c.draw_line(mid + Vector2(-1, -5) * k, mid + Vector2(6, 15) * k, Color(light, 0.6), 7.0 * k, true)
			c.draw_line(mid + Vector2(-1, -5) * k, mid + Vector2(6, 15) * k, white, 2.5 * k, true)
		"lift":
			# Three chevrons of light rising.
			for i in 3:
				var y := 10.0 - i * 9.0
				c.draw_polyline(_pts(mid, k, [Vector2(-11, y + 6), Vector2(0, y - 3), Vector2(11, y + 6)]), white if i == 2 else light, 3.0 * k, true)
		"refrain":
			# A circle that comes back on itself, with a note in it.
			c.draw_arc(mid, 14.0 * k, 0.3, TAU - 0.4, 24, light, 3.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(14, -6), Vector2(19, 2), Vector2(9, 2)]), light)
			_note(c, mid + Vector2(-2, 3) * k, k * 0.8, white)
		"canticle":
			# Three notes along an arc.
			for i in 3:
				var a := PI + PI * (i + 0.5) / 3.0
				_note(c, mid + Vector2(cos(a), sin(a) + 0.6) * 13.0 * k, k * 0.7, white if i == 1 else light)
		"exultation":
			# Light bursting outward in every direction.
			for i in 16:
				var a := TAU * i / 16.0
				var r1 := 7.0 if i % 2 == 0 else 9.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * r1 * k, mid + Vector2(cos(a), sin(a)) * (17.0 if i % 2 == 0 else 13.0) * k, light, 2.0 * k, true)
			c.draw_circle(mid, 6.0 * k, white)
		"antiphon":
			# Two voices answering each other.
			c.draw_arc(mid + Vector2(-8, 0) * k, 8.0 * k, -0.9, 0.9, 10, white, 2.5 * k, true)
			c.draw_arc(mid + Vector2(-8, 0) * k, 13.0 * k, -0.8, 0.8, 10, Color(white, 0.6), 2.0 * k, true)
			c.draw_arc(mid + Vector2(8, 0) * k, 8.0 * k, PI - 0.9, PI + 0.9, 10, light, 2.5 * k, true)
			c.draw_arc(mid + Vector2(8, 0) * k, 13.0 * k, PI - 0.8, PI + 0.8, 10, Color(light, 0.6), 2.0 * k, true)
		"shelter":
			# A pointed arch of light over a small figure.
			c.draw_polyline(_pts(mid, k, [Vector2(-14, 14), Vector2(-14, -2), Vector2(0, -16), Vector2(14, -2), Vector2(14, 14)]), light, 3.5 * k, true)
			c.draw_circle(mid + Vector2(0, 0) * k, 3.5 * k, white)
			c.draw_line(mid + Vector2(0, 4) * k, mid + Vector2(0, 13) * k, white, 3.0 * k, true)
		"steadyvoice":
			# Level sound waves spreading to both sides.
			for i in 3:
				var r := (6.0 + i * 5.0) * k
				var cl := Color(white if i == 0 else light, 1.0 - i * 0.25)
				c.draw_arc(mid, r, -0.6, 0.6, 8, cl, 2.5 * k, true)
				c.draw_arc(mid, r, PI - 0.6, PI + 0.6, 8, cl, 2.5 * k, true)
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, light, 2.0 * k, true)
		"highnote":
			# A single note with a spark at its peak.
			_note(c, mid + Vector2(-3, 6) * k, k * 1.2, white)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				c.draw_line(mid + Vector2(10, -14) * k, mid + Vector2(10, -14) * k + Vector2(cos(a), sin(a)) * 5.0 * k, light, 1.8 * k, true)
		"reprise":
			# A repeat sign: two dots before a double bar.
			c.draw_line(mid + Vector2(4, -14) * k, mid + Vector2(4, 14) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(10, -14) * k, mid + Vector2(10, 14) * k, white, 4.5 * k, true)
			c.draw_circle(mid + Vector2(-4, -5) * k, 3.0 * k, white)
			c.draw_circle(mid + Vector2(-4, 5) * k, 3.0 * k, white)
		"swell":
			# A crescendo hairpin, widening to the right.
			c.draw_line(mid + Vector2(-15, 0) * k, mid + Vector2(15, -11) * k, white, 3.0 * k, true)
			c.draw_line(mid + Vector2(-15, 0) * k, mid + Vector2(15, 11) * k, light, 3.0 * k, true)
		"rest":
			# A musical rest: a quiet zigzag.
			c.draw_polyline(_pts(mid, k, [Vector2(-3, -15), Vector2(5, -6), Vector2(-4, 2), Vector2(4, 8)]), white, 3.5 * k, true)
			c.draw_arc(mid + Vector2(0, 11) * k, 4.5 * k, PI * 0.2, PI * 1.3, 8, white, 3.0 * k, true)
		"lastverse":
			# A figure rising under a halo.
			c.draw_arc(mid + Vector2(0, -12) * k, 7.0 * k, 0.0, TAU, 20, light, 2.0 * k, true)
			c.draw_circle(mid + Vector2(0, -4) * k, 4.0 * k, white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-7, 15), Vector2(-3, 1), Vector2(3, 1), Vector2(7, 15)]), white)
			c.draw_line(mid + Vector2(-14, 4) * k, mid + Vector2(-9, -6) * k, Color(light, 0.7), 2.0 * k, true)
			c.draw_line(mid + Vector2(14, 4) * k, mid + Vector2(9, -6) * k, Color(light, 0.7), 2.0 * k, true)
		# --- Holy tank: the Censer ---
		"censerswing":
			# The censer swung on its chain, a trail of light behind it.
			c.draw_line(mid + Vector2(-14, -14) * k, mid + Vector2(4, 2) * k, light, 2.0 * k, true)
			c.draw_arc(mid + Vector2(-14, -14) * k, 24.0 * k, 0.25, 1.35, 12, Color(white, 0.5), 3.0 * k, true)
			_censer(c, mid + Vector2(6, 5) * k, k, col, white)
		"hallowedarc":
			# A full circle swept by the censer.
			c.draw_arc(mid, 15.0 * k, 0.0, TAU, 32, Color(light, 0.75), 3.0 * k, true)
			c.draw_line(mid, mid + Vector2(10, -11) * k, light, 1.8 * k, true)
			_censer(c, mid + Vector2(11, -12) * k, k * 0.7, col, white)
			c.draw_circle(mid, 3.0 * k, white)
		"beckon":
			# A ray of light flicked out to the side, curling back.
			_censer(c, mid + Vector2(-9, 4) * k, k * 0.8, col, white)
			c.draw_line(mid + Vector2(-4, 2) * k, mid + Vector2(15, -10) * k, white, 2.5 * k, true)
			c.draw_arc(mid + Vector2(13, -6) * k, 4.0 * k, -PI * 0.5, PI * 0.6, 8, light, 2.0 * k, true)
		"pourout":
			# The censer tipped, a wave of light pouring out under it.
			_censer(c, mid + Vector2(-5, -8) * k, k * 0.8, col, white)
			for i in 3:
				c.draw_arc(mid + Vector2(0, 16) * k, (8.0 + i * 5.0) * k, PI * 1.1, PI * 1.9, 12, Color(white if i == 0 else light, 1.0 - i * 0.25), 2.5 * k, true)
		"absolve":
			# Light falling into an open hand.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-13, 6), Vector2(13, 6), Vector2(9, 14), Vector2(-9, 14)]), light)
			for x in [-6, 0, 6]:
				c.draw_circle(mid + Vector2(x, -6.0 - absf(x) * 0.6) * k, 2.6 * k, white)
			c.draw_line(mid + Vector2(0, -15) * k, mid + Vector2(0, 2) * k, Color(white, 0.5), 2.0 * k, true)
		"aureole":
			# A blazing ring of light around a small figure.
			for i in 12:
				var a := TAU * i / 12.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 13.0 * k, mid + Vector2(cos(a), sin(a)) * 17.0 * k, light, 2.0 * k, true)
			c.draw_arc(mid, 12.0 * k, 0.0, TAU, 28, white, 2.5 * k, true)
			c.draw_circle(mid + Vector2(0, -3) * k, 3.5 * k, white)
			c.draw_line(mid + Vector2(0, 1) * k, mid + Vector2(0, 8) * k, white, 3.0 * k, true)
		"gatherthelight":
			# Motes streaming in toward the middle.
			c.draw_circle(mid, 4.5 * k, white)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				var far := mid + Vector2(cos(a), sin(a)) * 15.0 * k
				c.draw_line(far, mid + Vector2(cos(a), sin(a)) * 7.0 * k, Color(light, 0.6), 1.6 * k, true)
				c.draw_circle(far, 2.4 * k, light)
		"raisethecenser":
			# The censer high up, rays of light falling from it.
			_censer(c, mid + Vector2(0, -9) * k, k * 0.8, col, white)
			for x in [-10, 0, 10]:
				c.draw_line(mid + Vector2(x * 0.3, -2) * k, mid + Vector2(x, 15) * k, Color(light, 0.7), 2.0 * k, true)
			c.draw_line(mid + Vector2(-15, 15) * k, mid + Vector2(15, 15) * k, light, 2.0 * k, true)
		"unfallen":
			# A figure standing inside a column of light.
			c.draw_rect(Rect2(mid + Vector2(-8, -16) * k, Vector2(16, 32) * k), Color(light, 0.3), true)
			c.draw_line(mid + Vector2(-8, -16) * k, mid + Vector2(-8, 16) * k, light, 1.5 * k, true)
			c.draw_line(mid + Vector2(8, -16) * k, mid + Vector2(8, 16) * k, light, 1.5 * k, true)
			c.draw_circle(mid + Vector2(0, -7) * k, 3.5 * k, white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-5, 13), Vector2(-3, -2), Vector2(3, -2), Vector2(5, 13)]), white)
		# --- Holy healer #2: the Prisms ---
		"setprism":
			# A crystal set down on the ground, with a small plus.
			_prism(c, mid + Vector2(-3, 2) * k, k, light, white)
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(10, 15) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(12, -14) * k, mid + Vector2(12, -6) * k, white, 2.5 * k, true)
			c.draw_line(mid + Vector2(8, -10) * k, mid + Vector2(16, -10) * k, white, 2.5 * k, true)
		"moveprism":
			# A crystal flickering from one spot to another.
			_prism(c, mid + Vector2(-9, 4) * k, k * 0.7, Color(light, 0.35), Color(white, 0.35))
			_prism(c, mid + Vector2(8, -4) * k, k * 0.8, light, white)
			c.draw_line(mid + Vector2(-4, 4) * k, mid + Vector2(2, -1) * k, Color(white, 0.6), 1.6 * k, true)
		"mendingray":
			# A steady beam into a small figure.
			c.draw_line(mid + Vector2(-16, 10) * k, mid + Vector2(8, -2) * k, light, 4.0 * k, true)
			c.draw_line(mid + Vector2(-16, 10) * k, mid + Vector2(8, -2) * k, white, 1.6 * k, true)
			c.draw_circle(mid + Vector2(11, -8) * k, 3.5 * k, white)
			c.draw_line(mid + Vector2(11, -4) * k, mid + Vector2(11, 5) * k, white, 3.0 * k, true)
		"brightlance":
			# A long spear of light, point up.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -16), Vector2(4, -6), Vector2(1.5, 15), Vector2(-1.5, 15), Vector2(-4, -6)]), white)
			c.draw_line(mid + Vector2(-9, -4) * k, mid + Vector2(9, -4) * k, light, 2.0 * k, true)
		"gleam":
			# A quick four-pointed sparkle.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -14), Vector2(3, -3), Vector2(14, 0), Vector2(3, 3), Vector2(0, 14),
				Vector2(-3, 3), Vector2(-14, 0), Vector2(-3, -3)]), white)
			c.draw_circle(mid, 3.0 * k, light)
		"prismward":
			# A shield shape cut like a crystal.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -15), Vector2(13, -8), Vector2(10, 7), Vector2(0, 15), Vector2(-10, 7), Vector2(-13, -8)]), Color(light, 0.55))
			c.draw_polyline(_pts(mid, k, [Vector2(0, -15), Vector2(0, 15)]), white, 1.5 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-13, -8), Vector2(0, 0), Vector2(13, -8)]), white, 1.5 * k, true)
		"piercinglight":
			# A thin beam stabbing through a mark.
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(16, -14) * k, white, 2.0 * k, true)
			c.draw_arc(mid + Vector2(6, -5) * k, 6.0 * k, 0.0, TAU, 16, Color(1.0, 0.5, 0.35), 2.2 * k, true)
			c.draw_circle(mid + Vector2(-16, 14) * k, 2.5 * k, light)
		"realign":
			# Three crystals in a triangle, arrows turning around them.
			for p in [Vector2(0, -9), Vector2(-9, 7), Vector2(9, 7)]:
				_prism(c, mid + p * k, k * 0.45, light, white)
			c.draw_arc(mid, 15.0 * k, -0.4, 1.2, 10, Color(white, 0.7), 2.0 * k, true)
			c.draw_arc(mid, 15.0 * k, PI - 0.4, PI + 1.2, 10, Color(white, 0.7), 2.0 * k, true)
		"shatterprism":
			# One crystal breaking into shards.
			_prism(c, mid, k * 0.7, light, white)
			for i in 6:
				var a := TAU * i / 6.0 + 0.4
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 10.0 * k, mid + Vector2(cos(a), sin(a)) * 15.0 * k, white, 2.0 * k, true)
		"shatterall":
			# Three crystals breaking at once.
			for p in [Vector2(0, -8), Vector2(-9, 7), Vector2(9, 7)]:
				_prism(c, mid + p * k, k * 0.4, light, white)
				for i in 4:
					var a := TAU * i / 4.0 + 0.8
					c.draw_line(mid + p * k + Vector2(cos(a), sin(a)) * 5.0 * k, mid + p * k + Vector2(cos(a), sin(a)) * 8.0 * k, Color(white, 0.8), 1.4 * k, true)
		"infuse":
			# Light pouring down into a crystal.
			_prism(c, mid + Vector2(0, 5) * k, k * 0.75, light, white)
			for x in [-5, 0, 5]:
				c.draw_line(mid + Vector2(x, -16) * k, mid + Vector2(x * 0.4, -6) * k, Color(white, 0.75), 1.8 * k, true)
		"kaleidoscope":
			# A ring of coloured facets.
			var hues: Array[Color] = [Color(1.0, 0.5, 0.5), Color(1.0, 0.85, 0.4), Color(0.5, 1.0, 0.6), Color(0.45, 0.75, 1.0), Color(0.8, 0.55, 1.0), Color(1.0, 1.0, 1.0)]
			for i in 6:
				var a0 := TAU * i / 6.0
				var a1 := TAU * (i + 1) / 6.0
				c.draw_colored_polygon(PackedVector2Array([mid, mid + Vector2(cos(a0), sin(a0)) * 15.0 * k,
					mid + Vector2(cos(a1), sin(a1)) * 15.0 * k]), Color(hues[i], 0.8))
			c.draw_circle(mid, 4.0 * k, white)
		# --- Holy archer: Lightstring (gold prisms) ---
		"prismarrow":
			# An arrow with a crystal for a head, stuck in the ground.
			c.draw_line(mid + Vector2(-12, -14) * k, mid + Vector2(2, 2) * k, Color(0.7, 0.55, 0.35), 2.5 * k, true)
			_prism(c, mid + Vector2(5, 6) * k, k * 0.6, Color(1.0, 0.82, 0.35), white)
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(14, 15) * k, light, 2.0 * k, true)
		"glimmershot":
			# A short golden arrow with a spark at its tip.
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(10, -6) * k, Color(1.0, 0.85, 0.4), 2.5 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(14, -9), Vector2(6, -8), Vector2(10, -2)]), white)
			c.draw_circle(mid + Vector2(14, -9) * k, 3.0 * k, Color(white, 0.6))
		"refractingshot":
			# One arrow hitting a crystal and splitting into three.
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-3, 0) * k, white, 2.5 * k, true)
			_prism(c, mid + Vector2(0, 2) * k, k * 0.5, Color(1.0, 0.82, 0.35), white)
			for dy in [-9, 0, 9]:
				c.draw_line(mid + Vector2(4, 0) * k, mid + Vector2(16, dy) * k, Color(1.0, 0.9, 0.5), 2.0 * k, true)
		"sunlitarrow":
			# An arrow inside a small sun.
			c.draw_circle(mid, 9.0 * k, Color(1.0, 0.8, 0.3, 0.5))
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 11.0 * k, mid + Vector2(cos(a), sin(a)) * 15.0 * k, Color(1.0, 0.85, 0.4), 2.0 * k, true)
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(12, -12) * k, white, 2.5 * k, true)
		"prismbreaker":
			# An arrow through a cracked crystal.
			_prism(c, mid + Vector2(2, 2) * k, k * 0.8, Color(1.0, 0.82, 0.35), white)
			c.draw_polyline(_pts(mid, k, [Vector2(-2, -8), Vector2(3, -2), Vector2(-1, 3), Vector2(4, 9)]), Color(0.3, 0.2, 0.1), 1.6 * k, true)
			c.draw_line(mid + Vector2(-16, -14) * k, mid + Vector2(14, 14) * k, white, 2.0 * k, true)
		"stepoflight":
			# A figure fading out on the left, whole again beside a crystal.
			c.draw_circle(mid + Vector2(-10, -5) * k, 3.0 * k, Color(white, 0.35))
			c.draw_line(mid + Vector2(-10, -1) * k, mid + Vector2(-10, 8) * k, Color(white, 0.35), 3.0 * k, true)
			c.draw_circle(mid + Vector2(3, -5) * k, 3.0 * k, white)
			c.draw_line(mid + Vector2(3, -1) * k, mid + Vector2(3, 8) * k, white, 3.0 * k, true)
			_prism(c, mid + Vector2(12, 4) * k, k * 0.45, Color(1.0, 0.82, 0.35), white)
		"spectrumvolley":
			# Three crystals, each shooting a ray outward.
			for p in [Vector2(-9, 8), Vector2(0, -6), Vector2(9, 8)]:
				_prism(c, mid + p * k, k * 0.4, Color(1.0, 0.82, 0.35), white)
				var away: Vector2 = p.normalized()
				c.draw_line(mid + p * k + away * 5.0 * k, mid + p * k + away * 12.0 * k, Color(1.0, 0.9, 0.5), 1.8 * k, true)
		"singmercy":
			# Mercy: a heart inside the ring of the Hymn.
			c.draw_arc(mid, 16.0 * k, 0.0, TAU, 28, HYMN_COLORS["mercy"], 2.0 * k, true)
			c.draw_circle(mid + Vector2(-4.5, -3) * k, 5.5 * k, HYMN_COLORS["mercy"].lightened(0.3))
			c.draw_circle(mid + Vector2(4.5, -3) * k, 5.5 * k, HYMN_COLORS["mercy"].lightened(0.3))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-9.8, -1), Vector2(9.8, -1), Vector2(0, 11)]), HYMN_COLORS["mercy"].lightened(0.3))
		"singchorus":
			# Chorus: three voices together inside the ring.
			c.draw_arc(mid, 16.0 * k, 0.0, TAU, 28, HYMN_COLORS["chorus"], 2.0 * k, true)
			for p: Vector2 in [Vector2(-7, 3), Vector2(7, 3), Vector2(0, -6)]:
				c.draw_circle(mid + p * k, 6.0 * k, Color(HYMN_COLORS["chorus"], 0.55))
			c.draw_circle(mid + Vector2(0, 0) * k, 3.0 * k, white)
		"singvigil":
			# Vigil: a watchful eye inside the ring.
			c.draw_arc(mid, 16.0 * k, 0.0, TAU, 28, HYMN_COLORS["vigil"], 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, 0), Vector2(-5, -6), Vector2(5, -6), Vector2(12, 0), Vector2(5, 6), Vector2(-5, 6)]),
				HYMN_COLORS["vigil"].lightened(0.2))
			c.draw_circle(mid, 4.0 * k, Color(0.1, 0.15, 0.3))
			c.draw_circle(mid + Vector2(-1.2, -1.2) * k, 1.4 * k, white)
		# --- Rune spells ---
		"polarstrike":
			# A blade between a positive and a negative charge.
			var spark := Color(0.45, 0.55, 1.0)
			var plus := Color(0.6, 0.9, 1.0)
			var minus := Color(1.0, 0.5, 0.4)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(11, -11) * k, Color(spark, 0.5), 7.0 * k, true)
			c.draw_line(mid + Vector2(-7, 7) * k, mid + Vector2(10, -10) * k, Color(0.92, 0.92, 0.96), 3.5 * k, true)
			c.draw_line(mid + Vector2(-7, 7) * k, mid + Vector2(-13, 13) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			c.draw_line(mid + Vector2(-16, -10) * k, mid + Vector2(-6, -10) * k, plus, 2.8 * k, true)
			c.draw_line(mid + Vector2(-11, -15) * k, mid + Vector2(-11, -5) * k, plus, 2.8 * k, true)
			c.draw_line(mid + Vector2(6, 11) * k, mid + Vector2(16, 11) * k, minus, 2.8 * k, true)
		"frostfirebolt":
			# One bolt split along its flight: frost on one side, flame on the other.
			var frost := Color(0.45, 0.85, 1.0)
			var fire := Color(0.98, 0.5, 0.15)
			var tail := Vector2(-1, 1).normalized()
			var o := mid + Vector2(4, -4) * k
			for i in range(3, 0, -1):
				var back: Vector2 = o + tail * i * 6.5 * k
				c.draw_circle(back + Vector2(-3, -3) * k, (5.5 - i * 1.2) * k, Color(frost, 0.2 + 0.1 * (3 - i)))
				c.draw_circle(back + Vector2(3, 3) * k, (5.5 - i * 1.2) * k, Color(fire, 0.2 + 0.1 * (3 - i)))
			c.draw_circle(o, 10.0 * k, frost)
			var side := PackedVector2Array()
			for i in 13:
				var a := -PI / 4.0 + PI * i / 12.0
				side.append(o + Vector2(cos(a), sin(a)) * 10.0 * k)
			c.draw_colored_polygon(side, fire)
			c.draw_circle(o, 4.5 * k, white)
		# --- Fire ---
		"fireball":
			c.draw_circle(mid + Vector2(-6, 6) * k, 4.0 * k, Color(col, 0.35))
			c.draw_circle(mid + Vector2(-11, 11) * k, 2.5 * k, Color(col, 0.2))
			_flame(c, mid + Vector2(3, -1) * k, 1.3 * k, col, Color(1.0, 0.9, 0.4))
		"searingstrike":
			_sword(c, mid, k, col)
			_flame(c, mid + Vector2(10, -11) * k, 0.8 * k, col, Color(1.0, 0.9, 0.4))
		"quench":
			# A glowing blade driven down into a trough of water, steam rising off it.
			c.draw_line(mid + Vector2(9, -16) * k, mid + Vector2(-2, 7) * k, Color(col, 0.5), 7.5 * k, true)
			c.draw_line(mid + Vector2(9, -16) * k, mid + Vector2(-2, 7) * k, Color(1.0, 0.9, 0.4), 3.5 * k, true)
			c.draw_line(mid + Vector2(4, -18) * k, mid + Vector2(14, -13) * k, Color(0.55, 0.5, 0.48), 3.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-16, 7) * k, Vector2(32, 9) * k), Color(0.22, 0.45, 0.7), true)
			c.draw_line(mid + Vector2(-16, 7) * k, mid + Vector2(16, 7) * k, Color(0.7, 0.9, 1.0), 2.0 * k, true)
			for sx in [-12.0, -6.0, 9.0]:
				c.draw_arc(mid + Vector2(sx, 0) * k, 3.5 * k, PI * 0.9, PI * 2.0, 8, white, 1.8 * k, true)
				c.draw_arc(mid + Vector2(sx + 3.0, -7) * k, 3.0 * k, PI * 0.0, PI * 1.1, 8, Color(white, 0.6), 1.5 * k, true)
		"pitcharrow":
			# An arrow whose head is a dark blob of pitch, drops falling off it.
			_arrow_shaft(c, mid, k, col)
			c.draw_circle(mid + Vector2(10, -10) * k, 7.0 * k, Color(0.12, 0.09, 0.08))
			c.draw_arc(mid + Vector2(10, -10) * k, 7.0 * k, PI * 1.1, PI * 1.9, 10, light, 1.8 * k, true)
			for pd in [Vector2(6, 0), Vector2(13, 3), Vector2(1, -3)]:
				c.draw_circle(mid + (pd as Vector2) * k, 2.2 * k, Color(0.12, 0.09, 0.08))
			_flame(c, mid + Vector2(-9, -9) * k, 0.55 * k, col, Color(1.0, 0.9, 0.4))
		"cinderrain":
			# Burning arrows falling onto a glowing patch of ground.
			c.draw_line(mid + Vector2(-17, 15) * k, mid + Vector2(17, 15) * k, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			for ax in [-11.0, 0.0, 11.0]:
				var top := mid + Vector2(ax + 6.0, -17.0 + absf(ax) * 0.35) * k
				var tip := mid + Vector2(ax - 2.0, 9.0 - absf(ax) * 0.25) * k
				c.draw_line(top, tip, Color(0.75, 0.55, 0.35), 2.2 * k, true)
				c.draw_circle(tip, 3.2 * k, col)
				c.draw_circle(tip, 1.5 * k, white)
		"cinderwing":
			# A phoenix with its wings spread, a white-hot heart, a trailing tail.
			for side: float in [-1.0, 1.0]:
				var wing := _pts(mid, k, [Vector2(0, -2), Vector2(8 * side, -12), Vector2(18 * side, -14),
					Vector2(14 * side, -5), Vector2(17 * side, 0), Vector2(10 * side, 2), Vector2(4 * side, 5)])
				c.draw_colored_polygon(wing, Color(col, 0.9))
				wing.append(wing[0])
				c.draw_polyline(wing, light, 1.4 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -8), Vector2(4, 0), Vector2(2, 8), Vector2(0, 17), Vector2(-2, 8), Vector2(-4, 0)]), Color(1.0, 0.9, 0.4))
			c.draw_circle(mid + Vector2(0, -10) * k, 3.2 * k, Color(1.0, 0.9, 0.4))
			c.draw_circle(mid + Vector2(0, 1) * k, 2.2 * k, white)
		"flare":
			# A blade swung through a wide arc, flames flying off the sweep.
			c.draw_arc(mid + Vector2(0, 13) * k, 21.0 * k, PI * 1.12, PI * 1.88, 16, Color(col, 0.55), 6.0 * k, true)
			c.draw_arc(mid + Vector2(0, 13) * k, 21.0 * k, PI * 1.12, PI * 1.88, 16, light, 2.0 * k, true)
			for fa in [PI * 1.25, PI * 1.5, PI * 1.75]:
				_flame(c, mid + Vector2(0, 13) * k + Vector2(cos(fa), sin(fa)) * 20.0 * k, 0.6 * k, col, Color(1.0, 0.9, 0.4))
			c.draw_line(mid + Vector2(-3, 16) * k, mid + Vector2(6, 2) * k, Color(0.92, 0.92, 0.96), 3.5 * k, true)
			c.draw_line(mid + Vector2(-7, 11) * k, mid + Vector2(2, 16) * k, light, 2.6 * k, true)
		"flamingarrow":
			_arrow_shaft(c, mid, k, col)
			_flame(c, mid + Vector2(10, -10) * k, 0.9 * k, col, Color(1.0, 0.9, 0.4))
		"flamenova":
			for i in 8:
				var a := TAU * i / 8.0
				_flame(c, mid + Vector2(cos(a), sin(a)) * 12.0 * k, 0.55 * k, col, light)
			c.draw_circle(mid, 5.0 * k, Color(1.0, 0.9, 0.4))
		"ventflames":
			# Flames bursting up through a slotted vent.
			for x in [-9.0, 9.0]:
				_flame(c, mid + Vector2(x, -1) * k, 0.8 * k, col, Color(1.0, 0.9, 0.4))
			_flame(c, mid + Vector2(0, -5) * k, 1.15 * k, light, white)
			c.draw_rect(Rect2(mid + Vector2(-16, 9) * k, Vector2(32, 6) * k), Color(0.55, 0.5, 0.48), true)
			for x in [-9.0, 0.0, 9.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 2.5, 10.5) * k, Vector2(5, 3) * k), Color(0.1, 0.05, 0.03), true)
		"kilnblast":
			# A kiln's arched mouth with a white-hot ball of fire leaving it.
			c.draw_arc(mid + Vector2(-5, 6) * k, 12.0 * k, PI, TAU, 16, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_line(mid + Vector2(-17, 6) * k, mid + Vector2(-17, 15) * k, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_line(mid + Vector2(7, 6) * k, mid + Vector2(7, 15) * k, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_circle(mid + Vector2(-5, 7) * k, 6.0 * k, Color(col, 0.6))
			c.draw_circle(mid + Vector2(9, -8) * k, 8.0 * k, col)
			c.draw_circle(mid + Vector2(9, -8) * k, 4.5 * k, white)
			c.draw_line(mid + Vector2(-2, 3) * k, mid + Vector2(4, -3) * k, light, 2.5 * k, true)
		"slowfuse":
			# A round charge with a long curling fuse and a spark at its end.
			c.draw_circle(mid + Vector2(-4, 6) * k, 10.0 * k, Color(0.16, 0.13, 0.13))
			c.draw_arc(mid + Vector2(-4, 6) * k, 10.0 * k, 0, TAU, 24, col, 2.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(2, -2), Vector2(7, -8), Vector2(4, -13), Vector2(10, -16), Vector2(15, -11)]), light, 2.2 * k, true)
			for i in 6:
				var sa := TAU * i / 6.0
				c.draw_line(mid + Vector2(15, -11) * k, mid + (Vector2(15, -11) + Vector2(cos(sa), sin(sa)) * 5.0) * k, Color(1.0, 0.9, 0.4), 1.6 * k, true)
			c.draw_circle(mid + Vector2(15, -11) * k, 2.2 * k, white)
		"rekindle":
			# Two arrows circling a flame (the burn starting over).
			_flame(c, mid + Vector2(0, -1) * k, 0.95 * k, col, Color(1.0, 0.9, 0.4))
			c.draw_arc(mid, 15.0 * k, PI * 0.15, PI * 0.85, 12, light, 2.4 * k, true)
			c.draw_arc(mid, 15.0 * k, PI * 1.15, PI * 1.85, 12, light, 2.4 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-18, 7), Vector2(-10, 5), Vector2(-14, 12)]), light)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(18, -7), Vector2(10, -5), Vector2(14, -12)]), light)
		"walloffire":
			# A row of flames standing on a glowing line.
			c.draw_rect(Rect2(mid + Vector2(-18, 11) * k, Vector2(36, 4) * k), light, true)
			for i in 4:
				var wx := -13.5 + i * 9.0
				_flame(c, mid + Vector2(wx, (-1.0 if i % 2 == 0 else 2.0)) * k, (1.0 if i % 2 == 0 else 0.8) * k, col, Color(1.0, 0.9, 0.4))
		"immolate":
			# A dark figure wrapped in a ring of flames.
			for i in 6:
				var ia := TAU * i / 6.0 + PI / 6.0
				_flame(c, mid + Vector2(cos(ia) * 13.0, sin(ia) * 12.0 + 2.0) * k, 0.6 * k, col, Color(1.0, 0.9, 0.4))
			c.draw_circle(mid + Vector2(0, -5) * k, 4.5 * k, Color(0.14, 0.1, 0.1))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-6, 12), Vector2(-4, 0), Vector2(4, 0), Vector2(6, 12)]), Color(0.14, 0.1, 0.1))
		"stoke":
			# A flame fanned from below: two upward chevrons under it.
			_flame(c, mid + Vector2(0, -6) * k, 1.25 * k, col, Color(1.0, 0.9, 0.4))
			for i in 2:
				var y := 9.0 + i * 6.0
				c.draw_polyline(_pts(mid, k, [Vector2(-9, y + 4), Vector2(0, y - 2), Vector2(9, y + 4)]), white if i == 0 else light, 2.4 * k, true)
		"embervolley":
			# A fan of embers flying out to the right, each with a short tail.
			for i in 5:
				var a := deg_to_rad(-36.0 + 18.0 * i)
				var d := Vector2(cos(a), sin(a))
				var tip := mid + Vector2(-14, 0) * k + d * (22.0 + (4.0 if i % 2 == 0 else 0.0)) * k
				c.draw_line(tip - d * 9.0 * k, tip, Color(col, 0.6), 2.0 * k, true)
				c.draw_colored_polygon(PackedVector2Array([tip + d * 4.0 * k, tip + d.orthogonal() * 3.0 * k,
					tip - d * 4.0 * k, tip - d.orthogonal() * 3.0 * k]), Color(1.0, 0.9, 0.4) if i == 2 else light)
			c.draw_circle(mid + Vector2(-14, 0) * k, 3.5 * k, white)
		"furnacebreath":
			# An open maw on the left breathing a widening cone of fire.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-10, 0), Vector2(17, -15), Vector2(17, 15)]), Color(col, 0.55))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-8, 0), Vector2(15, -8), Vector2(15, 8)]), Color(1.0, 0.9, 0.4))
			for y in [-11.0, 0.0, 11.0]:
				c.draw_circle(mid + Vector2(16, y) * k, 3.0 * k, light)
			c.draw_arc(mid + Vector2(-13, 0) * k, 7.0 * k, PI * 0.3, PI * 1.7, 14, white, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, -6), Vector2(-8, -6), Vector2(-10, -2)]), white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, 6), Vector2(-8, 6), Vector2(-10, 2)]), white)
		"crucible":
			# A crucible seen from the side: a dark bowl brimming with molten glow.
			c.draw_arc(mid + Vector2(0, 14) * k, 17.0 * k, 0, TAU, 28, Color(col, 0.5), 1.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-13, -6), Vector2(13, -6), Vector2(8, 12), Vector2(-8, 12)]), Color(0.2, 0.16, 0.15))
			c.draw_polyline(_pts(mid, k, [Vector2(-13, -6), Vector2(-8, 12), Vector2(8, 12), Vector2(13, -6)]), light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-12, -6) * k, mid + Vector2(12, -6) * k, Color(1.0, 0.9, 0.4), 3.2 * k, true)
			_flame(c, mid + Vector2(0, -13) * k, 0.7 * k, col, Color(1.0, 0.9, 0.4))
		"cinderstep":
			# A boot striding off a trail of cinders.
			for i in 4:
				c.draw_circle(mid + Vector2(-16.0 + i * 6.0, 13.0 - (i % 2) * 2.0) * k, (2.0 + i * 0.4) * k, Color(col, 0.35 + 0.15 * i))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -15), Vector2(8, -15), Vector2(9, 0), Vector2(17, 5), Vector2(17, 10), Vector2(0, 10)]), light)
			c.draw_line(mid + Vector2(0, 10) * k, mid + Vector2(17, 10) * k, white, 2.0 * k, true)
			c.draw_line(mid + Vector2(-9, -9) * k, mid + Vector2(-3, -9) * k, white, 1.8 * k, true)
			c.draw_line(mid + Vector2(-12, -2) * k, mid + Vector2(-4, -2) * k, white, 1.8 * k, true)
		"heatsink":
			# Cooling fins soaking up heat, a glow building at their base.
			for x in [-12.0, -4.0, 4.0, 12.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 2.0, -14) * k, Vector2(4, 20) * k), Color(0.62, 0.6, 0.6), true)
			c.draw_rect(Rect2(mid + Vector2(-16, 6) * k, Vector2(32, 5) * k), Color(0.45, 0.43, 0.43), true)
			c.draw_line(mid + Vector2(-15, 14) * k, mid + Vector2(15, 14) * k, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			c.draw_line(mid + Vector2(-11, 17) * k, mid + Vector2(11, 17) * k, col, 2.0 * k, true)
		"brand":
			# A branding iron: a handle and a glowing mark at its end.
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(2, -3) * k, Color(0.55, 0.5, 0.48), 3.2 * k, true)
			c.draw_arc(mid + Vector2(8, -9) * k, 8.5 * k, 0, TAU, 20, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			c.draw_line(mid + Vector2(3, -9) * k, mid + Vector2(13, -9) * k, light, 2.4 * k, true)
			c.draw_line(mid + Vector2(8, -14) * k, mid + Vector2(8, -4) * k, light, 2.4 * k, true)
		"cinderguard":
			# A raised shield with cinders flying off its face.
			var guard := _pts(mid, k, [Vector2(-12, -14), Vector2(8, -14), Vector2(8, 2), Vector2(-2, 15), Vector2(-12, 2)])
			c.draw_colored_polygon(guard, Color(0.24, 0.19, 0.17))
			guard.append(guard[0])
			c.draw_polyline(guard, light, 2.2 * k, true)
			_flame(c, mid + Vector2(-2, -1) * k, 0.8 * k, col, Color(1.0, 0.9, 0.4))
			for p in [Vector2(14, -11), Vector2(17, -1), Vector2(13, 8)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.2 * k, Color(1.0, 0.9, 0.4))
		"anvil":
			# An anvil with a shockwave spreading from under it.
			c.draw_arc(mid + Vector2(0, 14) * k, 17.0 * k, PI * 1.05, PI * 1.95, 18, col, 2.2 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, -10), Vector2(12, -10), Vector2(12, -3), Vector2(4, -1), Vector2(4, 5), Vector2(10, 11), Vector2(-10, 11), Vector2(-4, 5), Vector2(-4, -1), Vector2(-10, -3)]), Color(0.5, 0.48, 0.5))
			c.draw_line(mid + Vector2(-16, -10) * k, mid + Vector2(12, -10) * k, white, 2.0 * k, true)
			c.draw_line(mid + Vector2(-10, 11) * k, mid + Vector2(10, 11) * k, Color(1.0, 0.9, 0.4), 2.4 * k, true)
		"slagskin":
			# A dark slab of slag with glowing cracks and sparks thrown back at attackers.
			var slab := _pts(mid, k, [Vector2(-11, -13), Vector2(4, -15), Vector2(12, -6), Vector2(11, 9), Vector2(1, 15), Vector2(-12, 10), Vector2(-14, -2)])
			c.draw_colored_polygon(slab, Color(0.2, 0.16, 0.15))
			slab.append(slab[0])
			c.draw_polyline(slab, col, 2.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-9, -9), Vector2(-3, -3), Vector2(-6, 3), Vector2(0, 10)]), Color(1.0, 0.9, 0.4), 2.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-3, -3), Vector2(5, -6), Vector2(8, 1)]), light, 1.8 * k, true)
			for p in [Vector2(17, -13), Vector2(18, 0), Vector2(16, 12)]:
				c.draw_line(mid + (p as Vector2) * k, mid + ((p as Vector2) + Vector2(-4, 0)) * k, light, 1.8 * k, true)
		"coolhead":
			# A calm head and shoulders with a small flame held inside a ring.
			c.draw_arc(mid + Vector2(0, 22) * k, 15.0 * k, PI * 1.12, PI * 1.88, 16, light, 3.0 * k, true)
			c.draw_circle(mid + Vector2(0, -4) * k, 11.0 * k, Color(col, 0.35))
			c.draw_arc(mid + Vector2(0, -4) * k, 11.0 * k, 0, TAU, 28, light, 2.0 * k, true)
			_flame(c, mid + Vector2(0, -3) * k, 0.7 * k, col, Color(1.0, 0.9, 0.4))
			for sx in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(sx * 15, -9) * k, mid + Vector2(sx * 19, -11) * k, Color(0.75, 0.92, 1.0), 1.6 * k, true)
				c.draw_line(mid + Vector2(sx * 16, -3) * k, mid + Vector2(sx * 20, -3) * k, Color(0.75, 0.92, 1.0), 1.6 * k, true)
		# --- Lightning ---
		"lightningbolt":
			c.draw_colored_polygon(_pts(mid, k, [Vector2(3, -17), Vector2(-9, 2), Vector2(-1, 2), Vector2(-5, 17),
				Vector2(9, -4), Vector2(1, -4), Vector2(7, -17)]), light)
		"chainlightning":
			var nodes := [Vector2(-13, 10), Vector2(-2, -8), Vector2(7, 6), Vector2(14, -12)]
			for i in nodes.size() - 1:
				var a: Vector2 = nodes[i]
				var b: Vector2 = nodes[i + 1]
				var m2 := (a + b) / 2.0 + Vector2(3, 2)
				_zigzag(c, mid, k, [a, m2, b], light, 2.0)
			for p in nodes:
				c.draw_circle(mid + (p as Vector2) * k, 3.0 * k, col)
		"thunderstrike":
			_sword(c, mid, k, col)
			_zigzag(c, mid, k, [Vector2(-15, -4), Vector2(-9, -9), Vector2(-7, -4), Vector2(-1, -12)], light, 2.2)
		"stormarrow":
			_arrow_shaft(c, mid, k, col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(14, -14), Vector2(5, -11), Vector2(11, -5)]), light)
			_zigzag(c, mid, k, [Vector2(4, 4), Vector2(9, 2), Vector2(8, 7), Vector2(14, 5)], light, 1.8)
			_zigzag(c, mid, k, [Vector2(-5, -6), Vector2(-2, -11), Vector2(-7, -10), Vector2(-4, -15)], light, 1.8)
		# --- Lightning tank (a parry tank with a two-handed weapon) ---
		"stormshield":
			# Stormbreak: a two-handed blade driven straight down, the charge breaking out to both sides.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3.5, -10), Vector2(3.5, -10), Vector2(3.5, 5), Vector2(0, 11), Vector2(-3.5, 5)]),
				Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(0, -9) * k, mid + Vector2(0, 6) * k, light, 1.6 * k, true)
			c.draw_line(mid + Vector2(-9, -10) * k, mid + Vector2(9, -10) * k, col, 3.2 * k, true)
			c.draw_line(mid + Vector2(0, -11) * k, mid + Vector2(0, -18) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			c.draw_line(mid + Vector2(-17, 14) * k, mid + Vector2(17, 14) * k, col.darkened(0.2), 2.4 * k, true)
			for sx in [-1.0, 1.0]:
				_zigzag(c, mid, k, [Vector2(sx * 2, 12), Vector2(sx * 7, 6), Vector2(sx * 10, 11), Vector2(sx * 17, 3)], white, 2.2)
		"thunderaegis":
			# Humming Blade: a blade held level across the body, the air shivering above and below it.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-8, -3), Vector2(11, -3), Vector2(18, 0), Vector2(11, 3), Vector2(-8, 3)]),
				Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(-8, -8) * k, mid + Vector2(-8, 8) * k, col, 3.2 * k, true)
			c.draw_line(mid + Vector2(-9, 0) * k, mid + Vector2(-18, 0) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			for sy in [-1.0, 1.0]:
				_zigzag(c, mid, k, [Vector2(-5, sy * 9), Vector2(-1, sy * 12), Vector2(3, sy * 9), Vector2(7, sy * 12),
					Vector2(11, sy * 9), Vector2(15, sy * 12)], light, 2.0)
				_zigzag(c, mid, k, [Vector2(-3, sy * 15), Vector2(1, sy * 18), Vector2(5, sy * 15), Vector2(9, sy * 18)], Color(light, 0.55), 1.6)
		"returnstroke":
			# The answer to a parry: the blow that came in, and the bolt that goes straight back.
			c.draw_line(mid + Vector2(17, -10) * k, mid + Vector2(-6, -10) * k, Color(0.9, 0.4, 0.35), 2.6 * k, true)
			c.draw_arc(mid + Vector2(-6, -1) * k, 9.0 * k, PI * 0.5, PI * 1.5, 12, light, 2.6 * k, true)
			_zigzag(c, mid, k, [Vector2(-6, 8), Vector2(1, 5), Vector2(4, 11), Vector2(11, 8)], white, 3.0)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(18, 8), Vector2(10, 2), Vector2(10, 14)]), white)
		"shockring":
			# Two rings of charge rolling out from you, bolts jumping between them.
			c.draw_arc(mid, 17.0 * k, 0, TAU, 32, Color(col, 0.8), 2.0 * k, true)
			c.draw_arc(mid, 10.5 * k, 0, TAU, 28, light, 2.8 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				var d := Vector2(cos(a), sin(a))
				var side := d.orthogonal()
				c.draw_polyline(PackedVector2Array([mid + d * 10.5 * k, mid + (d * 12.5 + side * 2.0) * k,
					mid + (d * 14.5 - side * 2.0) * k, mid + d * 17.0 * k]), white, 1.8 * k, true)
			c.draw_circle(mid, 4.0 * k, white)
		"crossguard":
			# A blade held across, and every blow stopping dead on it.
			c.draw_line(mid + Vector2(-9, 5) * k, mid + Vector2(18, 5) * k, Color(0.92, 0.92, 0.96), 4.0 * k, true)
			c.draw_line(mid + Vector2(-9, -2) * k, mid + Vector2(-9, 12) * k, col, 3.2 * k, true)
			c.draw_line(mid + Vector2(-10, 5) * k, mid + Vector2(-18, 5) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			for x in [-2.0, 6.0, 14.0]:
				c.draw_line(mid + Vector2(x - 4, -17) * k, mid + Vector2(x, 2) * k, Color(0.9, 0.4, 0.35), 2.4 * k, true)
				_star(c, mid + Vector2(x, 3) * k, 4.0 * k, white, 4)
			c.draw_line(mid + Vector2(-7, 14) * k, mid + Vector2(17, 14) * k, Color(light, 0.6), 1.6 * k, true)
		"reelin":
			# A lash wrapped round a target, and the arrow that drags it back to you.
			c.draw_arc(mid + Vector2(10, -8) * k, 6.5 * k, 0, TAU, 16, col, 2.4 * k, true)
			c.draw_circle(mid + Vector2(10, -8) * k, 2.4 * k, white)
			c.draw_polyline(_pts(mid, k, [Vector2(4, -4), Vector2(-2, 2), Vector2(1, 5), Vector2(-7, 10), Vector2(-14, 14)]), light, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-18, 18), Vector2(-16, 8), Vector2(-8, 16)]), white)
			for y in [-14.0, -9.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-9 - (y + 14.0) * 0.6, y) * k, Color(light, 0.6), 1.6 * k, true)
		"recharge":
			# A cell emptying into a green cross: Energy turned into health.
			c.draw_rect(Rect2(mid + Vector2(-17, -8) * k, Vector2(12, 20) * k), col.darkened(0.35), true)
			c.draw_rect(Rect2(mid + Vector2(-17, -8) * k, Vector2(12, 20) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-14, -12) * k, Vector2(6, 4) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-15, 6) * k, Vector2(8, 4) * k), white, true)
			_zigzag(c, mid, k, [Vector2(-4, 3), Vector2(0, -1), Vector2(1, 4), Vector2(5, 1)], white, 2.0)
			var mend := Color(0.45, 1.0, 0.5)
			c.draw_rect(Rect2(mid + Vector2(10, -10) * k, Vector2(5, 17) * k), mend, true)
			c.draw_rect(Rect2(mid + Vector2(4, -4) * k, Vector2(17, 5) * k), mend, true)
		"drawthestorm":
			# A raised blade, and every bolt of the storm bending down onto it.
			c.draw_line(mid + Vector2(0, 17) * k, mid + Vector2(0, -4) * k, Color(0.92, 0.92, 0.96), 3.4 * k, true)
			c.draw_line(mid + Vector2(-6, 11) * k, mid + Vector2(6, 11) * k, col, 3.0 * k, true)
			for sx in [-1.0, 1.0]:
				_zigzag(c, mid, k, [Vector2(sx * 17, -16), Vector2(sx * 9, -13), Vector2(sx * 10, -8), Vector2(sx * 2, -6)], light, 2.4)
				_zigzag(c, mid, k, [Vector2(sx * 17, 2), Vector2(sx * 11, 0), Vector2(sx * 9, 5), Vector2(sx * 3, 2)], Color(light, 0.6), 1.8)
			_zigzag(c, mid, k, [Vector2(2, -18), Vector2(-2, -13), Vector2(2, -11), Vector2(0, -6)], white, 2.4)
			_star(c, mid + Vector2(0, -5) * k, 4.5 * k, white, 4)
		"discharge":
			# A battery cell emptying itself through one fat bolt.
			c.draw_rect(Rect2(mid + Vector2(-16, -9) * k, Vector2(13, 20) * k), col.darkened(0.35), true)
			c.draw_rect(Rect2(mid + Vector2(-16, -9) * k, Vector2(13, 20) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-12, -13) * k, Vector2(5, 4) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-14, 6) * k, Vector2(9, 3) * k), white, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3, -3), Vector2(6, -9), Vector2(4, -3), Vector2(16, -6),
				Vector2(3, 7), Vector2(5, 1), Vector2(-3, 3)]), white)
		"balllightning":
			# A crackling orb with arcs reaching out of it.
			c.draw_circle(mid, 9.0 * k, col.darkened(0.2))
			c.draw_arc(mid, 9.0 * k, 0, TAU, 24, light, 2.0 * k, true)
			c.draw_circle(mid + Vector2(-2, -2) * k, 3.5 * k, white)
			for a in [0.5, 2.1, 3.6, 5.2]:
				var d := Vector2(cos(a), sin(a))
				var side := d.orthogonal()
				c.draw_polyline(PackedVector2Array([mid + d * 10.0 * k, mid + (d * 13.0 + side * 3.0) * k,
					mid + (d * 15.0 - side * 2.0) * k, mid + d * 19.0 * k]), light, 1.8 * k, true)
		"groundout":
			# A bolt running down into the ground symbol, a shield around it.
			c.draw_arc(mid + Vector2(0, -2) * k, 15.0 * k, PI * 0.95, PI * 2.05, 18, light, 2.4 * k, true)
			_zigzag(c, mid, k, [Vector2(3, -13), Vector2(-3, -5), Vector2(2, -5), Vector2(0, 4)], white, 2.4)
			for i in 3:
				var half := 11.0 - i * 4.0
				c.draw_line(mid + Vector2(-half, 6 + i * 4) * k, mid + Vector2(half, 6 + i * 4) * k, col if i > 0 else light, 2.4 * k, true)
		"groundingsurge":
			# Feet planted on the ground, current surging up through the body.
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(16, 14) * k, col.darkened(0.2), 3.0 * k, true)
			for x in [-6.0, 6.0]:
				c.draw_line(mid + Vector2(x, 14) * k, mid + Vector2(x * 0.5, 3) * k, light, 3.0 * k, true)
				c.draw_line(mid + Vector2(x, 14) * k, mid + Vector2(x * 1.7, 14) * k, light, 3.0 * k, true)
			c.draw_line(mid + Vector2(0, 3) * k, mid + Vector2(0, -8) * k, light, 3.0 * k, true)
			c.draw_circle(mid + Vector2(0, -12) * k, 3.5 * k, light)
			for x in [-12.0, 12.0]:
				_zigzag(c, mid, k, [Vector2(x, 10), Vector2(x * 0.75 + 2, 2), Vector2(x - 1, 0), Vector2(x * 0.8, -9)], white, 1.8)
				c.draw_colored_polygon(_pts(mid, k, [Vector2(x * 0.8, -14), Vector2(x * 0.8 - 3, -9), Vector2(x * 0.8 + 3, -9)]), white)
		"arcflash":
			# A bright flash bursting outward in every direction from a small core.
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var d := Vector2(cos(a), sin(a))
				var side := d.orthogonal()
				c.draw_polyline(PackedVector2Array([mid + d * 5.0 * k, mid + (d * 10.0 + side * 2.5) * k,
					mid + (d * 13.0 - side * 2.0) * k, mid + d * 18.0 * k]), light if i % 2 == 0 else col, 2.0 * k, true)
			_star(c, mid, 7.0 * k, white, 4)
		"livewire":
			# Two contacts joined by a sagging, sparking wire.
			c.draw_arc(mid + Vector2(0, -14) * k, 18.0 * k, PI * 0.22, PI * 0.78, 16, col, 2.4 * k, true)
			for x in [-13.0, 13.0]:
				c.draw_circle(mid + Vector2(x, -3) * k, 4.0 * k, light)
				c.draw_circle(mid + Vector2(x, -3) * k, 1.8 * k, white)
			for p in [Vector2(-5, 9), Vector2(1, 12), Vector2(7, 8)]:
				_star(c, mid + (p as Vector2) * k, 3.2 * k, white, 4)
		"thunderhead":
			# A heavy cloud with a bolt dropping out of it.
			for p in [Vector2(-8, -6), Vector2(0, -10), Vector2(8, -6), Vector2(-3, -3), Vector2(4, -3)]:
				c.draw_circle(mid + (p as Vector2) * k, 6.5 * k, col.darkened(0.45))
			c.draw_arc(mid + Vector2(0, -10) * k, 6.5 * k, PI * 1.1, PI * 1.9, 10, light, 1.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(2, 1), Vector2(-6, 9), Vector2(-1, 9), Vector2(-4, 17),
				Vector2(6, 6), Vector2(1, 6), Vector2(5, 1)]), white)
		"forkedbolt":
			# One bolt splitting into two prongs.
			_zigzag(c, mid, k, [Vector2(-15, -14), Vector2(-7, -8), Vector2(-9, -3), Vector2(-1, 1)], light, 3.0)
			_zigzag(c, mid, k, [Vector2(-1, 1), Vector2(6, -2), Vector2(8, -8), Vector2(15, -11)], white, 2.4)
			_zigzag(c, mid, k, [Vector2(-1, 1), Vector2(2, 8), Vector2(9, 9), Vector2(13, 16)], white, 2.4)
			c.draw_circle(mid + Vector2(-1, 1) * k, 2.6 * k, col)
		"jolt":
			# A cast bar struck through by a short, sharp bolt.
			c.draw_rect(Rect2(mid + Vector2(-15, 6) * k, Vector2(30, 7) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-15, 6) * k, Vector2(16, 7) * k), Color(1.0, 0.72, 0.15), true)
			c.draw_rect(Rect2(mid + Vector2(-15, 6) * k, Vector2(30, 7) * k), light, false, 1.4 * k)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(6, -17), Vector2(-5, -3), Vector2(1, -3), Vector2(-3, 9),
				Vector2(9, -7), Vector2(3, -7), Vector2(9, -17)]), white)
		"flicker":
			# A figure jumping forward, fading after-images behind it.
			for i in 3:
				var x := -13.0 + i * 11.0
				var tone := Color(light, 0.3 + i * 0.3) if i < 2 else white
				c.draw_circle(mid + Vector2(x, -9) * k, 3.2 * k, tone)
				c.draw_line(mid + Vector2(x, -5) * k, mid + Vector2(x - 2, 6) * k, tone, 2.6 * k, true)
				c.draw_line(mid + Vector2(x - 2, 6) * k, mid + Vector2(x - 6, 14) * k, tone, 2.2 * k, true)
				c.draw_line(mid + Vector2(x - 2, 6) * k, mid + Vector2(x + 3, 14) * k, tone, 2.2 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(13, -2), Vector2(18, 3), Vector2(13, 8)]), col, 2.2 * k, true)
		"capacitor":
			# Two plates with a charge held between them.
			for x in [-5.0, 5.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 1.5, -13) * k, Vector2(3, 26) * k), light, true)
			c.draw_line(mid + Vector2(-17, 0) * k, mid + Vector2(-6.5, 0) * k, col, 2.4 * k, true)
			c.draw_line(mid + Vector2(6.5, 0) * k, mid + Vector2(17, 0) * k, col, 2.4 * k, true)
			for y in [-8.0, 0.0, 8.0]:
				_star(c, mid + Vector2(0, y) * k, 2.6 * k, white, 4)
		# --- Lightning melee ---
		"chargededge":
			# An upright blade with one edge lit and throwing sparks.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3, 10), Vector2(-3, -10), Vector2(0, -17), Vector2(3, -10), Vector2(3, 10)]),
				Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(3.5, -10) * k, mid + Vector2(3.5, 10) * k, light, 2.6 * k, true)
			c.draw_line(mid + Vector2(-9, 10) * k, mid + Vector2(9, 10) * k, col, 3.2 * k, true)
			c.draw_line(mid + Vector2(0, 11) * k, mid + Vector2(0, 18) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			for p in [Vector2(10, -11), Vector2(12, -2), Vector2(9, 5)]:
				_star(c, mid + (p as Vector2) * k, 3.0 * k, white, 4)
		"arccleave":
			# A wide crescent sweep with a second, fainter one inside it.
			c.draw_arc(mid + Vector2(0, 10) * k, 18.0 * k, PI * 1.12, PI * 1.88, 20, light, 4.5 * k, true)
			c.draw_arc(mid + Vector2(0, 10) * k, 11.0 * k, PI * 1.18, PI * 1.82, 14, col, 2.4 * k, true)
			for x in [-10.0, 0.0, 10.0]:
				_zigzag(c, mid, k, [Vector2(x, 14), Vector2(x + 2, 9), Vector2(x - 2, 7), Vector2(x, 2)], white, 1.8)
		"overdrive":
			# A gauge with its needle pushed into the red.
			c.draw_arc(mid + Vector2(0, 6) * k, 15.0 * k, PI, PI * 1.7, 16, light, 3.4 * k, true)
			c.draw_arc(mid + Vector2(0, 6) * k, 15.0 * k, PI * 1.7, TAU, 10, Color(1.0, 0.4, 0.3), 3.4 * k, true)
			for i in 5:
				var a := PI + PI * i / 4.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(0, 6) + d * 9.0) * k, mid + (Vector2(0, 6) + d * 12.0) * k, col, 1.6 * k, true)
			c.draw_line(mid + Vector2(0, 6) * k, mid + Vector2(11, -3) * k, white, 2.6 * k, true)
			c.draw_circle(mid + Vector2(0, 6) * k, 3.0 * k, white)
			_zigzag(c, mid, k, [Vector2(-6, 11), Vector2(0, 14), Vector2(-2, 15), Vector2(6, 18)], light, 1.8)
		"twincurrent":
			# Two bolts side by side: the swing and its echo.
			_zigzag(c, mid, k, [Vector2(-5, -16), Vector2(-12, -2), Vector2(-5, -2), Vector2(-11, 16)], white, 3.2)
			_zigzag(c, mid, k, [Vector2(10, -16), Vector2(3, -2), Vector2(10, -2), Vector2(4, 16)], light, 3.2)
		"staticstep":
			# A crackling dash that ends on a marked target.
			c.draw_arc(mid + Vector2(11, -1) * k, 6.5 * k, 0, TAU, 16, col, 2.2 * k, true)
			c.draw_circle(mid + Vector2(11, -1) * k, 2.2 * k, white)
			_zigzag(c, mid, k, [Vector2(-17, 7), Vector2(-10, -4), Vector2(-6, 4), Vector2(1, -2)], light, 3.0)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-1, -8), Vector2(7, -1), Vector2(-3, 3)]), white)
			for y in [11.0, 15.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-8, y) * k, Color(light, 0.6), 1.6 * k, true)
		"backcurrent":
			# A blow coming in against a plate, and the current running back out along it.
			c.draw_rect(Rect2(mid + Vector2(-13, -15) * k, Vector2(5, 30) * k), col.darkened(0.2), true)
			c.draw_rect(Rect2(mid + Vector2(-13, -15) * k, Vector2(5, 30) * k), light, false, 1.4 * k)
			c.draw_line(mid + Vector2(16, 10) * k, mid + Vector2(-6, 4) * k, Color(0.9, 0.4, 0.35), 2.6 * k, true)
			_zigzag(c, mid, k, [Vector2(-6, -3), Vector2(2, -8), Vector2(3, -3), Vector2(11, -9)], white, 2.6)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(17, -13), Vector2(9, -13), Vector2(13, -6)]), white)
		"cadence":
			# Three beats, each taller than the last.
			var beats := [Vector2(-15, 8), Vector2(-4, 15), Vector2(7, 26)]
			var tones := [col, light, white]
			for i in beats.size():
				var b: Vector2 = beats[i]
				c.draw_rect(Rect2(mid + Vector2(b.x, 14 - b.y) * k, Vector2(8, b.y) * k), tones[i], true)
			c.draw_line(mid + Vector2(-17, 16) * k, mid + Vector2(17, 16) * k, col.darkened(0.2), 2.0 * k, true)
		"splitsecond":
			# A clock face cut in two by a bolt, its halves pulled apart.
			c.draw_arc(mid + Vector2(-3, 0) * k, 14.0 * k, PI * 0.5, PI * 1.5, 16, light, 2.6 * k, true)
			c.draw_arc(mid + Vector2(3, 0) * k, 14.0 * k, PI * 1.5, PI * 2.5, 16, col, 2.6 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(-11, -5) * k, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(5, 0) * k, mid + Vector2(11, 5) * k, col, 2.2 * k, true)
			_zigzag(c, mid, k, [Vector2(3, -18), Vector2(-3, -5), Vector2(3, -1), Vector2(-3, 18)], white, 2.6)
		"whiplash":
			# A whip of lightning uncurling from its handle, a spark at the tip.
			c.draw_line(mid + Vector2(-17, 17) * k, mid + Vector2(-11, 11) * k, Color(0.4, 0.25, 0.15), 4.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-11, 11), Vector2(-4, 9), Vector2(3, 4), Vector2(1, -4), Vector2(-6, -8),
				Vector2(-3, -15), Vector2(6, -14), Vector2(13, -9)]), light, 2.6 * k, true)
			_star(c, mid + Vector2(14, -8) * k, 5.0 * k, white, 4)
		"faradayguard":
			# A cage of bars with the current running around it, not through it.
			c.draw_rect(Rect2(mid + Vector2(-10, -11) * k, Vector2(20, 24) * k), light, false, 2.2 * k)
			for x in [-3.5, 3.5]:
				c.draw_line(mid + Vector2(x, -11) * k, mid + Vector2(x, 13) * k, col, 1.8 * k, true)
			for y in [-3.0, 5.0]:
				c.draw_line(mid + Vector2(-10, y) * k, mid + Vector2(10, y) * k, col, 1.8 * k, true)
			c.draw_circle(mid + Vector2(0, 1) * k, 2.4 * k, white)
			for sx in [-1.0, 1.0]:
				_zigzag(c, mid, k, [Vector2(sx * 3, -19), Vector2(sx * 9, -15), Vector2(sx * 13, -16), Vector2(sx * 16, -8),
					Vector2(sx * 14, -4), Vector2(sx * 17, 3)], white, 1.8)
		"reflexarc":
			# An incoming blow turned aside on your blade: a flash where they meet.
			_sword(c, mid, k, col)
			c.draw_line(mid + Vector2(-16, -14) * k, mid + Vector2(1, 0) * k, Color(0.9, 0.4, 0.35), 3.0 * k, true)
			_star(c, mid + Vector2(2, -1) * k, 7.0 * k, white, 4)
		# --- Arcane ---
		"arcanemissiles":
			for p in [Vector2(-9, 8), Vector2(0, -1), Vector2(9, -10)]:
				c.draw_line(mid + ((p as Vector2) + Vector2(-7, 7)) * k, mid + (p as Vector2) * k, Color(col, 0.5), 3.0 * k, true)
				_star(c, mid + (p as Vector2) * k, 5.0 * k, light)
		"arcanestrike":
			_sword(c, mid, k, col)
			_star(c, mid + Vector2(-8, -8) * k, 6.0 * k, light)
		"arcaneshot":
			_arrow_shaft(c, mid, k, col)
			_star(c, mid + Vector2(11, -11) * k, 7.0 * k, light)
		"arcaneexplosion":
			for r in [16.0, 11.0, 6.0]:
				c.draw_arc(mid, r * k, 0, TAU, 28, Color(col, 0.5 + (16.0 - r) / 25.0), 2.0 * k, true)
			_star(c, mid, 8.0 * k, light, 8)
		"counterspell":
			c.draw_circle(mid, 13.0 * k, Color(col, 0.3))
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, light, 2.5 * k, true)
			_star(c, mid, 7.0 * k, Color(light, 0.6))
			c.draw_line(mid + Vector2(-10, 10) * k, mid + Vector2(10, -10) * k, Color(1, 0.4, 0.35), 3.5 * k, true)
		"unravel":
			# A wound thread coming apart: a spiral whose loose end trails off.
			var u_prev := mid + Vector2(-3, 2) * k
			for i in 30:
				var t := i / 29.0
				var p := mid + Vector2(-3, 2) * k + Vector2(cos(t * TAU * 1.75), sin(t * TAU * 1.75)) * (1.5 + t * 10.0) * k
				c.draw_line(u_prev, p, Color(col, 0.5 + t * 0.5), 2.4 * k, true)
				u_prev = p
			_zigzag(c, mid, k, [Vector2(-3, -9.5), Vector2(4, -13), Vector2(8, -9), Vector2(13, -14), Vector2(16, -10)], light, 2.0)
		"countdown":
			# A dial running down: the time left is the bright wedge.
			c.draw_circle(mid, 14.0 * k, Color(col, 0.25))
			var wedge := PackedVector2Array([mid])
			for i in 11:
				var a := -PI / 2.0 + TAU * 0.3 * i / 10.0
				wedge.append(mid + Vector2(cos(a), sin(a)) * 13.0 * k)
			c.draw_colored_polygon(wedge, Color(light, 0.85))
			c.draw_arc(mid, 14.0 * k, 0, TAU, 28, col, 2.2 * k, true)
			for i in 4:
				var a := TAU * i / 4.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 11.0 * k, mid + Vector2(cos(a), sin(a)) * 14.0 * k, white, 1.6 * k, true)
			c.draw_line(mid, mid + Vector2(0, -11) * k, white, 2.0 * k, true)
		"convergence":
			# Four beams meeting at one point.
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var dir := (d as Vector2).normalized()
				c.draw_line(mid + dir * 19.0 * k, mid + dir * 7.0 * k, Color(col, 0.9), 2.6 * k, true)
				var side := Vector2(-dir.y, dir.x)
				c.draw_colored_polygon(PackedVector2Array([mid + dir * 4.0 * k, mid + dir * 10.0 * k + side * 3.5 * k,
					mid + dir * 10.0 * k - side * 3.5 * k]), light)
			c.draw_circle(mid, 3.2 * k, white)
		"rewind":
			# An arrow running backwards around a circle.
			c.draw_arc(mid, 12.0 * k, -PI * 0.5, PI * 1.05, 24, col, 3.0 * k, true)
			var tip := mid + Vector2(0, -12) * k
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, 0) * k, tip + Vector2(1, -6) * k, tip + Vector2(1, 6) * k]), light)
			c.draw_line(mid, mid + Vector2(0, -6) * k, white, 1.8 * k, true)
			c.draw_line(mid, mid + Vector2(-5, 2) * k, white, 1.8 * k, true)
		"lapse":
			# An hourglass.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-10, -14), Vector2(10, -14), Vector2(0, 0)]), Color(col, 0.45))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-10, 14), Vector2(10, 14), Vector2(0, 0)]), Color(col, 0.45))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-7, 14), Vector2(7, 14), Vector2(0, 7)]), light)
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(0, 8) * k, light, 1.6 * k, true)
			for y in [-15.0, 15.0]:
				c.draw_line(mid + Vector2(-12, y) * k, mid + Vector2(12, y) * k, white, 2.6 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-10, -14), Vector2(0, 0), Vector2(-10, 14)]), col, 1.8 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(10, -14), Vector2(0, 0), Vector2(10, 14)]), col, 1.8 * k, true)
		"mirrorsigil":
			# A sigil and its reflection either side of a mirror line.
			c.draw_line(mid + Vector2(0, -17) * k, mid + Vector2(0, 17) * k, white, 1.6 * k, true)
			for sx in [-1.0, 1.0]:
				var mc := Color(col, 1.0 if sx < 0.0 else 0.55)
				var dia := _pts(mid, k, [Vector2(sx * 3, 0), Vector2(sx * 9, -9), Vector2(sx * 15, 0), Vector2(sx * 9, 9), Vector2(sx * 3, 0)])
				c.draw_polyline(dia, mc, 2.2 * k, true)
				_star(c, mid + Vector2(sx * 9, 0) * k, 4.5 * k, Color(light, 1.0 if sx < 0.0 else 0.6))
		"collapse":
			# A ring falling in on its centre.
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, Color(col, 0.6), 2.0 * k, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.26
				var dir := Vector2(cos(a), sin(a))
				var side := Vector2(-dir.y, dir.x)
				c.draw_colored_polygon(PackedVector2Array([mid + dir * 5.0 * k, mid + dir * 12.0 * k + side * 3.2 * k,
					mid + dir * 12.0 * k - side * 3.2 * k]), light)
			c.draw_circle(mid, 3.5 * k, col.darkened(0.45))
			c.draw_arc(mid, 3.5 * k, 0, TAU, 12, white, 1.2 * k, true)
		"scatter":
			# One dart breaking into three.
			var from := mid + Vector2(-14, 12) * k
			var fork := mid + Vector2(-5, 3) * k
			c.draw_line(from, fork, Color(col, 0.8), 3.0 * k, true)
			for p in [Vector2(-8, -13), Vector2(8, -8), Vector2(13, 8)]:
				c.draw_line(fork, mid + (p as Vector2) * k, Color(col, 0.55), 2.0 * k, true)
				_star(c, mid + (p as Vector2) * k, 4.5 * k, light)
		"glint":
			# A single bright spark with a short trail: thrown in passing.
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(2, -4) * k, Color(col, 0.45), 4.0 * k, true)
			c.draw_line(mid + Vector2(-9, 7) * k, mid + Vector2(2, -4) * k, Color(light, 0.7), 2.0 * k, true)
			_star(c, mid + Vector2(5, -6) * k, 11.0 * k, white, 4)
			_star(c, mid + Vector2(5, -6) * k, 6.0 * k, light, 8)
			c.draw_circle(mid + Vector2(5, -6) * k, 2.2 * k, white)
		"intervalward":
			# A shield with a clock's hands on it.
			var ward := _pts(mid, k, [Vector2(0, -16), Vector2(13, -11), Vector2(12, 3), Vector2(0, 16), Vector2(-12, 3), Vector2(-13, -11)])
			c.draw_colored_polygon(ward, Color(col, 0.45))
			ward.append(ward[0])
			c.draw_polyline(ward, light, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, -2) * k, 7.0 * k, 0, TAU, 18, Color(white, 0.7), 1.4 * k, true)
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(0, -8) * k, white, 1.8 * k, true)
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(4, 1) * k, white, 1.8 * k, true)
		# --- Arcane tank (a dodge tank that lives on its Reflections) ---
		"doubleup":
			# You and a Reflection of you, one blade across both.
			_figure(c, mid + Vector2(6, 15) * k, k, Color(light, 0.5))
			_figure(c, mid + Vector2(-6, 15) * k, k, white)
			c.draw_line(mid + Vector2(-16, 4) * k, mid + Vector2(16, -12) * k, Color(col, 0.55), 5.0 * k, true)
			c.draw_line(mid + Vector2(-14, 3) * k, mid + Vector2(15, -11.5) * k, Color(0.92, 0.92, 0.96), 2.2 * k, true)
		"ripple":
			# Rings spreading over the ground from where you stand.
			for i in 3:
				var rr := 6.0 + i * 5.5
				c.draw_arc(mid + Vector2(0, 3) * k, rr * k, PI * 0.08, PI * 0.92, 14, Color(light, 0.95 - i * 0.25), 2.4 * k, true)
				c.draw_arc(mid + Vector2(0, 3) * k, rr * k, PI * 1.08, PI * 1.92, 14, Color(col, 0.9 - i * 0.25), 2.0 * k, true)
			_star(c, mid + Vector2(0, 3) * k, 5.0 * k, white, 4)
		"fullset":
			# You in the middle, a Reflection on every side.
			for p in [Vector2(-12, 7), Vector2(12, 7), Vector2(0, -3), Vector2(0, 18)]:
				_figure(c, mid + (p as Vector2) * k, 0.72 * k, Color(light, 0.6))
			_figure(c, mid + Vector2(0, 9) * k, 0.8 * k, white)
		"missedbeat":
			# A Reflection breaking apart, and the blow that answers it.
			for p in [Vector2(-13, -12), Vector2(-5, -15), Vector2(-14, -3)]:
				var shard := mid + (p as Vector2) * k
				c.draw_colored_polygon(PackedVector2Array([shard + Vector2(0, -4) * k, shard + Vector2(3.5, 2) * k,
					shard + Vector2(-3, 3) * k]), Color(light, 0.9))
			_sword(c, mid + Vector2(3, 3) * k, k, col)
			_star(c, mid + Vector2(14, -9) * k, 4.5 * k, white, 4)
		"standin":
			# A blow stopped by the Reflection standing in front of you.
			_figure(c, mid + Vector2(9, 15) * k, k, white)
			_figure(c, mid + Vector2(-3, 15) * k, k, Color(light, 0.55))
			c.draw_line(mid + Vector2(-18, -7) * k, mid + Vector2(-8, 1) * k, Color(0.9, 0.4, 0.35), 2.6 * k, true)
			_star(c, mid + Vector2(-7, 2) * k, 5.0 * k, white, 4)
		"tradeplaces":
			# You and a Reflection changing places, and the health it buys.
			_figure(c, mid + Vector2(-10, 17) * k, 0.8 * k, white)
			_figure(c, mid + Vector2(10, 17) * k, 0.8 * k, Color(light, 0.55))
			c.draw_arc(mid + Vector2(0, 3) * k, 9.0 * k, PI * 1.15, PI * 1.85, 10, light, 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(11, 2), Vector2(5, 0), Vector2(10, -5)]), light)
			var mend := Color(0.45, 1.0, 0.5)
			c.draw_rect(Rect2(mid + Vector2(-2, -19) * k, Vector2(4, 11) * k), mend, true)
			c.draw_rect(Rect2(mid + Vector2(-5.5, -15.5) * k, Vector2(11, 4) * k), mend, true)
		"crowdofone":
			# One of you, and a whole row of Reflections behind.
			for i in 5:
				if i != 2:
					_figure(c, mid + Vector2(-14.0 + i * 7.0, 12) * k, 0.8 * k, Color(light, 0.5))
			_figure(c, mid + Vector2(0, 17) * k, k, white)
			_star(c, mid + Vector2(0, -13) * k, 4.0 * k, light, 4)
		"decoy":
			# A Reflection standing alone, and every eye on it.
			_figure(c, mid + Vector2(0, 13) * k, k, Color(light, 0.75))
			c.draw_arc(mid + Vector2(0, 2) * k, 14.0 * k, 0, TAU, 28, Color(1.0, 0.4, 0.3), 2.0 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(0, 2) * k + d * 11.0 * k, mid + Vector2(0, 2) * k + d * 18.0 * k,
					Color(1.0, 0.45, 0.35), 2.4 * k, true)
		# --- Arcane melee (its strikes leave Traces; Encore replays them) ---
		"swiftcut":
			# Two fast, light cuts side by side, speed lines behind them.
			for i in 2:
				var off := Vector2(-4.0 + i * 8.0, 0)
				c.draw_line(mid + (Vector2(-10, 12) + off) * k, mid + (Vector2(8, -13) + off) * k, Color(col, 0.5), 4.0 * k, true)
				c.draw_line(mid + (Vector2(-9, 11) + off) * k, mid + (Vector2(8, -13) + off) * k, white, 1.8 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-18, -8 + i * 6) * k, mid + Vector2(-12 + i, -8 + i * 6) * k, Color(light, 0.7), 1.6 * k, true)
		"deepcut":
			# One heavy cut: a wide gash, deepest in the middle.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, 14), Vector2(-2, -4), Vector2(15, -15), Vector2(3, 3)]), Color(col, 0.75))
			c.draw_polyline(_pts(mid, k, [Vector2(-16, 14), Vector2(-2, -4), Vector2(15, -15), Vector2(3, 3), Vector2(-16, 14)]),
				light, 1.6 * k, true)
			c.draw_line(mid + Vector2(-14, 12.5) * k, mid + Vector2(14, -14) * k, white, 2.2 * k, true)
		"latecut":
			# A cut, the fainter one still to come, and the clock it waits on.
			c.draw_line(mid + Vector2(-16, 6) * k, mid + Vector2(4, -14) * k, Color(col, 0.5), 4.5 * k, true)
			c.draw_line(mid + Vector2(-15, 5) * k, mid + Vector2(4, -14) * k, white, 2.0 * k, true)
			c.draw_line(mid + Vector2(-9, 14) * k, mid + Vector2(11, -6) * k, Color(light, 0.45), 2.0 * k, true)
			c.draw_circle(mid + Vector2(10, 9) * k, 6.5 * k, Color(0.08, 0.05, 0.14))
			c.draw_arc(mid + Vector2(10, 9) * k, 6.5 * k, 0, TAU, 18, light, 1.6 * k, true)
			c.draw_line(mid + Vector2(10, 9) * k, mid + Vector2(10, 4.5) * k, white, 1.4 * k, true)
			c.draw_line(mid + Vector2(10, 9) * k, mid + Vector2(13, 10.5) * k, white, 1.4 * k, true)
		"encore":
			# Three cuts, faint to bright, and the arrow that brings them round again.
			for i in 3:
				var off := Vector2(-7.0 + i * 7.0, 4)
				c.draw_line(mid + (Vector2(-5, 10) + off) * k, mid + (Vector2(5, -8) + off) * k,
					Color(light, 0.4 + i * 0.3), (1.6 + i * 0.5) * k, true)
			c.draw_arc(mid + Vector2(0, -2) * k, 15.0 * k, PI * 1.05, PI * 1.9, 14, white, 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(15.8, -1.9), Vector2(18.1, -7.8), Vector2(10.5, -5.4)]), white)
		"widecut":
			# One wide sweep: a crescent of steel across everything in front of you.
			c.draw_arc(mid + Vector2(0, 5) * k, 15.0 * k, PI * 1.05, PI * 1.95, 18, Color(col, 0.55), 6.0 * k, true)
			c.draw_arc(mid + Vector2(0, 5) * k, 15.0 * k, PI * 1.08, PI * 1.92, 18, white, 2.2 * k, true)
			c.draw_arc(mid + Vector2(0, 5) * k, 9.0 * k, PI * 1.2, PI * 1.8, 12, Color(light, 0.6), 1.6 * k, true)
			c.draw_circle(mid + Vector2(0, 9) * k, 2.6 * k, light)
		"doubletime":
			# Two clock faces, one over the other.
			for i in 2:
				var at := mid + Vector2(-5.0 + i * 10.0, 3.0 - i * 6.0) * k
				var rim := light if i == 1 else Color(light, 0.55)
				var hand := white if i == 1 else Color(white, 0.55)
				c.draw_circle(at, 10.0 * k, Color(0.08, 0.05, 0.14))
				c.draw_arc(at, 10.0 * k, 0, TAU, 24, rim, 2.0 * k, true)
				c.draw_line(at, at + Vector2(0, -7) * k, hand, 1.8 * k, true)
				c.draw_line(at, at + Vector2(5, 2) * k, hand, 1.8 * k, true)
		# --- Shadow ---
		"corruption":
			# Spiral into a dark eye.
			var prev := mid
			for i in 40:
				var t := i / 39.0
				var p := mid + Vector2(cos(t * TAU * 2.2), sin(t * TAU * 2.2)) * (2.0 + t * 14.0) * k
				c.draw_line(prev, p, Color(col, 0.4 + t * 0.6), 2.2 * k, true)
				prev = p
			c.draw_circle(mid, 3.0 * k, light)
		"shadowstrike":
			_sword(c, mid, k, col)
			for p in [Vector2(-10, -4), Vector2(-7, -11), Vector2(-13, -12)]:
				c.draw_arc(mid + (p as Vector2) * k, 3.5 * k, 0.5, 3.8, 8, light, 1.8 * k, true)
		"shadowarrow":
			_arrow_shaft(c, mid, k, col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(14, -14), Vector2(5, -11), Vector2(11, -5)]), light)
			c.draw_arc(mid + Vector2(4, -4) * k, 9.0 * k, 2.0, 4.6, 10, Color(col, 0.8), 2.5 * k, true)
			c.draw_arc(mid + Vector2(-3, 3) * k, 9.0 * k, -1.2, 1.4, 10, Color(col, 0.8), 2.5 * k, true)
		# --- Shadow melee: the Hounds (two demon dogs, red hide and violet horns) ---
		"sic":
			# Sic: a Hound sent at its prey, jaws wide.
			for i in 3:
				c.draw_line(mid + Vector2(-20, -9.0 + i * 8.0) * k, mid + Vector2(-13.0 + (i % 2) * 3.0, -9.0 + i * 8.0) * k,
					Color(light, 0.75), 1.7 * k, true)
			_hound_head(c, mid + Vector2(-1, 2) * k, 1.4 * k, light, white, 1.0)
		"openup":
			# Open Up: three gashes torn side by side, still wet.
			for i in 3:
				var gash := Vector2(-9.0 + i * 9.0, 0)
				c.draw_line(mid + (Vector2(4, -15) + gash) * k, mid + (Vector2(-4, 12) + gash) * k, HOUND_RED, 4.6 * k, true)
				c.draw_line(mid + (Vector2(3.2, -12) + gash) * k, mid + (Vector2(-3, 9) + gash) * k, Color(1.0, 0.78, 0.84), 1.4 * k, true)
			c.draw_circle(mid + Vector2(-13.5, 16) * k, 1.9 * k, HOUND_RED)
			c.draw_circle(mid + Vector2(4.5, 16.5) * k, 1.4 * k, HOUND_RED)
			c.draw_arc(mid + Vector2(13, -12) * k, 3.5 * k, 0.5, 3.8, 8, light, 1.8 * k, true)
		"bothatonce":
			# Both At Once: the two of them, from either side, on the one between.
			_hound_head(c, mid + Vector2(-9, -7) * k, 0.95 * k, light, white, 0.9)
			_hound_head(c, mid + Vector2(9, 9) * k, 0.95 * k, light, white, 0.9, -1.0)
			_star(c, mid + Vector2(0, 2) * k, 4.2 * k, white)
		"runthemdown":
			# Run Them Down: a pack of enemies, and the Hound that is into all of them.
			for i in 3:
				_figure(c, mid + Vector2(5.0 + i * 5.5, 16.0 - (i % 2) * 3.0) * k, 0.55 * k, Color(light, 0.55 + 0.2 * i))
			_hound_head(c, mid + Vector2(-7, -4) * k, 1.15 * k, light, white, 0.85)
		"guarddogs":
			# Guard Dogs: a Hound standing over you like a shield.
			var ward := _pts(mid, k, [Vector2(-15, -15), Vector2(15, -15), Vector2(14, 2), Vector2(0, 17), Vector2(-14, 2)])
			c.draw_colored_polygon(ward, col.darkened(0.35))
			ward.append(ward[0])
			c.draw_polyline(ward, light, 2.0 * k, true)
			_hound_head(c, mid + Vector2(-2, 0) * k, 1.0 * k, light, white, 0.2)
		"offthechain":
			# Off the Chain: the Hound, and the links that held it, snapped.
			for i in 3:
				var gap := 0.9 if i == 2 else 0.0
				c.draw_arc(mid + Vector2(-17.0 + i * 5.5, 13.0 - i * 2.5) * k, 3.0 * k, gap, TAU - gap, 10, Color(0.82, 0.82, 0.88), 1.7 * k, true)
			_hound_head(c, mid + Vector2(2, -4) * k, 1.25 * k, light, white, 1.0)
		"bringitdown":
			# Bring It Down: the hole it came out of, and the Hound going back into it with its jaws shut on something.
			_hound_head(c, mid + Vector2(-3, -6) * k, 1.2 * k, light, white, 0.0)
			_hole(c, mid + Vector2(0, 13) * k, Vector2(16, 5) * k, light, 1.8 * k)
			for sx: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(15 * sx, -15) * k, mid + Vector2(15 * sx, 1) * k, white, 2.0 * k, true)
				c.draw_colored_polygon(_pts(mid, k, [Vector2(15 * sx, 6), Vector2(15 * sx - 4, 0), Vector2(15 * sx + 4, 0)]), white)
		# --- Shadow healer: the Strings (a demon holding allies up on puppet strings) ---
		"puppetstring":
			# String: one thread from above, and who hangs on it.
			_demon_hand(c, mid + Vector2(0, -17) * k, 0.8 * k, HOUND_RED, white)
			_thread(c, mid + Vector2(0, -8) * k, mid + Vector2(0, -2) * k, STRING_PALE, 1.6 * k)
			_figure(c, mid + Vector2(0, 18) * k, 0.85 * k, light)
		"patchup":
			# Patch Up: a patch sewn on, stitch by stitch.
			var patch := Rect2(mid + Vector2(-11, -11) * k, Vector2(22, 22) * k)
			c.draw_rect(patch, col.darkened(0.2), true)
			c.draw_rect(patch, light, false, 1.6 * k)
			for i in 4:
				c.draw_line(mid + Vector2(-15, -9 + i * 6) * k, mid + Vector2(-9, -7 + i * 6) * k, STRING_PALE, 1.5 * k, true)
				c.draw_line(mid + Vector2(15, -9 + i * 6) * k, mid + Vector2(9, -7 + i * 6) * k, STRING_PALE, 1.5 * k, true)
			_plus(c, mid, 6.0 * k, HEAL_GREEN, 3.4 * k)
		"hoist":
			# Hoist: lifted clear of the ground on two threads.
			for sx: float in [-1.0, 1.0]:
				_thread(c, mid + Vector2(8 * sx, -20) * k, mid + Vector2(4 * sx, -6) * k, STRING_PALE, 1.5 * k)
			_figure(c, mid + Vector2(0, 9) * k, 0.8 * k, white)
			c.draw_line(mid + Vector2(-13, 17) * k, mid + Vector2(13, 17) * k, Color(light, 0.7), 1.8 * k, true)
			for sx: float in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(15 * sx, -6), Vector2(11 * sx, 1), Vector2(19 * sx, 1)]), HEAL_GREEN)
		"tug":
			# Tug: a thread jerked taut, and the hand that jerked it.
			_demon_hand(c, mid + Vector2(-7, -16) * k, 0.8 * k, HOUND_RED, white)
			_zigzag(c, mid, k, [Vector2(-7, -7), Vector2(-2, -2), Vector2(-9, 3), Vector2(-3, 8), Vector2(-7, 13)], STRING_PALE, 1.8)
			for i in 3:
				c.draw_arc(mid + Vector2(6, 4) * k, (4.0 + i * 4.5) * k, -PI * 0.35, PI * 0.35, 8, Color(HEAL_GREEN, 0.95 - i * 0.25), 1.8 * k, true)
		"catscradle":
			# Cat's Cradle: threads crossed between its two hands.
			for sx: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(15 * sx, -15) * k, mid + Vector2(15 * sx, 15) * k, HOUND_RED, 4.0 * k, true)
			for row in [[-12, 12], [12, -12], [-12, -4], [4, 12], [-4, -12], [12, 4]]:
				c.draw_line(mid + Vector2(-13, float(row[0])) * k, mid + Vector2(13, float(row[1])) * k, STRING_PALE, 1.4 * k, true)
		"wrench":
			# Wrench: the thread on an enemy, twisted hard.
			_figure(c, mid + Vector2(7, 18) * k, 0.8 * k, HOUND_RED)
			_zigzag(c, mid, k, [Vector2(-16, -18), Vector2(-6, -12), Vector2(-12, -6), Vector2(0, -3), Vector2(7, -4)], STRING_PALE, 1.8)
			_star(c, mid + Vector2(7, -2) * k, 6.0 * k, white, 6)
		"pulltaut":
			# Pull Taut: one thread drawn tight between two fists, humming.
			for sx: float in [-1.0, 1.0]:
				c.draw_circle(mid + Vector2(15 * sx, 0) * k, 4.5 * k, HOUND_RED)
				c.draw_arc(mid + Vector2(15 * sx, 0) * k, 4.5 * k, 0, TAU, 14, light, 1.3 * k, true)
			c.draw_line(mid + Vector2(-11, 0) * k, mid + Vector2(11, 0) * k, STRING_PALE, 2.2 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-6 + i * 6, -9) * k, mid + Vector2(-6 + i * 6, -4) * k, HEAL_GREEN, 1.6 * k, true)
				c.draw_line(mid + Vector2(-6 + i * 6, 4) * k, mid + Vector2(-6 + i * 6, 9) * k, HEAL_GREEN, 1.6 * k, true)
		"cuppedhands":
			# Cupped Hands: two great hands closed round a small figure.
			c.draw_arc(mid + Vector2(0, 2) * k, 15.0 * k, PI * 0.62, PI * 1.38, 16, HOUND_RED, 5.0 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 15.0 * k, -PI * 0.38, PI * 0.38, 16, HOUND_RED, 5.0 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 18.0 * k, PI * 0.62, PI * 1.38, 16, light, 1.3 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 18.0 * k, -PI * 0.38, PI * 0.38, 16, light, 1.3 * k, true)
			_figure(c, mid + Vector2(0, 12) * k, 0.75 * k, white)
		"stringup":
			# String Up: an enemy hanging well clear of the floor.
			for sx: float in [-1.0, 1.0]:
				_thread(c, mid + Vector2(11 * sx, -20) * k, mid + Vector2(5 * sx, -9) * k, STRING_PALE, 1.5 * k)
			_figure(c, mid + Vector2(0, 6) * k, 0.8 * k, HOUND_RED)
			c.draw_line(mid + Vector2(-15, 17) * k, mid + Vector2(15, 17) * k, light, 2.0 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-5 + i * 5, 9) * k, mid + Vector2(-5 + i * 5, 13) * k, Color(light, 0.6), 1.3 * k, true)
		"restring":
			# Restring: the thread taken off one and tied to another.
			_figure(c, mid + Vector2(-11, 18) * k, 0.6 * k, Color(light, 0.5))
			_figure(c, mid + Vector2(11, 18) * k, 0.6 * k, white)
			c.draw_line(mid + Vector2(-11, -16) * k, mid + Vector2(-11, -2) * k, Color(STRING_PALE, 0.35), 1.4 * k, true)
			_thread(c, mid + Vector2(11, -16) * k, mid + Vector2(11, 2) * k, STRING_PALE, 1.6 * k)
			c.draw_arc(mid + Vector2(0, -7) * k, 9.0 * k, PI * 1.15, PI * 1.85, 10, HEAL_GREEN, 1.9 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(10, -9), Vector2(4.5, -14.5), Vector2(11, -15)]), HEAL_GREEN)
		"knot":
			# Knot: the thread tied off so it cannot slip.
			c.draw_line(mid + Vector2(0, -19) * k, mid + Vector2(0, -8) * k, STRING_PALE, 2.0 * k, true)
			c.draw_arc(mid + Vector2(-4, 0) * k, 7.0 * k, 0, TAU, 20, STRING_PALE, 2.2 * k, true)
			c.draw_arc(mid + Vector2(4, 0) * k, 7.0 * k, 0, TAU, 20, STRING_PALE, 2.2 * k, true)
			c.draw_circle(mid, 3.2 * k, light)
			c.draw_line(mid + Vector2(-2, 8) * k, mid + Vector2(-7, 18) * k, STRING_PALE, 2.0 * k, true)
			c.draw_line(mid + Vector2(2, 8) * k, mid + Vector2(7, 18) * k, STRING_PALE, 2.0 * k, true)
		"tangle":
			# Tangle: threads strung low across the floor, and the feet caught in them.
			_hole(c, mid + Vector2(0, 6) * k, Vector2(17, 9) * k, light, 1.4 * k)
			for row in [[-17, 2, 17, 9], [-15, 11, 15, 0], [-10, -2, 12, 13], [-12, 13, 9, -2]]:
				c.draw_line(mid + Vector2(float(row[0]), float(row[1])) * k, mid + Vector2(float(row[2]), float(row[3])) * k, STRING_PALE, 1.4 * k, true)
			for sx: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(4 * sx, -17) * k, mid + Vector2(4 * sx, 4) * k, HOUND_RED, 3.4 * k, true)
				c.draw_line(mid + Vector2(4 * sx, 5) * k, mid + Vector2(4 * sx + 5, 6) * k, HOUND_RED, 3.4 * k, true)
		"yank":
			# Yank: hauled across the room on the thread.
			_figure(c, mid + Vector2(10, 16) * k, 0.8 * k, white)
			c.draw_line(mid + Vector2(-19, -6) * k, mid + Vector2(8, -2) * k, STRING_PALE, 1.8 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(15 + i * 2.5, -12 + i * 7) * k, mid + Vector2(20 + i * 1.5, -12 + i * 7) * k, Color(light, 0.7), 1.5 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-19, 8), Vector2(-9, 2), Vector2(-9, 14)]), HEAL_GREEN)
			c.draw_line(mid + Vector2(-9, 8) * k, mid + Vector2(0, 8) * k, HEAL_GREEN, 3.0 * k, true)
		"doublethread":
			# Double Thread: two threads where there was one.
			_demon_hand(c, mid + Vector2(0, -17) * k, 0.8 * k, HOUND_RED, white)
			for sx: float in [-1.0, 1.0]:
				_thread(c, mid + Vector2(3 * sx, -8) * k, mid + Vector2(5 * sx, 1) * k, STRING_PALE, 1.6 * k)
			_figure(c, mid + Vector2(0, 19) * k, 0.8 * k, light)
		"behinditsback":
			# Behind Its Back: the demon, horned and huge, and you small in front of it.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-15, 17), Vector2(-17, -2), Vector2(-9, -12), Vector2(9, -12), Vector2(17, -2), Vector2(15, 17)]),
				HOUND_RED.darkened(0.25))
			for sx: float in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(9 * sx, -11), Vector2(4 * sx, -12), Vector2(13 * sx, -20)]), light)
				c.draw_circle(mid + Vector2(5 * sx, -5) * k, 1.9 * k, white)
			_figure(c, mid + Vector2(0, 18) * k, 0.7 * k, white)
		"slack":
			# Slack: a thread let go loose, and what runs back along it.
			for sx: float in [-1.0, 1.0]:
				c.draw_circle(mid + Vector2(16 * sx, -12) * k, 3.2 * k, HOUND_RED)
			c.draw_arc(mid + Vector2(0, -19) * k, 22.0 * k, PI * 0.2, PI * 0.8, 16, STRING_PALE, 1.9 * k, true)
			var drop := _pts(mid + Vector2(0, 9) * k, k, [Vector2(0, -8), Vector2(5, 1), Vector2(3.5, 6), Vector2(0, 7.5), Vector2(-3.5, 6), Vector2(-5, 1)])
			c.draw_colored_polygon(drop, Color(0.35, 0.55, 1.0))
			drop.append(drop[0])
			c.draw_polyline(drop, white, 1.3 * k, true)
		"stillstanding":
			# Still Standing: on its feet only because the threads will not let it fall.
			for sx: float in [-1.0, 1.0]:
				_thread(c, mid + Vector2(13 * sx, -20) * k, mid + Vector2(7 * sx, -2) * k, STRING_PALE, 1.5 * k)
			_thread(c, mid + Vector2(0, -20) * k, mid + Vector2(0, -12) * k, STRING_PALE, 1.5 * k)
			_figure(c, mid + Vector2(0, 15) * k, 0.85 * k, white)
			c.draw_rect(Rect2(mid + Vector2(-14, 17) * k, Vector2(28, 4) * k), Color(0, 0, 0, 0.55), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 17) * k, Vector2(4, 4) * k), Color(0.85, 0.2, 0.2), true)
		"cutthestrings":
			# Cut the Strings: every thread parted by one stroke.
			for i in 4:
				var x := -12.0 + i * 8.0
				c.draw_line(mid + Vector2(x, -19) * k, mid + Vector2(x, -5 + i * 2.5) * k, STRING_PALE, 1.6 * k, true)
				c.draw_line(mid + Vector2(x + 1.5, 1 + i * 2.5) * k, mid + Vector2(x + 3.0, 18) * k, Color(STRING_PALE, 0.55), 1.6 * k, true)
			c.draw_line(mid + Vector2(-19, -7) * k, mid + Vector2(19, 5) * k, white, 3.0 * k, true)
			c.draw_line(mid + Vector2(-19, -7) * k, mid + Vector2(-13, -11) * k, HOUND_RED, 3.0 * k, true)
		"notfinished":
			# Not Finished With You: the fallen dragged back upright.
			_thread(c, mid + Vector2(-2, -20) * k, mid + Vector2(-9, -3) * k, STRING_PALE, 1.6 * k)
			_thread(c, mid + Vector2(8, -20) * k, mid + Vector2(8, 6) * k, STRING_PALE, 1.6 * k)
			c.draw_circle(mid + Vector2(-11, 0) * k, 3.6 * k, white)
			c.draw_line(mid + Vector2(-8, 3) * k, mid + Vector2(9, 12) * k, white, 6.0 * k, true)
			c.draw_line(mid + Vector2(-17, 17) * k, mid + Vector2(17, 17) * k, light, 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(16, -16), Vector2(12, -9), Vector2(20, -9)]), HEAL_GREEN)
		# --- Shadow caster: the Breach ("decay" in the code), a hole under the enemy and the hands clawing out of it ---
		"blight":
			# Break Ground: the floor splits, and the first hand is through.
			for crack in [[Vector2(-18, 6), Vector2(-9, 9)], [Vector2(18, 5), Vector2(10, 9)],
					[Vector2(-13, 17), Vector2(-6, 13)], [Vector2(14, 17), Vector2(7, 13)]]:
				c.draw_line(mid + (crack[0] as Vector2) * k, mid + (crack[1] as Vector2) * k, light, 1.6 * k, true)
			_hole(c, mid + Vector2(0, 10) * k, Vector2(11, 4.5) * k, light, 1.8 * k)
			_claw(c, mid + Vector2(0, 10) * k, Vector2(0.12, -1).normalized(), 25.0 * k, col.lightened(0.15), white, 2.2 * k)
		"erode":
			# Beckon: a crooked finger from above, and a hand below that answers it.
			_hole(c, mid + Vector2(0, 13) * k, Vector2(13, 4) * k, light, 1.6 * k)
			_claw(c, mid + Vector2(-3, 13) * k, Vector2(-0.1, -1).normalized(), 14.0 * k, col.lightened(0.15), light, 1.9 * k)
			c.draw_line(mid + Vector2(14, -17) * k, mid + Vector2(8, -9) * k, white, 3.4 * k, true)
			c.draw_arc(mid + Vector2(4.5, -9.5) * k, 3.6 * k, -0.2, PI + 0.5, 10, white, 2.6 * k, true)
		"calldue":
			# Call Due: they have it by the legs, and it is going under.
			_hole(c, mid + Vector2(0, 11) * k, Vector2(15, 5) * k, light, 1.8 * k)
			c.draw_circle(mid + Vector2(0, -12) * k, 4.2 * k, white)
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(0, 9) * k, white, 3.0 * k, true)
			c.draw_line(mid + Vector2(-8, -15) * k, mid + Vector2(0, -4) * k, white, 2.2 * k, true)
			c.draw_line(mid + Vector2(8, -15) * k, mid + Vector2(0, -4) * k, white, 2.2 * k, true)
			_claw(c, mid + Vector2(-11, 11) * k, Vector2(0.55, -1).normalized(), 15.0 * k, col.lightened(0.15), light, 1.9 * k)
			_claw(c, mid + Vector2(11, 11) * k, Vector2(-0.55, -1).normalized(), 15.0 * k, col.lightened(0.15), light, 1.9 * k)
		"gnaw":
			# Gnaw: a leg, and the teeth that have closed on it from the hole.
			_hole(c, mid + Vector2(0, 13) * k, Vector2(15, 4.5) * k, light, 1.6 * k)
			c.draw_line(mid + Vector2(2, -18) * k, mid + Vector2(0, 4) * k, white, 5.0 * k, true)
			c.draw_line(mid + Vector2(0, 4) * k, mid + Vector2(7, 6) * k, white, 4.0 * k, true)
			for i in 3:
				var y := -4.0 + i * 5.0
				c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, y - 3), Vector2(-14, y + 3), Vector2(-3.5, y)]), col.lightened(0.3))
				c.draw_colored_polygon(_pts(mid, k, [Vector2(16, y - 3), Vector2(16, y + 3), Vector2(5.5, y)]), col.lightened(0.3))
			c.draw_line(mid + Vector2(-14, -8) * k, mid + Vector2(-14, 10) * k, col, 2.4 * k, true)
			c.draw_line(mid + Vector2(16, -8) * k, mid + Vector2(16, 10) * k, col, 2.4 * k, true)
		"spill":
			# Widen: the hole under one enemy cracks through to the ground under the others.
			_hole(c, mid + Vector2(0, -2) * k, Vector2(9, 4) * k, light, 1.8 * k)
			_claw(c, mid + Vector2(0, -2) * k, Vector2(0, -1), 14.0 * k, col.lightened(0.15), white, 1.8 * k)
			for sx: float in [-1.0, 1.0]:
				c.draw_polyline(_pts(mid, k, [Vector2(8 * sx, 0), Vector2(11 * sx, 5), Vector2(10 * sx, 8), Vector2(13 * sx, 11)]),
					light, 1.5 * k, true)
				_hole(c, mid + Vector2(13 * sx, 13) * k, Vector2(6, 2.8) * k, Color(light, 0.85), 1.4 * k)
				_claw(c, mid + Vector2(13 * sx, 13) * k, Vector2(0, -1), 8.0 * k, col.lightened(0.15), light, 1.3 * k)
		"pall":
			# Many Hands (ability id "pall", the name it was first given): a whole patch of ground reaching up.
			c.draw_line(mid + Vector2(-18, 15) * k, mid + Vector2(18, 15) * k, light, 2.0 * k, true)
			var heights := [13.0, 22.0, 16.0, 26.0, 14.0]
			for i in 5:
				_claw(c, mid + Vector2(-14.0 + i * 7.0, 15) * k, Vector2((i - 2) * 0.09, -1).normalized(), float(heights[i]) * k,
					col.lightened(0.1 + 0.08 * (i % 2)), white if i % 2 == 1 else light, 1.6 * k)
		"hush":
			# Hush: a mouth, and the hand from below that has shut it.
			c.draw_arc(mid + Vector2(0, -22) * k, 16.0 * k, PI * 0.3, PI * 0.7, 10, light, 2.4 * k, true)
			c.draw_line(mid + Vector2(-10, -9) * k, mid + Vector2(10, -9) * k, white, 2.6 * k, true)
			_claw(c, mid + Vector2(0, 18) * k, Vector2(0, -1), 30.0 * k, col.lightened(0.15), white, 2.4 * k)
		"takeitback":
			# Take It Back: a hand called out of the hole to stand in front of you, palm out, on a shield.
			var guard := _pts(mid, k, [Vector2(-13, -15), Vector2(13, -15), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)])
			c.draw_colored_polygon(guard, col.darkened(0.3))
			guard.append(guard[0])
			c.draw_polyline(guard, light, 1.9 * k, true)
			_claw(c, mid + Vector2(0, 17) * k, Vector2(0, -1), 26.0 * k, col.lightened(0.2), white, 2.2 * k)
		"bottomless":
			# Bottomless: the hole from above, ring under ring with no floor, and the hands over its edge.
			for i in 4:
				c.draw_arc(mid + Vector2(0, i * 2.0) * k, (16.0 - i * 4.0) * k, 0, TAU, 24, Color(light, 1.0 - i * 0.22),
					(2.4 - i * 0.3) * k, true)
			c.draw_circle(mid + Vector2(0, 7) * k, 3.0 * k, Color(0.05, 0.02, 0.09))
			for a: float in [PI * 1.2, PI * 1.8, PI * 0.5]:
				var over := Vector2(cos(a), sin(a))
				_claw(c, mid + over * 9.0 * k, over, 10.0 * k, col.lightened(0.15), white, 1.3 * k)
		# --- Nature ---
		"thornshot":
			# Three thorns flying up and to the right.
			for o in [Vector2(-8, 6), Vector2(0, 0), Vector2(-2, 12)]:
				var b := mid + (o as Vector2) * k
				c.draw_colored_polygon(PackedVector2Array([b + Vector2(-6, 6) * k, b + Vector2(10, -10) * k, b + Vector2(-3, 8) * k]), light)
				c.draw_line(b + Vector2(-12, 12) * k, b + Vector2(-5, 5) * k, Color(col, 0.6), 1.4 * k, true)
		"briartiger":
			# A tiger's head woven of vines: ears, eyes and vine stripes.
			c.draw_circle(mid + Vector2(0, 2) * k, 12.0 * k, col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, -6), Vector2(-9, -15), Vector2(-3, -9)]), col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(12, -6), Vector2(9, -15), Vector2(3, -9)]), col)
			for s in [-1.0, 1.0]:
				c.draw_polyline(_pts(mid, k, [Vector2(s * 11, -2), Vector2(s * 6, 0), Vector2(s * 10, 3)]), light, 1.6 * k, true)
				c.draw_circle(mid + Vector2(s * 4.5, -2) * k, 1.8 * k, white)
			c.draw_line(mid + Vector2(0, -10) * k, mid + Vector2(0, -4) * k, light, 1.6 * k, true)
			c.draw_circle(mid + Vector2(0, 6) * k, 2.0 * k, Color(0.15, 0.1, 0.05))
		"mossback":
			# A big bear's head with round ears and moss on its brow.
			c.draw_circle(mid + Vector2(-10, -10) * k, 5.0 * k, col)
			c.draw_circle(mid + Vector2(10, -10) * k, 5.0 * k, col)
			c.draw_circle(mid + Vector2(0, 2) * k, 13.0 * k, col)
			c.draw_circle(mid + Vector2(0, 7) * k, 5.5 * k, col.lightened(0.25))
			c.draw_circle(mid + Vector2(0, 5) * k, 2.0 * k, Color(0.15, 0.1, 0.05))
			c.draw_circle(mid + Vector2(-5, -1) * k, 1.6 * k, white)
			c.draw_circle(mid + Vector2(5, -1) * k, 1.6 * k, white)
			for p in [Vector2(-7, -8), Vector2(-2, -10), Vector2(3, -9), Vector2(8, -7)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.2 * k, light)
		"thornwing":
			# A diving hawk, wings swept back, thorny edges.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, 14), Vector2(-4, 2), Vector2(-16, -10), Vector2(-6, -6),
				Vector2(0, -12), Vector2(6, -6), Vector2(16, -10), Vector2(4, 2)]), col)
			for s in [-1.0, 1.0]:
				for i in 3:
					var at := mid + Vector2(s * (7 + i * 3), -7 - i * 1.0) * k
					c.draw_line(at, at + Vector2(s * 2, -4) * k, light, 1.4 * k, true)
			c.draw_circle(mid + Vector2(0, 9) * k, 1.6 * k, white)
		"chokingvipers":
			# Two vipers coiled around a point, heads raised.
			for s in [-1.0, 1.0]:
				var prev := mid + Vector2(s * 12, 14) * k
				for i in 14:
					var t := (i + 1) / 14.0
					var p := mid + Vector2(s * (12 - t * 12) * cos(t * 6.0), 14 - t * 26) * k
					c.draw_line(prev, p, light if s > 0 else col, (3.6 - t * 1.6) * k, true)
					prev = p
				c.draw_circle(prev, 3.0 * k, light if s > 0 else col)
				c.draw_circle(prev + Vector2(s * 1.2, -0.5) * k, 0.9 * k, white)
		"greenwoodstag":
			# A stag's head with wide branching antlers.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-5, -2), Vector2(5, -2), Vector2(3, 12), Vector2(-3, 12)]), col)
			for s in [-1.0, 1.0]:
				var base := mid + Vector2(s * 4, -3) * k
				var tip := mid + Vector2(s * 14, -15) * k
				c.draw_line(base, tip, light, 2.2 * k, true)
				c.draw_line(base.lerp(tip, 0.4), base.lerp(tip, 0.4) + Vector2(s * -2, -8) * k, light, 1.8 * k, true)
				c.draw_line(base.lerp(tip, 0.75), base.lerp(tip, 0.75) + Vector2(s * 6, -1) * k, light, 1.6 * k, true)
				c.draw_circle(mid + Vector2(s * 2.5, 2) * k, 1.4 * k, white)
		"dewfall":
			# Three dewdrops falling onto a leaf.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, 12), Vector2(-2, 4), Vector2(14, 8), Vector2(0, 15)]), col)
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(12, 8) * k, light, 1.2 * k, true)
			for p in [Vector2(-7, -10), Vector2(2, -3), Vector2(9, -12)]:
				var d := mid + (p as Vector2) * k
				c.draw_circle(d, 3.2 * k, light)
				c.draw_colored_polygon(PackedVector2Array([d + Vector2(-3, -0.5) * k, d + Vector2(0, -7) * k, d + Vector2(3, -0.5) * k]), light)
				c.draw_circle(d + Vector2(-1, -1) * k, 0.9 * k, white)
		"fawn":
			# A leaping fawn's head, big ears, spots, and a bouncing arc.
			c.draw_arc(mid + Vector2(0, 10) * k, 13.0 * k, PI * 1.1, PI * 1.9, 12, Color(light, 0.7), 1.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-6, -4), Vector2(6, -4), Vector2(3, 10), Vector2(-3, 10)]), col)
			for s in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(s * 5, -4), Vector2(s * 14, -10), Vector2(s * 7, -1)]), col)
				c.draw_circle(mid + Vector2(s * 3, 0) * k, 1.4 * k, white)
			for p in [Vector2(-2, -7), Vector2(2, -9), Vector2(0, -5)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.1 * k, light)
		"rootguard":
			# Roots curling up around a figure like a cage.
			c.draw_circle(mid + Vector2(0, -6) * k, 3.5 * k, white)
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(0, 8) * k, white, 3.0 * k, true)
			for s in [-1.0, 1.0]:
				for i in 2:
					var r := 9.0 + i * 5.0
					c.draw_arc(mid + Vector2(0, 14) * k, r * k, PI * 1.5 + s * 0.15, PI * 1.5 + s * (0.9 + i * 0.25), 10, col if i == 0 else light, 2.4 * k, true)
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(14, 15) * k, col, 2.0 * k, true)
		"owl":
			# An owl's face: two big round eyes, ear tufts and a beak.
			c.draw_circle(mid + Vector2(0, 2) * k, 13.0 * k, col)
			for s in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(s * 6, -9), Vector2(s * 12, -16), Vector2(s * 11, -6)]), col)
				c.draw_circle(mid + Vector2(s * 5.5, 0) * k, 4.8 * k, light)
				c.draw_circle(mid + Vector2(s * 5.5, 0) * k, 2.0 * k, Color(0.12, 0.08, 0.04))
				c.draw_circle(mid + Vector2(s * 5.0, -0.8) * k, 0.8 * k, white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-2, 4), Vector2(2, 4), Vector2(0, 9)]), white)
		"heartwoodelk":
			# A broad elk head with palm-shaped antlers and a glowing heart of wood.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-6, -3), Vector2(6, -3), Vector2(4, 13), Vector2(-4, 13)]), col)
			for s in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(s * 5, -4), Vector2(s * 15, -8), Vector2(s * 16, -15), Vector2(s * 11, -12),
					Vector2(s * 10, -16), Vector2(s * 7, -11), Vector2(s * 4, -14)]), light)
				c.draw_circle(mid + Vector2(s * 2.5, 2) * k, 1.3 * k, white)
			c.draw_circle(mid + Vector2(0, 7) * k, 2.4 * k, light)
		"wildherd":
			# Three fawns running in a row, one behind the other.
			for i in 3:
				var o := mid + Vector2(-9 + i * 9, 6 - i * 6) * k
				c.draw_colored_polygon(PackedVector2Array([o + Vector2(-6, 2) * k, o + Vector2(4, -2) * k, o + Vector2(7, -6) * k,
					o + Vector2(8, -2) * k, o + Vector2(4, 3) * k, o + Vector2(-5, 5) * k]), col if i != 1 else light)
				c.draw_line(o + Vector2(-4, 4) * k, o + Vector2(-7, 9) * k, col, 1.4 * k, true)
				c.draw_line(o + Vector2(3, 3) * k, o + Vector2(6, 8) * k, col, 1.4 * k, true)
		"returntobloom":
			# A figure rising out of a ring of vines that curl up into a bloom.
			c.draw_line(mid + Vector2(-14, 12) * k, mid + Vector2(14, 12) * k, col, 2.0 * k, true)
			for s in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(s * 9, 12) * k, 7.0 * k, PI, PI * 1.5 if s < 0 else PI * 2.0, 8, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(0, 11) * k, mid + Vector2(0, -2) * k, white, 3.0 * k, true)
			c.draw_circle(mid + Vector2(0, -6) * k, 3.5 * k, white)
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2.0
				c.draw_circle(mid + Vector2(0, -6) * k + Vector2(cos(a), sin(a)) * 6.5 * k, 2.4 * k, Color(light, 0.85))
		"hymnofwaking":
			# A column of light over a resting figure, music notes rising in it.
			c.draw_rect(Rect2(mid + Vector2(-5, -16) * k, Vector2(10, 28) * k), Color(light, 0.45))
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(12, 12) * k, white, 3.0 * k, true)
			for p in [Vector2(-2, -10), Vector2(2, -2)]:
				var o := mid + (p as Vector2) * k
				c.draw_circle(o, 2.0 * k, col)
				c.draw_line(o + Vector2(1.8, 0) * k, o + Vector2(1.8, -6) * k, col, 1.2 * k, true)
		"relight":
			# A white beam striking down onto a figure made of light shards.
			c.draw_line(mid + Vector2(-12, -16) * k, mid + Vector2(0, -2) * k, white, 3.0 * k, true)
			for p in [Vector2(-4, 2), Vector2(4, 2), Vector2(0, 8), Vector2(-3, 13), Vector2(3, 13)]:
				var o := mid + (p as Vector2) * k
				c.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -3) * k, o + Vector2(2.5, 0) * k, o + Vector2(0, 3) * k, o + Vector2(-2.5, 0) * k]), light)
			c.draw_circle(mid + Vector2(0, -3) * k, 3.2 * k, col)
		"backonyourfeet":
			# A puppet figure lifted upright by three strings from above.
			c.draw_line(mid + Vector2(-12, -15) * k, mid + Vector2(12, -15) * k, col, 2.4 * k, true)
			for x in [-8.0, 0.0, 8.0]:
				c.draw_line(mid + Vector2(x, -15) * k, mid + Vector2(x * 0.6, -4 if x == 0.0 else 2) * k, light, 1.0 * k, true)
			c.draw_circle(mid + Vector2(0, -6) * k, 3.2 * k, white)
			c.draw_line(mid + Vector2(0, -3) * k, mid + Vector2(0, 7) * k, white, 2.6 * k, true)
			c.draw_line(mid + Vector2(-5, 2) * k, mid + Vector2(5, 2) * k, white, 2.0 * k, true)
			for s in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(0, 7) * k, mid + Vector2(s * 4, 14) * k, white, 2.0 * k, true)
		"rootsnare":
			# Roots snapping up out of the ground and closing over a foot.
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(15, 12) * k, col, 2.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-4, -2) * k, Vector2(8, 12) * k), white)
			for s in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(s * 6, 12) * k, 8.0 * k, PI * 1.5 - s * 0.2, PI * 1.5 - s * 1.6, 10, light, 2.4 * k, true)
				c.draw_arc(mid + Vector2(s * 11, 12) * k, 6.0 * k, PI * 1.5 - s * 0.1, PI * 1.5 - s * 1.4, 8, col, 1.8 * k, true)
		"bellows":
			# A forge bellows on the left, a hot gust blowing out of its nozzle.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, -8), Vector2(-4, -3), Vector2(-4, 3), Vector2(-16, 8)]), Color(0.45, 0.32, 0.22))
			c.draw_line(mid + Vector2(-16, -8) * k, mid + Vector2(-16, 8) * k, white, 1.6 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-4, -1.5) * k, Vector2(5, 3) * k), light)
			for i in 3:
				var y := -7.0 + i * 7.0
				c.draw_arc(mid + Vector2(4, y) * k, 6.0 * k, -PI * 0.35, PI * 0.35, 8, col, 2.0 * k, true)
				c.draw_arc(mid + Vector2(10, y) * k, 6.0 * k, -PI * 0.3, PI * 0.3, 8, light, 1.6 * k, true)
		"deeproots":
			# A figure standing still, roots spreading deep beneath its feet.
			c.draw_circle(mid + Vector2(0, -11) * k, 3.2 * k, white)
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(0, 2) * k, white, 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 3) * k, mid + Vector2(12, 3) * k, col, 2.0 * k, true)
			for x in [-8.0, -3.0, 3.0, 8.0]:
				c.draw_line(mid + Vector2(x * 0.4, 3) * k, mid + Vector2(x, 15) * k, light, 1.8 * k, true)
		"sporesleep":
			# A cloud of spores with a sleepy "z z" drifting up.
			for p in [Vector2(-7, 4), Vector2(0, 0), Vector2(7, 4), Vector2(-3, 8), Vector2(4, 9)]:
				c.draw_circle(mid + (p as Vector2) * k, 5.0 * k, Color(col, 0.75))
			for p in [Vector2(-9, -2), Vector2(2, -4), Vector2(8, -1), Vector2(-2, 6)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.2 * k, light)
			for z in [[Vector2(3, -9), 4.0], [Vector2(9, -15), 3.0]]:
				var o: Vector2 = mid + (z[0] as Vector2) * k
				var s := float(z[1]) * k
				c.draw_polyline(PackedVector2Array([o, o + Vector2(s, 0), o + Vector2(0, s), o + Vector2(s, s)]), white, 1.4 * k, true)
		"stormfront":
			# A storm cloud racing right, wind lines streaming behind it.
			for p in [Vector2(-2, -4), Vector2(5, -6), Vector2(10, -2), Vector2(3, 0)]:
				c.draw_circle(mid + (p as Vector2) * k, 5.5 * k, Color(0.55, 0.6, 0.75))
			c.draw_polyline(_pts(mid, k, [Vector2(5, 2), Vector2(2, 9), Vector2(6, 9), Vector2(3, 16)]), light, 2.0 * k, true)
			for i in 3:
				var y := -8.0 + i * 6.0
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-9, y) * k, col, 1.8 * k, true)
		"circleofsilence":
			# A ring of light on the ground around a crossed-out speech mark.
			c.draw_arc(mid + Vector2(0, 2) * k, 13.0 * k, 0, TAU, 28, col, 2.4 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 9.0 * k, 0, TAU, 22, Color(light, 0.5), 1.2 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(-4, 2) * k, (3.0 + i * 3.0) * k, -PI * 0.3, PI * 0.3, 6, white, 1.4 * k, true)
			c.draw_line(mid + Vector2(-8, 10) * k, mid + Vector2(8, -6) * k, light, 2.4 * k, true)
		"climbthestring":
			# A figure hauled up along a taut thread toward a far point.
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(14, -14) * k, col, 1.6 * k, true)
			c.draw_circle(mid + Vector2(14, -14) * k, 2.5 * k, light)
			c.draw_circle(mid + Vector2(-3, 1) * k, 3.0 * k, white)
			c.draw_line(mid + Vector2(-5, 4) * k, mid + Vector2(-10, 12) * k, white, 2.6 * k, true)
			c.draw_line(mid + Vector2(-3, 1) * k, mid + Vector2(2, -2) * k, white, 2.0 * k, true)
			for i in 2:
				c.draw_line(mid + Vector2(-12 - i * 3, 6 - i * 4) * k, mid + Vector2(-8 - i * 3, 2 - i * 4) * k, Color(light, 0.6), 1.2 * k, true)
		"leafcloak":
			# A hooded shape made of overlapping leaves.
			for p in [Vector2(-6, 2), Vector2(6, 2), Vector2(0, -6), Vector2(-3, 10), Vector2(3, 10)]:
				var o := mid + (p as Vector2) * k
				c.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -6) * k, o + Vector2(4, 0) * k, o + Vector2(0, 6) * k, o + Vector2(-4, 0) * k]),
					col if p.y > 0 else light)
				c.draw_line(o + Vector2(0, -5) * k, o + Vector2(0, 5) * k, Color(white, 0.5), 0.8 * k, true)
			c.draw_circle(mid + Vector2(0, -3) * k, 2.0 * k, Color(0.1, 0.12, 0.08))
		"coolingslag":
			# A molten pool: glowing at the middle, gone grey and hard at the rim.
			c.draw_circle(mid + Vector2(0, 4) * k, 14.0 * k, Color(0.45, 0.4, 0.38))
			c.draw_circle(mid + Vector2(0, 4) * k, 10.0 * k, col)
			c.draw_circle(mid + Vector2(0, 4) * k, 5.0 * k, light)
			for p in [Vector2(-7, -8), Vector2(5, -11)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.8 * k, light)
		"staticsnare":
			# A bolt pinning the ground, with a spark leaping to a second spot.
			c.draw_polyline(_pts(mid, k, [Vector2(-6, -15), Vector2(-1, -4), Vector2(-5, -3), Vector2(0, 9)]), white, 2.6 * k, true)
			c.draw_arc(mid + Vector2(0, 11) * k, 6.0 * k, 0, TAU, 14, col, 2.0 * k, true)
			c.draw_arc(mid + Vector2(6, 4) * k, 8.0 * k, -PI * 0.6, PI * 0.1, 8, Color(light, 0.8), 1.4 * k, true)
			c.draw_circle(mid + Vector2(13, 6) * k, 2.2 * k, light)
		"fixedpoint":
			# A clock face with a pin through its middle.
			c.draw_arc(mid, 12.0 * k, 0, TAU, 24, col, 2.4 * k, true)
			for i in 4:
				var a := TAU * i / 4.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 9.0 * k, mid + Vector2(cos(a), sin(a)) * 11.0 * k, light, 1.6 * k, true)
			c.draw_line(mid, mid + Vector2(0, -8) * k, white, 1.8 * k, true)
			c.draw_line(mid, mid + Vector2(6, 0) * k, white, 1.8 * k, true)
			c.draw_circle(mid, 2.4 * k, light)
		"bindingring":
			# A figure inside a golden ring; a small enemy caught at its edge.
			c.draw_arc(mid + Vector2(0, 4) * k, 13.0 * k, 0, TAU, 28, col, 2.6 * k, true)
			c.draw_circle(mid + Vector2(0, -2) * k, 3.0 * k, white)
			c.draw_line(mid + Vector2(0, 1) * k, mid + Vector2(0, 9) * k, white, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(10, 10), Vector2(16, 10), Vector2(13, 16)]), light)
		"vinefist":
			# A big fist of braided vines punching forward, glowing veins on the knuckles.
			c.draw_rect(Rect2(mid + Vector2(-10, -8) * k, Vector2(18, 16) * k), col)
			c.draw_rect(Rect2(mid + Vector2(-16, -3) * k, Vector2(7, 9) * k), col.darkened(0.15))
			for i in 4:
				c.draw_line(mid + Vector2(-9 + i * 5, -8) * k, mid + Vector2(-9 + i * 5, -3) * k, light, 1.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(10, -6 + i * 6) * k, mid + Vector2(16, -6 + i * 6) * k, Color(light, 0.6), 1.6 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-10, 2), Vector2(-3, 4), Vector2(4, 1), Vector2(8, 5)]), light, 1.2 * k, true)
		"grasp":
			# A giant hand reaching up out of the ground, fingers curled.
			c.draw_line(mid + Vector2(-15, 14) * k, mid + Vector2(15, 14) * k, col.darkened(0.2), 2.4 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-7, 14), Vector2(7, 14), Vector2(8, 0), Vector2(-8, 0)]), col)
			for i in 4:
				var x := -7.0 + i * 4.7
				c.draw_polyline(_pts(mid, k, [Vector2(x, 0), Vector2(x - 1, -9), Vector2(x + 2, -13)]), col, 3.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-8, 4), Vector2(-14, -2), Vector2(-12, -7)]), col, 3.0 * k, true)
			c.draw_line(mid + Vector2(-4, 10) * k, mid + Vector2(4, 3) * k, light, 1.3 * k, true)
		"stomp":
			# A huge foot coming down, cracks spreading in the ground under it.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-10, -16), Vector2(4, -16), Vector2(5, 0), Vector2(13, 4), Vector2(13, 8), Vector2(-11, 8)]), col)
			c.draw_line(mid + Vector2(-8, -10) * k, mid + Vector2(2, -4) * k, light, 1.3 * k, true)
			for v in [Vector2(-15, 15), Vector2(-4, 16), Vector2(8, 16), Vector2(16, 13)]:
				c.draw_line(mid + Vector2(0, 11) * k, mid + (v as Vector2) * k, light, 1.5 * k, true)
		"giantshands":
			# Two giant hands closing around a small figure.
			c.draw_circle(mid + Vector2(0, -2) * k, 3.0 * k, white)
			c.draw_line(mid + Vector2(0, 1) * k, mid + Vector2(0, 9) * k, white, 2.6 * k, true)
			for s in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(0, 2) * k, 13.0 * k, PI * 0.5 + s * 0.3, PI * 0.5 + s * 2.6, 14, col, 4.0 * k, true)
				for i in 3:
					var a: float = PI * 0.5 + s * (2.2 + i * 0.25)
					c.draw_line(mid + Vector2(0, 2) * k + Vector2(cos(a), sin(a)) * 13.0 * k,
						mid + Vector2(0, 2) * k + Vector2(cos(a), sin(a)) * 8.0 * k, light, 1.6 * k, true)
		"heartsap":
			# A tree trunk opened at the chest, golden sap pouring out.
			c.draw_rect(Rect2(mid + Vector2(-11, -15) * k, Vector2(22, 30) * k), col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -9), Vector2(-6, -1), Vector2(0, 7), Vector2(6, -1)]), Color(1.0, 0.72, 0.25))
			c.draw_circle(mid + Vector2(0, -1) * k, 2.4 * k, Color(1.0, 0.92, 0.6))
			for x in [-3.0, 0.0, 3.0]:
				c.draw_line(mid + Vector2(x, 6) * k, mid + Vector2(x * 1.4, 15) * k, Color(1.0, 0.72, 0.25), 1.6 * k, true)
		"awaken":
			# The whole vine giant's head and shoulders rising, glowing eyes.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, 16), Vector2(-14, 2), Vector2(-6, -2), Vector2(6, -2), Vector2(14, 2), Vector2(16, 16)]), col)
			c.draw_rect(Rect2(mid + Vector2(-7, -16) * k, Vector2(14, 15) * k), col.lightened(0.1))
			for s in [-1.0, 1.0]:
				c.draw_circle(mid + Vector2(s * 3, -10) * k, 1.8 * k, Color(0.75, 1.0, 0.4))
				c.draw_line(mid + Vector2(s * 6, -16) * k, mid + Vector2(s * 10, -20) * k, light, 1.6 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-12, 6), Vector2(-4, 10), Vector2(4, 6), Vector2(12, 10)]), light, 1.3 * k, true)
		"fangarrow", "adderarrow", "asparrow", "kraitarrow":
			# An arrow flying up-right with a woven snake coiled around its shaft, in its venom's colour.
			var venom: Color = {"fangarrow": light, "adderarrow": Color(0.4, 0.95, 0.3),
				"asparrow": Color(1.0, 0.85, 0.25), "kraitarrow": Color(0.92, 0.95, 1.0)}[id]
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(10, -10) * k, Color(0.6, 0.45, 0.28), 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(14, -14), Vector2(6, -11), Vector2(11, -6)]), white)
			var prev := mid + Vector2(-12, 12) * k
			for i in 12:
				var t := (i + 1) / 12.0
				var along := Vector2(-12, 12).lerp(Vector2(8, -8), t)
				var p := mid + (along + Vector2(1, 1).normalized() * sin(t * TAU * 2.0) * 4.0) * k
				c.draw_line(prev, p, venom, 2.2 * k, true)
				prev = p
			c.draw_circle(prev, 2.4 * k, venom)
			match id:
				"fangarrow":   # a fang
					c.draw_colored_polygon(_pts(mid, k, [Vector2(-2, -4), Vector2(2, -4), Vector2(0, 4)]), white)
				"adderarrow":   # drops falling from the head
					for p in [Vector2(-6, 2), Vector2(-9, 8)]:
						c.draw_circle(mid + (p as Vector2) * k, 1.8 * k, venom)
				"asparrow":   # slow lines behind
					for y in [4.0, 9.0]:
						c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(-9, y) * k, Color(venom, 0.8), 1.6 * k, true)
				"kraitarrow":   # dark bands on the snake
					for t in [0.3, 0.55, 0.8]:
						c.draw_circle(mid + Vector2(-12, 12).lerp(Vector2(8, -8), t) * k, 1.3 * k, Color(0.1, 0.1, 0.12))
		"venomburst":
			# A green explosion: a bright core and drops flying out.
			c.draw_circle(mid, 9.0 * k, Color(0.4, 0.95, 0.3, 0.55))
			c.draw_circle(mid, 5.0 * k, Color(0.75, 1.0, 0.5))
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + d * 9.0 * k, mid + d * 15.0 * k, light, 2.0 * k, true)
				c.draw_circle(mid + d * 16.0 * k, 1.8 * k, Color(0.4, 0.95, 0.3))
		"spittingvolley":
			# Arrows raining down onto a puddle of venom.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-15, 12), Vector2(0, 8), Vector2(15, 12), Vector2(0, 16)]), Color(0.4, 0.95, 0.3, 0.7))
			for x in [-9.0, 0.0, 9.0]:
				c.draw_line(mid + Vector2(x - 3, -15) * k, mid + Vector2(x, 6) * k, Color(0.6, 0.45, 0.28), 1.8 * k, true)
				c.draw_colored_polygon(_pts(mid, k, [Vector2(x - 2, 4), Vector2(x + 2, 4), Vector2(x + 0.5, 9)]), light)
		"bloatarrow":
			# A swollen round body pierced by an arrow, cracks of light.
			c.draw_circle(mid + Vector2(0, 2) * k, 12.0 * k, col)
			c.draw_line(mid + Vector2(-16, -10) * k, mid + Vector2(4, 0) * k, Color(0.6, 0.45, 0.28), 2.0 * k, true)
			for v in [Vector2(6, -8), Vector2(9, 6), Vector2(-4, 11), Vector2(-9, 2)]:
				c.draw_line(mid + Vector2(0, 2) * k, mid + (v as Vector2) * k, Color(0.75, 1.0, 0.5), 1.4 * k, true)
		"coilback":
			# A figure leaping back from a coiled thorn trap.
			c.draw_circle(mid + Vector2(8, -10) * k, 3.0 * k, white)
			c.draw_line(mid + Vector2(8, -7) * k, mid + Vector2(12, 2) * k, white, 2.4 * k, true)
			c.draw_arc(mid + Vector2(2, -2) * k, 9.0 * k, PI * 1.1, PI * 1.6, 8, Color(white, 0.6), 1.4 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(-7, 10) * k, (3.0 + i * 2.5) * k, 0, PI * 1.6, 10, light if i == 1 else col, 1.8 * k, true)
		"venomsurge":
			# Two snakes rising together around a glowing drop.
			for s in [-1.0, 1.0]:
				var prev := mid + Vector2(s * 4, 15) * k
				for i in 12:
					var t := (i + 1) / 12.0
					var p := mid + Vector2(s * sin(t * TAU * 1.2) * 9.0, 15 - t * 28) * k
					c.draw_line(prev, p, light if s > 0 else col, 2.4 * k, true)
					prev = p
				c.draw_circle(prev, 2.6 * k, light if s > 0 else col)
			c.draw_circle(mid, 4.0 * k, Color(0.4, 0.95, 0.3))
			c.draw_circle(mid + Vector2(-1, -1) * k, 1.2 * k, white)
		# --- Frost ---
		"froststrike":
			_sword(c, mid, k, col)
			for p in [Vector2(-10, -6), Vector2(-5, -12), Vector2(-13, -13)]:
				_star(c, mid + (p as Vector2) * k, 3.5 * k, light, 3)
		"frostarrow":
			_arrow_shaft(c, mid, k, col)
			for i in 3:
				var a := i * PI / 3.0
				var v := Vector2(cos(a), sin(a)) * 7.0 * k
				c.draw_line(mid + Vector2(10, -10) * k - v, mid + Vector2(10, -10) * k + v, light, 2.0 * k, true)
		"rimeshell":
			c.draw_circle(mid, 14.0 * k, Color(col, 0.25))
			c.draw_arc(mid, 14.0 * k, 0, TAU, 28, light, 2.5 * k, true)
			c.draw_arc(mid, 9.0 * k, PI * 1.1, PI * 1.5, 8, white, 2.5 * k, true)
			c.draw_circle(mid + Vector2(5, 5) * k, 2.0 * k, white)
		# --- Frost healer: Cold Comfort ---
		"meltwater":
			# A drop of meltwater falling from a block of ice.
			c.draw_rect(Rect2(mid + Vector2(-10, -16) * k, Vector2(20, 9) * k), Color(light, 0.8), true)
			c.draw_rect(Rect2(mid + Vector2(-10, -16) * k, Vector2(20, 9) * k), white, false, 1.5 * k)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -4), Vector2(7, 7), Vector2(0, 14), Vector2(-7, 7)]), Color(col, 0.9))
			c.draw_circle(mid + Vector2(0, 7) * k, 7.0 * k, Color(col, 0.9))
			c.draw_circle(mid + Vector2(-2.5, 5) * k, 2.0 * k, white)
		"rimeveil":
			# Three thin layers of ice over a heart of light.
			for i in 3:
				c.draw_arc(mid, (7.0 + i * 4.5) * k, PI * 1.05, PI * 1.95, 12, Color(white if i == 2 else light, 0.9 - i * 0.2), 2.0 * k, true)
			c.draw_circle(mid + Vector2(0, 3) * k, 5.0 * k, Color(col, 0.8))
			c.draw_circle(mid + Vector2(0, 3) * k, 2.0 * k, white)
		"breaktheice":
			# A shell split by a crack, two shards flying off.
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, light, 2.5 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-3, -13), Vector2(2, -5), Vector2(-3, 1), Vector2(3, 7), Vector2(0, 13)]), white, 2.5 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(13, -12), Vector2(18, -16), Vector2(16, -9)]), white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, 12), Vector2(-19, 15), Vector2(-16, 8)]), light)
		"frostlattice":
			# Three small shells joined by threads of ice.
			var spots := [Vector2(0, -11), Vector2(-11, 8), Vector2(11, 8)]
			for i in 3:
				c.draw_line(mid + (spots[i] as Vector2) * k, mid + (spots[(i + 1) % 3] as Vector2) * k, light, 2.0 * k, true)
			for p in spots:
				c.draw_circle(mid + (p as Vector2) * k, 5.0 * k, Color(col, 0.85))
				c.draw_arc(mid + (p as Vector2) * k, 5.0 * k, 0, TAU, 12, white, 1.5 * k, true)
		"rimefall":
			# Rime falling over a dome.
			c.draw_arc(mid + Vector2(0, 12) * k, 15.0 * k, PI, TAU, 18, light, 3.0 * k, true)
			for p in [Vector2(-9, -12), Vector2(0, -6), Vector2(9, -13), Vector2(-4, -16), Vector2(6, -2)]:
				_star(c, mid + (p as Vector2) * k, 2.5 * k, white, 3)
		"frosttide":
			# A breaking wave with a snowflake riding it.
			c.draw_polyline(_pts(mid, k, [Vector2(-16, 8), Vector2(-8, 2), Vector2(0, 6), Vector2(8, 0), Vector2(14, -8), Vector2(8, -12), Vector2(4, -6)]), light, 3.0 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-16, 14), Vector2(-6, 9), Vector2(4, 13), Vector2(16, 6)]), Color(col, 0.9), 2.5 * k, true)
			_star(c, mid + Vector2(-6, -8) * k, 4.5 * k, white, 3)
		"stillwater":
			# A figure held still inside a block of ice.
			c.draw_rect(Rect2(mid + Vector2(-11, -15) * k, Vector2(22, 30) * k), Color(col, 0.35), true)
			c.draw_rect(Rect2(mid + Vector2(-11, -15) * k, Vector2(22, 30) * k), light, false, 2.0 * k)
			c.draw_circle(mid + Vector2(0, -6) * k, 4.0 * k, white)
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(0, 9) * k, white, 3.0 * k, true)
			c.draw_line(mid + Vector2(-5, 2) * k, mid + Vector2(5, 2) * k, white, 2.0 * k, true)
		"springthaw":
			# A green shoot rising out of thawing ice.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, 14), Vector2(-10, 6), Vector2(10, 6), Vector2(16, 14)]), Color(light, 0.8))
			c.draw_line(mid + Vector2(0, 8) * k, mid + Vector2(0, -10) * k, Color(0.45, 0.9, 0.4), 3.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -6), Vector2(-9, -12), Vector2(-2, -2)]), Color(0.45, 0.9, 0.4))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(0, -2), Vector2(9, -8), Vector2(2, 2)]), Color(0.55, 1.0, 0.5))
			for p in [Vector2(-9, 10), Vector2(8, 10)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.5 * k, white)
		"shatteringwave":
			for i in 6:
				var a0 := TAU * i / 6.0
				c.draw_arc(mid, 14.0 * k, a0 + 0.12, a0 + TAU / 6.0 - 0.12, 6, light, 2.5 * k, true)
			for i in 6:
				var a := TAU * (i + 0.5) / 6.0
				c.draw_colored_polygon(PackedVector2Array([mid + Vector2(cos(a), sin(a)) * 4.0 * k,
					mid + Vector2(cos(a + 0.25), sin(a + 0.25)) * 9.0 * k, mid + Vector2(cos(a - 0.2), sin(a - 0.2)) * 10.0 * k]), col)
		"flashfreeze":
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, 12), Vector2(14, -4), Vector2(12, 8), Vector2(6, 16)]), Color(col, 0.45))
			for i in 3:
				var at := mid + Vector2(2 + i * 4, 6 - i * 3) * k
				_star(c, at, 3.5 * k, white, 3)
		"iceshards":
			# A fan of three sharp ice splinters flying up-right.
			for p in [Vector2(-10, 8), Vector2(-2, 2), Vector2(6, -6)]:
				var tip := mid + ((p as Vector2) + Vector2(8, -8)) * k
				var l := mid + ((p as Vector2) + Vector2(-3, -1)) * k
				var r := mid + ((p as Vector2) + Vector2(1, 3)) * k
				c.draw_line(mid + ((p as Vector2) + Vector2(-8, 8)) * k, mid + (p as Vector2) * k, Color(col, 0.45), 2.0 * k, true)
				c.draw_colored_polygon(PackedVector2Array([tip, l, r]), Color(col, 0.8))
				c.draw_polyline(PackedVector2Array([l, tip, r]), white, 1.4 * k, true)
		"hoarfrost":
			var hex := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				hex.append(mid + Vector2(cos(a), sin(a)) * 13.0 * k)
			c.draw_colored_polygon(hex, Color(col, 0.4))
			hex.append(hex[0])
			c.draw_polyline(hex, light, 2.0 * k, true)
			for i in 3:
				var a := i * PI / 3.0 + PI / 6.0
				var v := Vector2(cos(a), sin(a)) * 9.0 * k
				c.draw_line(mid - v, mid + v, white, 1.6 * k, true)
		"shatteringslam":
			# Hammer head smashing a cracked block of ice.
			c.draw_rect(Rect2(mid + Vector2(-12, 2) * k, Vector2(24, 13) * k), Color(col, 0.55), true)
			_zigzag(c, mid, k, [Vector2(-2, 2), Vector2(2, 7), Vector2(-3, 10), Vector2(1, 15)], white, 1.8)
			_zigzag(c, mid, k, [Vector2(2, 7), Vector2(9, 9), Vector2(12, 14)], white, 1.5)
			c.draw_rect(Rect2(mid + Vector2(-8, -12) * k, Vector2(16, 9) * k), Color(0.7, 0.7, 0.75), true)
			c.draw_line(mid + Vector2(0, -12) * k, mid + Vector2(0, -18) * k, Color(0.5, 0.33, 0.18), 3.0 * k)
		"rimeslash":
			c.draw_arc(mid + Vector2(-4, 4) * k, 15.0 * k, -1.5, 0.1, 14, Color(col, 0.6), 7.0 * k, true)
			c.draw_arc(mid + Vector2(-4, 4) * k, 15.0 * k, -1.5, 0.1, 14, white, 2.0 * k, true)
			c.draw_circle(mid + Vector2(-2, 2) * k, 5.0 * k, Color(light, 0.35))
			c.draw_arc(mid + Vector2(-2, 2) * k, 5.0 * k, 0, TAU, 14, light, 1.5 * k, true)
		"coldspike":
			# One great icicle driven point-first, frost streaming off its tail.
			var spike := _pts(mid, k, [Vector2(15, -15), Vector2(-3, -9), Vector2(-14, 8), Vector2(-8, 14), Vector2(9, 3)])
			c.draw_colored_polygon(spike, Color(col, 0.85))
			spike.append(spike[0])
			c.draw_polyline(spike, white, 1.6 * k, true)
			c.draw_line(mid + Vector2(13, -13) * k, mid + Vector2(-9, 9) * k, light, 2.0 * k, true)
			for p in [Vector2(-15, -2), Vector2(-2, 15), Vector2(-16, 16)]:
				_star(c, mid + (p as Vector2) * k, 2.6 * k, light, 3)
		"sleetwave":
			# Three crests rolling to the right over a streak of ice.
			for i in 3:
				var crest := mid + Vector2(-13 + i * 9, 1) * k
				c.draw_arc(crest, 11.0 * k, -PI * 0.42, PI * 0.42, 12, Color(light if i == 2 else col, 0.45 + 0.25 * i), (2.5 + i) * k, true)
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(16, 15) * k, Color(white, 0.8), 2.0 * k, true)
			for p in [Vector2(-14, -12), Vector2(-6, 13), Vector2(-17, 4)]:
				c.draw_line(mid + (p as Vector2) * k, mid + ((p as Vector2) + Vector2(5, 0)) * k, white, 1.4 * k, true)
		"deepwinter":
			# A full snowflake over a midwinter night.
			c.draw_circle(mid, 15.0 * k, Color(0.08, 0.16, 0.32))
			for i in 6:
				var a := TAU * i / 6.0 + PI / 2.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid, mid + d * 13.0 * k, white, 2.0 * k, true)
				for s: float in [-1.0, 1.0]:
					c.draw_line(mid + d * 7.5 * k, mid + d * 7.5 * k + d.rotated(s * 0.75) * 4.5 * k, light, 1.5 * k, true)
			c.draw_circle(mid, 2.4 * k, light)
		"rimelock":
			# A padlock of ice snapped shut.
			c.draw_arc(mid + Vector2(0, -4) * k, 7.5 * k, PI, TAU, 12, light, 3.2 * k, true)
			c.draw_line(mid + Vector2(-7.5, -4) * k, mid + Vector2(-7.5, 0) * k, light, 3.2 * k)
			c.draw_line(mid + Vector2(7.5, -4) * k, mid + Vector2(7.5, 0) * k, light, 3.2 * k)
			c.draw_rect(Rect2(mid + Vector2(-12, -1) * k, Vector2(24, 16) * k), Color(col, 0.9), true)
			c.draw_rect(Rect2(mid + Vector2(-12, -1) * k, Vector2(24, 16) * k), white, false, 1.5 * k)
			c.draw_circle(mid + Vector2(0, 5) * k, 2.8 * k, Color(0.08, 0.16, 0.32))
			c.draw_line(mid + Vector2(0, 6) * k, mid + Vector2(0, 11) * k, Color(0.08, 0.16, 0.32), 2.4 * k)
			_zigzag(c, mid, k, [Vector2(-12, 2), Vector2(-7, 5), Vector2(-10, 9)], white, 1.3)
		"snowward":
			# A dome of snow over three allies, flakes drifting down on it.
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				dome.append(mid + Vector2(0, 11) * k + Vector2(cos(a), sin(a)) * 16.0 * k)
			c.draw_colored_polygon(dome, Color(col, 0.3))
			c.draw_arc(mid + Vector2(0, 11) * k, 16.0 * k, PI, TAU, 18, white, 2.4 * k, true)
			c.draw_line(mid + Vector2(-17, 11) * k, mid + Vector2(17, 11) * k, light, 2.0 * k, true)
			for ax: float in [-8.0, 0.0, 8.0]:
				var top := 2.0 if ax == 0.0 else 4.0
				c.draw_circle(mid + Vector2(ax, top) * k, 2.4 * k, light)
				c.draw_line(mid + Vector2(ax, top + 3.0) * k, mid + Vector2(ax, 10) * k, light, 3.0 * k)
			for p in [Vector2(-10, -12), Vector2(10, -13), Vector2(0, -16)]:
				_star(c, mid + (p as Vector2) * k, 2.2 * k, white, 3)
		"winterhide":
			# A thick pelt with a ragged hem, frost on its shoulders.
			var pelt := _pts(mid, k, [Vector2(-13, -12), Vector2(-5, -15), Vector2(5, -15), Vector2(13, -12), Vector2(15, 4),
				Vector2(10, 15), Vector2(6, 8), Vector2(2, 16), Vector2(-2, 8), Vector2(-6, 16), Vector2(-10, 8), Vector2(-15, 13), Vector2(-15, 2)])
			c.draw_colored_polygon(pelt, col.darkened(0.25))
			pelt.append(pelt[0])
			c.draw_polyline(pelt, light, 1.6 * k, true)
			for p in [Vector2(-7, -8), Vector2(0, -4), Vector2(7, -8), Vector2(-4, 2), Vector2(4, 2)]:
				c.draw_line(mid + (p as Vector2) * k, mid + ((p as Vector2) + Vector2(0, 4)) * k, white, 1.5 * k, true)
		"rimeedge":
			# A single blade, its edge hung with icicles.
			c.draw_line(mid + Vector2(-13, 9) * k, mid + Vector2(14, -12) * k, Color(0.92, 0.92, 0.96), 3.6 * k, true)
			c.draw_line(mid + Vector2(-15, 3) * k, mid + Vector2(-8, 12) * k, col, 3.0 * k, true)
			c.draw_line(mid + Vector2(-17, 13) * k, mid + Vector2(-12, 8) * k, col.darkened(0.3), 3.2 * k, true)
			for i in 4:
				var hang := mid + Vector2(-5 + i * 5.5, 3 - i * 4.3) * k
				c.draw_colored_polygon(PackedVector2Array([hang + Vector2(-1.8, 0) * k, hang + Vector2(1.8, 0) * k,
					hang + Vector2(0.6, 9.0 - i * 1.2) * k]), light)
		"icebreaker":
			# A block of ice split clean in two by a blade.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-15, -2), Vector2(-4, -5), Vector2(-2, 14), Vector2(-14, 14)]), Color(col, 0.75))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(4, -5), Vector2(15, -2), Vector2(14, 14), Vector2(2, 14)]), Color(col, 0.75))
			c.draw_polyline(_pts(mid, k, [Vector2(-15, -2), Vector2(-4, -5), Vector2(-2, 14)]), white, 1.5 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(15, -2), Vector2(4, -5), Vector2(2, 14)]), white, 1.5 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3.5, -16), Vector2(3.5, -16), Vector2(0, 6)]), Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(-7, -16) * k, mid + Vector2(7, -16) * k, Color(0.5, 0.33, 0.18), 3.0 * k)
			for p in [Vector2(-10, -11), Vector2(11, -10)]:
				_star(c, mid + (p as Vector2) * k, 2.4 * k, white, 3)
		# --- Frost tank: Glacier Wall ---
		"coldshoulder":
			# A shield shouldered side-on, an enemy's red glare turned onto it.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-4, -15), Vector2(10, -11), Vector2(10, 4), Vector2(3, 14), Vector2(-4, 6)]), col)
			c.draw_polyline(_pts(mid, k, [Vector2(-4, -15), Vector2(10, -11), Vector2(10, 4), Vector2(3, 14), Vector2(-4, 6), Vector2(-4, -15)]), light, 1.6 * k, true)
			c.draw_arc(mid + Vector2(-10, -2) * k, 7.0 * k, PI * 0.6, PI * 1.4, 10, white, 2.6 * k, true)
			for p in [Vector2(-14, -12), Vector2(-15, 9)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.8 * k, Color(1.0, 0.35, 0.25))
			_star(c, mid + Vector2(4, -3) * k, 3.2 * k, white, 3)
		"rimequake":
			# A boot stamping down, rings of frost cracking out across the ground.
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, Color(col, 0.6), 2.0 * k, true)
			for i in 2:
				c.draw_arc(mid + Vector2(0, 12) * k, (8.0 + i * 6.0) * k, PI, TAU, 14, Color(light, 0.9 - i * 0.35), 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-5, -16), Vector2(4, -16), Vector2(4, 4), Vector2(10, 6), Vector2(10, 11), Vector2(-5, 11)]), Color(0.7, 0.72, 0.78))
			_zigzag(c, mid, k, [Vector2(-12, 12), Vector2(-9, 15), Vector2(-5, 13)], white, 1.4)
			_zigzag(c, mid, k, [Vector2(8, 12), Vector2(11, 15), Vector2(15, 13)], white, 1.4)
		"hailcoat":
			# Five stacked layers of ice over a shield, hail falling onto it.
			for i in 5:
				var y := 12.0 - i * 5.0
				c.draw_rect(Rect2(mid + Vector2(-12 + i, y - 4) * k, Vector2(24 - i * 2, 4) * k), Color(col, 0.45 + i * 0.1), true)
				c.draw_line(mid + Vector2(-12 + i, y - 4) * k, mid + Vector2(12 - i, y - 4) * k, light, 1.2 * k, true)
			for p in [Vector2(-10, -15), Vector2(0, -17), Vector2(9, -14)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.0 * k, white)
		"hardrime":
			# A cracked layer of ice knitting itself back together.
			c.draw_rect(Rect2(mid + Vector2(-14, -6) * k, Vector2(28, 12) * k), Color(col, 0.6), true)
			c.draw_rect(Rect2(mid + Vector2(-14, -6) * k, Vector2(28, 12) * k), light, false, 1.5 * k)
			_zigzag(c, mid, k, [Vector2(-2, -6), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 6)], white, 1.6)
			for s in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(0, 0) * k, 12.0 * k, -PI * 0.5 + s * 0.6, -PI * 0.5 + s * 1.4, 8, white, 2.0 * k, true)
				c.draw_arc(mid + Vector2(0, 0) * k, 12.0 * k, PI * 0.5 + s * 0.6, PI * 0.5 + s * 1.4, 8, white, 2.0 * k, true)
		"glacialbulwark":
			# A tall wall of glacier ice with a figure behind it, shards bursting off its face.
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, 16), Vector2(-13, -8), Vector2(-6, -16), Vector2(4, -13), Vector2(12, -16), Vector2(13, 16)]), Color(col, 0.75))
			c.draw_polyline(_pts(mid, k, [Vector2(-12, 16), Vector2(-13, -8), Vector2(-6, -16), Vector2(4, -13), Vector2(12, -16), Vector2(13, 16)]), white, 1.6 * k, true)
			for x in [-6.0, 1.0, 7.0]:
				c.draw_line(mid + Vector2(x, -10) * k, mid + Vector2(x + 1.5, 14) * k, Color(light, 0.7), 1.3 * k, true)
			for a in [-2.6, -1.6, -0.5]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(0, -16) * k + d * 2.0 * k, mid + Vector2(0, -16) * k + d * 6.0 * k, white, 1.6 * k, true)
		# --- Frost DPS: Frostbitten Steel ---
		"hoarcleave":
			# A greatsword's wide arc through two frosted shapes.
			c.draw_arc(mid + Vector2(2, 6) * k, 15.0 * k, PI * 1.05, PI * 1.95, 16, Color(col, 0.55), 6.0 * k, true)
			c.draw_arc(mid + Vector2(2, 6) * k, 15.0 * k, PI * 1.05, PI * 1.95, 16, white, 1.8 * k, true)
			c.draw_line(mid + Vector2(-14, 12) * k, mid + Vector2(-3, -3) * k, Color(0.92, 0.92, 0.96), 3.2 * k, true)
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(-12, 10) * k, Color(0.4, 0.25, 0.15), 3.4 * k, true)
			for p in [Vector2(-8, -8), Vector2(10, -6)]:
				c.draw_circle(mid + (p as Vector2) * k, 4.0 * k, Color(light, 0.45))
				_star(c, mid + (p as Vector2) * k, 2.6 * k, white, 3)
		"calving":
			# A slab of ice breaking off a blade's edge and falling, smaller chunks scattering.
			c.draw_line(mid + Vector2(-15, -12) * k, mid + Vector2(12, -12) * k, Color(0.92, 0.92, 0.96), 3.4 * k, true)
			c.draw_line(mid + Vector2(-17, -12) * k, mid + Vector2(-13, -12) * k, Color(0.4, 0.25, 0.15), 3.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-6, -9), Vector2(8, -9), Vector2(10, 4), Vector2(-3, 8)]), Color(col, 0.85))
			c.draw_polyline(_pts(mid, k, [Vector2(-6, -9), Vector2(8, -9), Vector2(10, 4), Vector2(-3, 8), Vector2(-6, -9)]), white, 1.4 * k, true)
			for p in [Vector2(-12, 12), Vector2(0, 15), Vector2(13, 12)]:
				c.draw_colored_polygon(_pts(mid, k, [(p as Vector2) + Vector2(-2.5, -2), (p as Vector2) + Vector2(2.5, -2), (p as Vector2) + Vector2(0, 3)]), light)
		"bitteredge":
			# A thin blade nicking a frozen block, a sharp glint where it bites.
			c.draw_rect(Rect2(mid + Vector2(-2, -4) * k, Vector2(16, 18) * k), Color(col, 0.55), true)
			c.draw_rect(Rect2(mid + Vector2(-2, -4) * k, Vector2(16, 18) * k), light, false, 1.4 * k)
			c.draw_line(mid + Vector2(-15, 10) * k, mid + Vector2(4, -10) * k, Color(0.92, 0.92, 0.96), 2.4 * k, true)
			c.draw_line(mid + Vector2(-16, 11) * k, mid + Vector2(-12, 7) * k, Color(0.4, 0.25, 0.15), 3.0 * k, true)
			_star(c, mid + Vector2(1, -6) * k, 5.0 * k, white, 4)
		"blackfrost":
			# A dark night-blue snowflake with a pale blade through its middle.
			c.draw_circle(mid, 15.0 * k, Color(0.05, 0.08, 0.16))
			for i in 6:
				var a := TAU * i / 6.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid, mid + d * 12.0 * k, Color(col.darkened(0.2), 1.0), 2.4 * k, true)
				c.draw_circle(mid + d * 12.0 * k, 1.6 * k, light)
			c.draw_line(mid + Vector2(-13, 13) * k, mid + Vector2(13, -13) * k, white, 2.2 * k, true)
		# --- Frost, the bow ---
		"shattershot":
			# An arrow punching through a block of ice, the pieces flying apart.
			_arrow_shaft(c, mid, k, col)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(16, -16), Vector2(6, -13), Vector2(13, -6)]), white)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3, -7), Vector2(5, -3), Vector2(-1, 3)]), Color(light, 0.9))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-9, -15), Vector2(-2, -13), Vector2(-7, -8)]), Color(light, 0.8))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(9, 3), Vector2(16, 6), Vector2(10, 10)]), Color(light, 0.8))
			c.draw_colored_polygon(_pts(mid, k, [Vector2(3, 9), Vector2(7, 15), Vector2(0, 14)]), Color(col, 0.9))
			for a: float in [-2.2, -0.2, 1.1]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(2, -2) + d * 8.0) * k, mid + (Vector2(2, -2) + d * 12.0) * k, white, 1.5 * k, true)
		"glacialdraw":
			# A bow drawn all the way back, a long arrow of ice on the string.
			c.draw_arc(mid + Vector2(-2, 0) * k, 15.0 * k, -PI * 0.42, PI * 0.42, 16, Color(0.6, 0.42, 0.25), 3.0 * k, true)
			var top := mid + Vector2(-2 + 15.0 * cos(PI * 0.42), -15.0 * sin(PI * 0.42)) * k
			var bottom := mid + Vector2(-2 + 15.0 * cos(PI * 0.42), 15.0 * sin(PI * 0.42)) * k
			c.draw_line(top, mid + Vector2(-15, 0) * k, white, 1.4 * k, true)
			c.draw_line(bottom, mid + Vector2(-15, 0) * k, white, 1.4 * k, true)
			c.draw_line(mid + Vector2(-15, 0) * k, mid + Vector2(11, 0) * k, light, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(19, 0), Vector2(10, -5), Vector2(10, 5)]), white)
			_star(c, mid + Vector2(-9, -11) * k, 3.0 * k, light, 3)
		"rimefletch":
			# An arrow whose fletching has frosted over: a snowflake where the feathers are.
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(11, -11) * k, Color(0.75, 0.55, 0.35), 2.5 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(17, -17), Vector2(7, -14), Vector2(14, -7)]), Color(0.85, 0.87, 0.9))
			for i in 3:
				var a := i * PI / 3.0 + 0.3
				var v := Vector2(cos(a), sin(a)) * 8.0 * k
				c.draw_line(mid + Vector2(-9, 9) * k - v, mid + Vector2(-9, 9) * k + v, light, 2.2 * k, true)
			c.draw_circle(mid + Vector2(-9, 9) * k, 2.2 * k, white)
			for i in 4:
				c.draw_circle(mid + Vector2(3 + i * 4.5, 14) * k, 1.6 * k, white if i < 4 else col)
		"coldmark":
			# A mark on the target: a ring with four ticks, a snowflake at its heart.
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, light, 2.2 * k, true)
			for i in 4:
				var a := TAU * i / 4.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + d * 10.0 * k, mid + d * 17.0 * k, white, 2.2 * k, true)
			for i in 3:
				var a := i * PI / 3.0 + PI / 6.0
				var v := Vector2(cos(a), sin(a)) * 6.5 * k
				c.draw_line(mid - v, mid + v, white, 2.0 * k, true)
		"icyretreat":
			# A sheet of ice on the ground, and the leap away from it.
			var sheet := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				sheet.append(mid + Vector2(5 + cos(a) * 11.0, 10 + sin(a) * 4.5) * k)
			c.draw_colored_polygon(sheet, Color(light, 0.75))
			c.draw_line(mid + Vector2(-1, 9) * k, mid + Vector2(8, 11) * k, white, 1.4 * k, true)
			c.draw_line(mid + Vector2(6, 8) * k, mid + Vector2(12, 12) * k, white, 1.4 * k, true)
			c.draw_arc(mid + Vector2(-3, 6) * k, 14.0 * k, -PI * 0.95, -PI * 0.3, 12, light, 2.2 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-18, 5), Vector2(-19, -5), Vector2(-11, 0)]), white)
		"icepin":
			# An arrow driven straight down into the ground, ice spreading from where it struck.
			c.draw_line(mid + Vector2(5, -17) * k, mid + Vector2(-1, 8) * k, Color(0.75, 0.55, 0.35), 2.4 * k, true)
			c.draw_line(mid + Vector2(1, -17) * k, mid + Vector2(6, -11) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(9, -16) * k, mid + Vector2(4, -11) * k, light, 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-5, 4), Vector2(3, 6), Vector2(-2, 13)]), white)
			c.draw_line(mid + Vector2(-17, 13) * k, mid + Vector2(17, 13) * k, col, 2.5 * k, true)
			for side: float in [-1.0, 1.0]:
				c.draw_colored_polygon(_pts(mid, k, [Vector2(-2 + side * 4, 13), Vector2(-2 + side * 12, 13), Vector2(-2 + side * 10, 5)]), Color(light, 0.85))
		# --- Martial warrior: the Wheel (drawn in scripts/ui/wheel_icons.gd) ---
		"wheelgreataxe", "wheelgreatsword", "wheelhalberd", "wheelmaul", "quickswing", "fullswing", "weaponart", "wheelbreak":
			WheelIcons.draw(c, id, mid, k)
		"hack", "chop", "rush", "shrapnel", "slash", "lunge", "bladeguard", "shardlance":
			WheelIcons.draw(c, id, mid, k)
		"jab", "hook", "dragin", "flyinghead", "thud", "crush", "earthshake", "faultline":
			WheelIcons.draw(c, id, mid, k)
		# --- Martial tank: the Brawler (drawn in scripts/ui/brawler_icons.gd) ---
		"punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle":
			BrawlerIcons.draw(c, id, mid, k)
		"rapidfists", "haymaker", "sweep", "roundhouse", "clinch", "shakeoff", "turnitaround", "throw", "takedown":
			BrawlerIcons.draw(c, id, mid, k)
		# --- Martial DPS: the Rogue and Martial Utility (drawn in scripts/ui/rogue_icons.gd) ---
		"cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride", "rollwithit", "snatch":
			RogueIcons.draw(c, id, mid, k)
		"gut", "throughandthrough", "redwhirl", "backflip", "drivethrough", "pintheshadow", "overtheshoulder", "playdead":
			RogueIcons.draw(c, id, mid, k)
		# --- Martial archer: Sharpshooter (drawn in scripts/ui/sharpshooter_icons.gd) ---
		"quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands":
			SharpshooterIcons.draw(c, id, mid, k)
		_:
			return false
	return true
