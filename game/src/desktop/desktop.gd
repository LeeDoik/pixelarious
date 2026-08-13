extends Control
## 바탕화면: 배경색, 아이콘 그리드, 작업표시줄(열린 창 버튼 + 시계), CRT 오버레이

const ACT_CLOCK := {1: "21:47", 2: "23:30", 3: "01:12"}
# 앱 빌더 레지스트리 — Task 7~11이 여기에 앱을 추가한다
var APP_BUILDERS: Dictionary = {
	"explorer": func() -> Control: return Explorer.new(),
	"messenger": func() -> Control: return Messenger.new(),
	"mail": func() -> Control: return MailApp.new(),
	"trash": func(): return Label.new(),
}

var wm: WindowManager
var _taskbar_box: HBoxContainer
var _clock: Label
var _icons: VBoxContainer

func _ready() -> void:
	theme = NuriTheme.build()
	var bg := ColorRect.new()
	bg.color = NuriTheme.DESKTOP_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	wm = WindowManager.new()
	wm.set_anchors_preset(Control.PRESET_FULL_RECT)
	wm.offset_bottom = -36  # 작업표시줄 높이만큼
	_register_apps()
	_build_icons()
	add_child(wm)
	_build_taskbar()
	_build_crt()
	GameState.act_changed.connect(func(_a): _clock.text = clock_text())
	_clock.text = clock_text()

func _register_apps() -> void:
	for id in APP_BUILDERS:
		wm.register_app(id, ContentDB.ui("app_" + id), APP_BUILDERS[id])

func _build_icons() -> void:
	_icons = VBoxContainer.new()
	_icons.position = Vector2(16, 12)
	_icons.add_theme_constant_override("separation", 14)
	for id in APP_BUILDERS:
		var b := Button.new()
		b.text = ContentDB.ui("app_" + id)
		b.flat = true
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(wm.open_app.bind(id))
		_icons.add_child(b)
	add_child(_icons)

func icon_count() -> int:
	return _icons.get_child_count()

func _build_taskbar() -> void:
	var bar := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = NuriTheme.TASKBAR_COLOR
	bar.add_theme_stylebox_override("panel", s)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, 36)
	bar.offset_top = -36
	var start := Label.new()
	start.text = " " + ContentDB.ui("os_name")
	start.add_theme_color_override("font_color", Color.WHITE)
	start.position = Vector2(8, 8)
	bar.add_child(start)
	_taskbar_box = HBoxContainer.new()
	_taskbar_box.position = Vector2(180, 4)
	bar.add_child(_taskbar_box)
	_clock = Label.new()
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-70, 8)
	_clock.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_clock)
	add_child(bar)
	wm.windows_changed.connect(_refresh_taskbar)

func _refresh_taskbar(ids: Array) -> void:
	for c in _taskbar_box.get_children():
		_taskbar_box.remove_child(c)
		c.queue_free()
	for id in ids:
		var b := Button.new()
		b.text = ContentDB.ui("app_" + id)
		b.pressed.connect(wm.focus_app.bind(id))
		_taskbar_box.add_child(b)

func clock_text() -> String:
	return clock_text_for_act(GameState.current_act())

func clock_text_for_act(act: int) -> String:
	return ACT_CLOCK[act]

func _build_crt() -> void:
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float scan = 0.04 * sin(UV.y * 768.0 * 3.14159);
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.85, 0.45, length(c)) * 0.12 + 0.88;
	COLOR = vec4(vec3(0.0), (0.04 + scan) * (1.0 - vig) + 0.05 * (1.0 - vig));
}
"""
	mat.shader = sh
	crt.material = mat
	add_child(crt)
