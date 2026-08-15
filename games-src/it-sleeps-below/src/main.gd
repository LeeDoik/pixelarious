extends Node2D
## TITLE → OPENING → SURFACE ↔ MINE → DEATH → SURFACE. 씬 전환은 자식 교체.

enum S { TITLE, OPENING, SURFACE, MINE, DEATH, ENDING }

var state: int = S.TITLE
var current: Node

var _font: FontFile
var _font_big: FontFile

# ── 일시정지 오버레이 (Main 전체를 ALWAYS로 돌려 get_tree().paused 변화를 계속 감시) ──
var pause_layer: CanvasLayer
var pause_label := Label.new()
var pause_hint := Label.new()
var _was_paused := false

# ── 타이틀 ──
var _title_tap_label: Label
var haptics_btn: Button
var flash_btn: Button

# ── 오프닝 ──
var _opening_caption: Label
var _opening_stage := 0

func _ready() -> void:
	_font = load("res://assets/fonts/Galmuri9.ttf")
	_font_big = load("res://assets/fonts/Galmuri11.ttf")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_overlay()
	TextDb.text_loaded.connect(_on_text_loaded)
	_show_title()

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_update_pause_overlay(paused)

func _on_text_loaded() -> void:
	# 웹에서는 text.json이 비동기 로드된다 — 타이틀이 떠 있는 동안 로드가 끝나면 라벨을 새로고침
	if state == S.TITLE:
		_refresh_title_labels()

func _swap(node: Node) -> void:
	if current:
		current.queue_free()
	current = node
	node.process_mode = Node.PROCESS_MODE_PAUSABLE  # Main 자체는 ALWAYS이므로 게임 화면은 명시적으로 되돌려준다
	get_tree().paused = false
	add_child(node)

# ── TITLE ──

func _show_title() -> void:
	state = S.TITLE
	var scene := Node2D.new()

	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.position = Vector2.ZERO
	catcher.size = Vector2(270, 480)
	catcher.pressed.connect(_on_title_tap)
	scene.add_child(catcher)

	var logo := Sprite2D.new()
	logo.texture = load("res://assets/img/logo.png")
	logo.centered = false
	logo.scale = Vector2(2, 2)
	logo.position = Vector2(39, 64)
	scene.add_child(logo)

	var title_label := Label.new()
	title_label.add_theme_font_override("font", _font_big)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 104)
	title_label.size = Vector2(270, 20)
	title_label.text = "IT SLEEPS BELOW"
	scene.add_child(title_label)

	_title_tap_label = Label.new()
	_title_tap_label.add_theme_font_override("font", _font)
	_title_tap_label.add_theme_font_size_override("font_size", 10)
	_title_tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_tap_label.position = Vector2(0, 200)
	_title_tap_label.size = Vector2(270, 20)
	scene.add_child(_title_tap_label)

	var lang_btn := Button.new()
	lang_btn.add_theme_font_override("font", _font)
	lang_btn.add_theme_font_size_override("font_size", 9)
	lang_btn.text = "KO / EN"
	lang_btn.position = Vector2(95, 260)
	lang_btn.size = Vector2(80, 30)
	lang_btn.pressed.connect(_toggle_lang)
	scene.add_child(lang_btn)

	haptics_btn = Button.new()
	haptics_btn.add_theme_font_override("font", _font)
	haptics_btn.add_theme_font_size_override("font_size", 9)
	haptics_btn.position = Vector2(55, 320)
	haptics_btn.size = Vector2(160, 30)
	haptics_btn.pressed.connect(_toggle_haptics)
	scene.add_child(haptics_btn)

	flash_btn = Button.new()
	flash_btn.add_theme_font_override("font", _font)
	flash_btn.add_theme_font_size_override("font_size", 9)
	flash_btn.position = Vector2(55, 360)
	flash_btn.size = Vector2(160, 30)
	flash_btn.pressed.connect(_toggle_flash)
	scene.add_child(flash_btn)

	_refresh_title_labels()
	_refresh_toggles()
	_swap(scene)

func _on_title_tap() -> void:
	if state != S.TITLE:
		return
	if GameState.profile.opening_seen:
		_show_surface()
	else:
		_show_opening()

func _refresh_title_labels() -> void:
	if is_instance_valid(_title_tap_label):
		_title_tap_label.text = TextDb.t("ui", "tap_to_descend")

func _refresh_toggles() -> void:
	haptics_btn.text = "HAPTICS ON" if GameState.profile.settings.haptics else "HAPTICS OFF"
	flash_btn.text = "FLASH REDUCED" if GameState.profile.settings.reduced_flash else "FLASH ON"

func _toggle_lang() -> void:
	var cur: String = GameState.profile.settings.lang
	GameState.profile.settings.lang = "en" if cur == "ko" else "ko"
	GameState.save()
	_refresh_title_labels()

func _toggle_haptics() -> void:
	GameState.profile.settings.haptics = not GameState.profile.settings.haptics
	GameState.save()
	_refresh_toggles()

func _toggle_flash() -> void:
	GameState.profile.settings.reduced_flash = not GameState.profile.settings.reduced_flash
	GameState.save()
	_refresh_toggles()

# ── OPENING ──

func _show_opening() -> void:
	state = S.OPENING
	var scene := Node2D.new()

	var vista := Sprite2D.new()
	vista.texture = load("res://assets/img/vista_calm.png")
	vista.centered = false
	var s := 270.0 / 136.0
	vista.scale = Vector2(s, s)
	scene.add_child(vista)

	_opening_caption = Label.new()
	_opening_caption.add_theme_font_override("font", _font)
	_opening_caption.add_theme_font_size_override("font_size", 10)
	_opening_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opening_caption.position = Vector2(16, 320)
	_opening_caption.size = Vector2(238, 120)
	_opening_caption.text = TextDb.t("opening", "arrive")
	scene.add_child(_opening_caption)

	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.position = Vector2.ZERO
	catcher.size = Vector2(270, 480)
	catcher.pressed.connect(_opening_advance)
	scene.add_child(catcher)

	_opening_stage = 0
	_swap(scene)
	_opening_arm_timer(3.5)

func _opening_arm_timer(sec: float) -> void:
	var stage_at_call := _opening_stage
	get_tree().create_timer(sec).timeout.connect(func() -> void:
		if state == S.OPENING and _opening_stage == stage_at_call:
			_opening_advance())

func _opening_advance() -> void:
	if state != S.OPENING or not is_instance_valid(_opening_caption):
		return
	_opening_stage += 1
	if _opening_stage == 1:
		_opening_caption.text = TextDb.t("merchant", "opening")
		_opening_arm_timer(1.5)
	else:
		GameState.profile.opening_seen = true
		GameState.save()
		_show_surface()

# ── SURFACE / MINE ──

func _show_surface(earned: int = -1) -> void:
	state = S.SURFACE
	var s := Surface.new()
	s.pending_earned = earned
	s.descend_pressed.connect(_show_mine)
	_swap(s)

func _show_mine() -> void:
	state = S.MINE
	var m := Mine.new()
	m.run_ended.connect(_on_run_ended)
	_swap(m)

func _on_run_ended(reason: String, depth: int) -> void:
	if reason == "surfaced":
		var earned := GameState.end_run_settle()
		_show_surface(earned)  # Surface가 정산 결과 + merchant.settle_N 대사 표시
	elif reason == "finale_escaped":
		var earned := GameState.end_run_settle()  # 탈출도 정산은 동일 — 심장·유혹 광석 값을 잃지 않는다
		_show_ending(earned, depth)
	else:
		_show_death(reason)

# ── ENDING ──

func _show_ending(earned: int, depth: int) -> void:
	state = S.ENDING
	var e := Ending.new()
	e.earned = earned
	e.depth = depth
	e.finished.connect(func() -> void: _show_surface(earned))
	_swap(e)

# ── DEATH ──

func _show_death(reason: String) -> void:
	state = S.DEATH
	var first_death: bool = GameState.profile.miner_no == 2  # miner_no는 죽을 때 이미 증가된 뒤다
	var scene := Node2D.new()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.position = Vector2.ZERO
	bg.size = Vector2(270, 480)
	scene.add_child(bg)

	var msg := Label.new()
	msg.add_theme_font_override("font", _font_big)
	msg.add_theme_font_size_override("font_size", 12)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.position = Vector2(20, 180)
	msg.size = Vector2(230, 60)
	msg.text = _death_text(reason)
	scene.add_child(msg)

	if first_death:
		var next_line := Label.new()
		next_line.add_theme_font_override("font", _font)
		next_line.add_theme_font_size_override("font_size", 9)
		next_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next_line.position = Vector2(20, 244)
		next_line.size = Vector2(230, 40)
		next_line.text = TextDb.t("merchant", "next_miner")
		scene.add_child(next_line)

	var hint := Label.new()
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 420)
	hint.size = Vector2(270, 20)
	hint.text = TextDb.t("ui", "retry")
	scene.add_child(hint)

	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.position = Vector2.ZERO
	catcher.size = Vector2(270, 480)
	catcher.pressed.connect(func() -> void: if state == S.DEATH: _show_surface())
	scene.add_child(catcher)

	_swap(scene)

func _death_text(reason: String) -> String:
	var key := reason if reason in ["death_fall", "death_lurker"] else "death_generic"
	return TextDb.t("ui", key)

# ── PAUSE 오버레이 ──

func _build_pause_overlay() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 10
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	add_child(pause_layer)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.7)
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(270, 480)
	pause_layer.add_child(scrim)

	pause_label.add_theme_font_override("font", _font_big)
	pause_label.add_theme_font_size_override("font_size", 14)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.position = Vector2(0, 210)
	pause_label.size = Vector2(270, 24)
	pause_layer.add_child(pause_label)

	pause_hint.add_theme_font_override("font", _font)
	pause_hint.add_theme_font_size_override("font_size", 9)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.position = Vector2(0, 244)
	pause_hint.size = Vector2(270, 20)
	pause_layer.add_child(pause_hint)

	var catcher := Button.new()
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.position = Vector2.ZERO
	catcher.size = Vector2(270, 480)
	catcher.pressed.connect(func() -> void: get_tree().paused = false)
	pause_layer.add_child(catcher)

func _update_pause_overlay(paused: bool) -> void:
	pause_layer.visible = paused
	if not paused:
		return
	var flags: Array = GameState.profile.anomaly_flags
	if flags.has("pause_message") and not flags.has("pause_message_done"):
		pause_label.text = TextDb.t("ui", "pause_dont_go")
		flags.append("pause_message_done")
		GameState.save()
	else:
		pause_label.text = TextDb.t("ui", "paused")
	pause_hint.text = TextDb.t("ui", "retry")
