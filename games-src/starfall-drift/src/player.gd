class_name Player
extends Node2D
## 표류자. ORBITING(별 공전) → FLYING(접선 발사·포물선) → 포획 반복. 실패 시 DEAD.

signal died
signal hopped(bonus: int)
signal captured(star: Star)

enum State { ORBITING, FLYING, DEAD }

var state: int = State.ORBITING
var star: Star = null
var last_star: Star = null
var angle := 0.0
var dir := 1
var vel := Vector2.ZERO

var _sprite: Sprite2D
var _trail: CPUParticles2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/img/player.png")
	_trail = CPUParticles2D.new()
	_trail.amount = 12
	_trail.lifetime = 0.4
	_trail.local_coords = false
	# 잔상 트레일: 지나온 자리에 그대로 남아 사라져야 한다 — 기본 중력(980 하방)을 끄지 않으면
	# 파티클이 아래로 쏟아져 뭔가를 흘리는 것처럼 보인다.
	_trail.gravity = Vector2.ZERO
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.0
	_trail.scale_amount_min = 0.5
	_trail.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#FF77A8"))
	ramp.set_color(1, Color(1.0, 0.466, 0.658, 0.0))
	_trail.color_ramp = ramp
	_trail.emitting = true
	add_child(_trail)
	add_child(_sprite)

func attach_to(s: Star, entry_pos: Vector2, entry_vel: Vector2) -> void:
	star = s
	star.occupied = true
	last_star = s
	dir = OrbitMath.entry_dir(s.global_position, entry_pos, entry_vel)
	angle = OrbitMath.entry_angle(s.global_position, entry_pos)
	global_position = OrbitMath.orbit_pos(s.global_position, s.orbit_r, angle)
	state = State.ORBITING
	if s.type == "dwarf":
		GameState.register_dwarf()
	Sfx.play("capture")
	captured.emit(s)

func launch() -> void:
	if state != State.ORBITING or star == null or not is_instance_valid(star):
		return
	var bonus := GameState.register_hop(star.gauge_ratio())
	vel = OrbitMath.launch_velocity(star.global_position, global_position, dir, Tuning.LAUNCH_SPEED)
	star.occupied = false
	star = null
	state = State.FLYING
	Sfx.play("hop")
	if bonus > 0 and GameState.combo >= 3:
		Sfx.play("combo")
	hopped.emit(bonus)

func drop() -> void:
	# 별 붕괴 시: 죽지 않고 공전 관성을 안은 채 낙하로 전환. 아래 별에 잡히면 생존.
	if state != State.ORBITING or star == null:
		return
	if is_instance_valid(star):
		vel = OrbitMath.launch_velocity(star.global_position, global_position, dir, star.ang_vel * star.orbit_r)
		star.occupied = false
	else:
		vel = Vector2.ZERO
	star = null
	last_star = null
	state = State.FLYING
	Sfx.play("warn", -4.0)

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if star and is_instance_valid(star):
		star.occupied = false
		star = null
	_sprite.visible = false
	_trail.emitting = false
	Sfx.play("death")
	died.emit()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	match state:
		State.ORBITING:
			if star == null or not is_instance_valid(star) or not star.alive:
				return
			angle = OrbitMath.advance_angle(angle, star.ang_vel, dir, delta)
			global_position = OrbitMath.orbit_pos(star.global_position, star.orbit_r, angle)
			_sprite.rotation = angle + (PI / 2.0 if dir == 1 else -PI / 2.0)
		State.FLYING:
			var r := OrbitMath.integrate_flight(global_position, vel, Tuning.GRAVITY, delta)
			var b := OrbitMath.bounce_x(r[0], r[1], Tuning.WALL_MIN_X, Tuning.WALL_MAX_X, Tuning.WALL_DAMPING)
			global_position = b[0]
			vel = b[1]
			_sprite.rotation = vel.angle() + PI / 2.0
			if last_star != null and (not is_instance_valid(last_star) or global_position.distance_to(last_star.global_position) > last_star.orbit_r + 4.0):
				last_star = null
