extends Control
## 바탕화면: 배경색, 아이콘 그리드, 작업표시줄(시작 버튼 + 열린 창 + 트레이), CRT 오버레이

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
## 앱별 기본 창 크기 (없으면 WindowManager.DEFAULT_WIN_SIZE)
const APP_WIN_SIZE := {"mail": Vector2(768, 560), "browser": Vector2(768, 580),
	"trash": Vector2(736, 520), "messenger": Vector2(440, 600)}
const OS_LOGO := "res://assets/img/icons/oslogo.png"
const TRAY_VOLUME := "res://assets/img/icons/tray_volume.png"

const TASKBAR_H := 36.0
const START_W := 92.0
const TRAY_W := 200.0
const START_MENU_H := 252.0
const TASK_BTN_MAX := 160.0
const TASK_BTN_MIN := 64.0

var wm: WindowManager
var _taskbar_box: HBoxContainer
var _clock: Label
var _icons: VBoxContainer
var _start_menu: PanelContainer
var _menu_catcher: Control
var _selected_icon := ""

func _ready() -> void:
	theme = NuriTheme.shared()
	var bg := ColorRect.new()
	bg.color = NuriTheme.DESKTOP_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_desktop_input)
	add_child(bg)
	wm = WindowManager.new()
	wm.set_anchors_preset(Control.PRESET_FULL_RECT)
	wm.offset_bottom = -TASKBAR_H  # 작업표시줄 높이만큼
	_register_apps()
	_build_icons()
	add_child(wm)
	_build_taskbar()
	_build_start_menu()
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
		wm.register_app(id, ContentDB.ui("app_" + id), APP_BUILDERS[id], ICON_TEXTURES.get(id, ""),
			APP_WIN_SIZE.get(id, WindowManager.DEFAULT_WIN_SIZE))

# --- 바탕화면 아이콘 ---

func _build_icons() -> void:
	_icons = VBoxContainer.new()
	_icons.position = Vector2(12, 10)
	_icons.add_theme_constant_override("separation", 4)
	for id in APP_BUILDERS:
		_icons.add_child(_desktop_icon(id))
	add_child(_icons)

func _desktop_icon(id: String) -> Button:
	# 이 시대의 바탕화면 아이콘은 그림이 위, 이름이 아래다 (가로로 붙으면 도구모음처럼 보인다)
	var b := Button.new()
	b.text = ContentDB.ui("app_" + id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 72)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 14)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	# 배경 그림 밝기가 제각각이라 라벨은 외곽선이 있어야 어디서든 읽힌다
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	if ICON_TEXTURES.has(id) and ResourceLoader.exists(ICON_TEXTURES[id]):
		b.icon = load(ICON_TEXTURES[id])
	_style_icon(b, false)
	b.gui_input.connect(_on_icon_input.bind(id))
	return b

func _style_icon(b: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(NuriTheme.SELECT, 0.62) if selected else Color(0, 0, 0, 0)
	normal.set_content_margin_all(4)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(NuriTheme.SELECT, 0.72 if selected else 0.34)
	hover.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)

func _on_icon_input(e: InputEvent, id: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	select_icon(id)
	if (e as InputEventMouseButton).double_click:
		wm.open_app(id)

func select_icon(id: String) -> void:
	## 한 번 클릭 = 선택, 두 번 = 실행 (탐색기 목록과 같은 규칙)
	_selected_icon = id
	var ids: Array = APP_BUILDERS.keys()
	for i in _icons.get_child_count():
		var b := _icons.get_child(i) as Button
		if b != null and i < ids.size():
			_style_icon(b, String(ids[i]) == id)

func selected_icon() -> String:
	return _selected_icon

func _on_desktop_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		select_icon("")
		_close_start_menu()

func icon_count() -> int:
	return _icons.get_child_count()

# --- 작업표시줄 ---

func _build_taskbar() -> void:
	var bar := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = NuriTheme.TASKBAR_COLOR
	s.border_color = NuriTheme.TASKBAR_COLOR.lightened(0.35)
	s.border_width_top = 1
	bar.add_theme_stylebox_override("panel", s)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, TASKBAR_H)
	bar.offset_top = -TASKBAR_H
	bar.add_child(_build_start_button())
	_taskbar_box = HBoxContainer.new()
	_taskbar_box.position = Vector2(START_W + 8, 4)
	_taskbar_box.add_theme_constant_override("separation", 4)
	bar.add_child(_taskbar_box)
	bar.add_child(_build_tray())
	add_child(bar)
	wm.windows_changed.connect(_refresh_taskbar)
	wm.app_focused.connect(func(_id): _sync_taskbar_state())

func _build_start_button() -> Button:
	var b := Button.new()
	b.text = "시작"
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(4, 4)
	b.custom_minimum_size = Vector2(START_W - 8, TASKBAR_H - 8)
	b.add_theme_font_size_override("font_size", 15)
	if ResourceLoader.exists(OS_LOGO):
		b.icon = load(OS_LOGO)
		b.add_theme_constant_override("icon_max_width", 20)
	b.pressed.connect(_toggle_start_menu)
	return b

func _build_tray() -> Control:
	# 시계와 시스템 아이콘이 앉는 파인 판. 여기가 없으면 시계가 허공에 뜬 라벨로 보인다
	var tray := PanelContainer.new()
	tray.add_theme_stylebox_override("panel", NuriTheme.sunken(NuriTheme.TASKBAR_COLOR.lightened(0.10)))
	tray.anchor_left = 1.0
	tray.anchor_right = 1.0
	tray.offset_left = -(TRAY_W + 6)
	tray.offset_right = -6
	tray.offset_top = 4
	tray.offset_bottom = TASKBAR_H - 4
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_theme_constant_override("margin_right", 4)
	row.add_child(_tray_button("전체화면", "", func(): Fx.toggle_fullscreen()))
	row.add_child(_tray_button("", TRAY_VOLUME, func(): Fx.toggle_menu()))
	_clock = Label.new()
	_clock.add_theme_color_override("font_color", Color.WHITE)
	_clock.add_theme_font_size_override("font_size", 14)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_clock)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	row.add_child(pad)
	tray.add_child(row)
	return tray

func _tray_button(label: String, icon_path: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_content_margin_all(3)
	b.add_theme_stylebox_override("normal", flat)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.16)
	hover.set_content_margin_all(3)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.add_theme_constant_override("icon_max_width", 16)
	b.pressed.connect(cb)
	return b

func _refresh_taskbar(ids: Array) -> void:
	for c in _taskbar_box.get_children():
		_taskbar_box.remove_child(c)
		c.queue_free()
	var room := get_viewport_rect().size.x - START_W - TRAY_W - 24.0
	var width := clampf(room / maxf(ids.size(), 1.0) - 4.0, TASK_BTN_MIN, TASK_BTN_MAX)
	for id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = wm.window_title(id)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(width, TASKBAR_H - 8)
		b.add_theme_font_size_override("font_size", 14)
		var icon_path := wm.window_icon(id)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			b.icon = load(icon_path)
			b.add_theme_constant_override("icon_max_width", 16)
		b.pressed.connect(wm.taskbar_clicked.bind(id))
		_taskbar_box.add_child(b)
	_sync_taskbar_state()

func _sync_taskbar_state() -> void:
	# 눌린 버튼 = 지금 앞에 있는 창. 작업표시줄만 봐도 어느 창이 활성인지 알 수 있어야 한다
	var active := wm.active_id()
	var ids: Array = wm.open_ids()
	for i in _taskbar_box.get_child_count():
		var b := _taskbar_box.get_child(i) as Button
		if b != null and i < ids.size():
			b.set_pressed_no_signal(String(ids[i]) == active)

func taskbar_button_count() -> int:
	return _taskbar_box.get_child_count()

# --- 시작 메뉴 ---

func _build_start_menu() -> void:
	_menu_catcher = Control.new()
	_menu_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catcher.visible = false
	_menu_catcher.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_start_menu())
	add_child(_menu_catcher)
	_start_menu = PanelContainer.new()
	_start_menu.visible = false
	_start_menu.anchor_top = 1.0
	_start_menu.anchor_bottom = 1.0
	_start_menu.offset_left = 4
	_start_menu.offset_top = -(START_MENU_H + TASKBAR_H)
	_start_menu.offset_bottom = -TASKBAR_H
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.add_child(_start_band())
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 0)
	items.custom_minimum_size = Vector2(200, 0)
	for id in APP_BUILDERS:
		items.add_child(_start_item(ContentDB.ui("app_" + id), ICON_TEXTURES.get(id, ""), func(): wm.open_app(id)))
	var sep := HSeparator.new()
	var sep_line := StyleBoxLine.new()
	sep_line.color = NuriTheme.FACE_DARK
	sep_line.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_line)
	sep.add_theme_constant_override("separation", 7)
	items.add_child(sep)
	items.add_child(_start_item(ContentDB.ui("app_help"), "", open_help))
	items.add_child(_start_item("시스템 설정", "", func(): Fx.toggle_menu()))
	row.add_child(items)
	_start_menu.add_child(row)
	add_child(_start_menu)

func _start_band() -> Control:
	# 세로로 세운 OS 이름 띠 — 이 시대 시작 메뉴의 가장 알아보기 쉬운 부분.
	# 컨테이너는 회전을 배치에 반영하지 않으므로 Panel 위에 라벨을 직접 앉힌다.
	var band := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = NuriTheme.TITLE_A
	band.add_theme_stylebox_override("panel", s)
	band.custom_minimum_size = Vector2(26, 0)
	var l := Label.new()
	l.text = ContentDB.ui("os_name") + " 2002"
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_font_size_override("font_size", 14)
	l.size = Vector2(START_MENU_H - 24.0, 20)
	l.rotation = -PI / 2.0
	l.position = Vector2(3, START_MENU_H - 14.0)
	band.add_child(l)
	return band

func _start_item(label: String, icon_path: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 15)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 8
	flat.content_margin_right = 8
	var hover := StyleBoxFlat.new()
	hover.bg_color = NuriTheme.SELECT
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_hover_color", NuriTheme.SELECT_TEXT)
	b.add_theme_color_override("font_pressed_color", NuriTheme.SELECT_TEXT)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.add_theme_constant_override("icon_max_width", 20)
	b.pressed.connect(func():
		_close_start_menu()
		cb.call())
	return b

## 도움말은 바탕화면 아이콘이 아니라 시스템 화면이다 — 시스템 설정과 같은 급으로 시작 메뉴에만 있다
func open_help() -> void:
	wm.open_window("help", ContentDB.ui("app_help"), HelpApp.new(), Vector2(640, 460))

func _toggle_start_menu() -> void:
	if _start_menu.visible:
		_close_start_menu()
	else:
		_start_menu.visible = true
		_menu_catcher.visible = true

func _close_start_menu() -> void:
	_start_menu.visible = false
	_menu_catcher.visible = false

func is_start_menu_open() -> bool:
	return _start_menu.visible

# --- 그 외 ---

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
