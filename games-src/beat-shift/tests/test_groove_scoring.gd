extends GdUnitTestSuite

func test_groove_apply_values_and_clamp() -> void:
	assert_float(Groove.apply(60.0, "perfect")).is_equal_approx(64.0, 0.001)
	assert_float(Groove.apply(60.0, "good")).is_equal_approx(62.0, 0.001)
	assert_float(Groove.apply(60.0, "miss")).is_equal_approx(45.0, 0.001)
	assert_float(Groove.apply(60.0, "stray")).is_equal_approx(55.0, 0.001)
	assert_float(Groove.apply(99.0, "perfect")).is_equal_approx(100.0, 0.001)
	assert_float(Groove.apply(10.0, "miss")).is_equal_approx(0.0, 0.001)

func test_groove_dead_boundary_and_recover() -> void:
	assert_bool(Groove.dead(0.0)).is_true()
	assert_bool(Groove.dead(0.1)).is_false()
	assert_float(Groove.recover(45.0)).is_equal_approx(55.0, 0.001)
	assert_float(Groove.recover(95.0)).is_equal_approx(100.0, 0.001)

func test_scoring_hit_multiplies_then_increments() -> void:
	var r := Scoring.hit("perfect", 1)
	assert_int(r.points).is_equal(100)
	assert_int(r.mult).is_equal(2)
	r = Scoring.hit("good", 3)
	assert_int(r.points).is_equal(150)
	assert_int(r.mult).is_equal(4)
	r = Scoring.hit("perfect", 5)
	assert_int(r.points).is_equal(500)
	assert_int(r.mult).is_equal(5)

func test_scoring_fail_resets() -> void:
	var r := Scoring.hit("miss", 4)
	assert_int(r.points).is_equal(0)
	assert_int(r.mult).is_equal(1)
	r = Scoring.hit("stray", 4)
	assert_int(r.mult).is_equal(1)

func test_section_bonus_scales() -> void:
	assert_int(Scoring.section_bonus(0)).is_equal(500)
	assert_int(Scoring.section_bonus(2)).is_equal(1500)

func test_persistence_roundtrip_missing_and_corrupt() -> void:
	var path := "user://test_best.json"
	Persistence.save_best(path, 777)
	assert_int(Persistence.load_best(path)).is_equal(777)
	DirAccess.remove_absolute(path)
	assert_int(Persistence.load_best("user://no_such_file.json")).is_equal(0)
	var f := FileAccess.open("user://corrupt.json", FileAccess.WRITE)
	f.store_string("not json{{")
	f.close()
	assert_int(Persistence.load_best("user://corrupt.json")).is_equal(0)
	DirAccess.remove_absolute("user://corrupt.json")

func test_game_state_run_flow() -> void:
	GameState.start_run()
	assert_int(GameState.score()).is_equal(0)
	assert_float(GameState.groove).is_equal_approx(60.0, 0.001)
	assert_int(GameState.register_hit("perfect")).is_equal(100)   # mult 1→2, groove 64
	assert_int(GameState.register_hit("perfect")).is_equal(200)   # mult 2→3, groove 68
	GameState.register_fail("miss")                               # mult 리셋, groove 53
	assert_int(GameState.mult).is_equal(1)
	assert_float(GameState.groove).is_equal_approx(53.0, 0.001)
	assert_int(GameState.register_section_clear(0)).is_equal(500) # groove 63
	assert_int(GameState.score()).is_equal(800)
	assert_bool(GameState.is_dead()).is_false()

func test_game_state_death() -> void:
	GameState.start_run()
	for i in range(4):
		GameState.register_fail("miss")   # 60 - 4*15 = 0
	assert_bool(GameState.is_dead()).is_true()

func test_tap_action_registered() -> void:
	assert_bool(InputMap.has_action("tap")).is_true()
