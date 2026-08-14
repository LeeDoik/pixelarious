extends Control
## 부팅 연출: 검은 화면 → POST 텍스트 타이핑 → 부팅 로고 → Desktop 전환.
## 웹에서는 엔진 로딩(HTML 셸)이 끝난 직후라 "켜지는 중" 서사가 이어진다.

const LINE_DELAY := 0.35

var _label: RichTextLabel
var _idx := 0
var _done := false

func post_lines() -> Array:
	return [
		"HANBYUL Computer BIOS v2.02",
		"Memory Test : 131072K OK",
		"Detecting IDE Drives ... HDD0: HB-D5400 (40GB)",
		"Boot from HDD ...",
		"",
		"누리OS 2002 시작하는 중...",
	]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label = RichTextLabel.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 24
	_label.offset_top = 24
	_label.add_theme_color_override("default_color", Color("9adfc0"))
	_label.add_theme_font_override("normal_font", load("res://assets/fonts/Galmuri11.ttf"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_next_line()

func _next_line() -> void:
	if _done:
		return
	if _idx >= post_lines().size():
		_finish()
		return
	_label.append_text(post_lines()[_idx] + "\n")
	_idx += 1
	get_tree().create_timer(LINE_DELAY).timeout.connect(_next_line)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		skip()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		skip()

func skip() -> void:
	if _done:
		return
	_label.clear()
	for l in post_lines():
		_label.append_text(l + "\n")
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if GameState.has_save():
		_show_continue_menu()
	else:
		_go_desktop()

func _show_continue_menu() -> void:
	var box := VBoxContainer.new()
	# Boot는 테마 없이 도는 프리-OS 화면 — 한글 버튼 폰트를 테마로 공급 (웹엔 시스템 폴백 없음)
	box.theme = NuriTheme.build()
	box.set_anchors_preset(Control.PRESET_CENTER)
	var cont := Button.new()
	cont.text = "이어서 하기"
	cont.pressed.connect(func():
		GameState.load_game()
		_go_desktop())
	var fresh := Button.new()
	fresh.text = "처음부터"
	fresh.pressed.connect(func():
		GameState.reset()
		_go_desktop())
	box.add_child(cont)
	box.add_child(fresh)
	add_child(box)

func _go_desktop() -> void:
	get_tree().change_scene_to_file("res://src/desktop/desktop.tscn")
