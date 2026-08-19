extends GdUnitTestSuite
## 갱도 입력 배선 — 순수 함수(MoveRules.tap_dir) 밖의 연결부를 여기서 잡는다.
## STARFALL에서 모바일 터치가 죽었던 지점이 정확히 이 배선이었다.

var _mine: Mine

func before_test() -> void:
	_mine = Mine.new()
	add_child(_mine)

func after_test() -> void:
	# 갱도는 자식(HUD·라이트·뷰·디렉터)을 많이 달고 있다 — 즉시 해제해 고아 노드를 남기지 않는다
	if is_instance_valid(_mine):
		remove_child(_mine)
		_mine.free()

func _screen_of(tile: Vector2i) -> Vector2:
	# 실제 경로 그대로 — 카메라 변환을 거쳐 화면 좌표로 되돌린다
	return _mine.get_canvas_transform() * (Vector2(tile * 16) + Vector2(8, 8))

func test_touch_and_mouse_both_drive_the_same_step() -> void:
	var below := _screen_of(_mine.ppos + Vector2i(0, 1))

	_mine._pointer(below, true)
	assert_vector(_mine.held_dir).is_equal(Vector2i(0, 1))
	_mine._pointer(below, false)
	assert_vector(_mine.held_dir).is_equal(Vector2i.ZERO)

	# 같은 탭이 터치와 에뮬레이션 마우스로 두 번 들어와도 결과가 같아야 한다
	# (에뮬레이션을 켜둔 채 터치를 직접 받기 때문 — mine.gd 주석 참고)
	_mine._pointer(below, true)
	_mine._pointer(below, true)
	assert_vector(_mine.held_dir).is_equal(Vector2i(0, 1))
	_mine._pointer(below, false)
	_mine._pointer(below, false)
	assert_vector(_mine.held_dir).is_equal(Vector2i.ZERO)

func test_non_adjacent_tap_is_ignored() -> void:
	var far := _screen_of(_mine.ppos + Vector2i(0, 4))
	_mine._pointer(far, true)
	assert_vector(_mine.held_dir).is_equal(Vector2i.ZERO)

func test_hud_capacity_matches_what_collect_allows() -> void:
	# 기름병은 가방 칸을 먹는다 — HUD가 원래 슬롯 수를 보여주면 담기지도 않는 칸을 광고하게 된다
	GameState.run.bottles = 2
	var slots := Economy.bag_slots(GameState.profile.upgrades.bag)
	assert_int(_mine.bag_capacity()).is_equal(slots - 2)
	GameState.run.bottles = 0
	assert_int(_mine.bag_capacity()).is_equal(slots)
