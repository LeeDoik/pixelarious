extends GdUnitTestSuite

func _dug_world() -> PackedInt32Array:
	# 실제 생성 월드에 "플레이어가 판 길"을 흉내: 중앙 col 8을 지표까지 수직 개통
	var g: Dictionary = WorldGen.generate(77, {"journals_found": [], "relic": {}})
	var cells: PackedInt32Array = g.cells
	for y in range(0, 400):
		cells[WorldGen.idx(8, y)] = WorldGen.T_EMPTY
	return cells

func test_reachable_on_open_shaft() -> void:
	assert_bool(Finale.reachable(_dug_world())).is_true()

func test_unreachable_when_sealed() -> void:
	var cells := _dug_world()
	for x in range(1, WorldGen.W - 1):
		cells[WorldGen.idx(x, 200)] = WorldGen.T_FLESH
	assert_bool(Finale.reachable(cells)).is_false()

func test_twist_always_reachable_and_applies_ops() -> void:
	for seed_v in [1, 22, 333]:
		var out: Dictionary = Finale.twist(_dug_world(), seed_v)
		assert_bool(Finale.reachable(out.cells)).is_true()
		assert_int(out.blocked.size() + out.ramps.size()).is_greater(0)
		assert_int(out.blocked.size()).is_less_equal(Tuning.FINALE_BLOCKS)
