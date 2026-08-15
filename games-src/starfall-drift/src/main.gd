extends Node2D
## 월드 조립: 스폰·카메라·충돌·낙사 판정. 상태 오버레이는 task 11.

var cam: Camera2D
var hud: Hud
var player: Player
var stars_root: Node2D
var asteroids_root: Node2D
var rng := RandomNumberGenerator.new()

var start_y := 0.0
var top_star: Dictionary = {}   # {"type": String, "pos": Vector2} — 스포너 체인의 최상단
var cam_target_y := 0.0

func _ready() -> void:
	rng.randomize()
	stars_root = Node2D.new()
	asteroids_root = Node2D.new()
	add_child(stars_root)
	add_child(asteroids_root)
	cam = Camera2D.new()
	cam.position = Vector2(Tuning.VIEW_W / 2.0, Tuning.VIEW_H / 2.0)
	add_child(cam)
	cam.make_current()
	cam.add_child(Starfield.new())
	hud = Hud.new()
	add_child(hud)
	_build_world()
	Sfx.start_ambient()

func _build_world() -> void:
	start_y = Tuning.VIEW_H - 100.0
	var first := _spawn_star("giant", Vector2(Tuning.VIEW_W / 2.0, start_y), 1.0)
	top_star = {"type": "giant", "pos": first.global_position}
	player = Player.new()
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
	if player == null:
		return
	_handle_capture()
	_handle_asteroid_hit()
	_stream_spawn()
	_update_camera(delta)
	_check_fall_death()
	GameState.update_rise(_height())
	hud.set_altitude(Scoring.height_score(_height()))
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
	var view_top := cam.position.y - Tuning.VIEW_H / 2.0
	while (top_star.pos as Vector2).y > view_top - 200.0:
		var h: float = start_y - (top_star.pos as Vector2).y
		var next := Spawner.next_star(top_star, h, rng)
		var p := Spawner.params_for_height(h)
		_spawn_star(next.type, next.pos, p.collapse_mult)
		if rng.randf() < p.asteroid_p:
			var ast := Asteroid.new()
			asteroids_root.add_child(ast)
			ast.add_to_group("asteroids")
			ast.setup((next.pos as Vector2).y + 45.0, rng)
		top_star = next
	var view_bottom := cam.position.y + Tuning.VIEW_H / 2.0
	for s in stars_root.get_children():
		if (s as Node2D).global_position.y > view_bottom + 100.0:
			s.queue_free()
	for a in asteroids_root.get_children():
		if (a as Node2D).global_position.y > view_bottom + 100.0:
			a.queue_free()

func _update_camera(delta: float) -> void:
	cam_target_y = minf(cam_target_y, player.global_position.y + Tuning.CAM_LEAD)
	cam.position.y = lerpf(cam.position.y, cam_target_y, minf(6.0 * delta, 1.0))

func _check_fall_death() -> void:
	if player.state == Player.State.FLYING and player.global_position.y > cam.position.y + Tuning.VIEW_H / 2.0 + Tuning.KILL_MARGIN:
		player.die()

func _on_star_collapsed(s: Star) -> void:
	if player and player.star == s:
		player.die()

func _on_player_died() -> void:
	GameState.end_run()   # 게임오버 연출·오버레이는 Task 11

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drift") and GameState.phase == GameState.Phase.PLAYING:
		player.launch()
