class_name MoveRules
## 인접 탭 → 행동 분류. 순수 함수.

const A_BLOCKED := 0
const A_WALK := 1
const A_CLIMB := 2
const A_DIG := 3

static func passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY

# 타일 단위. 화면 폭 270px에 타일 16px이라 실기에서 한 칸은 25~30px — 손가락 패드보다 작다.
# 2.3이면 8방향 이웃과 두 칸 빗맞음까지 받고, 세 칸부터는 확실히 무시한다.
const TAP_REACH := 2.3

static func tap_dir(world_pos: Vector2, ppos: Vector2i) -> Vector2i:
	## 화면 좌표 탭 → 인접 4방향 중 하나. 제 칸과 먼 곳은 Vector2i.ZERO (무시).
	##
	## 정확히 인접한 칸이면 그 방향 그대로. 그보다 조금 빗나갔거나 대각이면 — 모바일에서
	## 16px 타일을 정확히 맞히기 어렵다 — TAP_REACH 안에 한해 지배적인 축으로 스냅한다.
	## 어느 경우든 실제 행동은 인접 한 칸뿐이라 "비인접 탭 무시" 규칙(스펙 §11)은 지킨다.
	## floori를 쓴다 — int()는 0으로 절삭해서 음수 좌표가 한 칸 밀린다.
	var tile := Vector2i(floori(world_pos.x / float(Tuning.TILE_PX)), floori(world_pos.y / float(Tuning.TILE_PX)))
	var d := tile - ppos
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) + absi(d.y) == 1:
		return d
	if Vector2(d).length() > TAP_REACH:
		return Vector2i.ZERO
	# 대각·근접 빗맞음 → 더 크게 벗어난 축으로. 완전한 대각은 세로 우선(하강이 이 게임의 축이다)
	if absi(d.x) > absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

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
