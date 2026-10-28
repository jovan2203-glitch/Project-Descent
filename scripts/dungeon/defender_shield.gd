extends Node

# Defender role: its shield (child "DefenderShield", Roles._add_shield) blocks
# hits from the front. In combat it channels "Shield Up" without end, so its
# cast bar says what to do: an interrupt or a stun knocks the shield down (no
# block) for Balance.DEFENDER_SHIELD_DOWN s, then it comes back up.
# The host / solo decides; party members get "shield" enemy fx (their copy
# needs the block off too: their hits are worked out on their machine).

const Names = preload("res://scripts/dungeon/names.gd")
const Balance = preload("res://scripts/balance.gd")

const UP_POS := Vector3(0, 0.1, -0.55)
const DOWN_POS := Vector3(0.45, -0.45, -0.25)
const DOWN_TILT := 1.2

var enemy: Node3D
var block := 0.0             # the role's frontal block, given back when the shield comes up
var up := true
var _tween: Tween            # the running Shield Up channel (host / solo)
var _down_until := 0.0

func _ready() -> void:
	enemy = get_parent() as Node3D
	block = float(enemy.frontal_block)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _authority() -> bool:
	var n := _net()
	return n == null or not n.is_client()

func _process(_delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.is_alive():
		set_process(false)
		return
	if not _authority():
		return
	var stunned: bool = enemy.status != null and enemy.status.has_flag("stun")
	if up:
		if stunned:
			_stop_channel()
			_knock_down()
		elif _tween != null and not _tween.is_valid():
			_tween = null   # enemy.interrupt() killed the channel
			_knock_down()
		elif _tween == null and enemy.is_in_combat() and not enemy.is_casting():
			_channel()
		elif _tween != null and not enemy.is_in_combat():
			_stop_channel()
	elif stunned:
		_down_until = maxf(_down_until, _now() + Balance.DEFENDER_SHIELD_DOWN)
	elif _now() >= _down_until:
		set_up(true)

func _channel() -> void:
	var title := Names.t("ab_shield_up")
	enemy.cast_name = title
	enemy._show_cast(true, Balance.DEFENDER_CHANNEL)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(enemy, "cast", null, {"d": Balance.DEFENDER_CHANNEL, "n": title})
	var t := enemy.create_tween()
	_tween = t
	enemy._cast_tween = t
	t.tween_interval(Balance.DEFENDER_CHANNEL)
	t.tween_callback(func():
		if enemy._cast_tween == t:
			enemy._cast_tween = null
		_tween = null
		if up and enemy.is_alive() and enemy.is_in_combat():
			_channel()   # loops: the bar starts over
		else:
			enemy._show_cast(false))

func _stop_channel() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		if enemy._cast_tween == _tween:
			enemy._cast_tween = null
		enemy._show_cast(false)
	_tween = null

func _knock_down() -> void:
	_down_until = _now() + Balance.DEFENDER_SHIELD_DOWN
	set_up(false)

## Shield up (blocks) or down; on the host also tells the party.
func set_up(on: bool) -> void:
	if on == up:
		return
	up = on
	enemy.frontal_block = block if on else 0.0
	if not on:
		enemy._show_cast(false)
		enemy._cs().float_text(enemy, Names.t("shield_down"), Color(1.0, 0.85, 0.4), true)
	var m := enemy.get_node_or_null("DefenderShield") as Node3D
	if m:
		var tw := m.create_tween().set_parallel()
		tw.tween_property(m, "position", UP_POS if on else DOWN_POS, 0.2)
		tw.tween_property(m, "rotation:x", 0.0 if on else DOWN_TILT, 0.2)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(enemy, "shield", null, {"on": on})
