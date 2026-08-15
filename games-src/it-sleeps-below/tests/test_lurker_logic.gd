extends GdUnitTestSuite

func _open_all(_p: Vector2i) -> bool:
	return true

func _open_corridor(p: Vector2i) -> bool:
	return p.y == 0 and p.x >= 0 and p.x <= 5  # 가로 복도만

func test_frozen_in_light_only_when_lamp_on() -> void:
	assert_bool(LurkerLogic.is_frozen(Vector2i(3, 0), Vector2i(0, 0), 3.5, true)).is_true()
	assert_bool(LurkerLogic.is_frozen(Vector2i(3, 0), Vector2i(0, 0), 3.5, false)).is_false()
	assert_bool(LurkerLogic.is_frozen(Vector2i(5, 0), Vector2i(0, 0), 3.5, true)).is_false()

func test_next_step_moves_through_open_cells_only() -> void:
	var step := LurkerLogic.next_step(Vector2i(0, 0), Vector2i(5, 0), _open_corridor)
	assert_that(step).is_equal(Vector2i(1, 0))
	# 목표가 막힌 영역이면 제자리
	var stuck := LurkerLogic.next_step(Vector2i(0, 0), Vector2i(0, 5), _open_corridor)
	assert_that(stuck).is_equal(Vector2i(0, 0))

func test_hear_updates_target_on_loud_noise() -> void:
	var s := {"target": Vector2i(9, 9), "alert": false}
	s = LurkerLogic.hear(s, Vector2i(2, 3), Tuning.NOISE_LOUD)
	assert_that(s.target).is_equal(Vector2i(2, 3))
	assert_bool(s.alert).is_true()
	var quiet := LurkerLogic.hear({"target": Vector2i(9, 9), "alert": false}, Vector2i(2, 3), Tuning.NOISE_QUIET)
	assert_that(quiet.target).is_equal(Vector2i(9, 9))

func test_director_cycle_order_and_depth_pressure() -> void:
	var lens := LurkerLogic.cycle_lengths(240)
	var deep := LurkerLogic.cycle_lengths(390)
	assert_float(deep.silence).is_less(lens.silence)
	assert_float(LurkerLogic.cycle_lengths(4000).silence).is_equal_approx(Tuning.DIRECTOR_SILENCE_MIN, 0.001)
	var d := {"mode": LurkerLogic.M_SILENCE, "t": 0.5}
	d = LurkerLogic.director_step(d, 1.0, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_HUNT)
	d.t = 0.0
	d = LurkerLogic.director_step(d, 0.1, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_RETREAT)
	d.t = 0.0
	d = LurkerLogic.director_step(d, 0.1, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_SILENCE)

func test_arrived_wander_switches_target() -> void:
	var s := {"target": Vector2i(1, 1), "alert": true}
	s = LurkerLogic.arrived_wander(s, Vector2i(7, 7))
	assert_that(s.target).is_equal(Vector2i(7, 7))
	assert_bool(s.alert).is_false()
