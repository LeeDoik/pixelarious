extends GdUnitTestSuite

const PhotoViewScript := preload("res://src/apps/photo_view.gd")

func test_uv_at_maps_click_to_normalized_coords() -> void:
	var uv: Vector2 = PhotoViewScript.uv_at(Vector2(100, 200), Vector2(200, 400), 1.0)
	assert_float(uv.x).is_equal_approx(0.5, 0.001)
	assert_float(uv.y).is_equal_approx(0.5, 0.001)

func test_uv_at_accounts_for_zoom() -> void:
	var uv: Vector2 = PhotoViewScript.uv_at(Vector2(200, 400), Vector2(200, 400), 2.0)
	assert_float(uv.x).is_equal_approx(0.5, 0.001)
	assert_float(uv.y).is_equal_approx(0.5, 0.001)

func test_uv_at_returns_sentinel_outside_the_image() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2(-1, 10), Vector2(200, 400), 1.0)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 500), Vector2(200, 400), 1.0)).is_equal(Vector2(-1, -1))

func test_uv_at_guards_against_zero_texture() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 10), Vector2.ZERO, 1.0)).is_equal(Vector2(-1, -1))

func test_toggle_zoom_cycles_between_fit_and_double() -> void:
	var v: Control = auto_free(PhotoViewScript.new())
	v.image_path = "res://assets/img/photos/bomi_2002.png"
	add_child(v)
	assert_float(v.zoom()).is_equal_approx(1.0, 0.001)
	v.toggle_zoom()
	assert_float(v.zoom()).is_equal_approx(2.0, 0.001)
	v.toggle_zoom()
	assert_float(v.zoom()).is_equal_approx(1.0, 0.001)

func test_uv_at_guards_against_nonpositive_zoom() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 10), Vector2(200, 400), 0.0)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 10), Vector2(200, 400), -1.0)).is_equal(Vector2(-1, -1))

func test_uv_at_top_left_corner_is_in_bounds() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2.ZERO, Vector2(200, 400), 1.0)).is_equal(Vector2(0, 0))

func test_uv_at_bottom_right_corner_is_inclusive_by_design() -> void:
	# 경계는 의도적으로 닫힌 구간이다(>1.0만 밖으로 친다) — 반열린 구간으로 "고치지" 말 것.
	var tex_size := Vector2(200, 400)
	var zoom := 1.0
	assert_vector(PhotoViewScript.uv_at(tex_size * zoom, tex_size, zoom)).is_equal(Vector2(1, 1))

func test_uv_at_returns_sentinel_one_unit_past_each_edge() -> void:
	var tex_size := Vector2(200, 400)
	var zoom := 1.0
	assert_vector(PhotoViewScript.uv_at(Vector2(-1, 0), tex_size, zoom)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(Vector2(0, -1), tex_size, zoom)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(tex_size * zoom + Vector2(1, 0), tex_size, zoom)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(tex_size * zoom + Vector2(0, 1), tex_size, zoom)).is_equal(Vector2(-1, -1))

func test_region_clicked_does_not_emit_at_fit_zoom() -> void:
	var v: Control = auto_free(PhotoViewScript.new())
	v.image_path = "res://assets/img/photos/bomi_2002.png"
	add_child(v)
	var got: Array = []
	v.region_clicked.connect(func(uv: Vector2) -> void: got.append(uv))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(10, 10)
	v._on_image_input(mb)
	assert_array(got).is_empty()

func test_region_clicked_emits_with_expected_uv_at_2x_zoom() -> void:
	var v: Control = auto_free(PhotoViewScript.new())
	v.image_path = "res://assets/img/photos/bomi_2002.png"
	add_child(v)
	v.toggle_zoom()
	var got: Array = []
	v.region_clicked.connect(func(uv: Vector2) -> void: got.append(uv))
	var tex: Texture2D = load("res://assets/img/photos/bomi_2002.png")
	var tex_size: Vector2 = Vector2(tex.get_size())
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = tex_size
	v._on_image_input(mb)
	assert_array(got).has_size(1)
	var uv: Vector2 = got[0]
	assert_float(uv.x).is_equal_approx(0.5, 0.001)
	assert_float(uv.y).is_equal_approx(0.5, 0.001)
