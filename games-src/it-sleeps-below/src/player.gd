class_name Player
extends Node2D
## 광부 비주얼 — 그리드 좌표는 Mine이 관리, 여기는 표시·애니만.

var sprites := {}
var _frame := 0
var _anim := "idle"
var _t := 0.0

func _ready() -> void:
	for n in ["idle", "walk1", "walk2", "climb1", "climb2", "dig1", "dig2", "death"]:
		sprites[n] = load("res://assets/img/miner_%s.png" % n)
	z_index = 10

func set_anim(anim: String) -> void:
	_anim = anim
	_t = 0.0

func _process(delta: float) -> void:
	_t += delta
	_frame = int(_t / 0.14) % 2
	queue_redraw()

func _draw() -> void:
	var tex: Texture2D
	match _anim:
		"walk": tex = sprites["walk1"] if _frame == 0 else sprites["walk2"]
		"climb": tex = sprites["climb1"] if _frame == 0 else sprites["climb2"]
		"dig": tex = sprites["dig1"] if _frame == 0 else sprites["dig2"]
		"death": tex = sprites["death"]
		_: tex = sprites["idle"]
	draw_texture(tex, Vector2(-8, -8))
