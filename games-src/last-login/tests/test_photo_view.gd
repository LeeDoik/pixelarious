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
