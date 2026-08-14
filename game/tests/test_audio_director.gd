extends GdUnitTestSuite

func test_layers_follow_act() -> void:
	GameState.reset()
	assert_int(AudioDirector.active_layers()).is_equal(1)
	GameState.set_flag("puzzle1_solved")
	assert_int(AudioDirector.active_layers()).is_equal(2)
	GameState.set_flag("puzzle3_solved")
	assert_int(AudioDirector.active_layers()).is_equal(3)

func test_click_variants_discovered() -> void:
	# 분할된 클릭 녹음이 임포트되어 랜덤 풀에 잡혀야 한다
	assert_int(AudioDirector.click_variant_count()).is_greater(1)
