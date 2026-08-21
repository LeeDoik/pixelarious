extends GdUnitTestSuite

func test_sfx_streams_loaded() -> void:
	for n in ["precue", "good", "miss", "whiff", "jingle", "gameover", "anvil_1", "anvil_2", "anvil_3", "anvil_4"]:
		assert_bool(Sfx.has_stream(n)).is_true()

func test_unknown_name_is_silent_noop() -> void:
	var before := Sfx.get_child_count()
	Sfx.play("no_such_sound")
	assert_int(Sfx.get_child_count()).is_equal(before)

func test_loop_assets_exist_for_all_bpm_steps() -> void:
	for bpm in Tuning.BPM_STEPS:
		assert_bool(ResourceLoader.exists("res://assets/sfx/loop_%d.wav" % int(bpm))).is_true()

func test_conductor_start_stop_and_clamp() -> void:
	Conductor.start_section(0)
	assert_float(Conductor.bpm).is_equal_approx(96.0, 0.001)
	assert_bool(Conductor.running).is_true()
	Conductor.start_section(99)
	assert_float(Conductor.bpm).is_equal_approx(160.0, 0.001)
	Conductor.stop()
	assert_bool(Conductor.running).is_false()

func test_conductor_resume_at_bar_offsets_time() -> void:
	Conductor.start_section(0)   # 96 BPM — 1마디 = 2.5s
	Conductor.stop()
	Conductor.resume_at_bar(3)
	assert_float(Conductor.song_time()).is_greater_equal(7.49)
	assert_float(Conductor.song_beats()).is_greater_equal(11.98)
	Conductor.stop()
