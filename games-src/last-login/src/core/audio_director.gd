extends Node
## 앰비언트 레이어(액트 수만큼 겹침) + 창밖 한 겹 + SFX 원샷 + 엔딩 음악.

const SFX := {
	"msg": "res://assets/sfx/msg.wav", "unlock": "res://assets/sfx/unlock.wav",
	"click": "res://assets/sfx/click.wav", "boot": "res://assets/sfx/boot.wav",
	"startup": "res://assets/sfx/startup.wav",
	"error": "res://assets/sfx/error.wav",
	"msg_tense": "res://assets/sfx/msg_tense.wav",   # 4단부터 msg 대신 — 반갑던 소리가 긴장되는 소리로
	"shutdown": "res://assets/sfx/shutdown.wav",     # 엔딩 "시스템을 종료하는 중"
}
## 다섯 단 — 팬 · 형광등 험 · 불협 드론 · 심장처럼 뛰는 저음 · 들숨 같은 노이즈 (GameState.current_act 순)
const LAYERS := ["res://assets/sfx/amb_fan.wav", "res://assets/sfx/amb_hum.wav", "res://assets/sfx/amb_drone.wav",
	"res://assets/sfx/amb_pulse.wav", "res://assets/sfx/amb_breath.wav"]
## 창밖 — 밤(1~3단)에서 새벽(4·5단)으로. 액트가 곧 밤이 깊어 가는 시간이다 (설계서 "저녁 → 새벽")
const WINDOW := {"night": "res://assets/sfx/amb_window_night.wav", "dawn": "res://assets/sfx/amb_window_dawn.wav"}
const WINDOW_DB := -6.0
const MUSIC := {"ending_theme": "res://assets/sfx/ending_theme.ogg"}
const MUSIC_DB := -8.0
## msg가 긴장된 소리로 바뀌는 액트
const TENSE_FROM_ACT := 4

var _layer_players: Array[AudioStreamPlayer] = []
var _window_players: Dictionary = {}  # "night"/"dawn" -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _variant_pools: Dictionary = {}  # 이름 -> 경로 배열 (매번 랜덤 재생)
var _silenced := false  # 컴퓨터를 끈 뒤 — 층이 다시 켜지지 않는다

func _ready() -> void:
	# 실제 녹음을 분할한 변주 풀 — 재생마다 랜덤 선택 (풀이 비면 SFX 폴백)
	for prefix in ["click", "key"]:
		var pool: Array[String] = []
		var i := 1
		while ResourceLoader.exists("res://assets/sfx/%s_%d.wav" % [prefix, i]):
			pool.append("res://assets/sfx/%s_%d.wav" % [prefix, i])
			i += 1
		if not pool.is_empty():
			_variant_pools[prefix] = pool
	for path in LAYERS:
		_layer_players.append(_make_loop_player(path, -14.0))
	for key in WINDOW:
		_window_players[key] = _make_loop_player(WINDOW[key], WINDOW_DB)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	GameState.act_changed.connect(func(_a): _sync_layers())
	_sync_layers()

func _make_loop_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = stream.data.size() / 2
		p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	return p

func _sync_layers() -> void:
	if _silenced:
		return
	for i in _layer_players.size():
		_set_playing(_layer_players[i], i < GameState.current_act())
	var w := window_for_act(GameState.current_act())
	for key in _window_players:
		_set_playing(_window_players[key], key == w)

static func _set_playing(p: AudioStreamPlayer, should: bool) -> void:
	if should and not p.playing and p.stream != null:
		p.play()
	elif not should and p.playing:
		p.stop()

func active_layers() -> int:
	return GameState.current_act()

## 창밖 소리 — 1~3단은 밤, 4단(유서 복원)부터 새벽
static func window_for_act(act: int) -> String:
	return "dawn" if act >= TENSE_FROM_ACT else "night"

## 이름이 가리키는 파일 — msg는 4단부터 msg_tense로 바뀐다 (파일이 없으면 원래 소리)
func sfx_path(name: String) -> String:
	if name == "msg" and GameState.current_act() >= TENSE_FROM_ACT and ResourceLoader.exists(SFX["msg_tense"]):
		return SFX["msg_tense"]
	if _variant_pools.has(name):
		var pool: Array = _variant_pools[name]
		return pool[randi() % pool.size()]
	if SFX.has(name) and ResourceLoader.exists(SFX[name]):
		return SFX[name]
	return ""

func play_sfx(name: String) -> void:
	var path := sfx_path(name)
	if path == "":
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func variant_count(name: String) -> int:
	return (_variant_pools[name] as Array).size() if _variant_pools.has(name) else 0

## 컴퓨터를 끄면 팬·험·창밖이 함께 멎는다 — 방이 조용해진다. fade 초에 걸쳐.
func silence(fade: float = 1.5) -> void:
	_silenced = true
	var players: Array[AudioStreamPlayer] = _layer_players.duplicate()
	for key in _window_players:
		players.append(_window_players[key])
	for p in players:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)

func play_music(name: String) -> void:
	if not MUSIC.has(name) or not ResourceLoader.exists(MUSIC[name]):
		return
	_music.stream = load(MUSIC[name])
	_music.volume_db = MUSIC_DB
	_music.play()

func stop_music(fade: float = 2.0) -> void:
	if not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -60.0, fade)
	tw.tween_callback(_music.stop)

func music_playing() -> bool:
	return _music.playing
