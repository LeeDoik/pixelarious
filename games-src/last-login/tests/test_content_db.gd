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
	assert_int(seen).is_equal(9)   # 기존 5장 + 필사 3장 + 서원문

func test_bowl_record_is_hidden_inside_locked_folder() -> void:
	var db := _make()
	var n: Dictionary = db.fs_node("l_bowl")
	assert_dict(n).is_not_empty()
	assert_str(String(n.get("parent", ""))).is_equal("locked")
	assert_bool(n.get("hidden", false)).is_true()
	assert_str(String(n.get("cid", ""))).is_equal("doc:bowl_record")

func test_bowl_record_body_has_no_observation_paragraph() -> void:
	## 제출본에만 있는 문단이다 — 사본에 있으면 퍼즐6이 성립하지 않는다
	var db := _make()
	var body := String(db.doc("doc:bowl_record").get("body", ""))
	assert_str(body).is_not_empty()
	assert_str(body).not_contains("○○ 님은")

func test_evidence_memo_points_at_the_hidden_file() -> void:
	var db := _make()
	var body := String(db.doc("doc:evidence_memo").get("body", ""))
	assert_str(body).contains("안 보이게 해놨다")
