extends GdUnitTestSuite

const BrowserApp := preload("res://src/apps/browser.gd")

func before_test() -> void:
	GameState.reset()

func test_dead_cafe_page_renders_closed_notice() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page: Dictionary = b.navigate("cafe.nurinet.co.kr/saebit")
	assert_str(String(page["title"])).contains("찾을 수 없습니다")

func test_gate_url_solves_puzzle3_and_marks_record() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page: Dictionary = b.navigate("cafe.nurinet.co.kr/saebit/gate")
	assert_bool(GameState.has_flag("puzzle3_solved")).is_true()
	assert_bool(GameState.is_read("web:cafe_gate")).is_true()
	assert_str(String(page["title"])).contains("새빛")

func test_unknown_url_returns_empty() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	assert_bool(b.navigate("nowhere.example").is_empty()).is_true()
