extends GdUnitTestSuite
## Task 11 통합 테스트: 타이틀 탭 → PLAYING, 강제 낙사 → GAME_OVER. 씬 러너로 헤드리스 구동.

func after_test() -> void:
	# 이 테스트 러너 창은 OS 포커스가 없어 실행 중 NOTIFICATION_APPLICATION_FOCUS_OUT이 발생할 수 있고,
	# main.gd의 포커스아웃 일시정지가 SceneTree.paused를 true로 남긴 채 테스트가 끝날 수 있다.
	# 이후 스위트에 새는 것을 막기 위해 각 테스트 뒤 명시적으로 해제.
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
