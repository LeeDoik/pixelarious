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

func test_window_resize_grows_and_respects_min_size() -> void:
	var wm := _make()
	wm.size = Vector2(1024, 732)
	wm.open_app("memo")
	var w: OSWindow = wm.get_child(wm.get_child_count() - 1)
	var before := w.size
	w._resize_zone = 6  # 우하단 모서리
	w._apply_resize(Vector2(40, 30))
	assert_bool(w.size.x > before.x and w.size.y > before.y).is_true()
	w._apply_resize(Vector2(-10000, -10000))
	assert_bool(w.size.x >= w.MIN_WIN_SIZE.x and w.size.y >= w.MIN_WIN_SIZE.y).is_true()

func test_window_resize_left_edge_moves_and_resizes() -> void:
	var wm := _make()
	wm.size = Vector2(1024, 732)
	wm.open_app("memo")
	var w: OSWindow = wm.get_child(wm.get_child_count() - 1)
	var right_edge := w.position.x + w.size.x
	w._resize_zone = 1  # 왼쪽 가장자리
	w._apply_resize(Vector2(-20, 0))
	assert_float(w.position.x + w.size.x).is_equal_approx(right_edge, 0.5)  # 오른쪽 변은 고정
	assert_bool(w.position.x < 60.0).is_true()

func test_edge_cursor_matches_drag_direction() -> void:
	# 커서 모양은 실제 끌리는 방향과 붙어 있어야 한다. 특히 대각선 둘을 맞바꾸면
	# 커서가 드래그 방향과 반대로 기울어지는데, 눈으로만 보면 놓치기 쉽다.
	var wm := _make()
	wm.size = Vector2(1024, 732)
	wm.open_app("memo")
	var w: OSWindow = wm.get_child(wm.get_child_count() - 1)
	var mid := w.size * 0.5
	var edge := w.RESIZE_MARGIN * 0.5
	var cases := {
		Vector2(edge, mid.y): Control.CURSOR_HSIZE,                      # 왼쪽 변
		Vector2(w.size.x - edge, mid.y): Control.CURSOR_HSIZE,           # 오른쪽 변
		Vector2(mid.x, w.size.y - edge): Control.CURSOR_VSIZE,           # 아래 변
		Vector2(edge, w.size.y - edge): Control.CURSOR_BDIAGSIZE,        # 좌하 모서리 = "/"
		Vector2(w.size.x - edge, w.size.y - edge): Control.CURSOR_FDIAGSIZE,  # 우하 모서리 = "\"
		mid: Control.CURSOR_ARROW,                                       # 본체 안쪽
	}
	for point in cases:
		w._update_resize_cursor(w._zone_at(point))
		assert_int(w.mouse_default_cursor_shape).override_failure_message(
			"wrong cursor at %s" % point).is_equal(cases[point])

func test_maximize_fills_the_desktop_and_restores_exactly() -> void:
	var wm := _make()
	wm.size = Vector2(1024, 732)
	wm.open_app("memo")
	var w: OSWindow = wm.get_child(wm.get_child_count() - 1)
	var before := Rect2(w.position, w.size)
	w.toggle_maximize()
	assert_bool(w.is_maximized()).is_true()
	assert_bool(w.position.is_equal_approx(Vector2.ZERO)).is_true()
	assert_bool(w.size.is_equal_approx(wm.size)).is_true()
	w.toggle_maximize()
	assert_bool(w.is_maximized()).is_false()
	assert_bool(w.position.is_equal_approx(before.position)).is_true()
	assert_bool(w.size.is_equal_approx(before.size)).is_true()

func test_maximized_window_does_not_offer_resize_edges() -> void:
	# 최대화된 창의 가장자리가 계속 잡히면 화면 밖으로 끌려 나간다
	var wm := _make()
	wm.size = Vector2(1024, 732)
	wm.open_app("memo")
	var w: OSWindow = wm.get_child(wm.get_child_count() - 1)
	w.toggle_maximize()
	var e := InputEventMouseMotion.new()
	e.position = Vector2(w.size.x - 2.0, w.size.y - 2.0)
	w._on_body_input(e)
	assert_int(w.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)

func test_taskbar_knows_which_window_is_in_front() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("mail")
	assert_str(wm.active_id()).is_equal("mail")
	wm.focus_app("memo")
	assert_str(wm.active_id()).is_equal("memo")
	wm.toggle_minimize("memo")           # 최소화된 창은 활성이 아니다
	assert_str(wm.active_id()).is_equal("mail")

func test_window_icon_is_remembered_for_the_taskbar() -> void:
	var wm := _make()
	wm.register_app("photo", "사진", func() -> Control: return Label.new(), "res://assets/img/icons/photo.png")
	wm.open_app("photo")
	assert_str(wm.window_icon("photo")).is_equal("res://assets/img/icons/photo.png")
