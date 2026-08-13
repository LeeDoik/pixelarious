extends GdUnitTestSuite

const MailApp := preload("res://src/apps/mail.gd")

func before_test() -> void:
	GameState.reset()

func test_open_mail_marks_read() -> void:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	m.open_mail("m1")
	assert_bool(GameState.is_read("mail:m1")).is_true()

func test_attachment_locked_until_puzzle2() -> void:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	m.open_mail("m1")
	assert_bool(m.open_attachment("m1")).is_false()
	assert_bool(m.submit_password("030703")).is_true()
	assert_bool(m.open_attachment("m1")).is_true()
	assert_bool(GameState.is_read("doc:doctrine_full")).is_true()
