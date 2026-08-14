extends GdUnitTestSuite

const DESKTOP := preload("res://src/desktop/desktop.tscn")

func test_desktop_builds_icons_and_taskbar() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_object(d.wm).is_not_null()
	assert_int(d.icon_count()).is_greater(3)

func test_clock_shows_local_time_format() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	var re := RegEx.new()
	re.compile("^\\d{2}:\\d{2}$")
	assert_bool(re.search(d.clock_text()) != null).is_true()

func test_window_layer_does_not_block_desktop_icons() -> void:
	# wm이 풀렉트 STOP이면 아래 형제인 아이콘들이 클릭 불가가 된다 (회귀 방지)
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_int(d.wm.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

func test_desktop_fills_viewport_so_windows_can_move() -> void:
	# 루트 앵커가 무시되면 wm.size가 0이 되어 창 드래그가 (0,0)에 고정된다 (회귀 방지)
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	await get_tree().process_frame
	assert_bool(d.size.x > 0.0 and d.size.y > 0.0).is_true()
	assert_bool(d.wm.size.x > 0.0 and d.wm.size.y > 0.0).is_true()
