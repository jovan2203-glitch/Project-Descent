extends Node

# Extra behaviour for the Support and Summoner roles (child of the enemy).
# Runs on the host / solo only; party members see the cast bar through Net.
#
#   Support:  casts "Mend" (interruptible) on the most hurt ally nearby,
#             healing it for a chunk of its max health.
#   Summoner: casts "Summon" (interruptible), calling in a few enemies of
#             `summon_role` from the dungeon's roster. Keeps a small cap alive.

const Names = preload("res://scripts/dungeon/names.gd")

const MEND_TIME := 1.6
const MEND_EVERY := 7.0
const MEND_RANGE := 12.0
const MEND_PCT := 0.25          # of the healed ally's max health
const MEND_BELOW := 0.8         # only allies under this share of health
const SUMMON_TIME := 2.0
const SUMMON_EVERY := 14.0
const SUMMON_COUNT := 2
const SUMMON_CAP := 3           # alive summons per summoner

var kind := "support"
var summon_role := "swarmer"
var enemy: Node3D
var _cd := 3.0

func _ready() -> void:
	enemy = get_parent() as Node3D

func _authority() -> bool:
	var n := get_node_or_null("/root/Net")
	return n == null or not n.is_client()

func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or not _authority():
		return
	if not enemy.is_in_combat():
		return
	_cd -= delta
	if _cd > 0.0 or enemy.is_casting() or enemy.is_silenced() or enemy.status.has_flag("stun"):
		return
	if kind == "support":
		var tgt := _hurt_ally()
		if tgt == null:
			_cd = 1.0
			return
		_cd = MEND_EVERY
		_cast(Names.t("ab_mend"), MEND_TIME, func():
			if is_instance_valid(tgt) and tgt.is_alive():
				var amount := maxi(int(round(float(tgt.max_health) * MEND_PCT)), 1)
				tgt.receive_heal(amount)
				get_node("/root/CombatSystem").float_text(tgt, "+%d" % amount, Color(0.45, 1.0, 0.45), false))
	elif kind == "summoner":
		if _alive_summons() >= SUMMON_CAP:
			_cd = 2.0
			return
		_cd = SUMMON_EVERY
		_cast(Names.t("ab_summon"), SUMMON_TIME, func():
			var scene := get_tree().current_scene
			if scene and scene.has_method("summon_adds"):
				scene.summon_adds(enemy.global_position, SUMMON_COUNT, summon_role, enemy))

func _hurt_ally() -> Node3D:
	var best: Node3D = null
	var best_pct := MEND_BELOW
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("is_alive") or not e.is_alive():
			continue
		if enemy._flat_dist(e.global_position) > MEND_RANGE:
			continue
		var pct := float(e.health) / maxf(float(e.max_health), 1.0)
		if pct < best_pct:
			best_pct = pct
			best = e
	return best

func _alive_summons() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get_meta("summoned_by", "") == str(enemy.name) and e.is_alive():
			n += 1
	return n

## A cast that interrupts cancel (it IS the enemy's cast tween).
func _cast(title: String, time: float, done: Callable) -> void:
	enemy.cast_name = title   # its normal bolts switch back (enemy.base_cast_name)
	enemy.busy_until = Time.get_ticks_msec() / 1000.0 + time
	enemy._show_cast(true, time)
	var n := get_node_or_null("/root/Net")
	if n and n.is_host():
		n.enemy_fx(enemy, "cast", null, {"d": time, "n": title})
	var t := enemy.create_tween()
	enemy._cast_tween = t
	t.tween_interval(time)
	t.tween_callback(func():
		enemy._cast_tween = null
		enemy._show_cast(false)
		if is_instance_valid(enemy) and enemy.is_alive():
			done.call())
