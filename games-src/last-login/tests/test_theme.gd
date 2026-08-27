extends GdUnitTestSuite

## 이 스위트가 막는 사고: 앱이 쓰는 위젯에 테마 항목이 비어 있으면 Godot 기본 테마
## (둥근 모서리 + 어두운 판 + 흰 글자)가 2002년 창 안에 그대로 뜬다. 눈으로만 보면
## 그 앱을 열어보기 전까지 모른다.

const REQUIRED_STYLEBOXES := [
	["Panel", "panel"],
	["PanelContainer", "panel"],       # 대화상자·알림이 여기로 샜다
	["Button", "normal"],
	["Button", "pressed"],
	["CheckBox", "normal"],
	["LineEdit", "normal"],
	["ItemList", "panel"],
	["Tree", "panel"],
	# 목록 줄의 상태 조합 — 고른 줄에 마우스를 얹은 순간 흰 글자 밑에 흰 판이 깔렸다
	["ItemList", "hovered"],
	["ItemList", "selected"],
	["ItemList", "hovered_selected"],
	["ItemList", "selected_focus"],
	["ItemList", "hovered_selected_focus"],
	["Tree", "hovered"],
	["Tree", "hovered_dimmed"],
	["Tree", "selected"],
	["Tree", "hovered_selected"],
	["Tree", "selected_focus"],
	["Tree", "hovered_selected_focus"],
	["RichTextLabel", "normal"],       # 메일·누리넷·휴지통·메모장의 본문 표면
	["TabContainer", "panel"],         # PC통신 본문 전체
	["TabBar", "tab_selected"],
	["PopupMenu", "panel"],            # LineEdit 우클릭 메뉴가 이걸 쓴다
	["TooltipPanel", "panel"],         # 탐색기 아이콘 보기의 전체 이름 풍선
	["ProgressBar", "background"],    # 휴지통 복원 진행률
	["ProgressBar", "fill"],
	["HSlider", "slider"],
	["VScrollBar", "grabber"],
	["HScrollBar", "grabber"],
]

const REQUIRED_ICONS := [
	["CheckBox", "checked"],
	["CheckBox", "unchecked"],
	["HSlider", "grabber"],
]

func test_theme_covers_every_widget_the_apps_use() -> void:
	var t := NuriTheme.shared()
	for entry in REQUIRED_STYLEBOXES:
		assert_bool(t.has_stylebox(entry[1], entry[0])).override_failure_message(
			"테마에 %s/%s 스타일박스가 없다 — Godot 기본값이 화면에 샌다" % [entry[0], entry[1]]).is_true()

## 글자와 그 밑에 깔리는 판의 명도가 붙어 있으면 그 상태에서만 글씨가 사라진다.
## Godot 기본 테마의 글자색이 죄다 흰색 계열이라, 한 조합만 빠뜨려도 이 사고가 난다.
const READABLE_PAIRS := [
	["ItemList", "font_color", "panel"],
	["ItemList", "font_hovered_color", "hovered"],
	["ItemList", "font_selected_color", "selected"],
	["ItemList", "font_hovered_selected_color", "hovered_selected"],
	["ItemList", "font_selected_color", "selected_focus"],
	["ItemList", "font_hovered_selected_color", "hovered_selected_focus"],
	["Tree", "font_hovered_color", "hovered"],
	["Tree", "font_hovered_dimmed_color", "hovered_dimmed"],
	["Tree", "font_hovered_selected_color", "hovered_selected"],
	["Tree", "font_hovered_selected_color", "hovered_selected_focus"],
]

const MIN_CONTRAST := 0.25

func test_list_rows_stay_readable_in_every_state() -> void:
	var t := NuriTheme.shared()
	for entry in READABLE_PAIRS:
		var fg: Color = t.get_color(entry[1], entry[0])
		var box: StyleBox = t.get_stylebox(entry[2], entry[0])
		var bg: Color = box.bg_color if box is StyleBoxFlat else NuriTheme.FIELD
		var gap: float = absf(fg.get_luminance() - bg.get_luminance())
		assert_float(gap).override_failure_message(
			"%s: %s(%s)가 %s(%s) 위에서 안 읽힌다 — 명도차 %.2f" % [
				entry[0], entry[1], fg.to_html(false), entry[2], bg.to_html(false), gap]
			).is_greater(MIN_CONTRAST)

## 버튼은 누르고 있는 동안·포커스가 갔을 때도 글자가 보여야 한다
func test_button_labels_survive_every_state() -> void:
	var t := NuriTheme.shared()
	for type in ["Button", "CheckBox"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color",
				"font_hover_pressed_color", "font_focus_color"]:
			assert_bool(t.has_color(state, type)).override_failure_message(
				"테마에 %s/%s가 없다 — 기본 테마의 흰 글자가 베이지 판 위에 뜬다" % [type, state]).is_true()
			assert_float(t.get_color(state, type).get_luminance()).override_failure_message(
				"%s/%s가 너무 밝다" % [type, state]).is_less(0.5)

func test_theme_supplies_widget_glyphs() -> void:
	var t := NuriTheme.shared()
	for entry in REQUIRED_ICONS:
		assert_bool(t.has_icon(entry[1], entry[0])).override_failure_message(
			"테마에 %s/%s 아이콘이 없다 (scripts/gen_icons.py 생성물)" % [entry[0], entry[1]]).is_true()

func test_shared_theme_is_a_single_instance() -> void:
	# 창마다 build()를 부르면 나인패치를 그만큼 다시 굽고, 테마 수정이 일부에만 반영된다
	assert_object(NuriTheme.shared()).is_same(NuriTheme.shared())

func test_bevel_pair_flips_the_light_source() -> void:
	# 위-왼쪽은 raised가 밝고, 아래-오른쪽은 sunken이 밝다. 두 베벨이 같은 방향을 보면
	# 눌린 버튼과 튀어나온 버튼이 화면에서 구별되지 않는다.
	var a := NuriTheme.raised(NuriTheme.FACE).texture.get_image()
	var b := NuriTheme.sunken(NuriTheme.FACE).texture.get_image()
	assert_bool(a.get_pixel(0, 0).get_luminance() > b.get_pixel(0, 0).get_luminance()).override_failure_message(
		"raised의 좌상단이 sunken보다 밝아야 한다").is_true()
	assert_bool(b.get_pixel(5, 5).get_luminance() > a.get_pixel(5, 5).get_luminance()).override_failure_message(
		"sunken의 우하단이 raised보다 밝아야 한다").is_true()
