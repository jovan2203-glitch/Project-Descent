extends RefCounted

# Absorb shields the player puts on people (Rime Shell, Frozen Aegis), built the
# same way for you, the training ally dummy and party members.
# Usage: const Shields = preload("res://scripts/core/shields.gd")

const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const RIME_SHELL_FX = preload("res://data/effects/rime_shell.tres")
const Balance = preload("res://scripts/balance.gd")
const AEGIS_ID := "frozen_aegis"

## Rime Shell's effect, plus Hardened Frost's armor bonus when armor_pct > 0.
static func rime_shell_fx(armor_pct: float) -> Resource:
	if armor_pct <= 0.0:
		return RIME_SHELL_FX
	var fx: Resource = RIME_SHELL_FX.duplicate()
	var mods: Dictionary = RIME_SHELL_FX.stat_modifiers.duplicate()
	mods["armor%"] = float(mods.get("armor%", 0.0)) + armor_pct
	fx.stat_modifiers = mods
	return fx

const RIME_SHELL_FOE_FX = preload("res://data/effects/rime_shell_foe.tres")
const RIME_SHELL_ID := "rime_shell"
const RIME_SHELL_FOE_ID := "rime_shell_foe"
const RIME_SHELL_TAGS := ["Frost", "Spell"]

## Put a Rime Shell of `amount` on the character that owns `status`. The one
## routine for every target: you, a party member, the training ally and enemies.
##   on_enemy  - the enemy version: it takes more damage from everyone, and the
##               shell STAYS on it for its full time after the shield breaks
##               (on an ally the shell ends when its shield is used up).
##   shatter   - called when damage uses the shield up (the caster's machine
##               deals the shatter, see Net.request_shatter). Not called when
##               the shell runs out or is removed.
## Returns true if the shell went on.
static func put_rime_shell(status: Node, caster: Node, amount: int, on_enemy: bool,
		armor_pct: float = 0.0, shatter: Callable = Callable()) -> bool:
	if status == null or amount <= 0:
		return false
	var fx: Resource = RIME_SHELL_FOE_FX if on_enemy else rime_shell_fx(armor_pct)
	status.apply(fx, caster, PackedStringArray(RIME_SHELL_TAGS))
	var id := RIME_SHELL_FOE_ID if on_enemy else RIME_SHELL_ID
	if not status.effects.has(id):
		return false   # resisted / dead
	status.set_absorb(id, amount, shatter, on_enemy)
	return true

## Take the shield off `status`'s Rime Shell without shattering it (the caller
## shatters it: Shattering Wave / Shattering Slam). On an enemy the shell itself
## stays; on an ally it ends. Returns true if there was a shield.
static func drop_rime_shield(status: Node, on_enemy: bool) -> bool:
	if status == null:
		return false
	var id := RIME_SHELL_FOE_ID if on_enemy else RIME_SHELL_ID
	var had: bool = status.break_absorb(id, true)
	if not on_enemy:
		status.remove(id)
	return had

## The Frozen Aegis rune's shield effect (armor_pct = Hardened Frost).
static func aegis_fx(armor_pct: float) -> Resource:
	var r := StatusEffectScript.new()
	r.id = StringName(AEGIS_ID)
	r.display_name = "Frozen Aegis"
	r.description = "An icy shield absorbs damage."
	r.color = Color(0.6, 0.9, 1.0)
	r.tags = PackedStringArray(["Frost"])
	r.duration = Balance.FROZEN_AEGIS_TIME
	r.stack_mode = 0
	if armor_pct > 0.0:
		r.stat_modifiers = {"armor%": armor_pct}
	return r

const WARD_ID := "snow_ward"

## Snow Ward's shield effect (armor_pct = Hardened Frost).
static func ward_fx(armor_pct: float) -> Resource:
	var r := StatusEffectScript.new()
	r.id = StringName(WARD_ID)
	r.display_name = "Snow Ward"
	r.description = "A shield of snow absorbs damage."
	r.color = Color(0.85, 0.95, 1.0)
	r.tags = PackedStringArray(["Frost"])
	r.duration = Balance.SNOW_WARD_TIME
	r.stack_mode = 0
	if armor_pct > 0.0:
		r.stat_modifiers = {"armor%": armor_pct}
	return r

## Shield a Snow Ward of `amount` leaves on someone who already has `left` of
## one: it never stacks and never shrinks what is there.
static func ward_total(left: int, amount: int) -> int:
	return maxi(left, amount)

## Put a Snow Ward of `amount` on `status` (restarts its time).
static func set_ward(status: Node, caster: Node, amount: int, armor_pct: float) -> void:
	if status == null or amount <= 0:
		return
	var total := ward_total(int(status.absorb_left(WARD_ID)), amount)
	if not status.apply(ward_fx(armor_pct), caster):
		return
	status.set_absorb(WARD_ID, total)

## Add `amount` to the Frozen Aegis shield on `status`, up to `cap` in total.
static func add_aegis(status: Node, caster: Node, amount: int, cap: int, armor_pct: float) -> void:
	if status == null or amount <= 0:
		return
	var total := mini(int(status.absorb_left(AEGIS_ID)) + amount, maxi(cap, amount))
	if not status.apply(aegis_fx(armor_pct), caster):
		return
	status.set_absorb(AEGIS_ID, total)
