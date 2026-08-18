class_name OSWindow
extends Panel
## 공통 창: 타이틀바(드래그·닫기) + 콘텐츠 슬롯

signal request_close(id: String)
signal request_minimize(id: String)
signal focused(id: String)

const RESIZE_MARGIN := 6.0
const MIN_WIN_SIZE := Vector2(360, 260)
const MAXIMIZE_GLYPH := "□"
const RESTORE_GLYPH := "▣"

var win_id := ""
var _dragging := false
var _resizing := false
var _resize_zone := 0  # 비트마스크: 1=왼쪽 2=오른쪽 4=아래
var _titlebar: Panel
var _max_btn: Button
var _maximized := false
var _restore_rect := Rect2()

func setup(id: String, title: String, win_size: Vector2, icon_path: String = "") -> void:
	win_id = id
	custom_minimum_size = MIN_WIN_SIZE
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
		# expand_mode를 크기 지정보다 먼저 — 아니면 최소 크기가 텍스처 원본(32px)에 묶인다
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(20, 20)
		ic.position = Vector2(6, 4)
		ic.size = Vector2(20, 20)
		_titlebar.add_child(ic)
		title_x = 32.0
	var tl := Label.new()
	tl.text = title
	tl.position = Vector2(title_x, 4)
	tl.add_theme_color_override("font_color", Color.WHITE)
	_titlebar.add_child(tl)
	var x := _titlebar_button("X", -26.0, -4.0)
	x.pressed.connect(func(): request_close.emit(win_id))
	_titlebar.add_child(x)
	_max_btn = _titlebar_button(MAXIMIZE_GLYPH, -50.0, -28.0)
	_max_btn.pressed.connect(toggle_maximize)
	_titlebar.add_child(_max_btn)
	var mn := _titlebar_button("_", -74.0, -52.0)
	mn.pressed.connect(func(): request_minimize.emit(win_id))
	_titlebar.add_child(mn)
	add_child(_titlebar)
	gui_input.connect(_on_body_input)

func _on_body_input(e: InputEvent) -> void:
	# 창 본체: 클릭 = 포커스, 가장자리 드래그 = 리사이즈 (상단은 타이틀바 = 이동)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			focused.emit(win_id)
			_resize_zone = 0 if _maximized else _zone_at(e.position)
			_resizing = _resize_zone != 0
		else:
			_resizing = false
	elif e is InputEventMouseMotion:
		if _resizing:
			if not (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
				_resizing = false
				return
			_apply_resize(e.relative)
		else:
			_update_resize_cursor(0 if _maximized else _zone_at(e.position))

func _zone_at(p: Vector2) -> int:
	var z := 0
	if p.x <= RESIZE_MARGIN:
		z |= 1
	elif p.x >= size.x - RESIZE_MARGIN:
		z |= 2
	if p.y >= size.y - RESIZE_MARGIN:
		z |= 4
	return z

func _update_resize_cursor(z: int) -> void:
	match z:
		1, 2:
			mouse_default_cursor_shape = Control.CURSOR_HSIZE
		4:
			mouse_default_cursor_shape = Control.CURSOR_VSIZE
		5:
			mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
		6:
			mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
		_:
			mouse_default_cursor_shape = Control.CURSOR_ARROW

func _apply_resize(rel: Vector2) -> void:
	var area := get_parent_area_size()
	if _resize_zone & 2:
		size.x = clampf(size.x + rel.x, MIN_WIN_SIZE.x, maxf(area.x - position.x, MIN_WIN_SIZE.x))
	if _resize_zone & 4:
		size.y = clampf(size.y + rel.y, MIN_WIN_SIZE.y, maxf(area.y - position.y, MIN_WIN_SIZE.y))
	if _resize_zone & 1:
		var new_x := clampf(position.x + rel.x, 0.0, position.x + size.x - MIN_WIN_SIZE.x)
		size.x += position.x - new_x
		position.x = new_x

func set_active(active: bool) -> void:
	if is_instance_valid(_titlebar):
		_titlebar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(active))

func _titlebar_button(label: String, off_left: float, off_right: float) -> Button:
	# 테마 기본 버튼(폰트 16 + 여백 6)의 최소 크기가 22px 틀을 넘으므로 여백만 줄인 전용 베벨
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = off_left
	b.offset_top = 3.0
	b.offset_right = off_right
	b.offset_bottom = 25.0
	b.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover"]:
		var up := NuriTheme.raised(NuriTheme.FACE if state == "normal" else NuriTheme.FACE.lightened(0.08))
		up.set_content_margin_all(1)
		b.add_theme_stylebox_override(state, up)
	var down := NuriTheme.sunken(NuriTheme.FACE.darkened(0.10))
	down.set_content_margin_all(1)
	b.add_theme_stylebox_override("pressed", down)
	return b

func toggle_maximize() -> void:
	## 최대화 = 창 영역(작업표시줄 위)을 가득. 복원 좌표는 최대화 직전 값을 그대로 되돌린다.
	if _maximized:
		position = _restore_rect.position
		size = _restore_rect.size
	else:
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		size = get_parent_area_size()
	_maximized = not _maximized
	if is_instance_valid(_max_btn):
		_max_btn.text = RESTORE_GLYPH if _maximized else MAXIMIZE_GLYPH
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func is_maximized() -> bool:
	return _maximized

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
		focused.emit(win_id)
		if e.pressed and e.double_click:
			# 타이틀바 더블클릭 = 최대화/복원 (이 시대 OS의 기본 동작)
			_dragging = false
			toggle_maximize()
			return
		_dragging = e.pressed and not _maximized
	elif e is InputEventMouseMotion and _dragging:
		# 캔버스 밖에서 버튼을 놓아 릴리즈를 놓친 경우 드래그 자동 해제
		if not (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_dragging = false
			return
		var bounds := get_parent_area_size() - size
		position = (position + e.relative).clamp(Vector2.ZERO, Vector2(maxf(bounds.x, 0), maxf(bounds.y, 0)))
