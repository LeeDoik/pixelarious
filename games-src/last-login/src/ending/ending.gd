class_name EndingScene
extends CanvasLayer
## 엔딩: 페이드 아웃 → 에필로그 타이핑. 줄은 content/ending.json에서 오고,
## 각 줄의 require(ChatPlayer.open 문법)가 모은 증거·선택에 따라 줄을 갈아 끼운다 —
## 에필로그의 뼈대는 하나(성진 생사 미확정), 결과의 폭만 갈린다.
## 기록물 9개 전부 열람 + 컴퓨터를 손에 둔(인쇄) 길에서만 숨은 신이 붙는다.

## ending.json이 없을 때의 뼈대 — 테스트·개발용
const FALLBACK := {
	"epilogue": [
		{"text": "당신은 마지막 대화 내용을 저장하고, 컴퓨터를 껐다."},
		{"text": "다음 날, 슬기에게서 문자가 왔다."},
		{"text": "\"거기 가봤어요. 오빠 물건이 있었어요. 고마워요.\""},
		{"text": ""}, {"text": "LAST LOGIN"},
	],
	"hidden": [
		{"text": "…전원을 끄기 직전, 메신저가 울렸다."},
		{"text": "[알 수 없음]: 그 컴퓨터, 어디서 나셨어요?"},
		{"text": "[알 수 없음]: 아, 아까 말씀하셨죠.", "require": "pickup_told"},
		{"text": "[알 수 없음]: 휴지통은 비우고 쓰셔야죠.", "require": "intruder_found"},
	],
}

var line_delay := 1.4
var shutdown_hold := 1.8

static func _data() -> Dictionary:
	var d := ContentDB.ending()
	return d if not d.is_empty() else FALLBACK

## require가 찬 줄만 — 순서는 json 그대로
static func _pick(section: String) -> Array:
	var out: Array = []
	for line in _data().get(section, []):
		if ChatPlayer.open(line.get("require", ""), GameState):
			out.append(String(line["text"]))
	return out

static func epilogue_lines() -> Array:
	return _pick("epilogue")

## 시작할 때 슬기에게 주운 곳을 말했다면 그 말은 이 컴퓨터에 남아 있다.
## 남은 것은 읽힌다 — 마지막 질문이 되돌아오는 이유다.
## 입을 닫았던 플레이어에게는 돌아오지 않는다 — 그 경계가 옳았던 것이 된다.
## 점검표를 찾은 플레이어에게는 한 줄이 더 온다 — 그들이 지운 것을 이쪽이 주웠다는 사실을, 그들이 안다는 것만.
static func hidden_lines() -> Array:
	return _pick("hidden")

## 조건 없는 숨은 줄의 수 — 되돌아오는 줄이 몇 개 붙었는지 세는 기준
static func hidden_base_count() -> int:
	var n := 0
	for line in _data().get("hidden", []):
		if String(line.get("require", "")) == "" and not (line.get("require", "") is Array):
			n += 1
	return n

## 기록물을 다 읽었고, 컴퓨터가 아직 여기 있을 때만 — 원본을 슬기에게 보냈다면 그 질문은 여기로 오지 않는다
static func should_show_hidden() -> bool:
	return ContentDB.records().size() > 0 \
		and GameState.records_count() == ContentDB.records().size() \
		and not GameState.has_flag("ending_original")

func play(hidden: bool) -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	add_child(bg)
	var shutdown := _shutdown_screen()
	add_child(shutdown)
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
	tw.tween_interval(shutdown_hold)          # "종료하는 중" 한 장을 보여주고
	tw.tween_property(bg, "modulate:a", 1.0, 2.0)   # 그 위로 검은 화면이 덮는다
	tw.tween_callback(func():
		if is_instance_valid(shutdown):
			shutdown.queue_free())
	tw.tween_callback(func(): _type_lines(label, epilogue_lines(), hidden))

func _shutdown_screen() -> Control:
	## 에필로그가 "컴퓨터를 껐다"로 시작하니, 끄는 장면이 실제로 있어야 말이 맞는다.
	## CanvasLayer는 데스크톱 테마를 상속받지 못한다 — 폰트를 직접 지정한다.
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("2a3b52")
	panel.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = "누리OS 2002

시스템을 종료하는 중입니다..."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.add_theme_color_override("font_color", Color("dfe6ef"))
	l.add_theme_font_override("font", load("res://assets/fonts/Galmuri11.ttf"))
	l.add_theme_font_size_override("font_size", 22)
	panel.add_child(l)
	return panel

func _type_lines(label: RichTextLabel, lines: Array, then_hidden: bool) -> void:
	for line in lines:
		label.append_text(String(line) + "\n")
		await get_tree().create_timer(line_delay).timeout
	if then_hidden and should_show_hidden():
		await get_tree().create_timer(2.0).timeout
		AudioDirector.play_sfx("msg")
		_type_lines(label, hidden_lines(), false)
