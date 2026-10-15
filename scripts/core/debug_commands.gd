extends RefCounted

# Cheat / debug console commands, typed into the chat box starting with "/".
# Usage: DebugCommands.run(tree, "/give sword 3") -> Array of reply lines.

const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Balance = preload("res://scripts/balance.gd")

const HELP := [
	"/help — this list",
	"/give <item> [rarity] [item level] — e.g. /give storm idol epic 30  (type /give alone for the item list)",
	"/level <n> — set your level",
	"/xp <n> — gain experience",
	"/god — toggle god mode (no damage taken)",
	"/heal — full health",
	"/killall — kill every enemy",
	"/clearbag — empty your inventory",
	"/fps — toggle the FPS / stats overlay (also F3)",
	"/pool — object pool statistics",
	"/draft — open a level-up draft now",
	"/learn <ability> — learn a draftable ability (e.g. rimeshell)",
	"/learn all (or /learnall) — learn every ability",
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
			return _give(tree, pd, args)
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
			player.receive_heal(9999999)
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
		"learn", "learnall":
			var Abilities = preload("res://scripts/abilities.gd")
			if cmd == "learnall" or (not args.is_empty() and args[0] == "all"):
				var n := 0
				for id in Abilities.DRAFT_POOL:
					if not pd.has_ability(id):
						pd.learn_ability(id)
						n += 1
				return ["Learned %d abilities — you now know all %d (open the Spellbook, P)" % [n, Abilities.DRAFT_POOL.size()]]
			if args.is_empty() or not Abilities.DRAFT_POOL.has(args[0]):
				return ["Usage: /learn <all|%s>" % "|".join(Abilities.DRAFT_POOL)]
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
			if player == null:
				return ["Only works inside a dungeon"]
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

# --- /give -----------------------------------------------------------------------------
# /give <item> [rarity] [item level]
#   item      its name or id, or any part of either ("storm", "Storm Idol", "storm_idol")
#   rarity    common / uncommon / rare / epic, or 0-3 (default: common)
#   level     the item level (default: your level)
# In a dungeon the item goes into your bag; in the main menu (where the bag is
# not shown) it goes straight into your bank.

## What `/give` alone prints: how to use it, and every item by kind.
static func give_help() -> Array:
	var kinds := {}   # heading -> names
	for id in Items.ALL:
		var d := Items.get_item(str(id))
		var head := "Other"
		if d.has("weapon"):
			head = "Weapons"
		elif str(d.get("slot", "")).begins_with("Trinket"):
			head = "Trinkets"
		elif str(d.get("slot", "")) != "":
			head = "Armor and jewelry"
		if not kinds.has(head):
			kinds[head] = []
		(kinds[head] as Array).append(Items.item_name(str(id)))
	var out := [
		"/give <item> [armor type] [rarity] [item level]",
		"  item: its name, or part of it.  rarity: common, uncommon, rare or epic (default common).  item level: default is your level.",
		"  armor type (armor pieces only): cloth, light, medium or heavy (default: a random one).",
		"  Examples:  /give sword     /give storm idol epic     /give helmet rare 30     /give chestplate heavy epic 50",
	]
	for head in ["Weapons", "Armor and jewelry", "Trinkets", "Other"]:
		if kinds.has(head):
			out.append("  %s: %s" % [head, ", ".join(kinds[head])])
	return out

## Item ids that `text` could mean: an exact id or name wins, otherwise every
## item whose id or name contains it.
static func find_items(text: String) -> Array:
	var want := text.strip_edges().to_lower()
	var loose: Array = []
	if want == "":
		return loose
	for id in Items.ALL:
		var sid := str(id)
		var name := Items.item_name(sid).to_lower()
		if want == sid or want == name or want == sid.replace("_", " "):
			return [sid]
		if sid.contains(want.replace(" ", "_")) or name.contains(want):
			loose.append(sid)
	return loose

## Split "/give" arguments into {"item": text, "rarity": 0-3, "level": n (0 = yours)}.
## Trailing words that are a rarity or a number are options; the rest is the item.
static func parse_give(args: Array) -> Dictionary:
	var words: Array = []
	for a in args:
		words.append(str(a))
	var rarity := -1
	var armor_type := ItemDB.ROLL_ARMOR_TYPE
	var numbers: Array = []
	while not words.is_empty():
		var last := str(words[words.size() - 1]).to_lower()
		var named := -1
		for i in ItemDB.RARITY_NAMES.size():
			if str(ItemDB.RARITY_NAMES[i]).to_lower() == last:
				named = i
		# An armor type (cloth, light, medium, heavy), as long as it is not the whole item name.
		var typed := -1
		for i in Balance.ARMOR_TYPE_NAMES.size():
			if str(Balance.ARMOR_TYPE_NAMES[i]).to_lower() == last:
				typed = i
		if named >= 0 and rarity < 0:
			rarity = named
		elif typed >= 0 and armor_type < 0 and words.size() > 1:
			armor_type = typed
		elif last.is_valid_int():
			numbers.push_front(int(last))
		else:
			break
		words.pop_back()
	var level := 0
	if numbers.size() >= 2:
		# The old form: /give sword 3 30 = rarity 3, item level 30.
		if rarity < 0:
			rarity = clampi(int(numbers[0]), 0, 3)
		level = int(numbers[numbers.size() - 1])
	elif numbers.size() == 1:
		# One number: 0-3 is a rarity (unless one was named), anything else a level.
		if rarity < 0 and int(numbers[0]) <= 3:
			rarity = clampi(int(numbers[0]), 0, 3)
		else:
			level = int(numbers[0])
	var out := {"item": " ".join(words), "rarity": maxi(rarity, 0), "level": maxi(level, 0)}
	if armor_type >= 0:
		out["armor_type"] = armor_type   # (only when one was named: otherwise the piece rolls its own)
	return out

static func _give(tree: SceneTree, pd: Node, args: Array) -> Array:
	if args.is_empty():
		return give_help()
	var want := parse_give(args)
	var found := find_items(str(want["item"]))
	if found.is_empty():
		return ["No item called \"%s\". Type /give on its own to see every item." % str(want["item"])]
	if found.size() > 1:
		var names: Array = []
		for id in found:
			names.append(Items.item_name(str(id)))
		return ["\"%s\" could be: %s. Type more of the name." % [str(want["item"]), ", ".join(names)]]
	var rarity := int(want["rarity"])
	var ilvl := int(want["level"]) if int(want["level"]) > 0 else maxi(int(pd.level), 1)
	var id := ItemDB.create_rolled(str(found[0]), ilvl, rarity, "", int(want.get("armor_type", ItemDB.ROLL_ARMOR_TYPE)))
	# In a dungeon: the bag. In the main menu: the bank (the bag isn't shown there).
	var in_game := tree.get_first_node_in_group("player") != null
	var where := "bag"
	if in_game:
		if not pd.add_item(id):
			ItemDB.destroy(id)
			return ["Your bag is full: nothing was given."]
	else:
		where = "bank"
		var free: int = pd.bank.find("")
		if free == -1:
			ItemDB.destroy(id)
			return ["Your bank is full: nothing was given."]
		pd.bank[free] = id
		pd.changed.emit()
	var need := Items.required_level(id)
	return ["Gave %s %s (item level %d) - it is in your %s.%s" % [ItemDB.RARITY_NAMES[rarity], Items.item_name(id), ilvl, where,
		"  Needs level %d to wear." % need if need > int(pd.level) else ""]]
