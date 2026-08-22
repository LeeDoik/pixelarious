class_name OSDialog
extends Control
## 창 안에서 뜨는 모달 대화상자 — 타이틀바 + 스크림 + 안내문 + (선택) 영숫자 암호 입력.
## 탐색기의 잠긴 폴더와 누리메일의 잠긴 첨부가 같은 물건을 쓴다. 두 벌로 두면
## 한쪽만 손보다가 결이 갈라진다.

signal submitted(text: String)
signal confirmed()
signal closed()

enum Mode { MESSAGE, PASSWORD, CONFIRM }

const ALNUM := "abcdefghijklmnopqrstuvwxyz0123456789"
const BOX_MIN_W := 420
const BODY_MIN_W := 320

var _title: Label
var _body: Label
var _error: Label
var _icon: TextureRect
var _edit: LineEdit
var _ok: Button
var _cancel: Button
var _message := ""
var _mode := Mode.MESSAGE

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.35)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(BOX_MIN_W, 0)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	shell.add_child(_build_titlebar())
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(_build_head())
	_edit = LineEdit.new()
	_edit.max_length = 24
	_edit.placeholder_text = "비밀번호 (영문/숫자)"
	_edit.secret = true
	_edit.text_changed.connect(_filter)
	_edit.text_submitted.connect(func(t: String) -> void: submitted.emit(t))
	col.add_child(_edit)
	_error = Label.new()
	_error.add_theme_font_size_override("font_size", 14)
	_error.add_theme_color_override("font_color", Color("9c2f2f"))
	_error.visible = false
	col.add_child(_error)
	col.add_child(_build_buttons())
	pad.add_child(col)
	shell.add_child(pad)
	box.add_child(shell)
	center.add_child(box)
	add_child(center)

func _build_titlebar() -> Control:
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(true))
	bar.custom_minimum_size = Vector2(0, 24)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.position = Vector2(8, 3)
	bar.add_child(_title)
	return bar

func _build_head() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(BODY_MIN_W, 0)
	texts.add_child(_body)
	head.add_child(texts)
	return head

func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	_ok = Button.new()
	_ok.custom_minimum_size = Vector2(80, 0)
	_ok.pressed.connect(_on_ok)
	_cancel = Button.new()
	_cancel.custom_minimum_size = Vector2(80, 0)
	_cancel.pressed.connect(close)
	row.add_child(_ok)
	row.add_child(_cancel)
	return row

func ask_password(title: String, body: String, icon_path: String = "") -> void:
	_mode = Mode.PASSWORD
	_open(title, body, icon_path, "확인", "취소")
	_edit.visible = true
	_edit.text = ""
	_cancel.visible = true
	_edit.grab_focus()

func show_message(title: String, body: String, icon_path: String = "") -> void:
	_mode = Mode.MESSAGE
	_open(title, body, icon_path, "확인", "")
	_edit.visible = false
	_cancel.visible = false

func ask_confirm(title: String, body: String, icon_path: String = "",
		ok_text: String = "예", cancel_text: String = "아니오") -> void:
	## 되돌릴 수 없는 일을 묻는다 — 휴지통 비우기가 이걸 쓴다. 확인을 누르면
	## 창을 먼저 닫고 confirmed를 보낸다 (받는 쪽이 곧바로 다른 대화상자를 열 수 있게).
	_mode = Mode.CONFIRM
	_open(title, body, icon_path, ok_text, cancel_text)
	_edit.visible = false
	_cancel.visible = true

func show_error(text: String) -> void:
	_error.text = text
	_error.visible = true
	_message = text

func close() -> void:
	if not visible:
		return
	visible = false
	_mode = Mode.MESSAGE
	closed.emit()

func is_open() -> bool:
	return visible

func last_message() -> String:
	return _message

func input_text() -> String:
	return _edit.text

func mode() -> Mode:
	return _mode

func _open(title: String, body: String, icon_path: String,
		ok_text: String, cancel_text: String) -> void:
	_ok.text = ok_text
	_cancel.text = cancel_text
	_title.text = title
	_body.text = body
	_message = body
	_error.visible = false
	_icon.texture = load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null
	visible = true

func _on_ok() -> void:
	match _mode:
		Mode.PASSWORD:
			submitted.emit(_edit.text)
		Mode.CONFIRM:
			close()
			confirmed.emit()
		_:
			close()

func _filter(t: String) -> void:
	# 스펙 §3: 플레이어 입력은 영숫자만 (한글 IME 금지)
	var filtered := ""
	for ch in t:
		if ch.to_lower() in ALNUM:
			filtered += ch
	if filtered != t:
		_edit.text = filtered
		_edit.caret_column = filtered.length()
