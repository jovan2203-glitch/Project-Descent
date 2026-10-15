extends Node

# Elite traits. Every elite enemy rolls one (seeded by its spawn zone, so every
# machine in a party picks the same). The trait's name goes in front of the
# enemy's name ("Vampiric Elite Zombie") and its description shows in the
# target frame. Numbers live in balance.gd (ELITE_*). Works for every enemy type.
#
#   shielded     regains a damage shield (% of max health) a while after it breaks
#   hasted       moves and attacks faster
#   unstoppable  immune to stuns, roots and slows (incl. Frozen)
#   vampiric     heals for part of the damage it deals
#   volatile     explodes shortly after dying (red warning circle: get out)
#   berserker    enrages at low health: more damage, faster attacks
#
# Static helpers are used by enemy.gd; an instance of this script is the
# per-enemy runtime part (child "EliteTrait") for the traits that need to tick.
# Only the host / solo player runs the gameplay side; party members get the
# visuals through Net.enemy_fx.

const Balance = preload("res://scripts/balance.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const BOSS_ABILITIES = preload("res://scripts/dungeon/boss_abilities.gd")

const TRAITS := {
	"shielded": {"title": "Shielded", "color": Color(0.6, 0.85, 1.0),
		"desc": "Regains a damage shield every %d s" % int(Balance.ELITE_SHIELD_EVERY)},
	"hasted": {"title": "Hasted", "color": Color(1.0, 0.95, 0.4),
		"desc": "Moves and attacks %d%% faster" % int(Balance.ELITE_HASTE_ATTACK)},
	"unstoppable": {"title": "Unstoppable", "color": Color(0.85, 0.75, 0.6),
		"desc": "Immune to stuns, roots and slows"},
	"vampiric": {"title": "Vampiric", "color": Color(0.85, 0.2, 0.35),
		"desc": "Heals for %d%% of the damage it deals" % int(Balance.ELITE_VAMPIRIC_PCT)},
	"volatile": {"title": "Volatile", "color": Color(1.0, 0.5, 0.15),
		"desc": "Explodes when it dies - get out of the circle!"},
	"berserker": {"title": "Berserker", "color": Color(1.0, 0.25, 0.2),
		"desc": "Enrages below %d%% health" % int(Balance.ELITE_BERSERK_AT)},
}

static func roll(rng: RandomNumberGenerator) -> String:
	var keys := TRAITS.keys()
	return str(keys[rng.randi_range(0, keys.size() - 1)])

static func title(t: String) -> String:
	return str(TRAITS.get(t, {}).get("title", ""))

static func desc(t: String) -> String:
	return str(TRAITS.get(t, {}).get("desc", ""))

static func color(t: String) -> Color:
	return TRAITS.get(t, {}).get("color", Color.WHITE)

## Does `t` make the enemy ignore this status effect? (StatusContainer asks)
static func resists(t: String, res: Resource) -> bool:
	if t != "unstoppable" or res == null:
		return false
	return bool(res.stun) or bool(res.root) or float(res.stat_modifiers.get("move_speed", 0.0)) < 0.0

## Volatile: warning circle where it died, then a blast. Runs on every machine
## (the circle); only `authority` deals the damage.
static func explode(e: Node3D, authority: bool) -> void:
	var scene := e.get_tree().current_scene
	var at := e.global_position
	var r := Balance.ELITE_VOLATILE_RADIUS
	var col := Color(1.0, 0.45, 0.1)
	BOSS_ABILITIES.telegraph(scene, Vector3(at.x, at.y - e.call("ground_offset") + 0.05, at.z), r,
		Balance.ELITE_VOLATILE_DELAY, col)
	e.get_tree().create_timer(Balance.ELITE_VOLATILE_DELAY).timeout.connect(func():
		if scene == null or not is_instance_valid(scene):
			return
		BOSS_ABILITIES.burst(scene, at, r, col)
		if not authority or not is_instance_valid(e):
			return
		var net := e.get_node_or_null("/root/Net")
		var bodies: Array = net.party_bodies() if net else e.get_tree().get_nodes_in_group("player")
		for b in bodies:
			if not is_instance_valid(b) or not b.is_alive():
				continue
			if Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length() <= r:
				e.deal_melee_hit(b, float(e.contact_damage) * Balance.ELITE_VOLATILE_COEF, "elite_volatile"))

# --- Per-enemy runtime part ---------------------------------------------------------

var trait_id := ""
var enemy: Node3D
var _shield_at := 0.0       # when the next shield comes up
var _shield_up := false
var _berserk := false
var _bubble: MeshInstance3D

const SHIELD_ID := "elite_shield"

func _ready() -> void:
	enemy = get_parent() as Node3D
	_shield_at = _now() + 0.5
	set_process(trait_id == "shielded" or trait_id == "berserker")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _authority() -> bool:
	return enemy != null and not enemy.call("_replica")

func _process(_delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		set_process(false)
		return
	if not _authority():
		return
	match trait_id:
		"shielded":
			_tick_shield()
		"berserker":
			if not _berserk and float(enemy.health) <= float(enemy.max_health) * Balance.ELITE_BERSERK_AT / 100.0:
				_go_berserk()

func _tick_shield() -> void:
	var st: Node = enemy.get_node_or_null("Status")
	if st == null:
		return
	var up: bool = st.absorb_left(SHIELD_ID) > 0
	if _shield_up and not up:
		_shield_up = false   # broken (or cleared when it went home)
		_shield_at = _now() + Balance.ELITE_SHIELD_EVERY
		set_bubble(false)
		_send_fx("elite_shield", {"on": false})
	if not up and _now() >= _shield_at:
		var fx := StatusContainer.make_buff(SHIELD_ID, "Elite Shield", "none", 0.0, 3600.0, 1, color("shielded"))
		fx.stat_modifiers = {}
		fx.description = "Absorbs damage. Comes back %d s after it breaks." % int(Balance.ELITE_SHIELD_EVERY)
		if st.apply(fx, enemy):
			st.set_absorb(SHIELD_ID, maxi(int(round(enemy.max_health * Balance.ELITE_SHIELD_PCT / 100.0)), 1))
			_shield_up = true
			set_bubble(true)
			_send_fx("elite_shield", {"on": true})

func _go_berserk() -> void:
	_berserk = true
	enemy.contact_damage = float(enemy.contact_damage) * (1.0 + Balance.ELITE_BERSERK_DAMAGE / 100.0)
	enemy.attack_cooldown = float(enemy.attack_cooldown) / (1.0 + Balance.ELITE_BERSERK_ATTACK / 100.0)
	BOSS_ABILITIES.apply_enrage_look(enemy)
	var cs := get_node_or_null("/root/CombatSystem")
	if cs:
		cs.float_text(enemy, "Berserk!", color("berserker"), true)
	_send_fx("enrage", {})

func _send_fx(kind: String, extra: Dictionary) -> void:
	var net := get_node_or_null("/root/Net")
	if net and net.is_host():
		net.enemy_fx(enemy, kind, null, extra)

## Pale bubble around the enemy while its shield is up (also on party members' screens).
func set_bubble(on: bool) -> void:
	if on and _bubble == null:
		_bubble = MeshInstance3D.new()
		var s := SphereMesh.new()
		var r := maxf(float(enemy.get("health_bar_height")) * 0.6, 0.7)
		s.radius = r
		s.height = r * 2.0
		_bubble.mesh = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color("shielded"), 0.18)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bubble.material_override = mat
		_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bubble.position.y = r * 0.3
		enemy.add_child(_bubble)
		_bubble.scale = Vector3.ONE * 0.2
		_bubble.create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not on and _bubble != null:
		var b := _bubble
		_bubble = null
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector3.ONE * 1.3, 0.12)
		t.tween_callback(b.queue_free)
