extends Node
## 세션 상태·점수·베스트. 씬 리로드에도 살아남는 오토로드.

enum Phase { TITLE, PLAYING, GAME_OVER }

const BEST_PATH := "user://best.json"

var phase: int = Phase.TITLE
var combo: int = 1
var best: int = 0
var quick_restart: bool = false
## 포커스 아웃 자동 일시정지 스위치 — 테스트 러너 창은 OS 포커스가 없어 가짜 FOCUS_OUT이
## 수시로 날아오므로 테스트에서만 끈다. 프로덕션 기본값 true.
var pause_on_focus_out: bool = true
var _bonus: int = 0
var _rise_px: float = 0.0

func _ready() -> void:
	best = Persistence.load_best(BEST_PATH)
	_register_input()

func _register_input() -> void:
	if InputMap.has_action("drift"):
		return
	InputMap.add_action("drift")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("drift", key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("drift", mouse)

func start_run() -> void:
	phase = Phase.PLAYING
	combo = 1
	_bonus = 0
	_rise_px = 0.0

func register_hop(gauge_ratio: float) -> int:
	var r := Scoring.hop_result(gauge_ratio, combo)
	combo = r.combo
	_bonus += r.bonus
	return r.bonus

func register_dwarf() -> void:
	_bonus += Tuning.DWARF_BONUS

func update_rise(px: float) -> void:
	_rise_px = maxf(_rise_px, px)

func score() -> int:
	return Scoring.height_score(_rise_px) + _bonus

func collapse_active() -> bool:
	return Scoring.collapse_active(score())

func end_run() -> void:
	phase = Phase.GAME_OVER
	if score() > best:
		best = score()
		Persistence.save_best(BEST_PATH, best)
