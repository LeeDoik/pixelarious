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
