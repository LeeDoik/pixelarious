extends Control
## 부팅 연출: CRT 켜짐 → POST 텍스트 타이핑 → 누리OS 스플래시 → Desktop 전환.
## 웹에서는 엔진 로딩(HTML 셸)이 끝난 직후라 "켜지는 중" 서사가 이어진다.

const LINE_DELAY := 0.35
const CURSOR_BLINK := 0.45
const SPLASH_HOLD := 1.3
const WARMUP := 0.4
const CURSOR := "█"
const POST_COLOR := Color("9adfc0")

var _label: RichTextLabel
var _idx := 0
var _done := false
var _cursor_on := true
var _splash: Control

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
	_label.add_theme_color_override("default_color", POST_COLOR)
	_label.add_theme_font_override("normal_font", load("res://assets/fonts/Galmuri11.ttf"))
	# 이 화면은 OS 이전이라 테마를 받지 않는다 — 본문 판도 직접 지운다
	_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_play_warmup()
	var blink := Timer.new()
	blink.wait_time = CURSOR_BLINK
	blink.autostart = true
	blink.timeout.connect(func():
		_cursor_on = not _cursor_on
		_render())
	add_child(blink)
	_next_line()

func _play_warmup() -> void:
	# CRT 전원이 들어올 때의 가로선 한 줄 — 0.4초짜리지만 "기계를 켰다"를 가장 싸게 전달한다
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.95, 0.9)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_CENTER)
	flash.anchor_left = 0.0
	flash.anchor_right = 1.0
	flash.offset_top = -1.0
	flash.offset_bottom = 1.0
	flash.pivot_offset = Vector2(0, 1)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale:y", 90.0, WARMUP).from(1.0).set_trans(Tween.TRANS_QUART)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, WARMUP)
	tw.tween_callback(flash.queue_free)

func _render() -> void:
	if not is_instance_valid(_label):
		return
	var shown := post_lines().slice(0, _idx)
	var body := "\n".join(PackedStringArray(shown))
	if not _done and _cursor_on:
		body += ("\n" if _idx > 0 else "") + CURSOR
	_label.text = body

func _next_line() -> void:
	if _done:
		return
	if _idx >= post_lines().size():
		_finish()
		return
	_idx += 1
	_render()
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
	_idx = post_lines().size()
	_render()
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	_render()
	_show_splash()

func _show_splash() -> void:
	## POST가 끝나고 바탕화면이 뜨기 전 한 박자 — 이 시대 OS는 늘 자기 이름을 한 번 보여줬다
	_splash = PanelContainer.new()
	_splash.theme = NuriTheme.shared()
	_splash.set_anchors_preset(Control.PRESET_CENTER)
	_splash.offset_left = -190
	_splash.offset_right = 190
	_splash.offset_top = -70
	_splash.offset_bottom = 70
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var logo_row := HBoxContainer.new()
	logo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_theme_constant_override("separation", 10)
	if ResourceLoader.exists("res://assets/img/icons/oslogo.png"):
		var ic := TextureRect.new()
		ic.texture = load("res://assets/img/icons/oslogo.png")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(40, 40)
		logo_row.add_child(ic)
	var title := Label.new()
	title.text = ContentDB.ui("os_name") + " 2002"
	title.add_theme_font_size_override("font_size", 28)
	logo_row.add_child(title)
	col.add_child(logo_row)
	var sub := Label.new()
	sub.text = "시작하는 중입니다..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	col.add_child(sub)
	_splash.add_child(col)
	add_child(_splash)
	get_tree().create_timer(SPLASH_HOLD).timeout.connect(_go_desktop)

func _go_desktop() -> void:
	if not is_inside_tree():
		return
	if GameState.has_save():
		if is_instance_valid(_splash):
			_splash.queue_free()
		_show_continue_menu()
		return
	get_tree().change_scene_to_file("res://src/desktop/desktop.tscn")

func _show_continue_menu() -> void:
	var box := VBoxContainer.new()
	# Boot는 테마 없이 도는 프리-OS 화면 — 한글 버튼 폰트를 테마로 공급 (웹엔 시스템 폴백 없음)
	box.theme = NuriTheme.shared()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 8)
	var cont := Button.new()
	cont.text = "이어서 하기"
	cont.pressed.connect(func():
		GameState.load_game()
		_enter_desktop())
	var fresh := Button.new()
	fresh.text = "처음부터"
	fresh.pressed.connect(func():
		GameState.reset()
		_enter_desktop())
	box.add_child(cont)
	box.add_child(fresh)
	add_child(box)

func _enter_desktop() -> void:
	get_tree().change_scene_to_file("res://src/desktop/desktop.tscn")
