extends GdUnitTestSuite

func test_params_at_ground() -> void:
	var p := Spawner.params_for_height(0.0)
	assert_float(p.gap).is_equal_approx(90.0, 0.001)
	assert_float(p.dwarf_p).is_equal_approx(0.10, 0.001)
	assert_float(p.giant_p).is_equal_approx(0.25, 0.001)
	assert_float(p.collapse_mult).is_equal_approx(1.0, 0.001)
	assert_float(p.asteroid_p).is_equal_approx(0.0, 0.001)
	assert_bool(p.collapses).is_false()

func test_stars_do_not_collapse_below_grace_height() -> void:
	assert_bool(Spawner.params_for_height(0.0).collapses).is_false()
	assert_bool(Spawner.params_for_height(4999.0).collapses).is_false()
	assert_bool(Spawner.params_for_height(5000.0).collapses).is_true()
	assert_bool(Spawner.params_for_height(20000.0).collapses).is_true()

func test_params_at_ramp_max_and_clamped_beyond() -> void:
	var p := Spawner.params_for_height(10000.0)
	assert_float(p.gap).is_equal_approx(140.0, 0.001)
	assert_float(p.dwarf_p).is_equal_approx(0.45, 0.001)
	assert_float(p.giant_p).is_equal_approx(0.10, 0.001)
	var p2 := Spawner.params_for_height(99999.0)
	assert_float(p2.gap).is_equal_approx(140.0, 0.001)
	assert_float(p2.collapse_mult).is_equal_approx(1.5, 0.001)

func test_asteroid_prob_starts_at_300m() -> void:
	assert_float(Spawner.params_for_height(2999.0).asteroid_p).is_equal_approx(0.0, 0.001)
	assert_float(Spawner.params_for_height(3000.0).asteroid_p).is_equal_approx(0.15, 0.001)
	assert_float(Spawner.params_for_height(15000.0).asteroid_p).is_equal_approx(0.40, 0.001)

func test_pick_type_thresholds() -> void:
	var p := {"dwarf_p": 0.2, "giant_p": 0.3}
	assert_str(Spawner.pick_type(p, 0.19)).is_equal("dwarf")
	assert_str(Spawner.pick_type(p, 0.49)).is_equal("giant")
	assert_str(Spawner.pick_type(p, 0.50)).is_equal("standard")

func test_reachable_within_budget() -> void:
	# max_rise(260,240)=140.8, budget = 140.8+28+28-8 = 188.8
	assert_bool(Spawner.reachable(Vector2(135, 400), 28.0, Vector2(135, 220), 28.0)).is_true()
	assert_bool(Spawner.reachable(Vector2(135, 400), 28.0, Vector2(135, 200), 28.0)).is_false()
	assert_bool(Spawner.reachable(Vector2(30, 400), 28.0, Vector2(200, 350), 28.0)).is_false()  # dx 170 > 160

func test_next_star_always_reachable_and_in_walls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var prev := {"type": "giant", "pos": Vector2(135.0, 380.0)}
	for i in range(300):
		var h := float(i) * 40.0
		var s := Spawner.next_star(prev, h, rng)
		var to_r: float = Tuning.STAR_TYPES[s.type].orbit_r
		var prev_r: float = Tuning.STAR_TYPES[prev.type].orbit_r
		assert_bool(Spawner.reachable(prev.pos, prev_r, s.pos, to_r)).is_true()
		assert_float(s.pos.x).is_greater_equal(Tuning.WALL_MIN_X + to_r)
		assert_float(s.pos.x).is_less_equal(Tuning.WALL_MAX_X - to_r)
		assert_float(s.pos.y).is_less(prev.pos.y)
		prev = s
