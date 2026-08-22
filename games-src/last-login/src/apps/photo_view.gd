class_name PhotoView
extends Control
## 사진 창의 내용물. 창에 맞추기(1x)와 실제 크기 2배(2x) 두 단계.
## 2x에서는 스크롤로 훑고, 클릭 위치를 사진 좌표(0~1)로 돌려준다 —
## 종이에 적힌 것을 손가락으로 짚는 동작이 이 게임에서 처음 생기는 자리다.

signal region_clicked(uv: Vector2)

const ZOOM_FIT := 1.0
const ZOOM_NEAR := 2.0

var image_path := ""

var _zoom := ZOOM_FIT
var _tex: Texture2D
var _scroll: ScrollContainer
var _rect: TextureRect
var _zoom_btn: Button

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if image_path != "":
		_tex = load(image_path)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.theme_type_variation = "NuriField"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rect = TextureRect.new()
	_rect.texture = _tex
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.gui_input.connect(_on_image_input)
	frame.add_child(_rect)
	_scroll.add_child(frame)
	col.add_child(_scroll)
	_apply_zoom()

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_zoom_btn = Button.new()
	_zoom_btn.theme_type_variation = "NuriFlat"
	_zoom_btn.focus_mode = Control.FOCUS_NONE
	_zoom_btn.add_theme_font_size_override("font_size", 14)
	_zoom_btn.pressed.connect(toggle_zoom)
	row.add_child(_zoom_btn)
	bar.add_child(row)
	return bar

func zoom() -> float:
	return _zoom

func toggle_zoom() -> void:
	_zoom = ZOOM_NEAR if is_equal_approx(_zoom, ZOOM_FIT) else ZOOM_FIT
	_apply_zoom()

func _apply_zoom() -> void:
	if not is_instance_valid(_rect):
		return
	var near := not is_equal_approx(_zoom, ZOOM_FIT)
	_zoom_btn.text = "창에 맞추기" if near else "확대"
	if near and _tex != null:
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.custom_minimum_size = Vector2(_tex.get_size()) * ZOOM_NEAR
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.custom_minimum_size = Vector2.ZERO
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _on_image_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton):
		return
	var mb := e as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_equal_approx(_zoom, ZOOM_FIT) or _tex == null:
		return
	var uv := uv_at(mb.position, Vector2(_tex.get_size()), ZOOM_NEAR)
	if uv.x >= 0.0:
		region_clicked.emit(uv)

static func uv_at(local_pos: Vector2, tex_size: Vector2, zoom: float) -> Vector2:
	## 2x에서는 TextureRect가 tex_size * zoom 크기로 고정되므로 나눗셈 한 번이면 된다.
	## 창에 맞추기 상태의 여백 계산이 필요 없도록 클릭 판정을 2x에서만 받는다.
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or zoom <= 0.0:
		return Vector2(-1, -1)
	var uv := local_pos / (tex_size * zoom)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv
