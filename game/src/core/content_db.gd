extends Node
## content/*.json 로드와 스키마 검증. 게임의 모든 서사 데이터 접근 창구.

var _d: Dictionary = {}

func _ready() -> void:
	var errors := load_all()
	if not errors.is_empty():
		push_error("ContentDB validation failed: " + str(errors))

func load_all(base: String = "res://content") -> Array:
	var raw := {}
	for key in ["fs", "docs", "chat", "mail", "web", "puzzles", "records", "strings"]:
		var path := "%s/%s.json" % [base, key]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			return ["cannot parse " + path]
		raw[key] = parsed
	var errors := validate(raw)
	if errors.is_empty():
		_d = raw
	return errors

func validate(raw: Dictionary) -> Array:
	var errors: Array = []
	var docs: Dictionary = raw["docs"]
	var web_pages: Dictionary = raw["web"]["pages"]
	var known_cids := {}
	for cid in docs.keys():
		known_cids[cid] = true
	for url in web_pages.keys():
		if web_pages[url].has("cid"):
			known_cids[web_pages[url]["cid"]] = true
	# fs가 참조하는 cid 존재 확인 (image 유형은 파일 경로라 제외)
	for n in raw["fs"]["nodes"]:
		if n.get("type") == "doc" and not n.get("corrupt", false) and not docs.has(n.get("cid", "")):
			errors.append("fs node %s references missing doc %s" % [n["id"], n.get("cid", "?")])
	# mail 첨부 cid
	for m in raw["mail"]:
		if m.has("attachment") and not docs.has(m["attachment"].get("cid", "")):
			errors.append("mail %s attachment missing doc" % m["id"])
		known_cids["mail:" + m["id"]] = true
	# chat 노드 연결
	var nodes: Dictionary = raw["chat"]["nodes"]
	if not nodes.has(raw["chat"]["start"]):
		errors.append("chat start node missing")
	for id in nodes:
		var node: Dictionary = nodes[id]
		var targets: Array = []
		if node.has("next"):
			targets.append(node["next"])
		for c in node.get("choices", []):
			targets.append(c["next"])
		for t in targets:
			if not nodes.has(t):
				errors.append("chat node %s -> missing %s" % [id, t])
	# 퍼즐 정답 영숫자(+주소용 / .)
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9/.]+$")
	for pid in raw["puzzles"]:
		var p: Dictionary = raw["puzzles"][pid]
		if re.search(String(p.get("answer", ""))) == null:
			errors.append("puzzle %s answer not alnum" % pid)
		if p.get("hints", []).size() != 3:
			errors.append("puzzle %s needs exactly 3 hints" % pid)
	# 기록물 존재 + 9개 (개발 중 완화 플래그)
	var recs: Array = raw["records"]["records"]
	for cid in recs:
		if not known_cids.has(cid):
			errors.append("record cid missing: " + str(cid))
	if not raw["strings"].get("dev_allow_partial_records", false) and recs.size() != 9:
		errors.append("records must be exactly 9, got %d" % recs.size())
	return errors

func fs_children(parent_id: String) -> Array:
	var out: Array = []
	for n in _d["fs"]["nodes"]:
		if n.get("parent") == parent_id:
			out.append(n)
	return out

func fs_node(id: String) -> Dictionary:
	for n in _d["fs"]["nodes"]:
		if n["id"] == id:
			return n
	return {}

func trash_items() -> Array:
	return fs_children("trash")

func doc(cid: String) -> Dictionary:
	return _d["docs"].get(cid, {})

func chat_thread() -> Dictionary:
	return {"start": _d["chat"]["start"], "nodes": _d["chat"]["nodes"]}

func chat_logs() -> Array:
	return _d["chat"]["logs"]

func mails() -> Array:
	return _d["mail"]

func web_bookmarks() -> Array:
	return _d["web"]["bookmarks"]

func web_page(url: String) -> Dictionary:
	return _d["web"]["pages"].get(url, {})

func puzzle(id: String) -> Dictionary:
	return _d["puzzles"].get(id, {})

func records() -> Array:
	return _d["records"]["records"]

func ui(key: String) -> String:
	return String(_d["strings"].get(key, key))
