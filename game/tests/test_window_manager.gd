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

func test_click_anywhere_inside_window_raises_it() -> void:
	var wm := _make()
	wm.open_app("memo")   # (60,40) 640x480
	wm.open_app("mail")   # (88,68) — 위에 겹침
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(70, 50)   # memo 안, mail 밖
	wm._input(e)
	var top := wm.get_child(wm.get_child_count() - 1)
	assert_str(top.win_id).is_equal("memo")

func test_click_on_overlap_raises_only_topmost() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("mail")   # mail이 위
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(200, 200)   # 두 창이 겹치는 지점
	wm._input(e)
	var top := wm.get_child(wm.get_child_count() - 1)
	assert_str(top.win_id).is_equal("mail")

func test_open_window_dynamic_dedup_and_title() -> void:
	var wm := _make()
	wm.open_window("photo:p1", "가족사진.jpg", Label.new())
	assert_bool(wm.is_open("photo:p1")).is_true()
	assert_str(wm.window_title("photo:p1")).is_equal("가족사진.jpg")
	wm.open_window("photo:p1", "가족사진.jpg", Label.new())  # 중복 열기 → 포커스만, 내용물은 정리됨
	assert_int(wm.open_ids().size()).is_equal(1)
	wm.close_app("photo:p1")
	assert_bool(wm.is_open("photo:p1")).is_false()

func test_close_button_fits_inside_titlebar() -> void:
	# 테마 최소 크기(폰트+여백)가 X 버튼을 늘려 타이틀바 아래로 삐져나오면 안 된다
	var wm := _make()
	wm.open_app("memo")
	var w: Control = wm.get_child(wm.get_child_count() - 1)
	await get_tree().process_frame
	var tb: Control = w.get_child(0)
	var checked := false
	for c in tb.get_children():
		if c is Button:
			checked = true
			assert_bool(c.position.y + c.size.y <= tb.size.y + 0.5).is_true()
	assert_bool(checked).is_true()

func test_content_wrapper_does_not_block_titlebar_hits() -> void:
	var wm := _make()
	wm.open_app("memo")
	var w: Control = wm.get_child(wm.get_child_count() - 1)
	# 콘텐츠 래퍼(마지막 자식, 풀렉트)가 히트테스트에서 빠져야 타이틀바 드래그/닫기가 동작한다
	var wrapper: Control = w.get_child(w.get_child_count() - 1)
	assert_bool(wrapper is MarginContainer).is_true()
	assert_int(wrapper.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

func test_titlebar_shows_app_icon_when_registered() -> void:
	var wm: Control = auto_free(WM.new())
	add_child(wm)
	wm.register_app("memo", "메모장", func() -> Control: return Label.new(), "res://assets/img/icons/folder.png")
	wm.open_app("memo")
	var w: Control = wm.get_child(wm.get_child_count() - 1)
	var tb: Control = w.get_child(0)
	var found := false
	for c in tb.get_children():
		if c is TextureRect:
			found = true
	assert_bool(found).is_true()

func test_minimize_restore_cycle() -> void:
	var wm := _make()
	wm.open_app("memo")
	assert_bool(wm.is_minimized("memo")).is_false()
	wm.toggle_minimize("memo")
	assert_bool(wm.is_minimized("memo")).is_true()
	wm.taskbar_clicked("memo")   # 최소화된 창 → 복원
	assert_bool(wm.is_minimized("memo")).is_false()
	wm.taskbar_clicked("memo")   # 최상위 활성 창 → 최소화
	assert_bool(wm.is_minimized("memo")).is_true()

func test_taskbar_click_raises_background_window() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("mail")          # mail이 위
	wm.taskbar_clicked("memo")   # 뒤에 있는 창 → 최소화가 아니라 앞으로
	assert_bool(wm.is_minimized("memo")).is_false()
	var top := wm.get_child(wm.get_child_count() - 1)
	assert_str(top.win_id).is_equal("memo")
