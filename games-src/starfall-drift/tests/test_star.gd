extends GdUnitTestSuite

## 붕괴는 HUD 점수가 Tuning.COLLAPSE_GRACE_SCORE에 닿은 뒤에만 진행된다.
## 붕괴 자체를 보려는 테스트는 먼저 유예를 벗어나야 한다.
func _past_grace() -> void:
	GameState.start_run()
	GameState.update_rise(Tuning.COLLAPSE_GRACE_SCORE * Tuning.PX_PER_M)

func test_setup_reads_tuning() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	assert_float(s.orbit_r).is_equal_approx(16.0, 0.001)
	assert_float(s.ang_vel).is_equal_approx(3.6, 0.001)
	assert_float(s.collapse_time).is_equal_approx(2.0, 0.001)

func test_collapse_mult_shortens_life() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.5)
	assert_float(s.collapse_time).is_equal_approx(3.5 / 1.5, 0.001)

func test_gauge_frozen_during_score_grace() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	GameState.start_run()
	s.occupied = true
	var got: Array = []
	s.collapsed.connect(func(star): got.append(star))
	s.tick(60.0)  # 점수 0 — 유예 구간
	assert_int(got.size()).is_equal(0)
	assert_bool(s.alive).is_true()
	assert_float(s.gauge_ratio()).is_equal_approx(0.0, 0.001)
	# 점수가 기준을 넘으면 그 시점부터 게이지가 찬다
	GameState.update_rise(Tuning.COLLAPSE_GRACE_SCORE * Tuning.PX_PER_M)
	s.tick(1.0)
	assert_float(s.gauge_ratio()).is_equal_approx(1.0 / 2.0, 0.001)

func test_gauge_advances_only_when_occupied_playing() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.0)
	_past_grace()
	s.occupied = false
	s.tick(1.0)
	assert_float(s.gauge).is_equal_approx(0.0, 0.001)
	s.occupied = true
	s.tick(1.0)
	assert_float(s.gauge_ratio()).is_equal_approx(1.0 / 3.5, 0.001)

func test_full_gauge_emits_collapsed() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	_past_grace()
	s.occupied = true
	var got: Array = []
	s.collapsed.connect(func(star): got.append(star))
	s.tick(2.5)
	assert_int(got.size()).is_equal(1)
	assert_bool(s.alive).is_false()
