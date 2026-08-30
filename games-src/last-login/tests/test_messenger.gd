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

## 창을 열면 대화창이 아니라 대화 목록이 먼저다 — 라이브 한 칸 + 남아 있는 지난 대화들
func test_opens_on_the_room_list_with_every_conversation_in_it() -> void:
	var m := _make()
	assert_str(m.current_room()).is_equal("")
	assert_int(m.room_count()).is_equal(ContentDB.chat_logs().size() + 1)

func test_seulgi_sits_in_the_online_group_and_drops_out_when_she_logs_off() -> void:
	var m := _make()
	assert_bool("live" in m.online_room_ids()).is_true()
	m._bubble("sys", "슬기님이 접속을 종료했습니다.")
	assert_int(m.online_room_ids().size()).is_equal(0)
	# 접속을 끊어도 그 대화는 목록에서 사라지지 않는다 — 오프라인 칸으로 내려갈 뿐이다
	assert_int(m.room_count()).is_equal(ContentDB.chat_logs().size() + 1)

## 목록을 보는 동안에도 슬기는 계속 말한다 — 안 본 줄이 쌓이는 게 보여야 열어본다
func test_lines_arriving_while_the_list_shows_pile_up_as_unread() -> void:
	var m := _make()
	assert_int(m.unread_count()).is_greater(0)
	m.open_room("live")
	assert_str(m.current_room()).is_equal("live")
	assert_int(m.unread_count()).is_equal(0)
	m.show_list()
	assert_str(m.current_room()).is_equal("")

func test_opening_a_past_log_switches_rooms_without_touching_her_status() -> void:
	var m := _make()
	m.open_log(_log_index("2002-06-26"))
	assert_str(m.current_room()).is_equal("chatlog:2002-06-26")
	assert_bool(m.is_online()).is_true()

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

## 숨은 엔딩의 유일한 조건이 화면에 안 보이면 아무도 그 엔딩을 보지 못한다
func test_records_counter_is_visible_and_counts_up() -> void:
	var m := _make()
	var total := ContentDB.records().size()
	assert_int(total).is_greater(0)
	assert_str(m.records_text()).contains("0 / %d" % total)
	GameState.mark_read(String(ContentDB.records()[0]))
	assert_str(m.records_text()).contains("1 / %d" % total)

## "(대답하지 않는다)"는 지문이다 — 이 컴퓨터에 남는 로그에 발화로 찍히면 안 된다
func test_unspoken_choice_leaves_no_line_in_the_log() -> void:
	var m := _make()
	m._auto_pending = false
	m._try_continue()                 # n02
	m._on_choice(1)                   # (대답하지 않는다)
	for line in m.line_texts():
		assert_str(line).not_contains("대답하지 않는다")

func test_spoken_choice_still_lands_in_the_log() -> void:
	var m := _make()
	m._auto_pending = false
	m._try_continue()
	m._on_choice(0)                   # 이 컴퓨터 주운 사람인데요
	var joined := "".join(m.line_texts())
	assert_str(joined).contains("주운 사람인데요")

## 조건이 안 찬 선택지는 보이지 않는다 — 점검표를 찾은 사람에게만 그 질문이 생긴다
func test_gated_choice_appears_only_with_its_flag() -> void:
	var m := _make()
	var node := {"from": "seulgi", "text": "t", "choices": [
		{"text": "a", "next": "x"},
		{"text": "b", "next": "y", "require": "intruder_found"}]}
	m._render_choices(node)
	assert_int(m.choice_count()).is_equal(1)
	GameState.set_flag("intruder_found")
	m._render_choices(node)
	assert_int(m.choice_count()).is_equal(2)

## 파일을 읽으면 "찾은 것 말하기"가 생기고, 말하면 사라진다 — 말하지 않는 것도 선택이다
func test_reading_a_file_offers_to_tell_and_telling_uses_it_up() -> void:
	var m := _make()
	var tell: Dictionary = ContentDB.tells()[0]
	var cid := String(tell["cid"])
	m._auto_pending = false
	m._try_continue()                          # n02 — 선택지 노드, 본선이 멈춰 있다
	assert_int(m.tell_count()).is_equal(0)
	GameState.mark_read(cid)
	m._refresh_choices()
	assert_int(m.tell_count()).is_equal(1)
	assert_int(m.choice_count()).is_equal(2 + 1)   # 본선 둘 + 말하기 하나
	m._on_tell(cid)
	assert_bool(GameState.has_flag("told:" + cid)).is_true()
	var joined := "".join(m.line_texts())
	assert_str(joined).contains(String(tell["say"]))          # 내 말풍선
	assert_str(joined).contains(String(ContentDB.chat_thread()["nodes"][tell["node"]]["text"]))
	assert_bool(m._cp.in_detour()).is_true()
	m._refresh_choices()
	assert_int(m.tell_count()).is_equal(0)                    # 한 번 말한 건 다시 안 뜬다

## 응답이 끝나면 본선 선택지가 그대로 돌아온다 — 본선 대사는 다시 찍히지 않는다
func test_after_the_reply_the_main_choices_come_back() -> void:
	var m := _make()
	m._auto_pending = false
	m._try_continue()                          # n02
	var node := {"from": "seulgi", "text": "끝 응답"}
	m._cp._nodes["__t_end"] = node
	var before: int = m.line_count()
	m._cp.detour("__t_end")
	m._show_current()
	assert_int(m.line_count()).is_equal(before + 1)
	assert_bool(m._auto_pending).is_true()     # 돌아오는 잠깐
	m._auto_pending = false
	m._cp.pop_detour()
	m._after_detour()
	assert_int(m.line_count()).is_equal(before + 1)          # 본선 "오빠 맞지"는 다시 안 나온다
	assert_int(m.choice_count()).is_equal(2)
	assert_str(m._cp.current_id()).is_equal("n02")

## 본선이 퍼즐 앞에 멈추면 "입력 중"이 아니라 말해줄 수 있는 것들이 보인다
func test_a_locked_main_line_shows_tells_instead_of_typing() -> void:
	var m := _make()
	var cid := String(ContentDB.tells()[0]["cid"])
	m._cp._nodes["__a"] = {"from": "seulgi", "text": "q", "next": "__b"}
	m._cp._nodes["__b"] = {"from": "seulgi", "text": "t", "require": "puzzle1_solved"}
	m._cp._cur = "__a"
	m._auto_pending = false                    # 첫 노드의 자동 진행 타이머는 끝난 것으로
	GameState.mark_read(cid)
	m._render_choices(m._cp.current())
	assert_bool(m._auto_pending).is_false()
	assert_int(m.tell_count()).is_equal(1)

## 슬기가 접속을 끊으면 말해줄 사람이 없다
func test_no_tells_once_she_is_offline() -> void:
	var m := _make()
	GameState.mark_read(String(ContentDB.tells()[0]["cid"]))
	m._bubble("sys", "슬기님이 접속을 종료했습니다.")
	m._render_choices({"from": "seulgi", "text": "t"})
	assert_int(m.tell_count()).is_equal(0)

## 숫자 키 슬롯은 본선 선택지 뒤에 이어 붙는다
func test_tell_slots_continue_after_the_choice_slots() -> void:
	var m := _make()
	var cid := String(ContentDB.tells()[0]["cid"])
	m._auto_pending = false
	m._try_continue()                          # n02 — 선택지 둘
	GameState.mark_read(cid)
	m._refresh_choices()
	assert_int(m._choice_slots.size()).is_equal(2)
	assert_int(m._tell_slots.size()).is_equal(1)
	assert_str(m._tell_slots[0]).is_equal(cid)
	var rows := []
	for c in m._choice_box.get_children():
		if c is Button and c.visible:
			rows.append(c)
	assert_str(String(rows[2].text)).starts_with("3.")

## 파일 내용을 짚는 힌트는 그 파일을 말해준 뒤에만 — 그 전엔 대체 문장
func test_gated_hint_falls_back_until_the_player_has_told_her() -> void:
	var m := _make()
	var h := {"text": "내용을 짚는 힌트", "require": "told:mail:m_welcome", "fallback": "습관만 말하는 힌트"}
	assert_str(m._hint_text(h)).is_equal("습관만 말하는 힌트")
	GameState.set_flag("told:mail:m_welcome")
	assert_str(m._hint_text(h)).is_equal("내용을 짚는 힌트")
	assert_str(m._hint_text("그냥 문자열")).is_equal("그냥 문자열")

## 선택지에 붙는 번호는 화면에 보이는 순서다. 걸러진 선택지 때문에 번호와
## 원래 인덱스가 어긋나면 숫자 키가 엉뚱한 말을 보낸다.
func test_number_slots_follow_what_is_on_screen_not_the_raw_index() -> void:
	var m := _make()
	var node := {"from": "seulgi", "text": "t", "choices": [
		{"text": "a", "next": "x"},
		{"text": "b", "next": "y", "require": "intruder_found"},
		{"text": "c", "next": "z"}]}
	m._render_choices(node)
	assert_int(m.choice_count()).is_equal(2)
	assert_int(m._choice_slots.size()).is_equal(2)
	assert_int(m._choice_slots[0]).is_equal(0)
	assert_int(m._choice_slots[1]).is_equal(2)   # 2번 키 = 세 번째 선택지
