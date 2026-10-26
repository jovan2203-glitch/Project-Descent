extends Node
class_name MenuPart

# A component of the main menu: one tab's (or overlay's) own code, moved out of
# scripts/main_menu.gd so that file stays the shared core (scene, pages, nav bar,
# XP bar, toasts, input callbacks). The menu makes one of each in its "Components"
# section (_part), as a child node, and calls into it. Inside a part, `menu` is the
# menu: menu.ui, menu.pages, menu._toast_ok(...); the menu's consts and static
# functions are MainMenu.NAME. Engine callbacks (_ready, _process, _input, ...) stay
# in main_menu.gd. SPLIT_HOST=menu tools/split_batch.sh moves a section into a part.

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const SOCIAL_PANEL = preload("res://scripts/ui/social_panel.gd")
const ChatBox = preload("res://scripts/ui/chat_box.gd")
const RuneScreens = preload("res://scripts/ui/rune_screens.gd")
const RuneManager = preload("res://scripts/ui/rune_manager.gd")
const MacroWindow = preload("res://scripts/ui/macro_window.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Pacts = preload("res://scripts/pacts.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const DB = preload("res://scripts/dungeon/dungeon_db.gd")

## The main menu this part works for.
var menu: MainMenu

## For PlayerData.changed_late, bound to a page and its refresh:
## `pd.changed_late.connect(_refresh_if_shown.bind(page, _refresh_x))`.
## Refreshes now while `page` is showing, otherwise once it is next shown, so a
## hidden page doesn't rebuild on every change (e.g. each talent point). A bound
## method, not a lambda: Godot drops it when the menu is freed.
func _refresh_if_shown(page: Control, refresh: Callable) -> void:
	if page.is_visible_in_tree():
		refresh.call()
		return
	if not page.has_meta("_stale"):
		page.visibility_changed.connect(_refresh_stale.bind(page))
	var stale: Array = page.get_meta("_stale", [])
	if not stale.has(refresh):
		stale.append(refresh)
	page.set_meta("_stale", stale)

func _refresh_stale(page: Control) -> void:
	if not page.is_visible_in_tree():
		return
	var stale: Array = page.get_meta("_stale", [])
	page.set_meta("_stale", [])
	for refresh in stale:
		refresh.call()
