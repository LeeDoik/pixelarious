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
