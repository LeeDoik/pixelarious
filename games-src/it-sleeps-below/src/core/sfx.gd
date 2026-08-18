extends Node
## 사운드 재생 — 이름으로 재생, 앰비언트 1채널, 음악 1채널, 심박 1채널.
## 음악과 앰비언트는 채널이 따로다: 거점에서 새소리는 그대로 두고 음악만 음정을 흔들고,
## 갱도에서는 음악만 죽이고 지층 앰비언트는 계속 간다 (스펙 §14).

const MUSIC_DB := -10.0  # 음악은 앰비언트 아래에 깔린다 — 거점에서도 소리의 주인공은 아니다

var _players: Array[AudioStreamPlayer] = []
var _amb := AudioStreamPlayer.new()
var _music := AudioStreamPlayer.new()
var _beat := AudioStreamPlayer.new()
var _amb_name := ""
var _music_name := ""

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	add_child(_amb)
	add_child(_music)
	add_child(_beat)
	_amb.volume_db = -6.0
	_music.volume_db = MUSIC_DB

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

func _switch(player: AudioStreamPlayer, current: String, name: String) -> String:
	# 전환에 실패하면(파일 없음) 이름을 기억하지 않고 현재 상태를 유지한다.
	# 없는 이름을 기억해두면 파일이 들어온 뒤에도 같은 이름 호출이 조용히 무시된다.
	if name == current:
		return current
	if name == "":
		player.stop()
		return ""
	var s := _stream(name)
	if s == null:
		return current
	if s is AudioStreamOggVorbis:
		s.loop = true
	player.stream = s
	player.play()
	return name

func ambience(name: String) -> void:
	_amb_name = _switch(_amb, _amb_name, name)

func ambience_pitch(p: float) -> void:
	_amb.pitch_scale = p

func ambience_volume(db: float) -> void:
	_amb.volume_db = db

func music(name: String) -> void:
	_music_name = _switch(_music, _music_name, name)

func music_pitch(p: float) -> void:
	_music.pitch_scale = p

func music_volume(db: float) -> void:
	_music.volume_db = db

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
