extends Node
## 세션 상태·점수·베스트. 씬 리로드에도 살아남는 오토로드.

enum Phase { TITLE, PLAYING, GAME_OVER }

const BEST_PATH := "user://best.json"

var phase: int = Phase.TITLE
var mult: int = 1
var groove: float = Tuning.GROOVE_START
var best: int = 0
var quick_restart: bool = false
var _score: int = 0

func _ready() -> void:
	best = Persistence.load_best(BEST_PATH)
	_register_input()

func _register_input() -> void:
	if InputMap.has_action("tap"):
		return
	InputMap.add_action("tap")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("tap", key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("tap", mouse)

func start_run() -> void:
	phase = Phase.PLAYING
	mult = 1
	groove = Tuning.GROOVE_START
	_score = 0

func register_hit(result: String) -> int:
	groove = Groove.apply(groove, result)
	var r := Scoring.hit(result, mult)
	mult = r.mult
	_score += r.points
	return r.points

func register_fail(kind: String) -> void:
	groove = Groove.apply(groove, kind)
	mult = 1

func register_section_clear(section_index: int) -> int:
	groove = Groove.recover(groove)
	var b := Scoring.section_bonus(section_index)
	_score += b
	return b

func is_dead() -> bool:
	return Groove.dead(groove)

func score() -> int:
	return _score

func end_run() -> void:
	phase = Phase.GAME_OVER
	if score() > best:
		best = score()
		Persistence.save_best(BEST_PATH, best)
