class_name Hud
extends CanvasLayer
## 최소주의 HUD — 갱도에서는 생존 정보만 (스펙 §12).

signal lamp_pressed
signal pause_pressed

var oil_bar := ColorRect.new()
var oil_back := ColorRect.new()
var hearts_label := Label.new()
var bag_label := Label.new()
var depth_label := Label.new()
var strata_banner := Label.new()
var lamp_btn := Button.new()
var pause_btn := Button.new()
var _font: FontFile

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
	for l in [hearts_label, bag_label, depth_label, strata_banner]:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 8)
		add_child(l)
	hearts_label.position = Vector2(6, 4)
	bag_label.position = Vector2(210, 4)
	depth_label.position = Vector2(232, 230)
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
	pause_btn.position = Vector2(238, 28)
	pause_btn.size = Vector2(26, 26)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

func update_state(oil_ratio: float, lamp_on: bool, hearts: int, bag: int, slots: int, depth: int) -> void:
	oil_bar.size.x = 98.0 * clampf(oil_ratio, 0.0, 1.0)
	oil_bar.color = Color("#FFEC27") if lamp_on else Color(0.4, 0.4, 0.4)
	hearts_label.text = "♥".repeat(hearts)
	bag_label.text = "%d/%d" % [bag, slots]
	depth_label.text = "%dm" % depth

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
