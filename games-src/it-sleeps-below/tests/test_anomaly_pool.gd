extends GdUnitTestSuite

func test_catalog_has_three_kinds_and_min_sizes() -> void:
	var kinds := {"diegetic": 0, "meta": 0, "encounter": 0}
	for e in AnomalyPool.catalog():
		kinds[e.kind] += 1
	assert_int(kinds.diegetic).is_greater_equal(8)
	assert_int(kinds.meta).is_greater_equal(4)
	assert_int(kinds.encounter).is_greater_equal(4)

func test_once_per_save_excluded() -> void:
	var e := {"id": "x", "kind": "diegetic", "min_depth": 0, "once": true, "realized": false}
	assert_bool(AnomalyPool.eligible(e, [], 100, 0)).is_true()
	assert_bool(AnomalyPool.eligible(e, ["x"], 100, 0)).is_false()

func test_depth_and_realized_gates() -> void:
	var e := {"id": "y", "kind": "diegetic", "min_depth": 240, "once": false, "realized": true}
	assert_bool(AnomalyPool.eligible(e, [], 100, 5)).is_false()   # 깊이 미달
	assert_bool(AnomalyPool.eligible(e, [], 300, 0)).is_false()   # 실체화는 오염 3+ 필요
	assert_bool(AnomalyPool.eligible(e, [], 300, 3)).is_true()

func test_pick_respects_flags() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var flags: Array = []
	for i in range(200):
		var p := AnomalyPool.pick(flags, 400, 4, rng)
		if p.is_empty():
			break
		if p.once:
			assert_bool(flags.has(p.id)).is_false()
			flags.append(p.id)
	assert_int(flags.size()).is_greater(0)
