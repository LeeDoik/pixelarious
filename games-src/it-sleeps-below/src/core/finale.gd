class_name Finale
## 피날레 — "네가 판 길"을 산이 뒤튼다. 뒤튼 뒤에도 반드시 오를 수 있어야 한다 (스펙 §9).

static func heart_pos() -> Vector2i:
	return Vector2i(Tuning.HEART_X, WorldGen.DEPTH - 2)

static func _passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY or c == WorldGen.T_HEART

static func reachable(cells: PackedInt32Array) -> bool:
	var q: Array[Vector2i] = [heart_pos()]
	var seen := {heart_pos(): true}
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur.y == 0:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= WorldGen.W or n.y < 0 or n.y >= WorldGen.DEPTH:
				continue
			if seen.has(n) or not _passable(cells[WorldGen.idx(n.x, n.y)]):
				continue
			seen[n] = true
			q.append(n)
	return false

static func twist(cells: PackedInt32Array, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := PackedInt32Array(cells)
	var blocked: Array[Vector2i] = []
	var ramps: Array[Vector2i] = []

	# ② 긴 수직갱 옆 붕괴 경사 — 오를 수 없는 갱을 나눠준다
	var run := 0
	for x in range(1, WorldGen.W - 1):
		run = 0
		for y in range(1, Tuning.CHAMBER_TOP):
			if out[WorldGen.idx(x, y)] == WorldGen.T_EMPTY:
				run += 1
				if run >= Tuning.FINALE_SHAFT_LIMIT:
					var side := 1 if x < WorldGen.W - 2 else -1
					var p := Vector2i(x + side, y - int(Tuning.FINALE_SHAFT_LIMIT / 2.0))
					if out[WorldGen.idx(p.x, p.y)] != WorldGen.T_BORDER:
						out[WorldGen.idx(p.x, p.y)] = WorldGen.T_EMPTY
						ramps.append(p)
					run = 0
			else:
				run = 0

	# ① 통로 봉쇄 — 우회 강제. 봉쇄마다 도달 가능성 재검증, 깨지면 롤백
	var candidates: Array[Vector2i] = []
	for y in range(Tuning.STRATA_BOUNDS[0], Tuning.CHAMBER_TOP):
		for x in range(1, WorldGen.W - 1):
			if out[WorldGen.idx(x, y)] == WorldGen.T_EMPTY:
				candidates.append(Vector2i(x, y))
	# 수동 Fisher-Yates (전역 shuffle은 시드 재현성이 없다)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	for p in candidates:
		if blocked.size() >= Tuning.FINALE_BLOCKS:
			break
		var prev := out[WorldGen.idx(p.x, p.y)]
		out[WorldGen.idx(p.x, p.y)] = WorldGen.T_FLESH
		if reachable(out):
			blocked.append(p)
		else:
			out[WorldGen.idx(p.x, p.y)] = prev

	return {"cells": out, "blocked": blocked, "ramps": ramps}
