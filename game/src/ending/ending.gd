class_name EndingScene
extends CanvasLayer
## 엔딩: 페이드 아웃 → 에필로그 타이핑. 기록물 9개 전부 열람 시 숨겨진 신 추가.

const EPILOGUE := [
	"당신은 마지막 대화 내용을 저장하고, 컴퓨터를 껐다.",
	"다음 날, 슬기에게서 문자가 왔다.",
	"\"거기 가봤어요. 오빠 물건이 있었어요. 고마워요.\"",
	"", "LAST LOGIN",
]
const HIDDEN := [
	"…전원을 끄기 직전, 메신저가 울렸다.",
	"[알 수 없음]: 그 컴퓨터, 어디서 나셨어요?",
]

var line_delay := 1.4

static func should_show_hidden() -> bool:
	return ContentDB.records().size() > 0 \
		and GameState.records_count() == ContentDB.records().size()

func play(hidden: bool) -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	add_child(bg)
	var label := RichTextLabel.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 120
	label.offset_top = 200
	label.offset_right = -120
	label.add_theme_color_override("default_color", Color("cfe8dc"))
	# CanvasLayer는 데스크톱 테마를 상속받지 못한다 — 한글 폰트 직접 지정 (웹엔 시스템 폴백 없음)
	label.add_theme_font_override("normal_font", load("res://assets/fonts/Galmuri11.ttf"))
	label.add_theme_font_size_override("normal_font_size", 20)
	add_child(label)
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 2.0)
	tw.tween_callback(func(): _type_lines(label, EPILOGUE, hidden))

func _type_lines(label: RichTextLabel, lines: Array, then_hidden: bool) -> void:
	for line in lines:
		label.append_text(String(line) + "\n")
		await get_tree().create_timer(line_delay).timeout
	if then_hidden and should_show_hidden():
		await get_tree().create_timer(2.0).timeout
		AudioDirector.play_sfx("msg")
		_type_lines(label, HIDDEN, false)
