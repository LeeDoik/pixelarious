extends Node
## content/*.json 로드와 스키마 검증. 게임의 모든 서사 데이터 접근 창구.

const TRASH_ID := "trash"
const PURGED_ID := "__purged"   # 영구 삭제된 파일이 가는 자리 (어떤 폴더도 아니다)

var _d: Dictionary = {}

func _ready() -> void:
	var errors := load_all()
	if not errors.is_empty():
		push_error("ContentDB validation failed: " + str(errors))

func load_all(base: String = "res://content") -> Array[String]:
	var raw := {}
	for key in ["fs", "docs", "chat", "mail", "web", "puzzles", "records", "strings"]:
		var path := "%s/%s.json" % [base, key]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			var e: Array[String] = ["cannot parse " + path]
			return e
		raw[key] = parsed
	# 도움말·엔딩은 있어도 되고 없어도 된다 — 없으면 코드의 뼈대가 대신한다
	for extra in ["help", "ending"]:
		var extra_path := "%s/%s.json" % [base, extra]
		if FileAccess.file_exists(extra_path):
			var parsed_extra = JSON.parse_string(FileAccess.get_file_as_string(extra_path))
			if parsed_extra == null:
				var e: Array[String] = ["cannot parse " + extra_path]
				return e
			raw[extra] = parsed_extra
	var errors := validate(raw)
	if errors.is_empty():
		_d = raw
	return errors

func validate(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	# 구조 사전 검사: 최상위 키 존재 + 타입 확인 (없으면 아래 깊은 검사가 크래시함)
	var required_types := {
		"fs": TYPE_DICTIONARY,
		"docs": TYPE_DICTIONARY,
		"chat": TYPE_DICTIONARY,
		"mail": TYPE_ARRAY,
		"web": TYPE_DICTIONARY,
		"puzzles": TYPE_DICTIONARY,
		"records": TYPE_DICTIONARY,
		"strings": TYPE_DICTIONARY,
	}
	for key in required_types:
		if not raw.has(key) or typeof(raw[key]) != required_types[key]:
			errors.append("section missing or wrong type: %s" % key)
	if raw.has("fs") and typeof(raw["fs"]) == TYPE_DICTIONARY:
		if not raw["fs"].has("nodes") or typeof(raw["fs"]["nodes"]) != TYPE_ARRAY:
			errors.append("section missing or wrong type: fs.nodes")
	if raw.has("web") and typeof(raw["web"]) == TYPE_DICTIONARY:
		if not raw["web"].has("pages") or typeof(raw["web"]["pages"]) != TYPE_DICTIONARY:
			errors.append("section missing or wrong type: web.pages")
	if raw.has("chat") and typeof(raw["chat"]) == TYPE_DICTIONARY:
		if not raw["chat"].has("start"):
			errors.append("section missing or wrong type: chat.start")
		if not raw["chat"].has("nodes") or typeof(raw["chat"]["nodes"]) != TYPE_DICTIONARY:
			errors.append("section missing or wrong type: chat.nodes")
	if raw.has("records") and typeof(raw["records"]) == TYPE_DICTIONARY:
		if not raw["records"].has("records") or typeof(raw["records"]["records"]) != TYPE_ARRAY:
			errors.append("section missing or wrong type: records.records")
	if not errors.is_empty():
		return errors
	var docs: Dictionary = raw["docs"]
	var web_pages: Dictionary = raw["web"]["pages"]
	var known_cids := {}
	for cid in docs.keys():
		known_cids[cid] = true
	for url in web_pages.keys():
		if web_pages[url].has("cid"):
			known_cids[web_pages[url]["cid"]] = true
	# 메신저 로그는 chatlog:<date> 로 mark_read 된다 (Messenger 지난 대화 탭)
	for lg in raw["chat"].get("logs", []):
		known_cids["chatlog:" + String(lg.get("date", ""))] = true
	# fs가 참조하는 cid 존재 확인 (image 유형은 파일 경로라 doc 존재 검사에서 제외)
	for n in raw["fs"]["nodes"]:
		if n.get("type") == "doc" and not n.get("corrupt", false) and not docs.has(n.get("cid", "")):
			errors.append("fs node %s references missing doc %s" % [n["id"], n.get("cid", "?")])
		if n.get("type") == "image" and n.has("cid"):
			known_cids[n["cid"]] = true
	# mail 첨부 — 문서(cid)이거나 압축 폴더(folder: fs에 그 부모를 가진 노드가 있어야)
	for m in raw["mail"]:
		if m.has("attachment"):
			var a: Dictionary = m["attachment"]
			if a.has("folder"):
				var inside := 0
				for n in raw["fs"]["nodes"]:
					if String(n.get("parent", "")) == String(a["folder"]):
						inside += 1
				if inside == 0:
					errors.append("mail %s attachment folder %s is empty" % [m["id"], a["folder"]])
			elif not docs.has(a.get("cid", "")):
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
	# 말해주기 항목 — 읽을 수 있는 cid(찾은 것)이거나 id(물어보기)여야 하고,
	# 응답 노드가 있어야 하고, 할 말이 있어야 한다
	for t in raw["chat"].get("tells", []):
		var tcid := String(t.get("cid", ""))
		if tcid == "" and String(t.get("id", "")) == "":
			errors.append("tell without cid or id: " + str(t.get("say", "?")))
		elif tcid != "" and not known_cids.has(tcid):
			errors.append("tell cid missing: " + tcid)
		if not nodes.has(String(t.get("node", ""))):
			errors.append("tell %s -> missing node %s" % [tcid, t.get("node", "?")])
		if String(t.get("say", "")) == "":
			errors.append("tell %s has no say" % tcid)
	# 퍼즐 정답 영숫자(+주소용 / .) · 힌트는 셋 — 문자열이거나 {text, require, fallback}
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9/.]+$")
	for pid in raw["puzzles"]:
		var p: Dictionary = raw["puzzles"][pid]
		# answer가 없는 퍼즐은 "질문이 열쇠" — 자물쇠 대신 대화 노드가 <id>_solved를 찍는다
		if p.has("answer") and re.search(String(p["answer"])) == null:
			errors.append("puzzle %s answer not alnum" % pid)
		if p.get("hints", []).size() != 3:
			errors.append("puzzle %s needs exactly 3 hints" % pid)
		for h in p.get("hints", []):
			if typeof(h) == TYPE_DICTIONARY and String(h.get("text", "")) == "":
				errors.append("puzzle %s hint without text" % pid)
			elif typeof(h) != TYPE_DICTIONARY and typeof(h) != TYPE_STRING:
				errors.append("puzzle %s hint of wrong type" % pid)
	# 기록물 존재 + 9개 (개발 중 완화 플래그)
	var recs: Array = raw["records"]["records"]
	for cid in recs:
		if not known_cids.has(cid):
			errors.append("record cid missing: " + str(cid))
	if not raw["strings"].get("dev_allow_partial_records", false) and recs.size() != 9:
		errors.append("records must be exactly 9, got %d" % recs.size())
	return errors

func fs_children(parent_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in _d["fs"]["nodes"]:
		if effective_parent(n) == parent_id:
			out.append(n)
	return out

func effective_parent(n: Dictionary) -> String:
	## 휴지통 안의 파일만 자리가 고정이 아니다 — 복원하면 원래 폴더로 옮겨가고,
	## 휴지통을 비우면 손상된 것들은 어디에도 없어진다. 그 상태는 콘텐츠가 아니라
	## 진행 상태라서 GameState가 갖고, 여기서는 물어보기만 한다.
	var parent := String(n.get("parent", ""))
	if parent != TRASH_ID:
		return parent
	if GameState.is_restored(String(n["id"])):
		return String(n.get("origin", "mydocs"))
	if n.get("corrupt", false) and GameState.has_flag("trash_purged"):
		return PURGED_ID
	return parent

func fs_node(id: String) -> Dictionary:
	for n in _d["fs"]["nodes"]:
		if n["id"] == id:
			return n
	return {}

func trash_items() -> Array[Dictionary]:
	return fs_children(TRASH_ID)

func doc(cid: String) -> Dictionary:
	return _d["docs"].get(cid, {})

func chat_thread() -> Dictionary:
	return {"start": _d["chat"]["start"], "nodes": _d["chat"]["nodes"]}

func chat_logs() -> Array:
	return _d["chat"]["logs"]

## 플레이어가 슬기에게 말해줄 수 있는 것들 — {cid, say, node}
func tells() -> Array:
	return _d["chat"].get("tells", [])

func help_topics() -> Array:
	return _d.get("help", {}).get("topics", [])

## 에필로그·숨은 신의 줄들 — {epilogue: [{text, require?}], hidden: [...]}
func ending() -> Dictionary:
	return _d.get("ending", {})

## 퍼즐의 종류로 찾는다 — "restore"(휴지통 복원이 정답) 같은 앱 쪽 자물쇠는 id를 박지 않고 이걸로 묻는다
func puzzle_of_kind(kind: String) -> String:
	for pid in _d["puzzles"]:
		if String(_d["puzzles"][pid].get("kind", "")) == kind:
			return pid
	return ""

func mails() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_d["mail"])
	return out

func web_bookmarks() -> Array:
	return _d["web"]["bookmarks"]

func web_page(url: String) -> Dictionary:
	return _d["web"]["pages"].get(url, {})

func puzzle(id: String) -> Dictionary:
	return _d["puzzles"].get(id, {})

## puzzles.json에 적힌 순서 — 힌트 엔진이 첫 미해결 퍼즐을 이 순서로 고른다
func puzzle_ids() -> Array:
	return _d["puzzles"].keys()

func records() -> Array:
	return _d["records"]["records"]

func ui(key: String) -> String:
	return String(_d["strings"].get(key, key))
