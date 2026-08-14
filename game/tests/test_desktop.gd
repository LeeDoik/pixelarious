extends GdUnitTestSuite

const DESKTOP := preload("res://src/desktop/desktop.tscn")

func test_desktop_builds_icons_and_taskbar() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_object(d.wm).is_not_null()
	assert_int(d.icon_count()).is_greater(3)

func test_clock_follows_act() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_str(d.clock_text_for_act(1)).is_equal("21:47")
	assert_str(d.clock_text_for_act(3)).is_equal("01:12")

func test_desktop_fills_viewport_so_windows_can_move() -> void:
	# 루트 앵커가 무시되면 wm.size가 0이 되어 창 드래그가 (0,0)에 고정된다 (회귀 방지)
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	await get_tree().process_frame
	assert_bool(d.size.x > 0.0 and d.size.y > 0.0).is_true()
	assert_bool(d.wm.size.x > 0.0 and d.wm.size.y > 0.0).is_true()
