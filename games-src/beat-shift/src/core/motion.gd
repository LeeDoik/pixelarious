class_name Motion
## 장면 연출용 이동 수학.

static func arc_pos(from: Vector2, to: Vector2, u: float, height: float) -> Vector2:
	return from.lerp(to, u) + Vector2(0.0, -height * 4.0 * u * (1.0 - u))
