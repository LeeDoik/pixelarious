class_name Messenger
extends Control
## PC통신: 대화 탭(상대 표시줄 + 대화 로그 + 보낼 말) / 지난 대화 탭(대화 목록 + 전문).
## 이 시대 메신저의 문법대로 말풍선이 아니라 "닉네임 줄 + 들여쓴 본문"으로 쌓는다.
## 힌트는 슬기가 보낸 줄로 섞여 들어온다.

const STATUS_ON := "res://assets/img/icons/status_on.png"
const STATUS_OFF := "res://assets/img/icons/status_off.png"

const SPEAKER_NAMES := {"seulgi": "슬기", "player": "나"}
const SYSTEM_SPEAKERS := ["sys", "시스템"]
## 이 컴퓨터의 주인 쪽 발화 — 라이브 대화의 "나"와 지난 로그의 "성진"은 같은 자리다
const SELF_SPEAKERS := ["player", "나", "성진"]
const SELF_COLOR := Color("9c3a24")
const OTHER_COLOR := Color("1b4d8f")
const INDENT := 14
const COMPOSE_MIN_H := 76

var _cp: ChatPlayer
var _hints: HintEngine
var _chat_box: VBoxContainer
var _choice_box: VBoxContainer
var _scroll: ScrollContainer
var _status_icon: TextureRect
var _status_label: Label
var _log_list: ItemList
var _log_view: VBoxContainer
var _log_scroll: ScrollContainer
var _online := true
var _auto_pending := false
var _catching_up := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(_build_live_tab())
	tabs.add_child(_build_logs_tab())
	add_child(tabs)
	_start_script()

# ── 대화 탭 ───────────────────────────────────────────────────────────────

func _build_live_tab() -> Control:
	var live := VBoxContainer.new()
	live.name = "대화"
	live.add_theme_constant_override("separation", 6)
	live.add_child(_build_contact_bar())
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_chat_box)
	pad.add_child(_scroll)
	field.add_child(pad)
	live.add_child(field)
	live.add_child(_build_compose())
	return live

func _build_contact_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_status_icon = TextureRect.new()
	_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_status_icon.custom_minimum_size = Vector2(16, 16)
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status_icon)
	var who := Label.new()
	who.text = "슬기"
	who.add_theme_font_size_override("font_size", 15)
	row.add_child(who)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_status_label)
	bar.add_child(row)
	_set_online(true)
	return bar

func _build_compose() -> Control:
	# 자유 입력이 없는 게임이라 메신저의 입력칸 자리를 "고를 수 있는 말"이 대신한다
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var caption := Label.new()
	caption.text = "보낼 말"
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	box.add_child(caption)
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.custom_minimum_size = Vector2(0, COMPOSE_MIN_H)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 0)
	pad.add_child(_choice_box)
	field.add_child(pad)
	box.add_child(field)
	return box

func _set_online(on: bool) -> void:
	_online = on
	var path := STATUS_ON if on else STATUS_OFF
	if ResourceLoader.exists(path):
		_status_icon.texture = load(path)
	_status_label.text = "· 접속중" if on else "· 접속 종료"

func status_text() -> String:
	return _status_label.text

func is_online() -> bool:
	return _online

# ── 지난 대화 탭 ──────────────────────────────────────────────────────────

func _build_logs_tab() -> Control:
	var split := HSplitContainer.new()
	split.name = "지난 대화"
	_log_list = ItemList.new()
	_log_list.custom_minimum_size = Vector2(190, 0)
	_log_list.add_theme_font_size_override("font_size", 14)
	_log_list.item_selected.connect(open_log)
	split.add_child(_log_list)
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	_log_scroll = ScrollContainer.new()
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_view = VBoxContainer.new()
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.add_theme_constant_override("separation", 8)
	_log_scroll.add_child(_log_view)
	pad.add_child(_log_scroll)
	field.add_child(pad)
	split.add_child(field)
	_refresh_log_list()
	_show_log_placeholder()
	return split

func _show_log_placeholder() -> void:
	var l := Label.new()
	l.text = "왼쪽에서 대화를 고르세요."
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	_log_view.add_child(l)

func _refresh_log_list() -> void:
	_log_list.clear()
	for lg in ContentDB.chat_logs():
		var date := String(lg.get("date", ""))
		var read := GameState.is_read("chatlog:" + date)
		var i := _log_list.add_item("%s  %s  %s" % ["  " if read else "●", date.substr(5), String(lg.get("with", ""))])
		_log_list.set_item_metadata(i, date)
		# 안 읽은 대화가 목록에서 먼저 눈에 띄어야 한다 (기록물 하나가 여기 숨어 있다)
		_log_list.set_item_custom_fg_color(i, NuriTheme.TEXT_DIM if read else NuriTheme.TEXT)

func open_log(index: int) -> void:
	var logs := ContentDB.chat_logs()
	if index < 0 or index >= logs.size():
		return
	var lg: Dictionary = logs[index]
	for c in _log_view.get_children():
		_log_view.remove_child(c)
		c.queue_free()
	_log_view.add_child(_log_header(lg))
	_log_view.add_child(_rule())
	for line in lg["lines"]:
		_log_view.add_child(_make_line(String(line["from"]), String(line["text"]), ""))
	GameState.mark_read("chatlog:" + String(lg.get("date", "")))
	_refresh_log_list()
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = 0

func _log_header(lg: Dictionary) -> Control:
	var l := Label.new()
	l.text = "%s · %s" % [String(lg.get("date", "")), String(lg.get("with", ""))]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	return l

func log_count() -> int:
	return _log_list.item_count

func log_line_count() -> int:
	return maxi(_log_view.get_child_count() - 2, 0)   # 머리글 + 구분선 제외

# ── 줄 그리기 ─────────────────────────────────────────────────────────────

func _make_line(from: String, text: String, stamp: String) -> Control:
	if _is_system(from):
		return _system_line(text)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = _display_name(from) + ("" if stamp == "" else " (%s)" % stamp)
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", SELF_COLOR if from in SELF_SPEAKERS else OTHER_COLOR)
	box.add_child(head)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", INDENT)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	indent.add_child(body)
	box.add_child(indent)
	return box

func _system_line(text: String) -> Control:
	# 접속/종료 같은 시스템 알림은 발화가 아니라 사건이다 — 가운데 줄로 끊어 보여준다
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_rule())
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(l)
	row.add_child(_rule())
	return row

func _rule() -> Control:
	var sep := HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := StyleBoxLine.new()
	line.color = NuriTheme.GUIDE
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	return sep

func _display_name(from: String) -> String:
	return String(SPEAKER_NAMES.get(from, from))

func _is_system(from: String) -> bool:
	return from in SYSTEM_SPEAKERS

func _stamp() -> String:
	# 작업표시줄 시계와 같은 출처 (접속 지역 실제 시각)
	return Time.get_time_string_from_system().substr(0, 5)

# ── 스크립트 재생 ─────────────────────────────────────────────────────────

func _start_script() -> void:
	_cp = ChatPlayer.new(ContentDB.chat_thread(), GameState)
	_hints = HintEngine.new(func() -> int: return Time.get_ticks_msec())
	_hints.hint_ready.connect(_on_hint)
	GameState.flag_changed.connect(func(_n):
		_hints.set_gate(_current_gate())
		if not _auto_pending:
			call_deferred("_try_continue"))
	_hints.set_gate(_current_gate())
	_catching_up = GameState.has_flag("met_seulgi")
	_show_current()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_hints.poll)
	add_child(timer)

func _current_gate() -> String:
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		if not GameState.has_flag(pid + "_solved"):
			return pid
	return ""

func _bubble(from: String, text: String) -> void:
	_chat_box.add_child(_make_line(from, text, _stamp()))
	if _is_system(from):
		# 라이브 대화의 시스템 줄은 슬기가 접속을 끊는 그 한 줄뿐이다
		_set_online(false)
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _show_current() -> void:
	var n := _cp.current()
	if n["from"] == "sys":
		_bubble("sys", n["text"])
	else:
		AudioDirector.play_sfx("msg")
		_bubble(n["from"], n["text"])
	_render_choices(n)

func _render_choices(n: Dictionary) -> void:
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()
	if n.has("choices"):
		for i in n["choices"].size():
			_choice_box.add_child(_choice_row(String(n["choices"][i]["text"]), i))
	elif n.has("next"):
		_auto_pending = true
		_choice_box.add_child(_waiting_row())
		get_tree().create_timer((n.get("delay_ms", 900) if not _catching_up else 50) / 1000.0).timeout.connect(func():
			_auto_pending = false
			_try_continue())

func _choice_row(text: String, index: int) -> Button:
	var b := Button.new()
	b.text = "› " + text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	flat.content_margin_top = 4
	flat.content_margin_bottom = 4
	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = NuriTheme.SELECT
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_hover_color", NuriTheme.SELECT_TEXT)
	b.add_theme_color_override("font_pressed_color", NuriTheme.SELECT_TEXT)
	b.pressed.connect(_on_choice.bind(index))
	return b

func _waiting_row() -> Control:
	var l := Label.new()
	l.text = "슬기님이 입력 중입니다..."
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	return l

func choice_count() -> int:
	var n := 0
	for c in _choice_box.get_children():
		if c is Button:
			n += 1
	return n

func line_count() -> int:
	return _chat_box.get_child_count()

func _on_choice(i: int) -> void:
	_bubble("player", _cp.current()["choices"][i]["text"])
	_cp.choose(i)
	_show_current()

func _try_continue() -> void:
	if _auto_pending:
		return
	if _cp.advance():
		_show_current()
	elif _cp.current().has("next"):
		_catching_up = false

func _on_hint(puzzle_id: String, level: int) -> void:
	var hints: Array = ContentDB.puzzle(puzzle_id).get("hints", [])
	if level - 1 < hints.size():
		AudioDirector.play_sfx("msg")
		_bubble("seulgi", hints[level - 1])
