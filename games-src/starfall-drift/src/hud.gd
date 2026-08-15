class_name Hud
extends CanvasLayer
## 고도·콤보 최소 표시 + 보너스 플로터.

var _alt: Label
var _combo: Label
var _bonus: Label
var _bonus_tw: Tween

func _make_label(size: int, pos: Vector2, color := Color("#FFF1E8")) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri9.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.position = pos
	add_child(l)
	return l

func _ready() -> void:
	_alt = _make_label(18, Vector2(10, 8))
	_combo = _make_label(9, Vector2(10, 30), Color("#FFEC27"))
	_bonus = _make_label(9, Vector2(180, 8), Color("#29ADFF"))
	_bonus.modulate.a = 0.0
	_update_offset()
	get_viewport().size_changed.connect(_update_offset)

func _update_offset() -> void:
	offset.x = (get_viewport().get_visible_rect().size.x - Tuning.VIEW_W) / 2.0

func set_altitude(m: int) -> void:
	_alt.text = "%dm" % m

func set_combo(mult: int) -> void:
	_combo.text = "x%d" % mult if mult > 1 else ""

func show_bonus(text: String) -> void:
	_bonus.text = text
	_bonus.modulate.a = 1.0
	if _bonus_tw:
		_bonus_tw.kill()
	_bonus_tw = create_tween()
	_bonus_tw.tween_property(_bonus, "modulate:a", 0.0, 0.8).set_delay(0.4)
