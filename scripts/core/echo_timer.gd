extends RefCounted

# A one-shot timer for something a player sets to happen later (Player.echo_timer):
# `timeout` like a SceneTreeTimer's. One set during a free cast (Rune of the Wild
# Page) goes off as part of it, so what it deals is an echo too.

const Combat = preload("res://scripts/combat_utils.gd")

signal timeout

static func make(tree: SceneTree, seconds: float, src: Node, echo: bool) -> RefCounted:
	var t: RefCounted = load("res://scripts/core/echo_timer.gd").new()
	tree.create_timer(seconds).timeout.connect(func(): Combat.run_as(src, echo, func(): t.timeout.emit()))
	return t
