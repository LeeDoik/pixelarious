extends GdUnitTestSuite

func test_beats_time_roundtrip() -> void:
	assert_float(ConductorMath.beats_from_time(2.5, 96.0)).is_equal_approx(4.0, 0.0001)
	assert_float(ConductorMath.time_from_beats(4.0, 96.0)).is_equal_approx(2.5, 0.0001)
	assert_float(ConductorMath.time_from_beats(ConductorMath.beats_from_time(1.234, 128.0), 128.0)).is_equal_approx(1.234, 0.0001)

func test_wrapped_time() -> void:
	assert_float(ConductorMath.wrapped_time(2.5, 0, 0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(ConductorMath.wrapped_time(2.5, 3, 0.7)).is_equal_approx(8.2, 0.0001)

func test_classify_boundaries() -> void:
	assert_str(ConductorMath.classify(0.0, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(0.07, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(-0.07, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(0.071, 0.07, 0.14)).is_equal("good")
	assert_str(ConductorMath.classify(-0.14, 0.07, 0.14)).is_equal("good")
	assert_str(ConductorMath.classify(0.141, 0.07, 0.14)).is_equal("")

func test_due_cues_window_semantics() -> void:
	# 노트 10.0, lead 1.25 → 큐 시각 8.75. (from, to] — from 배타, to 포함
	var notes := [10.0, 12.0, 20.0]
	assert_array(ConductorMath.due_cues(notes, 8.0, 8.75, 1.25)).contains_exactly([10.0])
	assert_array(ConductorMath.due_cues(notes, 8.75, 9.0, 1.25)).is_empty()
	assert_array(ConductorMath.due_cues(notes, 8.0, 11.0, 1.25)).contains_exactly([10.0, 12.0])

func test_arc_pos_endpoints_and_apex() -> void:
	var from := Vector2(0, 100)
	var to := Vector2(100, 100)
	assert_bool(Motion.arc_pos(from, to, 0.0, 40.0).is_equal_approx(from)).is_true()
	assert_bool(Motion.arc_pos(from, to, 1.0, 40.0).is_equal_approx(to)).is_true()
	assert_bool(Motion.arc_pos(from, to, 0.5, 40.0).is_equal_approx(Vector2(50, 60))).is_true()
