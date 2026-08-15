class_name Ending
extends Node2D
## 코즈믹 리빌 — vista_alive 줌아웃(심장 펄스 동기화) → 자막 → 크레딧 → 탭 → 거점.

signal finished

const VISTA_SCALE := 270.0 / 136.0
const ZOOM_SEC := 8.0
const ZOOM_END_MULT := 0.25
const CAPTION_SEC := 5.0
const CREDITS_SCROLL_SEC := 6.0

var earned := -1
var depth := 0

var vista: Sprite2D
var caption: Label
var credits_label: Label
var tap_hint: Label

var _font: FontFile
var _reduced: bool
var _pulse_t := 0.0
var _stage := 0  # 0=줌아웃, 1=자막, 2=크레딧(탭 대기)

func _ready() -> void:
	_font = load("res://assets/fonts/Galmuri9.ttf")
	_reduced = GameState.profile.settings.reduced_flash

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.position = Vector2.ZERO
	bg.size = Vector2(270, 480)
	add_child(bg)

	vista = Sprite2D.new()
	vista.texture = load("res://assets/img/vista_alive.png")
	vista.centered = true
	vista.position = Vector2(135, 190)
	vista.scale = Vector2(VISTA_SCALE, VISTA_SCALE)
	add_child(vista)

	caption = Label.new()
	caption.add_theme_font_override("font", _font)
	caption.add_theme_font_size_override("font_size", 10)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.position = Vector2(16, 380)
	caption.size = Vector2(238, 80)
	caption.modulate.a = 0.0
	add_child(caption)

	credits_label = Label.new()
	credits_label.add_theme_font_override("font", _font)
	credits_label.add_theme_font_size_override("font_size", 9)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_label.position = Vector2(16, 480)
	credits_label.size = Vector2(238, 400)
	credits_label.visible = false
	add_child(credits_label)

	tap_hint = Label.new()
	tap_hint.add_theme_font_override("font", _font)
	tap_hint.add_theme_font_size_override("font_size", 8)
	tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_hint.position = Vector2(0, 440)
	tap_hint.size = Vector2(270, 20)
	tap_hint.visible = false
	add_child(tap_hint)

	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.position = Vector2.ZERO
	catcher.size = Vector2(270, 480)
	catcher.pressed.connect(_on_tap)
	add_child(catcher)

	Sfx.play("awaken")  # 리빌의 시작 — 각성 사운드를 다시 울려 경외감을 되짚는다
	_run_sequence()

func _process(delta: float) -> void:
	if not is_instance_valid(vista):
		return
	_pulse_t += delta
	# 봉우리 불빛 — 심장 펄스와 동기화된 은은한 모듈레이트 (reduced_flash면 진폭 절반)
	var phase := sin(_pulse_t * TAU / Tuning.HEART_PULSE_SEC)
	var amp := 0.075 if _reduced else 0.15
	var b := 1.0 + amp * maxf(0.0, phase)
	vista.modulate = Color(b, b, b)

func _run_sequence() -> void:
	var tw := create_tween()
	tw.tween_property(vista, "scale", Vector2(VISTA_SCALE, VISTA_SCALE) * ZOOM_END_MULT, ZOOM_SEC)
	await tw.finished
	if not is_instance_valid(self):
		return
	_stage = 1
	caption.text = TextDb.t("ending", "caption")
	var ctw := create_tween()
	ctw.tween_property(caption, "modulate:a", 1.0, 0.6)
	ctw.tween_interval(maxf(0.1, CAPTION_SEC - 1.2))
	ctw.tween_property(caption, "modulate:a", 0.0, 0.6)
	await ctw.finished
	if not is_instance_valid(self):
		return
	_show_credits()

func _show_credits() -> void:
	_stage = 2
	var found: int = GameState.profile.journals_found.size()
	var total: int = Lore.series().size()
	var lines := [
		TextDb.t("ending", "credits_thanks"), "",
		"IT SLEEPS BELOW", "",
		"MINER No. %d" % GameState.profile.miner_no,
		"DEPTH REACHED %dm" % depth,
		"JOURNALS %d / %d" % [found, total],
	]
	credits_label.text = "\n".join(lines)
	credits_label.visible = true
	credits_label.position = Vector2(16, 480)
	var tw := create_tween()
	tw.tween_property(credits_label, "position:y", -280.0, CREDITS_SCROLL_SEC)
	tap_hint.text = TextDb.t("ui", "retry")
	tap_hint.visible = true

func _on_tap() -> void:
	if _stage != 2:
		return
	GameState.profile.ending_seen = true
	GameState.save()
	finished.emit()
