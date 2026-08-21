class_name Ingot
extends Sprite2D
## 조수가 던진 잉곳. 비행은 Conductor 시간으로 구동 — 정박에 정확히 모루 도착.

const ARC_HEIGHT := 46.0

var _from: Vector2
var _to: Vector2
var _t0 := 0.0
var _t1 := 1.0
var _state := "fly"
var _vel := Vector2.ZERO
var _life := 0.0

func setup(from: Vector2, to: Vector2, t0: float, t1: float) -> void:
	texture = load("res://assets/img/ingot.png")
	_from = from
	_to = to
	_t0 = t0
	_t1 = t1
	position = from

func note_time() -> float:
	return _t1

func forge(perfect: bool) -> void:
	_state = "done"
	texture = load("res://assets/img/blade.png")
	_vel = Vector2(150.0, -220.0) if perfect else Vector2(120.0, -140.0)
	if perfect:
		scale = Vector2(1.25, 1.25)

func drop() -> void:
	_state = "done"
	_vel = Vector2(40.0, 60.0)
	modulate = Color(0.6, 0.6, 0.7)

func _process(delta: float) -> void:
	match _state:
		"fly":
			var u := clampf((Conductor.song_time() - _t0) / maxf(_t1 - _t0, 0.001), 0.0, 1.0)
			position = Motion.arc_pos(_from, _to, u, ARC_HEIGHT)
		"done":
			_vel += Vector2(0.0, 500.0) * delta
			position += _vel * delta
			rotation += 6.0 * delta
			_life += delta
			if _life > 1.2:
				queue_free()
