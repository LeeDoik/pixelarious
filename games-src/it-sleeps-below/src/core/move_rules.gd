class_name MoveRules
## 인접 탭 → 행동 분류. 순수 함수.

const A_BLOCKED := 0
const A_WALK := 1
const A_CLIMB := 2
const A_DIG := 3

static func passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY

static func classify(cells: PackedInt32Array, pos: Vector2i, dir: Vector2i, pick_level: int) -> int:
	var t := pos + dir
	if t.x < 1 or t.x > WorldGen.W - 2 or t.y < 0 or t.y >= WorldGen.DEPTH:
		return A_BLOCKED
	var c := cells[WorldGen.idx(t.x, t.y)]
	if c == WorldGen.T_BORDER:
		return A_BLOCKED
	if passable(c):
		return A_CLIMB if dir.y < 0 else A_WALK
	if not Economy.dig_allowed(pick_level, t.y):
		return A_BLOCKED
	return A_DIG

static func braced(cells: PackedInt32Array, pos: Vector2i) -> bool:
	# 침니 클라이밍 — 좌우 벽, 또는 좌하/우하 모서리를 짚을 수 있으면 버틴다
	# (스펙 §2 "벽을 짚고 오른다" + 구덩이 가장자리 모서리 잡기).
	# 1칸 폭 수직갱은 항상 braced; 구덩이 가장자리도 모서리를 잡아 옆걸음이 안전하다.
	# 잡을 것이 전혀 없는 허공(넓은 공동 한가운데)에서만 낙하한다.
	for off: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
		var n := pos + off
		if n.x < 0 or n.x >= WorldGen.W or n.y >= WorldGen.DEPTH:
			continue
		if not passable(cells[WorldGen.idx(n.x, n.y)]):
			return true
	return false

static func fall_landing(cells: PackedInt32Array, pos: Vector2i) -> Vector2i:
	var p := pos
	while p.y + 1 < WorldGen.DEPTH and passable(cells[WorldGen.idx(p.x, p.y + 1)]):
		p.y += 1
	return p
