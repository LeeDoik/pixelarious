extends GdUnitTestSuite

const P := "user://test_isb_save.json"

func after_test() -> void:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(P)

func test_default_profile_schema() -> void:
	var p := Persistence.default_profile()
	assert_int(p.version).is_equal(1)
	assert_int(p.upgrades.pick).is_equal(1)
	assert_str(p.settings.lang).is_equal("ko")
	assert_int(p.miner_no).is_equal(1)

func test_roundtrip() -> void:
	var p := Persistence.default_profile()
	p.gold = 777
	p.journals_found = ["han_1"]
	p.relic = {"row": 150, "items": [2, 3]}
	Persistence.save_profile(P, p)
	var q := Persistence.load_profile(P)
	assert_int(q.gold).is_equal(777)
	assert_that(q.journals_found).contains(["han_1"])
	assert_int(int(q.relic.row)).is_equal(150)

func test_load_missing_returns_default() -> void:
	assert_int(Persistence.load_profile("user://no_such_file.json").gold).is_equal(0)

func test_load_fills_missing_keys() -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "gold": 5}))
	f.close()
	var q := Persistence.load_profile(P)
	assert_int(q.gold).is_equal(5)
	assert_int(q.upgrades.lamp).is_equal(1)  # 누락 키가 default로 채워짐
