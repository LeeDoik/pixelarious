extends GdUnitTestSuite

func after_test() -> void:
	# 다른 테스트에 영향 없게 기본값 복원
	Fx.set_volume(1.0)
	Fx.set_warp(true)
	if Fx.is_menu_open():
		Fx.toggle_menu()

func test_volume_sets_master_bus() -> void:
	Fx.set_volume(0.5)
	assert_float(AudioServer.get_bus_volume_db(0)).is_equal_approx(linear_to_db(0.5), 0.1)
	Fx.set_volume(0.0)
	assert_float(AudioServer.get_bus_volume_db(0)).is_less_equal(-79.0)

func test_warp_toggle_persists() -> void:
	Fx.set_warp(false)
	assert_bool(Fx.is_warp_on()).is_false()
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	assert_bool(bool(data["warp"])).is_false()
	Fx.set_warp(true)
	data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	assert_bool(bool(data["warp"])).is_true()

func test_menu_toggles() -> void:
	assert_bool(Fx.is_menu_open()).is_false()
	Fx.toggle_menu()
	assert_bool(Fx.is_menu_open()).is_true()
	Fx.toggle_menu()
	assert_bool(Fx.is_menu_open()).is_false()
