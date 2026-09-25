extends Node

# Global event bus (autoload "SignalBus").
# Emit from anywhere:   SignalBus.enemy_died.emit(self)
# Listen from anywhere: SignalBus.enemy_died.connect(_on_enemy_died)
# Emitters and listeners never need references to each other.

# --- Player ---
signal player_health_changed(current: int, maximum: int)
signal player_damaged(amount: int)
signal player_died
signal action_error(message: String)          # "Not enough mana", "Out of range", ...
signal player_blocked                          # armor blocked a hit
## Every hit the player lands. ability_id is e.g. "frostbolt", "auto_melee".
## is_proc = caused by an rune (runes ignore these to avoid chains).
signal player_hit(ability_id: String, target: Node, amount: int, crit: bool, is_proc: bool)
signal rune_triggered(rune_id: String)
## Every damage event from CombatSystem (a DamageInfo), player or enemy.
signal damage_dealt(info: RefCounted)
## Fired by CombatSystem BEFORE a hit's damage is calculated, after status-effect
## modifiers were added. Listeners may call info.add_bonus(pct, "label") to make
## the hit stronger/weaker (talents, set bonuses, scripted interactions).
signal damage_modify(info: RefCounted)
## An enemy's state machine changed state (GameManager/AI debugging, UI).
signal enemy_state_changed(enemy: Node, state: String)
signal buffs_changed

# --- Abilities / casting ---
signal ability_used(ability_id: String)
signal cast_started(ability_id: String, duration: float)
signal cast_finished(ability_id: String)
signal cast_interrupted(ability_id: String)

# --- Enemies ---
signal enemy_aggroed(enemy: Node)
signal enemy_damaged(enemy: Node, amount: int)
signal enemy_died(enemy: Node)

## A status effect was newly applied (or gained a stack) on `target`.
signal status_applied(target: Node, effect_name: String, is_debuff: bool, stacks: int)
## A "consume on use" effect was used up by a hit (e.g. Stormfire on a fire spell).
signal status_consumed(target: Node, effect_id: String, effect_name: String, stacks: int)
## CombatSystem.heal() restored HP.
signal healed(source: Node, target: Node, amount: int)

# --- Progression ---
signal xp_changed(level: int, xp: int, xp_to_next: int)
signal xp_gained(amount: int)
signal level_up(level: int)
signal skill_card_unlocked(ability_id: String)
## Level-up draft: overlay opened with these choices / an ability was learned.
signal draft_opened(level: int, choices: Array)
signal ability_learned(ability_id: String)

# --- Dungeon ---
signal room_cleared(room_index: int)
signal boss_engaged(boss: Node)
signal boss_defeated(boss: Node)
signal dungeon_cleared(summary: Dictionary)

# --- Items ---
signal item_looted(item_id: String)
signal loot_dropped(item_id: String, position: Vector3)

# --- Chat / debug ---
## A chat line was sent locally (the chat UI shows it).
signal chat_message(sender: String, text: String)

# --- Game flow ---
signal game_state_changed(state: int)          # GameManager.State
