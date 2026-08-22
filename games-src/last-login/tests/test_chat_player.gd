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
