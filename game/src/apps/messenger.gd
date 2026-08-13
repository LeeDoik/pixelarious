class_name Messenger
extends Control
## 단짝: 대화 탭(스크립트 재생 + 선택지) / 지난 대화 탭. 힌트는 슬기 말풍선으로.

var _cp: ChatPlayer
var _hints: HintEngine
var _chat_box: VBoxContainer
var _choice_box: HBoxContainer
var _scroll: ScrollContainer
var _logs_marked := false

func _ready() -> void:
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 대화 탭
	var live := VBoxContainer.new()
	live.name = "대화"
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_chat_box)
	live.add_child(_scroll)
	_choice_box = HBoxContainer.new()
	live.add_child(_choice_box)
	tabs.add_child(live)
	# 지난 대화 탭
	var logs := RichTextLabel.new()
	logs.name = "지난 대화"
	for lg in ContentDB.chat_logs():
		logs.append_text("[%s] %s\n" % [lg["date"], lg["with"]])
		for line in lg["lines"]:
			logs.append_text("  %s: %s\n" % [line["from"], line["text"]])
	tabs.add_child(logs)
	add_child(tabs)
	tabs.tab_changed.connect(func(idx: int):
		if tabs.get_tab_control(idx) == logs and not _logs_marked:
			_logs_marked = true
			for lg2 in ContentDB.chat_logs():
				GameState.mark_read("chatlog:" + String(lg2["date"])))
	# 스크립트 재생
	_cp = ChatPlayer.new(ContentDB.chat_thread(), GameState)
	_hints = HintEngine.new(func() -> int: return Time.get_ticks_msec())
	_hints.hint_ready.connect(_on_hint)
	GameState.flag_changed.connect(func(_n):
		_hints.set_gate(_current_gate())
		call_deferred("_try_continue"))
	_hints.set_gate(_current_gate())
	_show_current()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_hints.poll)
	add_child(timer)

func _current_gate() -> String:
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		if not GameState.has_flag(pid + "_solved"):
			return pid
	return ""

func _bubble(from: String, text: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = ("슬기: " if from == "seulgi" else ("나: " if from == "player" else "")) + text
	_chat_box.add_child(l)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _show_current() -> void:
	var n := _cp.current()
	if n["from"] != "sys":
		AudioDirector.play_sfx("msg")
		_bubble(n["from"], n["text"])
	for c in _choice_box.get_children():
		c.queue_free()
	if n.has("choices"):
		for i in n["choices"].size():
			var b := Button.new()
			b.text = n["choices"][i]["text"]
			b.pressed.connect(_on_choice.bind(i))
			_choice_box.add_child(b)
	elif n.has("next"):
		get_tree().create_timer(n.get("delay_ms", 900) / 1000.0).timeout.connect(_try_continue)

func _on_choice(i: int) -> void:
	_bubble("player", _cp.current()["choices"][i]["text"])
	_cp.choose(i)
	_show_current()

func _try_continue() -> void:
	if _cp.advance():
		_show_current()

func _on_hint(puzzle_id: String, level: int) -> void:
	var hints: Array = ContentDB.puzzle(puzzle_id).get("hints", [])
	if level - 1 < hints.size():
		AudioDirector.play_sfx("msg")
		_bubble("seulgi", hints[level - 1])
