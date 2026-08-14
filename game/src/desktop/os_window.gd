class_name OSWindow
extends Panel
## 공통 창: 타이틀바(드래그·닫기) + 콘텐츠 슬롯

signal request_close(id: String)
signal focused(id: String)

var win_id := ""
var _dragging := false
var _drag_off := Vector2.ZERO
var _titlebar: Panel

func setup(id: String, title: String, win_size: Vector2) -> void:
	win_id = id
	custom_minimum_size = win_size
	size = win_size
	_titlebar = Panel.new()
	_titlebar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(true))
	_titlebar.custom_minimum_size = Vector2(0, 28)
	_titlebar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titlebar.gui_input.connect(_on_titlebar_input)
	var tl := Label.new()
	tl.text = title
	tl.position = Vector2(8, 4)
	tl.add_theme_color_override("font_color", Color.WHITE)
	_titlebar.add_child(tl)
	var x := Button.new()
	x.text = "X"
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -26.0
	x.offset_top = 3.0
	x.offset_right = -4.0
	x.offset_bottom = 25.0
	x.pressed.connect(func(): request_close.emit(win_id))
	_titlebar.add_child(x)
	add_child(_titlebar)
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			focused.emit(win_id))

func set_content(c: Control) -> void:
	var m := MarginContainer.new()
	# 풀렉트 래퍼가 타이틀바(아래 형제)의 히트테스트를 가리지 않도록 제외
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 32)
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	add_child(m)

func _on_titlebar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		_drag_off = get_global_mouse_position() - global_position
		focused.emit(win_id)
	elif e is InputEventMouseMotion and _dragging:
		var p := get_global_mouse_position() - _drag_off
		var parent_origin := Vector2.ZERO
		var pc := get_parent()
		if pc is Control:
			parent_origin = (pc as Control).global_position
		var local := p - parent_origin
		var bounds := get_parent_area_size() - size
		position = local.clamp(Vector2.ZERO, Vector2(maxf(bounds.x, 0), maxf(bounds.y, 0)))
