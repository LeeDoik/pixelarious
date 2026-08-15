extends GdUnitTestSuite

func test_swift_hop_increments_combo_and_pays() -> void:
	var r := Scoring.hop_result(0.30, 1)
	assert_int(r.combo).is_equal(2)
	assert_int(r.bonus).is_equal(50)

func test_slow_hop_resets_combo_no_bonus() -> void:
	var r := Scoring.hop_result(0.31, 4)
	assert_int(r.combo).is_equal(1)
	assert_int(r.bonus).is_equal(0)

func test_combo_caps_at_max() -> void:
	var r := Scoring.hop_result(0.1, 5)
	assert_int(r.combo).is_equal(5)
	assert_int(r.bonus).is_equal(125)

func test_height_score_floors_and_clamps() -> void:
	assert_int(Scoring.height_score(1234.0)).is_equal(123)
	assert_int(Scoring.height_score(-5.0)).is_equal(0)

func test_persistence_roundtrip() -> void:
	var path := "user://test_best.json"
	Persistence.save_best(path, 777)
	assert_int(Persistence.load_best(path)).is_equal(777)
	DirAccess.remove_absolute(path)

func test_persistence_missing_and_corrupt() -> void:
	assert_int(Persistence.load_best("user://no_such_file.json")).is_equal(0)
	var f := FileAccess.open("user://corrupt.json", FileAccess.WRITE)
	f.store_string("not json{{")
	f.close()
	assert_int(Persistence.load_best("user://corrupt.json")).is_equal(0)
	DirAccess.remove_absolute("user://corrupt.json")

func test_game_state_run_flow() -> void:
	GameState.start_run()
	assert_int(GameState.score()).is_equal(0)
	GameState.update_rise(500.0)
	var bonus := GameState.register_hop(0.2)   # combo 1→2, +50
	assert_int(bonus).is_equal(50)
	GameState.register_dwarf()                 # +50
	assert_int(GameState.score()).is_equal(150)  # 50m + 50 + 50
	GameState.update_rise(400.0)               # 최대치 유지
	assert_int(GameState.score()).is_equal(150)

func test_drift_action_registered() -> void:
	assert_bool(InputMap.has_action("drift")).is_true()
