extends GdUnitTestSuite
## 일시정지 재개 이음새: 노트 목록을 remaining_after로 재구성하고 큐 커서를
## lead만큼 되돌리면, 처리된 노트는 재큐되지 않고 마디 초입 노트는 다시 큐된다.

func test_resume_recues_pending_and_skips_resolved() -> void:
	var judge := NoteJudge.new([10.0, 10.5, 11.0, 12.0], 0.07, 0.14)
	judge.on_tap(10.0)
	var missed := judge.advance(10.8)
	assert_array(missed).contains_exactly([10.5])
	var bar_start := 10.0
	var lead := 1.25
	var remaining := judge.remaining_after(bar_start)
	assert_array(remaining).contains_exactly([11.0, 12.0])
	var cues := ConductorMath.due_cues(remaining, bar_start - lead, bar_start, lead)
	assert_array(cues).contains_exactly([11.0])
	assert_bool(remaining.has(10.0)).is_false()
	assert_bool(remaining.has(10.5)).is_false()
