extends GdUnitTestSuite

func test_streams_loaded() -> void:
	for n in ["hop", "capture", "warn", "death", "combo", "ambient"]:
		assert_bool(Sfx.has_stream(n)).is_true()

func test_unknown_name_is_silent_noop() -> void:
	var before := Sfx.get_child_count()
	Sfx.play("no_such_sound")   # 미등록 이름은 플레이어를 만들지 않고 무시
	assert_int(Sfx.get_child_count()).is_equal(before)
