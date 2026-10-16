@tool
extends McpTestSuite

# What the Breach looks like (scripts/breach_fx.gd): a hole under the enemy and
# hands clawing out of it, higher up its body the more damage is in the Breach.
# The enemy shows it from its own debuffs, so the whole party sees it. And the
# same hands as a one-off where a Shadow spell lands.

const BreachFx = preload("res://scripts/breach_fx.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Effects = preload("res://scripts/core/effects.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const Abilities = preload("res://scripts/abilities.gd")

func suite_name() -> String:
	return "breach_fx"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

## Something shaped like an enemy: a body 1.8 m tall and 0.8 m wide with its
## origin in its middle, and debuffs.
func _enemy() -> Node3D:
	var e := Node3D.new()
	track(e)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	e.add_child(cs)
	var st: Node = StatusContainer.new()
	st.name = "Status"
	e.add_child(st)
	return e

func _picture(e: Node3D) -> Node3D:
	var fx := Node3D.new()
	fx.name = BreachFx.NODE_NAME
	fx.set_script(BreachFx)
	e.add_child(fx)
	fx._build()
	return fx

func test_the_hands_reach_higher_the_more_is_in_it() -> void:
	assert_eq(Balance.BREACH_FX_FULL_HITS, 10.0)
	assert_eq(Stats.level_hit(10), 100.0)
	# An enemy with plenty of health at level 10: ten standard hits fill it.
	assert_eq(BreachFx.reach(0.0, 5000.0, 10), 0.0)
	assert_eq(BreachFx.reach(250.0, 5000.0, 10), 0.25)
	assert_eq(BreachFx.reach(500.0, 5000.0, 10), 0.5)
	assert_eq(BreachFx.reach(1000.0, 5000.0, 10), 1.0)
	assert_eq(BreachFx.reach(9000.0, 5000.0, 10), 1.0, "never past the top")
	assert_eq(BreachFx.reach(-5.0, 5000.0, 10), 0.0)
	# A small enemy: as much as its whole health is enough.
	assert_eq(BreachFx.reach(150.0, 300.0, 10), 0.5)
	assert_eq(BreachFx.reach(300.0, 300.0, 10), 1.0)
	# From the ankles to over the head.
	assert_eq(BreachFx.arm_share(0.0), BreachFx.LOW)
	assert_eq(BreachFx.arm_share(1.0), BreachFx.HIGH)
	assert_true(BreachFx.LOW < 0.35, "next to nothing in it: only at its feet")
	assert_true(BreachFx.HIGH > 1.0, "all of it: over its head")
	var last := -1.0
	for i in 11:
		var share := BreachFx.arm_share(i / 10.0)
		assert_true(share > last, "every bit more reaches higher")
		last = share

func test_it_is_fitted_to_the_body() -> void:
	var e := _enemy()
	var body := BreachFx.body_of(e)
	assert_true(is_equal_approx(float(body["height"]), 1.8))
	assert_true(is_equal_approx(float(body["radius"]), 0.4))
	assert_true(is_equal_approx(float(body["feet"]), -0.9), "the origin of an enemy is its middle")
	assert_true(is_equal_approx(BreachFx.hole_radius(0.4), 0.68), "wider than the body standing on it")
	assert_eq(BreachFx.hole_radius(0.1), BreachFx.MIN_RADIUS)
	assert_eq(BreachFx.arm_count(0.68), 5)
	assert_eq(BreachFx.arm_count(5.0), 8, "a boss gets more hands, not a crowd")
	assert_true(BreachFx.thickness(1.5) > BreachFx.thickness(0.68), "and thicker arms")
	# Something without a shape gets a body of ordinary size.
	var bare := Node3D.new()
	track(bare)
	assert_true(is_equal_approx(float(BreachFx.body_of(bare)["height"]), 1.8))

func test_it_reads_the_enemys_debuffs() -> void:
	var e := _enemy()
	var st: Node = e.get_node("Status")
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	assert_eq(BreachFx.read(st), {"on": false, "open": false, "amount": 0.0})
	assert_eq(BreachFx.read(null), {"on": false, "open": false, "amount": 0.0})
	st.apply(Effects.get_effect("decay"), me)
	st.set_stacks_from("decay", me, 95)
	assert_eq(BreachFx.read(st), {"on": true, "open": true, "amount": 95.0})
	# A party member's Breach on the same enemy: one picture for both, added up.
	st.apply(Effects.get_effect("decay_closed"), ally)
	st.set_stacks_from("decay_closed", ally, 40)
	assert_eq(BreachFx.read(st), {"on": true, "open": true, "amount": 135.0})
	st.remove_from("decay", me)
	assert_eq(BreachFx.read(st), {"on": true, "open": false, "amount": 40.0}, "only the closed one is left")
	# Another debuff is not a Breach.
	st.remove_from("decay_closed", ally)
	st.apply(Effects.get_effect("corrupted"), me)
	assert_false(bool(BreachFx.read(st)["on"]))

func test_the_picture_follows_the_breach() -> void:
	var e := _enemy()
	var st: Node = e.get_node("Status")
	var me: Node = track(Node.new())
	# Nothing on it: nothing is made. (And nothing outside a running scene.)
	BreachFx.sync(e)
	assert_true(e.get_node_or_null(BreachFx.NODE_NAME) == null)
	st.apply(Effects.get_effect("decay"), me)
	st.set_stacks_from("decay", me, 95)   # half of what shows at level 1 (ten hits of 19)
	var fx := _picture(e)
	assert_eq(fx.arms(), 5)
	assert_true(is_equal_approx(fx.position.y, -0.9 + 0.03), "the hole lies on the ground under its feet")
	assert_true(fx.is_open())
	assert_true(is_equal_approx(fx.target_reach(), 0.5))
	assert_eq(fx.shown_reach(), 0.0, "the hands come up, they are not just there")
	for i in 40:
		fx._advance(0.05)
	assert_true(fx.shown_reach() > 0.45 and fx.shown_reach() <= 0.5)
	# More damage gathers: they reach higher.
	st.set_stacks_from("decay", me, 190)
	for i in 40:
		fx._advance(0.05)
	assert_eq(fx.target_reach(), 1.0)
	assert_true(fx.shown_reach() > 0.9)
	# It shrinks again as the Breach deals its damage.
	st.set_stacks_from("decay", me, 19)
	for i in 60:
		fx._advance(0.05)
	assert_true(fx.shown_reach() < 0.2)
	# Closed: still there, and it says so.
	st.remove_from("decay", me)
	st.apply(Effects.get_effect("decay_closed"), me)
	for i in 10:
		fx._advance(0.05)
	assert_false(fx.is_open())
	assert_false(fx.is_queued_for_deletion())
	# Gone: the hands sink and the picture removes itself.
	st.remove_from("decay_closed", me)
	for i in 20:
		fx._advance(0.05)
	assert_true(fx.is_queued_for_deletion())

func test_the_enemy_makes_it_from_its_debuffs() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert_contains(src, "status.changed.connect(_sync_breach_fx)")
	assert_contains(src, "BREACH_FX.sync(self)")
	# Nothing of it is sent over the network: the debuffs already are.
	assert_eq(BreachFx.OPEN_ID, "decay")
	assert_eq(BreachFx.CLOSED_ID, "decay_closed")
	assert_true(Effects.get_effect(BreachFx.OPEN_ID) != null and Effects.get_effect(BreachFx.CLOSED_ID) != null)

func test_hands_burst_out_where_a_spell_lands() -> void:
	assert_eq(BreachFx.burst_grow(0.0), 0.0)
	assert_eq(BreachFx.burst_grow(BreachFx.BURST_RISE), 1.0)
	assert_eq(BreachFx.burst_grow(BreachFx.BURST_RISE + BreachFx.BURST_HOLD * 0.5), 1.0)
	assert_eq(BreachFx.burst_grow(BreachFx.burst_time()), 0.0)
	assert_true(BreachFx.burst_time() < 1.0, "over before the next spell")
	var scene := Node3D.new()
	track(scene)
	# Many Hands: a field of them, and no single hole.
	var field: Node3D = BreachFx.burst(scene, Vector3(3, 0, 4), 6.0, 18, 1.3)
	assert_true(field != null)
	assert_eq(field.arms(), 18)
	assert_true(field._is_field())
	# One spell on one enemy: a few hands round one hole.
	var one: Node3D = BreachFx.burst(scene, Vector3.ZERO, 0.6, 5, 1.0)
	assert_eq(one.arms(), 5)
	assert_false(one._is_field())
	assert_eq(BreachFx.burst(scene, Vector3.ZERO, 0.6, 500, 1.0).arms(), 24, "never a crowd that costs frames")
	for i in 30:
		one._advance(0.05)
	assert_true(one.is_queued_for_deletion(), "they sink again and it is gone")
	# Which spells of mine do it as they hit, and that the party sees them too.
	var p := _player()
	for id in p.CLAW_HITS:
		assert_true(Abilities.PATHS.has(id), "%s is an ability" % id)
		assert_eq(Abilities.category_of(id), "shadow")
	assert_true(p.CLAW_HITS.has("blight") and p.CLAW_HITS.has("gnaw") and p.CLAW_HITS.has("hush"))
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_contains(net, "\"claws\":")
	assert_contains(net, "BREACH_FX.burst(w, at")
	var player_src := PlayerSource.text()
	assert_contains(player_src, "_net_fx(\"claws\", at, null")
