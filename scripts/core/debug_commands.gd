extends RefCounted

# Cheat / debug console commands, typed into the chat box starting with "/".
# Usage: DebugCommands.run(tree, "/give sword 3") -> Array of reply lines.

const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")

const HELP := [
	"/help — this list",
	"/give <item> [rarity 0-3] [item level] — items: helmet, chestplate, sword, bow",
	"/level <n> — set your level",
	"/xp <n> — gain experience",
	"/god — toggle god mode (no damage taken)",
	"/heal — full health",
	"/killall — kill every enemy",
	"/clearbag — empty your inventory",
	"/fps — toggle the FPS / stats overlay (also F3)",
	"/pool — object pool statistics",
	"/draft — open a level-up draft now",
	"/learn <ability> — learn a draftable ability (e.g. icelance)",
	"/descend — jump to the next dungeon floor",
	"/card <id|all|random> — add Skill Card(s) to your collection",
	"/die — die now (applies the death penalty)",
	"/rune <id> [slot] — learn a rune (and put it on the item in that slot, e.g. \"Main Hand\")",
	"/effect <id> [target] — apply a status effect to yourself (or to your target with \"target\")",
]

static func run(tree: SceneTree, line: String) -> Array:
	var parts := line.strip_edges().trim_prefix("/").split(" ", false)
	if parts.is_empty():
		return []
	var cmd := parts[0].to_lower()
	var args := parts.slice(1)
	var root := tree.root
	var pd := root.get_node_or_null("PlayerData")
	var player := tree.get_first_node_in_group("player")
	var gl := root.get_node_or_null("GameLog")
	if gl:
		gl.info("debug", "Command: %s" % line)
	match cmd:
		"help", "?":
			return HELP
		"give":
			if args.is_empty() or not Items.PATHS.has(args[0]):
				return ["Usage: /give <%s> [rarity 0-3] [item level]" % "|".join(Items.ALL)]
			var rarity := clampi(int(args[1]), 0, 3) if args.size() > 1 else 0
			var ilvl := maxi(int(args[2]), 1) if args.size() > 2 else maxi(int(pd.level), 1)
			var id := ItemDB.create_rolled(args[0], ilvl, rarity)
			if not pd.add_item(id):
				ItemDB.destroy(id)
				return ["Inventory full"]
			return ["Gave %s (%s, item level %d)" % [Items.item_name(id), ItemDB.RARITY_NAMES[rarity], ilvl]]
		"level":
			if args.is_empty():
				return ["Usage: /level <1-%d>" % pd.MAX_LEVEL]
			pd.set_level(int(args[0]))
			if player and player.has_method("_on_level_up"):
				player._on_level_up(pd.level)
			return ["Level set to %d" % pd.level]
		"xp":
			if args.is_empty():
				return ["Usage: /xp <amount>"]
			pd.add_xp(int(args[0]))
			return ["Now level %d, %d / %d XP" % [pd.level, pd.xp, pd.xp_to_next(pd.level)]]
		"god":
			if player == null:
				return ["No player in this scene"]
			player.god_mode = not player.god_mode
			return ["God mode %s" % ("ON" if player.god_mode else "OFF")]
		"heal":
			if player == null:
				return ["No player in this scene"]
			player.receive_heal(9999)
			return ["Healed to full"]
		"killall":
			var n := 0
			for e in tree.get_nodes_in_group("enemies"):
				if e.has_method("is_alive") and e.is_alive() and e.has_method("_die"):
					e._die()
					n += 1
			return ["Killed %d enemies" % n]
		"clearbag":
			for i in pd.INVENTORY_SIZE:
				if pd.inventory[i] != "":
					ItemDB.destroy(pd.inventory[i])
					pd.inventory[i] = ""
			pd.changed.emit()
			return ["Inventory cleared"]
		"fps":
			var overlay := tree.get_first_node_in_group("debug_overlay")
			if overlay == null:
				return ["Overlay not available here"]
			overlay.toggle()
			return ["Overlay %s" % ("shown" if overlay.visible else "hidden")]
		"draft":
			pd.pending_drafts.append(maxi(int(pd.level), 2))
			return ["Draft queued (opens in a moment)"]
		"learn":
			if args.is_empty() or not preload("res://scripts/abilities.gd").DRAFT_POOL.has(args[0]):
				return ["Usage: /learn <%s>" % "|".join(preload("res://scripts/abilities.gd").DRAFT_POOL)]
			pd.learn_ability(args[0])
			return ["Learned %s" % args[0]]
		"rune":
			var Runes = preload("res://scripts/runes.gd")
			if args.is_empty() or not Runes.PATHS.has(args[0]):
				return ["Usage: /rune <%s> [slot]" % "|".join(Runes.ALL)]
			pd.learn_rune(args[0])
			if args.size() > 1:
				var slot := " ".join(args.slice(1))
				var err: String = pd.apply_rune(slot, args[0])
				if err != "":
					return ["Learned %s, but: %s" % [Runes.rune_name(args[0]), err]]
				return ["Learned %s and applied it to %s" % [Runes.rune_name(args[0]), slot]]
			pd.changed.emit()
			return ["Learned %s (apply it from the Runes panel)" % Runes.rune_name(args[0])]
		"effect":
			var Effects = preload("res://scripts/core/effects.gd")
			if args.is_empty() or Effects.get_effect(args[0]) == null:
				return ["Usage: /effect <%s> [target]" % "|".join(Effects.all_ids())]
			var who: Node = player
			if args.size() > 1 and args[1] == "target":
				who = player.target if player and player.has_valid_target() else null
			if who == null:
				return ["No target"]
			Effects.apply(who, args[0], player)
			return ["Applied %s" % args[0]]
		"card":
			var SkillCards = preload("res://scripts/skill_cards.gd")
			if args.is_empty():
				return ["Usage: /card <all|random|%s>" % "|".join(SkillCards.ALL)]
			if args[0] == "all":
				for c in SkillCards.ALL:
					pd.grant_card(c)
				return ["You now own all %d Skill Cards" % SkillCards.ALL.size()]
			var cid: String = pd.random_unowned_card() if args[0] == "random" else args[0]
			if cid == "":
				return ["You already own every Skill Card"]
			if not SkillCards.exists(cid):
				return ["Unknown card: %s" % cid]
			return ["Added Skill Card %s" % cid] if pd.grant_card(cid) else ["You already own %s" % cid]
		"die":
			if player == null or not player.is_alive():
				return ["No living player here"]
			var was_god: bool = player.god_mode
			player.god_mode = false
			player.take_damage(99999)
			player.god_mode = was_god
			return ["You died"]
		"descend":
			root.get_node("GameManager").descend()
			return ["Descending…"]
		"pool":
			var pool := root.get_node_or_null("Pool")
			if pool == null:
				return ["No pool"]
			var out := []
			for key in pool.stats:
				out.append("%s: created %d, reused %d, idle %d" % [key, pool.stats[key]["created"], pool.stats[key]["reused"], pool.free_count(key)])
			return out if not out.is_empty() else ["Pool is empty"]
	return ["Unknown command: /%s  (try /help)" % cmd]
