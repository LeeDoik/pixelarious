extends Control
## 바탕화면: 배경색, 아이콘 그리드, 작업표시줄(열린 창 버튼 + 시계), CRT 오버레이

# 앱 빌더 레지스트리 — Task 7~11이 여기에 앱을 추가한다
var APP_BUILDERS: Dictionary = {
	"explorer": func() -> Control: return Explorer.new(),
	"messenger": func() -> Control: return Messenger.new(),
	"mail": func() -> Control: return MailApp.new(),
	"browser": func() -> Control: return BrowserApp.new(),
	"trash": func() -> Control: return TrashApp.new(),
}
const ICON_TEXTURES := {
	"explorer": "res://assets/img/icons/folder.png",
	"messenger": "res://assets/img/icons/messenger.png",
	"mail": "res://assets/img/icons/mail.png",
	"browser": "res://assets/img/icons/browser.png",
	"trash": "res://assets/img/icons/trash.png",
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
	_clock.text = clock_text()
	var clock_timer := Timer.new()
	clock_timer.wait_time = 5.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(func(): _clock.text = clock_text())
	add_child(clock_timer)
	GameState.flag_changed.connect(func(n):
		if n == "ending_start":
			var e := EndingScene.new()
			add_child(e)
			e.play(true))
	AudioDirector.play_sfx("startup")
	# 신규 플레이어 유도: 슬기를 아직 만나지 않았다면 잠시 후 새 쪽지 알림
	get_tree().create_timer(15.0).timeout.connect(_maybe_nudge)

func _register_apps() -> void:
	for id in APP_BUILDERS:
		wm.register_app(id, ContentDB.ui("app_" + id), APP_BUILDERS[id], ICON_TEXTURES.get(id, ""))

func _build_icons() -> void:
	_icons = VBoxContainer.new()
	_icons.position = Vector2(16, 12)
	_icons.add_theme_constant_override("separation", 14)
	for id in APP_BUILDERS:
		var b := Button.new()
		b.text = ContentDB.ui("app_" + id)
		b.flat = true
		b.add_theme_color_override("font_color", Color.WHITE)
		if ICON_TEXTURES.has(id) and ResourceLoader.exists(ICON_TEXTURES[id]):
			b.icon = load(ICON_TEXTURES[id])
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
	var start := HBoxContainer.new()
	start.position = Vector2(8, 4)
	start.add_theme_constant_override("separation", 6)
	if ResourceLoader.exists("res://assets/img/icons/oslogo.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/img/icons/oslogo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.custom_minimum_size = Vector2(24, 24)
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		start.add_child(logo)
	var start_label := Label.new()
	start_label.text = ContentDB.ui("os_name")
	start_label.add_theme_color_override("font_color", Color.WHITE)
	start.add_child(start_label)
	bar.add_child(start)
	_taskbar_box = HBoxContainer.new()
	_taskbar_box.position = Vector2(180, 4)
	bar.add_child(_taskbar_box)
	var fs_btn := Button.new()
	fs_btn.text = "전체화면"
	fs_btn.add_theme_font_size_override("font_size", 12)
	fs_btn.anchor_left = 1.0
	fs_btn.anchor_right = 1.0
	fs_btn.offset_left = -186.0
	fs_btn.offset_right = -84.0
	fs_btn.offset_top = 4.0
	fs_btn.offset_bottom = 32.0
	fs_btn.pressed.connect(func(): Fx.toggle_fullscreen())
	bar.add_child(fs_btn)
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
		b.text = wm.window_title(id)
		b.pressed.connect(wm.taskbar_clicked.bind(id))
		_taskbar_box.add_child(b)

func clock_text() -> String:
	# 접속 지역 실제 시각 (HH:MM)
	return Time.get_time_string_from_system().substr(0, 5)

func _maybe_nudge() -> void:
	if not is_inside_tree():
		return
	if GameState.has_flag("met_seulgi") or wm.is_open("messenger"):
		return
	AudioDirector.play_sfx("msg")
	var p := PanelContainer.new()
	var l := Label.new()
	l.text = "PC통신에 새 쪽지가 도착했습니다 — 클릭해서 확인"
	p.add_child(l)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -420.0
	p.offset_right = -12.0
	p.offset_top = -84.0
	p.offset_bottom = -44.0
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			wm.open_app("messenger")
			p.queue_free())
	add_child(p)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_callback(func():
		if is_instance_valid(p):
			p.queue_free())
	# 아직도 안 열었다면 45초 후 한 번 더
	get_tree().create_timer(45.0).timeout.connect(_maybe_nudge)

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
