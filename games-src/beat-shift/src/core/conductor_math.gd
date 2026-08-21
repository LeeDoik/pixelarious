class_name ConductorMath
## 박자·판정창 순수 수학. 시간 단위는 초.

static func beats_from_time(t: float, bpm: float) -> float:
	return t * bpm / 60.0

static func time_from_beats(beats: float, bpm: float) -> float:
	return beats * 60.0 / bpm

static func wrapped_time(loop_len: float, loop_count: int, pos: float) -> float:
	return float(loop_count) * loop_len + pos

static func classify(delta: float, perfect_win: float, good_win: float) -> String:
	var d := absf(delta)
	if d <= perfect_win:
		return "perfect"
	if d <= good_win:
		return "good"
	return ""

static func due_cues(note_times: Array, from_t: float, to_t: float, lead: float) -> Array:
	var due: Array = []
	for nt in note_times:
		var cue_t := float(nt) - lead
		if cue_t > from_t and cue_t <= to_t:
			due.append(nt)
	return due
