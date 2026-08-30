extends GdUnitTestSuite

const CDB := preload("res://src/core/content_db.gd")

func _make() -> Node:
	var db: Node = auto_free(CDB.new())
	var errors: Array = db.load_all("res://content")
	assert_array(errors).is_empty()
	return db

func test_fs_tree_and_doc_lookup() -> void:
	var db := _make()
	var root: Array = db.fs_children("root")
	assert_int(root.size()).is_greater(0)
	var d: Dictionary = db.doc("doc:essay_2001")
	assert_str(String(d["title"])).is_not_empty()

func test_puzzle_answers_are_alnum() -> void:
	var db := _make()
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9/.]+$")
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		var p: Dictionary = db.puzzle(pid)
		assert_bool(re.search(String(p["answer"])) != null).is_true()

func test_chat_thread_targets_exist() -> void:
	var db := _make()
	var t: Dictionary = db.chat_thread()
	assert_bool(t["nodes"].has(t["start"])).is_true()

func test_validator_catches_missing_doc() -> void:
	var db: Node = auto_free(CDB.new())
	# 존재하지 않는 cid를 참조하는 fs를 메모리에서 주입
	var errors: Array = db.validate({
		"fs": {"nodes": [{"id": "x", "parent": "root", "name": "유령.txt", "type": "doc", "cid": "doc:ghost"}]},
		"docs": {}, "chat": {"start": "n1", "nodes": {"n1": {"from": "sys", "text": "hi"}}, "logs": []},
		"mail": [], "web": {"bookmarks": [], "pages": {}},
		"puzzles": {}, "records": {"records": []}, "strings": {"dev_allow_partial_records": true}
	})
	assert_array(errors).is_not_empty()

## 말해주기 항목은 읽을 수 있는 cid와 실제 응답 노드를 가리켜야 한다 — 하나라도 어긋나면
## "찾은 것 말하기"를 눌렀을 때 조용히 아무 일도 안 일어난다
func test_validator_catches_a_tell_pointing_nowhere() -> void:
	var db: Node = auto_free(CDB.new())
	var base := {
		"fs": {"nodes": []}, "docs": {"doc:a": {"title": "a", "body": "b"}},
		"chat": {"start": "n1", "nodes": {"n1": {"from": "sys", "text": "hi"}, "t1": {"from": "seulgi", "text": "r"}},
			"logs": [], "tells": [{"cid": "doc:a", "say": "a가 있어요", "node": "t1"}]},
		"mail": [], "web": {"bookmarks": [], "pages": {}},
		"puzzles": {}, "records": {"records": []}, "strings": {"dev_allow_partial_records": true}
	}
	assert_array(db.validate(base)).is_empty()
	var bad_cid := base.duplicate(true)
	bad_cid["chat"]["tells"][0]["cid"] = "doc:ghost"
	assert_array(db.validate(bad_cid)).is_not_empty()
	var bad_node := base.duplicate(true)
	bad_node["chat"]["tells"][0]["node"] = "t9"
	assert_array(db.validate(bad_node)).is_not_empty()
	var no_say := base.duplicate(true)
	no_say["chat"]["tells"][0]["say"] = ""
	assert_array(db.validate(no_say)).is_not_empty()

## 힌트는 문자열이거나 {text, require, fallback} — 여전히 정확히 셋
func test_validator_accepts_gated_hints_but_not_empty_ones() -> void:
	var db: Node = auto_free(CDB.new())
	var base := {
		"fs": {"nodes": []}, "docs": {},
		"chat": {"start": "n1", "nodes": {"n1": {"from": "sys", "text": "hi"}}, "logs": []},
		"mail": [], "web": {"bookmarks": [], "pages": {}},
		"puzzles": {"puzzle1": {"answer": "1", "hints": ["a", {"text": "b", "require": "told:doc:x", "fallback": "c"}, "d"]}},
		"records": {"records": []}, "strings": {"dev_allow_partial_records": true}
	}
	assert_array(db.validate(base)).is_empty()
	var bad := base.duplicate(true)
	bad["puzzles"]["puzzle1"]["hints"][1] = {"require": "told:doc:x"}
	assert_array(db.validate(bad)).is_not_empty()

## 실제 콘텐츠의 말해주기 항목 — 열다섯은 넘고, 전부 다른 열쇠(파일 또는 질문)를 가진다
func test_shipped_tells_are_plentiful_and_distinct() -> void:
	var db := _make()
	var tells: Array = db.tells()
	assert_int(tells.size()).is_greater_equal(15)
	var seen := {}
	for t in tells:
		var key: String = String(t["cid"]) if t.has("cid") else "ask:" + String(t["id"])
		assert_bool(seen.has(key)).override_failure_message(
			"같은 열쇠에 말하기 항목이 둘: " + key).is_false()
		seen[key] = true

## 자물쇠 없는 퍼즐(질문이 열쇠)은 answer 없이 힌트만 가진다 — 대화상자로는 못 푼다
func test_a_question_puzzle_has_no_answer_and_cannot_be_typed() -> void:
	var db := _make()
	var p: Dictionary = db.puzzle("puzzle6")
	assert_bool(p.has("answer")).is_false()
	assert_int(p["hints"].size()).is_equal(3)
	GameState.reset()
	assert_bool(GameState.try_answer("puzzle6", "choiyoungsik")).is_false()
	assert_bool(GameState.has_flag("puzzle6_solved")).is_false()

## 압축 폴더 첨부는 fs에 그 폴더를 부모로 둔 노드가 있어야 하고, 물어보기는 cid 대신 id로 선다
func test_validator_checks_zip_attachments_and_questions() -> void:
	var db: Node = auto_free(CDB.new())
	var base := {
		"fs": {"nodes": [{"id": "z1", "parent": "zip_x", "name": "a.txt", "type": "doc", "cid": "doc:a", "mtime": "2002-11-02 19:00"}]},
		"docs": {"doc:a": {"title": "a", "body": "b"}},
		"chat": {"start": "n1", "nodes": {"n1": {"from": "sys", "text": "hi"}, "t1": {"from": "seulgi", "text": "r"}},
			"logs": [], "tells": [{"id": "birthday", "ask": true, "say": "생일이요?", "node": "t1", "require": "met_seulgi"}]},
		"mail": [{"id": "m9", "from": "x", "date": "2002-11-02", "subject": "s", "body": "b",
			"attachment": {"name": "x.zip", "locked_by": "puzzle5", "folder": "zip_x"}}],
		"web": {"bookmarks": [], "pages": {}},
		"puzzles": {}, "records": {"records": []}, "strings": {"dev_allow_partial_records": true}
	}
	assert_array(db.validate(base)).is_empty()
	var empty_zip := base.duplicate(true)
	empty_zip["mail"][0]["attachment"]["folder"] = "zip_nowhere"
	assert_array(db.validate(empty_zip)).is_not_empty()
	var no_key := base.duplicate(true)
	no_key["chat"]["tells"][0].erase("id")
	assert_array(db.validate(no_key)).is_not_empty()

func test_exactly_nine_records_enforced() -> void:
	var db := _make()
	assert_int(db.records().size()).is_equal(9)

func test_validator_rejects_missing_sections() -> void:
	var db: Node = auto_free(CDB.new())
	var errors: Array = db.validate({"fs": {"nodes": []}})
	assert_array(errors).is_not_empty()

## 성진은 유서에 "같은 글 마이홈 비밀글 17번에도 올려놓았음"이라고 쓴다.
## 두 사본이 갈라지면 퍼즐3의 보상(관문까지 가서 얻는 증거)이 조용히 깨진다 —
## 한쪽만 고치는 사고는 눈으로는 안 잡힌다. 둘 다 가져야 하는 사실을 목록으로 못 박는다.
func test_the_will_and_its_web_copy_carry_the_same_evidence() -> void:
	var db := _make()
	var will: String = String(db.doc("doc:diary_final")["body"])
	var page: Dictionary = db.web_page("myhome.nurinet.co.kr/sj2002/diary/17")
	var copy: String = String(page.get("body", ""))
	assert_str(copy).is_not_empty()
	for fact in ["가천분교", "4862", "흰 건물 두 동", "진부"]:
		assert_str(will).override_failure_message(
			"유서에 '%s'가 없다" % fact).contains(fact)
		assert_str(copy).override_failure_message(
			"diary/17 사본에 '%s'가 없다 — 유서만 고쳐졌다" % fact).contains(fact)

## 성진은 8월 수련회 뒤로 수련원에 간 적이 없다. 11월 1일 메모가 "앞 글자를 못 봤다"고
## 써 둔 간판을 다음날 유서가 "이번엔 똑똑히 봤다"고 하면 없는 방문이 생긴다.
func test_the_will_does_not_claim_a_second_visit() -> void:
	var db := _make()
	var will: String = String(db.doc("doc:diary_final")["body"])
	assert_str(will).override_failure_message(
		"유서가 간판을 다시 봤다고 말한다 — 코퍼스 어디에도 두 번째 방문이 없다"
	).not_contains("간판을 이번엔")

## 이미지 노드가 가리키는 파일이 실제로 있어야 한다 — 탐색기에서 열면 빈 창이 된다
func test_every_image_node_has_its_asset() -> void:
	var nodes: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/fs.json"))["nodes"]
	var seen := 0
	for n in nodes:
		if String(n.get("type", "")) != "image":
			continue
		seen += 1
		assert_bool(FileAccess.file_exists(String(n.get("image", "")))).override_failure_message(
			"%s의 이미지 파일이 없다: %s" % [n.get("name"), n.get("image")]).is_true()
	assert_int(seen).is_equal(12)   # 기존 5장 + 필사 3장 + 서원문 + 비움기록 + 정리.zip 안의 둘
