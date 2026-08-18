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

func test_warp_point_identity_at_center() -> void:
	var center := Vector2(512, 384)
	assert_bool(Fx.warp_point(center).is_equal_approx(center)).is_true()

func test_warp_point_pushes_corner_outward() -> void:
	# 좌상단 근처 클릭은 코너 방향(더 작은 좌표)으로 보정되어야 한다
	var p := Vector2(50, 50)
	var w := Fx.warp_point(p)
	assert_bool(w.x < p.x and w.y < p.y).is_true()

func test_menu_toggles() -> void:
	assert_bool(Fx.is_menu_open()).is_false()
	Fx.toggle_menu()
	assert_bool(Fx.is_menu_open()).is_true()
	Fx.toggle_menu()
	assert_bool(Fx.is_menu_open()).is_false()

func test_pointer_cursors_are_present_and_center_hotspot_safe() -> void:
	# 창 가장자리 커서 자산이 빠지면 그 순간에만 호스트 OS 커서가 튀어나온다.
	# Fx가 핫스팟을 이미지 정중앙으로 잡으므로 가로세로는 짝수여야 한다.
	assert_int(Fx.POINTER_CURSORS.size()).is_equal(6)
	for shape in Fx.POINTER_CURSORS:
		var path: String = Fx.POINTER_CURSORS[shape]
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"cursor asset missing: " + path).is_true()
		var tex: Texture2D = load(path)
		assert_int(tex.get_width() % 2).override_failure_message(
			"%s width %d is odd" % [path, tex.get_width()]).is_equal(0)
		assert_int(tex.get_height() % 2).override_failure_message(
			"%s height %d is odd" % [path, tex.get_height()]).is_equal(0)
