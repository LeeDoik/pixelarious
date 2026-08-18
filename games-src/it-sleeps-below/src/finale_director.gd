class_name FinaleDirector
extends Node
## 산이 깨어난다 — 피날레 시퀀스 전부. mine이 심장을 채굴하면 기동되어
## 트위스트 적용, 심장 펄스 조명, 러커 3개체(예외 규칙), 유혹 광석을 관리한다.

var mine: Mine
var current_radius := 0.75  # 매 프레임 광원 반경 — Mine._process가 fog reveal에 그대로 참조
var lurkers: Array[Lurker] = []

var _pulse_t := 0.0
var _shake_gen := 0

func start() -> void:
	Sfx.ambience("amb_finale")
	Sfx.play("awaken")
	_awaken_intro()
	var out: Dictionary = Finale.twist(mine.cells, GameState.run.seed)
	mine.cells = out.cells
	mine.view.cells = mine.cells
	mine.lamp_on = false
	mine.finale_mode = true
	mine._despawn_lurker()
	_scatter_temptation()
	for i in range(3):
		var l := Lurker.new()
		mine.add_child(l)
		l.setup(_spawn_pos(i), mine.is_open_cell)
		l.caught.connect(func() -> void:
			mine.die("death_lurker"))
		mine.noise_event.connect(l.hear)  # 유혹 광석을 캐는 소리에도 반응해야 한다
		lurkers.append(l)

func _process(delta: float) -> void:
	if not mine.finale_mode or not mine.alive:
		return
	_pulse_t += delta
	var phase := sin(_pulse_t * TAU / Tuning.HEART_PULSE_SEC)
	var bright := phase > 0.0
	current_radius = 0.75 + (5.0 - 0.75) * maxf(0.0, phase)
	mine.light_rig.set_radius_tiles(current_radius)
	Sfx.heartbeat(1.4)
	for l in lurkers:
		# 펄스 밝은 반주기 = 전원 정지 (빛 규칙의 피날레 버전) — 어두운 반주기만 움직인다
		if not bright:
			l.tick(delta, mine.ppos, 0.0, false)
		else:
			l.frozen = true
			l.queue_redraw()

# ── 각성 연출: 자막 + 화면 셰이크 + 플래시 (유일한 충격 연출, reduced_flash면 절반) ──

func _awaken_intro() -> void:
	if not is_instance_valid(mine):
		return
	var reduced: bool = GameState.profile.settings.reduced_flash
	var amp := 2.0 if reduced else 4.0
	var flash_peak := 0.325 if reduced else 0.65
	_show_caption(TextDb.t("ending", "awaken"), 2.5)
	_flash(flash_peak, 1.5)
	_shake(amp, 1.5)

func _show_caption(text: String, sec: float) -> void:
	if not is_instance_valid(mine):
		return
	var layer := CanvasLayer.new()
	layer.layer = 21
	mine.add_child(layer)
	var label := Label.new()
	label.add_theme_font_override("font", load("res://assets/fonts/Galmuri9.ttf"))
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(16, 200)
	label.size = Vector2(238, 60)
	label.modulate.a = 0.0
	label.text = text
	layer.add_child(label)
	var tw := layer.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(maxf(0.1, sec - 1.0))
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	await tw.finished
	if is_instance_valid(layer):
		layer.queue_free()

func _flash(peak_alpha: float, dur: float) -> void:
	if not is_instance_valid(mine):
		return
	var layer := CanvasLayer.new()
	layer.layer = 22
	mine.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.position = Vector2.ZERO
	rect.size = Vector2(270, 480)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	layer.add_child(rect)
	var tw := layer.create_tween()
	tw.tween_property(rect, "modulate:a", peak_alpha, dur * 0.25)
	tw.tween_property(rect, "modulate:a", 0.0, dur * 0.75)
	await tw.finished
	if is_instance_valid(layer):
		layer.queue_free()

func _shake(amp: float, dur: float) -> void:
	_shake_gen += 1
	var gen := _shake_gen
	var t := 0.0
	while t < dur:
		if not (is_instance_valid(mine) and mine.alive and is_instance_valid(mine.camera)) or gen != _shake_gen:
			return
		mine.camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		await get_tree().create_timer(0.15).timeout
		t += 0.15
	if is_instance_valid(mine) and is_instance_valid(mine.camera) and gen == _shake_gen:
		mine.camera.offset = Vector2.ZERO

# ── 러커 스폰 지점: 챔버 위 20·60·100m 지점에서 가장 가까운 파낸 셀 ──

func _spawn_pos(i: int) -> Vector2i:
	var offsets := [20, 60, 100]
	var target_row: int = maxi(1, (WorldGen.DEPTH - 1) - offsets[i])
	return _nearest_open_to_row(target_row)

func _nearest_open_to_row(target_row: int) -> Vector2i:
	# mine.ppos(챔버)에서 파낸 셀만 통해 BFS — 목표 행에 가장 가까운 셀을 고른다
	var start: Vector2i = mine.ppos
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var best := start
	var best_d := absi(start.y - target_row)
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		var d := absi(cur.y - target_row)
		if d < best_d:
			best_d = d
			best = cur
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if seen.has(nxt) or not mine.is_open_cell(nxt):
				continue
			seen[nxt] = true
			q.append(nxt)
	return best

# ── 유혹 광석: 챔버~지표 파낸 통로에 인접한 벽 12곳에 발광 광석(6번)을 심는다 ──

func _scatter_temptation() -> void:
	var candidates := {}
	var seen := {mine.ppos: true}
	var q: Array[Vector2i] = [mine.ppos]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if nxt.x < 1 or nxt.x >= WorldGen.W - 1 or nxt.y < 0 or nxt.y >= WorldGen.DEPTH:
				continue
			if mine.is_open_cell(nxt):
				if not seen.has(nxt):
					seen[nxt] = true
					q.append(nxt)
				continue
			var c: int = mine.cells[WorldGen.idx(nxt.x, nxt.y)]
			if WorldGen.STRATA_BASE_TILE.has(c):
				candidates[nxt] = true  # 파낸 통로 인접한 순수 암반 벽만 (기존 광석/기름/일지는 건드리지 않는다)
	var pool: Array = candidates.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run.seed
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var n: int = mini(12, pool.size())
	for i in range(n):
		var p: Vector2i = pool[i]
		mine.cells[WorldGen.idx(p.x, p.y)] = WorldGen.ORE_BASE + 6
	mine.view.cells = mine.cells
