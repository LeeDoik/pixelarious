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

static func fall_landing(cells: PackedInt32Array, pos: Vector2i) -> Vector2i:
	var p := pos
	while p.y + 1 < WorldGen.DEPTH and passable(cells[WorldGen.idx(p.x, p.y + 1)]):
		p.y += 1
	return p
