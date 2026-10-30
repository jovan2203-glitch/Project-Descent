extends RefCounted

# Keywords and named things, in one place:
#   - KEYWORDS: the game's status words (Chilled, Frozen, Burning, Heat...) with
#     every form a text may use ("Chills", "Freezing") and what they mean.
#   - Named things: every ability, talent, rune and status effect, by its name.
# Used by:
#   paint()     tooltips show keywords and names in orange
#   explain()   holding Shift over a tooltip explains the keywords in it
#   search()    the search bars (Abilities & Talents, Runes)
#   related()   hovering an ability / talent highlights everything that mentions
#               it, or that it mentions
# Usage: const Keywords = preload("res://scripts/core/keywords.gd")
#
# Entity keys: "a:<ability id>", "t:<talent id>", "r:<rune id>", "e:<effect id>",
# "k:<keyword id>".

const TextFill = preload("res://scripts/core/text_fill.gd")
const Effects = preload("res://scripts/core/effects.gd")

## Colour of keywords and names in tooltips.
const COLOR := Color(1.0, 0.62, 0.22)

## Status words. `forms` = how texts spell it (first = the name shown). `effect` =
## the status effect that explains it (its own description and duration), or
## `text` = an explanation written here (placeholders are filled by TextFill).
const KEYWORDS := {
	"chilled": {"forms": ["Chilled", "Chilling", "Chills", "Chill"], "effect": "chilled"},
	"frozen": {"forms": ["Frozen", "Freezing", "Freezes", "Freeze"], "effect": "frozen"},
	"burning": {"forms": ["Burning", "Burns"], "effect": "burning"},
	"poisoned": {"forms": ["Poisoned", "Poisoning", "Poisons"], "effect": "poisoned"},
	"rooted": {"forms": ["Rooted", "Rooting"], "effect": "rooted"},
	"stunned": {"forms": ["Stunned", "Stunning", "Stuns"], "effect": "stunned"},
	"withering": {"forms": ["Withering", "Withers"], "effect": "corrupted"},
	"weakened": {"forms": ["Weakened"], "effect": "weakened"},
	"thawing": {"forms": ["Thawing"], "effect": "thawing"},
	"branded": {"forms": ["Branded"], "effect": "branded"},
	"pitch": {"forms": ["Pitch"],
		"text": "Your own coat on a target, up to {b:PITCH_MAX_LAYERS} layers, lasting {b:PITCH_TIME} sec (each new layer starts the time over). Each of your arrows that does not critically strike adds a layer. Your Burning and {n:immolate} on it tick {b:PITCH_LAYER_SPEED_PCT}% faster per layer. An arrow critical strike Ignites it."},
	"ignite": {"forms": ["Ignites", "Ignite"],
		"text": "Your Pitch on a target bursts into flame: each layer deals Fire damage to the target and every enemy within {b:PITCH_IGNITE_RADIUS} m of it, every enemy hit without your Burning starts Burning, and the layers are gone."},
	"heat": {"forms": ["Heat"],
		"text": "Built by your melee hits on a target that has your Burning or {n:immolate}, up to {b:HEAT_MAX_STACKS}. Your abilities (not spells) deal {b:HEAT_DAMAGE_PCT}% more Fire damage per Heat. All of it is lost after {b:HEAT_TIME} sec without gaining more. While you hold Heat your melee hits cannot critically strike: one that would have is a Spark."},
	"spark": {"forms": ["Sparks", "Spark"],
		"text": "While you hold Heat, a melee hit of yours that would have critically struck deals normal damage and builds one more Heat instead."},
	"heat_band": {"forms": ["Red band", "Orange band", "White band"],
		"text": "How hot your weapon is: the Red band is below {b:HEAT_BAND_ORANGE} Heat, the Orange band from {b:HEAT_BAND_ORANGE} and the White band from {b:HEAT_BAND_WHITE}. Forge Heat's abilities do more in the Orange and White bands."},
	"slag": {"forms": ["Slag"],
		"text": "Stacks of Armor (up to {b:SLAG_MAX_STACKS}) from the attacks you block and your melee hits while {n:slagskin} is active. Slag from a critical strike is brittle: it crumbles after {b:SLAG_BRITTLE_TIME} sec. Slag never breaks by itself; {n:forgeblow} shatters it all for Fire damage around you."},
	"concentrated_fire": {"forms": ["Concentrated Fire"],
		"text": "Gained during {n:coolhead}. When it ends, each stack makes one Fire spell or ability with a cast time instant, for {b:CONCENTRATED_FIRE_WINDOW} sec."},
	"fury": {"forms": ["Fury"],
		"text": "A bar of 100 that abilities costing Fury spend. You lose {b:FURY_DECAY} a second while you are not casting. Your Fire spells that do not critically strike give {b:FIRE_FURY_BASE} Fury plus {b:FIRE_FURY_PER_CRIT} per 1% of your critical strike chance, once per cast; spells that cost Fury give none. A Fire spell critical strike Vents {b:FIRE_FURY_VENT_PCT}% of your Fury: it is lost, and the crit still deals full damage."},
	"afterburn": {"forms": ["Afterburn"], "effect": "afterburn"},
	"stormfire": {"forms": ["Stormfire"], "effect": "stormfire"},
	"static": {"forms": ["Static"],
		"text": "Built by your Lightning spells and abilities while you carry the Rune of Overload, up to {b:STATIC_MAX_STACKS}. You deal {b:STATIC_DAMAGE_PCT}% more Lightning damage per Static. All of it is lost after {b:STATIC_TIME} sec without gaining more."},
	"overload": {"forms": ["Overload", "Overloaded", "Overloads"],
		"text": "Happens when building Static leaves you at {b:STATIC_MAX_STACKS} while you are not Grounded: all of it discharges as Lightning damage to enemies around you, and you cannot build Static for {b:OVERLOAD_LOCKOUT} sec."},
	"grounded": {"forms": ["Grounded"],
		"text": "Gained after {b:OVERLOAD_GROUND_AFTER} sec without casting a Lightning spell or ability, with the Rune of Overload. You cannot Overload. It lasts {b:OVERLOAD_GROUND_TIME} sec once you cast Lightning again."},
	"reflection": {"forms": ["Reflection", "Reflections"],
		"text": "An image of you that stands beside you, up to {b:REFLECTION_MAX} at once. Each one gives {b:REFLECTION_DODGE}% Dodge and raises your Dodge cap by {b:REFLECTION_DODGE_CAP}%. When you dodge an attack, one Reflection takes it and shatters: it deals {dt:REFLECTION_SHATTER} Arcane damage with {b:REFLECTION_SHATTER_THREAT}x threat to enemies within {b:REFLECTION_SHATTER_RADIUS} m, and takes {b:REFLECTION_SHATTER_COOLDOWN} sec off the cooldown of every Arcane spell and ability (interrupts are not affected). They last {b:REFLECTION_TIME} sec; gaining one makes all of them last that long again."},
	"trace": {"forms": ["Trace", "Traces"],
		"text": "A record of the damage one of your strikes with an Arcane melee ability dealt. You hold up to {b:TRACE_MAX}; each lasts {b:TRACE_TIME} sec, and a new one pushes out the oldest. {n:encore} replays them on your target. Traces are only kept once you have learned {n:encore}."},
	# (The Breach is "decay" in the code and the data: its first name.)
	"decay": {"forms": ["Breach", "Breaches"],
		"text": "A hole you open in the ground under an enemy, with demons clawing at its feet through it. Its debuff shows how much damage they still have to deal. They deal {b:DECAY_TICK_PCT}% of that as Shadow damage {bev:DECAY_TICK} (faster with Haste), and that much less is left; a tick can critically strike. {n:blight} opens it for {b:DECAY_OPEN_TIME} sec. While it is open, your other Shadow spells call more through it: {b:DECAY_FEED_PCT}% of the direct damage they deal is added to it. After that it is closed: the demons keep clawing, but no more can come through, and once less than {ds:DECAY_LAST_DROP} is left, its next tick deals all of it and the Breach is gone. If the enemy dies, what is left moves under the nearest enemy within {b:DECAY_JUMP_RADIUS} m."},
	"hounds": {"forms": ["Hounds", "Hound"],
		"text": "Two demon dogs that fight beside you. With none out, your next Shadow ability that needs a melee weapon calls them up through the ground for {b:HOUND_TIME} sec. Each bites the last enemy you damaged directly (damage over time does not count) for {d:HOUND_BITE} Shadow damage every {b:HOUND_BITE_EVERY} sec (faster with Haste). Sent at an enemy more than a second's run away, they dash to it. They have no stats of their own: their hits use your Attack Power, Spell Power, critical strike chance and damage bonuses, and count as yours. Their hits are procs: effects that react to your own spell and ability hits do not react to them. Enemies cannot attack them. When their time is up, each drags at its prey for {d:HOUND_DRAG} Shadow damage, and your next such ability calls a new pair."},
	"roused": {"forms": ["Roused", "Rouses", "Rouse"],
		"text": "Any ability that costs Fury makes your Hounds Roused for {b:ROUSED_TIME} sec: their bites deal {b:ROUSED_PCT}% more damage. Spending Fury again starts the time over; it does not stack."},
	"strings": {"forms": ["Strings", "String"],
		"text": "The demon behind you holds {b:STRING_MAX} Strings, for allies and enemies together. {n:puppetstring} ties one from your hand. On an ally, each String heals for {ds:STRING_HEAL} {bev:STRING_TICK} (faster with Haste) for {b:STRING_TIME} sec. Up to {b:STRING_STACKS} go on one ally, and tying another starts the time of all of them over. Your spells and abilities that heal an ally on a String also heal every other ally on one for {b:STRING_SHARE_PCT}% of the amount. On an enemy, a String lasts {b:STRING_ENEMY_TIME} sec. A String that runs out, or whose target dies or is more than {b:STRING_LEASH} m from you, is back in your hand at once. One that is used up comes back after {b:STRING_RECHARGE} sec, one at a time."},
	"crossed": {"forms": ["Crossed Strings", "crossed"],
		"text": "A String on an enemy is crossed with the ally you tied a String to last. That ally takes {b:STRING_CROSS_PCT}% less damage, and what it is spared is dealt to the enemy as Shadow damage. It breaks when the two are more than {b:STRING_CROSS_RANGE} m apart, when either String is gone, or when the enemy dies. An ally and an enemy can each be in one crossing."},
	"hymn": {"forms": ["Hymns", "Hymn"],
		"text": "You sing one of three Hymns: Mercy, Chorus or Vigil. Singing another one with {b:VERSE_MAX} Verses makes the Hymn you enter boom (Benediction, Chorale or Bulwark of Song) and spends every Verse. With fewer, you lose your Verses. A boom is {b:BOOM_MATCH_PCT}% stronger for each spent Verse of its own Hymn. When your last three booms were Mercy, Chorus and Vigil, the third is a Full Choir: {b:FULL_CHOIR_PCT}% stronger, and {b:FULL_CHOIR_REFUND} Verses come back."},
	"verse": {"forms": ["Mercy Verses", "Mercy Verse", "Chorus Verses", "Chorus Verse", "Vigil Verses", "Vigil Verse", "Verses", "Verse"],
		"text": "Your Holy healer spells give Verses, up to {b:VERSE_MAX}; more are wasted. Each suits one Hymn: heals on one ally give Mercy Verses, heals on many give Chorus Verses, shields and less damage taken give Vigil Verses. Out of combat they fade, one every {b:VERSE_DRAIN_EVERY} sec."},
	"full_choir": {"forms": ["Full Choir"],
		"text": "When your last three booms were Mercy, Chorus and Vigil, in any order, the third is {b:FULL_CHOIR_PCT}% stronger (Bulwark of Song: lasts longer) and gives you {b:FULL_CHOIR_REFUND} Verses of its Hymn back."},
	"incense": {"forms": ["Incense"],
		"text": "The light in your censer, up to {b:INCENSE_MAX}. Each stack gives {b:INCENSE_BLOCK}% Block (your barrier of light), and enemies within {b:INCENSE_AURA_RADIUS} m take up to {dt:INCENSE_AURA_FULL} Holy damage {bev:INCENSE_AURA_EVERY} (that much at {b:INCENSE_MAX}, less with fewer) with {b:INCENSE_AURA_THREAT}x threat. Each hit you take gives {b:INCENSE_PER_HIT}, each hit you block {b:INCENSE_PER_BLOCK}. It lasts {b:INCENSE_TIME} sec; gaining more makes it last that long again. Your censer appears when you first use one of its abilities and fades {b:CENSER_LINGER} sec after combat ends."},
	"mote": {"forms": ["motes of light", "mote of light"],
		"text": "Light knocked loose or spent from your censer, lying on the ground for {b:MOTE_TIME} sec. Walk within {b:MOTE_PICKUP} m of one to pick it up: it gives {b:MOTE_VALUE} Incense and heals you for {h:MOTE_HEAL_SHARE}. Spending Incense drops motes worth {b:MOTE_SPEND_PCT}% of what was spent. You can have up to {b:MOTE_MAX} on the ground; the oldest fades first. Only you can pick up yours."},
	"mulch": {"forms": ["Mulch", "mulch"],
		"text": "Patches of earth your woven creatures leave where they strike, lying on the ground for {b:MULCH_TIME} sec. You can have up to {b:MULCH_MAX}; the oldest sinks first. Your rooted creatures use up every patch within {b:MULCH_REACH} m of their target and grow stronger with each. Only your own creatures use yours."},
	"blossom": {"forms": ["Blossoms", "Blossom"],
		"text": "A flower your woven creatures leave on an ally they heal. An ally holds up to {b:BLOSSOM_MAX}; they last {b:BLOSSOM_TIME} sec, and a new one starts the time of all of them over. Your rooted creatures use them up and heal or shield more for each. Only your own creatures use yours."},
	"woven": {"forms": ["woven creatures", "woven creature", "woven heals", "woven heal"],
		"text": "Creatures you weave out of vines from your hand: Briar Tiger, Thornwing, Fawn and the Owl. Each strikes or heals once, then leaves Mulch where it struck or Blossoms on the ally it healed."},
	"rooted_creature": {"forms": ["rooted creatures", "rooted creature"],
		"text": "Creatures you grow out of the ground: Mossback, Choking Vipers, Greenwood Stag, Rootguard and Heartwood Elk. They use up your Mulch or Blossoms and grow stronger for each."},
	"thornburst": {"forms": ["Thornburst"],
		"text": "When your Thornshot lands, thorns also burst from every Mulch patch of yours within {b:MULCH_REACH} m of its target, hitting each enemy within {b:THORNBURST_RADIUS} m of a patch once."},
	"full_bloom": {"forms": ["Full Bloom"],
		"text": "An ally who had {b:BLOSSOM_MAX} Blossoms when your Heartwood Elk used them up takes {b:FULL_BLOOM_PCT}% less damage for {b:FULL_BLOOM_TIME} sec."},
	"sap": {"forms": ["Sap"],
		"text": "Sap glowing in your bark, up to {b:SAP_MAX}; it lasts {b:SAP_TIME} sec, and gaining more starts the time over. Each Sap heals you for {b:SAP_HEAL_PCT}% of your maximum health every second. {n:heartsap} uses it all up."},
	"ice_layers": {"forms": ["Ice Layers", "Ice Layer"],
		"text": "One shield of ice on you, in layers: up to {b:ICE_LAYERS_MAX}, each absorbing {b:ICE_LAYER_PCT}% of your maximum health. They last {b:ICE_LAYERS_TIME} sec, and gaining one starts the time over. Each Layer a hit breaks gives you {b:ICE_LAYER_FURY} Fury and Chills the attacker. {n:shatteringslam} spends them all."},
	"glaze": {"forms": ["Glaze"],
		"text": "Rime on your blade, up to {b:GLAZE_MAX}; it lasts {b:GLAZE_TIME} sec, and gaining more starts the time over. Your Frost abilities build it when they hit a target you had already Chilled or Frozen. {n:icebreaker} and {n:calving} spend all of it for more damage."},
	"wheel": {"forms": ["Wheel"],
		"text": "Four floating weapons on your back, always in this order: {n:wheelgreataxe}, {n:wheelgreatsword}, {n:wheelhalberd}, {n:wheelmaul} (the ones you have learned). You hold the one in front. It takes {b:WHEEL_USES} uses: every ability you use counts, from any book, except abilities off the global cooldown and trinkets. Then it breaks and the next one comes into your hands. {n:wheelbreak} breaks it on purpose. Leaving combat makes the held weapon whole again; out of combat, clicking the Wheel above your action bar turns it to the next weapon."},
	"cracks": {"forms": ["Cracks", "Crack"],
		"text": "Cracks in the weapon you hold. {n:quickswing} adds {b:CRACKS_QUICK} and {n:fullswing} adds {b:CRACKS_FULL}; there is no limit. {n:wheelbreak} deals more for each one. They are lost when the weapon breaks any other way."},
	"stagger": {"forms": ["Stagger"],
		"text": "Built on an enemy by your ability hits while you hold the {n:wheelmaul}: {b:STAGGER_PER_HIT} per hit, up to {b:STAGGER_MAX}. At {b:STAGGER_MAX} the enemy is Knocked Down for {b:STAGGER_KNOCKDOWN} sec and its Stagger starts over. It fades after {b:STAGGER_FADE} sec without a hit from you. Bosses never build Stagger."},
	"knocked_down": {"forms": ["Knocked Down"], "effect": "knocked_down"},
	"bruise": {"forms": ["Bruise"],
		"text": "While you are in {n:putemup}, {b:BRUISE_PCT}% of every hit you take is not dealt at once: it goes into your Bruise and hurts you over {b:BRUISE_TIME} sec instead. More damage adds to it and starts the time over with the total left. Each tick gives you {b:BRUISE_FURY} Fury for every 1% of your maximum health it deals."},
	"chain": {"forms": ["Chain"],
		"text": "Your last strikes, shown as orbs on your back: {n:punch} red, {n:brawlkick} green, {n:elbow} blue, {n:catch} white. When its last strike lands ({b:CHAIN_LENGTH} in all), a move goes off and the Chain starts over; {b:CHAIN_TIMEOUT} sec without a strike clears it. The strike that ends it picks the move, and three different strikes make the strong one."},
	"caught_hit": {"forms": ["caught hit"],
		"text": "The hit you caught with {n:catch}: it landed on you in full, with nothing of it going into your Bruise. A Chain started by Catch uses it."},
	"flow": {"forms": ["Flow"],
		"text": "Built by your Rogue hits (not auto attacks), up to {b:FLOW_MAX}: you deal {b:FLOW_PCT}% more damage per stack. A hit from a different range than your last one (melee after a throw, or a throw after melee) gives {b:FLOW_SWITCH} more. After {b:FLOW_HOLD} sec without a Rogue hit it drops by one {bev:FLOW_DECAY_EVERY}. No Flow builds in a Kill window."},
	"kill_window": {"forms": ["Kill window", "Kill windows"],
		"text": "Opened by {n:goin} or {n:hityourstride}. While it lasts, {n:cut}, {n:twinstab}, {n:whirl}, {n:kickoff} and {n:dartin} take their Kill forms, each of your Rogue crits gives {b:KILL_CRIT_ENERGY} Energy, and a Kill form that differs from the one before it adds {b:KILL_VARIETY} sec (up to {b:KILL_VARIETY_MAX} sec)."},
	"kill_form": {"forms": ["Kill form", "Kill forms"],
		"text": "What a Rogue builder becomes in a Kill window: {n:cut} is {n:gut}, {n:twinstab} is {n:throughandthrough}, {n:whirl} is {n:redwhirl}, {n:kickoff} is {n:backflip} and {n:dartin} is {n:drivethrough}."},
	"stuck_dagger": {"forms": ["stuck daggers", "stuck dagger"],
		"text": "Your thrown daggers stay in the enemy they hit: up to {b:DAGGER_MAX} of yours in each, for {b:DAGGER_TIME} sec. Your melee Rogue abilities rip them out: {d:DAGGER_RIP} Physical damage each."},
	"overcut": {"forms": ["Overcut"],
		"text": "When one of your Sharpshooter shots would bring back sooner a shot that is already ready, that time goes onto the ready shot instead, up to {b:OVERCUT_MAX} sec: it deals {b:OVERCUT_PCT}% more damage per second of it. Firing the shot spends it all. Leaving combat clears it."},
	"streak": {"forms": ["Streak"],
		"text": "Built by {n:quickshot}, {n:pierce}, {n:spread}, {n:heavydraw} and {n:followup}: +1 each, up to {b:STREAK_MAX}. You deal {b:STREAK_PCT}% more damage per stack. {n:loose} halves it, and {b:STREAK_HOLD} sec without a Sharpshooter shot loses it. At {b:STREAK_MAX}, {n:heavydraw} is instant and always a critical hit."},
	"blinded": {"forms": ["Blinded"], "effect": "blinded"},
	"pinned": {"forms": ["Pinned"], "effect": "pinned_shadow"},
	"melee_tell": {"forms": ["melee tell"],
		"text": "A short, bright spark at an enemy just before its melee hit lands ({b:MELEE_TELL_TIME} sec). Stuns and knockdowns stop the hit."},	"venom": {"forms": ["Venom"],
		"text": "Your Venom bar (up to {b:VENOM_MAX}). While Adder Venom, Asp Venom and Krait Venom of yours are all on enemies (any enemies), you have Venom Flow: every tick of your poisons gives {b:VENOM_PER_TICK} Venom. Out of combat it drains away."},
	"venom_flow": {"forms": ["Venom Flow"],
		"text": "All three of your poisons are on enemies somewhere: every tick of your poisons gives {b:VENOM_PER_TICK} Venom."},
	"heal_over_time": {"forms": ["heals over time", "heal over time"],
		"text": "Healing that comes a little at a time, every second or so: Sap, Evergreen, the Strings, Refrain and Catch Your Breath."},
	"steeped": {"forms": ["Steeped"],
		"text": "An enemy with all three of your poisons on it. Your poisons on it deal {b:STEEPED_PCT}% more damage instead of {b:TWO_POISONS_PCT}% for two."},
	"prism": {"forms": ["white prisms", "white prism", "gold prisms", "gold prism", "prisms", "prism"],
		"text": "A floating crystal of light you place, up to {b:PRISM_MAX} of both colours together (a new one replaces your oldest); each lasts {b:PRISM_TIME} sec. White prisms (your healer spells) work only with heals: a heal's beam from you to the ally charges every white prism it passes through with {b:PRISM_CHARGE_PCT}% of the heal (up to {h:PRISM_CAP_HEALS}) and is {b:PRISM_AMPLIFY_PCT}% stronger for each. A shattering white prism heals the allies within {b:PRISM_SHATTER_RADIUS} m with its light, split evenly, and hurts the enemies there. Gold prisms (your bow) work only with arrows: see Refraction. Light never moves between the colours, and your heals never target a prism. Only your own beams and arrows use your prisms."},
	"refraction": {"forms": ["refracted arrows", "refracted arrow", "Refraction", "refracts"],
		"text": "Each of your gold prisms a shot passes through fires a refracted arrow at another enemy within {b:REFRACT_RADIUS} m of it, for {b:REFRACT_PCT}% of the shot's damage. With no other enemy there, the shot is {b:REFRACT_FOCUS_PCT}% stronger instead. The prism also stores {b:GOLD_CHARGE_PCT}% of the shot's damage as light. Your auto-shots do this too, more weakly."},
	"ice_shard": {"forms": ["Ice Shard charge", "Ice Shard charges"],
		"text": "A charge of {n:iceshards}: one every {b:ICE_SHARDS_RECHARGE} sec and one each time you cast a Frost spell, up to {b:ICE_SHARDS_MAX_CHARGES}."},
}

static var _built := false
static var _names := {}        # exact text -> Array of entity keys
static var _re: RegEx
static var _paint_cache := {}
static var _mention_cache := {}
static var _texts := {}        # entity key -> lower-case searchable text
static var _titles := {}       # entity key -> display name
static var _related := {}      # entity key -> Array of entity keys
static var _level := -1

static func _abilities() -> GDScript:
	return load("res://scripts/abilities.gd")

static func _talents() -> GDScript:
	return load("res://scripts/talents.gd")

static func _runes() -> GDScript:
	return load("res://scripts/runes.gd")

static func _add_name(text: String, key: String) -> void:
	if text.strip_edges().length() < 3:
		return
	if not _names.has(text):
		_names[text] = []
	if not (_names[text] as Array).has(key):
		(_names[text] as Array).append(key)

## Build the name table and the regex that finds names in a text (longest first).
static func _build() -> void:
	if _built:
		return
	_built = true
	var A := _abilities()
	for id in A.ALL:
		if A.is_trinket_slot(str(id)):
			continue
		_add_name(str(A.ability_name(str(id))), "a:" + str(id))
	var T := _talents()
	var tdb: Dictionary = T.db()
	for id in tdb:
		if not bool(tdb[id].get("placeholder", false)):
			_add_name(str(tdb[id]["name"]), "t:" + str(id))
	var R := _runes()
	for id in R.ALL:
		_add_name(str(R.rune_name(str(id))), "r:" + str(id))
	for id in Effects.all_ids():
		var fx: Resource = Effects.get_effect(str(id))
		if fx and fx.get("display_name") != null:
			_add_name(str(fx.get("display_name")), "e:" + str(id))
	for kid in KEYWORDS:
		for form in KEYWORDS[kid]["forms"]:
			_add_name(str(form), "k:" + str(kid))
	var all: Array = _names.keys()
	all.sort_custom(func(a, b): return str(a).length() > str(b).length())
	var parts: Array[String] = []
	for n in all:
		parts.append(_escape(str(n)))
	_re = RegEx.create_from_string("(?<![A-Za-z])(" + "|".join(parts) + ")(?![A-Za-z])")

static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if "\\^$.|?*+()[]{}".contains(ch) else ch
	return out

## Forget everything worked out from texts (numbers in them follow your level).
static func _check_level() -> void:
	var lv: int = load("res://scripts/core/stats.gd")._player_level()
	if lv != _level:
		_level = lv
		_texts.clear()

# --- Finding names in a text ---------------------------------------------------------

## Every entity key `text` mentions (names and keyword forms), in order, no repeats.
static func mentions(text: String) -> Array:
	_build()
	if _mention_cache.has(text):
		return _mention_cache[text]
	var out: Array = []
	for m in _re.search_all(strip_bbcode(text)):
		for key in _names.get(m.get_string(1), []):
			if not out.has(key):
				out.append(key)
	if _mention_cache.size() > 600:
		_mention_cache.clear()
	_mention_cache[text] = out
	return out

static var _tag_re: RegEx

## `text` without its BBCode tags.
static func strip_bbcode(text: String) -> String:
	if not text.contains("["):
		return text
	if _tag_re == null:
		_tag_re = RegEx.create_from_string("\\[[^\\[\\]]*\\]")
	return _tag_re.sub(text, "", true).replace("[lb]", "[")

## BBCode `text` with every keyword and name wrapped in the keyword colour.
## Tags already in the text are left alone.
static func paint(text: String) -> String:
	_build()
	if text == "":
		return text
	if _paint_cache.has(text):
		return _paint_cache[text]
	var open := "[color=#%s]" % COLOR.to_html(false)
	var out := ""
	var at := 0
	while at < text.length():
		var tag := text.find("[", at)
		var plain := text.substr(at) if tag < 0 else text.substr(at, tag - at)
		out += _re.sub(plain, open + "$1[/color]", true)
		if tag < 0:
			break
		var close := text.find("]", tag)
		if close < 0:
			out += text.substr(tag)
			break
		out += text.substr(tag, close - tag + 1)
		at = close + 1
	if _paint_cache.size() > 600:
		_paint_cache.clear()
	_paint_cache[text] = out
	return out

# --- Explaining (Shift) ----------------------------------------------------------------

## What keyword `kid` means, numbers filled in.
static func keyword_text(kid: String) -> String:
	var k: Dictionary = KEYWORDS.get(kid, {})
	if k.is_empty():
		return ""
	if k.has("effect"):
		return _effect_text(str(k["effect"]))
	return TextFill.constants(str(k.get("text", "")))

static func keyword_name(kid: String) -> String:
	var k: Dictionary = KEYWORDS.get(kid, {})
	return str(k["forms"][0]) if not k.is_empty() else ""

static func _effect_text(id: String) -> String:
	load("res://scripts/balance.gd").apply_effects()
	var fx: Resource = Effects.get_effect(id)
	if fx == null:
		return ""
	var text := TextFill.effect(fx)
	var time: Variant = fx.get("duration")
	# (An effect that lasts until something ends it has no time to quote: a closed Decay.)
	if time != null and float(time) > 0.0 and fx.get("show_time") != false:
		# (With what your talents add: Hard Freeze, Long Burn...)
		var A := _abilities()
		var more: float = A.effect_time_bonus(fx, func(key: String, field: String) -> float: return A.talent(key, field))
		text += " Lasts %s sec." % TextFill.num(float(time) + more)
	return text

## One-line description of an entity, numbers filled in ("" if it has none).
static func describe(key: String) -> String:
	var id := key.substr(2)
	match key.substr(0, 2):
		"k:":
			return keyword_text(id)
		"e:":
			return _effect_text(id)
		"a:":
			var A := _abilities()
			var r: Resource = A.get_resource(id)
			return str(A.fill(id, r.description, Callable(), {})) if r else ""
		"t:":
			return str(_talents().description(id))
		"r:":
			return str(_runes().description(id))
	return ""

static func title(key: String) -> String:
	if _titles.has(key):
		return _titles[key]
	var id := key.substr(2)
	var out := ""
	match key.substr(0, 2):
		"k:": out = keyword_name(id)
		"e:":
			var fx: Resource = Effects.get_effect(id)
			out = str(fx.get("display_name")) if fx else ""
		"a:": out = str(_abilities().ability_name(id))
		"t:": out = str(_talents().get_talent(id).get("name", ""))
		"r:": out = str(_runes().rune_name(id))
	_titles[key] = out
	return out

## The explanations Shift adds under a tooltip, as BBCode lines: each keyword and
## each named ability / effect the text mentions. `own` = the tooltip's own
## subject (never explained to itself). At most `limit` lines.
static func explain(text: String, own: String = "", limit: int = 6) -> Array[String]:
	var lines: Array[String] = []
	var seen := {}   # names already explained (an effect and an ability may share one)
	if own != "":
		seen[title(own)] = true
	var keys := mentions(text)
	# Keywords first, then effects, then abilities.
	for prefix in ["k:", "e:", "a:"]:
		for key in keys:
			if not str(key).begins_with(prefix) or lines.size() >= limit:
				continue
			var name := title(str(key))
			if name == "" or seen.has(name):
				continue
			var what := describe(str(key))
			if what == "":
				continue
			seen[name] = true
			lines.append("[color=#%s]%s[/color]: %s" % [COLOR.to_html(false), name, what])
	return lines

# --- Search ------------------------------------------------------------------------------

## Everything that can be searched for: "a:", "t:" and "r:" keys.
static func all_keys(kinds: String = "atr") -> Array:
	var out: Array = []
	if kinds.contains("a"):
		var A := _abilities()
		for id in A.ALL:
			if not A.is_trinket_slot(str(id)):
				out.append("a:" + str(id))
	if kinds.contains("t"):
		var tdb: Dictionary = _talents().db()
		for id in tdb:
			if not bool(tdb[id].get("placeholder", false)):
				out.append("t:" + str(id))
	if kinds.contains("r"):
		for id in _runes().ALL:
			out.append("r:" + str(id))
	return out

## The text a search looks through: name, description, and for abilities the
## status they apply, their tags and their book.
static func _full_text(key: String) -> String:
	var id := key.substr(2)
	var parts: Array[String] = [title(key), describe(key)]
	match key.substr(0, 2):
		"a:":
			var A := _abilities()
			var r: Resource = A.get_resource(id)
			if r:
				var fx: Resource = r.get("on_hit_effect")
				if fx and fx.get("display_name") != null:
					parts.append(str(fx.get("display_name")))
				parts.append(" ".join(r.tags))
			parts.append(str(load("res://scripts/categories.gd").cat_name(A.category_of(id))))
		"t:":
			var T := _talents()
			parts.append(str(T.capstone_text(id)))
			var req := str(T.get_talent(id).get("requires", ""))
			if req != "":
				parts.append(str(_abilities().ability_name(req)))
			parts.append(str(load("res://scripts/categories.gd").cat_name(T.category_of(id))))
		"r:":
			parts.append(str(_runes().rarity_name(id)))
	return ". ".join(parts)

## Lower-case searchable text of `key`.
static func search_text(key: String) -> String:
	_check_level()
	if not _texts.has(key):
		_texts[key] = _full_text(key).to_lower()
	return _texts[key]

static var _keywords_of := {}   # entity key -> Array of keyword ids it uses

## The keywords `key` interacts with: the ones its text uses as a word of their
## own ("Frozen Focus" is a name, not a use of Frozen).
static func keywords_of(key: String) -> Array:
	if not _keywords_of.has(key):
		var out: Array = []
		for m in mentions(_full_text(key)):
			if str(m).begins_with("k:"):
				out.append(str(m).substr(2))
			elif str(m).begins_with("e:"):
				# An effect that a keyword explains (Chilled, Frozen, Burning...).
				for kid in KEYWORDS:
					if str(KEYWORDS[kid].get("effect", "")) == str(m).substr(2) and not out.has(kid):
						out.append(kid)
		_keywords_of[key] = out
	return _keywords_of[key]

## Keywords a search term stands for: the term is (the start of) one of the
## keyword's forms, so "chill", "chilled" and "chilling" all mean Chilled.
static func term_keywords(term: String) -> Array:
	var out: Array = []
	if term.length() < 3:
		return out
	for kid in KEYWORDS:
		for form in KEYWORDS[kid]["forms"]:
			var f := str(form).to_lower()
			if f.begins_with(term) or term == f:
				out.append(kid)
				break
	return out

## Is `term` in `text` at the start of a word? ("vent" finds "Vent Flames", not
## "preventing".)
static func has_word(text: String, term: String) -> bool:
	var at := text.find(term)
	while at >= 0:
		if at == 0:
			return true
		var before := text.unicode_at(at - 1)
		if not ((before >= 97 and before <= 122) or (before >= 65 and before <= 90)):
			return true
		at = text.find(term, at + 1)
	return false

## Does `key` match `query`? Every word of the query must be found: as typed
## (at the start of a word), or as a keyword the entry interacts with.
static func matches(key: String, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q == "":
		return false
	var text := search_text(key)
	for term in q.split(" ", false):
		var t := str(term)
		if has_word(text, t):
			continue
		var found := false
		var uses := keywords_of(key)
		for kid in term_keywords(t):
			if uses.has(kid):
				found = true
				break
		if not found:
			return false
	return true

## Keys (of `kinds`: any of "a", "t", "r") that match `query`. Names that match
## come first.
static func search(query: String, kinds: String = "at") -> Array:
	var q := query.strip_edges().to_lower()
	var by_name: Array = []
	var by_text: Array = []
	if q == "":
		return by_name
	for key in all_keys(kinds):
		if not matches(str(key), q):
			continue
		if title(str(key)).to_lower().contains(q):
			by_name.append(key)
		else:
			by_text.append(key)
	return by_name + by_text

# --- What mentions what ---------------------------------------------------------------------

static func _build_related() -> void:
	if not _related.is_empty():
		return
	var T := _talents()
	var keys := all_keys("at")
	var links := {}
	for key in keys:
		links[key] = {}
	for key in keys:
		var k := str(key)
		var text := describe(k)
		if k.begins_with("t:"):
			text += " " + str(T.capstone_text(k.substr(2)))
			for field in ["requires", "capstone_requires"]:
				var req := str(T.get_talent(k.substr(2)).get(field, ""))
				if req != "" and links.has("a:" + req):
					links[k]["a:" + req] = true
					links["a:" + req][k] = true
		for other in mentions(text):
			var o := str(other)
			if o == k or not links.has(o):
				continue
			links[k][o] = true
			links[o][k] = true
	for key in links:
		_related[key] = (links[key] as Dictionary).keys()

## Abilities and talents that mention `key`, or that `key` mentions (by name, or
## as the ability a talent requires).
static func related(key: String) -> Array:
	_build_related()
	return _related.get(key, [])
