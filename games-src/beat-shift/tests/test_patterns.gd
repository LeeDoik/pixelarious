extends GdUnitTestSuite

func _rng(seed_v: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return rng

func test_tier_for_section_clamps() -> void:
	assert_int(Patterns.tier_for_section(0)).is_equal(0)
	assert_int(Patterns.tier_for_section(2)).is_equal(2)
	assert_int(Patterns.tier_for_section(99)).is_equal(Patterns.TIERS.size() - 1)

func test_pattern_data_invariants() -> void:
	# 모든 패턴: 0.0으로 시작, [0, 6.5] 범위, 오름차순, 최소 간격 0.5박
	for tier in Patterns.TIERS:
		for pattern in tier:
			assert_float(pattern[0]).is_equal_approx(0.0, 0.0001)
			for i in range(pattern.size()):
				assert_float(pattern[i]).is_between(0.0, 6.5)
				if i > 0:
					assert_float(float(pattern[i]) - float(pattern[i - 1])).is_greater_equal(0.5)

func test_section_notes_range_order_and_spacing() -> void:
	for tier in range(Patterns.TIERS.size()):
		var notes := Patterns.section_notes(tier, _rng(42 + tier))
		assert_int(notes.size()).is_between(12, 28)
		for i in range(notes.size()):
			assert_float(notes[i]).is_between(0.0, 31.9)
			if i > 0:
				assert_float(float(notes[i]) - float(notes[i - 1])).is_greater_equal(0.5)

func test_section_notes_phrase_alignment() -> void:
	# 패턴이 전부 0.0으로 시작하므로 각 프레이즈 시작박(0,8,16,24)은 항상 노트
	var notes := Patterns.section_notes(0, _rng(7))
	for start in [0.0, 8.0, 16.0, 24.0]:
		assert_bool(notes.has(start)).is_true()

func test_section_notes_deterministic_with_seed() -> void:
	assert_array(Patterns.section_notes(2, _rng(123))).is_equal(Patterns.section_notes(2, _rng(123)))
