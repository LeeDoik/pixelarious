class_name PhotoViewer
extends Control
## 사진 뷰어: 휠로 확대·축소(포인터 밑 지점이 고정), 끌어서 이동, 더블클릭으로 맞춤↔실제 크기.
##
## 필사본 사진들이 800픽셀을 넘어서 "창에 맞춤"으로 열면 절반 크기로 줄어든다 —
## 손글씨가 안 읽히면 그 안에 숨긴 것도 못 찾는다. 확대가 장식이 아니라 통로다.
##
## 좌표 계산은 전부 아래 static 함수에 모아 뒀다. 창 크기가 잡히기 전에도(창을 열자마자,
## 테스트에서) 같은 답이 나와야 해서 노드 상태에 기대지 않는다.

const ZOOM_MIN := 0.15
const ZOOM_MAX := 6.0
const ZOOM_STEP := 1.25

var image_path := ""   ## 창을 열기 전에 채워 넣는다 (_ready에서 반영)

var _tex: Texture2D
var _canvas: Control
var _img: TextureRect
var _zoom_label: Label
var _size_label: Label
var _zoom := 1.0
var _fitted := true    ## 아직 사용자가 배율을 정하지 않았다 — 창이 바뀌면 다시 맞춘다
var _dragging := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if image_path != "" and ResourceLoader.exists(image_path):
		_tex = load(image_path)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	col.add_child(_build_canvas())
	col.add_child(_build_status_bar())
	_refresh_labels()
	# 창 크기는 다음 프레임에야 잡힌다 — 그때 처음 맞춘다
	_canvas.resized.connect(_on_canvas_resized)

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_tool_button("－ 축소", func(): zoom_by(1.0 / ZOOM_STEP)))
	row.add_child(_tool_button("＋ 확대", func(): zoom_by(ZOOM_STEP)))
	row.add_child(VSeparator.new())
	row.add_child(_tool_button("창에 맞춤", fit))
	row.add_child(_tool_button("실제 크기", actual_size))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var hint := Label.new()
	hint.text = "휠: 확대·축소 / 끌기: 이동"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(hint)
	bar.add_child(row)
	return bar

func _tool_button(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "NuriFlat"
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b

func _build_canvas() -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = "NuriField"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 확대한 사진이 창 밖으로 새지 않게 — 이 안이 곧 보이는 영역이다
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_input)
	_img = TextureRect.new()
	_img.texture = _tex
	_img.stretch_mode = TextureRect.STRETCH_SCALE
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_img)
	frame.add_child(_canvas)
	return frame

func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriStatusBar"
	var row := HBoxContainer.new()
	_size_label = Label.new()
	_size_label.add_theme_font_size_override("font_size", 14)
	_size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_label.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_size_label)
	_zoom_label = Label.new()
	_zoom_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_zoom_label)
	bar.add_child(row)
	return bar

# ── 배율 ──────────────────────────────────────────────────────────────────

func fit() -> void:
	## 창에 맞춤. 이 상태로 두면 창 크기를 바꿔도 계속 맞춰 따라간다.
	_zoom = clampf(fit_zoom(tex_size(), view_size()), ZOOM_MIN, ZOOM_MAX)
	_fitted = true
	if is_instance_valid(_img):
		_img.position = Vector2.ZERO
	_apply()

func actual_size() -> void:
	set_zoom(1.0, view_size() * 0.5)

func zoom_by(factor: float) -> void:
	## 도구모음 버튼 — 창 한가운데를 기준으로 배율만 바꾼다
	set_zoom(_zoom * factor, view_size() * 0.5)

func set_zoom(z: float, pivot: Vector2) -> void:
	var next := clampf(z, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return
	if is_instance_valid(_img):
		_img.position = zoom_anchor(_img.position, pivot, next / _zoom)
	_zoom = next
	_fitted = false
	_apply()

func zoom() -> float:
	return _zoom

func zoom_percent() -> int:
	return roundi(_zoom * 100.0)

func is_fitted() -> bool:
	return _fitted

func offset() -> Vector2:
	return _img.position if is_instance_valid(_img) else Vector2.ZERO

func tex_size() -> Vector2:
	return Vector2(_tex.get_size()) if _tex != null else Vector2.ZERO

func view_size() -> Vector2:
	return _canvas.size if is_instance_valid(_canvas) else Vector2.ZERO

func can_pan() -> bool:
	var shown := tex_size() * _zoom
	var view := view_size()
	return shown.x > view.x + 0.5 or shown.y > view.y + 0.5

func _apply() -> void:
	if is_instance_valid(_img) and _tex != null:
		var shown := tex_size() * _zoom
		_img.size = shown
		_img.position = clamp_offset(_img.position, shown, view_size())
		_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG if can_pan() else Control.CURSOR_ARROW
	_refresh_labels()

func _refresh_labels() -> void:
	if not is_instance_valid(_zoom_label):
		return
	var t := tex_size()
	_size_label.text = "%d × %d 픽셀" % [int(t.x), int(t.y)] if _tex != null else "사진을 열 수 없습니다"
	_zoom_label.text = "%d%%" % zoom_percent()

func _on_canvas_resized() -> void:
	# 아직 배율을 손대지 않았으면 창을 따라 계속 맞춘다. 손댔으면 배율은 두고 위치만 다잡는다.
	if _fitted:
		fit()
	else:
		_apply()

# ── 입력 ──────────────────────────────────────────────────────────────────

func _on_canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		_on_canvas_button(e as InputEventMouseButton)
	elif e is InputEventMouseMotion and _dragging:
		var mm := e as InputEventMouseMotion
		# 캔버스 밖에서 버튼을 놓아 릴리즈를 놓친 경우 드래그 자동 해제 (창 이동과 같은 규칙)
		if not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_dragging = false
			return
		_img.position += mm.relative
		_apply()
		accept_event()

func _on_canvas_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		set_zoom(_zoom * ZOOM_STEP, mb.position)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		set_zoom(_zoom / ZOOM_STEP, mb.position)
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and mb.double_click:
			# 더블클릭 = 맞춤 ↔ 실제 크기 (이 시대 뷰어의 관습)
			if _fitted:
				set_zoom(1.0, mb.position)
			else:
				fit()
			_dragging = false
		else:
			_dragging = mb.pressed and can_pan()
		accept_event()

# ── 좌표 계산 (노드 없이도 성립해야 한다) ────────────────────────────────

static func fit_zoom(tex: Vector2, view: Vector2) -> float:
	## 사진 전체가 들어가는 최대 배율. 아직 창이 안 잡혔으면 1:1로 둔다.
	if tex.x <= 0.0 or tex.y <= 0.0 or view.x <= 0.0 or view.y <= 0.0:
		return 1.0
	return minf(view.x / tex.x, view.y / tex.y)

static func zoom_anchor(pos: Vector2, pivot: Vector2, ratio: float) -> Vector2:
	## 배율이 ratio배로 바뀔 때, pivot 밑에 있던 지점이 그대로 pivot 밑에 남는 새 원점.
	## 이게 없으면 휠을 굴릴 때마다 보던 곳이 화면 밖으로 달아난다.
	return pivot - (pivot - pos) * ratio

static func clamp_offset(pos: Vector2, shown: Vector2, view: Vector2) -> Vector2:
	## 보이는 영역보다 작은 축은 가운데로, 큰 축은 가장자리가 안으로 들어오지 않게 붙든다.
	var out := pos
	for axis in 2:
		if shown[axis] <= view[axis]:
			out[axis] = (view[axis] - shown[axis]) * 0.5
		else:
			out[axis] = clampf(out[axis], view[axis] - shown[axis], 0.0)
	return out
