extends Node
## 앰비언트 레이어(액트 수만큼 겹침) + SFX 원샷.

const SFX := {
	"msg": "res://assets/sfx/msg.wav", "unlock": "res://assets/sfx/unlock.wav",
	"click": "res://assets/sfx/click.wav", "boot": "res://assets/sfx/boot.wav",
	"startup": "res://assets/sfx/startup.wav",
	"error": "res://assets/sfx/error.wav",
}
const LAYERS := ["res://assets/sfx/amb_fan.wav", "res://assets/sfx/amb_hum.wav", "res://assets/sfx/amb_drone.wav"]

var _layer_players: Array[AudioStreamPlayer] = []
var _variant_pools: Dictionary = {}  # 이름 -> 경로 배열 (매번 랜덤 재생)

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
		var p := AudioStreamPlayer.new()
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = stream.data.size() / 2
			p.stream = stream
		p.volume_db = -14.0
		add_child(p)
		_layer_players.append(p)
	GameState.act_changed.connect(func(_a): _sync_layers())
	_sync_layers()

func _sync_layers() -> void:
	for i in _layer_players.size():
		var should := i < GameState.current_act()
		var p := _layer_players[i]
		if should and not p.playing and p.stream != null:
			p.play()
		elif not should and p.playing:
			p.stop()

func active_layers() -> int:
	return GameState.current_act()

func play_sfx(name: String) -> void:
	var path: String
	if _variant_pools.has(name):
		var pool: Array = _variant_pools[name]
		path = pool[randi() % pool.size()]
	elif SFX.has(name) and ResourceLoader.exists(SFX[name]):
		path = SFX[name]
	else:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func variant_count(name: String) -> int:
	return (_variant_pools[name] as Array).size() if _variant_pools.has(name) else 0
