extends GdUnitTestSuite
## Sfx는 파일이 없으면 조용히 넘어간다 — 앰비언트가 통째로 빠져도 아무도 모른다.
## 코드가 이름으로 부르는 사운드가 실제로 있는지 여기서 못 박는다.

# mine.gd의 지층 테이블(심층 둘은 의도적 무음)과 finale_director.gd의 피날레 트랙
const REQUIRED_AMBIENCE := ["amb_surface", "amb_rock", "amb_fissure", "amb_finale"]
# surface.gd가 음악 채널로 트는 것
const REQUIRED_MUSIC := ["bgm_camp"]

func test_required_music_streams_exist() -> void:
	for name: String in REQUIRED_MUSIC:
		var path := "res://assets/sfx/%s.ogg" % name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"음악 %s.ogg가 없다 — Sfx.music이 조용히 스킵해 거점이 무음이 된다" % name).is_true()
		assert_object(load(path)).is_instanceof(AudioStreamOggVorbis)

func test_required_ambience_streams_exist() -> void:
	for name: String in REQUIRED_AMBIENCE:
		var path := "res://assets/sfx/%s.ogg" % name
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"앰비언트 %s.ogg가 없다 — Sfx.ambience가 조용히 스킵해 무음이 된다" % name).is_true()
		assert_object(load(path)).is_instanceof(AudioStreamOggVorbis)

func test_ambience_loops_are_long_enough_to_not_flutter() -> void:
	# 루프가 너무 짧으면 반복이 귀에 잡힌다. 크로스페이드 루프 기준 4초 이상.
	for name: String in REQUIRED_AMBIENCE:
		var s: AudioStreamOggVorbis = load("res://assets/sfx/%s.ogg" % name)
		assert_float(s.get_length()).override_failure_message(
			"%s 루프가 %.2f초로 너무 짧다" % [name, s.get_length()]).is_greater(4.0)

func test_music_and_ambience_are_separate_channels() -> void:
	# 한 채널이던 시절엔 나중에 튼 쪽이 앞을 덮어썼다 — 거점 음악이 새소리에 곧바로 지워졌다
	Sfx.ambience("amb_surface")
	Sfx.music("bgm_camp")
	assert_bool(Sfx._amb.playing).is_true()
	assert_bool(Sfx._music.playing).is_true()
	# 갱도 진입: 음악만 죽고 앰비언트는 계속 간다
	Sfx.music("")
	assert_bool(Sfx._music.playing).is_false()
	assert_bool(Sfx._amb.playing).is_true()
	Sfx.ambience("")

func test_missing_name_does_not_clobber_the_channel() -> void:
	# 없는 이름을 기억해버리면 파일이 들어온 뒤에도 같은 이름 호출이 조용히 무시된다
	Sfx.ambience("amb_rock")
	Sfx.ambience("no_such_sound")
	assert_bool(Sfx._amb.playing).is_true()
	Sfx.ambience("amb_rock")
	assert_bool(Sfx._amb.playing).is_true()
	Sfx.ambience("")
