extends GdUnitTestSuite

const MailApp := preload("res://src/apps/mail.gd")

func before_test() -> void:
	GameState.reset()

func _make() -> Control:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	return m

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
