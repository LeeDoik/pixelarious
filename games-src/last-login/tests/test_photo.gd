extends GdUnitTestSuite

## 사진 뷰어의 좌표 계산. 필사본 사진이 800픽셀을 넘어 "창에 맞춤"으로는 손글씨가 안 읽히고,
## 그 안에 퍼즐이 걸려 있다 — 확대가 어긋나면 게임이 막힌다.
## 텍스처는 헤드리스에서 못 읽으므로 크기를 직접 넘겨 계산만 검증한다.

const PhotoViewer := preload("res://src/apps/photo.gd")

const PILSA := Vector2(835, 827)     # assets/img/photos/pilsa_1.png
const VIEW := Vector2(560, 420)

func _make() -> Control:
	var v: Control = auto_free(PhotoViewer.new())
	v.image_path = "res://assets/img/photos/pilsa_1.png"
	add_child(v)
	return v

func test_fit_shrinks_a_big_photo_and_grows_a_small_one() -> void:
	# 짧은 쪽이 아니라 더 빡빡한 쪽에 맞춰야 사진 전체가 들어간다
	var z := PhotoViewer.fit_zoom(PILSA, VIEW)
	assert_float(z).is_equal_approx(VIEW.y / PILSA.y, 0.001)
	assert_float(PILSA.x * z).is_less_equal(VIEW.x + 0.5)
	assert_float(PILSA.y * z).is_less_equal(VIEW.y + 0.5)
	assert_float(PhotoViewer.fit_zoom(Vector2(100, 100), VIEW)).is_greater(1.0)

func test_fit_falls_back_to_one_to_one_before_the_window_has_a_size() -> void:
	# 창을 여는 첫 프레임에는 캔버스 크기가 0이다 — 0으로 나눠 NaN이 되면 사진이 사라진다
	assert_float(PhotoViewer.fit_zoom(PILSA, Vector2.ZERO)).is_equal(1.0)
	assert_float(PhotoViewer.fit_zoom(Vector2.ZERO, VIEW)).is_equal(1.0)

func test_wheel_zoom_keeps_the_point_under_the_pointer_still() -> void:
	# 이게 어긋나면 휠을 굴릴 때마다 읽던 글자가 화면 밖으로 달아난다
	var pos := Vector2(-120.0, -80.0)
	var pivot := Vector2(300.0, 210.0)
	var before := 0.8
	var after := before * PhotoViewer.ZOOM_STEP
	var pt_before := (pivot - pos) / before                       # 포인터 밑의 사진 좌표
	var moved := PhotoViewer.zoom_anchor(pos, pivot, after / before)
	var pt_after := (pivot - moved) / after
	assert_float(pt_after.x).is_equal_approx(pt_before.x, 0.01)
	assert_float(pt_after.y).is_equal_approx(pt_before.y, 0.01)

func test_a_photo_smaller_than_the_window_is_centred() -> void:
	var shown := Vector2(200, 100)
	var at := PhotoViewer.clamp_offset(Vector2(999, -999), shown, VIEW)
	assert_float(at.x).is_equal_approx((VIEW.x - shown.x) * 0.5, 0.001)
	assert_float(at.y).is_equal_approx((VIEW.y - shown.y) * 0.5, 0.001)

func test_a_zoomed_photo_cannot_be_dragged_past_its_edges() -> void:
	# 확대한 사진을 끌다 보면 빈 여백만 남기 쉽다 — 가장자리에서 멈춰야 한다
	var shown := PILSA * 2.0
	assert_float(PhotoViewer.clamp_offset(Vector2(80, 40), shown, VIEW).x).is_equal_approx(0.0, 0.001)
	assert_float(PhotoViewer.clamp_offset(Vector2(80, 40), shown, VIEW).y).is_equal_approx(0.0, 0.001)
	var far := PhotoViewer.clamp_offset(Vector2(-9999, -9999), shown, VIEW)
	assert_float(far.x).is_equal_approx(VIEW.x - shown.x, 0.001)
	assert_float(far.y).is_equal_approx(VIEW.y - shown.y, 0.001)

func test_dragging_within_range_is_left_alone() -> void:
	var shown := PILSA * 2.0
	var at := PhotoViewer.clamp_offset(Vector2(-300, -200), shown, VIEW)
	assert_float(at.x).is_equal_approx(-300.0, 0.001)
	assert_float(at.y).is_equal_approx(-200.0, 0.001)

func test_viewer_opens_fitted_and_reports_its_scale() -> void:
	var v := _make()
	assert_bool(v.is_fitted()).is_true()
	assert_int(v.zoom_percent()).is_equal(100)   # 창 크기가 아직 0 — 1:1로 시작한다

func test_zoom_is_clamped_at_both_ends() -> void:
	var v := _make()
	for i in 40:
		v.zoom_by(PhotoViewer.ZOOM_STEP)
	assert_float(v.zoom()).is_equal_approx(PhotoViewer.ZOOM_MAX, 0.001)
	for i in 80:
		v.zoom_by(1.0 / PhotoViewer.ZOOM_STEP)
	assert_float(v.zoom()).is_equal_approx(PhotoViewer.ZOOM_MIN, 0.001)

## 확대하고 나면 창 크기가 바뀌어도 그 배율을 지켜야 한다 (다시 맞춤으로 튀면 읽던 걸 놓친다)
func test_zooming_by_hand_turns_off_auto_fit_until_asked_again() -> void:
	var v := _make()
	v.zoom_by(PhotoViewer.ZOOM_STEP)
	assert_bool(v.is_fitted()).is_false()
	v.fit()
	assert_bool(v.is_fitted()).is_true()

func test_actual_size_is_exactly_one_to_one() -> void:
	var v := _make()
	v.zoom_by(PhotoViewer.ZOOM_STEP)
	v.actual_size()
	assert_int(v.zoom_percent()).is_equal(100)
