class_name OSWindow
extends Panel
## 공통 창: 타이틀바(드래그·닫기) + 콘텐츠 슬롯

signal request_close(id: String)
signal focused(id: String)

var win_id := ""
var _dragging := false
var _titlebar: Panel

func setup(id: String, title: String, win_size: Vector2, icon_path: String = "") -> void:
	win_id = id
	custom_minimum_size = win_size
	size = win_size
	_titlebar = Panel.new()
	_titlebar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(true))
	_titlebar.custom_minimum_size = Vector2(0, 28)
	_titlebar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titlebar.gui_input.connect(_on_titlebar_input)
	var title_x := 8.0
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture = load(icon_path)
		ic.position = Vector2(6, 4)
		ic.custom_minimum_size = Vector2(20, 20)
		ic.size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_titlebar.add_child(ic)
		title_x = 32.0
	var tl := Label.new()
	tl.text = title
	tl.position = Vector2(title_x, 4)
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
	# 테마 기본 버튼(폰트 16 + 여백 6)의 최소 크기가 22px 틀을 넘지 않게 전용 소형 스타일 적용
	x.add_theme_font_size_override("font_size", 12)
	var xsb := StyleBoxFlat.new()
	xsb.bg_color = NuriTheme.FACE
	xsb.border_color = NuriTheme.FACE_DARK
	xsb.set_border_width_all(2)
	xsb.set_content_margin_all(1)
	x.add_theme_stylebox_override("normal", xsb)
	var xsb_down: StyleBoxFlat = xsb.duplicate()
	xsb_down.bg_color = NuriTheme.FACE.darkened(0.12)
	x.add_theme_stylebox_override("pressed", xsb_down)
	x.add_theme_stylebox_override("hover", xsb.duplicate())
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
		focused.emit(win_id)
	elif e is InputEventMouseMotion and _dragging:
		# 캔버스 밖에서 버튼을 놓아 릴리즈를 놓친 경우 드래그 자동 해제
		if not (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_dragging = false
			return
		var bounds := get_parent_area_size() - size
		position = (position + e.relative).clamp(Vector2.ZERO, Vector2(maxf(bounds.x, 0), maxf(bounds.y, 0)))
