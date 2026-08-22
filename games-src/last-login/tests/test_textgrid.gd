extends GdUnitTestSuite

## 이 스위트가 막는 사고: 누리넷 페이지들은 한글 2칸 / ASCII 1칸 격자로 손수 짜였다
## (게시판 표, 점선 리더, 박스 그리기). 폰트가 그 비율이 아니면 열이 전부 어긋나고,
## 폰트 크기를 바꿔서는 고쳐지지 않는다 — Galmuri는 어떤 크기에서도 ASCII 최대폭이
## 한글의 0.8배다. 그래서 본문만 Neo둥근모를 쓴다.

const TextGrid := preload("res://src/apps/textgrid.gd")
const BODY_FONT := "res://assets/fonts/neodgm.ttf"
const ASCII := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ .,:;'\"()[]/-_*#%"

func _make(text: String) -> Control:
	var g: Control = auto_free(TextGrid.new())
	g.add_theme_font_override("font", load(BODY_FONT))
	g.add_theme_font_size_override("font_size", 16)
	add_child(g)
	g.grid_text = text
	return g

func test_body_font_is_exactly_two_to_one() -> void:
	var f: Font = load(BODY_FONT)
	for size in [16, 20, 24]:
		var wide := f.get_string_size("가", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for i in ASCII.length():
			var w := f.get_string_size(ASCII[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			assert_float(w * 2.0).override_failure_message(
				"크기 %d에서 '%s'(%.0fpx)가 한글(%.0fpx)의 절반이 아니다" % [size, ASCII[i], w, wide]
			).is_equal_approx(wide, 0.01)

func test_columns_line_up_across_rows() -> void:
	# 게시판 표가 어긋났던 자리. 같은 칸에서 시작해야 할 글자가 같은 칸에 놓이는지 본다.
	var g := _make("1198  민규\n1191  합격기원\n1187  무명")
	assert_int(g.column_of(0, 6)).is_equal(6)
	assert_int(g.column_of(1, 6)).is_equal(6)
	assert_int(g.column_of(2, 6)).is_equal(6)

func test_hangul_takes_two_cells_and_ascii_one() -> void:
	var g := _make("가a")
	assert_int(g.column_of(0, 0)).is_equal(0)   # '가'
	assert_int(g.column_of(0, 1)).is_equal(2)   # 'a' — 한글 다음 두 칸 뒤

func test_urls_become_links_and_dates_do_not() -> void:
	var g := _make("2002.11.02 에 myhome.nurinet.co.kr/sj2002/guest 를 봤다")
	assert_int(g.link_count()).is_equal(1)
	assert_str(String(g.links()[0]["url"])).is_equal("myhome.nurinet.co.kr/sj2002/guest")

func test_short_hosts_are_not_links() -> void:
	# 점 하나짜리(파일명 등)를 링크로 잡으면 본문이 밑줄 범벅이 된다
	var g := _make("새빛자료.zip 과 index.html 을 열었다")
	assert_int(g.link_count()).is_equal(0)

func test_every_glyph_in_web_content_can_be_drawn() -> void:
	# 폰트에 없는 글자는 화면에서 조용히 사라진다. 폴백까지 포함해 확인한다.
	var main: Font = load(BODY_FONT)
	var fallback: Font = load("res://assets/fonts/Galmuri11.ttf")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	var missing := ""
	for url in raw["pages"]:
		var body := String(raw["pages"][url]["body"])
		for i in body.length():
			var code := body.unicode_at(i)
			if code <= 32:
				continue
			if not main.has_char(code) and not fallback.has_char(code):
				missing += body[i]
	assert_str(missing).override_failure_message(
		"neodgm에도 Galmuri에도 없는 글자: " + missing).is_empty()
