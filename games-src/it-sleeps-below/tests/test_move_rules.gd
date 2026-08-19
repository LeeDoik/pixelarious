extends GdUnitTestSuite

func _world() -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(WorldGen.W * WorldGen.DEPTH)
	cells.fill(WorldGen.T_DIRT)
	for y in range(WorldGen.DEPTH):
		cells[WorldGen.idx(0, y)] = WorldGen.T_BORDER
		cells[WorldGen.idx(WorldGen.W - 1, y)] = WorldGen.T_BORDER
	# (5,10)~(5,12) 수직 통로
	for y in range(10, 13):
		cells[WorldGen.idx(5, y)] = WorldGen.T_EMPTY
	return cells

func test_walk_into_empty() -> void:
	var c := _world()
	c[WorldGen.idx(6, 10)] = WorldGen.T_EMPTY
	assert_int(MoveRules.classify(c, Vector2i(5, 10), Vector2i(1, 0), 1)).is_equal(MoveRules.A_WALK)

func test_climb_up_empty() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(5, 12), Vector2i(0, -1), 1)).is_equal(MoveRules.A_CLIMB)

func test_dig_solid_with_gate() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(5, 10), Vector2i(1, 0), 1)).is_equal(MoveRules.A_DIG)
	# 암반(row 80)은 곡괭이 Lv1로 못 판다
	var c := _world()
	c[WorldGen.idx(5, 80)] = WorldGen.T_EMPTY
	assert_int(MoveRules.classify(c, Vector2i(5, 80), Vector2i(1, 0), 1)).is_equal(MoveRules.A_BLOCKED)
	assert_int(MoveRules.classify(c, Vector2i(5, 80), Vector2i(1, 0), 2)).is_equal(MoveRules.A_DIG)

func test_border_blocked() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(1, 10), Vector2i(-1, 0), 4)).is_equal(MoveRules.A_BLOCKED)

func test_fall_landing() -> void:
	var c := _world()
	for y in range(10, 20):
		c[WorldGen.idx(7, y)] = WorldGen.T_EMPTY
	assert_that(MoveRules.fall_landing(c, Vector2i(7, 10))).is_equal(Vector2i(7, 19))
	assert_that(MoveRules.fall_landing(_world(), Vector2i(5, 12))).is_equal(Vector2i(5, 12))

func test_fall_only_when_moving_down() -> void:
	var c := _world()
	# 5×10 짜리 넓은 공동 — 붙잡을 벽이 전혀 없는 한가운데를 만든다
	for x in range(3, 8):
		for y in range(20, 30):
			c[WorldGen.idx(x, y)] = WorldGen.T_EMPTY

	# 오르거나 옆으로 갔으면 허공 한가운데라도 그 자리에 붙는다 (벽타기 무조건 자유)
	assert_that(MoveRules.fall_from(c, Vector2i(5, 25), false)).is_equal(Vector2i(5, 25))
	# 스스로 아래로 내려갔을 때만 바닥까지 이어진다
	assert_that(MoveRules.fall_from(c, Vector2i(5, 25), true)).is_equal(Vector2i(5, 29))

func test_fall_from_solid_ground_is_noop() -> void:
	# 발밑이 단단하면 아래로 움직였어도 제자리
	assert_that(MoveRules.fall_from(_world(), Vector2i(5, 12), true)).is_equal(Vector2i(5, 12))

func test_tap_dir_accepts_only_adjacent_tiles() -> void:
	var p := Vector2i(8, 20)
	# 타일 중앙을 눌렀을 때 — 위/아래/좌/우
	assert_vector(MoveRules.tap_dir(Vector2(8 * 16 + 8, 19 * 16 + 8), p)).is_equal(Vector2i(0, -1))
	assert_vector(MoveRules.tap_dir(Vector2(8 * 16 + 8, 21 * 16 + 8), p)).is_equal(Vector2i(0, 1))
	assert_vector(MoveRules.tap_dir(Vector2(7 * 16 + 8, 20 * 16 + 8), p)).is_equal(Vector2i(-1, 0))
	assert_vector(MoveRules.tap_dir(Vector2(9 * 16 + 8, 20 * 16 + 8), p)).is_equal(Vector2i(1, 0))
	# 제 칸, 대각선, 두 칸 밖은 무시 — 비인접 탭은 아무 일도 일으키지 않는다 (스펙 §11)
	assert_vector(MoveRules.tap_dir(Vector2(8 * 16 + 8, 20 * 16 + 8), p)).is_equal(Vector2i.ZERO)
	assert_vector(MoveRules.tap_dir(Vector2(9 * 16 + 8, 21 * 16 + 8), p)).is_equal(Vector2i.ZERO)
	assert_vector(MoveRules.tap_dir(Vector2(8 * 16 + 8, 22 * 16 + 8), p)).is_equal(Vector2i.ZERO)

func test_tap_dir_handles_tile_edges_and_negative_coords() -> void:
	var p := Vector2i(8, 20)
	# 타일 경계 바로 안쪽도 그 타일이다
	assert_vector(MoveRules.tap_dir(Vector2(9 * 16, 20 * 16), p)).is_equal(Vector2i(1, 0))
	assert_vector(MoveRules.tap_dir(Vector2(9 * 16 + 15, 20 * 16 + 15), p)).is_equal(Vector2i(1, 0))
	# 두 칸 밖은 경계 픽셀이라도 무시
	assert_vector(MoveRules.tap_dir(Vector2(10 * 16, 20 * 16), p)).is_equal(Vector2i.ZERO)
	# 화면 위쪽(음수 y)은 int() 절삭이면 0행으로 접혀 오판한다 — floori라 -1행으로 간다
	assert_vector(MoveRules.tap_dir(Vector2(0 * 16 + 8, -8), Vector2i(0, 0))).is_equal(Vector2i(0, -1))
