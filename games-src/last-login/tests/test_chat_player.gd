extends GdUnitTestSuite

const CP := preload("res://src/core/chat_player.gd")

func before_test() -> void:
	GameState.reset()

func test_linear_advance_and_choice_sets_flag() -> void:
	var cp := CP.new(ContentDB.chat_thread(), GameState)
	assert_str(String(cp.current()["text"])).contains("오빠")
	cp.advance()  # n2 (선택지 노드)
	assert_int(cp.current()["choices"].size()).is_equal(2)
	cp.choose(0)  # met_seulgi 플래그
	assert_bool(GameState.has_flag("met_seulgi")).is_true()

func test_choose_applies_target_node_set() -> void:
	var thread := {"start": "a", "nodes": {
		"a": {"from": "seulgi", "text": "q", "choices": [{"text": "x", "next": "b"}]},
		"b": {"from": "seulgi", "text": "t", "set": ["target_flag"]}
	}}
	var cp := CP.new(thread, GameState)
	cp.choose(0)
	assert_bool(GameState.has_flag("target_flag")).is_true()

## 시작의 "어디서요"와 숨은 엔딩의 "어디서 나셨어요?"는 같은 질문이다.
## 답한 사람에게만 마지막에 그 말이 돌아온다 — 그 연결을 여기서 못 박는다.
func test_where_did_you_get_it_is_answerable() -> void:
	var cp := CP.new(ContentDB.chat_thread(), GameState)
	cp.advance()
	cp.choose(0)
	assert_str(String(cp.current()["text"])).contains("어디서")
	assert_int(cp.current()["choices"].size()).is_equal(3)
	cp.choose(0)
	assert_bool(GameState.has_flag("pickup_told")).is_true()

func test_staying_silent_about_where_leaves_no_trace() -> void:
	var cp := CP.new(ContentDB.chat_thread(), GameState)
	cp.advance()
	cp.choose(0)
	cp.choose(2)   # (어디서 주웠는지는 말하지 않는다)
	assert_bool(GameState.has_flag("pickup_told")).is_false()

## 말해주기 — 본선을 제자리에 두고 응답으로 샜다가, 응답이 끝나면 그 자리로 돌아온다
func test_detour_returns_to_where_the_main_line_was() -> void:
	var thread := {"start": "a", "nodes": {
		"a": {"from": "seulgi", "text": "q", "choices": [{"text": "x", "next": "b"}]},
		"b": {"from": "seulgi", "text": "t"},
		"t1": {"from": "seulgi", "text": "r1", "next": "t2"},
		"t2": {"from": "seulgi", "text": "r2", "set": ["heard"]}
	}}
	var cp := CP.new(thread, GameState)
	assert_bool(cp.in_detour()).is_false()
	cp.detour("t1")
	assert_bool(cp.in_detour()).is_true()
	assert_str(cp.current_id()).is_equal("t1")
	assert_bool(cp.advance()).is_true()
	assert_bool(GameState.has_flag("heard")).is_true()     # 응답 노드의 set도 그대로 먹는다
	assert_bool(cp.at_end()).is_true()
	assert_bool(cp.advance()).is_false()
	assert_bool(cp.pop_detour()).is_true()
	assert_str(cp.current_id()).is_equal("a")                # 본선 선택지는 아직 그대로
	assert_int(cp.current()["choices"].size()).is_equal(1)
	assert_bool(cp.pop_detour()).is_false()

## require에 접두가 붙는다 — read:<cid>는 열람 기록, told:<cid>는 플래그 이름 그대로
func test_gate_reads_told_and_read_prefixes() -> void:
	var cp := CP.new(ContentDB.chat_thread(), GameState)
	assert_bool(cp.gate_open("")).is_true()
	assert_bool(cp.gate_open("read:doc:essay_2001")).is_false()
	GameState.mark_read("doc:essay_2001")
	assert_bool(cp.gate_open("read:doc:essay_2001")).is_true()
	assert_bool(cp.gate_open("told:mail:m_welcome")).is_false()
	GameState.set_flag("told:mail:m_welcome")
	assert_bool(cp.gate_open("told:mail:m_welcome")).is_true()
	assert_bool(cp.gate_open("puzzle1_solved")).is_false()

## 본선이 퍼즐 앞에 멈춰 있는지를 다음 노드의 자물쇠로 안다
func test_next_gate_open_reports_the_lock_on_the_next_node() -> void:
	var thread := {"start": "a", "nodes": {
		"a": {"from": "seulgi", "text": "q", "next": "b"},
		"b": {"from": "seulgi", "text": "t", "require": "puzzle1_solved"}
	}}
	var cp := CP.new(thread, GameState)
	assert_bool(cp.next_gate_open()).is_false()
	assert_bool(cp.advance()).is_false()
	GameState.set_flag("puzzle1_solved")
	assert_bool(cp.next_gate_open()).is_true()
	assert_bool(cp.advance()).is_true()
	assert_bool(cp.next_gate_open()).is_false()   # 끝 노드 — 다음이 없다

## 침입자 분기가 종반 허브 양쪽에 걸려 있고, 그 끝이 엔딩 선택지에 닿는지
func test_intruder_branch_is_wired_into_the_finale() -> void:
	var nodes: Dictionary = ContentDB.chat_thread()["nodes"]
	for hub in ["g4l", "g4m"]:
		var found := false
		for c in nodes[hub]["choices"]:
			if String(c.get("require", "")) == "intruder_found":
				found = true
				assert_str(String(c["next"])).is_equal("iq1")
		assert_bool(found).override_failure_message(
			hub + "에 침입자 선택지가 없다").is_true()
	var endings := 0
	for c in nodes["iq4"]["choices"]:
		if Array(c.get("set", [])).has("ending_start"):
			endings += 1
	assert_int(endings).is_equal(2)
