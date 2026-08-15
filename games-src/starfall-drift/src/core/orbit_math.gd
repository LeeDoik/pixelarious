class_name OrbitMath
## 궤도·탄도·포획 순수 수학. 화면 y는 아래로 증가, dir=+1은 각도 증가 방향.

static func orbit_pos(center: Vector2, radius: float, angle: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * radius

static func advance_angle(angle: float, angular_vel: float, dir: int, delta: float) -> float:
	return angle + angular_vel * float(dir) * delta

static func launch_velocity(center: Vector2, pos: Vector2, dir: int, speed: float) -> Vector2:
	var radial := (pos - center).normalized()
	return Vector2(-radial.y, radial.x) * float(dir) * speed

static func integrate_flight(pos: Vector2, vel: Vector2, gravity: float, delta: float) -> Array:
	var new_vel := vel + Vector2(0.0, gravity) * delta
	return [pos + new_vel * delta, new_vel]

static func try_capture(pos: Vector2, star_center: Vector2, orbit_radius: float) -> bool:
	return pos.distance_to(star_center) <= orbit_radius

static func entry_dir(center: Vector2, pos: Vector2, vel: Vector2) -> int:
	var radial := pos - center
	return 1 if radial.x * vel.y - radial.y * vel.x >= 0.0 else -1

static func entry_angle(center: Vector2, pos: Vector2) -> float:
	return (pos - center).angle()

static func bounce_x(pos: Vector2, vel: Vector2, min_x: float, max_x: float, damping: float) -> Array:
	var p := pos
	var v := vel
	if p.x < min_x:
		p.x = min_x + (min_x - p.x)
		v.x = absf(v.x) * damping
	elif p.x > max_x:
		p.x = max_x - (p.x - max_x)
		v.x = -absf(v.x) * damping
	return [p, v]

static func max_rise(speed: float, gravity: float) -> float:
	return speed * speed / (2.0 * gravity)
