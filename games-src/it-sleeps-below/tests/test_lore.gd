extends GdUnitTestSuite

func test_series_is_depth_ordered_and_ids_unique() -> void:
	var s := Lore.series()
	assert_int(s.size()).is_greater_equal(9)
	var seen := {}
	for i in range(1, s.size()):
		assert_int(s[i].row).is_greater_equal(s[i - 1].row)
	for e in s:
		assert_bool(seen.has(e.id)).is_false()
		seen[e.id] = true

func test_next_unfound_and_rate() -> void:
	var s := Lore.series()
	assert_str(Lore.next_unfound([]).id).is_equal(s[0].id)
	assert_str(Lore.next_unfound([s[0].id]).id).is_equal(s[1].id)
	assert_float(Lore.collection_rate([])).is_equal_approx(0.0, 0.001)
	var all_ids: Array = []
	for e in s:
		all_ids.append(e.id)
	assert_float(Lore.collection_rate(all_ids)).is_equal_approx(1.0, 0.001)
