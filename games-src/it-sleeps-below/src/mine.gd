class_name Mine
extends Node2D
## 갱도 컨트롤러 — 입력, 채굴/이동/중력, 기름, 픽업, 죽음. 러커·이상현상은 Task 13에서 붙인다.

signal run_ended(reason: String, depth: int)
signal noise_event(pos: Vector2i, level: float)
signal journal_found(id: String)
signal strata_entered(strata: int)

const _LAST_AUTHOR_IDS := ["han_3", "baek_3", "seo_4"]

var cells: PackedInt32Array
var journal_spots: Array = []
var relic_spot: Dictionary = {}
var view: MineView
var player: Player
var camera: Camera2D
var light_rig: LightRig
var hud: Hud

var lurker: Lurker
var director := {"mode": LurkerLogic.M_SILENCE, "t": 20.0}
var anomalies: AnomalyDirector
var heartbeat_forced := false
var finale_mode := false
var finale: FinaleDirector

var ppos := Vector2i(8, 0)
var busy := false
var lamp_on := true
var oil := 0.0
var hearts := 3
var held_dir := Vector2i.ZERO
var _held_key := KEY_NONE
var _held_mouse := false
var _last_dig_end := -10.0
var _last_strata := -1
var last_dig_sfx := ""
var alive := true
var _lurker_mode := -1
var _beat_acc := 0.0
var _author_seen: Dictionary = {}

func _ready() -> void:
	var ctx: Dictionary = GameState.start_run()
	var g := WorldGen.generate(GameState.run.seed, ctx)
	cells = g.cells
	if GameState.profile.ending_seen:
		# 이미 리빌을 본 세이브 — 심장 챔버는 비어 있다 (스펙 §9)
		cells[WorldGen.idx(Tuning.HEART_X, WorldGen.DEPTH - 1)] = WorldGen.T_EMPTY
	journal_spots = g.journal_spots
	relic_spot = g.relic_spot
	oil = GameState.run.oil
	hearts = GameState.run.hearts

	view = MineView.new()
	view.cells = cells
	add_child(view)
	player = Player.new()
	add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	_sync_positions(true)
	light_rig = LightRig.new()
	add_child(light_rig)
	hud = Hud.new()
	add_child(hud)
	hud.lamp_pressed.connect(toggle_lamp)
	hud.pause_pressed.connect(func() -> void: get_tree().paused = not get_tree().paused)
	strata_entered.connect(hud.show_strata)
	strata_entered.connect(_on_strata_entered)
	Sfx.ambience_pitch(1.0)
	Sfx.ambience_volume(-6.0)
	anomalies = AnomalyDirector.new()
	anomalies.mine = self
	add_child(anomalies)

func light_radius() -> float:
	return Oil.radius(oil, Oil.tank(GameState.profile.upgrades.lamp), lamp_on)

func is_open_cell(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= WorldGen.W or p.y < 0 or p.y >= WorldGen.DEPTH:
		return false
	return MoveRules.passable(cells[WorldGen.idx(p.x, p.y)])

func bag_capacity() -> int:
	# 기름병은 가방 슬롯을 차지한다 — 보험 한 칸 = 광석 한 칸 (스펙 §10)
	return Economy.bag_slots(GameState.profile.upgrades.bag) - GameState.run.bottles

func _process(delta: float) -> void:
	if not alive:
		return
	oil = Oil.drain(oil, delta, lamp_on)
	if oil <= 0.0 and GameState.run.bottles > 0:
		GameState.run.bottles -= 1
		oil = Oil.tank(GameState.profile.upgrades.lamp) * Tuning.OIL_PICKUP_RATIO
		Sfx.play("lamp_toggle")
	GameState.run.oil = oil
	view.reveal(ppos, finale.current_radius if finale_mode and finale else light_radius())
	view.camera_row = ppos.y
	if held_dir != Vector2i.ZERO and not busy:
		_try_move(held_dir)
	var s := WorldGen.strata_of(ppos.y)
	if s != _last_strata:
		_last_strata = s
		strata_entered.emit(s)
		Sfx.ambience(["amb_surface", "amb_rock", "amb_fissure", "", ""][mini(s, 4)])
	light_rig.follow(player.position)
	if not finale_mode:
		# 피날레 중에는 FinaleDirector가 심장 펄스로만 반경을 구동한다 — 여기서 덮어쓰면 펄스가 씹힌다
		light_rig.set_radius_tiles(light_radius())
	hud.update_state(oil / Oil.tank(GameState.profile.upgrades.lamp), lamp_on, hearts,
		GameState.run.bag.size(), Economy.bag_slots(GameState.profile.upgrades.bag), ppos.y)
	if ppos.y >= Tuning.LURKER_MIN_DEPTH:
		director = LurkerLogic.director_step(director, delta, ppos.y)
		_update_lurker(delta)
	_check_last_journal_proximity()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and alive:
		get_tree().paused = true

func toggle_lamp() -> void:
	lamp_on = not lamp_on
	GameState.run.lamp_on = lamp_on
	Sfx.play("lamp_toggle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: toggle_lamp()
			KEY_LEFT, KEY_A:
				held_dir = Vector2i(-1, 0)
				_held_key = event.keycode
				_held_mouse = false
			KEY_RIGHT, KEY_D:
				held_dir = Vector2i(1, 0)
				_held_key = event.keycode
				_held_mouse = false
			KEY_UP, KEY_W:
				held_dir = Vector2i(0, -1)
				_held_key = event.keycode
				_held_mouse = false
			KEY_DOWN, KEY_S:
				held_dir = Vector2i(0, 1)
				_held_key = event.keycode
				_held_mouse = false
	elif event is InputEventKey and not event.pressed:
		if event.keycode == _held_key:
			held_dir = Vector2i.ZERO
			_held_key = KEY_NONE
	elif event is InputEventMouseButton:
		if event.pressed:
			var world := get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position
			var tile := Vector2i(int(world.x / 16.0), int(world.y / 16.0))
			var d := tile - ppos
			if abs(d.x) + abs(d.y) == 1:
				held_dir = d
				_held_mouse = true
				_held_key = KEY_NONE
		elif _held_mouse:
			held_dir = Vector2i.ZERO
			_held_mouse = false

func _try_move(dir: Vector2i) -> void:
	var act := MoveRules.classify(cells, ppos, dir, GameState.profile.upgrades.pick)
	match act:
		MoveRules.A_WALK, MoveRules.A_CLIMB:
			_step(ppos + dir, act)
		MoveRules.A_DIG:
			_dig(ppos + dir)
		_:
			pass

func _step(target: Vector2i, act: int) -> void:
	busy = true
	player.set_anim("climb" if act == MoveRules.A_CLIMB else "walk")
	if act == MoveRules.A_CLIMB:
		Sfx.play("climb")
	var dur := Tuning.CLIMB_TIME if act == MoveRules.A_CLIMB else Tuning.WALK_TIME
	var tw := create_tween()
	tw.tween_property(player, "position", Vector2(target * 16) + Vector2(8, 8), dur)
	await tw.finished
	ppos = target
	GameState.run.depth = maxi(GameState.run.depth, ppos.y)
	_after_move()

func _dig(target: Vector2i) -> void:
	busy = true
	player.set_anim("dig")
	var strata_row: int = target.y
	# 조심 채굴 판정은 채굴 "시작" 시점의 간격으로 — 홀드 연속은 간격≈0이라 항상 LOUD,
	# 끊어 파기(직전 채굴 종료 후 QUIET_GAP 이상 쉼)만 QUIET (스펙 §11)
	var gap := Time.get_ticks_msec() / 1000.0 - _last_dig_end
	var level: float = Tuning.NOISE_QUIET if gap >= Tuning.QUIET_GAP else Tuning.NOISE_LOUD
	await get_tree().create_timer(Economy.dig_time(GameState.profile.upgrades.pick, strata_row)).timeout
	_last_dig_end = Time.get_ticks_msec() / 1000.0
	noise_event.emit(target, level)
	_collect(target)
	cells[WorldGen.idx(target.x, target.y)] = WorldGen.T_EMPTY
	view.cells = cells
	var s: int = mini(WorldGen.strata_of(strata_row), 3)
	last_dig_sfx = ["dig_dirt", "dig_rock", "dig_rock", "dig_flesh"][s]
	Sfx.play(last_dig_sfx)
	_after_move()

func _collect(target: Vector2i) -> void:
	var c := cells[WorldGen.idx(target.x, target.y)]
	if c >= WorldGen.ORE_BASE:
		if GameState.run.bag.size() < bag_capacity():
			GameState.run.bag.append(c - WorldGen.ORE_BASE)
			Sfx.play("ore_pickup")
		else:
			hud.flash_bag_full()
	elif c == WorldGen.T_OIL:
		oil = minf(Oil.tank(GameState.profile.upgrades.lamp), oil + Oil.tank(GameState.profile.upgrades.lamp) * Tuning.OIL_PICKUP_RATIO)
		Sfx.play("ore_pickup")
	elif c == WorldGen.T_JOURNAL:
		for spot in journal_spots:
			if Vector2i(spot.x, spot.y) == target and not GameState.profile.journals_found.has(spot.id):
				GameState.profile.journals_found.append(spot.id)
				GameState.save()
				Sfx.play("journal_get")
				journal_found.emit(spot.id)
	elif c == WorldGen.T_RELIC:
		for item in GameState.profile.relic.get("items", []):
			if GameState.run.bag.size() < bag_capacity():
				GameState.run.bag.append(int(item))
		GameState.profile.relic = {}
		GameState.save()
		Sfx.play("ore_pickup")
	elif c == WorldGen.T_HEART:
		GameState.run.bag.append(6)  # 발광 광석 취급 + 서사상 '심장 하나' — 가방 용량 무시
		finale = FinaleDirector.new()
		finale.mine = self
		add_child(finale)
		finale.start()

func _after_move() -> void:
	player.set_anim("idle")
	# 금 간 타일 — 머리 위가 CRACK이면 0.4초 뒤 붕괴 (그 자리에 있으면 데미지)
	var above := ppos + Vector2i(0, -1)
	if above.y >= 0 and cells[WorldGen.idx(above.x, above.y)] == WorldGen.T_CRACK:
		var crack_pos := above
		var stood_at := ppos
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if cells[WorldGen.idx(crack_pos.x, crack_pos.y)] != WorldGen.T_CRACK:
				return
			cells[WorldGen.idx(crack_pos.x, crack_pos.y)] = WorldGen.T_EMPTY
			view.cells = cells
			Sfx.play("rockfall")
			if ppos == stood_at and alive:
				_damage(1, "death_fall"))
	# 중력
	var land := MoveRules.fall_landing(cells, ppos)
	if land != ppos:
		var fall := land.y - ppos.y
		var tw := create_tween()
		tw.tween_property(player, "position", Vector2(land * 16) + Vector2(8, 8), Tuning.FALL_TIME * fall)
		await tw.finished
		ppos = land
		GameState.run.depth = maxi(GameState.run.depth, ppos.y)
		Sfx.play("land")
		if fall > Economy.fall_tolerance(GameState.profile.upgrades.boots):
			_damage(1, "death_fall")
	_sync_positions(false)
	# 지표 복귀
	if ppos.y == 0 and alive:
		alive = false
		busy = false
		run_ended.emit("finale_escaped" if finale_mode else "surfaced", GameState.run.depth)
		return
	busy = false

func _damage(n: int, reason: String) -> void:
	hearts = maxi(0, hearts - n)
	GameState.run.hearts = hearts
	Sfx.play("fall_hurt")
	if hearts <= 0:
		die(reason)

func die(reason: String) -> void:
	if not alive:
		return
	alive = false
	player.set_anim("death")
	GameState.end_run_death(GameState.run.depth)
	await get_tree().create_timer(1.2).timeout
	run_ended.emit(reason, GameState.run.depth)

func _sync_positions(snap: bool) -> void:
	var p := Vector2(ppos * 16) + Vector2(8, 8)
	player.position = p
	camera.position = Vector2(WorldGen.W * 8, p.y)
	if snap:
		camera.reset_smoothing()

# ── 러커 스폰/디스폰/심박 (Task 13) ──

func _update_lurker(delta: float) -> void:
	if finale_mode:
		return  # 피날레는 FinaleDirector가 자체 러커 3개체를 직접 관리한다
	if director.mode != _lurker_mode:
		_lurker_mode = director.mode
		match director.mode:
			LurkerLogic.M_RETREAT:
				_retreat_lurker()
			LurkerLogic.M_SILENCE:
				_despawn_lurker()
	# M_HUNT는 모드 전환 프레임에만 스폰을 시도하면 _find_spawn_cell 실패 시
	# 헌트 웨이브 전체가 러커 없이 지나간다 — lurker == null인 한 매 프레임 재시도 (스폰 자체는 저렴)
	if director.mode == LurkerLogic.M_HUNT and lurker == null:
		_spawn_lurker()
	if lurker:
		lurker.tick(delta, ppos, light_radius(), lamp_on)
		var dist := Vector2(lurker.grid_pos).distance_to(Vector2(ppos))
		_tick_heartbeat(delta, 0.8 + 8.0 / maxf(dist, 1.0))
	elif not heartbeat_forced:
		_tick_heartbeat(delta, 0.0)

func _spawn_lurker() -> void:
	spawn_or_move_lurker(_find_spawn_cell(light_radius()))

func _retreat_lurker() -> void:
	if lurker == null:
		return
	var away := lurker.grid_pos - ppos
	if away == Vector2i.ZERO:
		away = Vector2i(0, -1)
	lurker.target = lurker.grid_pos + Vector2i(sign(away.x), sign(away.y)) * 20

func _despawn_lurker() -> void:
	if lurker == null:
		return
	lurker.queue_free()
	lurker = null
	_beat_acc = 0.0

func spawn_or_move_lurker(cell: Vector2i) -> void:
	# 디렉터·이상현상 양쪽에서 공유하는 스폰/재배치 진입점 — caught/hear 배선은 최초 1회만
	if cell == Vector2i(-1, -1):
		return
	if lurker == null:
		lurker = Lurker.new()
		add_child(lurker)
		lurker.setup(cell, is_open_cell)
		lurker.caught.connect(func() -> void: die("death_lurker"))
		noise_event.connect(lurker.hear)
	else:
		lurker.grid_pos = cell
		lurker.position = Vector2(cell * 16) + Vector2(8, 0)
	lurker.target = cell

func spawn_lurker_within(center: Vector2i, max_r: float) -> void:
	spawn_or_move_lurker(_find_cell_within(center, max_r))

func _tick_heartbeat(delta: float, rate: float) -> void:
	Sfx.heartbeat(rate)
	if rate <= 0.0:
		_beat_acc = 0.0
		return
	_beat_acc += delta * rate
	if _beat_acc >= 1.0:
		_beat_acc = fmod(_beat_acc, 1.0)
		if GameState.profile.settings.haptics:
			Input.vibrate_handheld(40)  # 웹 Android만 동작 — 다른 플랫폼은 조용히 무시된다

# BFS로 ppos에서 파낸(EMPTY) 셀만 통해 도달 가능한 집합 — 그리드가 작아 전수 탐색 허용
func _bfs_open_cells(center: Vector2i) -> Dictionary:
	var seen := {}
	if not is_open_cell(center):
		return seen
	seen[center] = true
	var q: Array[Vector2i] = [center]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if seen.has(nxt) or not is_open_cell(nxt):
				continue
			seen[nxt] = true
			q.append(nxt)
	return seen

func _find_spawn_cell(min_dist: float) -> Vector2i:
	# 빛 반경 밖 파낸 셀 중 가장 가까운 곳. 유품이 있으면 유품 6타일 이내를 우선한다
	var open := _bfs_open_cells(ppos)
	var fallback := Vector2i(-1, -1)
	for cell in open:
		if cell == ppos or Vector2(cell).distance_to(Vector2(ppos)) <= min_dist:
			continue
		if fallback == Vector2i(-1, -1):
			fallback = cell
		if relic_spot.has("x") and Vector2(cell).distance_to(Vector2(relic_spot.x, relic_spot.y)) <= 6.0:
			return cell
	return fallback

func _find_cell_within(center: Vector2i, max_r: float) -> Vector2i:
	var open := _bfs_open_cells(center)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for cell in open:
		if cell == center:
			continue
		var d: float = Vector2(cell).distance_to(Vector2(center))
		if d <= max_r and d < best_d:
			best_d = d
			best = cell
	return best

# 파낸 적 없는 지점(front)에서 가장 가까운 파낸 셀 — 벽을 통과해 위치만 탐색한다
func _nearest_open_to(target: Vector2i) -> Vector2i:
	if is_open_cell(target):
		return target
	var seen := {target: true}
	var q: Array[Vector2i] = [target]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if seen.has(nxt) or nxt.x < 0 or nxt.x >= WorldGen.W or nxt.y < 0 or nxt.y >= WorldGen.DEPTH:
				continue
			seen[nxt] = true
			if is_open_cell(nxt):
				return nxt
			q.append(nxt)
	return Vector2i(-1, -1)

func _on_strata_entered(s: int) -> void:
	# 첫 심층 진입 스크립트 조우 (스테이징 ②) — 디렉터 무시, 세이브당 1회
	if s == 3 and not GameState.profile.anomaly_flags.has("first_deep"):
		_first_deep_encounter()

func _first_deep_encounter() -> void:
	GameState.profile.anomaly_flags.append("first_deep")
	GameState.save()
	var front := _nearest_open_to(ppos + Vector2i(0, 8))
	if front == Vector2i(-1, -1):
		return
	var l := Lurker.new()
	add_child(l)
	l.setup(front, is_open_cell)
	for i in range(3):
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(l):
			return
		if not alive:
			l.queue_free()
			return
		l.grid_pos = LurkerLogic.next_step(l.grid_pos, ppos, is_open_cell)
		l.position = Vector2(l.grid_pos * 16) + Vector2(8, 0)
		l.frozen = LurkerLogic.is_frozen(l.grid_pos, ppos, light_radius(), lamp_on)
		l.queue_redraw()
	if not is_instance_valid(l):
		return
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	await tw.finished
	if is_instance_valid(l):
		l.queue_free()

func _check_last_journal_proximity() -> void:
	# 시리즈 마지막 일지 스팟 8타일 이내 — "작성자가 배회한다" (스펙 §8), 스팟당 세이브 내 1회
	for spot in journal_spots:
		if not _LAST_AUTHOR_IDS.has(spot.id) or _author_seen.has(spot.id):
			continue
		if Vector2(spot.x, spot.y).distance_to(Vector2(ppos)) <= 8.0:
			_author_seen[spot.id] = true
			Sfx.play("steps_wall")
			_silhouette_flash()

func _silhouette_flash() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = load("res://assets/img/lurker.png")
	var dir := -1 if randi() % 2 == 0 else 1
	ghost.position = Vector2(player.position) + Vector2(dir * (light_radius() + 1.5) * 16.0, 0)
	add_child(ghost)
	get_tree().create_timer(1.2).timeout.connect(ghost.queue_free)
