extends GdUnitTestSuite

func test_setup_reads_tuning() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	assert_float(s.orbit_r).is_equal_approx(16.0, 0.001)
	assert_float(s.ang_vel).is_equal_approx(3.6, 0.001)
	assert_float(s.collapse_time).is_equal_approx(2.0, 0.001)

func test_collapse_mult_shortens_life() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.5)
	assert_float(s.collapse_time).is_equal_approx(3.5 / 1.5, 0.001)

func test_grace_star_never_collapses() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0, false)
	assert_bool(is_inf(s.collapse_time)).is_true()
	GameState.phase = GameState.Phase.PLAYING
	s.occupied = true
	var got: Array = []
	s.collapsed.connect(func(star): got.append(star))
	s.tick(60.0)
	assert_int(got.size()).is_equal(0)
	assert_bool(s.alive).is_true()
	assert_float(s.gauge_ratio()).is_equal_approx(0.0, 0.001)

func test_gauge_advances_only_when_occupied_playing() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.0)
	GameState.phase = GameState.Phase.PLAYING
	s.occupied = false
	s.tick(1.0)
	assert_float(s.gauge).is_equal_approx(0.0, 0.001)
	s.occupied = true
	s.tick(1.0)
	assert_float(s.gauge_ratio()).is_equal_approx(1.0 / 3.5, 0.001)

func test_full_gauge_emits_collapsed() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	GameState.phase = GameState.Phase.PLAYING
	s.occupied = true
	var got: Array = []
	s.collapsed.connect(func(star): got.append(star))
	s.tick(2.5)
	assert_int(got.size()).is_equal(1)
	assert_bool(s.alive).is_false()
