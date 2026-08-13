class_name HintEngine
extends RefCounted
## 스펙 §3.2: 같은 게이트 5분 정체 → 1단계, 이후 3분 간격 상승, 최대 3단계.

signal hint_ready(puzzle_id: String, level: int)

const FIRST_MS := 5 * 60 * 1000
const STEP_MS := 3 * 60 * 1000

var _now: Callable
var _gate := ""
var _entered := 0
var _level := 0

func _init(time_source: Callable) -> void:
	_now = time_source

func set_gate(puzzle_id: String) -> void:
	if puzzle_id == _gate:
		return
	_gate = puzzle_id
	_entered = _now.call()
	_level = 0

func poll() -> void:
	if _gate == "" or _level >= 3:
		return
	var elapsed: int = _now.call() - _entered
	var target := 0
	if elapsed >= FIRST_MS + 2 * STEP_MS:
		target = 3
	elif elapsed >= FIRST_MS + STEP_MS:
		target = 2
	elif elapsed >= FIRST_MS:
		target = 1
	while _level < target:
		_level += 1
		hint_ready.emit(_gate, _level)
