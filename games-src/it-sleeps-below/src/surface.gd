class_name Surface
extends Node2D
## 거점 화면 — vista 원경(오염 틴트), 상인/상점, 수첩, 갱도 입구. 골드는 여기서만 표시(스펙 §14).

signal descend_pressed

const VISTA_SCALE := 270.0 / 136.0  # vista_calm.png(136px)를 270px 폭에 맞춘다
const MERCHANT_BASE_POS := Vector2(190, 250)
const TRACK_ORDER := ["pick", "lamp", "bag", "boots", "helmet"]
const TRACK_LABELS := {"pick": "PICK", "lamp": "LAMP", "bag": "BAG", "boots": "BOOTS", "helmet": "HELMET"}

# main.gd가 add_child 전에 설정 — 정산 직후 복귀면 획득 골드, 아니면 -1
var pending_earned: int = -1

static var _settle_cycle := 0  # merchant.settle_1~3 순환 (세션 한정, 저장하지 않음)

var vista: Sprite2D
var gold_label := Label.new()
var settle_label := Label.new()
var memo_label := Label.new()
var memo_ok_btn := Button.new()
var merchant: Sprite2D
var tent: Sprite2D
var shop_btn := Button.new()

var shop_panel: PanelContainer
var notebook_panel: PanelContainer
var journal_overlay: PanelContainer
var journal_text_label := Label.new()
var rate_label := Label.new()
var oil_label := Label.new()
var oil_btn := Button.new()

var _font: FontFile
var _shop_rows: Dictionary = {}
var _journal_btns: Dictionary = {}
var _merchant_away := false

func _ready() -> void:
	_font = load("res://assets/fonts/Galmuri9.ttf")
	vista = Sprite2D.new()
	vista.texture = load("res://assets/img/vista_calm.png")
	vista.centered = false
	vista.scale = Vector2(VISTA_SCALE, VISTA_SCALE)
	add_child(vista)
	_apply_corruption()
	Sfx.ambience("amb_surface")
	_build_ui()
	_apply_delayed_anomalies()
	_show_settle_result()

func _apply_corruption() -> void:
	var c := GameState.corruption()
	var tints := [Color.WHITE, Color(0.85, 0.8, 0.85), Color(0.75, 0.7, 0.8), Color(0.65, 0.55, 0.65), Color(0.55, 0.35, 0.45)]
	vista.modulate = tints[c]
	# 새소리(표층 앰비언트) 볼륨 — 오염 1단계부터 -6dB 추가 감쇠 (기본 -6dB 위에 누적)
	Sfx.ambience_volume(-12.0 if c >= 1 else -6.0)
	# bgm — 오염될수록 음정이 틀어진다 (bgm_camp.ogg는 아직 없음 — 파일이 들어오면 그대로 동작)
	Sfx.ambience("bgm_camp")
	# Sfx._amb.pitch_scale 직접 제어 대신 Sfx에 ambience_pitch(p) 헬퍼를 추가해 사용
	Sfx.ambience_pitch([1.0, 1.0, 0.98, 0.98, 0.95][c])

func _build_ui() -> void:
	gold_label.add_theme_font_override("font", _font)
	gold_label.add_theme_font_size_override("font_size", 10)
	gold_label.position = Vector2(178, 168)
	gold_label.size = Vector2(84, 16)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(gold_label)
	_refresh_gold()

	tent = Sprite2D.new()
	tent.texture = load("res://assets/img/tent.png")
	tent.centered = false
	tent.scale = Vector2(2, 2)
	tent.position = Vector2(20, 260)
	add_child(tent)

	merchant = Sprite2D.new()
	merchant.texture = load("res://assets/img/merchant.png")
	merchant.centered = false
	merchant.scale = Vector2(2, 2)
	merchant.position = MERCHANT_BASE_POS
	if GameState.corruption() >= 3:
		merchant.position += Vector2(6, -4)  # 오염 3+ — 위치가 미묘하게 이동
	add_child(merchant)

	settle_label.add_theme_font_override("font", _font)
	settle_label.add_theme_font_size_override("font_size", 8)
	settle_label.position = Vector2(10, 168)
	settle_label.size = Vector2(160, 60)
	settle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_label.modulate.a = 0.0
	settle_label.visible = false
	add_child(settle_label)

	memo_label.add_theme_font_override("font", _font)
	memo_label.add_theme_font_size_override("font_size", 8)
	memo_label.position = Vector2(160, 220)
	memo_label.size = Vector2(96, 90)
	memo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memo_label.visible = false
	add_child(memo_label)

	memo_ok_btn.text = "OK"
	memo_ok_btn.add_theme_font_override("font", _font)
	memo_ok_btn.add_theme_font_size_override("font_size", 9)
	memo_ok_btn.position = Vector2(196, 312)
	memo_ok_btn.size = Vector2(40, 24)
	memo_ok_btn.visible = false
	memo_ok_btn.pressed.connect(_ack_merchant_gone)
	add_child(memo_ok_btn)

	shop_btn.add_theme_font_override("font", _font)
	shop_btn.add_theme_font_size_override("font_size", 9)
	shop_btn.text = TextDb.t("ui", "shop")
	shop_btn.position = Vector2(8, 410)
	shop_btn.size = Vector2(80, 56)
	shop_btn.pressed.connect(_open_shop)
	add_child(shop_btn)

	var notebook_btn := Button.new()
	notebook_btn.add_theme_font_override("font", _font)
	notebook_btn.add_theme_font_size_override("font_size", 9)
	notebook_btn.text = TextDb.t("ui", "notebook")
	notebook_btn.position = Vector2(95, 410)
	notebook_btn.size = Vector2(80, 56)
	notebook_btn.pressed.connect(_open_notebook)
	add_child(notebook_btn)

	var descend_btn := Button.new()
	descend_btn.add_theme_font_override("font", _font)
	descend_btn.add_theme_font_size_override("font_size", 9)
	descend_btn.text = "DESCEND"
	descend_btn.position = Vector2(182, 410)
	descend_btn.size = Vector2(80, 56)
	descend_btn.pressed.connect(func() -> void: descend_pressed.emit())
	add_child(descend_btn)

	_build_shop_panel()
	_build_notebook_panel()

# ── 정산 표시 ──

func _show_settle_result() -> void:
	if pending_earned < 0:
		return
	var line := ""
	if not _merchant_away:
		line = "\n" + _next_settle_line()
	settle_label.text = "+%d G%s" % [pending_earned, line]
	settle_label.visible = true
	settle_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(settle_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(3.0)
	tw.tween_property(settle_label, "modulate:a", 0.0, 0.8)

func _next_settle_line() -> String:
	if GameState.corruption() >= 3:
		return TextDb.t("merchant", "settle_4")
	var n := (Surface._settle_cycle % 3) + 1
	Surface._settle_cycle += 1
	return TextDb.t("merchant", "settle_%d" % n)

# ── 지연 소비형 이상현상 (Task 13 규칙: id는 남기고 <id>_done만 추가) ──

func _apply_delayed_anomalies() -> void:
	var flags: Array = GameState.profile.anomaly_flags
	if flags.has("merchant_gone") and not flags.has("merchant_gone_done"):
		_merchant_away = true
		merchant.visible = false
		shop_btn.disabled = true
		memo_label.text = TextDb.t("merchant", "memo_gone")
		memo_label.visible = true
		memo_ok_btn.visible = true
	if flags.has("black_sky") and not flags.has("black_sky_done"):
		_play_black_sky()

func _ack_merchant_gone() -> void:
	GameState.profile.anomaly_flags.append("merchant_gone_done")
	GameState.save()
	memo_ok_btn.visible = false
	# memo_label/상점 비활성은 이번 방문 내내 유지 — 다음 복귀에 상인이 정상으로 보인다

func _play_black_sky() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color.BLACK
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(270.0, 80.0 * VISTA_SCALE)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	await get_tree().create_timer(1.0).timeout
	GameState.profile.anomaly_flags.append("black_sky_done")
	GameState.save()
	if not is_instance_valid(self) or not is_instance_valid(scrim):
		return
	var tw := create_tween()
	tw.tween_property(scrim, "modulate:a", 0.0, 0.4)
	await tw.finished
	if is_instance_valid(scrim):
		scrim.queue_free()

# ── 상점 ──

func _open_shop() -> void:
	_refresh_shop()
	shop_panel.visible = true

func _build_shop_panel() -> void:
	shop_panel = PanelContainer.new()
	shop_panel.position = Vector2(15, 30)
	shop_panel.custom_minimum_size = Vector2(240, 400)
	shop_panel.visible = false
	add_child(shop_panel)
	var vbox := VBoxContainer.new()
	shop_panel.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 12)
	title.text = TextDb.t("ui", "shop")
	vbox.add_child(title)

	for track in TRACK_ORDER:
		var row := HBoxContainer.new()
		vbox.add_child(row)
		var lbl := Label.new()
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lbl)
		var btn := Button.new()
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 9)
		btn.text = "BUY"
		btn.pressed.connect(_buy.bind(track))
		row.add_child(btn)
		_shop_rows[track] = {"label": lbl, "btn": btn}

	var oil_row := HBoxContainer.new()
	vbox.add_child(oil_row)
	oil_label.add_theme_font_override("font", _font)
	oil_label.add_theme_font_size_override("font_size", 9)
	oil_label.custom_minimum_size = Vector2(160, 0)
	oil_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oil_row.add_child(oil_label)
	oil_btn.add_theme_font_override("font", _font)
	oil_btn.add_theme_font_size_override("font_size", 9)
	oil_btn.text = "BUY"
	oil_btn.pressed.connect(_buy_oil)
	oil_row.add_child(oil_btn)

	var close_btn := Button.new()
	close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_font_size_override("font_size", 9)
	close_btn.text = "X"
	close_btn.pressed.connect(func() -> void: shop_panel.visible = false)
	vbox.add_child(close_btn)

	_refresh_shop()

func _refresh_gold() -> void:
	gold_label.text = "%d G" % GameState.profile.gold

func _refresh_shop() -> void:
	for track in TRACK_ORDER:
		var lv: int = GameState.profile.upgrades[track]
		var cost := Economy.upgrade_cost(track, lv + 1)
		var row: Dictionary = _shop_rows[track]
		var lbl: Label = row.label
		var btn: Button = row.btn
		if cost < 0:
			lbl.text = "%s Lv%d (MAX)" % [TRACK_LABELS[track], lv]
			btn.disabled = true
		else:
			lbl.text = "%s Lv%d → %d G" % [TRACK_LABELS[track], lv, cost]
			btn.disabled = GameState.profile.gold < cost
	var bottles: int = GameState.profile.oil_bottles
	if bottles >= Tuning.OIL_BOTTLE_CARRY_MAX:
		oil_label.text = "OIL BOTTLE %d/%d (MAX, uses 1 bag slot)" % [bottles, Tuning.OIL_BOTTLE_CARRY_MAX]
		oil_btn.disabled = true
	else:
		oil_label.text = "OIL BOTTLE %d/%d → %d G (uses 1 bag slot)" % [bottles, Tuning.OIL_BOTTLE_CARRY_MAX, Tuning.OIL_BOTTLE_PRICE]
		oil_btn.disabled = GameState.profile.gold < Tuning.OIL_BOTTLE_PRICE
	_refresh_gold()

func _buy(track: String) -> void:
	var next: int = GameState.profile.upgrades[track] + 1
	var cost := Economy.upgrade_cost(track, next)
	if cost < 0 or GameState.profile.gold < cost:
		return
	GameState.profile.gold -= cost
	GameState.profile.upgrades[track] = next
	GameState.save()
	Sfx.play("settle")
	_refresh_shop()

func _buy_oil() -> void:
	if GameState.profile.oil_bottles >= Tuning.OIL_BOTTLE_CARRY_MAX:
		return
	if GameState.profile.gold < Tuning.OIL_BOTTLE_PRICE:
		return
	GameState.profile.gold -= Tuning.OIL_BOTTLE_PRICE
	GameState.profile.oil_bottles += 1
	GameState.save()
	Sfx.play("settle")
	_refresh_shop()

# ── 수첩 ──

func _open_notebook() -> void:
	_refresh_notebook()
	notebook_panel.visible = true

func _build_notebook_panel() -> void:
	notebook_panel = PanelContainer.new()
	notebook_panel.position = Vector2(15, 30)
	notebook_panel.custom_minimum_size = Vector2(240, 420)
	notebook_panel.visible = false
	add_child(notebook_panel)
	var vbox := VBoxContainer.new()
	notebook_panel.add_child(vbox)

	var title := Label.new()
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 12)
	title.text = TextDb.t("ui", "notebook")
	vbox.add_child(title)

	rate_label.add_theme_font_override("font", _font)
	rate_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(rate_label)

	var i := 0
	for entry in Lore.series():
		i += 1
		var btn := Button.new()
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 9)
		btn.pressed.connect(_open_journal.bind(entry.id))
		vbox.add_child(btn)
		_journal_btns[entry.id] = {"btn": btn, "index": i}

	var close_btn := Button.new()
	close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_font_size_override("font_size", 9)
	close_btn.text = "X"
	close_btn.pressed.connect(func() -> void: notebook_panel.visible = false)
	vbox.add_child(close_btn)

	journal_overlay = PanelContainer.new()
	journal_overlay.position = Vector2(15, 30)
	journal_overlay.custom_minimum_size = Vector2(240, 420)
	journal_overlay.visible = false
	add_child(journal_overlay)
	var ovbox := VBoxContainer.new()
	journal_overlay.add_child(ovbox)
	journal_text_label.add_theme_font_override("font", _font)
	journal_text_label.add_theme_font_size_override("font_size", 9)
	journal_text_label.custom_minimum_size = Vector2(220, 0)
	journal_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ovbox.add_child(journal_text_label)
	var back_btn := Button.new()
	back_btn.add_theme_font_override("font", _font)
	back_btn.add_theme_font_size_override("font_size", 9)
	back_btn.text = "BACK"
	back_btn.pressed.connect(func() -> void: journal_overlay.visible = false)
	ovbox.add_child(back_btn)

	_refresh_notebook()

func _refresh_notebook() -> void:
	var found: Array = GameState.profile.journals_found
	for id in _journal_btns:
		var e: Dictionary = _journal_btns[id]
		var btn: Button = e.btn
		if found.has(id):
			btn.text = "%d. FOUND" % int(e.index)
			btn.disabled = false
		else:
			btn.text = "%d. ???" % int(e.index)
			btn.disabled = true
	var total := Lore.series().size()
	var rate := Lore.collection_rate(found)
	rate_label.text = "%d / %d (%d%%)" % [found.size(), total, int(round(rate * 100.0))]

func _open_journal(id: String) -> void:
	journal_text_label.text = TextDb.t("journals", id)
	notebook_panel.visible = false
	journal_overlay.visible = true
