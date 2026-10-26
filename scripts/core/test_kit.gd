extends RefCounted

# /testkit <spec> (debug_commands.gd): a ready-to-play character for group
# tests. Level 50, the spec's abilities (and its book's Utility) learned and on
# the bars, a full set of Epic item-level-50 gear with the spec's stats and the
# weapons its abilities need, and talent points spent for it. No runes. Talents
# and bars can be changed afterwards as usual.
# Usage: const TestKit = preload("res://scripts/core/test_kit.gd")
#        var lines: Array = TestKit.apply(pd, "venomstring")

const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Balance = preload("res://scripts/balance.gd")
const Macros = preload("res://scripts/core/macros.gd")
const Categories = preload("res://scripts/categories.gd")

const ILVL := 50
const RARITY := 3   # Epic: three rolled stats
const GEAR_SLOTS := ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves", "Legs", "Boots",
	"Finger 1", "Finger 2", "Trinket 1", "Trinket 2"]
## Weapon sets tried in order; the first that every ability of the spec can use
## and whose stats suit it best wins (ties: the earlier one).
const WEAPON_SETS := [["bow", ""], ["greatsword", ""], ["staff", ""], ["sword", "shield"],
	["sword", "dagger"], ["venom_fang", "dagger"], ["sword", "lantern"], ["sword", ""],
	["runed_blade", "tome"], ["runed_blade", "shield"], ["ritual_dagger", "tome"], ["runed_blade", "wand"],
	["runed_blade", "lantern"], ["runed_blade", ""]]

## Every spec a kit can be made for: spec name -> book.
static func specs() -> Dictionary:
	var out := {}
	for cat in Abilities.SPECS:
		for spec in Abilities.SPECS[cat]:
			if str(spec[0]) != "Utility":
				out[str(spec[0])] = str(cat)
	return out

static func _key(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if ch >= "a" and ch <= "z":
			out += ch
	return out

## The spec `typed` names: exact (ignoring case, spaces and punctuation), the
## start of a name, or the closest name. "" if nothing is close.
static func find_spec(typed: String) -> String:
	var k := _key(typed)
	if k == "":
		return ""
	var best := ""
	var best_score := 0.0
	for spec in specs():
		var sk := _key(spec)
		if sk == k:
			return spec
		var score := 0.9 if sk.begins_with(k) else sk.similarity(k)
		if score > best_score:
			best_score = score
			best = spec
	return best if best_score >= 0.6 else ""

## The spec's abilities, from its book's spec list.
static func abilities_of(spec: String) -> Array[String]:
	var out: Array[String] = []
	for s in Abilities.SPECS.get(specs().get(spec, ""), []):
		if str(s[0]) == spec:
			out.assign(s[1])
	return out

static func utility_of(spec: String) -> Array[String]:
	var out: Array[String] = []
	for s in Abilities.SPECS.get(specs().get(spec, ""), []):
		if str(s[0]) == "Utility":
			out.assign(s[1])
	return out

## The buttons `ids` put on a bar: a Wheel weapon's moves instead of the weapon,
## buttons that come with another (Go In with Cut...), no chain moves / Kill forms.
static func bar_buttons(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		var list: Array = Abilities.WHEEL_FORMS[id] if Abilities.WHEEL_ORDER.has(id) else [id]
		for m in list:
			var b := Abilities.bar_id(str(m))
			if Abilities.WHEEL_ORDER.has(b) or Abilities.is_chain_move(b) or Abilities.is_kill_form(b) or out.has(b):
				continue
			out.append(b)
		for brought in Abilities.BROUGHT_BUTTONS:
			if str(Abilities.BROUGHT_BUTTONS[brought]) == id and not out.has(brought):
				out.append(brought)
	return out

# --- What the spec wants -------------------------------------------------------------

## {"role", "caster" (spells over martial abilities), "ranged" (a bow), "stats"
## (the stats it wants, best first), "armor" (armor type: Cloth / Light / Medium / Heavy)}.
static func profile(spec: String) -> Dictionary:
	var ids := abilities_of(spec)
	var spells := 0
	var martial := 0
	var ranged := false
	for id in ids:
		var r := Abilities.get_resource(id)
		if r == null:
			continue
		if (r.tags as PackedStringArray).has("Spell"):
			spells += 1
		elif (r.tags as PackedStringArray).has("Ability"):
			martial += 1
		if int(r.weapon_requirement) == 2:
			ranged = true
	var role := str(Abilities.SPEC_ROLES.get(spec, "dps"))
	var caster := role == "healer" or spells > martial
	var main := "intellect" if caster else ("agility" if ranged else "strength")
	var power := "spell_power" if caster else "attack_power"
	var stats: Array[String] = []
	if role == "tank":
		stats.assign(["constitution", "armor", main, power])
	elif role == "healer":
		stats.assign([main, power, "haste", "crit_rating"])
	else:
		stats.assign([main, power, "crit_rating", "haste"])
	var armor := 3 if role == "tank" else Balance.ARMOR_TYPE_STAT.find(main)
	return {"role": role, "caster": caster, "ranged": ranged, "stats": stats, "armor": maxi(armor, 0)}

## How well an item's base stats suit `stats` (best first counts most).
static func _fit(base: String, stats: Array[String]) -> float:
	var d := Items.get_item(base)
	var score := 0.0
	for s in d.get("stats", {}):
		var i := stats.find(str(s))
		if i != -1:
			score += float(stats.size() - i)
	return score

## Can an ability be used with this Main Hand / Off Hand?
static func usable_with(id: String, main: String, off: String) -> bool:
	var r := Abilities.get_resource(id)
	if r == null:
		return true
	var m := Items.get_item(main)
	var o := Items.get_item(off) if off != "" else {}
	var weapon := str(m.get("weapon", ""))
	if int(r.weapon_requirement) == 1 and weapon != "melee":
		return false
	if int(r.weapon_requirement) == 2 and weapon != "ranged":
		return false
	if bool(r.get("requires_two_hand")) and not bool(m.get("locks_offhand", false)):
		return false
	if bool(r.get("requires_dual_wield")) and not (Items.is_one_handed_melee(main) and off != "" and Items.is_one_handed_melee(off)):
		return false
	var shield := str(o.get("item_type", "")) == "shield"
	if bool(r.get("requires_shield")) and not shield:
		return false
	if bool(r.get("forbids_shield")) and shield:
		return false
	if bool(r.get("requires_off_hand")) and not (off != "" and Items.is_off_hand_item(off)):
		return false
	return true

## The weapons for a spec: [main, off] from WEAPON_SETS.
static func weapons_for(spec: String) -> Array:
	var want: Array[String] = profile(spec)["stats"]
	var ids := abilities_of(spec)
	var best: Array = []
	var best_fit := -1.0
	for set in WEAPON_SETS:
		var main := str(set[0])
		var off := str(set[1])
		if not Items.PATHS.has(main) or (off != "" and not Items.PATHS.has(off)):
			continue
		if bool(Items.get_item(main).get("locks_offhand", false)) and off != "":
			continue
		if not ids.all(func(id): return usable_with(id, main, off)):
			continue
		var fit := _fit(main, want) + (_fit(off, want) if off != "" else 0.0)
		if fit > best_fit:
			best_fit = fit
			best = [main, off]
	return best

## The base item for a gear slot that suits the stats best ("" if none fits it).
static func _base_for(slot: String, want: Array[String], skip: String = "") -> String:
	var slot_kind := slot.trim_suffix(" 1").trim_suffix(" 2")
	var best := ""
	var best_fit := -1.0
	for base in Items.PATHS:
		var d := Items.get_item(str(base))
		if str(d.get("slot", "")).trim_suffix(" 1").trim_suffix(" 2") != slot_kind or str(base) == skip:
			continue
		var fit := _fit(str(base), want)
		if fit > best_fit:
			best_fit = fit
			best = str(base)
	return best

## An Epic item-level-50 item with three rolls of the spec's best stats.
static func _make(base: String, want: Array[String], armor: int) -> String:
	var rolled := {}
	for i in RARITY:
		var s := want[i % mini(want.size(), 2)] if i < 2 else want[mini(2, want.size() - 1)]
		rolled[s] = float(rolled.get(s, 0.0)) + ItemDB.roll_amount(s, ILVL)
	return ItemDB.create(base, "", ILVL, RARITY, rolled, armor if ItemDB.is_armor_piece(base) else ItemDB.NO_ARMOR_TYPE)

# --- Talents ---------------------------------------------------------------------------

## Spends every talent point for `spec`: its capstone first whenever it opens,
## then its own talents (its group on the ribbon layout, or talents for its
## abilities), then its book's other talents with no ability needed, then other
## books' to open rows. Choices take their first talent. Top rows first.
static func pick_talents(pd: Node, spec: String) -> void:
	pd.talents.clear()
	var cat: String = specs().get(spec, "")
	var own := abilities_of(spec)
	var pool: Array[String] = []
	for c in Categories.ORDER:
		for r in Talents.ROWS:
			for id in Talents.in_row(str(c), r):
				var opts := Talents.options_of(id)
				if opts.is_empty():
					pool.append(id)
				else:
					pool.append_array(opts)
	var scored: Array = []
	for id in pool:
		var s := _talent_score(id, spec, cat, own)
		if s > 0:
			scored.append([s, Talents.tier_of(id), id])
	scored.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var progress := true
	while progress and pd.talent_points_left() > 0:
		progress = false
		for e in scored:
			if pd.can_invest(str(e[2])) == "":
				pd.talents[str(e[2])] = pd.talent_rank(str(e[2])) + 1
				progress = true
				break
	pd._invalidate_stats()

static func _talent_score(id: String, spec: String, cat: String, own: Array[String]) -> int:
	var need := Talents.required_ability(id)
	var same_book := Talents.category_of(id) == cat
	if need != "" and not own.has(need):
		return 0   # for another spec's ability
	if same_book and Talents.group_of(id) == spec:
		return 300 if Talents.capstone_gated(id) else 200
	if same_book and need != "":
		return 180
	if Talents.capstone_gated(id):
		return 0   # another spec's capstone
	if same_book and (Talents.group_of(id) == Talents.OPEN_GROUP or Talents.group_of(id) == ""):
		return 100
	if not same_book and need == "" and Talents.group_of(id) in [Talents.OPEN_GROUP, ""]:
		return 10   # another book's open talent: only to open rows
	return 0

# --- Putting it on -------------------------------------------------------------------

## Makes `pd` a ready-to-play `spec_typed` character. Returns chat lines.
static func apply(pd: Node, spec_typed: String) -> Array:
	var spec := find_spec(spec_typed)
	if spec == "":
		var names := specs().keys()
		names.sort()
		return ["No spec called \"%s\". Specs: %s" % [spec_typed, ", ".join(names)]]
	var prof := profile(spec)
	var want: Array[String] = prof["stats"]
	pd.set_level(pd.MAX_LEVEL)
	# Abilities: the spec's and its book's Utility, the spec's first on the bars.
	var own := abilities_of(spec)
	var util := utility_of(spec)
	pd.learn_abilities(own + util)
	var buttons := bar_buttons(own)
	var util_buttons := bar_buttons(util)
	for i in pd.action_bar.size():
		if not Macros.is_macro(str(pd.action_bar[i])):
			pd.action_bar[i] = ""
	var slot := 0
	for b in buttons + util_buttons:
		if slot >= pd.action_bar.size():
			break
		pd.action_bar[slot] = b
		slot += 1
	# Gear: whatever is worn goes to the bank (or is dropped if the bank is full).
	var gear := {}
	var ring := ""
	var trinket := ""
	for s in GEAR_SLOTS:
		var skip := ring if s == "Finger 2" else (trinket if s == "Trinket 2" else "")
		var base := _base_for(s, want, skip)
		if base == "":
			base = _base_for(s, want)
		if s == "Finger 1":
			ring = base
		elif s == "Trinket 1":
			trinket = base
		if base != "":
			gear[s] = base
	var weapons := weapons_for(spec)
	if not weapons.is_empty():
		gear["Main Hand"] = str(weapons[0])
		if str(weapons[1]) != "":
			gear["Off Hand"] = str(weapons[1])
	for s in ["Main Hand", "Off Hand"] + GEAR_SLOTS:
		var old := str(pd.equipment.get(s, ""))
		if old != "":
			var free: int = pd.bank.find("")
			if free != -1:
				pd.bank[free] = old
			else:
				ItemDB.destroy(old)
		pd.equipment.erase(s)
		if gear.has(s):
			pd.equipment[s] = _make(str(gear[s]), want, int(prof["armor"]))
	pick_talents(pd, spec)
	pd.changed.emit()
	var in_spec := 0
	for id in pd.talents:
		if Talents.group_of(str(id)) == spec or own.has(Talents.required_ability(str(id))):
			in_spec += int(pd.talents[id])
	var extra := "" if buttons.size() + util_buttons.size() <= 8 else "  More buttons are on the extra bars."
	var lines := ["Test kit: %s (%s, %s). Level %d, %d abilities on your bars, %d Epic items, %d talent points spent (%d for %s).%s" % [
		spec, Categories.cat_name(specs()[spec]), str(prof["role"]), pd.level,
		buttons.size() + util_buttons.size(), pd.equipment.size(), pd.talent_points_spent(), in_spec, spec, extra]]
	if own.size() <= 1:
		lines.append("Note: %s is unfinished (only %d ability)." % [spec, own.size()])
	return lines
