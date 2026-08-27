class_name NuriTheme
## 누리OS 2002 룩 — XP 시대 디자인 언어, 독자 색·이름 (실존 브랜드 모사 금지)

const TITLE_A := Color("1a3a8c")
const TITLE_B := Color("4a7ec2")
const TASKBAR_COLOR := Color("2a6a5a")
const DESKTOP_COLOR := Color("3a7a9c")
const FACE := Color("d8d4c8")      # 창 본체 베이지
const FACE_DARK := Color("8a867c")
const TEXT := Color("101418")

# 2000년대 초 위젯의 2픽셀 베벨 — 바깥 1px는 강한 대비, 안쪽 1px는 약한 대비
const BEVEL_LIT := Color("fbf9f2")
const BEVEL_LIT_SOFT := Color("ece8dc")
const BEVEL_DIM := Color("6e6a60")
const BEVEL_DIM_HARD := Color("38352e")

const FIELD := Color("fdfdf8")     # 목록·입력칸 종이 흰색
const SELECT := Color("2f5fae")    # 선택 하이라이트 (타이틀바 계열)
const SELECT_TEXT := Color("ffffff")
const GUIDE := Color("cfcabb")     # 목록 구분선
const TEXT_DIM := Color("5a574e")
const TOOLTIP_FACE := Color("fdfbd0")  # 2002년 풍선도움말 특유의 연노랑

const PROGRESS := Color("2f5fae")   # 진행률 칸 (선택 하이라이트와 같은 계열)

const SCROLLBAR_THICKNESS := 14.0

const ICON := {
	"check_on": "res://assets/img/icons/check_on.png",
	"check_off": "res://assets/img/icons/check_off.png",
	"slider_grabber": "res://assets/img/icons/slider_grabber.png",
}

static var _shared: Theme

static func shared() -> Theme:
	## 창·메뉴·토스트가 각자 build()를 부르면 나인패치 텍스처를 그만큼 다시 굽고,
	## 나중에 테마를 고칠 때 일부만 바뀌는 사고가 난다. 한 벌을 돌려 쓴다.
	if _shared == null:
		_shared = build()
	return _shared

static func build() -> Theme:
	var t := Theme.new()
	var font := load("res://assets/fonts/Galmuri11.ttf")
	t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("panel", "Panel", raised(FACE))
	# PanelContainer는 별도 타입이라 따로 주지 않으면 Godot 기본 다크 패널이 새어 나온다
	t.set_stylebox("panel", "PanelContainer", raised(FACE))
	_build_buttons(t)
	_build_inputs(t)
	_build_lists(t)
	_build_text(t)
	_build_tabs(t)
	_build_popups(t)
	_build_scrollbars(t)
	_build_progress(t)
	_build_variations(t)
	return t

static func _build_buttons(t: Theme) -> void:
	t.set_stylebox("normal", "Button", _button_face(FACE))
	var btn_down := sunken(FACE.darkened(0.10))
	btn_down.set_content_margin_all(6)
	btn_down.content_margin_top = 7
	btn_down.content_margin_bottom = 5  # 눌림 시 내용이 살짝 내려앉는 촉감
	t.set_stylebox("pressed", "Button", btn_down)
	t.set_stylebox("hover", "Button", _button_face(FACE.lightened(0.06)))
	t.set_stylebox("disabled", "Button", _button_face(FACE))
	t.set_stylebox("focus", "Button", dotted_focus())
	# 기본 테마의 버튼 글자색은 전부 흰색 계열이다 — 한 상태라도 안 덮으면 그 상태에서만
	# 베이지 판 위에 흰 글자가 되어 글씨가 사라진다 (누르고 있는 동안이 특히 잘 걸린다)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_color", "Label", TEXT)
	# 체크박스는 버튼을 상속하지만 베벨을 입으면 안 된다 — 네모 글리프 + 라벨로 읽혀야 한다
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(state, "CheckBox", _flat_face(Color(0, 0, 0, 0)))
	t.set_stylebox("focus", "CheckBox", dotted_focus())
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "CheckBox", TEXT)
	t.set_color("font_disabled_color", "CheckBox", TEXT_DIM)
	var on := _icon("check_on")
	var off := _icon("check_off")
	if on != null and off != null:
		for item in ["checked", "radio_checked", "checked_disabled", "radio_checked_disabled"]:
			t.set_icon(item, "CheckBox", on)
		for item in ["unchecked", "radio_unchecked", "unchecked_disabled", "radio_unchecked_disabled"]:
			t.set_icon(item, "CheckBox", off)
	t.set_constant("h_separation", "CheckBox", 8)

static func _build_inputs(t: Theme) -> void:
	var line := sunken(Color.WHITE)
	line.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("selection_color", "LineEdit", SELECT)
	t.set_color("font_selected_color", "LineEdit", SELECT_TEXT)   # 파란 선택 위의 글자
	# 슬라이더: 파인 홈 + 튀어나온 사각 손잡이 (기본값은 얇은 선 + 동그란 손잡이라 시대가 어긋난다)
	for type in ["HSlider", "VSlider"]:
		# 홈의 두께 = 텍스처 여백(4) + 콘텐츠 여백. 안 주면 2픽셀 실선처럼 보인다
		var track := sunken(FACE.darkened(0.12))
		track.content_margin_top = 4
		track.content_margin_bottom = 4
		t.set_stylebox("slider", type, track)
		# 채워지는 막대는 현대식이다 — 이 시대 슬라이더는 파인 홈과 손잡이뿐이었다
		t.set_stylebox("grabber_area", type, StyleBoxEmpty.new())
		t.set_stylebox("grabber_area_highlight", type, StyleBoxEmpty.new())
		var grab := _icon("slider_grabber")
		if grab != null:
			for item in ["grabber", "grabber_highlight", "grabber_disabled"]:
				t.set_icon(item, type, grab)

static func _build_lists(t: Theme) -> void:
	# 파일 목록 두 형태 — ItemList(아이콘 보기) / Tree(자세히 보기).
	# 줄의 상태는 "고름 × 창 포커스 × 마우스 얹음"의 조합이라 스타일박스가 다섯 벌 필요하다.
	# 한 벌이라도 비면 그 조합에서만 Godot 기본 테마가 새는데 — 고른 줄에 마우스를 얹은
	# 순간 흰 글자 밑에 흰 판이 깔려 파일 이름이 통째로 사라졌다 — 눈으로 훑어선 안 잡힌다.
	for type in ["ItemList", "Tree"]:
		t.set_stylebox("panel", type, sunken(FIELD))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_stylebox("hovered", type, _fill(SELECT.lerp(FIELD, 0.82)))
		t.set_stylebox("selected", type, _fill(SELECT.lerp(FACE, 0.35)))
		t.set_stylebox("hovered_selected", type, _fill(SELECT.lerp(FACE, 0.20)))
		t.set_stylebox("selected_focus", type, _fill(SELECT))
		t.set_stylebox("hovered_selected_focus", type, _fill(SELECT.lightened(0.12)))
		t.set_stylebox("cursor", type, StyleBoxEmpty.new())
		t.set_stylebox("cursor_unfocused", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hovered_color", type, TEXT)              # 얹기만 한 줄은 옅은 판 + 검은 글자
		t.set_color("font_selected_color", type, SELECT_TEXT)
		t.set_color("font_hovered_selected_color", type, SELECT_TEXT)
		t.set_color("guide_color", type, GUIDE)
	t.set_constant("h_separation", "ItemList", 8)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("icon_margin", "ItemList", 6)
	# Tree는 선택 대상이 아닌 줄에 마우스를 얹었을 때 쓰는 한 벌이 더 있다
	t.set_stylebox("hovered_dimmed", "Tree", _fill(SELECT.lerp(FIELD, 0.90)))
	t.set_color("font_hovered_dimmed_color", "Tree", TEXT)
	t.set_stylebox("title_button_normal", "Tree", _column_head(FACE))
	t.set_stylebox("title_button_hover", "Tree", _column_head(FACE.lightened(0.06)))
	t.set_stylebox("title_button_pressed", "Tree", _column_head(FACE.darkened(0.08)))
	t.set_color("title_button_color", "Tree", TEXT)
	t.set_constant("v_separation", "Tree", 4)
	t.set_constant("item_margin", "Tree", 8)
	t.set_constant("draw_guides", "Tree", 1)
	t.set_constant("inner_item_margin_right", "Tree", 6)   # 크기 칸이 종류 칸에 붙지 않게
	t.set_constant("inner_item_margin_left", "Tree", 4)

static func _build_text(t: Theme) -> void:
	# 앱 본문 표면. 메일·누리넷·휴지통·메모장이 전부 RichTextLabel을 쓰는데
	# 테마가 비어 있으면 Godot 기본(어두운 판 + 흰 글자)이 창 안에 그대로 뜬다.
	var page := sunken(FIELD)
	page.set_content_margin_all(8)
	t.set_stylebox("normal", "RichTextLabel", page)
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_selected_color", "RichTextLabel", SELECT_TEXT)
	t.set_color("selection_color", "RichTextLabel", SELECT)
	t.set_constant("line_separation", "RichTextLabel", 2)
	# 풍선도움말 — 탐색기 아이콘 보기가 잘린 이름의 전체를 여기로 보여준다
	var tip := StyleBoxFlat.new()
	tip.bg_color = TOOLTIP_FACE
	tip.border_color = TEXT
	tip.set_border_width_all(1)
	tip.content_margin_left = 6
	tip.content_margin_right = 6
	tip.content_margin_top = 3
	tip.content_margin_bottom = 3
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)

static func _build_tabs(t: Theme) -> void:
	# PC통신의 "대화 / 지난 대화". TabContainer의 panel이 비면 본문 전체가 기본 회색 상자가 된다.
	t.set_stylebox("panel", "TabContainer", raised(FACE))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	for type in ["TabContainer", "TabBar"]:
		var sel := raised(FACE)
		sel.content_margin_left = 12
		sel.content_margin_right = 12
		sel.content_margin_top = 5
		sel.content_margin_bottom = 4
		var unsel := raised(FACE.darkened(0.09))
		unsel.content_margin_left = 12
		unsel.content_margin_right = 12
		unsel.content_margin_top = 3      # 선택 안 된 탭은 한 픽셀 내려앉는다
		unsel.content_margin_bottom = 6
		var hover := raised(FACE.lightened(0.05))
		hover.content_margin_left = 12
		hover.content_margin_right = 12
		hover.content_margin_top = 4
		hover.content_margin_bottom = 5
		t.set_stylebox("tab_selected", type, sel)
		t.set_stylebox("tab_unselected", type, unsel)
		t.set_stylebox("tab_disabled", type, unsel)
		t.set_stylebox("tab_hovered", type, hover)
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_color("font_selected_color", type, TEXT)
		t.set_color("font_unselected_color", type, TEXT_DIM)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_constant("side_margin", type, 4)

static func _build_popups(t: Theme) -> void:
	# 시작 메뉴가 쓰는 팝업
	var panel := raised(FACE)
	panel.set_content_margin_all(3)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("hover", "PopupMenu", _fill(SELECT))
	t.set_stylebox("separator", "PopupMenu", _fill(FACE_DARK))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", SELECT_TEXT)
	t.set_color("font_separator_color", "PopupMenu", TEXT_DIM)
	t.set_constant("v_separation", "PopupMenu", 4)
	t.set_constant("item_start_padding", "PopupMenu", 8)
	t.set_constant("item_end_padding", "PopupMenu", 8)

static func _build_scrollbars(t: Theme) -> void:
	# 홈통 스타일박스의 여백이 곧 막대 두께다 — 안 주면 몇 픽셀로 쪼그라들어 잡을 수가 없다
	for type in ["VScrollBar", "HScrollBar"]:
		for state in ["scroll", "scroll_focus"]:
			var trough := _fill(FACE.lerp(FIELD, 0.45))
			if type == "VScrollBar":
				trough.content_margin_left = SCROLLBAR_THICKNESS / 2
				trough.content_margin_right = SCROLLBAR_THICKNESS / 2
			else:
				trough.content_margin_top = SCROLLBAR_THICKNESS / 2
				trough.content_margin_bottom = SCROLLBAR_THICKNESS / 2
			t.set_stylebox(state, type, trough)
		t.set_stylebox("grabber", type, raised(FACE))
		t.set_stylebox("grabber_highlight", type, raised(FACE.lightened(0.06)))
		t.set_stylebox("grabber_pressed", type, sunken(FACE.darkened(0.06)))

static func _build_progress(t: Theme) -> void:
	# 이 시대 진행률 표시줄은 이어진 막대가 아니라 네모 칸이 하나씩 차오르는 물건이었다.
	# 휴지통 복원이 이걸 쓴다 — 손상된 파일에서 중간에 멈추는 게 보여야 한다.
	var trough := sunken(FACE.darkened(0.04))
	trough.set_content_margin_all(3)
	t.set_stylebox("background", "ProgressBar", trough)
	t.set_stylebox("fill", "ProgressBar", _progress_blocks())
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 14)

static func _progress_blocks() -> StyleBoxTexture:
	## 6픽셀 칸 + 2픽셀 틈을 가로로 타일링한다. 값이 늘면 칸이 하나씩 더 그려진다.
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 6:
		for y in 4:
			img.set_pixel(x, y, PROGRESS if x < 5 else PROGRESS.darkened(0.28))
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

static func _build_variations(t: Theme) -> void:
	# 앱이 골라 쓰는 이름 있는 판 — 도구모음/상태표시줄/입력칸 테두리
	t.set_type_variation("NuriToolbar", "Panel")
	t.set_stylebox("panel", "NuriToolbar", _toolbar_face())
	t.set_type_variation("NuriStatusBar", "Panel")
	t.set_stylebox("panel", "NuriStatusBar", _statusbar_face())
	t.set_type_variation("NuriField", "Panel")
	var field := sunken(FIELD)
	field.set_content_margin_all(3)
	t.set_stylebox("panel", "NuriField", field)
	t.set_type_variation("NuriFlat", "Button")
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, "NuriFlat", _flat_face(Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "NuriFlat", raised(FACE.lightened(0.10)))
	t.set_stylebox("pressed", "NuriFlat", sunken(FACE.darkened(0.06)))
	t.set_color("font_color", "NuriFlat", TEXT)
	t.set_color("font_disabled_color", "NuriFlat", TEXT_DIM)

static func raised(bg: Color) -> StyleBoxTexture:
	## 튀어나온 위젯 (버튼·창 본체·스크롤바 손잡이)
	return _bevel(bg, BEVEL_LIT, BEVEL_LIT_SOFT, BEVEL_DIM_HARD, BEVEL_DIM)

static func sunken(bg: Color) -> StyleBoxTexture:
	## 파인 위젯 (목록·입력칸·눌린 버튼) — 빛 방향이 뒤집힌다
	return _bevel(bg, BEVEL_DIM, BEVEL_DIM_HARD, BEVEL_LIT_SOFT, BEVEL_LIT)

static func dotted_focus() -> StyleBoxTexture:
	## 이 시대의 포커스 표시는 점선 사각형. 4x4를 타일링해 점선을 만든다.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 4:
		if i % 2 == 0:
			img.set_pixel(i, 0, TEXT)
			img.set_pixel(i, 3, TEXT)
			img.set_pixel(0, i, TEXT)
			img.set_pixel(3, i, TEXT)
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.set_texture_margin_all(1)
	# 여기는 점선이 곧 타일이라 타일을 쓴다. 다만 가운데(투명)까지 타일로 채우면
	# 배율에 따라 되감기가 어긋나며 안쪽에 점이 흩뿌려진다 — 아예 안 그린다.
	s.draw_center = false
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return s

static func _icon(key: String) -> Texture2D:
	var path: String = ICON[key]
	return load(path) if ResourceLoader.exists(path) else null

static func _button_face(bg: Color) -> StyleBoxTexture:
	var s := raised(bg)
	s.set_content_margin_all(6)
	return s

static func _flat_face(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_content_margin_all(4)
	return s

static func _fill(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	return s

static func _toolbar_face() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FACE.lightened(0.04)
	s.border_color = BEVEL_DIM
	s.border_width_bottom = 1
	s.set_content_margin_all(3)
	return s

static func _statusbar_face() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FACE
	s.border_color = BEVEL_LIT
	s.border_width_top = 1
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

static func _column_head(bg: Color) -> StyleBoxTexture:
	var s := raised(bg)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s

static func _bevel(bg: Color, outer_tl: Color, inner_tl: Color, outer_br: Color, inner_br: Color) -> StyleBoxTexture:
	# 6x6 나인패치: 바깥 1px + 안쪽 1px = 2픽셀 베벨, 가운데 2x2가 면.
	# 베벨 네 귀퉁이는 여백(2px)이 지켜주므로 어떤 크기에서도 1:1로 찍힌다.
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in 6:
		img.set_pixel(i, 0, outer_tl)
		img.set_pixel(0, i, outer_tl)
		img.set_pixel(i, 5, outer_br)
		img.set_pixel(5, i, outer_br)
	for i in range(1, 5):
		img.set_pixel(i, 1, inner_tl)
		img.set_pixel(1, i, inner_tl)
		img.set_pixel(i, 4, inner_br)
		img.set_pixel(4, i, inner_br)
	img.set_pixel(5, 0, bg.darkened(0.35))   # 대각 모서리는 중간 톤으로
	img.set_pixel(0, 5, bg.darkened(0.35))
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.set_texture_margin_all(2)
	# 늘리기(STRETCH)여야 한다 — 타일은 안 된다. 나인패치 타일은 셰이더가 칸마다
	# mod()로 UV를 되감는데, 캔버스가 정수배가 아닌 배율로 커지면(웹에서 창 크기에
	# 따라 늘 그렇다) 되감기는 지점이 가끔 가장자리 텍셀에 걸려 면 한가운데에
	# 검은 세로줄·가로줄이 격자로 그어진다. 면은 단색이라 늘려도 결과가 같다.
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

static func titlebar_style(active: bool) -> StyleBox:
	# 2000년대 초 OS의 수평 그라데이션 타이틀바 (비활성 창은 회색조)
	var g := Gradient.new()
	if active:
		g.set_color(0, TITLE_A)
		g.set_color(1, TITLE_B)
	else:
		g.set_color(0, TITLE_A.lerp(Color.GRAY, 0.55))
		g.set_color(1, TITLE_B.lerp(Color.GRAY, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 28
	var s := StyleBoxTexture.new()
	s.texture = tex
	return s
