extends CanvasLayer
## 시스템 이펙트·설정 레이어: CRT 곡면(배럴) 왜곡 오버레이 + ESC 설정 메뉴.
## 볼륨·왜곡 설정은 user://settings.json에 저장되어 재방문 시 유지된다.

const SETTINGS_PATH := "user://settings.json"

var _warp: ColorRect
var _menu: Panel
var _volume_slider: HSlider
var _warp_check: CheckBox

func _ready() -> void:
	layer = 90
	_build_warp()
	_build_menu()
	_load_settings()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		toggle_menu()
		get_viewport().set_input_as_handled()

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

void fragment() {
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	vec2 warped = c * (1.0 + 0.05 * r2);
	vec2 uv = (warped + 1.0) * 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_tex, uv).rgb;
		col *= 1.0 - 0.12 * r2;  // 가장자리로 갈수록 살짝 어둡게 (곡면 질감)
		COLOR = vec4(col, 1.0);
	}
}
"""
	mat.shader = sh
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
