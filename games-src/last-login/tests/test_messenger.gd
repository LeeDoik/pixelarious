extends GdUnitTestSuite

const Messenger := preload("res://src/apps/messenger.gd")

func before_test() -> void:
	GameState.reset()

func _make() -> Control:
	var m: Control = auto_free(Messenger.new())
	add_child(m)
	return m

func _log_index(date: String) -> int:
	var logs := ContentDB.chat_logs()
	for i in logs.size():
		if String(logs[i].get("date", "")) == date:
			return i
	return -1

func test_opens_with_seulgi_online_and_her_first_line() -> void:
	var m := _make()
	assert_int(m.line_count()).is_equal(1)
	assert_bool(m.is_online()).is_true()
	assert_str(m.status_text()).contains("접속중")

func test_choice_node_fills_the_compose_box_and_sending_adds_my_line() -> void:
	var m := _make()
	assert_int(m.choice_count()).is_equal(0)   # 첫 노드는 자동 진행 중 — 고를 말이 없다
	m._auto_pending = false
	m._try_continue()                          # n02 — 선택지 두 개
	assert_int(m.choice_count()).is_equal(2)
	var before: int = m.line_count()
	m._on_choice(0)
	assert_int(m.line_count()).is_greater(before)
	assert_bool(GameState.has_flag("met_seulgi")).is_true()

func test_system_line_flips_the_contact_bar_to_offline() -> void:
	# 라이브 대화의 시스템 줄은 슬기가 접속을 끊는 그 한 줄뿐이라 표시줄이 따라가야 한다
	var m := _make()
	m._bubble("sys", "슬기님이 접속을 종료했습니다.")
	assert_bool(m.is_online()).is_false()
	assert_str(m.status_text()).contains("종료")

func test_past_logs_are_listed_and_read_one_at_a_time() -> void:
	# 예전에는 탭을 열기만 해도 네 대화가 전부 읽음 처리됐다. 기록물 하나
	# (chatlog:2002-10-05)가 여기 걸려 있어서, 그러면 엔딩 게이트가 공짜가 된다.
	var m := _make()
	assert_int(m.log_count()).is_equal(ContentDB.chat_logs().size())
	var idx := _log_index("2002-10-05")
	assert_int(idx).is_greater_equal(0)
	assert_bool(GameState.is_read("chatlog:2002-10-05")).is_false()
	m.open_log(idx)
	assert_int(m.log_line_count()).is_equal(ContentDB.chat_logs()[idx]["lines"].size())
	assert_bool(GameState.is_read("chatlog:2002-10-05")).is_true()
	assert_bool(GameState.is_read("chatlog:2002-06-26")).is_false()

func test_the_record_log_is_reachable_from_the_list() -> void:
	# records.json이 chatlog:2002-10-05를 기록물로 세므로 목록에 그 날짜가 있어야 한다
	assert_array(ContentDB.records()).contains(["chatlog:2002-10-05"])
	assert_int(_log_index("2002-10-05")).is_greater_equal(0)

func test_owner_and_others_read_as_different_speakers() -> void:
	# 지난 로그에서 성진(이 컴퓨터 주인)과 상대가 한눈에 갈려야 한다
	assert_bool("성진" in Messenger.SELF_SPEAKERS).is_true()
	assert_bool("나" in Messenger.SELF_SPEAKERS).is_true()
	assert_bool("민규" in Messenger.SELF_SPEAKERS).is_false()
	assert_bool(Messenger.SELF_COLOR.is_equal_approx(Messenger.OTHER_COLOR)).is_false()

func test_every_log_speaker_is_known_to_the_renderer() -> void:
	# 로그의 from 값이 시스템도 자기 자신도 아니면 상대 색으로 그려진다.
	# 새 화자가 들어와도 색이 없어 검게 나오는 일은 없지만, 시스템 줄이
	# 일반 발화로 새는 건 막아야 한다.
	var m := _make()
	for lg in ContentDB.chat_logs():
		for line in lg["lines"]:
			var who := String(line["from"])
			if who == "시스템":
				assert_bool(m._is_system(who)).override_failure_message(
					"시스템 줄이 일반 발화로 그려진다: " + who).is_true()
			else:
				assert_bool(m._is_system(who)).is_false()
