extends GdUnitTestSuite

func test_layers_follow_act() -> void:
	GameState.reset()
	assert_int(AudioDirector.active_layers()).is_equal(1)
	GameState.set_flag("puzzle1_solved")
	assert_int(AudioDirector.active_layers()).is_equal(2)
	GameState.set_flag("puzzle3_solved")
	assert_int(AudioDirector.active_layers()).is_equal(3)
