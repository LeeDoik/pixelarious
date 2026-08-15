extends GdUnitTestSuite

func test_orbit_pos_angle_zero() -> void:
	var p := OrbitMath.orbit_pos(Vector2(100, 100), 10.0, 0.0)
	assert_bool(p.is_equal_approx(Vector2(110, 100))).is_true()

func test_orbit_pos_quarter_turn() -> void:
	var p := OrbitMath.orbit_pos(Vector2(100, 100), 10.0, PI / 2)
	assert_bool(p.is_equal_approx(Vector2(100, 110))).is_true()

func test_advance_angle_forward_and_reverse() -> void:
	assert_float(OrbitMath.advance_angle(0.0, 2.0, 1, 0.5)).is_equal_approx(1.0, 0.0001)
	assert_float(OrbitMath.advance_angle(0.0, 2.0, -1, 0.5)).is_equal_approx(-1.0, 0.0001)

func test_launch_velocity_is_tangent() -> void:
	# 별 중심 (0,0), 플레이어 오른쪽 (10,0), dir=+1 → 접선은 아래(+y)
	var v := OrbitMath.launch_velocity(Vector2.ZERO, Vector2(10, 0), 1, 5.0)
	assert_bool(v.is_equal_approx(Vector2(0, 5))).is_true()
	var v2 := OrbitMath.launch_velocity(Vector2.ZERO, Vector2(10, 0), -1, 5.0)
	assert_bool(v2.is_equal_approx(Vector2(0, -5))).is_true()

func test_integrate_flight_applies_gravity_then_moves() -> void:
	var r := OrbitMath.integrate_flight(Vector2.ZERO, Vector2(10, 0), 100.0, 0.1)
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(10, 10))).is_true()
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(1, 1))).is_true()

func test_try_capture_boundary() -> void:
	assert_bool(OrbitMath.try_capture(Vector2(3, 4), Vector2.ZERO, 5.0)).is_true()
	assert_bool(OrbitMath.try_capture(Vector2(3, 4.1), Vector2.ZERO, 5.0)).is_false()

func test_entry_dir_follows_rotation_sense() -> void:
	assert_int(OrbitMath.entry_dir(Vector2.ZERO, Vector2(10, 0), Vector2(0, 5))).is_equal(1)
	assert_int(OrbitMath.entry_dir(Vector2.ZERO, Vector2(10, 0), Vector2(0, -5))).is_equal(-1)

func test_entry_angle() -> void:
	assert_float(OrbitMath.entry_angle(Vector2(100, 100), Vector2(110, 100))).is_equal_approx(0.0, 0.0001)

func test_bounce_x_left_wall_reflects_and_damps() -> void:
	var r := OrbitMath.bounce_x(Vector2(5, 0), Vector2(-20, 0), 10.0, 260.0, 0.9)
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(15, 0))).is_true()
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(18, 0))).is_true()

func test_bounce_x_right_wall() -> void:
	var r := OrbitMath.bounce_x(Vector2(265, 0), Vector2(20, 0), 10.0, 260.0, 0.9)
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(255, 0))).is_true()
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(-18, 0))).is_true()

func test_max_rise() -> void:
	assert_float(OrbitMath.max_rise(260.0, 240.0)).is_equal_approx(140.833, 0.01)
