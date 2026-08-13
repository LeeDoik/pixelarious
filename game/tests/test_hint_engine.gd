extends GdUnitTestSuite

const HE := preload("res://src/core/hint_engine.gd")

var _now := 0

func _clock() -> int:
	return _now

func test_hint_levels_follow_spec_timing() -> void:
	var he := HE.new(Callable(self, "_clock"))
	var fired: Array = []
	he.hint_ready.connect(func(p, l): fired.append([p, l]))
	he.set_gate("puzzle1")
	_now = 4 * 60 * 1000
	he.poll()
	assert_array(fired).is_empty()          # 5분 전: 없음
	_now = 5 * 60 * 1000
	he.poll()
	assert_array(fired).is_equal([["puzzle1", 1]])   # 5분: 1단계
	_now = 8 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(2)    # +3분: 2단계
	_now = 11 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(3)    # +3분: 3단계
	_now = 30 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(3)    # 3단계 초과 없음

func test_gate_change_resets_timer() -> void:
	var he := HE.new(Callable(self, "_clock"))
	var fired: Array = []
	he.hint_ready.connect(func(p, l): fired.append([p, l]))
	he.set_gate("puzzle1")
	_now = 4 * 60 * 1000
	he.set_gate("puzzle2")
	_now = 8 * 60 * 1000   # puzzle2 기준 4분
	he.poll()
	assert_array(fired).is_empty()
