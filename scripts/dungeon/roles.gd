extends RefCounted

# Enemy ROLES: the fixed set of gameplay archetypes. A role says how an enemy
# FIGHTS; a "skin" (from a dungeon recipe's roster) says what it LOOKS like and
# what it's CALLED. Any skin can play any role, so reskinning a dungeon never
# touches AI or balance.
#
#   Brute     slow, hits hard
#   Swarmer   weak, comes in packs
#   Caster    ranged spells with casts you can interrupt
#   Archer    ranged physical, backs away (kites) when you close in
#   Defender  shield: takes far less damage from the front (flank it); channels
#             "Shield Up" - an interrupt or stun drops it for a while (defender_shield.gd)
#   Support   heals its allies (interruptible "Mend") - a priority kill
#   Summoner  calls in more enemies (interruptible "Summon")
#   Elite / Boss are RANKS on top of a role (see enemy.gd apply_rank).
#
# Usage (spawners, before adding the enemy to the tree):
#   Roles.apply(enemy, "caster", skin)   # skin = roster entry of the recipe
#   enemy.apply_rank("normal", level)

const Names = preload("res://scripts/dungeon/names.gd")
const BEHAVIOR = preload("res://scripts/dungeon/role_behavior.gd")
const SHIELD_GUARD = preload("res://scripts/dungeon/defender_shield.gd")

const ALL := ["brute", "swarmer", "caster", "archer", "defender", "support", "summoner"]

## Multipliers are on the skin's own base stats (a goblin brute is still
## quicker than a zombie brute). Absolute values are marked "set_".
const ROLES := {
	"brute": {"hp": 2.2, "dmg": 2.0, "speed": 0.75, "set_cd": 1.5, "scale": 1.2, "armor": 1.0},
	"swarmer": {"hp": 0.45, "dmg": 0.5, "speed": 1.2, "set_cd": 0.8, "scale": 0.85, "pack": 3},
	"caster": {"hp": 0.7, "set_dmg": 1.5, "speed": 0.9, "set_cd": 3.0, "ranged": "bolt", "windup": 1.2,
		"range": 14.0, "aggro": 9.0},
	"archer": {"hp": 0.7, "set_dmg": 0.8, "speed": 1.0, "set_cd": 1.7, "ranged": "arrow", "range": 12.0,
		"aggro": 9.0, "kite": 5.5},
	"defender": {"hp": 1.8, "dmg": 1.0, "speed": 0.85, "set_cd": 1.2, "armor": 2.0, "block": 0.7},
	"support": {"hp": 0.9, "set_dmg": 0.6, "speed": 0.9, "set_cd": 2.5, "ranged": "bolt", "windup": 1.0,
		"range": 12.0, "aggro": 9.0, "glow": Color(0.4, 1.0, 0.5)},
	"summoner": {"hp": 1.0, "set_dmg": 0.7, "speed": 0.85, "set_cd": 3.0, "ranged": "bolt", "windup": 1.0,
		"range": 12.0, "aggro": 9.0, "glow": Color(0.75, 0.45, 1.0)},
}

static func label(role: String) -> String:
	return Names.t("role_" + role)

## How many enemies one "slot" of this role becomes in a pack (swarmers come in groups).
static func pack_count(role: String) -> int:
	return int(ROLES.get(role, {}).get("pack", 1))

## Turn a freshly instanced enemy into `role`, dressed as `skin`.
## skin = {"scene", "name", "tint", "cast", "school", "color"} (all optional but scene).
static func apply(e: Node, role: String, skin: Dictionary) -> void:
	var r: Dictionary = ROLES.get(role, {})
	e.set("role", role)
	var nm := str(skin.get("name", ""))
	if nm != "":
		e.display_name = Names.t(nm)
		e.elite_name = ""
		e.boss_name = ""
	if skin.has("tint"):
		e.model_tint = skin["tint"]
	if r.is_empty():
		return
	e.max_health = maxi(int(round(float(e.max_health) * float(r.get("hp", 1.0)))), 1)
	if r.has("set_dmg"):
		e.contact_damage = float(r["set_dmg"])
	else:
		e.contact_damage = float(e.contact_damage) * float(r.get("dmg", 1.0))
	e.move_speed = float(e.move_speed) * float(r.get("speed", 1.0))
	if r.has("set_cd"):
		e.attack_cooldown = float(r["set_cd"])
	e.armor = float(e.armor) + float(r.get("armor", 0.0))
	# Ranged or melee.
	var ranged := str(r.get("ranged", ""))
	e.projectile = ranged
	if ranged == "":
		e.attack_windup = 0.0
		e.attack_range = 1.0
		e.cast_name = ""
	else:
		e.attack_range = float(r.get("range", 12.0))
		e.attack_windup = float(r.get("windup", 0.0))
		e.aggro_radius = maxf(float(e.aggro_radius), float(r.get("aggro", 9.0)))
		var school := str(skin.get("school", "shadow" if ranged == "bolt" else "physical"))
		e.projectile_damage_type = school
		if ranged == "bolt":
			e.projectile_tags = PackedStringArray([school.capitalize(), "Spell", "Ranged"])
			e.cast_name = Names.t(str(skin.get("cast", "ab_shadow_bolt")))
			e.base_cast_name = e.cast_name
		else:
			e.projectile_tags = PackedStringArray(["Physical", "Ranged"])
		if skin.has("color"):
			e.projectile_color = skin["color"]
	e.kite_distance = float(r.get("kite", 0.0))
	e.frontal_block = float(r.get("block", 0.0))
	var s := float(r.get("scale", 1.0))
	if not is_equal_approx(s, 1.0):
		e.make_bigger(s)
	if role == "defender":
		_add_shield(e)
		var g := Node.new()
		g.name = "ShieldGuard"
		g.set_script(SHIELD_GUARD)
		e.add_child(g)
	if r.has("glow"):
		e.show_name = true
		e._add_glow(r["glow"], 0.8)
	if role == "support" or role == "summoner":
		var b := Node.new()
		b.name = "RoleBehavior"
		b.set_script(BEHAVIOR)
		b.set("kind", role)
		b.set("summon_role", str(skin.get("summons", "swarmer")))
		e.add_child(b)

## A visible shield in front of Defenders (the side that blocks).
static func _add_shield(e: Node) -> void:
	var m := MeshInstance3D.new()
	m.name = "DefenderShield"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 1.1, 0.1)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.6)
	mat.metallic = 0.7
	mat.roughness = 0.4
	m.material_override = mat
	m.position = Vector3(0, 0.1, -0.55)   # enemies face -Z
	e.add_child(m)
