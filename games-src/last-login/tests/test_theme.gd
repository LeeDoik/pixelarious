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
	["RichTextLabel", "normal"],       # 메일·누리넷·휴지통·메모장의 본문 표면
	["TabContainer", "panel"],         # PC통신 본문 전체
	["TabBar", "tab_selected"],
	["PopupMenu", "panel"],            # LineEdit 우클릭 메뉴가 이걸 쓴다
	["TooltipPanel", "panel"],         # 탐색기 아이콘 보기의 전체 이름 풍선
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
