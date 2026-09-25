extends Node

# Object pool (autoload "Pool"). Reuses short-lived nodes (projectiles, damage
# numbers, effects) instead of creating and freeing hundreds per fight.
#
#   var bolt = Pool.acquire("frost_bolt", func(): return make_bolt())
#   scene.add_child(bolt)            # caller adds it to the tree
#   ...
#   Pool.release(bolt)               # instead of queue_free()
#
# Released nodes are taken out of the tree and kept (up to MAX_PER_KEY per key).
# A node's _ready() only runs the first time, so pooled scripts build their
# visuals once and reset their state when reused.

const MAX_PER_KEY := 64

var _free := {}          # key -> Array of detached nodes
var stats := {}          # key -> {"created": n, "reused": n}

func acquire(key: String, factory: Callable) -> Node:
	var list: Array = _free.get(key, [])
	while not list.is_empty():
		var n: Node = list.pop_back()
		if is_instance_valid(n):
			_count(key, "reused")
			if n is Node3D or n is CanvasItem:
				n.visible = true
			return n
	var created: Node = factory.call()
	created.set_meta("pool_key", key)
	_count(key, "created")
	return created

## Return a node to the pool (safe to call from the node's own callbacks).
func release(n: Node) -> void:
	if n == null or not is_instance_valid(n) or n.get_meta("pooled", false):
		return
	var key := str(n.get_meta("pool_key", ""))
	if key == "":
		n.queue_free()
		return
	n.set_meta("pooled", true)
	_detach.call_deferred(n, key)

func _detach(n: Node, key: String) -> void:
	if not is_instance_valid(n):
		return
	var parent := n.get_parent()
	if parent:
		parent.remove_child(n)
	n.set_meta("pooled", false)
	var list: Array = _free.get(key, [])
	if list.size() >= MAX_PER_KEY:
		n.queue_free()
		return
	list.append(n)
	_free[key] = list

func _count(key: String, what: String) -> void:
	if not stats.has(key):
		stats[key] = {"created": 0, "reused": 0}
	stats[key][what] += 1

func free_count(key: String) -> int:
	return (_free.get(key, []) as Array).size()

func _exit_tree() -> void:
	for key in _free:
		for n in _free[key]:
			if is_instance_valid(n):
				n.free()
	_free.clear()
