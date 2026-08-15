class_name AnomalyDirector
extends Node
## 이상 현상 — 풀에서 뽑아 연출 실행. 1회성은 프로필 플래그로 영속.

var mine: Mine
var rng := RandomNumberGenerator.new()
var _next_t := 0.0

func _ready() -> void:
	rng.randomize()
	_arm()

func _arm() -> void:
	_next_t = rng.randf_range(45.0, 90.0)

func _process(delta: float) -> void:
	if not mine.alive or mine.ppos.y < 40:
		return
	_next_t -= delta
	if _next_t > 0.0:
		return
	_arm()
	var e := AnomalyPool.pick(GameState.profile.anomaly_flags, mine.ppos.y, GameState.corruption(), rng)
	if e.is_empty():
		return
	if e.once:
		GameState.profile.anomaly_flags.append(e.id)
		GameState.save()
	_run(e.id)

func _run(id: String) -> void:
	match id:
		"lamp_blink":
			Sfx.play("lamp_flicker")
			mine.light_rig.blackout(2.0)
		"lamp_blink_real":
			Sfx.play("lamp_flicker")
			mine.light_rig.blackout(2.0)
			mine.spawn_lurker_within(mine.ppos, 6.0)
		"tunnel_sealed":
			_reseal_above(1)
		"tunnel_sealed_real":
			_reseal_above(3)
		"echo_pick":
			Sfx.play("echo_pick")
		"edge_silhouette":
			var ghost := Sprite2D.new()
			ghost.texture = load("res://assets/img/lurker.png")
			var dir := -1 if rng.randi_range(0, 1) == 0 else 1
			ghost.position = Vector2(mine.player.position) + Vector2(dir * (mine.light_radius() + 1.5) * 16.0, 0)
			mine.add_child(ghost)
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if is_instance_valid(ghost):
					ghost.queue_free())
		"ore_whisper":
			Sfx.play("whisper")
		"rhythm_continues":
			# 실제로 방금 낸 채굴음을 그대로 반복 — strata에서 다시 유도하지 않는다 (마지막 소리와 어긋날 수 있음)
			var sound: String = mine.last_dig_sfx
			if sound == "":
				var names := ["dig_dirt", "dig_rock", "dig_rock", "dig_flesh"]
				sound = names[mini(WorldGen.strata_of(mine.ppos.y), 3)]
			Sfx.play(sound)
			get_tree().create_timer(0.6).timeout.connect(func() -> void:
				if is_instance_valid(mine):
					Sfx.play(sound))
		"ore_resealed":
			_reseal_ore()
		"false_heartbeat":
			mine.heartbeat_forced = true
			Sfx.heartbeat(1.6)
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				if is_instance_valid(mine):
					mine.heartbeat_forced = false
				Sfx.heartbeat(0.0))
		"side_tunnel":
			_dig_side_tunnel()
		"depth_999":
			mine.hud.lie_depth(999, 1.2)
		"depth_rises":
			_lie_depth_rises()
		"gauge_zero":
			mine.hud.lie_oil_zero(1.5)
		"black_ore":
			mine.hud.lie_bag_plus(1.5)
		"back_turned":
			_back_turned()
		"silent_mimic":
			_silent_mimic()
		"parallel_steps":
			_parallel_steps()
		"other_lamp":
			_other_lamp()
		_:
			pass  # black_sky / merchant_gone / pause_message — pick()에서 이미 플래그 기록됨 (지연 소비)

# ── 셀 뮤테이션 (mine.cells 직접 조작 + view 갱신) ──

func _reseal_above(count: int) -> void:
	var y := mine.ppos.y - 18
	var done := 0
	while y >= 1 and done < count:
		for x in range(1, WorldGen.W - 1):
			var i := WorldGen.idx(x, y)
			if mine.cells[i] == WorldGen.T_EMPTY:
				mine.cells[i] = WorldGen.STRATA_BASE_TILE[mini(WorldGen.strata_of(y), 3)]
				done += 1
				if done >= count:
					break
		y -= 1
	mine.view.cells = mine.cells

func _reseal_ore() -> void:
	var candidates: Array[Vector2i] = []
	for y in range(1, WorldGen.DEPTH):
		if absi(y - mine.ppos.y) <= 17:
			continue
		for x in range(1, WorldGen.W - 1):
			if mine.cells[WorldGen.idx(x, y)] >= WorldGen.ORE_BASE:
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return
	var p: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	mine.cells[WorldGen.idx(p.x, p.y)] = WorldGen.STRATA_BASE_TILE[mini(WorldGen.strata_of(p.y), 3)]
	mine.view.cells = mine.cells

func _dig_side_tunnel() -> void:
	var dir := -1 if rng.randi_range(0, 1) == 0 else 1
	var n := rng.randi_range(3, 5)
	var last := mine.ppos
	var hit_relic := false
	for i in range(1, n + 1):
		var p := mine.ppos + Vector2i(dir * i, 0)
		if p.x <= 0 or p.x >= WorldGen.W - 1:
			break
		if mine.cells[WorldGen.idx(p.x, p.y)] == WorldGen.T_RELIC:
			hit_relic = true
			break
		mine.cells[WorldGen.idx(p.x, p.y)] = WorldGen.T_EMPTY
		last = p
	mine.view.cells = mine.cells
	if not hit_relic and last != mine.ppos:
		var prop := Sprite2D.new()
		prop.texture = load("res://assets/img/journal.png")
		prop.position = Vector2(last * 16) + Vector2(8, 8)
		mine.add_child(prop)

# ── HUD 거짓말 ──

func _lie_depth_rises() -> void:
	var base := mine.ppos.y
	for i in range(6):
		get_tree().create_timer(i * 0.5).timeout.connect(
			func() -> void:
				if is_instance_valid(mine):
					mine.hud.lie_depth(base + i + 1, 0.5))

# ── 연출 조우 (러커 스프라이트 스크립트 배치, AI 없음) ──

func _ghost_at(pos: Vector2i) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = load("res://assets/img/lurker.png")
	g.position = Vector2(pos * 16) + Vector2(8, 0)
	mine.add_child(g)
	return g

func _dissolve(ghost: Sprite2D) -> void:
	if not is_instance_valid(ghost):
		return
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.5)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

func _find_nearby_ore(center: Vector2i, r: int) -> Vector2i:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := center + Vector2i(dx, dy)
			if p.x > 0 and p.x < WorldGen.W - 1 and p.y > 0 and p.y < WorldGen.DEPTH:
				if mine.cells[WorldGen.idx(p.x, p.y)] >= WorldGen.ORE_BASE:
					return p
	return Vector2i(-1, -1)

func _back_turned() -> void:
	# 통로 끝에 등 돌린 정지 → 빛에 닿으면 벽 속으로 스며든다
	var side := -1 if rng.randi_range(0, 1) == 0 else 1
	var pos: Vector2i = mine.ppos + Vector2i(side * 3, 0)
	var ghost := _ghost_at(pos)
	for i in range(18):
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(ghost) or not is_instance_valid(mine):
			return
		if Vector2(pos).distance_to(Vector2(mine.ppos)) <= mine.light_radius() and mine.lamp_on:
			break
	_dissolve(ghost)

func _silent_mimic() -> void:
	# 캐다 만 광석 앞에서 소리 없이 곡괭이질을 흉내
	var pos := _find_nearby_ore(mine.ppos, 10)
	if pos == Vector2i(-1, -1):
		return
	var ghost := _ghost_at(pos)
	get_tree().create_timer(4.0).timeout.connect(func() -> void: _dissolve(ghost))

func _parallel_steps() -> void:
	# 벽 한 겹 너머 발걸음
	Sfx.play("steps_wall")
	var dir := -1 if rng.randi_range(0, 1) == 0 else 1
	var ghost := _ghost_at(mine.ppos + Vector2i(dir * 3, 0))
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "position:y", ghost.position.y + 16.0 * 5, 4.0)
	tw.finished.connect(func() -> void: _dissolve(ghost))

func _other_lamp() -> void:
	# 저 아래 갱도에서 램프 불빛 하나가 천천히 올라온 뒤 소등
	var dot := Sprite2D.new()
	dot.texture = load("res://assets/img/lurker.png")
	dot.modulate = Color(1.0, 0.9, 0.5)
	dot.position = Vector2(mine.player.position) + Vector2(0, 16.0 * 15)
	mine.add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "position:y", dot.position.y - 16.0 * 10, 3.0)
	tw.finished.connect(dot.queue_free)
