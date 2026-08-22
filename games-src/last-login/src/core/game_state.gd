extends Node
## 진행 상태의 단일 소스. 플래그·열람 기록·액트·퍼즐 판정·세이브.

signal flag_changed(name: String)
signal act_changed(act: int)
signal record_read(cid: String, total: int)

const SAVE_PATH := "user://save.json"

var puzzle_source: Callable = func(id: String) -> Dictionary:
	return ContentDB.puzzle(id)
var records_source: Callable = func() -> Array:
	return ContentDB.records()

var _flags: Dictionary = {}
var _read: Dictionary = {}  # cid -> true
var _restored: Dictionary = {}  # 휴지통에서 원래 자리로 되돌린 파일 id -> true

func set_flag(name: String) -> void:
	if _flags.has(name):
		return
	var before := current_act()
	_flags[name] = true
	flag_changed.emit(name)
	var after := current_act()
	if after != before:
		act_changed.emit(after)
	save_game()

func clear_flag(name: String) -> void:
	## 보기 설정처럼 껐다 켰다 하는 플래그가 있다. 막(act)은 다시 계산하지 않는다 —
	## 되돌릴 수 있는 설정이 이야기를 되감으면 안 된다.
	if not _flags.has(name):
		return
	_flags.erase(name)
	save_game()

func has_flag(name: String) -> bool:
	return _flags.has(name)

func current_act() -> int:
	if has_flag("puzzle3_solved"):
		return 3
	if has_flag("puzzle1_solved"):
		return 2
	return 1

func mark_read(cid: String) -> void:
	if _read.has(cid):
		return
	_read[cid] = true
	if cid in records_source.call():
		record_read.emit(cid, records_count())
	save_game()

func is_read(cid: String) -> bool:
	return _read.has(cid)

func records_count() -> int:
	var n := 0
	for cid in records_source.call():
		if _read.has(cid):
			n += 1
	return n

func restore_node(id: String) -> void:
	## 휴지통에서 꺼낸 파일. 어느 폴더에 있느냐는 콘텐츠가 아니라 진행 상태다 —
	## ContentDB는 여기 물어보고 부모를 정한다.
	if _restored.has(id):
		return
	_restored[id] = true
	save_game()

func is_restored(id: String) -> bool:
	return _restored.has(id)

func try_answer(puzzle_id: String, input: String) -> bool:
	var p: Dictionary = puzzle_source.call(puzzle_id)
	if p.is_empty():
		return false
	if input.strip_edges().to_lower() == String(p["answer"]).to_lower():
		set_flag(puzzle_id + "_solved")
		return true
	return false

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save_game: cannot open %s (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	var flags_to_save := _flags.duplicate()
	flags_to_save.erase("ending_start")
	f.store_string(JSON.stringify({"flags": flags_to_save, "read": _read, "restored": _restored}))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_flags = data.get("flags", {})
	_read = data.get("read", {})
	_restored = data.get("restored", {})
	_flags.erase("ending_start")
	act_changed.emit(current_act())
	return true

func reset() -> void:
	_flags = {}
	_read = {}
	_restored = {}
	act_changed.emit(current_act())
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
