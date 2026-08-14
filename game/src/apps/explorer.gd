class_name Explorer
extends Control
## 파일 탐색기: 좌측 트리(리스트), 우측 뷰어. 잠긴 폴더는 영숫자 비번 입력.

var _cwd := "mydocs"
var _pending_locked := ""   # 비번 대기 중인 폴더 id
var _list: ItemList
var _viewer: RichTextLabel
var _pw_row: HBoxContainer
var _pw_edit: LineEdit

func _ready() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(220, 0)
	_list.item_activated.connect(_on_activate)
	split.add_child(_list)
	var right := VBoxContainer.new()
	_viewer = RichTextLabel.new()
	_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer.bbcode_enabled = false
	right.add_child(_viewer)
	_pw_row = HBoxContainer.new()
	_pw_row.visible = false
	_pw_edit = LineEdit.new()
	_pw_edit.max_length = 24
	_pw_edit.placeholder_text = "비밀번호 (영문/숫자)"
	_pw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pw_edit.text_changed.connect(func(t: String):
		var filtered := ""
		for ch in t:
			if ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789":
				filtered += ch
		if filtered != t:
			_pw_edit.text = filtered
			_pw_edit.caret_column = filtered.length())
	var ok := Button.new()
	ok.text = "확인"
	ok.pressed.connect(func(): submit_password(_pw_edit.text))
	_pw_row.add_child(_pw_edit)
	_pw_row.add_child(ok)
	right.add_child(_pw_row)
	split.add_child(right)
	add_child(split)
	_refresh()

func _refresh() -> void:
	_list.clear()
	if _cwd != "root":
		_list.add_item("[..]")
		_list.set_item_metadata(0, "..")
	for n in ContentDB.fs_children(_cwd):
		var name: String = n["name"]
		if n["type"] == "folder":
			name = "[" + name + "]"
			if n.has("locked_by") and not GameState.has_flag(String(n["locked_by"]) + "_solved"):
				name += " *잠김*"
		var i := _list.add_item(name)
		_list.set_item_metadata(i, n["id"])

func _on_activate(i: int) -> void:
	var id: String = _list.get_item_metadata(i)
	if id == "..":
		_clear_pending_lock()
		_cwd = ContentDB.fs_node(_cwd).get("parent", "root")
		_refresh()
		return
	var n := ContentDB.fs_node(id)
	if n["type"] == "folder":
		open_folder(id)
	else:
		open_file(id)

func open_folder(id: String) -> bool:
	var n := ContentDB.fs_node(id)
	var lock: String = n.get("locked_by", "")
	if lock != "" and not GameState.has_flag(lock + "_solved"):
		_pending_locked = id
		_pw_row.visible = true
		_viewer.text = "이 폴더는 비밀번호로 보호되어 있습니다."
		return false
	_cwd = id
	_pw_row.visible = false
	_refresh()
	return true

func submit_password(text: String) -> bool:
	if _pending_locked == "":
		return false
	var lock := String(ContentDB.fs_node(_pending_locked).get("locked_by", ""))
	if GameState.try_answer(lock, text):
		_pw_row.visible = false
		AudioDirector.play_sfx("unlock")
		var target := _pending_locked
		_pending_locked = ""
		return open_folder(target)
	_viewer.text = "비밀번호가 올바르지 않습니다."
	return false

func _clear_pending_lock() -> void:
	_pending_locked = ""
	_pw_row.visible = false

func open_file(node_id: String) -> void:
	_clear_pending_lock()
	var n := ContentDB.fs_node(node_id)
	if n.get("corrupt", false):
		_viewer.text = "파일이 손상되어 열 수 없습니다."
		return
	if n["type"] == "image":
		# 사진은 실제 OS처럼 별도 뷰어 창으로 연다
		_viewer.text = "[사진] %s — 새 창에서 열림" % n["name"]
		var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
		if wm != null:
			var tr := TextureRect.new()
			tr.texture = load(n["image"])
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			wm.open_window("photo:" + node_id, n["name"], tr, Vector2(560, 470))
	else:
		var d := ContentDB.doc(n["cid"])
		_viewer.text = String(d["title"]) + "\n\n" + String(d["body"])
	if n.has("cid"):
		GameState.mark_read(n["cid"])
