extends Node
## 사운드 재생 — 이름으로 재생, 앰비언트 1채널, 심박 1채널.

var _players: Array[AudioStreamPlayer] = []
var _amb := AudioStreamPlayer.new()
var _beat := AudioStreamPlayer.new()
var _amb_name := ""

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	add_child(_amb)
	add_child(_beat)
	_amb.volume_db = -6.0

func _stream(name: String) -> AudioStream:
	var path := "res://assets/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func play(name: String) -> void:
	var s := _stream(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.play()
			return

func ambience(name: String) -> void:
	if name == _amb_name:
		return
	_amb_name = name
	if name == "":
		_amb.stop()
		return
	var s := _stream(name)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	_amb.stream = s
	_amb.play()

func ambience_pitch(p: float) -> void:
	_amb.pitch_scale = p

func ambience_volume(db: float) -> void:
	_amb.volume_db = db

func heartbeat(rate: float) -> void:
	if rate <= 0.0:
		_beat.stop()
		return
	if not _beat.playing:
		var s := _stream("heartbeat")
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			s.loop = true
		_beat.stream = s
		_beat.play()
	_beat.pitch_scale = clampf(rate, 0.8, 2.2)
