extends GdUnitTestSuite

const MailApp := preload("res://src/apps/mail.gd")

func before_test() -> void:
	GameState.reset()

func _make() -> Control:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	return m

func _click_row(m: Control, id: String) -> void:
	## 목록에서 그 줄을 실제로 고른 것과 같은 경로 (item_selected → 이동)
	var row: TreeItem = m._list.get_root().get_first_child()
	while row != null:
		if String(row.get_metadata(0)) == id:
			row.select(2)
			return
		row = row.get_next()
	fail("no row for " + id)

func test_open_mail_marks_read() -> void:
	var m := _make()
	m.open_mail("m1")
	assert_bool(GameState.is_read("mail:m1")).is_true()

func test_attachment_locked_until_puzzle2() -> void:
	var m := _make()
	m.open_mail("m1")
	assert_bool(m.open_attachment("m1")).is_false()
	assert_bool(m.submit_password("nope")).is_false()
	assert_bool(m.submit_password("030703")).is_true()
	assert_bool(m.open_attachment("m1")).is_true()
	assert_bool(GameState.is_read("doc:doctrine_full")).is_true()

func test_list_shows_every_mail_and_counts_unread() -> void:
	var m := _make()
	var total := ContentDB.mails().size()
	assert_int(m.mail_count()).is_equal(total)
	assert_str(m.status_text()).is_equal("메일 %d통 · 안 읽음 %d통" % [total, total])
	m.open_mail("m1")
	assert_str(m.status_text()).is_equal("메일 %d통 · 안 읽음 %d통" % [total, total - 1])

func test_list_refresh_releases_its_signal_block() -> void:
	# 목록을 다시 그릴 때 신호를 막지 않으면 item_selected가 되돌아와
	# open_mail ↔ _refresh_list 가 무한히 돈다(스택 오버플로). 막은 뒤 풀지 않으면
	# 이번엔 목록 클릭이 죽는다 — 양쪽 다 조용히 망가지는 종류다.
	var m := _make()
	m.open_mail("m1")
	m.go_back()                      # 받은 편지함으로 돌아오며 목록을 다시 그린다
	assert_bool(m._list.is_blocking_signals()).is_false()

func test_header_carries_sender_date_subject() -> void:
	# 예전에는 이 세 줄이 본문과 같은 텍스트 덩어리에 섞여 있었다
	var m := _make()
	m.open_mail("m_demand_3")
	var head: String = m.header_text()
	assert_str(head).contains("보낸사람")
	assert_str(head).contains("날짜")
	assert_str(head).contains("2002-10-24")

func test_attachment_bar_only_shows_for_mails_that_have_one() -> void:
	# "첨부파일" 버튼이 첨부 없는 메일에서도 늘 떠 있던 것을 고친 자리
	var m := _make()
	m.open_mail("m_invite")
	assert_bool(m._attach_bar.visible).is_false()
	m.open_mail("m1")
	assert_bool(m._attach_bar.visible).is_true()
	assert_str(m._attach_label.text).contains("새빛자료.zip")
	assert_str(m._attach_label.text).contains("암호 필요")

func test_every_mail_has_the_fields_the_list_renders() -> void:
	# 목록이 보낸사람·제목·날짜 세 열을 그리므로 콘텐츠 쪽에서 비면 빈칸이 된다
	for mail in ContentDB.mails():
		for key in ["id", "from", "subject", "date"]:
			assert_bool(mail.has(key)).override_failure_message(
				"mail %s has no %s" % [mail.get("id", "?"), key]).is_true()
		assert_str(String(mail["date"])).has_length(10)   # YYYY-MM-DD

func test_toolbar_explains_why_it_cannot_send() -> void:
	# 답장·전달·삭제는 진짜로 동작할 수 없다. 죽은 버튼 대신 이유를 말한다.
	var m := _make()
	m._explain("보낼 수 없습니다", "이 계정으로는 메일을 보낼 수 없습니다.")
	assert_bool(m._dialog.is_open()).is_true()
	assert_str(m.last_message()).contains("보낼 수 없습니다")
	m._dialog.close()
	assert_bool(m._dialog.is_open()).is_false()

# ── 이동 (목록 ↔ 메일 한 장) ───────────────────────────────────────────────

func test_starts_on_the_inbox() -> void:
	var m := _make()
	assert_str(m.view_id()).is_equal("inbox")
	assert_bool(m.is_reading()).is_false()
	assert_bool(m._list.visible).is_true()
	assert_str(m.location_text()).is_equal("받은 편지함")
	assert_bool(m.can_go_back()).is_false()

func test_clicking_a_row_moves_the_whole_screen_to_that_mail() -> void:
	# 미리보기 칸이 아니라 화면이 통째로 넘어간다 — 목록은 자리를 비운다
	var m := _make()
	_click_row(m, "m_demand_3")
	assert_str(m.view_id()).is_equal("mail:m_demand_3")
	assert_bool(m.is_reading()).is_true()
	assert_bool(m._list.visible).is_false()
	assert_str(m.location_text()).contains("받은 편지함 > ")
	assert_str(m.location_text()).contains("3차 안내")

func test_back_returns_to_the_list_with_that_row_still_marked() -> void:
	var m := _make()
	m.open_mail("m1")
	assert_bool(m.can_go_back()).is_true()
	m.go_back()
	assert_str(m.view_id()).is_equal("inbox")
	assert_bool(m._list.visible).is_true()
	assert_str(String(m._list.get_selected().get_metadata(0))).is_equal("m1")
	assert_bool(m.can_go_forward()).is_true()
	m.go_forward()
	assert_str(m.view_id()).is_equal("mail:m1")

func test_inbox_button_comes_home_from_a_mail() -> void:
	var m := _make()
	m.open_mail("m_invite")
	m.open_inbox()
	assert_str(m.view_id()).is_equal("inbox")
	assert_bool(m.is_reading()).is_false()

func test_reopening_the_same_place_does_not_stack_history() -> void:
	# 같은 메일을 두 번 열었다고 뒤로가 두 번 필요해지면 안 된다
	var m := _make()
	m.open_mail("m1")
	m.open_mail("m1")
	m.go_back()
	assert_str(m.view_id()).is_equal("inbox")

func test_forward_history_is_cut_when_a_new_place_opens() -> void:
	var m := _make()
	m.open_mail("m1")
	m.go_back()
	m.open_mail("m_invite")
	assert_bool(m.can_go_forward()).is_false()
	m.go_back()
	assert_str(m.view_id()).is_equal("inbox")

## 성진이 자기에게 보낸 메일 — 첨부 zip은 슬기만 아는 날짜로 잠겨 있고, 풀면 탐색기 창이 열린다
func test_self_mail_zip_opens_an_explorer_window_after_her_birthday() -> void:
	var m := _make()
	var wm: WindowManager = auto_free(WindowManager.new())
	wm.add_to_group("window_manager")
	add_child(wm)
	m.open_mail("m_self")
	assert_bool(GameState.is_read("mail:m_self")).is_true()
	assert_bool(m.open_attachment("m_self")).is_false()
	assert_bool(m.submit_password("20020428")).is_false()   # 마이홈에 적힌 날짜 — 연도가 틀리다
	assert_bool(m.submit_password("19761201")).is_false()   # 오빠 생일
	assert_bool(m.submit_password("19810428")).is_true()
	assert_bool(GameState.has_flag("puzzle5_solved")).is_true()
	assert_bool(wm.is_open("zip:m_self")).is_true()
	assert_str(wm.window_title("zip:m_self")).is_equal("정리.zip")
	assert_str(m.view_id()).is_equal("mail:m_self")          # 메일 안의 자리는 그대로다

## 2002년의 메일은 본문 안의 주소가 문이었다 — 스팸의 "지금 바로 클릭"을 누르면 누리넷이 그 주소로 열린다
func test_spam_call_to_action_opens_the_browser_at_its_address() -> void:
	var m := _make()
	var wm: WindowManager = auto_free(WindowManager.new())
	wm.add_to_group("window_manager")
	wm.register_app("browser", "누리넷", func() -> Control: return BrowserApp.new())
	add_child(wm)
	m.open_mail("m_spam_1")
	var links: PackedStringArray = m.body_links()
	assert_bool("nurinet-event.co.kr/lucky3" in links).is_true()
	assert_str(m._view.get_parsed_text()).contains("지금 바로 클릭")      # 라벨은 남고
	assert_str(m._view.get_parsed_text()).not_contains("[[link:")        # 마커는 안 보인다
	assert_str(m._view.get_parsed_text()).contains("[백화점 상품권 100만원권]")   # 대괄호 글자는 그대로
	m._open_link("nurinet-event.co.kr/lucky3")
	assert_bool(wm.is_open("browser")).is_true()
	var b := wm.content_of("browser")
	assert_str(b.address_text()).is_equal("nurinet-event.co.kr/lucky3")
	assert_str(b.page_title()).contains("당첨")

## 맨몸 주소도 링크다 — 초대 메일 끝의 카페 공지 주소가 그렇다
func test_bare_addresses_in_a_mail_become_links() -> void:
	var m := _make()
	m.open_mail("m_invite")
	assert_bool("cafe.nurinet.co.kr/saebit/notice" in m.body_links()).is_true()
	m.open_mail("m_demand_3")
	assert_int(m.body_links().size()).is_equal(0)

func test_attachment_is_its_own_place() -> void:
	# 첨부를 열면 한 자리로 쌓이고, 뒤로 누르면 그 메일로 돌아온다
	var m := _make()
	m.open_mail("m1")
	m.open_attachment("m1")             # 잠김 → 암호 대화상자
	m.submit_password("030703")
	assert_str(m.view_id()).is_equal("attach:m1")
	assert_str(m.location_text()).contains("새빛자료.zip")
	assert_str(m.header_text()).contains("첨부")
	assert_bool(m._attach_bar.visible).is_false()   # 이미 그 문서를 보고 있다
	m.go_back()
	assert_str(m.view_id()).is_equal("mail:m1")
	assert_str(m.header_text()).contains("보낸사람")
	assert_bool(m._attach_bar.visible).is_true()

func test_unknown_mail_falls_back_to_the_inbox() -> void:
	var m := _make()
	m.open_mail("nope")
	assert_str(m.view_id()).is_equal("inbox")
	assert_bool(m.is_reading()).is_false()
