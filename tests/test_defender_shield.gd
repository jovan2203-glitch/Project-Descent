@tool
extends McpTestSuite

# Defenders (scripts/dungeon/defender_shield.gd): "Shield Up" is an endless
# channel; an interrupt or a stun drops the shield (no frontal block) for a
# while, then it comes back. Test kits always have an interrupt and a stun.

const Roles = preload("res://scripts/dungeon/roles.gd")
const Balance = preload("res://scripts/balance.gd")
const TestKit = preload("res://scripts/core/test_kit.gd")
const STUNNED = preload("res://data/effects/stunned.tres")

func suite_name() -> String:
	return "defender_shield"

func _defender() -> Node3D:
	var e: Node3D = load("res://scenes/goblin.tscn").instantiate()
	Roles.apply(e, "defender", {})
	(Engine.get_main_loop() as SceneTree).current_scene.add_child(e)
	return e

func test_defenders_get_a_shield_guard() -> void:
	var e := _defender()
	var g := e.get_node_or_null("ShieldGuard")
	assert_true(g != null, "a Defender has the Shield Up behaviour")
	assert_gt(float(e.frontal_block), 0.0, "its shield blocks")
	assert_eq(float(g.block), float(e.frontal_block))
	e.free()

func test_shield_drops_and_comes_back() -> void:
	var e := _defender()
	var g := e.get_node("ShieldGuard")
	var block := float(e.frontal_block)
	g._knock_down()
	assert_false(g.up)
	assert_eq(float(e.frontal_block), 0.0, "no block while it's down")
	g._down_until = 0.0
	g._process(0.1)
	assert_true(g.up, "back up once the time is over")
	assert_eq(float(e.frontal_block), block)
	e.free()

func test_a_stun_drops_it() -> void:
	var e := _defender()
	var g := e.get_node("ShieldGuard")
	e.status.apply(STUNNED, null)
	g._process(0.1)
	assert_false(g.up, "stunned: shield down")
	g._down_until = 0.0
	g._process(0.1)
	assert_false(g.up, "stays down while still stunned")
	e.free()

func test_an_interrupt_drops_it() -> void:
	var e := _defender()
	var g := e.get_node("ShieldGuard")
	g._channel()
	assert_true(e.is_casting(), "Shield Up is a cast that can be interrupted")
	assert_true(e.interrupt(null, 3.0))
	g._process(0.1)
	assert_false(g.up, "interrupted: shield down")
	e.free()

func test_shield_state_reaches_the_party() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert_true(src.contains("\"shield\":") and src.contains("guard.set_up("), "party members' copies drop the block too")

func test_every_test_kit_can_interrupt_and_stun() -> void:
	for spec in TestKit.specs():
		var ids: Array[String] = TestKit.abilities_of(spec) + TestKit.utility_of(spec)
		ids.append_array(TestKit.borrowed_for(ids))
		assert_true(ids.any(TestKit.is_interrupt), "%s has an interrupt" % spec)
		assert_true(ids.any(TestKit.is_stun), "%s has a stun" % spec)
	assert_true(TestKit.is_interrupt(TestKit.FALLBACK_INTERRUPT))
	assert_true(TestKit.is_stun(TestKit.FALLBACK_STUN))
	for id in TestKit.CODE_STUNS:
		assert_true(_has_ability(id), "%s is a real ability" % id)

func _has_ability(id: String) -> bool:
	return load("res://scripts/abilities.gd").get_resource(id) != null
