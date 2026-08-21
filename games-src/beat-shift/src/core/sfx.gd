extends Node
## 원샷 SFX. 스트림이 없으면 조용히 무시 — 에셋 없이도 게임이 동작한다.

const NAMES := ["precue", "good", "miss", "whiff", "jingle", "gameover",
	"anvil_1", "anvil_2", "anvil_3", "anvil_4"]

var _streams: Dictionary = {}

func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)

func has_stream(name: String) -> bool:
	return _streams.has(name)

func play(name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = _streams[name]
	pl.volume_db = volume_db
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()
