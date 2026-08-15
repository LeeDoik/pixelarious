extends GdUnitTestSuite

func _gen(seed_v: int) -> Dictionary:
	return WorldGen.generate(seed_v, {"journals_found": [], "relic": {}})

func test_same_seed_same_world() -> void:
	assert_that(_gen(42).cells).is_equal(_gen(42).cells)

func test_different_seed_differs() -> void:
	assert_bool(_gen(1).cells == _gen(2).cells).is_false()

func test_borders_and_surface() -> void:
	var cells: PackedInt32Array = _gen(7).cells
	for y in range(WorldGen.DEPTH):
		assert_int(cells[WorldGen.idx(0, y)]).is_equal(WorldGen.T_BORDER)
		assert_int(cells[WorldGen.idx(WorldGen.W - 1, y)]).is_equal(WorldGen.T_BORDER)
	for x in range(1, WorldGen.W - 1):
		assert_int(cells[WorldGen.idx(x, 0)]).is_equal(WorldGen.T_EMPTY)

func test_strata_of() -> void:
	assert_int(WorldGen.strata_of(10)).is_equal(0)
	assert_int(WorldGen.strata_of(80)).is_equal(1)
	assert_int(WorldGen.strata_of(200)).is_equal(2)
	assert_int(WorldGen.strata_of(300)).is_equal(3)
	assert_int(WorldGen.strata_of(400)).is_equal(4)

func test_strata_base_tiles() -> void:
	var cells: PackedInt32Array = _gen(7).cells
	var fam := {0: WorldGen.T_DIRT, 1: WorldGen.T_ROCK, 2: WorldGen.T_DEEP, 3: WorldGen.T_FLESH}
	for row in [20, 80, 180, 320]:
		var base_count := 0
		for x in range(1, WorldGen.W - 1):
			var c: int = cells[WorldGen.idx(x, row)]
			if c == fam[WorldGen.strata_of(row)]:
				base_count += 1
		assert_int(base_count).is_greater(5)  # 행의 과반은 지층 기본 타일

func test_ore_depth_gating() -> void:
	var cells: PackedInt32Array = _gen(11).cells
	for y in range(1, 40):
		for x in range(1, WorldGen.W - 1):
			var c: int = cells[WorldGen.idx(x, y)]
			if c >= WorldGen.ORE_BASE:
				assert_int(c - WorldGen.ORE_BASE).is_less_equal(1)  # 표토엔 석탄(0)/구리(1)만

func test_heart_chamber() -> void:
	var cells: PackedInt32Array = _gen(3).cells
	var found_heart := false
	for x in range(1, WorldGen.W - 1):
		if cells[WorldGen.idx(x, 400)] == WorldGen.T_HEART:
			found_heart = true
	assert_bool(found_heart).is_true()

func test_journal_spots_follow_series_order() -> void:
	var g := _gen(5)
	assert_int(g.journal_spots.size()).is_greater(0)
	var first: Dictionary = g.journal_spots[0]
	assert_str(first.id).is_equal(Lore.series()[0].id)
	# 이미 주운 일지는 배치되지 않는다
	var g2: Dictionary = WorldGen.generate(5, {"journals_found": [first.id], "relic": {}})
	for s in g2.journal_spots:
		assert_str(s.id).is_not_equal(first.id)

func test_relic_placement() -> void:
	var g: Dictionary = WorldGen.generate(9, {"journals_found": [], "relic": {"row": 150, "items": [2, 2, 3]}})
	assert_bool(g.relic_spot.has("x")).is_true()
	assert_int(abs(int(g.relic_spot.y) - 150)).is_less_equal(Tuning.RELIC_ROW_JITTER)
