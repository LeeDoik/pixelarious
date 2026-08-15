extends GdUnitTestSuite

func test_tank_by_level() -> void:
	assert_float(Oil.tank(1)).is_equal_approx(60.0, 0.001)
	assert_float(Oil.tank(4)).is_equal_approx(120.0, 0.001)

func test_drain_only_when_on() -> void:
	assert_float(Oil.drain(50.0, 2.0, true)).is_equal_approx(48.0, 0.001)
	assert_float(Oil.drain(50.0, 2.0, false)).is_equal_approx(50.0, 0.001)
	assert_float(Oil.drain(1.0, 5.0, true)).is_equal_approx(0.0, 0.001)  # 음수 금지

func test_radius_stages() -> void:
	assert_float(Oil.radius(61.0, 100.0, true)).is_equal_approx(4.5, 0.001)
	assert_float(Oil.radius(31.0, 100.0, true)).is_equal_approx(3.5, 0.001)
	assert_float(Oil.radius(11.0, 100.0, true)).is_equal_approx(2.5, 0.001)
	assert_float(Oil.radius(5.0, 100.0, true)).is_equal_approx(1.5, 0.001)
	assert_float(Oil.radius(0.0, 100.0, true)).is_equal_approx(Tuning.LIGHT_OFF_RADIUS, 0.001)
	assert_float(Oil.radius(90.0, 100.0, false)).is_equal_approx(Tuning.LIGHT_OFF_RADIUS, 0.001)
