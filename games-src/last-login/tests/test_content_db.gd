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
