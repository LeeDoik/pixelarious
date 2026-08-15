extends GdUnitTestSuite

const Explorer := preload("res://src/apps/explorer.gd")

func before_test() -> void:
	GameState.reset()

func _make() -> Control:
	var e: Control = auto_free(Explorer.new())
	add_child(e)
	return e

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
	var wm: Control = auto_free(preload("res://src/desktop/window_manager.gd").new())
	add_child(wm)  # _ready에서 "window_manager" 그룹 등록
	var e := _make()
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
