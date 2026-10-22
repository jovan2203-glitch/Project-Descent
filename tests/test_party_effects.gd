@tool
extends McpTestSuite

# Multiplayer rules for status effects on enemies: the host owns them, everyone
# sees them, and the DAMAGE of a damage-over-time effect is dealt on its
# caster's machine. (What can be checked without a second machine.)

const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const NetScript = preload("res://scripts/net/net.gd")
const CombatScript = preload("res://scripts/core/combat_system.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

func suite_name() -> String:
	return "party_effects"

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func _dot(id: String) -> Resource:
	var r: Resource = StatusEffectScript.new()
	r.id = StringName(id)
	r.display_name = id.capitalize()
	r.duration = 10.0
	r.tick_damage = 0.1
	r.tick_interval = 1.0
	r.dot_hasted = false
	return r

func test_only_the_casters_machine_deals_a_dot() -> void:
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	ally.add_to_group("remote_player")   # another party member's character, as seen here
	var st := _status()
	var burn := _dot("burning")
	st.apply(burn, me)
	st.apply(burn, ally)
	var mine: Dictionary = st.effects[StatusContainer.key_for(burn, me)]
	var theirs: Dictionary = st.effects[StatusContainer.key_for(burn, ally)]
	assert_false(StatusContainer.owned_elsewhere(mine), "my own DoT ticks here")
	assert_true(StatusContainer.owned_elsewhere(theirs), "a party member's DoT ticks on their machine")
	assert_false(StatusContainer.owned_elsewhere({"source": null}), "nobody's effect is dealt here (host)")

func test_per_caster_effects_get_their_own_copy() -> void:
	var a: Node = track(Node.new())
	var b: Node = track(Node.new())
	var mark: Resource = load("res://data/effects/countdown.tres")
	assert_true(bool(mark.get("per_caster")), "Countdown is one per caster")
	var mine: Resource = StatusEffectScript.new()
	mine.id = &"test_charge"
	mine.per_caster = true
	mine.duration = 5.0
	mine.max_stacks = 99
	assert_ne(StatusContainer.key_for(mine, a), StatusContainer.key_for(mine, b), "two players' charges don't share a debuff")
	var st := _status()
	st.apply(mine, a)
	st.apply(mine, b)
	assert_true(st.set_stacks_from("test_charge", a, 4))
	assert_eq(int(st.effects[StatusContainer.key_for(mine, a)]["stacks"]), 4)
	assert_eq(int(st.effects[StatusContainer.key_for(mine, b)]["stacks"]), 1, "the other player's charge is untouched")
	assert_true(st.remove_from("test_charge", a))
	assert_true(st.has_from("test_charge", b))
	var plain: Resource = StatusEffectScript.new()
	plain.id = &"chilled"
	assert_eq(StatusContainer.key_for(plain, a), "chilled", "ordinary effects are shared")

func test_host_copy_gets_the_casters_numbers() -> void:
	var caster: Node = track(Node.new())
	var st := _status()
	var burn := _dot("burning")
	st.apply(burn, caster)
	var p: Dictionary = st.params_of(burn, caster)
	assert_true(absf(float(p["dur"]) - 10.0) < 0.05, "duration left is reported")
	st.tune(burn, caster, {"dur": 14.0, "slow": 1.15})
	var e: Dictionary = st.effects[StatusContainer.key_for(burn, caster)]
	assert_true(absf(st.remaining_of("burning") - 14.0) < 0.05, "the host's copy lasts as long as the caster's talents say")
	assert_eq(float(e["slow_mult"]), 1.15)
	assert_eq(st.params_of(_dot("other"), caster), {}, "nothing to report for an effect that isn't there")

func test_ended_effects_are_not_revived_by_a_late_snapshot() -> void:
	var caster: Node = track(Node.new())
	var st := _status()
	var burn := _dot("burning")
	var key := StatusContainer.key_for(burn, caster)
	st.apply(burn, caster)
	st.mark_predicted(burn, caster)
	assert_true(st.effects[key].has("predicted"), "a fresh effect is protected until the host lists it")
	assert_false(st.is_suppressed(key))
	st.remove_from("burning", caster)
	assert_true(st.is_suppressed(key), "just removed here: the mirror must not bring it back")
	st.apply(burn, caster)
	assert_false(st.is_suppressed(key), "casting it again clears that")

func test_tags_are_remembered_for_mirrored_dots() -> void:
	var caster: Node = track(Node.new())
	var st := _status()
	st.apply(_dot("test_hint"), caster, PackedStringArray(["Fire", "Ability"]))
	assert_eq(StatusContainer.tag_hint("test_hint"), PackedStringArray(["Fire", "Ability"]))
	assert_eq(StatusContainer.tag_hint("never_applied"), PackedStringArray(["Spell"]), "unknown: scales like a spell")

func test_untagged_effects_of_mine_stay_untagged() -> void:
	# A rune's poison has no spell tags; its mirrored copy must not become a "Spell".
	var me: Node = track(Node.new())
	me.add_to_group("player")
	var st := _status()
	st.apply(_dot("test_rune_dot"), me, PackedStringArray(["Frost", "Spell"]))
	st.apply(_dot("test_rune_dot"), me)
	assert_eq(StatusContainer.tag_hint("test_rune_dot"), PackedStringArray())
	var someone: Node = track(Node.new())
	st.apply(_dot("test_other_dot"), someone, PackedStringArray(["Fire", "Spell"]))
	st.apply(_dot("test_other_dot"), someone)
	assert_eq(StatusContainer.tag_hint("test_other_dot"), PackedStringArray(["Fire", "Spell"]),
		"anyone else's untagged re-application leaves the hint alone")

func test_enemy_hits_carry_the_hosts_damage_unit() -> void:
	# Frenzied enemies and a dead Volatile elite's blast: only the host knows the unit.
	var me: Node = track(Node.new())
	var tags := PackedStringArray(["Physical", "Melee"])
	var info: RefCounted = NetScript.enemy_hit_info(null, me, 1.5, tags, "fire", 37.5, "elite_volatile")
	assert_eq(float(info.unit), 37.5, "the host's unit is used even with no copy of the enemy here")
	assert_eq(str(info.ability_id), "elite_volatile")
	assert_eq(str(info.damage_type), "fire")
	assert_eq(info.tags, tags)
	var old: RefCounted = NetScript.enemy_hit_info(null, me, 1.0, tags, "", -1.0, "")
	assert_true(float(old.unit) <= 0.0, "no unit sent: worked out from the enemy as before")
	assert_eq(str(old.ability_id), "enemy_melee")
	assert_eq(str(old.damage_type), "physical")

func test_shielded_hits_read_the_same_on_every_machine() -> void:
	assert_eq(CombatScript.hit_text(120, 0, false), "120")
	assert_eq(CombatScript.hit_text(120, 0, true), "120!")
	assert_eq(CombatScript.hit_text(120, 50, false), "70 (50 absorbed)")
	assert_eq(CombatScript.hit_text(120, 120, true), "Absorb 120")

func test_my_effects_keep_my_clock() -> void:
	# The host's copy of an effect I applied starts one trip later; that must not
	# look like a fresh application (Cold Snap and friends react to those).
	assert_true(EnemyScript.keeps_own_clock(10.0, 10.2))
	assert_true(EnemyScript.keeps_own_clock(10.0, 9.6))
	assert_false(EnemyScript.keeps_own_clock(10.0, 14.0), "really different (refreshed over there): take the host's")
