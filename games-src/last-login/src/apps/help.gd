class_name HelpApp
extends Control
## 누리OS 도움말: 왼쪽 주제 목록, 오른쪽 본문. 시작 메뉴에서 연다.
## 조작법(숨긴 파일·캐시·복원·주소 직접 입력)은 슬기가 아니라 OS가 가르친다 —
## 슬기는 화면을 못 보니까. 메모장 뷰어에 주제 목록을 붙인 시스템 화면이다.

const TOPIC_W := 168

var _topics: Array = []
var _list: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _buttons: Array[Button] = []
var _current := -1

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_topics = ContentDB.help_topics()
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	row.add_child(_build_topic_list())
	row.add_child(_build_page())
	col.add_child(row)
	if not _topics.is_empty():
		show_topic(0)

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	for item in ["목차", "찾기", "인쇄"]:
		var l := Label.new()
		l.text = item
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
		r.add_child(l)
	bar.add_child(r)
	return bar

func _build_topic_list() -> Control:
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.custom_minimum_size = Vector2(TOPIC_W, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	for i in _topics.size():
		var b := Button.new()
		b.text = String(_topics[i].get("title", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(show_topic.bind(i))
		_buttons.append(b)
		_list.add_child(b)
	scroll.add_child(_list)
	field.add_child(scroll)
	return field

func _build_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	page.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.selection_enabled = true
	_body.scroll_active = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_body)
	return page

func show_topic(i: int) -> void:
	if i < 0 or i >= _topics.size():
		return
	_current = i
	_title.text = String(_topics[i].get("title", ""))
	_body.text = String(_topics[i].get("body", ""))
	for j in _buttons.size():
		_buttons[j].add_theme_stylebox_override("normal",
			_row_style(NuriTheme.SELECT.lerp(NuriTheme.FIELD, 0.72) if j == i else Color(0, 0, 0, 0)))

func _row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = NuriTheme.GUIDE
	s.border_width_bottom = 1
	s.content_margin_left = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func topic_count() -> int:
	return _topics.size()

func current_topic() -> int:
	return _current

func body_shown() -> String:
	return _body.text if is_instance_valid(_body) else ""
