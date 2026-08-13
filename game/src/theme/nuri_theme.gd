class_name NuriTheme
## 누리OS 2002 룩 — XP 시대 디자인 언어, 독자 색·이름 (실존 브랜드 모사 금지)

const TITLE_A := Color("1a3a8c")
const TITLE_B := Color("4a7ec2")
const TASKBAR_COLOR := Color("2a6a5a")
const DESKTOP_COLOR := Color("3a7a9c")
const FACE := Color("d8d4c8")      # 창 본체 베이지
const FACE_DARK := Color("8a867c")
const TEXT := Color("101418")

static func build() -> Theme:
	var t := Theme.new()
	var font := load("res://assets/fonts/Galmuri11.ttf")
	t.default_font = font
	t.default_font_size = 16
	var panel := StyleBoxFlat.new()
	panel.bg_color = FACE
	panel.border_color = FACE_DARK
	panel.set_border_width_all(2)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = FACE
	btn.border_color = FACE_DARK
	btn.set_border_width_all(2)
	btn.set_content_margin_all(6)
	t.set_stylebox("normal", "Button", btn)
	var btn_down := btn.duplicate()
	btn_down.bg_color = FACE.darkened(0.12)
	t.set_stylebox("pressed", "Button", btn_down)
	t.set_stylebox("hover", "Button", btn.duplicate())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_color", "Label", TEXT)
	var line := StyleBoxFlat.new()
	line.bg_color = Color.WHITE
	line.border_color = FACE_DARK
	line.set_border_width_all(2)
	line.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_color("font_color", "LineEdit", TEXT)
	return t

static func titlebar_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TITLE_A if active else TITLE_A.lerp(Color.GRAY, 0.5)
	return s
