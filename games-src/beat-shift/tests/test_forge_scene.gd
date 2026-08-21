extends GdUnitTestSuite

func _scene() -> ForgeScene:
	var f: ForgeScene = auto_free(ForgeScene.new())
	add_child(f)
	return f

func test_spawn_cue_creates_ingot() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	assert_int(f.ingot_count()).is_equal(1)

func test_hit_consumes_matching_ingot() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.spawn_cue(12.0, 10.75)
	f.on_result("perfect", 10.0)
	assert_int(f.ingot_count()).is_equal(1)
	f.on_result("good", 12.0)
	assert_int(f.ingot_count()).is_equal(0)

func test_miss_consumes_ingot_and_stray_does_not() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.on_result("stray", -1.0)
	assert_int(f.ingot_count()).is_equal(1)
	f.on_result("miss", 10.0)
	assert_int(f.ingot_count()).is_equal(0)

func test_clear_cues() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.spawn_cue(12.0, 10.75)
	f.clear_cues()
	assert_int(f.ingot_count()).is_equal(0)
