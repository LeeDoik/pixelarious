class_name Lurker
extends Node2D
## '그것' — 규칙은 LurkerLogic, 여기는 스폰·걸음·표시·포획만.

signal caught

var grid_pos := Vector2i.ZERO
var target := Vector2i.ZERO
var is_open: Callable
var frozen := false
var _tex_walk: Texture2D
var _tex_frozen: Texture2D
var _step_t := 0.0

func _ready() -> void:
	_tex_walk = load("res://assets/img/lurker.png")
	_tex_frozen = load("res://assets/img/lurker_frozen.png")
	z_index = 9

func setup(pos: Vector2i, open_cb: Callable) -> void:
	grid_pos = pos
	is_open = open_cb
	position = Vector2(pos * 16) + Vector2(8, 0)

func tick(delta: float, player_pos: Vector2i, radius: float, lamp_on: bool) -> void:
	frozen = LurkerLogic.is_frozen(grid_pos, player_pos, radius, lamp_on)
	queue_redraw()
	if frozen:
		return
	_step_t += delta
	if _step_t < 0.35:
		return
	_step_t = 0.0
	grid_pos = LurkerLogic.next_step(grid_pos, target, is_open)
	position = Vector2(grid_pos * 16) + Vector2(8, 0)
	if grid_pos == player_pos:
		caught.emit()
	elif grid_pos == target:
		# 목표 도달 + 새 소음 없음 → 배회로 전환 (지나침 규칙, 스펙 §6)
		var s := LurkerLogic.arrived_wander({"target": target, "alert": false},
			grid_pos + Vector2i([-4, 4].pick_random(), [-3, 0, 3].pick_random()))
		target = s.target

func hear(pos: Vector2i, level: float) -> void:
	var s := LurkerLogic.hear({"target": target, "alert": false}, pos, level)
	target = s.target

func _draw() -> void:
	draw_texture(_tex_frozen if frozen else _tex_walk, Vector2(-8, -16))
