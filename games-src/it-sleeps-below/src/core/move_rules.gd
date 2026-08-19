class_name MoveRules
## 인접 탭 → 행동 분류. 순수 함수.

const A_BLOCKED := 0
const A_WALK := 1
const A_CLIMB := 2
const A_DIG := 3

static func passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY

static func tap_dir(world_pos: Vector2, ppos: Vector2i) -> Vector2i:
	## 화면 좌표 탭 → 인접 4방향 중 하나. 비인접·같은 칸은 Vector2i.ZERO (무시).
	## floori를 쓴다 — int()는 0으로 절삭해서 음수 좌표가 한 칸 밀린다.
	var tile := Vector2i(floori(world_pos.x / float(Tuning.TILE_PX)), floori(world_pos.y / float(Tuning.TILE_PX)))
	var d := tile - ppos
	if absi(d.x) + absi(d.y) == 1:
		return d
	return Vector2i.ZERO

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

static func fall_from(cells: PackedInt32Array, pos: Vector2i, moved_down: bool) -> Vector2i:
	# 벽타기는 무조건 자유 — 오르거나 옆으로 갔으면 잡을 것이 없어도 그 자리에 붙는다.
	# 낙하는 스스로 아래로 내려갔을 때만 이어진다 (하강이 빠른 비대칭은 유지).
	if not moved_down:
		return pos
	return fall_landing(cells, pos)

static func fall_landing(cells: PackedInt32Array, pos: Vector2i) -> Vector2i:
	var p := pos
	while p.y + 1 < WorldGen.DEPTH and passable(cells[WorldGen.idx(p.x, p.y + 1)]):
		p.y += 1
	return p
