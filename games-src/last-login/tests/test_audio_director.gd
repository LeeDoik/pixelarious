extends GdUnitTestSuite

func test_layers_follow_act() -> void:
	GameState.reset()
	assert_int(AudioDirector.active_layers()).is_equal(1)
	GameState.set_flag("puzzle1_solved")
	assert_int(AudioDirector.active_layers()).is_equal(2)
	GameState.set_flag("puzzle3_solved")
	assert_int(AudioDirector.active_layers()).is_equal(3)
	GameState.set_flag("final_diary_read")
	assert_int(AudioDirector.active_layers()).is_equal(4)
	GameState.set_flag("puzzle5_solved")
	assert_int(AudioDirector.active_layers()).is_equal(5)
	assert_int(AudioDirector.LAYERS.size()).is_equal(5)

func test_recorded_variant_pools_discovered() -> void:
	# 분할된 클릭·키보드 녹음이 임포트되어 랜덤 풀에 잡혀야 한다
	assert_int(AudioDirector.variant_count("click")).is_greater(1)
	assert_int(AudioDirector.variant_count("key")).is_greater(1)
