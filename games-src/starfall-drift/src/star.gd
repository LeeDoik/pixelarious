class_name Star
extends Node2D
## 별 하나. 잡히면 붕괴 게이지가 차고, 다 차면 collapsed를 emit하고 소멸.

signal collapsed(star: Star)

var type: String = "standard"
var orbit_r: float = 28.0
var ang_vel: float = 2.4
var collapse_time: float = 3.5
var gauge: float = 0.0
var occupied := false
var alive := true

var _body: Sprite2D
var _cracks: Sprite2D
var _debris: CPUParticles2D
var _warned := false

func _ready() -> void:
	_body = Sprite2D.new()
	_cracks = Sprite2D.new()
	_cracks.modulate.a = 0.0
	_debris = CPUParticles2D.new()
	_debris.emitting = false
	_debris.amount = 8
	_debris.lifetime = 0.6
	_debris.spread = 180.0
	_debris.initial_velocity_min = 20.0
	_debris.initial_velocity_max = 60.0
	_debris.gravity = Vector2(0, 120)
	_debris.scale_amount_min = 1.0
	_debris.scale_amount_max = 2.0
	_debris.color = Color("#FFF1E8")
	add_child(_body)
	add_child(_cracks)
	add_child(_debris)

func setup(t: String, collapse_mult: float) -> void:
	type = t
	var d: Dictionary = Tuning.STAR_TYPES[t]
	orbit_r = d.orbit_r
	ang_vel = d.ang_vel
	collapse_time = d.collapse / collapse_mult
	_body.texture = load("res://assets/img/%s.png" % d.sprite)
	# 균열은 별 종류마다 그 별 크기에 맞춰 뽑아 둔 원본 해상도 텍스처를 그대로 쓴다(확대 금지).
	_cracks.texture = load("res://assets/img/%s.png" % d.cracks)

func gauge_ratio() -> float:
	return gauge / collapse_time

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not alive or not occupied or GameState.phase != GameState.Phase.PLAYING:
		return
	# 도입부 유예: 점수가 Tuning.COLLAPSE_GRACE_SCORE에 닿기 전까지는 게이지가 차지 않는다.
	# 게이지가 0이므로 균열·흔들림·파편·경고음도 함께 꺼진 상태로 남는다.
	if not GameState.collapse_active():
		return
	gauge += delta
	var r := gauge_ratio()
	_cracks.modulate.a = clampf((r - 0.25) / 0.75, 0.0, 1.0)
	var shake := 2.5 * maxf(r - 0.4, 0.0)
	_body.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	_cracks.position = _body.position
	if r >= 0.6:
		_debris.emitting = true
		if not _warned:
			_warned = true
			Sfx.play("warn")
	if gauge >= collapse_time:
		_collapse()

func _collapse() -> void:
	alive = false
	collapsed.emit(self)
	_body.visible = false
	_cracks.visible = false
	_debris.one_shot = true
	_debris.amount = 24
	_debris.emitting = true
	var t := get_tree().create_timer(0.8)
	t.timeout.connect(queue_free)
