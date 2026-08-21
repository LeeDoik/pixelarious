class_name NoteJudge
extends RefCounted
## 한 섹션의 노트 판정 상태 머신. 시간 단위는 초. Godot API 비의존 — 헤드리스 테스트 대상.

var _notes: Array = []
var _hit: Array = []
var _perfect_win: float
var _good_win: float
var _miss_idx := 0

func _init(note_times: Array, perfect_win: float, good_win: float) -> void:
	_notes = note_times.duplicate()
	_notes.sort()
	_hit.resize(_notes.size())
	_hit.fill(false)
	_perfect_win = perfect_win
	_good_win = good_win

func on_tap(t: float) -> Dictionary:
	var best := -1
	var best_d := INF
	for i in range(_notes.size()):
		if _hit[i]:
			continue
		var d: float = float(_notes[i]) - t
		if d > _good_win:
			break
		if absf(d) <= _good_win and absf(d) < best_d:
			best = i
			best_d = absf(d)
	if best == -1:
		return {"result": "stray", "note_time": -1.0}
	_hit[best] = true
	return {"result": ConductorMath.classify(best_d, _perfect_win, _good_win), "note_time": _notes[best]}

func advance(t: float) -> Array:
	var missed: Array = []
	while _miss_idx < _notes.size():
		if _hit[_miss_idx]:
			_miss_idx += 1
			continue
		if float(_notes[_miss_idx]) + _good_win < t:
			_hit[_miss_idx] = true
			missed.append(_notes[_miss_idx])
			_miss_idx += 1
		else:
			break
	return missed

func remaining() -> int:
	var n := 0
	for h in _hit:
		if not h:
			n += 1
	return n

func remaining_after(t: float) -> Array:
	var out: Array = []
	for i in range(_notes.size()):
		if not _hit[i] and float(_notes[i]) >= t:
			out.append(_notes[i])
	return out
