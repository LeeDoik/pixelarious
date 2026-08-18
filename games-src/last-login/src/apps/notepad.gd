class_name Notepad
extends Control
## 메모장: 탐색기에서 연 .txt 한 개를 보여주는 읽기 전용 창 내용물.
## 창 제목이 파일 이름을 이미 달고 있으므로 여기서는 본문만 보여준다.

const MENU_ITEMS := ["파일", "편집", "서식", "도움말"]

var body_text := ""   ## 창을 열기 전에 채워 넣는다 (_ready에서 반영)

var _text: RichTextLabel

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_menubar())
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.selection_enabled = true
	_text.scroll_active = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var field := NuriTheme.sunken(NuriTheme.FIELD)
	field.set_content_margin_all(8)
	_text.add_theme_stylebox_override("normal", field)
	_text.add_theme_color_override("default_color", NuriTheme.TEXT)
	_text.add_theme_color_override("selection_color", NuriTheme.SELECT)
	_text.text = body_text
	col.add_child(_text)

func _build_menubar() -> Control:
	# 시대감을 위한 장식용 메뉴줄 — 이 게임의 메모장은 읽기 전용이라 항목은 열리지 않는다
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for item in MENU_ITEMS:
		var l := Label.new()
		l.text = item
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
		row.add_child(l)
	bar.add_child(row)
	return bar

func text_shown() -> String:
	return _text.text if is_instance_valid(_text) else body_text
