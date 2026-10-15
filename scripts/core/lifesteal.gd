extends Node

# Lifesteal (child of the player). The Lifesteal stat returns a share of what
# you do as health: that % of every hit you land and of the healing you do on
# OTHERS (healing yourself doesn't count). Collected continuously and paid out
# once per second as one "Lifesteal" heal, so it doesn't spam numbers - it
# shows up in the Details meter under Healing.

const TICK := 1.0

var _pending := 0.0
var _t := 0.0

func _player() -> Node:
	return get_parent()

func _ready() -> void:
	var bus := get_node("/root/SignalBus")
	bus.damage_dealt.connect(_on_damage)
	bus.heal_done.connect(_on_heal)

func _pct() -> float:
	var p := _player()
	var pct := float(p.get_stat("lifesteal")) if p and p.has_method("get_stat") else 0.0
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("lifesteal_mult"):
		pct *= float(gm.lifesteal_mult())   # Bloodthirst modifier
	return pct

func _on_damage(info: RefCounted) -> void:
	var src: Node = info.source
	if src == null or not is_instance_valid(src) or src != _player() or info.amount <= 0:
		return
	if info.target == src:
		return
	_pending += float(info.amount) * _pct() / 100.0

func _on_heal(source: Node, target: Node, _amount: int, effective: int, ability_id: String, _crit: bool) -> void:
	if source != _player() or target == source or ability_id == "lifesteal" or effective <= 0:
		return
	_pending += float(effective) * _pct() / 100.0

func _process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var amount := int(floor(_pending))
	if amount <= 0:
		return
	_pending -= amount
	var p := _player()
	if p == null or not p.has_method("is_alive") or not p.is_alive():
		_pending = 0.0
		return
	var h = p.get("health")
	var mh = p.get("max_health")
	if h != null and mh != null and int(h) >= int(mh):
		return   # already full: nothing to restore (the rest is dropped)
	get_node("/root/CombatSystem").heal(p, p, float(amount), "lifesteal", true)
