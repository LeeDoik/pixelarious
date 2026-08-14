extends Node
## 앰비언트 레이어(액트 수만큼 겹침) + SFX 원샷.

const SFX := {
	"msg": "res://assets/sfx/msg.wav", "unlock": "res://assets/sfx/unlock.wav",
	"click": "res://assets/sfx/click.wav", "boot": "res://assets/sfx/boot.wav",
}
const LAYERS := ["res://assets/sfx/amb_fan.wav", "res://assets/sfx/amb_hum.wav", "res://assets/sfx/amb_drone.wav"]

var _layer_players: Array[AudioStreamPlayer] = []
var _click_variants: Array[String] = []

func _ready() -> void:
	# 실제 녹음을 분할한 클릭 변주들 — 클릭마다 랜덤 재생 (없으면 신디사이징 click.wav 폴백)
	var i := 1
	while ResourceLoader.exists("res://assets/sfx/click_%d.wav" % i):
		_click_variants.append("res://assets/sfx/click_%d.wav" % i)
		i += 1
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
	if name == "click" and not _click_variants.is_empty():
		path = _click_variants[randi() % _click_variants.size()]
	elif SFX.has(name) and ResourceLoader.exists(SFX[name]):
		path = SFX[name]
	else:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func click_variant_count() -> int:
	return _click_variants.size()
