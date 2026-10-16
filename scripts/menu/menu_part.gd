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
