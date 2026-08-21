extends Node
## 박자 시계. 오디오 재생 위치가 진실 — 시각 프레임이 아니다.
## 백킹 루프는 정확히 1마디 → 루프 랩 카운트 = 마디 인덱스.

signal beat(index: int)

var bpm: float = 0.0
var running := false

var _player: AudioStreamPlayer
var _loop_len := 1.0
var _loop_count := 0
var _last_pos := 0.0
var _last_time := 0.0
var _last_beat := -1

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func start_section(bpm_step: int) -> void:
	bpm = Tuning.BPM_STEPS[mini(bpm_step, Tuning.BPM_STEPS.size() - 1)]
	var stream: AudioStreamWAV = load("res://assets/sfx/loop_%d.wav" % int(bpm))
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	_loop_len = ConductorMath.time_from_beats(float(Tuning.BEATS_PER_BAR), bpm)
	stream.loop_end = int(round(_loop_len * float(stream.mix_rate)))
	_player.stream = stream
	_loop_count = 0
	_last_pos = 0.0
	_last_time = 0.0
	_last_beat = -1
	running = true
	_player.play()

func resume_at_bar(bar: int) -> void:
	_loop_count = bar
	_last_pos = 0.0
	_last_time = float(bar) * _loop_len
	_last_beat = bar * Tuning.BEATS_PER_BAR - 1
	running = true
	_player.play(0.0)

func stop() -> void:
	running = false
	_player.stop()

func song_time() -> float:
	if not running:
		return _last_time
	var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	pos = maxf(pos, 0.0)
	if pos < _last_pos - _loop_len * 0.5:
		_loop_count += 1
	_last_pos = pos
	var t := ConductorMath.wrapped_time(_loop_len, _loop_count, pos)
	t = maxf(t, _last_time)
	_last_time = t
	return t

func song_beats() -> float:
	return ConductorMath.beats_from_time(song_time(), bpm)

func _process(_delta: float) -> void:
	if not running:
		return
	var b := int(floor(song_beats()))
	if b > _last_beat:
		_last_beat = b
		beat.emit(b)
