@tool
extends McpTestSuite

# Rune of the Wild Page (Legendary): a spell or ability of mine can cast a random
# damaging ability of its book at my target for free, with everything it does.

const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const Details = preload("res://scripts/core/details.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")

const BOOKS := ["martial", "fire", "frost", "lightning", "arcane", "shadow", "nature", "holy"]

func suite_name() -> String:
	return "wild_page"

func test_it_is_a_legendary_rune() -> void:
	assert_true(Runes.PATHS.has("wild_page") and Runes.ALL.has("wild_page"), "registered")
	assert_eq(Runes.rarity("wild_page"), Runes.LEGENDARY)
	assert_eq(Runes.rune_name("wild_page"), "Rune of the Wild Page")
	assert_ne(Runes.check_limits(["wild_page", "dusk_till_dawn"]), "", "only one Legendary rune at a time")
	assert_eq(Runes.check_limits(["wild_page", "overload", "frost"]), "", "fine next to Epic and lower runes")
	assert_eq(WildPageKit.WILD_PAGE_RUNE, "wild_page")

func test_its_text_has_every_number_filled_in() -> void:
	var text := Runes.description("wild_page")
	assert_eq(TextFill.leftover(text), "", "every placeholder is filled")
	assert_contains(text, "%s%% chance" % TextFill.num(Balance.WILD_PAGE_CHANCE))
	assert_contains(text, "%s sec" % TextFill.num(Balance.WILD_PAGE_COOLDOWN))
	var raw := str(Runes.get_resource("wild_page").description)
	assert_false(raw.contains(TextFill.num(Balance.WILD_PAGE_CHANCE) + "%"), "numbers come from balance.gd")

func test_every_book_has_pages() -> void:
	for book in BOOKS:
		var page := WildPageKit.pool(book, "", {})
		assert_true(page.size() >= 5, "%s has %d pages" % [book, page.size()])
		for id in page:
			assert_eq(Abilities.category_of(id), book, "%s is from %s" % [id, book])
			assert_true(WildPageKit.echo_coef(id, {}) > 0.0, "%s has a hit" % id)
			for t in WildPageKit.NO_HIT_TAGS:
				assert_false(Abilities.tags_of(id).has(t), "%s (%s) has no hit to echo" % [id, t])

func test_no_pages_outside_the_books() -> void:
	assert_true(WildPageKit.pool(Categories.RUNE, "", {}).is_empty(), "rune spells have no book to tear from")
	assert_true(WildPageKit.pool("", "", {}).is_empty())

func test_never_itself() -> void:
	assert_false(WildPageKit.pool("frost", "frostbolt", {}).has("frostbolt"))
	assert_true(WildPageKit.pool("frost", "", {}).has("frostbolt"))
	assert_false(WildPageKit.pool("frost", "", {}).has("rimeshell"), "a shield isn't a page")

func test_chance_and_cooldown() -> void:
	assert_eq(Balance.WILD_PAGE_CHANCE, 30.0)
	assert_eq(Balance.WILD_PAGE_COOLDOWN, 3.0)
	assert_true(WildPageKit.tears(29.9, 10.0, 0.0))
	assert_false(WildPageKit.tears(30.0, 10.0, 0.0), "a roll over the chance")
	assert_false(WildPageKit.tears(0.0, 10.0, 12.0), "still on its cooldown")
	assert_true(WildPageKit.tears(0.0, 12.0, 12.0))

func test_how_each_page_is_cast() -> void:
	assert_eq(WildPageKit.echo_kind("frostbolt"), "land", "a cast lands straight away")
	assert_eq(WildPageKit.echo_kind("blizzard"), "land", "so does a ground cast")
	assert_eq(WildPageKit.echo_kind("arcanemissiles"), "burst", "a channel goes out at once")
	assert_eq(WildPageKit.echo_kind("embervolley"), "burst")
	assert_eq(WildPageKit.echo_kind("cinderrain"), "placed", "an instant aimed at a spot: the target's feet")
	assert_eq(WildPageKit.echo_kind("frostnova"), "use", "an instant goes off as used")
	for book in BOOKS:
		for id in WildPageKit.pool(book, "", {}):
			assert_ne(WildPageKit.echo_kind(id), "", "%s can be cast for free" % id)

func test_free_casts_cost_nothing() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "func _land_spell(spell: String) -> void:", "a cast's landing is its own step")
	assert_contains(src, "\t_land_spell(spell)\n", "... which a real cast still goes through")
	assert_contains(src, "if echoing():\n\t\treturn true   # a free cast (Rune of the Wild Page)", "nothing is paid")
	assert_contains(src, "_use_drafted_now(id, res, w)   # a free cast: no requirement, range or cost")
	var kit := FileAccess.get_file_as_string("res://scripts/player/rune_wild_page.gd")
	for kept in ["\"resources\": player.resources.duplicate()", "\"gcd_left\": player.gcd_left", "\"cd\": float(player.cooldowns.get(id, 0.0))", "\"pstate\": player.pstate"]:
		assert_contains(kit, kept, "a free cast leaves this as it was: " + kept)
	for f in ["frost_steel", "frost_glacier", "holy_censer", "martial_sharpshooter"]:
		assert_contains(FileAccess.get_file_as_string("res://scripts/player/%s.gd" % f), "player.echoing()", "%s: no stacks used up" % f)

func test_echo_hits_have_their_own_lines() -> void:
	var info := DamageInfo.make(null, null, 1.0, "fireball")
	info.amount = 100
	assert_false(info.echo)
	info.echo = true
	var rows := Details.split_hit(info)
	assert_eq(str(rows[0][0]), "fireball" + Details.ECHO_SUFFIX)
	assert_eq(Details.spell_name("fireball" + Details.ECHO_SUFFIX), Abilities.ability_name("fireball") + " (Wild Page)")
	assert_eq(Details.spell_color("fireball" + Details.ECHO_SUFFIX), Details.spell_color("fireball"))
	for f in ["frost_bolt", "arrow", "sleet_wave", "blizzard", "thunderhead", "ball_lightning", "cinder_rain", "fire_wall"]:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % f)
		assert_contains(src, "echo = Combat.echoing(source)", "%s remembers being made by a free cast" % f)
		assert_contains(src, "Combat.run_as(source, echo,", "%s hits as an echo" % f)
