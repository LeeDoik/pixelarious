class_name LurkerLogic
## '그것'의 규칙 전부 — 순수 함수. 빛 안 정지 / 어둠 접근 / 소리 반응 / 파도형 디렉터.

const M_SILENCE := 0
const M_HUNT := 1
const M_RETREAT := 2

static func cycle_lengths(depth_m: int) -> Dictionary:
	var base: Dictionary = Tuning.DIRECTOR_BASE
	var over := maxf(0.0, float(depth_m - Tuning.LURKER_MIN_DEPTH))
	var silence: float = maxf(Tuning.DIRECTOR_SILENCE_MIN, base.silence - over * Tuning.DIRECTOR_DEPTH_SCALE)
	return {"hunt": base.hunt, "retreat": base.retreat, "silence": silence}

static func director_step(d: Dictionary, dt: float, depth_m: int) -> Dictionary:
	var out := {"mode": d.mode, "t": d.t - dt}
	if out.t > 0.0:
		return out
	var lens := cycle_lengths(depth_m)
	match int(d.mode):
		M_SILENCE:
			return {"mode": M_HUNT, "t": lens.hunt}
		M_HUNT:
			return {"mode": M_RETREAT, "t": lens.retreat}
		_:
			return {"mode": M_SILENCE, "t": lens.silence}

static func is_frozen(lurker: Vector2i, player: Vector2i, radius: float, lamp_on: bool) -> bool:
	if not lamp_on:
		return false
	return Vector2(lurker).distance_to(Vector2(player)) <= radius

static func hear(state: Dictionary, noise_pos: Vector2i, noise_level: float) -> Dictionary:
	var out := state.duplicate()
	if noise_level >= Tuning.NOISE_ALERT_THRESHOLD:
		out.target = noise_pos
		out.alert = true
	return out

static func pick_wander(from: Vector2i, candidates: Array, is_open: Callable) -> Vector2i:
	## 갈 수 있는 후보만 고른다. 벽이나 맵 밖을 목표로 잡으면 경로 탐색이 매번 전수 실패하고
	## 러커는 제자리에 굳는다 (실측: 파낸 공간 전체를 걸음마다 훑는다).
	for c: Vector2i in candidates:
		if is_open.call(c):
			return c
	return from

static func arrived_wander(state: Dictionary, rng_pick: Vector2i) -> Dictionary:
	var out := state.duplicate()
	out.target = rng_pick
	out.alert = false
	return out

const PATH_MAX_NODES := 800

static func next_step(lurker: Vector2i, target: Vector2i, is_open: Callable) -> Vector2i:
	if lurker == target:
		return lurker
	# BFS — 파낸 공간만 통과. 목표가 닿지 않으면 전수 탐색이 되므로 확장 수를 막아둔다
	# (러커는 플레이어 근처에 스폰하니 800칸이면 정상 경로는 다 잡힌다).
	var q: Array[Vector2i] = [lurker]
	var prev := {lurker: lurker}
	var expanded := 0
	while not q.is_empty():
		expanded += 1
		if expanded > PATH_MAX_NODES:
			return lurker
		var cur: Vector2i = q.pop_front()
		if cur == target:
			# 역추적으로 첫걸음 복원
			while prev[cur] != lurker:
				cur = prev[cur]
			return cur
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if prev.has(nxt) or not is_open.call(nxt):
				continue
			prev[nxt] = cur
			q.append(nxt)
	return lurker
