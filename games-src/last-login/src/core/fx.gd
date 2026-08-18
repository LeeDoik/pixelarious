extends CanvasLayer
## 시스템 이펙트·설정 레이어: CRT 곡면(배럴) 왜곡 오버레이 + ESC 설정 메뉴.
## 볼륨·왜곡 설정은 user://settings.json에 저장되어 재방문 시 유지된다.

const SETTINGS_PATH := "user://settings.json"
const WARP_K := 0.03           # 곡면 강도 (셰이더 uniform과 입력 보정이 공유)
const INJECTED_DEVICE := 4242  # 재주입 이벤트 식별용 센티널

## 크기조절·분할선 커서. 전부 이미지 정중앙이 핫스팟이라 가로세로가 짝수여야 한다
## (gen_cursor.py가 그 조건을 assert로 잡는다).
const POINTER_CURSORS := {
	Input.CURSOR_HSIZE: "res://assets/img/cursor_hsize.png",
	Input.CURSOR_VSIZE: "res://assets/img/cursor_vsize.png",
	Input.CURSOR_FDIAGSIZE: "res://assets/img/cursor_fdiag.png",
	Input.CURSOR_BDIAGSIZE: "res://assets/img/cursor_bdiag.png",
	Input.CURSOR_HSPLIT: "res://assets/img/cursor_hsplit.png",
	Input.CURSOR_VSPLIT: "res://assets/img/cursor_vsplit.png",
}

var _warp: ColorRect
var _menu: Panel
var _volume_slider: HSlider
var _warp_check: CheckBox
var _last_fs_ms := 0
var _toast: Control

func _ready() -> void:
	layer = 90
	_build_warp()
	_build_menu()
	_load_settings()
	_apply_cursor()

func _apply_cursor() -> void:
	# 2002풍 픽셀 커서 (scripts/gen_cursor.py 생성)
	if ResourceLoader.exists("res://assets/img/cursor_arrow.png"):
		var arrow := load("res://assets/img/cursor_arrow.png")
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2.ZERO)
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_POINTING_HAND, Vector2.ZERO)
	if ResourceLoader.exists("res://assets/img/cursor_ibeam.png"):
		Input.set_custom_mouse_cursor(load("res://assets/img/cursor_ibeam.png"), Input.CURSOR_IBEAM, Vector2(5, 17))
	# 창 가장자리·분할선 커서. 여기가 비면 창을 끄는 순간에만 호스트 OS의 커서가 튀어나온다
	for shape in POINTER_CURSORS:
		var path: String = POINTER_CURSORS[shape]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		Input.set_custom_mouse_cursor(tex, shape, tex.get_size() / 2.0)

func _process(_delta: float) -> void:
	# 브라우저가 자체적으로 전체화면을 해제한 직후의 ESC를 구분하기 위한 추적
	if _is_fullscreen():
		_last_fs_ms = Time.get_ticks_msec()

# --- 전체화면 ---

func _is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func is_fullscreen() -> bool:
	return _is_fullscreen()

func toggle_fullscreen() -> void:
	if _is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_show_fullscreen_toast()

func _show_fullscreen_toast() -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	var p := PanelContainer.new()
	p.theme = NuriTheme.build()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -280.0
	p.offset_right = 280.0
	p.offset_top = 20.0
	p.offset_bottom = 58.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "전체화면 모드 — ESC 키를 누르면 창 모드로 돌아갑니다"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	add_child(p)
	_toast = p
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)

func _input(e: InputEvent) -> void:
	# 키 입력 효과음 (홀드 반복은 제외 — 실제 누름 한 번당 한 번)
	if e is InputEventKey and e.pressed and not e.echo:
		AudioDirector.play_sfx("key")
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _is_fullscreen():
			# 전체화면에서는 ESC = 창 모드 복귀
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		elif Time.get_ticks_msec() - _last_fs_ms < 600:
			pass  # 브라우저가 방금 같은 ESC로 전체화면을 해제함 — 메뉴를 열지 않는다
		else:
			toggle_menu()
		return
	# 전역 클릭 효과음 (재주입 이벤트는 제외 — 이중 재생 방지)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and e.device != INJECTED_DEVICE:
		AudioDirector.play_sfx("click")
	# 곡면이 켜져 있으면 마우스 좌표를 셰이더와 같은 공식으로 보정해 재주입 —
	# "화면에 보이는 위치"와 "클릭되는 위치"가 일치하게 된다.
	# (설정 메뉴는 왜곡 없이 그려지므로 메뉴가 열려 있을 땐 보정하지 않는다)
	if not _warp.visible or _menu.visible:
		return
	if e is InputEventMouse and e.device != INJECTED_DEVICE:
		var w := e.duplicate() as InputEventMouse
		w.device = INJECTED_DEVICE
		w.position = warp_point(e.position)
		w.global_position = w.position
		if w is InputEventMouseMotion:
			var src := e as InputEventMouseMotion
			(w as InputEventMouseMotion).relative = warp_point(src.position) - warp_point(src.position - src.relative)
		get_viewport().set_input_as_handled()
		get_viewport().push_input(w, true)

func warp_point(p: Vector2) -> Vector2:
	## 화면 좌표 p에 표시되는 콘텐츠의 실제(비왜곡) 캔버스 좌표
	var size := get_viewport().get_visible_rect().size
	var c := (p / size) * 2.0 - Vector2.ONE
	c = c * (1.0 + WARP_K * c.length_squared())
	return (c + Vector2.ONE) * 0.5 * size

# --- CRT 곡면 왜곡 ---

func _build_warp() -> void:
	_warp = ColorRect.new()
	_warp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.03;

void fragment() {
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	vec2 warped = c * (1.0 + strength * r2);
	vec2 uv = (warped + 1.0) * 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_tex, uv).rgb;
		col *= 1.0 - 0.08 * r2;  // 가장자리로 갈수록 살짝 어둡게 (곡면 질감)
		COLOR = vec4(col, 1.0);
	}
}
"""
	mat.shader = sh
	mat.set_shader_parameter("strength", WARP_K)
	_warp.material = mat
	add_child(_warp)

# --- ESC 설정 메뉴 ---

func _build_menu() -> void:
	_menu = Panel.new()
	_menu.theme = NuriTheme.build()
	_menu.visible = false
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.custom_minimum_size = Vector2(340, 190)
	_menu.offset_left = -170
	_menu.offset_top = -95
	_menu.offset_right = 170
	_menu.offset_bottom = 95
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_top = 12
	box.offset_right = -16
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "시스템 설정"
	box.add_child(title)
	var vol_label := Label.new()
	vol_label.text = "소리 크기"
	box.add_child(vol_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.value = 100
	_volume_slider.value_changed.connect(func(v: float): set_volume(v / 100.0))
	box.add_child(_volume_slider)
	_warp_check = CheckBox.new()
	_warp_check.text = "화면 곡면 효과 (CRT)"
	_warp_check.button_pressed = true
	_warp_check.toggled.connect(set_warp)
	box.add_child(_warp_check)
	var close := Button.new()
	close.text = "닫기 (ESC)"
	close.pressed.connect(toggle_menu)
	box.add_child(close)
	_menu.add_child(box)
	add_child(_menu)

func toggle_menu() -> void:
	_menu.visible = not _menu.visible

func is_menu_open() -> bool:
	return _menu.visible

# --- 설정 API + 저장 ---

func set_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(v) if v > 0.0 else -80.0)
	if is_instance_valid(_volume_slider) and absf(_volume_slider.value - v * 100.0) > 0.5:
		_volume_slider.set_value_no_signal(v * 100.0)
	_save()

func get_volume() -> float:
	var db := AudioServer.get_bus_volume_db(0)
	return 0.0 if db <= -79.0 else db_to_linear(db)

func set_warp(on: bool) -> void:
	_warp.visible = on
	if is_instance_valid(_warp_check) and _warp_check.button_pressed != on:
		_warp_check.set_pressed_no_signal(on)
	_save()

func is_warp_on() -> bool:
	return _warp.visible

func _save() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("fx: cannot save settings (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify({"volume": get_volume(), "warp": is_warp_on()}))
	f.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	set_volume(float(data.get("volume", 1.0)))
	set_warp(bool(data.get("warp", true)))
