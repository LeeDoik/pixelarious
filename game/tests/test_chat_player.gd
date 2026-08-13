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
