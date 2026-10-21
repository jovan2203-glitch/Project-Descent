extends RefCounted

# Numbers in descriptions are never typed by hand. The text of an ability, a
# status effect, a talent, a rune or an item effect holds placeholders, and this
# fills them from the data, so a tooltip can't disagree with the game:
#   {b:NAME}     Balance.NAME                {b%:NAME}  x 100 (a share as a percent)
#   {b2:NAME}    x 2 (a radius as a width)   {bth:NAME} as an ordinal ("6th")
#   {bev:NAME}   a tick time in words ("every second", "every 0.5 sec")
#   {e:<effect id>.<field>}   a status effect's number
#                             (time, slow, pct, tick, every, stacks, mod)
#   {a:<ability id>.<field>}  an ability's number
#                             (radius, width, range, cd, cast, damage, threat)
#   {h:NAME}     Balance.NAME x your Heal spell, as a real amount
#   {d:NAME}     Balance.NAME (a damage coefficient) as the real damage of a hit
#                that scales like an ability, at your level and stats
#   {ds:NAME}    the same for a hit that scales like a spell
#   {n:<ability id>}  an ability's name      {ne:<effect id>}  an effect's name
#                (so a rename changes every text that mentions it)
# Abilities, talents and runes add their own on top (Abilities.fill,
# Talents.description - {v}, {vdmg:..}, {bdmg:..} - and TextFill.rune). tests/test_tooltips.gd fails when a
# description carries a typed number.
# Usage: const TextFill = preload("res://scripts/core/text_fill.gd")

const Balance = preload("res://scripts/balance.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Stats = preload("res://scripts/core/stats.gd")

static var _consts := {}
static var _re: RegEx
static var _effect_texts := {}   # filled effect descriptions (they never change while the game runs)

## "2", "0.5", "0.25", "1.5": up to two decimals, no trailing zeros.
static func num(v: float) -> String:
	var t := "%.2f" % v
	while t.contains(".") and (t.ends_with("0") or t.ends_with(".")):
		t = t.substr(0, t.length() - 1)
	return t

## "1st", "2nd", "3rd", "6th", "11th", "22nd".
static func ordinal(n: int) -> String:
	var suffix := "th"
	if (n % 100) < 11 or (n % 100) > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]

## "every second" for 1, "every 0.5 sec" otherwise.
static func every(seconds: float) -> String:
	return "every second" if is_equal_approx(seconds, 1.0) else "every %s sec" % num(seconds)

static func _f(v: Variant, fallback: float = 0.0) -> float:
	return float(v) if v != null else fallback

## A constant of balance.gd by name (null if there is none).
static func balance_value(name: String) -> Variant:
	# (A name the cached map doesn't know: balance.gd may have been edited while
	# the editor was open, so the map is read again before giving up.)
	if _consts.is_empty() or not _consts.has(name):
		var script: Script = load("res://scripts/balance.gd")
		_consts = script.get_script_constant_map()
	return _consts.get(name)

## One number of a status effect. `slow_mult` scales its slow (Deep Chill).
static func effect_number(fx: Resource, field: String, slow_mult: float = 1.0) -> String:
	if fx == null:
		return "?"
	var mods: Variant = fx.get("stat_modifiers")
	match field:
		"time":
			return num(_f(fx.get("duration"), 5.0))
		"slow":
			return num(absf(_f(mods.get("move_speed")) if mods is Dictionary else 0.0) * slow_mult)
		"pct":
			return num(absf(_f(fx.get("damage_mod_pct"))))
		"tick":
			return num(_f(fx.get("tick_interval"), 1.0))
		"every":
			return every(_f(fx.get("tick_interval"), 1.0))
		"stacks":
			return str(int(_f(fx.get("max_stacks"), 1.0)))
		"mod":   # its (first) stat modifier, e.g. the 1 of "+1% Intellect"
			if mods is Dictionary and not mods.is_empty():
				return num(absf(float(mods.values()[0])))
	return "?"

static func _ability_number(id: String, field: String) -> String:
	var r: Resource = load("res://scripts/abilities.gd").get_resource(id)
	if r == null:
		return "?"
	match field:
		"radius":
			return num(_f(r.get("radius")))
		"width":
			return num(_f(r.get("radius")) * 2.0)
		"range":
			return num(_f(r.get("cast_range")))
		"cd":
			return num(_f(r.get("cooldown")))
		"cast":
			return num(_f(r.get("cast_time")))
		"damage":
			return num(_f(r.get("damage")))
		"threat":
			return num(_f(r.get("threat_multiplier"), 1.0))
	return "?"

## Fill the {b:..}, {e:..} and {a:..} placeholders. `wrap` (optional) gets every
## filled-in number and returns what to show (the rich tooltips colour them).
static func constants(text: String, wrap: Callable = Callable()) -> String:
	if not text.contains("{"):
		return text
	if _re == null:
		_re = RegEx.create_from_string("\\{(b|b%|b2|bth|bev|e|a|n|ne|h|ds|d):([A-Za-z0-9_.]+)\\}")
	var out := ""
	var at := 0
	for m in _re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var kind := m.get_string(1)
		var key := m.get_string(2)
		var value := "?"
		if kind == "n" or kind == "ne":
			# A name, so renaming an ability or an effect renames it everywhere.
			# (Names are not numbers: they are never coloured.)
			var named: Resource = Effects.get_effect(key) if kind == "ne" else load("res://scripts/abilities.gd").get_resource(key)
			out += str(named.get("display_name")) if named and named.get("display_name") != null else key
			continue
		if kind == "h":
			# A shield worth a share of the reference heal (Balance.REFERENCE_HEAL), as the
			# real amount at your level and stats (with Rime Ward, like every shield you apply).
			var share: Variant = balance_value(key)
			if share is float or share is int:
				var abilities: GDScript = load("res://scripts/abilities.gd")
				var heal_coef: float = Balance.REFERENCE_HEAL * float(share)
				value = str(int(round(abilities.coef_damage(heal_coef, PackedStringArray(["Spell"]), true) \
					* (1.0 + abilities.talent("frost_absorb") / 100.0))))
		elif kind == "d" or kind == "ds":
			# A hit that is not an ability's own (a Reflection shattering): the real
			# damage of its coefficient, scaled the way abilities are ({ds:..}: the
			# way spells are, like Decay's last drop).
			var coef: Variant = balance_value(key)
			if coef is float or coef is int:
				var book: GDScript = load("res://scripts/abilities.gd")
				value = str(book.fmt_amount(book.coef_damage(float(coef), PackedStringArray(["Spell" if kind == "ds" else "Ability"]))))
		elif kind == "e" or kind == "a":
			var dot := key.find(".")
			if dot > 0:
				var id := key.substr(0, dot)
				var field := key.substr(dot + 1)
				if kind == "e":
					Balance.apply_effects()   # (the tuned numbers, like in game)
					value = effect_number(Effects.get_effect(id), field)
				else:
					value = _ability_number(id, field)
		else:
			var v: Variant = balance_value(key)
			if v is float or v is int:
				match kind:
					"b": value = num(float(v))
					"b%": value = num(float(v) * 100.0)
					"b2": value = num(float(v) * 2.0)
					"bth": value = ordinal(int(v))
					"bev": value = every(float(v))
		out += str(wrap.call(value)) if wrap.is_valid() else value
	return out + text.substr(at)

## A status effect's description with its own numbers: {time} {slow} {pct}
## {tick} {every} {stacks} {mod}. Runtime buffs (plain text) pass through.
static func effect(res: Resource, slow_mult: float = 1.0) -> String:
	if res == null:
		return ""
	var text := str(res.get("description")) if res.get("description") != null else ""
	if not text.contains("{"):
		return text
	# (The HUD asks for these every time it redraws: fill each text once.)
	var cache_key := "%d|%s|%s" % [res.get_instance_id(), num(slow_mult), text]
	if _effect_texts.has(cache_key):
		return _effect_texts[cache_key]
	for field in ["time", "slow", "pct", "tick", "every", "stacks", "mod"]:
		if text.contains("{%s}" % field):
			text = text.replace("{%s}" % field, effect_number(res, field, slow_mult))
	text = constants(text)
	_effect_texts[cache_key] = text
	return text

## A rune's or item effect's description (RuneData) with its own numbers:
##   {n} {nth}    its threshold as a count ("2 in a row", "every 3rd hit")
##   {chance}     its threshold as a % chance      {health}  as a % of health
##   {every_s}    its threshold in seconds         {cd}      internal cooldown
##   {time} {stacks} {radius} {threat}             its buff time / stacks, radius, threat %
##   {buff}       its buff at your level           {amount}  its damage / heal at your level
##   {fx_time} {fx_pct} {fx_stacks} {fx_mod} {fx_every} {dot}   of the status it applies
## `scale` = extra item scaling (Items.effect_scale).
static func rune(res: Resource, scale: float = 1.0) -> String:
	if res == null:
		return ""
	var text := str(res.get("description")) if res.get("description") != null else ""
	if not text.contains("{"):
		return text
	var level := Stats._player_level()
	var threshold := _f(res.get("threshold"), 1.0)
	var buff := _f(res.get("buff_amount"))
	if not Stats.is_percent(str(res.get("buff_stat"))):
		buff *= scale * Stats.unit_for(str(res.get("buff_stat")), level)
	var fx: Resource = res.get("status_effect")
	var nums := {
		"n": str(int(round(threshold))),
		"nth": ordinal(int(round(threshold))),
		"chance": num(threshold * 100.0),
		"health": num(threshold * 100.0),
		"every_s": num(threshold),
		"cd": num(_f(res.get("internal_cooldown"))),
		"time": num(_f(res.get("buff_duration"))),
		"stacks": str(int(_f(res.get("max_stacks"), 1.0))),
		"radius": num(_f(res.get("radius"))),
		"threat": num(_f(res.get("threat_bonus_pct"))),
		"buff": ("%d" % buff) if is_equal_approx(buff, round(buff)) else ("%.1f" % buff),
		"amount": str(maxi(int(round(_f(res.get("effect_amount"), 1.0) * scale * Stats.level_hit(level))), 1)),
		"fx_time": effect_number(fx, "time"),
		"fx_pct": effect_number(fx, "pct"),
		"fx_stacks": effect_number(fx, "stacks"),
		"fx_mod": effect_number(fx, "mod"),
		"fx_every": effect_number(fx, "every"),
		"dot": str(maxi(int(round(_f(fx.get("tick_damage")) * Stats.level_hit(level))), 1)) if fx else "?",
	}
	for k in nums:
		text = text.replace("{%s}" % k, str(nums[k]))
	return constants(text)

## Placeholders still in `text` after filling ("" = none). Tests use this.
static func leftover(text: String) -> String:
	var a := text.find("{")
	if a < 0:
		return ""
	var b := text.find("}", a)
	return text.substr(a, (b - a + 1) if b > a else 12)
