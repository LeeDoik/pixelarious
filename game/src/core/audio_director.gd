extends Node
## 앰비언트 레이어(액트 수만큼 겹침) + SFX 원샷.

const SFX := {
	"msg": "res://assets/sfx/msg.wav", "unlock": "res://assets/sfx/unlock.wav",
	"click": "res://assets/sfx/click.wav", "boot": "res://assets/sfx/boot.wav",
}
const LAYERS := ["res://assets/sfx/amb_fan.wav", "res://assets/sfx/amb_hum.wav", "res://assets/sfx/amb_drone.wav"]

var _layer_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
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
	if not SFX.has(name) or not ResourceLoader.exists(SFX[name]):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(SFX[name])
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
