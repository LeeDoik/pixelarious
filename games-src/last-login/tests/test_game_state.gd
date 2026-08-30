extends GdUnitTestSuite

const GS := preload("res://src/core/game_state.gd")

func _make() -> Node:
	var gs: Node = auto_free(GS.new())
	gs.puzzle_source = func(id: String) -> Dictionary:
		return {"answer": "20020316"} if id == "puzzle1" else {}
	gs.records_source = func() -> Array:
		return ["doc:r1", "doc:r2", "doc:r3"]
	return gs

func test_flags() -> void:
	var gs := _make()
	assert_bool(gs.has_flag("booted")).is_false()
	gs.set_flag("booted")
	assert_bool(gs.has_flag("booted")).is_true()

func test_act_progression() -> void:
	var gs := _make()
	assert_int(gs.current_act()).is_equal(1)
	gs.set_flag("puzzle1_solved")
	assert_int(gs.current_act()).is_equal(2)
	gs.set_flag("puzzle3_solved")
	assert_int(gs.current_act()).is_equal(3)
	gs.set_flag("final_diary_read")
	assert_int(gs.current_act()).is_equal(4)
	gs.set_flag("puzzle6_solved")          # 정리.zip이든 회계의 이름이든 — 마지막 증거
	assert_int(gs.current_act()).is_equal(5)

func test_try_answer_case_insensitive_and_flag() -> void:
	var gs := _make()
	assert_bool(gs.try_answer("puzzle1", "wrong")).is_false()
	assert_bool(gs.has_flag("puzzle1_solved")).is_false()
	assert_bool(gs.try_answer("puzzle1", "20020316")).is_true()
	assert_bool(gs.has_flag("puzzle1_solved")).is_true()

func test_records_count_only_counts_records() -> void:
	var gs := _make()
	gs.mark_read("doc:r1")
	gs.mark_read("doc:not_a_record")
	gs.mark_read("doc:r1")  # 중복
	assert_int(gs.records_count()).is_equal(1)

func test_save_and_load_roundtrip() -> void:
	var gs := _make()
	gs.set_flag("puzzle1_solved")
	gs.mark_read("doc:r2")
	gs.save_game()
	var gs2 := _make()
	assert_bool(gs2.has_save()).is_true()
	assert_bool(gs2.load_game()).is_true()
	assert_bool(gs2.has_flag("puzzle1_solved")).is_true()
	assert_int(gs2.records_count()).is_equal(1)
	gs2.reset()
	assert_bool(gs2.has_save()).is_false()

func test_load_game_emits_act_changed() -> void:
	var gs := _make()
	gs.set_flag("puzzle1_solved")
	gs.save_game()
	var gs2 := _make()
	var acts: Array = []
	gs2.act_changed.connect(func(a): acts.append(a))
	assert_bool(gs2.load_game()).is_true()
	assert_array(acts).is_equal([2])

func test_ending_start_not_persisted() -> void:
	var gs := _make()
	gs.set_flag("final_diary_read")
	gs.set_flag("ending_start")
	var gs2 := _make()
	assert_bool(gs2.load_game()).is_true()
	assert_bool(gs2.has_flag("final_diary_read")).is_true()
	assert_bool(gs2.has_flag("ending_start")).is_false()
