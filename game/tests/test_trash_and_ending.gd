extends GdUnitTestSuite

const TrashApp := preload("res://src/apps/trash.gd")
const EndingScene := preload("res://src/ending/ending.gd")

func before_test() -> void:
	GameState.reset()

func test_restore_decoy_fails_target_succeeds() -> void:
	var t: Control = auto_free(TrashApp.new())
	add_child(t)
	assert_bool(t.restore("t2")).is_false()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_false()
	assert_bool(t.restore("t1")).is_true()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_true()
	assert_bool(GameState.has_flag("final_diary_read")).is_true()
	assert_bool(GameState.is_read("doc:diary_final")).is_true()

func test_hidden_ending_gate_counts_records() -> void:
	# records_source를 좁혀 2개만 기록물로 두고 검증
	assert_bool(EndingScene.should_show_hidden()).is_false()
	for cid in ContentDB.records():
		GameState.mark_read(cid)
	# 콘텐츠는 기록물 9개로 확정됨 (records.json)
	assert_int(GameState.records_count()).is_equal(ContentDB.records().size())

func test_epilogue_types_all_lines_and_hidden_when_gated() -> void:
	var e: CanvasLayer = auto_free(EndingScene.new())
	add_child(e)
	e.line_delay = 0.01
	var label := RichTextLabel.new()
	e.add_child(label)
	for cid in ContentDB.records():
		GameState.mark_read(cid)
	await e._type_lines(label, e.EPILOGUE, true)
	await get_tree().create_timer(2.2).timeout
	var text := label.get_parsed_text()
	assert_str(text).contains("LAST LOGIN")
	assert_str(text).contains("어디서 나셨어요")
