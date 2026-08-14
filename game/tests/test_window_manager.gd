extends GdUnitTestSuite

const WM := preload("res://src/desktop/window_manager.gd")

func _make() -> Control:
	var wm: Control = auto_free(WM.new())
	add_child(wm)
	wm.register_app("memo", "메모장", func() -> Control: return Label.new())
	wm.register_app("mail", "누리메일", func() -> Control: return Label.new())
	return wm

func test_open_close_and_ids() -> void:
	var wm := _make()
	assert_bool(wm.is_open("memo")).is_false()
	wm.open_app("memo")
	assert_bool(wm.is_open("memo")).is_true()
	wm.open_app("mail")
	assert_array(wm.open_ids()).contains(["memo", "mail"])
	wm.close_app("memo")
	assert_bool(wm.is_open("memo")).is_false()

func test_reopen_focuses_instead_of_duplicating() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("memo")
	assert_int(wm.open_ids().size()).is_equal(1)

func test_focus_moves_to_front() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("mail")   # mail이 위
	wm.focus_app("memo")
	var top := wm.get_child(wm.get_child_count() - 1)
	assert_str(top.win_id).is_equal("memo")

func test_content_wrapper_does_not_block_titlebar_hits() -> void:
	var wm := _make()
	wm.open_app("memo")
	var w: Control = wm.get_child(wm.get_child_count() - 1)
	# 콘텐츠 래퍼(마지막 자식, 풀렉트)가 히트테스트에서 빠져야 타이틀바 드래그/닫기가 동작한다
	var wrapper: Control = w.get_child(w.get_child_count() - 1)
	assert_bool(wrapper is MarginContainer).is_true()
	assert_int(wrapper.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
