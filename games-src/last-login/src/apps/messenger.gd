class_name Messenger
extends Control
## PC통신: 대화 목록(온라인/오프라인) → 고른 상대의 대화창.
## 이 시대 메신저의 구조 그대로 — 친구 목록 창이 켜져 있고 거기서 상대를 눌러야
## 대화창이 열린다 — 를 한 창 안의 화면 전환으로 옮겼다.
## 라이브 대화는 목록을 보고 있는 동안에도 계속 흐르고, 안 본 줄은 빨간 점으로 쌓인다.
## 힌트는 슬기가 보낸 줄로 섞여 들어온다.

const STATUS_ON := "res://assets/img/icons/status_on.png"
const STATUS_OFF := "res://assets/img/icons/status_off.png"

const SPEAKER_NAMES := {"seulgi": "슬기", "player": "나"}
const SYSTEM_SPEAKERS := ["sys", "시스템"]
## 이 컴퓨터의 주인 쪽 발화 — 라이브 대화의 "나"와 지난 로그의 "성진"은 같은 자리다
const SELF_SPEAKERS := ["player", "나", "성진"]
const SELF_COLOR := Color("9c3a24")
const OTHER_COLOR := Color("1b4d8f")

const OWNER_NAME := "성진"        # 이 계정의 대화명 — 슬기 쪽에는 이 이름이 켜져 있는 것으로 보인다
const LIVE_ROOM := "live"
const LIVE_PARTNER := "슬기"
const LOG_PREFIX := "chatlog:"

const CHAT_BG := Color("e6e2d6")      # 대화창 바닥 — 말풍선이 떠 보이게 종이색보다 한 톤 어둡다
const SELF_BUBBLE := Color("fbeadd")
const OTHER_BUBBLE := Color("fdfdf8")
const RULE_COLOR := Color("bdb8a8")
const UNREAD_COLOR := Color("c23b1e")

const BUBBLE_MAX_RATIO := 0.72
const BUBBLE_MIN_W := 56.0
const ROOM_ROW_H := 48
const COMPOSE_MIN_H := 92
const PREVIEW_CHARS := 26

var _cp: ChatPlayer
var _hints: HintEngine

# 목록 화면
var _list_view: VBoxContainer
var _rooms_box: VBoxContainer
var _me_icon: TextureRect
var _badge_label: Label

# 대화창 화면
var _room_view: VBoxContainer
var _hdr_icon: TextureRect
var _hdr_name: Label
var _status_label: Label
var _hdr_note: Label
var _scroll: ScrollContainer
var _chat_box: VBoxContainer
var _log_scroll: ScrollContainer
var _log_view: VBoxContainer
var _compose: Control
var _choice_box: VBoxContainer
var _log_note: Control

var _records_label: Label

var _row_parts: Dictionary = {}   # 대화 id -> 그 줄에서 갈아 끼우는 라벨들
var _rooms_built := false
var _built_online := true

var _room_id := ""            # "" = 목록 화면
var _online := true
var _unread := 0
var _live_preview := ""
var _live_stamp := ""
var _last_live_from := ""
var _choice_slots: Array[int] = []
var _auto_pending := false
var _catching_up := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	root.add_child(_build_list_view())
	root.add_child(_build_room_view())
	root.add_child(_build_statusbar())
	_room_view.visible = false
	_refresh_rooms()
	_start_script()

# ── 대화 목록 ─────────────────────────────────────────────────────────────

func _build_list_view() -> Control:
	_list_view = VBoxContainer.new()
	_list_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_view.add_theme_constant_override("separation", 6)
	_list_view.add_child(_build_me_bar())
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", _sunken(NuriTheme.FIELD))
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rooms_box = VBoxContainer.new()
	_rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rooms_box.add_theme_constant_override("separation", 0)
	scroll.add_child(_rooms_box)
	field.add_child(scroll)
	_list_view.add_child(field)
	return _list_view

## 목록 맨 위는 내 자리다 — 슬기 쪽에서는 여기 적힌 이름이 말을 걸어오는 것으로 보인다
func _build_me_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_me_icon = _icon_rect(_status_tex(true), 16)
	row.add_child(_me_icon)
	var who := Label.new()
	who.text = OWNER_NAME
	who.add_theme_font_size_override("font_size", 15)
	row.add_child(who)
	var mine := Label.new()
	mine.text = "· 접속중"
	mine.add_theme_font_size_override("font_size", 14)
	mine.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(mine)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 13)
	_badge_label.add_theme_color_override("font_color", UNREAD_COLOR)
	row.add_child(_badge_label)
	bar.add_child(row)
	return bar

## 라이브 대화 한 칸 + 이 컴퓨터에 남은 지난 대화들. 최근 것이 위로 온다.
func _room_list() -> Array:
	var out: Array = [{
		"id": LIVE_ROOM, "kind": "live", "name": LIVE_PARTNER, "date": "",
		"preview": _live_preview if _live_preview != "" else "대화를 시작합니다",
		"when": _live_stamp,
	}]
	var logs := ContentDB.chat_logs()
	var order: Array = []
	for i in logs.size():
		order.append(i)
	order.sort_custom(func(a, b) -> bool:
		return String(logs[a].get("date", "")) > String(logs[b].get("date", "")))
	for i in order:
		var lg: Dictionary = logs[i]
		var date := String(lg.get("date", ""))
		out.append({
			"id": LOG_PREFIX + date, "kind": "log", "index": i, "name": String(lg.get("with", "")),
			"date": date, "preview": _log_preview(lg), "when": date,
		})
	return out

func _log_preview(lg: Dictionary) -> String:
	for line in lg.get("lines", []):
		if not _is_system(String(line["from"])):
			return _elide(String(line["text"]), PREVIEW_CHARS)
	return ""

func _room_by_id(id: String) -> Dictionary:
	for r in _room_list():
		if String(r["id"]) == id:
			return r
	return {}

## 목록은 슬기가 한 줄 보낼 때마다 손봐야 한다. 매번 다시 짓지 않고 —
## 줄마다 다섯 칸씩 버리면 금세 쓰레기가 쌓인다 — 칸의 글자만 갈아 끼운다.
## 다시 짓는 건 접속 상태가 바뀌어 온라인/오프라인 묶음이 갈릴 때뿐이다.
func _refresh_rooms() -> void:
	if not is_instance_valid(_rooms_box):
		return
	if not _rooms_built or _built_online != _online:
		_rebuild_rooms()
	else:
		_update_rows()
	if is_instance_valid(_badge_label):
		_badge_label.text = "새 메시지 %d" % _unread if _unread > 0 else ""

func _update_rows() -> void:
	for r in _room_list():
		var id := String(r["id"])
		if not _row_parts.has(id):
			continue
		var parts: Dictionary = _row_parts[id]
		var live: bool = r["kind"] == "live"
		var unread: int = _unread if live else (0 if GameState.is_read(id) else 1)
		(parts["preview"] as Label).text = _elide(String(r["preview"]), PREVIEW_CHARS)
		(parts["when"] as Label).text = String(r["when"])
		(parts["name"] as Label).add_theme_color_override("font_color",
			NuriTheme.TEXT if (unread > 0 or live) else NuriTheme.TEXT_DIM)
		var dot: Label = parts["dot"]
		dot.visible = unread > 0
		dot.text = "●" if (not live or unread <= 1) else "● %d" % unread

## 통째로 다시 짓는다. 여기 오는 길에는 목록 단추의 pressed 신호가 없다
## (신호 안에서 부르면 자기를 부순다) — 그래서 다음 프레임까지 미루지 않고 바로 지운다.
func _rebuild_rooms() -> void:
	for c in _rooms_box.get_children():
		_rooms_box.remove_child(c)
		c.free()
	_row_parts.clear()
	_rooms_built = true
	_built_online = _online
	var online: Array = []
	var offline: Array = []
	for r in _room_list():
		# 지난 대화의 상대는 오래전에 로그아웃했다 — 여기 켜져 있는 건 슬기뿐이다
		if r["kind"] == "live" and _online:
			online.append(r)
		else:
			offline.append(r)
	if not online.is_empty():
		_rooms_box.add_child(_group_head("온라인", online.size()))
		for r in online:
			_rooms_box.add_child(_room_row(r))
	if not offline.is_empty():
		_rooms_box.add_child(_group_head("오프라인", offline.size()))
		for r in offline:
			_rooms_box.add_child(_room_row(r))

func _group_head(title: String, n: int) -> Control:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = NuriTheme.FACE.lerp(NuriTheme.FIELD, 0.35)
	s.border_color = NuriTheme.GUIDE
	s.border_width_bottom = 1
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = "▼ %s (%d)" % [title, n]
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	p.add_child(l)
	return p

func _room_row(r: Dictionary) -> Button:
	var id := String(r["id"])
	var live: bool = r["kind"] == "live"
	var on: bool = live and _online
	# 안 읽은 대화가 목록에서 먼저 눈에 띄어야 한다 (기록물 하나가 여기 숨어 있다)
	var unread: int = _unread if live else (0 if GameState.is_read(id) else 1)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	b.custom_minimum_size = Vector2(0, ROOM_ROW_H)
	b.set_meta("room_kind", String(r["kind"]))
	b.set_meta("room_id", id)
	b.set_meta("room_online", on)
	b.tooltip_text = "%s%s" % [String(r["name"]),
		"" if String(r["date"]) == "" else " · " + String(r["date"])]
	b.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _row_style(NuriTheme.SELECT.lerp(NuriTheme.FIELD, 0.82)))
	b.add_theme_stylebox_override("pressed", _row_style(NuriTheme.SELECT.lerp(NuriTheme.FIELD, 0.68)))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 5)
	pad.add_theme_constant_override("margin_bottom", 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon_rect(_status_tex(on), 16))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := Label.new()
	name_l.text = String(r["name"])
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color",
		NuriTheme.TEXT if (unread > 0 or live) else NuriTheme.TEXT_DIM)
	col.add_child(name_l)
	var prev_l := Label.new()
	prev_l.text = _elide(String(r["preview"]), PREVIEW_CHARS)
	prev_l.add_theme_font_size_override("font_size", 13)
	prev_l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	prev_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(prev_l)
	row.add_child(col)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var when_l := _right_label(String(r["when"]), NuriTheme.TEXT_DIM)
	right.add_child(when_l)
	var dot := _right_label("●" if (not live or unread <= 1) else "● %d" % unread, UNREAD_COLOR)
	dot.visible = unread > 0
	right.add_child(dot)
	row.add_child(right)
	pad.add_child(row)
	b.add_child(pad)
	b.pressed.connect(open_room.bind(id))
	_row_parts[id] = {"name": name_l, "preview": prev_l, "when": when_l, "dot": dot}
	return b

func _right_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = NuriTheme.GUIDE
	s.border_width_bottom = 1
	return s

# ── 대화창 ────────────────────────────────────────────────────────────────

func _build_room_view() -> Control:
	_room_view = VBoxContainer.new()
	_room_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_view.add_theme_constant_override("separation", 6)
	_room_view.add_child(_build_room_header())
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", _sunken(CHAT_BG))
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 오간 말이 몇 줄뿐일 때도 대화는 창 아래에 붙어 있다 — 위쪽 여백이 아니라
	# 아직 안 쓴 자리로 읽히게. 줄이 넘치면 그때부터 위로 밀려 올라간다.
	_chat_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_box.alignment = BoxContainer.ALIGNMENT_END
	_chat_box.add_theme_constant_override("separation", 7)
	_chat_box.resized.connect(_fit_box.bind(_chat_box))
	_scroll.add_child(_chat_gutter(_chat_box, true))
	pad.add_child(_scroll)
	_log_scroll = ScrollContainer.new()
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_view = VBoxContainer.new()
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.add_theme_constant_override("separation", 7)
	_log_view.resized.connect(_fit_box.bind(_log_view))
	_log_scroll.add_child(_chat_gutter(_log_view, false))
	pad.add_child(_log_scroll)
	field.add_child(pad)
	_room_view.add_child(field)
	_compose = _build_compose()
	_room_view.add_child(_compose)
	_log_note = _build_log_note()
	_room_view.add_child(_log_note)
	_set_online(true)
	return _room_view

## 말풍선이 스크롤 막대에 닿지 않도록 대화 상자 양옆에 홈을 둔다
func _chat_gutter(box: Control, stretch: bool) -> Control:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if stretch:
		m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 7)
	m.add_child(box)
	return m

func _build_room_header() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var back := Button.new()
	back.text = "◀ 대화 목록"
	back.focus_mode = Control.FOCUS_NONE
	back.theme_type_variation = "NuriFlat"
	back.add_theme_font_size_override("font_size", 13)
	back.pressed.connect(show_list)
	row.add_child(back)
	var div := VSeparator.new()
	div.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	div.custom_minimum_size = Vector2(0, 18)
	row.add_child(div)
	_hdr_icon = _icon_rect(_status_tex(true), 16)
	row.add_child(_hdr_icon)
	_hdr_name = Label.new()
	_hdr_name.text = LIVE_PARTNER
	_hdr_name.add_theme_font_size_override("font_size", 15)
	row.add_child(_hdr_name)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_status_label)
	_hdr_note = Label.new()
	_hdr_note.add_theme_font_size_override("font_size", 14)
	_hdr_note.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	_hdr_note.visible = false
	row.add_child(_hdr_note)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	bar.add_child(row)
	return bar

## 자유 입력이 없는 게임이라 메신저의 입력칸 자리를 "고를 수 있는 말"이 대신한다.
## 대신 진짜 입력칸처럼 굴어야 한다 — 번호가 붙고, 숫자 키로도 보내진다.
func _build_compose() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var cap := HBoxContainer.new()
	var caption := Label.new()
	caption.text = "보낼 말"
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	cap.add_child(caption)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(spacer)
	var tip := Label.new()
	tip.text = "숫자 키로도 보낼 수 있습니다"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	cap.add_child(tip)
	box.add_child(cap)
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.custom_minimum_size = Vector2(0, COMPOSE_MIN_H)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	pad.add_child(_choice_box)
	field.add_child(pad)
	box.add_child(field)
	return box

func _build_log_note() -> Control:
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	var l := Label.new()
	l.text = "이미 끝난 대화입니다 — 여기로는 아무것도 보낼 수 없습니다."
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	pad.add_child(l)
	field.add_child(pad)
	field.visible = false
	return field

func _build_statusbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriStatusBar"
	var row := HBoxContainer.new()
	_records_label = Label.new()
	_records_label.add_theme_font_size_override("font_size", 13)
	_records_label.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_records_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var brand := Label.new()
	brand.text = "누리메신저 2.1"
	brand.add_theme_font_size_override("font_size", 13)
	brand.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(brand)
	bar.add_child(row)
	_refresh_records()
	GameState.record_read.connect(func(_cid, _total): _refresh_records())
	return bar

# ── 화면 전환 ─────────────────────────────────────────────────────────────

func open_room(id: String) -> void:
	var room := _room_by_id(id)
	if room.is_empty():
		return
	var live: bool = room["kind"] == "live"
	_room_id = id
	_list_view.visible = false
	_room_view.visible = true
	_scroll.visible = live
	_log_scroll.visible = not live
	_compose.visible = live
	_log_note.visible = not live
	_status_label.visible = live
	_hdr_note.visible = not live
	_hdr_name.text = String(room["name"])
	_hdr_icon.texture = _status_tex(live and _online)
	if live:
		_unread = 0
		_scroll_live_to_bottom()
	else:
		_hdr_note.text = "· 지난 대화 (%s)" % String(room["date"])
		_render_log(int(room["index"]))
	_refresh_rooms()
	_set_win_title()

func show_list() -> void:
	_room_id = ""
	_list_view.visible = true
	_room_view.visible = false
	_refresh_rooms()
	_set_win_title()

func current_room() -> String:
	return _room_id

func room_count() -> int:
	return _count_rows("")

func log_count() -> int:
	return _count_rows("log")

func unread_count() -> int:
	return _unread

## 지금 목록의 "온라인" 칸에 올라와 있는 대화들
func online_room_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_instance_valid(_rooms_box):
		return out
	for c in _rooms_box.get_children():
		if c.has_meta("room_online") and bool(c.get_meta("room_online")):
			out.append(String(c.get_meta("room_id")))
	return out

func _count_rows(kind: String) -> int:
	if not is_instance_valid(_rooms_box):
		return 0
	var n := 0
	for c in _rooms_box.get_children():
		if c.has_meta("room_kind") and (kind == "" or String(c.get_meta("room_kind")) == kind):
			n += 1
	return n

## 지난 대화를 ContentDB 순번으로 연다 (기록물 판정이 이 경로를 탄다)
func open_log(index: int) -> void:
	var logs := ContentDB.chat_logs()
	if index < 0 or index >= logs.size():
		return
	open_room(LOG_PREFIX + String(logs[index].get("date", "")))

func _render_log(index: int) -> void:
	var lg: Dictionary = ContentDB.chat_logs()[index]
	for c in _log_view.get_children():
		# 부모에서 떼어내고 미뤄 지우면 그 사이 프레임 동안 미아 노드로 남는다 —
		# 숨겨만 두고 지운다 (세는 쪽은 보이는 줄만 센다)
		c.hide()
		c.queue_free()
	_log_view.add_child(_system_line(String(lg.get("date", ""))))
	var prev := ""
	for line in lg["lines"]:
		var who := String(line["from"])
		_log_view.add_child(_make_line(who, String(line["text"]), "", prev))
		prev = who
	GameState.mark_read(LOG_PREFIX + String(lg.get("date", "")))
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = 0
	call_deferred("_fit_box", _log_view)

func log_line_count() -> int:
	var n := 0
	for c in _log_view.get_children():
		if c.visible and c.has_meta("chat_line"):
			n += 1
	return n

# ── 상태 표시 ─────────────────────────────────────────────────────────────

func _set_online(on: bool) -> void:
	_online = on
	if is_instance_valid(_status_label):
		_status_label.text = "· 접속중" if on else "· 접속 종료"
	if is_instance_valid(_hdr_icon) and _room_id == LIVE_ROOM:
		_hdr_icon.texture = _status_tex(on)
	_refresh_rooms()

## 기록물은 숨은 엔딩의 유일한 조건인데 지금까지 어디에도 보이지 않았다 —
## 찾았는지도 얼마나 남았는지도 모른 채로 끝난다. 슬기가 부탁한 일이니 그녀의 창에서 센다.
func _refresh_records() -> void:
	if not is_instance_valid(_records_label):
		return
	var total := ContentDB.records().size()
	_records_label.text = "오빠가 남긴 것 · %d / %d" % [GameState.records_count(), total]

func records_text() -> String:
	return _records_label.text if is_instance_valid(_records_label) else ""

func status_text() -> String:
	return _status_label.text

func is_online() -> bool:
	return _online

# ── 말풍선 ────────────────────────────────────────────────────────────────

## 같은 사람이 잇달아 말하면 이름을 다시 달지 않는다 — 실제 대화창처럼 읽히게.
func _make_line(from: String, text: String, stamp: String, prev_from: String = "") -> Control:
	if _is_system(from):
		var sys := _system_line(text)
		sys.set_meta("chat_line", true)
		return sys
	var is_self: bool = from in SELF_SPEAKERS
	var row := HBoxContainer.new()
	row.set_meta("chat_line", true)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_END if is_self else BoxContainer.ALIGNMENT_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
	if from != prev_from:
		var head := Label.new()
		head.text = _display_name(from)
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", SELF_COLOR if is_self else OTHER_COLOR)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_self else HORIZONTAL_ALIGNMENT_LEFT
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(head)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_self else Control.SIZE_SHRINK_BEGIN
	bubble.add_theme_stylebox_override("panel", _bubble_style(is_self))
	var body := Label.new()
	body.text = text
	body.set_meta("chat_text", text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	bubble.add_child(body)
	col.add_child(bubble)
	var time_l := Label.new()
	time_l.text = stamp
	time_l.visible = stamp != ""
	time_l.add_theme_font_size_override("font_size", 12)
	time_l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	time_l.size_flags_vertical = Control.SIZE_SHRINK_END
	if is_self:
		row.add_child(time_l)
		row.add_child(col)
	else:
		row.add_child(col)
		row.add_child(time_l)
	return row

func _bubble_style(is_self: bool) -> StyleBoxFlat:
	# 2002년 위젯의 문법대로 모서리는 각지게, 대신 말한 사람 쪽 가장자리만 두껍게 물들인다
	var s := StyleBoxFlat.new()
	s.bg_color = SELF_BUBBLE if is_self else OTHER_BUBBLE
	s.border_color = (SELF_COLOR if is_self else OTHER_COLOR).lerp(CHAT_BG, 0.58)
	s.set_border_width_all(1)
	if is_self:
		s.border_width_right = 3
	else:
		s.border_width_left = 3
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

## 말풍선은 내용만큼만 넓고 창의 일정 비율을 넘지 않는다. 자동 줄바꿈 라벨은
## 스스로 폭을 못 정하므로, 글자 폭을 재서 직접 물려준다.
func _fit_box(box: Control) -> void:
	if not is_instance_valid(box):
		return
	var avail := box.size.x - 26.0   # 시각 표시 자리 + 스크롤바
	if avail <= BUBBLE_MIN_W:
		return
	for l in _walk_labels(box):
		if not l.has_meta("chat_text"):
			continue
		var want := _bubble_width(l, avail)
		if absf(l.custom_minimum_size.x - want) > 0.5:
			l.custom_minimum_size.x = want

func _bubble_width(l: Label, avail: float) -> float:
	var f := l.get_theme_font("font")
	if f == null:
		f = ThemeDB.fallback_font
	var fs := l.get_theme_font_size("font_size")
	var widest := 0.0
	for ln in String(l.get_meta("chat_text", l.text)).split("\n"):
		widest = maxf(widest, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return ceilf(clampf(widest + 2.0, BUBBLE_MIN_W, avail * BUBBLE_MAX_RATIO))

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
	line.color = RULE_COLOR
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
			call_deferred("_try_continue")
		# 휴지통에서 점검표를 복원하고 돌아온 경우 — 열려 있던 선택지에 조건부가 나타난다
		call_deferred("_refresh_choices"))
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
	_chat_box.add_child(_make_line(from, text, _stamp(), _last_live_from))
	_last_live_from = from
	if _is_system(from):
		# 라이브 대화의 시스템 줄은 슬기가 접속을 끊는 그 한 줄뿐이다
		_live_preview = _elide(text, PREVIEW_CHARS)
		_set_online(false)
	else:
		_live_preview = _elide(("나: " if from in SELF_SPEAKERS else "") + text, PREVIEW_CHARS)
		_live_stamp = _stamp()
	# 목록을 보는 동안 도착한 줄은 빨간 점으로 쌓인다 (세이브 복구 중 몰아치는 건 제외)
	if _room_id != LIVE_ROOM and not _catching_up:
		_unread += 1
	_refresh_rooms()
	await get_tree().process_frame
	_fit_box(_chat_box)
	if _room_id == LIVE_ROOM and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _scroll_live_to_bottom() -> void:
	if not is_instance_valid(_scroll):
		return
	await get_tree().process_frame
	_fit_box(_chat_box)
	await get_tree().process_frame
	if is_instance_valid(_scroll):
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
		c.hide()
		c.queue_free()
	_choice_slots.clear()
	if n.has("choices"):
		for i in n["choices"].size():
			var c: Dictionary = n["choices"][i]
			# 조건이 안 찬 선택지는 아예 없다 — 회색 잠금은 '뭔가 있다'는 스포일러다.
			# 걸러도 원 인덱스를 넘기므로 ChatPlayer.choose와 어긋나지 않는다.
			var req := String(c.get("require", ""))
			if req != "" and not GameState.has_flag(req):
				continue
			_choice_slots.append(i)
			_choice_box.add_child(_choice_row(String(c["text"]), i, _choice_slots.size()))
	elif n.has("next"):
		_auto_pending = true
		_choice_box.add_child(_waiting_row())
		get_tree().create_timer((n.get("delay_ms", 900) if not _catching_up else 50) / 1000.0).timeout.connect(func():
			_auto_pending = false
			_try_continue())

func _refresh_choices() -> void:
	if _cp != null and is_instance_valid(_choice_box) and _cp.current().has("choices"):
		_render_choices(_cp.current())

## 괄호로 감싼 선택지는 대사가 아니라 지문이다 — 보낼 말과 한눈에 갈려야 한다.
func _choice_row(text: String, index: int, slot: int) -> Button:
	var spoken := not (text.begins_with("(") and text.ends_with(")"))
	var b := Button.new()
	b.text = "%d.  %s" % [slot, text]
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 15)
	b.tooltip_text = "" if spoken else "말하지 않고 행동만 합니다"
	b.add_theme_stylebox_override("normal",
		_choice_style(Color(0, 0, 0, 0), SELF_COLOR if spoken else NuriTheme.GUIDE))
	b.add_theme_stylebox_override("hover",
		_choice_style(NuriTheme.SELECT.lerp(NuriTheme.FIELD, 0.80), NuriTheme.SELECT))
	b.add_theme_stylebox_override("pressed",
		_choice_style(NuriTheme.SELECT.lerp(NuriTheme.FIELD, 0.62), NuriTheme.SELECT))
	b.add_theme_color_override("font_color", NuriTheme.TEXT if spoken else NuriTheme.TEXT_DIM)
	b.add_theme_color_override("font_hover_color", NuriTheme.TEXT)
	b.add_theme_color_override("font_pressed_color", NuriTheme.TEXT)
	b.pressed.connect(_on_choice.bind(index))
	return b

func _choice_style(bg: Color, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = accent
	s.border_width_left = 3
	s.content_margin_left = 9
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _waiting_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var l := Label.new()
	l.text = "슬기님이 입력 중입니다"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(l)
	var dots := Label.new()
	dots.text = "."
	dots.add_theme_font_size_override("font_size", 14)
	dots.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(dots)
	var t := Timer.new()
	t.wait_time = 0.35
	t.autostart = true
	t.timeout.connect(func():
		if is_instance_valid(dots):
			dots.text = ".".repeat((dots.text.length() % 3) + 1))
	row.add_child(t)
	return row

func choice_count() -> int:
	var n := 0
	for c in _choice_box.get_children():
		if c is Button and c.visible:
			n += 1
	return n

func line_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _chat_box.get_children():
		for n in _walk_labels(row):
			out.append(n.text)
	return out

func _walk_labels(node: Node) -> Array:
	var found := []
	if node is Label:
		found.append(node)
	for c in node.get_children():
		found.append_array(_walk_labels(c))
	return found

func line_count() -> int:
	return _chat_box.get_child_count()

## 괄호로 감싼 선택지는 대사가 아니라 지문이다. 이 대화창은 이 컴퓨터에
## 실제로 남는 로그이고 — 숨은 엔딩이 "그 로그를 누가 읽었다"에 기대고 있다 —
## 말하지 않기로 한 것이 발화로 찍혀 있으면 안 된다.
func _on_choice(i: int) -> void:
	var said := String(_cp.current()["choices"][i]["text"])
	if not (said.begins_with("(") and said.ends_with(")")):
		_bubble("player", said)
	_cp.choose(i)
	_show_current()

## 숫자 키로도 보낸다 — 진짜 메신저처럼 키보드에서 손을 떼지 않게.
func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if _room_id != LIVE_ROOM or not is_visible_in_tree() or _choice_slots.is_empty():
		return
	var wm := _wm()
	if wm != null and String(wm.active_id()) != "messenger":
		return
	var k: int = (e as InputEventKey).keycode
	var slot := -1
	if k >= KEY_1 and k <= KEY_9:
		slot = k - KEY_1
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		slot = k - KEY_KP_1
	if slot < 0 or slot >= _choice_slots.size():
		return
	accept_event()
	_on_choice(_choice_slots[slot])

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

# ── 잡동사니 ──────────────────────────────────────────────────────────────

func _status_tex(on: bool) -> Texture2D:
	var path := STATUS_ON if on else STATUS_OFF
	return load(path) if ResourceLoader.exists(path) else null

func _icon_rect(tex: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

func _elide(s: String, n: int) -> String:
	var t := s.replace("\n", " ").strip_edges()
	return t if t.length() <= n else t.substr(0, n - 1) + "…"

func _sunken(bg: Color) -> StyleBox:
	var s := NuriTheme.sunken(bg)
	s.set_content_margin_all(3)
	return s

func _wm() -> Node:
	return get_tree().get_first_node_in_group("window_manager") if is_inside_tree() else null

## 작업표시줄과 제목표시줄이 지금 누구와 이야기하는지 따라온다
func _set_win_title() -> void:
	var wm := _wm()
	if wm == null or not wm.has_method("set_window_title") or not wm.is_open("messenger"):
		return
	var base := ContentDB.ui("app_messenger")
	wm.set_window_title("messenger", base if _room_id == "" else "%s - %s" % [base, _hdr_name.text])
