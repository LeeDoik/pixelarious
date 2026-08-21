extends GdUnitTestSuite

const P := 0.070
const G := 0.140

func _judge(notes: Array) -> NoteJudge:
	return NoteJudge.new(notes, P, G)

func test_perfect_and_good_windows() -> void:
	# 주의: 10.07 - 10.0 은 float에서 0.07을 살짝 넘는다 — 경계 정밀 검증은
	# test_conductor_math의 classify가 담당하고, 여기는 창 안팎만 검증한다
	assert_str(_judge([10.0]).on_tap(10.0).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(10.069).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(9.931).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(10.072).result).is_equal("good")
	assert_str(_judge([10.0]).on_tap(9.861).result).is_equal("good")
	assert_str(_judge([10.0]).on_tap(10.142).result).is_equal("stray")

func test_tap_far_from_any_note_is_stray() -> void:
	var r := _judge([10.0, 12.0]).on_tap(11.0)
	assert_str(r.result).is_equal("stray")
	assert_float(r.note_time).is_equal_approx(-1.0, 0.0001)

func test_nearest_note_wins_when_windows_overlap() -> void:
	# 160BPM 엇박 간격 0.1875s < GOOD 창 2배 — 겹칠 때 더 가까운 노트를 소비
	# 탭 10.10: 10.0까지 0.10, 10.1875까지 0.0875 → 더 가까운 10.1875가 GOOD
	var j := _judge([10.0, 10.1875])
	var r := j.on_tap(10.10)
	assert_str(r.result).is_equal("good")
	assert_float(r.note_time).is_equal_approx(10.1875, 0.0001)

func test_consumed_note_cannot_be_hit_twice() -> void:
	var j := _judge([10.0])
	assert_str(j.on_tap(10.0).result).is_equal("perfect")
	assert_str(j.on_tap(10.02).result).is_equal("stray")
	assert_int(j.remaining()).is_equal(0)

func test_advance_reports_each_miss_once() -> void:
	var j := _judge([10.0, 11.0])
	assert_array(j.advance(10.0)).is_empty()
	assert_array(j.advance(10.15)).contains_exactly([10.0])
	assert_array(j.advance(10.2)).is_empty()
	assert_array(j.advance(12.0)).contains_exactly([11.0])
	assert_int(j.remaining()).is_equal(0)

func test_hit_note_is_not_missed_later() -> void:
	var j := _judge([10.0, 11.0])
	j.on_tap(10.0)
	assert_array(j.advance(12.0)).contains_exactly([11.0])

func test_remaining_after_filters_judged_and_past() -> void:
	var j := _judge([10.0, 11.0, 12.0, 13.0])
	j.on_tap(11.0)
	assert_array(j.remaining_after(11.5)).contains_exactly([12.0, 13.0])
	assert_array(j.remaining_after(9.0)).contains_exactly([10.0, 12.0, 13.0])
