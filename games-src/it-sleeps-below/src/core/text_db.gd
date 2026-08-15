extends Node
## 서사 텍스트 — 게임 팩 외부 text.json 런타임 로드 (스펙 §15).

signal text_loaded

var loaded := false
var _doc: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("web"):
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(_on_http)
		req.request("text/text.json")
	else:
		var path := ProjectSettings.globalize_path("res://").path_join("../../public/games/it-sleeps-below/text/text.json")
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			_parse(f.get_as_text())

func _on_http(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		_parse(body.get_string_from_utf8())

func _parse(raw: String) -> void:
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) == TYPE_DICTIONARY:
		_doc = data
		loaded = true
		text_loaded.emit()

func t(cat: String, key: String) -> String:
	var lang: String = GameState.profile.settings.lang
	if _doc.has(cat) and _doc[cat].has(key) and _doc[cat][key].has(lang):
		return _doc[cat][key][lang]
	return "[%s.%s]" % [cat, key]
