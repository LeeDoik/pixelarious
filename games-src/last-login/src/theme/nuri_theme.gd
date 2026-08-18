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

const SCROLLBAR_THICKNESS := 14.0

static func build() -> Theme:
	var t := Theme.new()
	var font := load("res://assets/fonts/Galmuri11.ttf")
	t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("panel", "Panel", raised(FACE))
	# PanelContainer는 별도 타입이라 따로 주지 않으면 Godot 기본 다크 패널이 새어 나온다
	t.set_stylebox("panel", "PanelContainer", raised(FACE))
	t.set_stylebox("normal", "Button", _button_face(FACE))
	var btn_down := sunken(FACE.darkened(0.10))
	btn_down.set_content_margin_all(6)
	btn_down.content_margin_top = 7
	btn_down.content_margin_bottom = 5  # 눌림 시 내용이 살짝 내려앉는 촉감
	t.set_stylebox("pressed", "Button", btn_down)
	t.set_stylebox("hover", "Button", _button_face(FACE.lightened(0.06)))
	t.set_stylebox("disabled", "Button", _button_face(FACE))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_color", "Label", TEXT)
	var line := sunken(Color.WHITE)
	line.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	t.set_color("selection_color", "LineEdit", SELECT)
	_build_lists(t)
	_build_scrollbars(t)
	_build_variations(t)
	return t

static func _build_lists(t: Theme) -> void:
	# 파일 목록 두 형태 — ItemList(아이콘 보기) / Tree(자세히 보기)
	for type in ["ItemList", "Tree"]:
		t.set_stylebox("panel", type, sunken(FIELD))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_stylebox("selected", type, _fill(SELECT.lerp(FACE, 0.35)))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_selected_color", type, SELECT_TEXT)
		t.set_color("guide_color", type, GUIDE)
	t.set_stylebox("selected_focus", "ItemList", _fill(SELECT))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "ItemList", _fill(SELECT.lerp(FIELD, 0.82)))
	t.set_constant("h_separation", "ItemList", 8)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_constant("icon_margin", "ItemList", 6)
	t.set_stylebox("selected_focused", "Tree", _fill(SELECT))
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("title_button_normal", "Tree", _column_head(FACE))
	t.set_stylebox("title_button_hover", "Tree", _column_head(FACE.lightened(0.06)))
	t.set_stylebox("title_button_pressed", "Tree", _column_head(FACE.darkened(0.08)))
	t.set_color("title_button_color", "Tree", TEXT)
	t.set_constant("v_separation", "Tree", 4)
	t.set_constant("item_margin", "Tree", 8)
	t.set_constant("draw_guides", "Tree", 1)
	t.set_constant("inner_item_margin_right", "Tree", 6)   # 크기 칸이 종류 칸에 붙지 않게
	t.set_constant("inner_item_margin_left", "Tree", 4)

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

static func _build_variations(t: Theme) -> void:
	# 앱이 골라 쓰는 이름 있는 판 — 도구모음/상태표시줄/입력칸 테두리
	t.set_type_variation("NuriToolbar", "Panel")
	t.set_stylebox("panel", "NuriToolbar", _toolbar_face())
	t.set_type_variation("NuriStatusBar", "Panel")
	t.set_stylebox("panel", "NuriStatusBar", _statusbar_face())
	t.set_type_variation("NuriField", "Panel")
	t.set_stylebox("panel", "NuriField", sunken(FIELD))
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
	# 가장자리는 타일로 늘려 보간 번짐을 막는다.
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
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
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
