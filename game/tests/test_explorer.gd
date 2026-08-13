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
