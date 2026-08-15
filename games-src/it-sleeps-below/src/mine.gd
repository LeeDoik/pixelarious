class_name Mine
extends Node2D
## 갱도 컨트롤러 — 입력, 채굴/이동/중력, 기름, 픽업, 죽음. 러커·이상현상은 Task 13에서 붙인다.

signal run_ended(reason: String, depth: int)
signal noise_event(pos: Vector2i, level: float)
signal journal_found(id: String)
signal strata_entered(strata: int)

var cells: PackedInt32Array
var journal_spots: Array = []
var view: MineView
var player: Player
var camera: Camera2D

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
var alive := true

func _ready() -> void:
	var ctx: Dictionary = GameState.start_run()
	var g := WorldGen.generate(GameState.run.seed, ctx)
	cells = g.cells
	journal_spots = g.journal_spots
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
	view.reveal(ppos, light_radius())
	view.camera_row = ppos.y
	if held_dir != Vector2i.ZERO and not busy:
		_try_move(held_dir)
	var s := WorldGen.strata_of(ppos.y)
	if s != _last_strata:
		_last_strata = s
		strata_entered.emit(s)
		Sfx.ambience(["amb_surface", "amb_rock", "amb_fissure", "", ""][mini(s, 4)])

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
	Sfx.play(["dig_dirt", "dig_rock", "dig_rock", "dig_flesh"][s])
	_after_move()

func _collect(target: Vector2i) -> void:
	var c := cells[WorldGen.idx(target.x, target.y)]
	if c >= WorldGen.ORE_BASE:
		if GameState.run.bag.size() < bag_capacity():
			GameState.run.bag.append(c - WorldGen.ORE_BASE)
			Sfx.play("ore_pickup")
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
		run_ended.emit("surfaced", GameState.run.depth)
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
