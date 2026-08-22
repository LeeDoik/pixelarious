class_name Spawner
## 고도 기반 절차 생성. 순수 static — rng는 호출자가 주입(테스트 결정론).

static func params_for_height(h: float) -> Dictionary:
	var t := clampf(h / Tuning.RAMP_H, 0.0, 1.0)
	var asteroid_p := 0.0
	if h >= Tuning.ASTEROID_START_H:
		var ta := clampf((h - Tuning.ASTEROID_START_H) / Tuning.ASTEROID_RAMP_H, 0.0, 1.0)
		asteroid_p = Tuning.ASTEROID_P_BASE + Tuning.ASTEROID_P_RANGE * ta
	return {
		"gap": Tuning.GAP_BASE + Tuning.GAP_RANGE * t,
		"dwarf_p": Tuning.DWARF_P_BASE + Tuning.DWARF_P_RANGE * t,
		"giant_p": Tuning.GIANT_P_BASE + Tuning.GIANT_P_RANGE * t,
		"collapse_mult": 1.0 + Tuning.COLLAPSE_MULT_RANGE * clampf(h / Tuning.COLLAPSE_RAMP_H, 0.0, 1.0),
		"collapses": h >= Tuning.COLLAPSE_GRACE_H,
		"asteroid_p": asteroid_p,
	}

static func pick_type(p: Dictionary, roll: float) -> String:
	if roll < p.dwarf_p:
		return "dwarf"
	if roll < p.dwarf_p + p.giant_p:
		return "giant"
	return "standard"

static func reachable(from_pos: Vector2, from_r: float, to_pos: Vector2, to_r: float) -> bool:
	var rise := from_pos.y - to_pos.y
	var budget := OrbitMath.max_rise(Tuning.LAUNCH_SPEED, Tuning.GRAVITY) + from_r + to_r - Tuning.SPAWN_SAFETY_MARGIN
	return rise <= budget and absf(to_pos.x - from_pos.x) <= Tuning.SPAWN_MAX_DX

static func next_star(prev: Dictionary, h: float, rng: RandomNumberGenerator) -> Dictionary:
	var p := params_for_height(h)
	var type := pick_type(p, rng.randf())
	var to_r: float = Tuning.STAR_TYPES[type].orbit_r
	var prev_r: float = Tuning.STAR_TYPES[prev.type].orbit_r
	var prev_pos: Vector2 = prev.pos
	for _i in range(Tuning.SPAWN_RETRY_COUNT):
		var gap: float = p.gap * rng.randf_range(Tuning.SPAWN_GAP_JITTER_MIN, Tuning.SPAWN_GAP_JITTER_MAX)
		var x := clampf(prev_pos.x + rng.randf_range(-Tuning.SPAWN_DRIFT_X, Tuning.SPAWN_DRIFT_X), Tuning.WALL_MIN_X + to_r + Tuning.SPAWN_WALL_MARGIN, Tuning.WALL_MAX_X - to_r - Tuning.SPAWN_WALL_MARGIN)
		var pos := Vector2(x, prev_pos.y - gap)
		if reachable(prev_pos, prev_r, pos, to_r):
			return {"type": type, "pos": pos}
	return {"type": type, "pos": Vector2(clampf(prev_pos.x, Tuning.WALL_MIN_X + to_r + Tuning.SPAWN_WALL_MARGIN, Tuning.WALL_MAX_X - to_r - Tuning.SPAWN_WALL_MARGIN), prev_pos.y - Tuning.GAP_BASE)}
