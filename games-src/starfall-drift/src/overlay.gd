class_name Overlay
extends CanvasLayer
## 타이틀/게임오버/일시정지 텍스트 오버레이. 일시정지 중에도 입력을 받도록 ALWAYS.

var _lines: Array[Label] = []
var _emblem: Sprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_emblem = Sprite2D.new()
	_emblem.texture = load("res://assets/img/emblem.png")
	_emblem.position = Vector2(Tuning.VIEW_W / 2.0, 120.0)
	_emblem.scale = Vector2(2, 2)
	add_child(_emblem)

func _label(text: String, y: float, size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri11.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(Tuning.VIEW_W, 30)
	l.position = Vector2(0, y)
	add_child(l)
	_lines.append(l)
	return l

func clear() -> void:
	for l in _lines:
		l.queue_free()
	_lines.clear()
	_emblem.visible = false
	visible = false

func show_title() -> void:
	clear()
	visible = true
	_emblem.visible = true
	_label("STARFALL DRIFT", 170, 22, Color("#FFEC27"))
	_label("TAP TO DRIFT", 220, 11, Color("#FFF1E8"))

func show_game_over(score: int, best: int, new_best: bool) -> void:
	clear()
	visible = true
	_label("SCORE  %d" % score, 160, 16, Color("#FFF1E8"))
	_label("BEST   %d" % best, 190, 16, Color("#FFEC27" if new_best else "#29ADFF"))
	if new_best:
		_label("NEW RECORD!", 220, 11, Color("#FF77A8"))
	_label("TAP TO RETRY", 260, 11, Color("#FFF1E8"))

func show_paused() -> void:
	clear()
	visible = true
	_label("PAUSED", 200, 16, Color("#FFF1E8"))
	_label("TAP TO RESUME", 230, 11, Color("#29ADFF"))
