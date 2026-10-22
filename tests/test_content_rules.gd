@tool
extends McpTestSuite

# Game-wide content rules (CLAUDE.md), checked for every book at once so new
# content can't quietly break them. Each test lists every offender it finds.

const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const Items = preload("res://scripts/items.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Details = preload("res://scripts/core/details.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

## Names that are allowed to be shared, and why.
const SHARED_NAMES := {
	"Blaze": "Immolate's ability and the burn it leaves are both Blaze",
}

func suite_name() -> String:
	return "content_rules"

func _report(problems: Array, what: String) -> void:
	assert_true(problems.is_empty(), "%s:\n%s" % [what, "\n".join(PackedStringArray(problems))])

# --- Names ------------------------------------------------------------------------------

func test_names_are_unique_across_the_game() -> void:
	var seen := {}   # name -> ["kind id", ...]
	var add := func(name: String, who: String):
		if name.strip_edges() == "":
			return
		if not seen.has(name):
			seen[name] = []
		seen[name].append(who)
	for id in Abilities.ALL:
		if not Abilities.is_trinket_slot(id):
			add.call(Abilities.ability_name(id), "ability " + id)
	for id in Talents.db():
		var t: Dictionary = Talents.get_talent(id)
		if not bool(t.get("placeholder", false)):
			add.call(str(t["name"]), "talent " + id)
	for id in Runes.ALL:
		add.call(Runes.rune_name(id), "rune " + id)
	for id in Items.ALL:
		add.call(Items.item_name(id), "item " + id)
	var problems := []
	for name in seen:
		var who: Array = seen[name]
		# (An ability's Skill Card or rune of the same name is the same thing.)
		if who.size() > 1 and not SHARED_NAMES.has(name):
			problems.append("%s: %s" % [name, ", ".join(PackedStringArray(who))])
	_report(problems, "Names used more than once")

# --- Text references -----------------------------------------------------------------

## Every {kind:name} in `text` that points at something missing.
func _bad_refs(text: String) -> Array:
	var out := []
	var re := RegEx.create_from_string("\\{(b|b%|b2|bth|bev|d|ds|h|n|ne|e|a):([A-Za-z0-9_.]+)\\}")
	for m in re.search_all(text):
		var kind := m.get_string(1)
		var key := m.get_string(2)
		var ok := true
		match kind:
			"n":
				ok = Abilities.get_resource(key) != null
			"ne":
				ok = Effects.get_effect(key) != null
			"e":
				ok = Effects.get_effect(key.get_slice(".", 0)) != null
			"a":
				ok = Abilities.get_resource(key.get_slice(".", 0)) != null
			_:
				ok = TextFill.balance_value(key) != null
		if not ok:
			out.append(m.get_string())
	return out

func test_text_references_point_at_real_things() -> void:
	var problems := []
	for id in Abilities.ALL:
		var r := Abilities.get_resource(id)
		if r:
			for b in _bad_refs(str(r.description)):
				problems.append("ability %s: %s" % [id, b])
	for id in Talents.db():
		var t: Dictionary = Talents.get_talent(id)
		for field in ["desc", "capstone"]:
			for b in _bad_refs(str(t.get(field, ""))):
				problems.append("talent %s (%s): %s" % [id, t.get("name", ""), b])
	for id in Runes.ALL:
		var rr := Runes.get_resource(id)
		if rr and rr.get("description") != null:
			for b in _bad_refs(str(rr.description)):
				problems.append("rune %s: %s" % [id, b])
	for id in Effects.all_ids():
		var fx := Effects.get_effect(id)
		if fx and fx.get("description") != null:
			for b in _bad_refs(str(fx.description)):
				problems.append("effect %s: %s" % [id, b])
	for kid in Keywords.KEYWORDS:
		for b in _bad_refs(str(Keywords.KEYWORDS[kid].get("text", ""))):
			problems.append("keyword %s: %s" % [kid, b])
	_report(problems, "Text references to things that don't exist")

func test_every_keyword_explains_itself() -> void:
	var problems := []
	for kid in Keywords.KEYWORDS:
		var text := Keywords.keyword_text(kid)
		if text.strip_edges() == "":
			problems.append("%s: no text" % kid)
		elif TextFill.leftover(text) != "" or text.contains("{") or text.contains("?"):
			problems.append("%s: not filled in: %s" % [kid, text])
	_report(problems, "Keywords")

# --- Icons -------------------------------------------------------------------------------

## Every id that has a case of its own in the ability icon drawing.
func _drawn_ids() -> Dictionary:
	var src := FileAccess.get_file_as_string("res://scripts/abilities.gd")
	var out := {}
	var line_re := RegEx.create_from_string("(?m)^\\t\\t((?:\"[a-z0-9_]+\",\\s*)*\"[a-z0-9_]+\"):")
	var id_re := RegEx.create_from_string("\"([a-z0-9_]+)\"")
	for m in line_re.search_all(src):
		for idm in id_re.search_all(m.get_string(1)):
			out[idm.get_string(1)] = true
	return out

func test_every_ability_has_a_picture() -> void:
	var drawn := _drawn_ids()
	var problems := []
	for id in Abilities.ALL:
		if Abilities.is_trinket_slot(id):
			continue
		if not drawn.has(id) and not Abilities.ICON_FORM.has(id):
			problems.append(id)
	_report(problems, "Abilities with no icon (only the plain square)")

func test_every_designed_talent_has_a_picture() -> void:
	var problems := []
	for id in Talents.db():
		var t: Dictionary = Talents.get_talent(id)
		if not bool(t.get("placeholder", false)) and not TalentIcons.has_icon(id):
			problems.append("%s (%s)" % [id, t.get("name", "")])
	_report(problems, "Talents with no icon")

# --- Talents -----------------------------------------------------------------------------

func test_talent_data_is_consistent() -> void:
	var problems := []
	for id in Talents.db():
		var t: Dictionary = Talents.get_talent(id)
		if bool(t.get("placeholder", false)):
			continue
		var ranks := int(t.get("max_rank", 1))
		var values: Array = t.get("values", [])
		if not values.is_empty() and values.size() != ranks:
			problems.append("%s (%s): %d values for %d ranks" % [id, t["name"], values.size(), ranks])
		var req := str(t.get("requires", ""))
		if req != "" and Abilities.get_resource(req) == null:
			problems.append("%s (%s): requires unknown ability %s" % [id, t["name"], req])
		var creq := str(t.get("capstone_requires", ""))
		if creq != "" and Abilities.get_resource(creq) == null:
			problems.append("%s (%s): capstone requires unknown ability %s" % [id, t["name"], creq])
		if str(t.get("capstone", "")) != "" and ranks < 2:
			problems.append("%s (%s): a capstone on a 1-rank talent" % [id, t["name"]])
	_report(problems, "Talent data")

func test_every_written_talent_is_in_the_tree() -> void:
	# A talent written for a slot its book's layout doesn't have is silently dropped.
	var problems := []
	var keys := {}
	for cat in Talents.TALENTS:
		for slot in Talents.TALENTS[cat]:
			var rc := str(slot)   # "r2c7"
			var row := int(rc.get_slice("c", 0).substr(1)) - 1
			var col := int(rc.get_slice("c", 1)) - 1
			var layout: Array = Talents.layout(cat)
			if row < 0 or row >= layout.size() or not (layout[row] as Array).has(col):
				problems.append("%s %s is not a slot of the %s layout" % [cat, rc, cat])
			# A choice slot holds two talents ({"choice": [a, b]}), each with its own key.
			var def: Variant = Talents.TALENTS[cat][slot]
			var entries: Array = def["choice"] if def is Dictionary else [def]
			for entry in entries:
				if entry.size() > 3 and entry[3] is Dictionary and (entry[3] as Dictionary).has("key"):
					var key := str(entry[3]["key"])
					if keys.has(key):
						problems.append("key %s used by %s and %s %s" % [key, keys[key], cat, rc])
					keys[key] = "%s %s" % [cat, rc]
	_report(problems, "Talent slots and keys")

# --- Skill Cards, meter lines ------------------------------------------------------------

func test_skill_cards_unlock_within_the_levels() -> void:
	# (Odd levels are allowed: those are re-offers of a skipped card.)
	var problems := []
	for cid in SkillCards.ALL:
		var lv := SkillCards.level_of(cid)
		if lv != 0 and (lv < 2 or lv > 50):
			problems.append("%s unlocks at level %d" % [cid, lv])
	_report(problems, "Skill Cards")

func test_every_meter_line_has_its_colour() -> void:
	var grey := Color(0.7, 0.7, 0.75)
	var problems := []
	for id in Details.HIT_NAMES:
		if Details.spell_color(str(id)) == grey:
			problems.append(str(id))
	_report(problems, "Damage / healing meter lines with no colour (plain grey)")
