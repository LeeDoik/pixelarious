extends Node
## 원샷 SFX + 앰비언트 루프. 스트림이 없으면 조용히 무시.

var _streams: Dictionary = {}
var _ambient: AudioStreamPlayer

func _ready() -> void:
	for n in ["hop", "capture", "warn", "death", "combo", "ambient"]:
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

func start_ambient() -> void:
	if _ambient != null or not _streams.has("ambient"):
		return
	var stream: AudioStreamWAV = _streams["ambient"]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = stream
	_ambient.volume_db = -10.0
	add_child(_ambient)
	_ambient.play()

func stop_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
