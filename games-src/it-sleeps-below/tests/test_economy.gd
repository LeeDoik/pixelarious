extends GdUnitTestSuite

func test_settle_sums_ore_values() -> void:
	assert_int(Economy.settle([0, 0, 6])).is_equal(5 + 5 + 300)

func test_upgrade_cost_curve_and_cap() -> void:
	assert_int(Economy.upgrade_cost("pick", 2)).is_equal(150)
	assert_int(Economy.upgrade_cost("pick", 4)).is_equal(900)
	assert_int(Economy.upgrade_cost("pick", 5)).is_equal(-1)
	assert_int(Economy.upgrade_cost("boots", 3)).is_equal(400)
	assert_int(Economy.upgrade_cost("boots", 4)).is_equal(-1)

func test_track_tables() -> void:
	assert_int(Economy.bag_slots(1)).is_equal(8)
	assert_int(Economy.bag_slots(4)).is_equal(20)
	assert_int(Economy.max_hearts(3)).is_equal(5)
	assert_int(Economy.fall_tolerance(2)).is_equal(4)

func test_strata_gate() -> void:
	assert_bool(Economy.dig_allowed(1, 20)).is_true()    # 표토
	assert_bool(Economy.dig_allowed(1, 80)).is_false()   # 암반은 Lv2
	assert_bool(Economy.dig_allowed(2, 80)).is_true()
	assert_bool(Economy.dig_allowed(3, 320)).is_false()  # 심층은 Lv4
	assert_bool(Economy.dig_allowed(4, 320)).is_true()

func test_dig_time_scales() -> void:
	assert_float(Economy.dig_time(1, 20)).is_equal_approx(0.35, 0.001)
	assert_float(Economy.dig_time(4, 320)).is_equal_approx(1.1 * 0.55, 0.001)
