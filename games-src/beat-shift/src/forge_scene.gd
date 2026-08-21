class_name ForgeScene
extends Node2D
## 대장간 장면 — 큐(잉곳 투척)와 판정 연출. 그루브가 높으면 화로가 살아난다.

const ANVIL_TOP := Vector2(150.0, 318.0)
const ASSIST_POS := Vector2(48.0, 310.0)
const SMITH_POS := Vector2(208.0, 302.0)
const FURNACE_POS := Vector2(62.0, 218.0)

var _smith: Sprite2D
var _assistant: Sprite2D
var _furnace: Sprite2D
var _sparks: CPUParticles2D
var _embers: CPUParticles2D
var _idle_tex: Texture2D
var _swing_tex: Texture2D
var _ingots: Array = []

func _ready() -> void:
	_build_backdrop()
	_furnace = Sprite2D.new()
	_furnace.texture = load("res://assets/img/furnace.png")
	_furnace.position = FURNACE_POS
	add_child(_furnace)
	_embers = CPUParticles2D.new()
	_embers.position = FURNACE_POS + Vector2(0, -20)
	_embers.amount = 12
	_embers.lifetime = 1.6
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(0, -30)
	_embers.initial_velocity_min = 10.0
	_embers.initial_velocity_max = 30.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.0
	_embers.color = Color("#FFA300")
	add_child(_embers)
	var anvil := Sprite2D.new()
	anvil.texture = load("res://assets/img/anvil.png")
	anvil.position = ANVIL_TOP + Vector2(0, 14)
	add_child(anvil)
	_assistant = Sprite2D.new()
	_assistant.texture = load("res://assets/img/assistant.png")
	_assistant.position = ASSIST_POS
	add_child(_assistant)
	_idle_tex = load("res://assets/img/smith_idle.png")
	_swing_tex = load("res://assets/img/smith_swing.png")
	_smith = Sprite2D.new()
	_smith.texture = _idle_tex
	_smith.position = SMITH_POS
	add_child(_smith)
	_sparks = CPUParticles2D.new()
	_sparks.position = ANVIL_TOP
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 14
	_sparks.lifetime = 0.5
	_sparks.spread = 70.0
	_sparks.direction = Vector2(0, -1)
	_sparks.initial_velocity_min = 60.0
	_sparks.initial_velocity_max = 140.0
	_sparks.gravity = Vector2(0, 240)
	_sparks.color = Color("#FFEC27")
	add_child(_sparks)
	Conductor.beat.connect(_on_beat)

func _build_backdrop() -> void:
	var wall := ColorRect.new()
	wall.color = Color("#1D2B53")
	wall.position = Vector2(0, 150)
	wall.size = Vector2(Tuning.VIEW_W, 190)
	wall.z_index = -10
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color("#141127")
	floor_rect.position = Vector2(0, 340)
	floor_rect.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H - 340)
	floor_rect.z_index = -10
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

func _on_beat(_b: int) -> void:
	# 화로가 박자에 맞춰 맥동 — 장면 전체가 메트로놈
	_furnace.self_modulate = Color(1.35, 1.2, 1.0)
	var tw := create_tween()
	tw.tween_property(_furnace, "self_modulate", Color.WHITE, 0.18)

func spawn_cue(note_time: float, cue_time: float) -> void:
	var ing := Ingot.new()
	add_child(ing)
	ing.setup(ASSIST_POS + Vector2(10.0, -12.0), ANVIL_TOP + Vector2(0.0, -6.0), cue_time, note_time)
	_ingots.append(ing)
	_assistant.position = ASSIST_POS + Vector2(0, -6)
	var tw := create_tween()
	tw.tween_property(_assistant, "position", ASSIST_POS, 0.15)
	Sfx.play("precue", -8.0)

func ingot_count() -> int:
	return _ingots.size()

func clear_cues() -> void:
	for ing in _ingots:
		(ing as Ingot).queue_free()
	_ingots.clear()

func _take_ingot(note_time: float) -> Ingot:
	for i in range(_ingots.size()):
		var ing := _ingots[i] as Ingot
		if absf(ing.note_time() - note_time) < 0.001:
			_ingots.remove_at(i)
			return ing
	return null

func on_result(result: String, note_time: float) -> void:
	match result:
		"perfect", "good":
			_swing()
			var ing := _take_ingot(note_time)
			if ing:
				ing.forge(result == "perfect")
			_sparks.amount = 18 if result == "perfect" else 8
			_sparks.restart()
			_punch()
		"miss":
			var ing := _take_ingot(note_time)
			if ing:
				ing.drop()
		"stray":
			_swing()

func _swing() -> void:
	_smith.texture = _swing_tex
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: _smith.texture = _idle_tex)

func _punch() -> void:
	# 화면 미세 펀치 — 장면을 한 프레임 내려찍고 복귀
	position = Vector2(0, 3)
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2.ZERO, 0.1)

func set_heat(ratio: float) -> void:
	# 그루브 게이지가 곧 장면 연출 — 낮으면 화로가 식는다
	_embers.emitting = ratio > 0.25
	_furnace.modulate = Color.WHITE.lerp(Color(1.2, 1.05, 0.9), clampf(ratio, 0.0, 1.0))
