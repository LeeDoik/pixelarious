extends Node2D
## 월드 조립: 스폰·카메라·충돌·낙사 판정·세션 흐름(타이틀/게임오버/일시정지).

var cam: Camera2D
var hud: Hud
var player: Player
var overlay: Overlay
var stars_root: Node2D
var asteroids_root: Node2D
var rng := RandomNumberGenerator.new()
var _paused := false

var start_y := 0.0
var top_star: Dictionary = {}   # {"type": String, "pos": Vector2} — 스포너 체인의 최상단
var cam_target_y := 0.0

func _ready() -> void:
	# 일시정지 중에도 _unhandled_input이 계속 호출되어야 "탭하여 재개"가 가능하다.
	# (트리가 paused면 기본 process_mode 노드는 입력 콜백도 멈춘다 — _process에서 _paused로 별도 게이트.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	stars_root = Node2D.new()
	asteroids_root = Node2D.new()
	# 일시정지 중 실제로 멈춰야 하는 서브트리는 Main의 ALWAYS를 상속하지 않도록 명시적으로 PAUSABLE 고정.
	stars_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	asteroids_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stars_root)
	add_child(asteroids_root)
	cam = Camera2D.new()
	cam.position = Vector2(Tuning.VIEW_W / 2.0, Tuning.VIEW_H / 2.0)
	add_child(cam)
	cam.make_current()
	cam.add_child(Starfield.new())
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	_build_world()
	overlay = Overlay.new()
	add_child(overlay)
	if GameState.quick_restart:
		GameState.quick_restart = false
		GameState.start_run()
		Sfx.start_ambient()
		overlay.clear()
	else:
		GameState.phase = GameState.Phase.TITLE
		overlay.show_title()

func _view_h() -> float:
	return get_viewport().get_visible_rect().size.y

func _build_world() -> void:
	start_y = Tuning.VIEW_H - Tuning.FIRST_STAR_OFFSET_Y
	var first := _spawn_star("giant", Vector2(Tuning.VIEW_W / 2.0, start_y), 1.0)
	top_star = {"type": "giant", "pos": first.global_position}
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_player_died)
	player.hopped.connect(func(bonus: int) -> void:
		if bonus > 0:
			hud.show_bonus("+%d" % bonus)
	)
	player.attach_to(first, first.global_position + Vector2(first.orbit_r, 0), Vector2(0, 10))
	cam_target_y = cam.position.y

func _spawn_star(type: String, pos: Vector2, collapse_mult: float) -> Star:
	var s := Star.new()
	stars_root.add_child(s)
	s.setup(type, collapse_mult)
	s.global_position = pos
	s.add_to_group("stars")
	s.collapsed.connect(_on_star_collapsed)
	return s

func _height() -> float:
	return start_y - player.global_position.y if player else 0.0

func _process(delta: float) -> void:
	if player == null or _paused:
		return
	_handle_capture()
	_handle_asteroid_hit()
	_stream_spawn()
	_update_camera(delta)
	_check_fall_death()
	var height := _height()
	GameState.update_rise(height)
	# 미터 표시는 순수 고도가 아니라 점수(최고 고도 + 보너스) — 게임오버 SCORE와 항상 일치해야 한다.
	hud.set_altitude(GameState.score())
	hud.set_combo(GameState.combo)

func _handle_capture() -> void:
	if player.state != Player.State.FLYING:
		return
	for s in stars_root.get_children():
		var star := s as Star
		if star == null or not star.alive or star == player.last_star:
			continue
		if OrbitMath.try_capture(player.global_position, star.global_position, star.orbit_r):
			player.attach_to(star, player.global_position, player.vel)
			return

func _handle_asteroid_hit() -> void:
	if player.state == Player.State.DEAD:
		return
	for a in asteroids_root.get_children():
		if player.global_position.distance_to((a as Node2D).global_position) < Tuning.ASTEROID_KILL_DIST:
			player.die()
			return

func _stream_spawn() -> void:
	var view_top := cam.position.y - _view_h() / 2.0
	while (top_star.pos as Vector2).y > view_top - Tuning.SPAWN_AHEAD:
		var h: float = start_y - (top_star.pos as Vector2).y
		var next := Spawner.next_star(top_star, h, rng)
		var p := Spawner.params_for_height(h)
		_spawn_star(next.type, next.pos, p.collapse_mult)
		if rng.randf() < p.asteroid_p:
			var ast := Asteroid.new()
			asteroids_root.add_child(ast)
			ast.add_to_group("asteroids")
			ast.setup((next.pos as Vector2).y + Tuning.ASTEROID_Y_OFFSET, rng)
		top_star = next
	var view_bottom := cam.position.y + _view_h() / 2.0
	for s in stars_root.get_children():
		if s == player.star or s == player.last_star:
			continue
		if (s as Node2D).global_position.y > view_bottom + Tuning.DESPAWN_BELOW:
			s.queue_free()
	for a in asteroids_root.get_children():
		if (a as Node2D).global_position.y > view_bottom + Tuning.DESPAWN_BELOW:
			a.queue_free()

func _update_camera(delta: float) -> void:
	cam_target_y = minf(cam_target_y, player.global_position.y + Tuning.CAM_LEAD)
	cam.position.y = lerpf(cam.position.y, cam_target_y, minf(Tuning.CAM_FOLLOW_SPEED * delta, 1.0))

func _check_fall_death() -> void:
	# 상태 무관: 킬라인(화면 하단 + 여유) 아래로 내려가면 사망 — 화면 밖 별에 잡혀 공전해도 예외 없음.
	if player.state != Player.State.DEAD and player.global_position.y > cam.position.y + _view_h() / 2.0 + Tuning.KILL_MARGIN:
		player.die()

func _on_star_collapsed(s: Star) -> void:
	# 붕괴는 즉사가 아니라 낙하 — 아래 별에 잡히면 살고, 화면 밖으로 떨어지면 낙사 규칙이 처리한다.
	if player and player.star == s:
		player.drop()

func _on_player_died() -> void:
	var was_best := GameState.best
	GameState.end_run()
	Sfx.stop_ambient()
	Engine.time_scale = Tuning.DEATH_SLOWMO
	var t := get_tree().create_timer(Tuning.DEATH_SLOWMO_SEC, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		overlay.show_game_over(GameState.score(), GameState.best, GameState.best > was_best)
	)

func _is_drift_press(event: InputEvent) -> bool:
	# 모바일 웹: 터치를 마우스 에뮬레이션에 맡기지 않고 직접 받는다
	# (에뮬레이션은 꺼져 있음 — 켜면 한 탭이 터치+마우스로 두 번 발사된다).
	if event is InputEventScreenTouch:
		return event.pressed
	return event.is_action_pressed("drift")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_drift_press(event):
		return
	if _paused:
		_paused = false
		get_tree().paused = false
		overlay.clear()
		return
	match GameState.phase:
		GameState.Phase.TITLE:
			overlay.clear()
			GameState.start_run()
			Sfx.start_ambient()
			player.launch()
		GameState.Phase.PLAYING:
			player.launch()
		GameState.Phase.GAME_OVER:
			if Engine.time_scale == 1.0:
				GameState.quick_restart = true
				get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _paused:
		if not GameState.pause_on_focus_out:
			return
		_paused = true
		get_tree().paused = true
		overlay.show_paused()
