extends OmniLight3D

# Firelight flicker for torches, candles and braziers: small random changes in
# brightness (and a hint of range), each light out of step with the others.

@export var amount := 0.22
@export var speed := 9.0

var _base_energy := 1.0
var _base_range := 1.0
var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	_base_energy = light_energy
	_base_range = omni_range
	_seed = randf() * 100.0

var _acc := 0.0

func _process(delta: float) -> void:
	# 20 updates a second is plenty for a flicker (and far lights fade out anyway).
	_acc += delta
	if _acc < 0.05:
		return
	delta = _acc
	_acc = 0.0
	_t += delta * speed
	var n := sin(_t + _seed) * 0.5 + sin(_t * 2.3 + _seed * 1.7) * 0.3 + sin(_t * 5.1 + _seed * 0.4) * 0.2
	light_energy = _base_energy * (1.0 + n * amount)
	omni_range = _base_range * (1.0 + n * amount * 0.15)
