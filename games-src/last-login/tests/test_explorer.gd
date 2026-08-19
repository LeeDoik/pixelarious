extends GdUnitTestSuite

const Explorer := preload("res://src/apps/explorer.gd")
const WindowManagerScript := preload("res://src/desktop/window_manager.gd")

func before_test() -> void:
	GameState.reset()

func _make() -> Control:
	var e: Control = auto_free(Explorer.new())
	add_child(e)
	return e

func _make_with_wm() -> Array:
	var wm: Control = auto_free(WindowManagerScript.new())
	add_child(wm)  # _ready에서 "window_manager" 그룹 등록
	return [_make(), wm]

func test_locked_folder_blocks_until_solved() -> void:
	var e := _make()
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("nope")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()

func test_open_file_marks_read() -> void:
	var e := _make()
	e.open_file("f_essay")
	assert_bool(GameState.is_read("doc:essay_2001")).is_true()

func test_navigating_away_clears_pending_lock() -> void:
	var e := _make()
	assert_bool(e.open_folder("locked")).is_false()
	e.open_file("f_essay")
	assert_bool(e.submit_password("20020316")).is_false()
	assert_bool(GameState.has_flag("puzzle1_solved")).is_false()

func test_opening_photo_spawns_viewer_window_and_marks_read() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	var wm: Control = pair[1]
	# 콘텐츠에서 이미지 노드를 하나 찾는다
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/fs.json"))
	var img_id := ""
	var img_cid := ""
	for n in raw["nodes"]:
		if n.get("type") == "image":
			img_id = n["id"]
			img_cid = n.get("cid", "")
			break
	assert_str(img_id).is_not_empty()
	e.open_file(img_id)
	assert_bool(wm.is_open("photo:" + img_id)).is_true()
	if img_cid != "":
		assert_bool(GameState.is_read(img_cid)).is_true()

func test_document_opens_notepad_window_with_body() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	var wm: Control = pair[1]
	e.open_file("f_essay")
	assert_bool(wm.is_open("doc:f_essay")).is_true()
	assert_str(wm.window_title("doc:f_essay")).is_equal("낙방 수기.txt")

func test_address_bar_follows_navigation() -> void:
	var e := _make()
	assert_str(e.address_text()).is_equal("C:\\내 문서")
	assert_bool(e.open_folder("photos")).is_true()
	assert_str(e.address_text()).is_equal("C:\\내 문서\\사진")

func test_up_button_climbs_to_parent() -> void:
	var e := _make()
	assert_bool(e.open_folder("photos")).is_true()
	e._go_up()
	assert_str(e.cwd()).is_equal("mydocs")

func test_back_button_returns_to_previous_folder() -> void:
	var e := _make()
	assert_bool(e.can_go_back()).is_false()
	assert_bool(e.open_folder("saebit")).is_true()
	assert_bool(e.can_go_back()).is_true()
	e._go_back()
	assert_str(e.cwd()).is_equal("mydocs")
	assert_bool(e.can_go_back()).is_false()

func test_both_views_show_every_entry() -> void:
	var e := _make()
	var expected := ContentDB.fs_children("mydocs").size()
	assert_int(e.item_count()).is_equal(expected)
	assert_int(e.detail_row_count()).is_equal(expected)
	assert_str(e.status_text()).is_equal("개체 %d개" % expected)

func test_view_toggle_swaps_visible_list() -> void:
	var e := _make()
	assert_int(e.view_mode()).is_equal(Explorer.ViewMode.ICONS)
	e.set_view_mode(Explorer.ViewMode.DETAILS)
	assert_int(e.view_mode()).is_equal(Explorer.ViewMode.DETAILS)
	e.set_view_mode(Explorer.ViewMode.ICONS)
	assert_int(e.view_mode()).is_equal(Explorer.ViewMode.ICONS)

func test_corrupt_file_reports_instead_of_opening() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	var wm: Control = pair[1]
	e.open_file("t2")
	assert_str(e.last_message()).is_equal("파일이 손상되어 열 수 없습니다.")
	assert_bool(wm.is_open("doc:t2")).is_false()

func test_every_node_carries_display_metadata() -> void:
	# 자세히 보기의 크기·수정한 날짜 칸이 비지 않도록 콘텐츠 쪽을 강제한다
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/fs.json"))
	for n in raw["nodes"]:
		assert_str(String(n.get("mtime", ""))).override_failure_message(
			"fs node %s has no mtime" % n["id"]).is_not_empty()
		if n.get("type") != "folder":
			assert_bool(n.has("size")).override_failure_message(
				"fs node %s has no size" % n["id"]).is_true()

func test_size_and_date_formatting() -> void:
	assert_str(Explorer.format_size(0)).is_equal("0KB")
	assert_str(Explorer.format_size(1)).is_equal("1KB")
	assert_str(Explorer.format_size(1024)).is_equal("1KB")
	assert_str(Explorer.format_size(1025)).is_equal("2KB")
	assert_str(Explorer.format_size(1024 * 1023)).is_equal("1,023KB")
	assert_str(Explorer.format_size(1024 * 1536)).is_equal("1.5MB")
	assert_str(Explorer.format_mtime("2002-11-02 03:52")).is_equal("2002-11-02 오전 3:52")
	assert_str(Explorer.format_mtime("2002-08-04 15:52")).is_equal("2002-08-04 오후 3:52")
	assert_str(Explorer.format_mtime("2002-01-01 00:12")).is_equal("2002-01-01 오전 12:12")

func test_type_labels_come_from_extension() -> void:
	assert_str(Explorer.type_label({"type": "folder", "name": "사진"})).is_equal("파일 폴더")
	assert_str(Explorer.type_label({"type": "doc", "name": "낙방 수기.txt"})).is_equal("텍스트 문서")
	assert_str(Explorer.type_label({"type": "image", "name": "봄이_첫날.jpg"})).is_equal("JPEG 이미지")
	assert_str(Explorer.type_label({"type": "doc", "name": "danjjak_temp.dat"})).is_equal("DAT 파일")

func test_selection_survives_a_view_switch() -> void:
	# 보기를 바꿨는데 선택이 풀리면 상태표시줄엔 파일 이름이 남고 목록은 텅 빈 채가 된다
	var e := _make()
	e._show_selection("f_essay")
	e.set_view_mode(Explorer.ViewMode.DETAILS)
	assert_str(e.selected_id()).is_equal("f_essay")
	var row: TreeItem = e._tree.get_selected()
	assert_object(row).is_not_null()
	assert_str(String(row.get_metadata(0))).is_equal("f_essay")
	e.set_view_mode(Explorer.ViewMode.ICONS)
	assert_array(e._list.get_selected_items()).is_not_empty()
