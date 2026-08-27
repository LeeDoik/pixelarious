extends GdUnitTestSuite

func test_group_digits() -> void:
	assert_str(Camp.group_digits(0)).is_equal("0")
	assert_str(Camp.group_digits(999)).is_equal("999")
	assert_str(Camp.group_digits(1000)).is_equal("1,000")
	assert_str(Camp.group_digits(1234567)).is_equal("1,234,567")
	assert_str(Camp.group_digits(-4200)).is_equal("-4,200")

func test_tags() -> void:
	assert_str(Camp.miner_tag(7)).is_equal("MINER #7")
	assert_str(Camp.best_depth_tag(187)).is_equal("BEST 187m")
	assert_str(Camp.gold_tag(1240)).is_equal("1,240 G")
	assert_str(Camp.oil_tag(2)).is_equal("OIL x2")

func test_journal_tag_counts_against_the_real_series() -> void:
	var total := Lore.series().size()
	assert_str(Camp.journal_tag([])).is_equal("JOURNAL 0/%d" % total)
	var one: Array = [Lore.series()[0].id]
	assert_str(Camp.journal_tag(one)).is_equal("JOURNAL 1/%d" % total)

func test_relic_tag_is_empty_without_a_relic() -> void:
	# 유품이 없으면 표식을 아예 띄우지 않는다 — 빈 칸이 남는 것보다 낫다
	assert_str(Camp.relic_tag({})).is_equal("")
	assert_str(Camp.relic_tag({"row": 187, "items": []})).is_equal("RELIC 187m")

func test_gear_pips_match_the_shop_tracks() -> void:
	var pips := Camp.gear_pips({"pick": 2, "lamp": 1, "bag": 4, "boots": 3, "helmet": 1})
	assert_int(pips.size()).is_equal(Camp.GEAR_ORDER.size())
	assert_str(pips[0].label).is_equal("PICK")
	assert_int(pips[0].level).is_equal(2)
	assert_int(pips[0].max).is_equal(Economy.max_level("pick"))
	# 장화·헬멧은 3레벨까지, 나머지는 4레벨까지 — 칸 수가 트랙마다 다르다
	assert_int(pips[2].max).is_equal(4)
	assert_int(pips[3].max).is_equal(3)
	assert_int(pips[3].level).is_equal(3)

func test_gear_pips_fall_back_to_level_one() -> void:
	# 세이브가 오래돼 트랙이 비어 있어도 화면이 깨지지 않아야 한다
	var pips := Camp.gear_pips({})
	for p: Dictionary in pips:
		assert_int(p.level).is_equal(1)
