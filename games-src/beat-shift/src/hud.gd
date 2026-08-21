class_name Hud
extends CanvasLayer
## 그루브 VU미터 + 콤보 배수. 숫자 최소주의 — 게이지가 곧 연출.

const SEGS := 10

var _blocks: Array = []
var _mult: Label
var _float: Label
var _float_tw: Tween

func _ready() -> void:
	for i in range(SEGS):
		var b := ColorRect.new()
		b.position = Vector2(10.0 + i * 15.0, 12.0)
		b.size = Vector2(11.0, 8.0)
		b.color = _seg_color(i)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
		_blocks.append(b)
	_mult = _make_label(12, Vector2(228, 8), Color("#FFEC27"))
	_float = _make_label(10, Vector2(60, 34), Color("#FFA300"))
	_float.modulate.a = 0.0

func _make_label(size: int, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri9.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.position = pos
	add_child(l)
	return l

func _seg_color(i: int) -> Color:
	if i < 3:
		return Color("#FF004D")
	if i < 7:
		return Color("#FFA300")
	return Color("#FFEC27")

func set_groove(ratio: float) -> void:
	var lit := int(ceilf(clampf(ratio, 0.0, 1.0) * SEGS))
	for i in range(SEGS):
		(_blocks[i] as ColorRect).modulate.a = 1.0 if i < lit else 0.15

func set_mult(m: int) -> void:
	_mult.text = "x%d" % m if m > 1 else ""

func flash(text: String) -> void:
	_float.text = text
	_float.modulate.a = 1.0
	if _float_tw:
		_float_tw.kill()
	_float_tw = create_tween()
	_float_tw.tween_property(_float, "modulate:a", 0.0, 0.9).set_delay(0.5)
