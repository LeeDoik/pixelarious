extends GdUnitTestSuite

const BOOT := preload("res://src/boot/boot.gd")

func test_post_lines_exist_and_korean_bios_flavor() -> void:
	var b: Node = auto_free(BOOT.new())
	var lines: Array = b.post_lines()
	assert_int(lines.size()).is_greater(4)
	assert_str(String(lines[0])).contains("HANBYUL")
