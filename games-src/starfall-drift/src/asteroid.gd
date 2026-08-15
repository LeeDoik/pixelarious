class_name Asteroid
extends Node2D
## 좌우로 흐르며 사인 진동하는 즉사 장애물.

var _speed := 60.0
var _dir := 1.0
var _base_y := 0.0
var _phase := 0.0
var _t := 0.0

func _ready() -> void:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/img/asteroid.png")
	add_child(sp)

func setup(y: float, rng: RandomNumberGenerator) -> void:
	_base_y = y
	_speed = rng.randf_range(Tuning.ASTEROID_SPEED_MIN, Tuning.ASTEROID_SPEED_MAX)
	_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_phase = rng.randf_range(0.0, TAU)
	global_position = Vector2(Tuning.WALL_MIN_X if _dir > 0.0 else Tuning.WALL_MAX_X, y)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	_t += delta
	global_position.x += _speed * _dir * delta
	global_position.y = _base_y + sin(_t * Tuning.ASTEROID_SINE_FREQ + _phase) * Tuning.ASTEROID_SINE_AMP
	rotation += delta * _dir * Tuning.ASTEROID_SPIN
	if global_position.x < Tuning.WALL_MIN_X - Tuning.ASTEROID_EDGE_MARGIN or global_position.x > Tuning.WALL_MAX_X + Tuning.ASTEROID_EDGE_MARGIN:
		_dir *= -1.0
