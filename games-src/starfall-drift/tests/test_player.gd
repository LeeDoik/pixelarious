extends GdUnitTestSuite

func _mk_star(t: String, pos: Vector2) -> Star:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup(t, 1.0)
	s.global_position = pos
	return s

func _mk_player() -> Player:
	var p: Player = auto_free(Player.new())
	add_child(p)
	return p

func test_attach_snaps_to_ring_and_sets_dir() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	# 오른쪽에서 아래로 향하는 진입 → dir +1
	p.attach_to(s, Vector2(130, 100), Vector2(0, 50))
	assert_int(p.state).is_equal(Player.State.ORBITING)
	assert_bool(s.occupied).is_true()
	assert_float(p.global_position.distance_to(s.global_position)).is_equal_approx(28.0, 0.01)
	assert_int(p.dir).is_equal(1)

func test_orbiting_follows_ring() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	p.tick(0.25)
	assert_float(p.global_position.distance_to(s.global_position)).is_equal_approx(28.0, 0.01)

func test_launch_releases_star_and_flies() -> void:
	GameState.start_run()
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	p.launch()
	assert_int(p.state).is_equal(Player.State.FLYING)
	assert_bool(s.occupied).is_false()
	assert_bool(p.vel.length() > 0.0).is_true()
	assert_int(GameState.combo).is_equal(2)   # 게이지 0% 스위프트

func test_flight_gravity_pulls_down() -> void:
	var p := _mk_player()
	p.state = Player.State.FLYING
	p.global_position = Vector2(135, 200)
	p.vel = Vector2(0, -100)
	p.tick(0.1)
	assert_bool(p.vel.y > -100.0).is_true()

func test_dwarf_capture_pays_bonus() -> void:
	GameState.start_run()
	var s := _mk_star("dwarf", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(116, 100), Vector2(0, 50))
	assert_int(GameState.score()).is_equal(50)

func test_die_is_idempotent_and_frees_star() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	var count: Array = []
	p.died.connect(func(): count.append(1))
	p.die()
	p.die()
	assert_int(count.size()).is_equal(1)
	assert_bool(s.occupied).is_false()
