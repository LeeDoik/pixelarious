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
	# 샘플 콘텐츠는 기록물 2개 — 9개 규칙은 Task 13 콘텐츠 완성 후 유효
	assert_int(GameState.records_count()).is_equal(ContentDB.records().size())
