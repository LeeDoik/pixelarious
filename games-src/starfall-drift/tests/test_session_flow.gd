extends GdUnitTestSuite
## Task 11 통합 테스트: 타이틀 탭 → PLAYING, 강제 낙사 → GAME_OVER. 씬 러너로 헤드리스 구동.

func before() -> void:
	# 러너 창은 OS 포커스가 없어 진짜 FOCUS_OUT이 수시로 도착한다. PLAYING 중이면 트리가
	# 일시정지돼 게이지·물리가 얼어붙는다. 테스트 "사이"의 틈(이전 씬이 아직 살아 있는
	# 티어다운 구간)에도 도착할 수 있으므로, 스위치는 테스트별이 아니라 스위트 전체에서 끈다.
	GameState.pause_on_focus_out = false

func after() -> void:
	GameState.pause_on_focus_out = true
	get_tree().paused = false

func before_test() -> void:
	# 이전 테스트 티어다운 틈에 새어든 일시정지 방어
	get_tree().paused = false

func after_test() -> void:
	get_tree().paused = false

func test_title_tap_starts_run_and_launches() -> void:
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(2)
	assert_int(GameState.phase).is_equal(GameState.Phase.TITLE)
	runner.simulate_action_pressed("drift")
	await runner.simulate_frames(2)
	assert_int(GameState.phase).is_equal(GameState.Phase.PLAYING)

func test_fall_death_reaches_game_over() -> void:
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(2)
	runner.simulate_action_pressed("drift")   # 시작 + 발사
	await runner.simulate_frames(2)
	var main = runner.scene()
	main.player.global_position.y = main.cam.position.y + 2000.0
	main.player.vel = Vector2.ZERO
	main.player.state = Player.State.FLYING
	# 사망 슬로모(DEATH_SLOWMO_SEC = 실시간 0.5s, ignore_time_scale)가 흐른 뒤 game-over 오버레이가 뜬다.
	# NOTE: await_millis()는 gdUnit4가 내부적으로 일반 Timer 노드를 사용하는데, 이 테스트 러너 창은
	# OS 포커스가 없어 헤드리스 구동 중 NOTIFICATION_APPLICATION_FOCUS_OUT이 발생하고, main.gd의
	# 포커스아웃 일시정지 기능이 트리를 paused=true로 만들면 그 Timer 노드도 함께 멈춰 영원히 hang된다.
	# 반면 simulate_frames()는 SceneTree.process_frame 신호를 기다리는데, 이 신호는 트리 일시정지와
	# 무관하게 매 프레임 발생하므로 안전하다. phase는 end_run()에서 동기적으로 GAME_OVER가 되므로
	# 슬로모 타이머 완료를 기다릴 필요는 없다 (오버레이 표시는 타이머 이후).
	await runner.simulate_frames(60)
	assert_int(GameState.phase).is_equal(GameState.Phase.GAME_OVER)

func test_raw_touch_tap_starts_run() -> void:
	# 모바일 웹: 마우스 에뮬레이션 없이 InputEventScreenTouch가 직접 drift로 동작해야 한다
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(2)
	assert_int(GameState.phase).is_equal(GameState.Phase.TITLE)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(135, 240)
	Input.parse_input_event(touch)
	await runner.simulate_frames(2)
	assert_int(GameState.phase).is_equal(GameState.Phase.PLAYING)
	# 전역 Input 상태 오염 방지 — 릴리스 없이 끝내면 다음 테스트로 눌림 상태가 샌다
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = touch.position
	Input.parse_input_event(release)
	await runner.simulate_frames(1)

func test_collapse_drops_player_and_run_continues() -> void:
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(2)
	runner.simulate_action_pressed("drift")   # 타이틀 탭 = 시작 + 발사
	await runner.simulate_frames(2)
	var main = runner.scene()
	# 비행 여부와 무관하게 확실한 공전 상태를 만든 뒤, 그 별을 강제 붕괴 직전까지 보낸다
	var star: Star = main.stars_root.get_children()[0]
	main.player.attach_to(star, star.global_position + Vector2(star.orbit_r, 0), Vector2(0, 10))
	star.gauge = star.collapse_time - 0.001
	await runner.simulate_frames(5)
	assert_int(main.player.state).is_equal(Player.State.FLYING)   # 죽지 않고 낙하
	assert_int(GameState.phase).is_equal(GameState.Phase.PLAYING)

func test_orbiting_below_kill_line_also_dies() -> void:
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(2)
	runner.simulate_action_pressed("drift")
	await runner.simulate_frames(2)
	var main = runner.scene()
	# 화면 아래 먼 곳의 별에 잡힌 상태를 만든다 — 공전 중이어도 킬라인 아래면 죽어야 한다
	var below: Star = main._spawn_star("standard", Vector2(135.0, main.cam.position.y + 2000.0), 1.0)
	main.player.attach_to(below, below.global_position + Vector2(below.orbit_r, 0), Vector2(0, 10))
	await runner.simulate_frames(5)
	assert_int(GameState.phase).is_equal(GameState.Phase.GAME_OVER)

func test_quick_restart_skips_title_and_resets_combo() -> void:
	GameState.combo = 4
	GameState.quick_restart = true
	var runner := scene_runner("res://src/main.tscn")
	await runner.simulate_frames(3)
	assert_int(GameState.phase).is_equal(GameState.Phase.PLAYING)
	assert_bool(GameState.quick_restart).is_false()
	assert_int(GameState.combo).is_equal(1)
