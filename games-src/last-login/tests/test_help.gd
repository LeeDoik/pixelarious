extends GdUnitTestSuite

const HelpApp := preload("res://src/apps/help.gd")

func _make() -> Control:
	var h: Control = auto_free(HelpApp.new())
	add_child(h)
	return h

## 조작법은 슬기가 아니라 OS가 가르친다 — 네 앱의 주제가 다 있어야 한다
func test_every_app_has_a_help_topic() -> void:
	var titles := PackedStringArray()
	for t in ContentDB.help_topics():
		titles.append(String(t["title"]))
	var joined := " ".join(titles)
	for word in ["탐색기", "누리넷", "휴지통", "누리메일"]:
		assert_str(joined).override_failure_message("도움말에 '%s' 주제가 없다" % word).contains(word)

func test_opens_on_the_first_topic_and_switches() -> void:
	var h := _make()
	assert_int(h.topic_count()).is_greater(3)
	assert_int(h.current_topic()).is_equal(0)
	assert_str(h.body_shown()).is_not_empty()
	h.show_topic(2)
	assert_int(h.current_topic()).is_equal(2)
	assert_str(h.body_shown()).is_equal(String(ContentDB.help_topics()[2]["body"]))

## 슬기가 말하면 경계 위반이 되는 조작법 셋 — 캐시 주소·복원·주소 직접 입력 — 이 여기엔 있어야 한다
func test_the_help_carries_what_seulgi_may_not_say() -> void:
	var all := ""
	for t in ContentDB.help_topics():
		all += String(t["body"]) + "\n"
	for word in ["주소 단위", "복원", "직접 입력"]:
		assert_str(all).override_failure_message("도움말에 '%s' 설명이 없다" % word).contains(word)

## 도움말은 바탕화면 아이콘이 아니다 — 시작 메뉴에서만 연다
func test_desktop_opens_help_as_a_window_not_an_icon() -> void:
	var Desktop := load("res://src/desktop/desktop.gd")
	var d: Control = auto_free(Desktop.new())
	add_child(d)
	var icons_before: int = d.icon_count()
	d.open_help()
	assert_bool(d.wm.is_open("help")).is_true()
	assert_int(d.icon_count()).is_equal(icons_before)
	assert_str(d.wm.window_title("help")).contains("도움말")
