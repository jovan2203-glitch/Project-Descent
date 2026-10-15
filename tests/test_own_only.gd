@tool
extends McpTestSuite

# Design rule: everything is OWN ONLY unless its text says it works for allies.
# A talent / ability that reacts to an effect (Chilled, Frozen, a Rime Shell, a
# burn, a Crucible) only counts the player's own - and what a party member does
# to the same effect never takes it away either.

const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")

func suite_name() -> String:
	return "own_only"

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

## A shared effect: one copy on the target whoever applies it (like Chilled).
func _shared(id: String, duration: float = 3.0) -> Resource:
	var r: Resource = StatusEffectScript.new()
	r.id = StringName(id)
	r.display_name = id.capitalize()
	r.duration = duration
	r.is_debuff = true
	return r

func test_an_allys_effect_is_not_mine() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st := _status()
	st.apply(_shared("chilled"), ally)
	assert_true(st.has("chilled"), "the enemy is Chilled")
	assert_true(st.has_from("chilled", ally))
	assert_false(st.has_from("chilled", me), "but not by me: my talents ignore it")
	assert_false(st.has_from("chilled", null))

func test_an_ally_refreshing_my_effect_doesnt_take_it_from_me() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st := _status()
	var chill := _shared("chilled")
	st.apply(chill, me)
	var mine_before: float = st.own_expires(st.effects["chilled"], me)
	st.apply(chill, ally)
	assert_eq(st.effects.size(), 1, "still one shared Chilled")
	assert_true(is_same(st.effects["chilled"]["source"], ally), "the ally cast it last")
	assert_true(st.has_from("chilled", me), "mine still counts")
	assert_true(st.has_from("chilled", ally), "and so does theirs")
	assert_eq(st.own_expires(st.effects["chilled"], me), mine_before, "their refresh doesn't look like me applying it again")

func test_mine_stops_counting_when_my_own_application_would_have_ended() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st := _status()
	var chill := _shared("chilled")
	st.apply(chill, me)
	st.apply(chill, ally)
	# My 3 s are over; the ally keeps the effect going.
	st.effects["chilled"]["by"][me.get_instance_id()] = Time.get_ticks_msec() / 1000.0 - 0.1
	assert_true(st.has("chilled"))
	assert_false(st.has_from("chilled", me), "only the ally's Chilled is left")
	assert_true(st.has_from("chilled", ally))
	assert_eq(st.own_expires(st.effects["chilled"], me), 0.0)

func test_my_own_reapplication_moves_my_clock() -> void:
	var me: Node = track(Node.new())
	var st := _status()
	var chill := _shared("chilled")
	st.apply(chill, me)
	st.effects["chilled"]["by"][me.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + 0.5
	st.apply(chill, me)
	var left: float = st.own_expires(st.effects["chilled"], me) - Time.get_ticks_msec() / 1000.0
	assert_true(left > 2.8 and left <= 3.0, "my refresh restarts my own 3 s, got %s" % left)

## A mirrored copy (party member's machine) has no caster list: its listed caster counts.
func test_a_mirrored_effect_belongs_to_its_listed_caster() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st := _status()
	var now := Time.get_ticks_msec() / 1000.0
	st.effects["frozen"] = {"res": _shared("frozen"), "stacks": 1, "expires": now + 3.0, "next_tick": INF, "source": me}
	assert_true(st.has_from("frozen", me))
	assert_false(st.has_from("frozen", ally))

func test_a_broken_shield_remembers_its_caster() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st := _status()
	var shell := _shared("test_shell", 10.0)
	shell.is_debuff = false
	st.apply(shell, ally)
	st.set_absorb("test_shell", 50)
	st.absorb_damage(80)
	assert_true(is_same(st.last_shield_source, ally), "an ally's shield on me broke: not mine (Ice Floe ignores it)")
	st.apply(shell, me)
	st.set_absorb("test_shell", 50)
	st.absorb_damage(80)
	assert_true(is_same(st.last_shield_source, me), "my own shield broke")

## The stated exception: Rime Shell's debuff on an enemy is for the whole party
## and for every kind of damage (hits and ticks, any school, any caster).
func test_rime_shell_debuff_is_for_everyone() -> void:
	const DamageInfo = preload("res://scripts/core/damage_info.gd")
	var src: Resource = load("res://data/effects/rime_shell_foe.tres")
	assert_eq(float(src.get("damage_mod_pct")), 5.0)
	assert_true(bool(src.get("modifies_incoming")), "damage TAKEN")
	assert_true(bool(src.get("mod_affects_dots")), "damage over time too")
	assert_false(bool(src.get("per_caster")), "one debuff for the whole party")
	# (A real instance: in the editor a loaded .tres has a placeholder script.)
	var fx: Resource = StatusEffectScript.new()
	for p in ["id", "display_name", "duration", "damage_mod_pct", "modifies_incoming", "mod_affects_dots",
			"mod_damage_types", "mod_required_tags", "is_debuff"]:
		if src.get(p) != null:
			fx.set(p, src.get(p))
	assert_true(fx.mod_damage_types.is_empty(), "every damage type")
	assert_true(fx.mod_required_tags.is_empty(), "spells and abilities alike")
	var caster: Node = track(Node.new())
	var someone_else: Node = track(Node.new())
	var st := _status()
	st.apply(fx, caster)
	for row in [["frost", ["Frost", "Spell"], false], ["fire", ["Ability", "Fire", "Melee"], false],
			["physical", ["Physical", "Melee", "AutoAttack"], false], ["fire", ["Fire", "Spell", "DoT"], true]]:
		var info := DamageInfo.make(someone_else, st.get_parent(), 3, "test")
		info.damage_type = str(row[0])
		info.tags = PackedStringArray(row[1])
		info.is_dot = bool(row[2])
		st.collect_damage_mods(info, true)
		assert_eq(info.bonus_pct, 5.0, "%s %s from another player takes the +5%%" % [row[0], "tick" if row[2] else "hit"])
	assert_contains(str(Abilities.get_resource("rimeshell").description), "from everyone")

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)

## Guard for every book, rune and item effect: no game code may ask "is effect
## X on this character?" without asking whose it is (StatusContainer.has_from /
## Effects.has_from). A player asking about their OWN buffs (`status.has(..)`)
## is fine: those are theirs by definition.
func test_no_code_checks_an_effect_without_its_caster() -> void:
	const Effects = preload("res://scripts/core/effects.gd")
	var ids := Effects.all_ids()
	var files := []
	_walk("res://scripts", files)
	var re := RegEx.create_from_string("(\\w+)\\.(has|stacks_of|remaining_of)\\(\"(\\w+)\"\\)|Effects\\.(has|stacks)\\(")
	var hits := []
	for p in files:
		if p.ends_with("core/status_container.gd") or p.ends_with("core/effects.gd"):
			continue   # (where the checks themselves are written)
		var lines := FileAccess.get_file_as_string(p).split("\n")
		for i in lines.size():
			var line := lines[i].strip_edges()
			if line.begins_with("#"):
				continue
			for m in re.search_all(line):
				# (`effects` / `locks` are plain dictionaries: host-side bookkeeping, not a rule.)
				if m.get_string(4) != "" or (not ["status", "effects", "locks"].has(m.get_string(1)) and ids.has(m.get_string(3))):
					hits.append("%s:%d  %s" % [p, i + 1, m.get_string()])
	assert_true(hits.is_empty(), "effect checks that ignore who applied it:\n" + "\n".join(hits))
	assert_true(files.size() > 50, "the scripts were scanned")

## Shadow Arrow no longer Weakens its target (a debuff that cut the enemy's
## damage for the whole party). No ability applies Weakened any more.
func test_no_ability_weakens_an_enemy() -> void:
	var arrow: Resource = ResourceLoader.load("res://data/abilities/shadowarrow.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(arrow.get("on_hit_effect") == null, "Shadow Arrow has no on-hit effect")
	assert_false(str(arrow.description).to_lower().contains("weaken"))
	for id in Abilities.PATHS:
		var r: Resource = ResourceLoader.load(str(Abilities.PATHS[id]), "", ResourceLoader.CACHE_MODE_IGNORE)
		var fx: Variant = r.get("on_hit_effect")
		assert_true(fx == null or str(fx.id) != "weakened", "%s does not apply Weakened" % id)

func test_texts_say_whose_it_must_be() -> void:
	assert_contains(str(Abilities.get_resource("crucible").description), "from you")
	assert_contains(str(Abilities.get_resource("shatteringwave").description), "of yours")
	assert_contains(str(Abilities.get_resource("shatteringslam").description), "your Rime Shell")
	assert_contains(str(Talents.get_talent(Talents.id_for_key("frost_chilled_dmg"))["desc"]), "you have Chilled")
	assert_contains(str(Talents.get_talent(Talents.id_for_key("frost_splinter"))["desc"]), "you have Frozen")
	assert_contains(str(Talents.get_talent(Talents.id_for_key("frost_ice_floe"))["desc"]), "you put on yourself")
