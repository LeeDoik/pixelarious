extends Node
## 서사 텍스트 — 게임 팩 외부 text.json 런타임 로드 (스펙 §15).

signal text_loaded

var loaded := false
var _doc: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("web"):
		var req := HTTPRequest.new()
		add_child(req)
		# 웹에서는 브라우저가 Content-Encoding을 이미 처리해 넘긴다 —
		# accept_gzip을 켜두면 Godot이 압축 해제된 본문을 한 번 더 풀려다 실패하고 본문이 비어버린다
		req.accept_gzip = false
		req.request_completed.connect(_on_http)
		# JS eval에서 상대 URL이 나오는 것을 막는다 — Godot의 relative request()는 웹 빌드에서
		# ERR_INVALID_PARAMETER로 실패한다(실측 확인). eval이 null/빈 문자열을 주면 상대 경로로 폴백.
		var base_result: Variant = JavaScriptBridge.eval("window.location.href.replace(/[^/]*$/, '')", true)
		var base: String = base_result if typeof(base_result) == TYPE_STRING else ""
		if base == "":
			req.request("text/text.json")
		else:
			req.request(base + "text/text.json")
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
