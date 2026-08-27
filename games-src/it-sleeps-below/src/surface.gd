class_name Surface
extends Node2D
## 거점 화면 — vista 원경(오염 틴트), 상인/상점, 수첩, 갱도 입구. 골드는 여기서만 표시(스펙 §14).

signal descend_pressed

const VISTA_SCALE := 270.0 / 136.0  # vista_calm.png(136px)를 270px 폭에 맞춘다
const MERCHANT_BASE_POS := Vector2(196, 220)
# 화면을 세 띠로 나눈다: 원경(0~159) / 상태바 / 캠프 / 갱도 입구 / 버튼(410~)
const STATUS_TOP := 162.0
const STATUS_H := 44.0
const GROUND_TOP := 268.0
const PIT_POS := Vector2(39, 272)
const PIT_SCALE := 2.0          # mine_mouth 96x64 -> 192x128
# 프레임에 둘러싸인 개구부(원본 x21~74, y14~53)를 그대로 옮긴 것 — 여기가 어둠이다
const PIT_VOID := Rect2(81, 300, 108, 80)
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
var notebook_btn := Button.new()
var shop_title := Label.new()
var notebook_title := Label.new()

var shop_panel: PanelContainer
var notebook_panel: PanelContainer
var journal_overlay: PanelContainer
var journal_text_label := Label.new()
var rate_label := Label.new()
var oil_label := Label.new()
var oil_btn := Button.new()

var miner_label := Label.new()
var depth_label := Label.new()
var journal_label := Label.new()
var bottles_label := Label.new()
var relic_label := Label.new()
var campfire: Sprite2D
var gear_row: Node2D

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
	# 웹에서는 text.json이 비동기라 거점이 먼저 그려질 수 있다 — 도착하면 라벨을 새로 쓴다
	TextDb.text_loaded.connect(_refresh_text)
	_apply_delayed_anomalies()
	_show_settle_result()

func _apply_corruption() -> void:
	var c := GameState.corruption()
	var tints := [Color.WHITE, Color(0.85, 0.8, 0.85), Color(0.75, 0.7, 0.8), Color(0.65, 0.55, 0.65), Color(0.55, 0.35, 0.45)]
	vista.modulate = tints[c]
	# 새소리(표층 앰비언트) 볼륨 — 오염 1단계부터 -6dB 추가 감쇠 (기본 -6dB 위에 누적)
	Sfx.ambience_volume(-12.0 if c >= 1 else -6.0)
	# bgm — 오염될수록 음정이 틀어진다. 음악은 앰비언트와 다른 채널이라
	# 새소리는 멀쩡한 채로 음악만 틀어진다 (한 채널이면 아래 amb_surface가 곧바로 덮어썼다)
	Sfx.music("bgm_camp")
	Sfx.music_pitch([1.0, 1.0, 0.98, 0.98, 0.95][c])

func _build_ui() -> void:
	_build_ground()
	_build_status_bar()
	_build_camp_props()
	_build_mine_mouth()

	settle_label.add_theme_font_override("font", _font)
	settle_label.add_theme_font_size_override("font_size", 8)
	settle_label.position = Vector2(8, 208)
	settle_label.size = Vector2(180, 28)
	settle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_label.modulate.a = 0.0
	settle_label.visible = false
	add_child(settle_label)

	memo_label.add_theme_font_override("font", _font)
	memo_label.add_theme_font_size_override("font_size", 8)
	memo_label.position = Vector2(146, 206)
	memo_label.size = Vector2(116, 56)
	memo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memo_label.visible = false
	add_child(memo_label)

	memo_ok_btn.text = "OK"
	memo_ok_btn.add_theme_font_override("font", _font)
	memo_ok_btn.add_theme_font_size_override("font_size", 9)
	memo_ok_btn.position = Vector2(196, 246)
	memo_ok_btn.size = Vector2(44, 18)
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

func _refresh_text() -> void:
	shop_btn.text = TextDb.t("ui", "shop")
	notebook_btn.text = TextDb.t("ui", "notebook")
	shop_title.text = TextDb.t("ui", "shop")
	notebook_title.text = TextDb.t("ui", "notebook")

# ── 화면 구성 ──

func _make_label(px: int, pos: Vector2, box: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", px)
	l.position = pos
	l.size = box
	l.horizontal_alignment = align
	add_child(l)
	return l

func _sprite(img: String, pos: Vector2, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/img/%s.png" % img)
	sp.centered = false
	sp.position = pos
	sp.scale = Vector2(s, s)
	add_child(sp)
	return sp

func _flicker(node: CanvasItem) -> void:
	# 캠프에서 유일하게 살아 움직이는 빛 — 정지 화면이 되지 않도록
	var tw := create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.75, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE)

func _build_ground() -> void:
	# 원경 아래는 캠프가 선 땅이고, 갱구는 그 땅에 뚫려 있다
	var soil := ColorRect.new()
	soil.color = Color("#241A2B")
	soil.position = Vector2(0, GROUND_TOP)
	soil.size = Vector2(270, 480 - GROUND_TOP)
	soil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(soil)
	# 경계를 납작한 선으로 두면 UI 구분선처럼 보인다 — 흙 층을 한 줄 깔아 지형으로 읽히게 한다.
	# tile_dirt는 23%만 불투명해 흩뿌려진 티가 나므로, 꽉 찬 tile_rock을 흙빛으로 물들여 바닥을 만들고
	# 그 위에 tile_dirt를 얹어 표면 질감만 준다.
	for i in range(18):
		var bed := _sprite("tile_rock", Vector2(i * 16, GROUND_TOP), 1.0)
		bed.modulate = Color(0.62, 0.48, 0.52)
		var top := _sprite("tile_dirt", Vector2(i * 16, GROUND_TOP - 6), 1.0)
		top.modulate = Color(0.78, 0.7, 0.72)

func _build_status_bar() -> void:
	# 내려가기 전에 알아야 할 것만 — 몇 번째 광부인지, 어디까지 갔는지, 무엇을 들고 가는지
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.04, 0.08, 0.82)
	bar.position = Vector2(0, STATUS_TOP)
	bar.size = Vector2(270, STATUS_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var prof: Dictionary = GameState.profile
	miner_label = _make_label(8, Vector2(8, STATUS_TOP + 2), Vector2(88, 12))
	miner_label.text = Camp.miner_tag(prof.miner_no)
	depth_label = _make_label(8, Vector2(92, STATUS_TOP + 2), Vector2(84, 12), HORIZONTAL_ALIGNMENT_CENTER)
	depth_label.text = Camp.best_depth_tag(prof.best_depth)

	gold_label.add_theme_font_override("font", _font)
	gold_label.add_theme_font_size_override("font_size", 10)
	gold_label.position = Vector2(178, STATUS_TOP)
	gold_label.size = Vector2(84, 14)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(gold_label)
	_refresh_gold()

	journal_label = _make_label(7, Vector2(8, STATUS_TOP + 15), Vector2(100, 10))
	journal_label.text = Camp.journal_tag(prof.journals_found)
	bottles_label = _make_label(7, Vector2(178, STATUS_TOP + 15), Vector2(84, 10), HORIZONTAL_ALIGNMENT_RIGHT)
	bottles_label.text = Camp.oil_tag(prof.oil_bottles)

	_build_gear_pips(STATUS_TOP + 29)

func _build_gear_pips(y: float) -> void:
	# 상점을 열지 않고도 장비 상태가 보인다 — 칸이 다 차면 만렙.
	# 상점에서 사면 그 자리에서 다시 그려야 하므로 통째로 갈아끼울 수 있게 담아둔다.
	if is_instance_valid(gear_row):
		gear_row.queue_free()
	gear_row = Node2D.new()
	add_child(gear_row)
	var x := 8.0
	for g: Dictionary in Camp.gear_pips(GameState.profile.upgrades):
		var lbl := Label.new()
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.position = Vector2(x, y)
		lbl.size = Vector2(26, 10)
		lbl.text = g.label
		gear_row.add_child(lbl)
		var px := x + 26.0
		for i in range(g.max):
			var dot := ColorRect.new()
			dot.color = Color("#FFEC27") if i < g.level else Color(0.24, 0.21, 0.29)
			dot.position = Vector2(px, y + 2)
			dot.size = Vector2(3, 5)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gear_row.add_child(dot)
			px += 5.0
		x += 52.0

func _build_camp_props() -> void:
	var c := GameState.corruption()
	tent = _sprite("tent", Vector2(4, 220), 2.0)
	_sprite("woodpile", Vector2(70, 238), 1.25)
	# 오염이 깊어지면 불이 사그라든다 — 거점이 식어가는 것을 말 없이 보여준다
	campfire = _sprite("campfire_low" if c >= 2 else "campfire", Vector2(102, 236), 2.0)
	_flicker(campfire)
	_sprite("miner_idle", Vector2(138, 236), 2.0)
	_sprite("crate", Vector2(172, 244), 1.5)

	merchant = _sprite("merchant", MERCHANT_BASE_POS, 2.0)
	if c >= 3:
		merchant.position += Vector2(6, -4)  # 오염 3+ — 위치가 미묘하게 이동

	var lamp := _sprite("lantern_post", Vector2(246, 236), 1.0)
	if c >= 2:
		lamp.modulate = Color(0.7, 0.66, 0.78)

func _build_mine_mouth() -> void:
	# 화면 이름이 갱도 입구인데 정작 입구가 없었다 — 여기가 이 화면의 주인공이다
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.015, 0.03)
	dark.position = PIT_VOID.position
	dark.size = PIT_VOID.size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)

	for i in range(3):  # 사다리는 내려갈수록 어둠에 먹힌다
		var rung := _sprite("ladder", Vector2(119, 300 + i * 30), 2.0)
		rung.modulate.a = 1.0 - i * 0.35

	_sprite("mine_mouth", PIT_POS, PIT_SCALE)
	_sprite("minecart", Vector2(4, 344), 1.5)  # 갱구 앞에 세워둔 광차

	var tag := Camp.relic_tag(GameState.profile.relic)
	if tag != "":
		# 저 아래 두고 온 가방 — 회수하러 갈 이유를 화면에 남긴다
		_sprite("relic_bag", Vector2(236, 300), 1.5)
		relic_label = _make_label(7, Vector2(206, 330), Vector2(60, 10), HORIZONTAL_ALIGNMENT_CENTER)
		relic_label.text = tag
		relic_label.modulate = Color("#FF77A8")

	var pit_btn := Button.new()  # 입구를 눌러도 내려간다
	pit_btn.flat = true
	pit_btn.focus_mode = Control.FOCUS_NONE
	pit_btn.position = PIT_POS
	pit_btn.size = Vector2(192, 128)
	pit_btn.pressed.connect(func() -> void: descend_pressed.emit())
	add_child(pit_btn)

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
	tw.tween_callback(func() -> void: if is_instance_valid(settle_label): settle_label.visible = false)

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

	shop_title.add_theme_font_override("font", _font)
	shop_title.add_theme_font_size_override("font_size", 12)
	shop_title.text = TextDb.t("ui", "shop")
	vbox.add_child(shop_title)

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
	gold_label.text = Camp.gold_tag(GameState.profile.gold)

func _refresh_status_bar() -> void:
	# 상점에서 사면 상태 바가 그대로 굳어 있었다 — 구매 경로에서 같이 갱신한다
	bottles_label.text = Camp.oil_tag(GameState.profile.oil_bottles)
	_build_gear_pips(STATUS_TOP + 29)

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
	_refresh_status_bar()

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
	_refresh_status_bar()

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

	notebook_title.add_theme_font_override("font", _font)
	notebook_title.add_theme_font_size_override("font_size", 12)
	notebook_title.text = TextDb.t("ui", "notebook")
	vbox.add_child(notebook_title)

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
	back_btn.pressed.connect(func() -> void: journal_overlay.visible = false; notebook_panel.visible = true)
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
