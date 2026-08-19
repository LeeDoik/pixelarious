class_name Hud
extends CanvasLayer
## 최소주의 HUD — 갱도에서는 생존 정보만 (스펙 §12).

signal lamp_pressed
signal pause_pressed

var oil_bar := ColorRect.new()
var oil_back := ColorRect.new()
var bag_label := Label.new()
var depth_label := Label.new()
var bottles_label := Label.new()
var strata_banner := Label.new()
var lamp_btn := Button.new()
var pause_btn := Button.new()
var _font: FontFile
var _depth_lie := -1
var _depth_lie_gen := 0
var _oil_lie := false
var _oil_lie_gen := 0
var _bag_lie := false

func _ready() -> void:
	_font = load("res://assets/fonts/Galmuri9.ttf")
	oil_back.color = Color(0.1, 0.1, 0.15)
	oil_back.position = Vector2(85, 6)
	oil_back.size = Vector2(100, 10)
	add_child(oil_back)
	oil_bar.color = Color("#FFEC27")
	oil_bar.position = Vector2(86, 7)
	oil_bar.size = Vector2(98, 8)
	add_child(oil_bar)
	for l in [bag_label, depth_label, bottles_label, strata_banner]:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 8)
		add_child(l)
	bag_label.position = Vector2(210, 4)
	depth_label.position = Vector2(6, 4)
	# 기름병은 가방 칸을 먹고 기름이 마르면 자동으로 쓰인다 — 몇 개 남았는지 보이지 않으면
	# 보험이 언제 사라졌는지 알 수 없다. 게이지 오른쪽에 붙여둔다.
	bottles_label.position = Vector2(188, 5)
	strata_banner.position = Vector2(0, 100)
	strata_banner.size = Vector2(270, 20)
	strata_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strata_banner.modulate.a = 0.0
	lamp_btn.text = "LAMP"
	lamp_btn.position = Vector2(6, 410)
	lamp_btn.size = Vector2(64, 64)
	lamp_btn.pressed.connect(func() -> void: lamp_pressed.emit())
	add_child(lamp_btn)
	pause_btn.text = "II"
	# 26x26은 모바일 터치 타깃으로 작다 (램프는 64x64) — 44로 키운다
	pause_btn.position = Vector2(218, 20)
	pause_btn.size = Vector2(44, 44)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

func lie_depth(value: int, sec: float) -> void:
	_depth_lie = value
	_depth_lie_gen += 1
	var gen := _depth_lie_gen
	get_tree().create_timer(sec).timeout.connect(func() -> void:
		if gen == _depth_lie_gen:
			_depth_lie = -1)

func lie_oil_zero(sec: float) -> void:
	_oil_lie = true
	_oil_lie_gen += 1
	var gen := _oil_lie_gen
	get_tree().create_timer(sec).timeout.connect(func() -> void:
		if gen == _oil_lie_gen:
			_oil_lie = false)

func lie_bag_plus(sec: float) -> void:
	_bag_lie = true
	get_tree().create_timer(sec).timeout.connect(func() -> void: _bag_lie = false)

func flash_oil_refill() -> void:
	## 기름병이 자동으로 쓰인 순간 — 소리만으로는 무엇이 일어났는지 알 수 없다
	oil_bar.modulate = Color(2.2, 2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(oil_bar, "modulate", Color.WHITE, 0.7)

func update_state(oil_ratio: float, lamp_on: bool, bag: int, slots: int, depth: int, bottles := 0) -> void:
	if _oil_lie:
		oil_ratio = 0.0
	oil_bar.size.x = 98.0 * clampf(oil_ratio, 0.0, 1.0)
	oil_bar.color = Color("#FFEC27").darkened(clampf(1.0 - oil_ratio, 0.0, 0.6)) if lamp_on else Color(0.4, 0.4, 0.4)
	bag_label.text = "%d/%d" % [bag + (1 if _bag_lie else 0), slots]
	bottles_label.text = ("x%d" % bottles) if bottles > 0 else ""
	depth_label.text = "%dm" % (_depth_lie if _depth_lie >= 0 else depth)

func show_strata(strata: int) -> void:
	strata_banner.text = "─ %s ─" % TextDb.t("ui", "strata_%d" % strata)
	var tw := create_tween()
	strata_banner.modulate.a = 0.0
	tw.tween_property(strata_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(strata_banner, "modulate:a", 0.0, 0.6)

func flash_bag_full() -> void:
	bag_label.modulate = Color(1.0, 0.35, 0.3)
	var tw := create_tween()
	tw.tween_property(bag_label, "modulate", Color.WHITE, 0.6)
