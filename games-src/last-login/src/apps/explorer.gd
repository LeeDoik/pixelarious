class_name Explorer
extends Control
## 파일 탐색기: 도구모음(뒤로·위로·보기) + 주소줄 + 파일 목록 + 상태표시줄.
## 문서는 메모장 창, 사진은 사진 뷰어 창으로 열린다. 잠긴 폴더는 영숫자 암호 대화상자.

enum ViewMode { ICONS, DETAILS }

const ICON := {
	"folder": "res://assets/img/icons/folder.png",
	"folder_locked": "res://assets/img/icons/folder_locked.png",
	"doc": "res://assets/img/icons/doc.png",
	"photo": "res://assets/img/icons/photo.png",
	"back": "res://assets/img/icons/nav_back.png",
	"up": "res://assets/img/icons/nav_up.png",
	"view_icons": "res://assets/img/icons/view_icons.png",
	"view_details": "res://assets/img/icons/view_details.png",
}
const ROOT_ID := "root"
const ROOT_LABEL := "내 컴퓨터"
const DRIVE := "C:"
const GRID_COLUMN_W := 148.0

## 보기 드롭다운 항목 id. 2번은 구분선이라 비어 있다.
const MENU_ICONS := 0
const MENU_DETAILS := 1
const MENU_HIDDEN := 3

var _cwd := "mydocs"
var _selected := ""          # 보기를 바꿔도 유지할 선택
var _pending_locked := ""      # 암호 대기 중인 폴더 id
var _history: Array[String] = []
var _view_mode := ViewMode.ICONS

var _list: ItemList
var _tree: Tree
var _addr: Label
var _addr_icon: TextureRect
var _status_left: Label
var _status_right: Label
var _back_btn: Button
var _up_btn: Button
var _view_btn: MenuButton
var _dialog: OSDialog
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	col.add_child(_build_address_bar())
	col.add_child(_build_list())
	col.add_child(_build_tree())
	col.add_child(_build_status_bar())
	_dialog = OSDialog.new()
	add_child(_dialog)
	_dialog.submitted.connect(submit_password)
	_dialog.closed.connect(func(): _pending_locked = "")
	set_view_mode(ViewMode.ICONS)
	_refresh()

# ── 구성 ──────────────────────────────────────────────────────────────────

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_back_btn = _tool_button("뒤로", ICON["back"], _go_back)
	_up_btn = _tool_button("위로", ICON["up"], _go_up)
	row.add_child(_back_btn)
	row.add_child(_up_btn)
	row.add_child(VSeparator.new())
	_view_btn = MenuButton.new()
	_view_btn.theme_type_variation = "NuriFlat"
	_view_btn.text = "보기"
	_view_btn.focus_mode = Control.FOCUS_NONE
	_view_btn.add_theme_font_size_override("font_size", 14)
	var vtex := _texture(ICON["view_details"])
	if vtex != null:
		_view_btn.icon = vtex
	var menu := _view_btn.get_popup()
	menu.add_theme_font_size_override("font_size", 14)
	menu.add_radio_check_item("큰 아이콘", MENU_ICONS)
	menu.add_radio_check_item("자세히", MENU_DETAILS)
	menu.add_separator()
	menu.add_check_item("숨긴 파일 보기", MENU_HIDDEN)
	menu.id_pressed.connect(select_view_menu)
	menu.about_to_popup.connect(sync_view_menu)
	row.add_child(_view_btn)
	bar.add_child(row)
	return bar

func _tool_button(label: String, icon_path: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "NuriFlat"
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	var tex := _texture(icon_path)
	if tex != null:
		b.icon = tex
	b.pressed.connect(cb)
	return b

func _build_address_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "주소"
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	_addr_icon = TextureRect.new()
	_addr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_addr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_addr_icon.custom_minimum_size = Vector2(16, 16)
	_addr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(_addr_icon)
	_addr = Label.new()
	_addr.add_theme_font_size_override("font_size", 14)
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_addr)
	field.add_child(inner)
	row.add_child(field)
	bar.add_child(row)
	return bar

func _build_list() -> Control:
	_list = ItemList.new()
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.fixed_icon_size = Vector2i(32, 32)
	_list.fixed_column_width = int(GRID_COLUMN_W)
	_list.same_column_width = true
	_list.max_columns = 1
	# XP 아이콘 보기처럼 긴 이름은 두 줄로 접고, 그래도 넘치면 말줄임
	_list.max_text_lines = 2
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_activated.connect(_on_activated)
	_list.item_selected.connect(_on_selected)
	_list.resized.connect(_relayout_grid)
	return _list

func _build_tree() -> Control:
	_tree = Tree.new()
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_reselect = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.add_theme_font_size_override("font_size", 14)
	_tree.add_theme_font_size_override("title_button_font_size", 14)
	var titles := ["이름", "크기", "종류", "수정한 날짜"]
	var widths := [210, 76, 120, 188]
	for c in 4:
		_tree.set_column_title(c, titles[c])
		_tree.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_tree.set_column_expand(c, c == 0)
		_tree.set_column_custom_minimum_width(c, widths[c])
	_tree.set_column_clip_content(0, true)
	_tree.item_activated.connect(_on_tree_activated)
	_tree.item_selected.connect(_on_tree_selected)
	return _tree

func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriStatusBar"
	var row := HBoxContainer.new()
	_status_left = Label.new()
	_status_left.add_theme_font_size_override("font_size", 14)
	_status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_right = Label.new()
	_status_right.add_theme_font_size_override("font_size", 14)
	_status_right.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_status_left)
	row.add_child(_status_right)
	bar.add_child(row)
	return bar

# ── 보기 전환 ─────────────────────────────────────────────────────────────

func view_menu() -> PopupMenu:
	return _view_btn.get_popup()

func select_view_menu(id: int) -> void:
	match id:
		MENU_ICONS:
			set_view_mode(ViewMode.ICONS)
		MENU_DETAILS:
			set_view_mode(ViewMode.DETAILS)
		MENU_HIDDEN:
			if GameState.has_flag("view_hidden"):
				GameState.clear_flag("view_hidden")
			else:
				GameState.set_flag("view_hidden")
			_refresh()
	sync_view_menu()

func sync_view_menu() -> void:
	var m := view_menu()
	m.set_item_checked(m.get_item_index(MENU_ICONS), _view_mode == ViewMode.ICONS)
	m.set_item_checked(m.get_item_index(MENU_DETAILS), _view_mode == ViewMode.DETAILS)
	m.set_item_checked(m.get_item_index(MENU_HIDDEN), GameState.has_flag("view_hidden"))

func set_view_mode(mode: ViewMode) -> void:
	_view_mode = mode
	var icons := mode == ViewMode.ICONS
	_list.visible = icons
	_tree.visible = not icons
	sync_view_menu()
	if icons:
		_relayout_grid()
	_apply_selection()

func _apply_selection() -> void:
	## 아이콘 ↔ 자세히를 오갈 때 고른 파일이 풀리면, 상태표시줄에는 이름이 남아 있는데
	## 목록에는 아무것도 안 눌린 창이 된다 (휴지통도 같은 규칙을 쓴다)
	if _selected == "":
		return
	if _view_mode == ViewMode.ICONS:
		for i in _list.item_count:
			if String(_list.get_item_metadata(i)) == _selected:
				_list.select(i)
				_list.ensure_current_is_visible()
				return
		return
	var row := _tree.get_root()
	row = row.get_first_child() if row != null else null
	while row != null:
		if String(row.get_metadata(0)) == _selected:
			row.select(0)
			_tree.scroll_to_item(row)
			return
		row = row.get_next()

func selected_id() -> String:
	return _selected

func view_mode() -> ViewMode:
	return _view_mode

func _relayout_grid() -> void:
	# ItemList는 폭에 맞춰 열 수를 스스로 줄이지 않는다 — 직접 계산해 넘긴다
	if not is_instance_valid(_list):
		return
	var usable := _list.size.x - 32.0
	_list.max_columns = maxi(1, int(usable / GRID_COLUMN_W))

# ── 탐색 ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var entries := ContentDB.fs_children(_cwd)
	_fill_grid(entries)
	_fill_details(entries)
	_selected = ""
	_addr.text = path_text(_cwd)
	var here := ContentDB.fs_node(_cwd)
	_addr_icon.texture = _texture(ICON["folder"] if here.is_empty() else _icon_path(here))
	_back_btn.disabled = _history.is_empty()
	_up_btn.disabled = _cwd == ROOT_ID
	# 목록은 보이는 것만, 상태표시줄은 폴더에 있는 것 전부를 센다.
	# 두 숫자가 어긋나는 순간이 '성진이만' 폴더에 딱 한 번 있다.
	_status_left.text = "개체 %d개" % ContentDB.fs_children_all(_cwd).size()
	_status_right.text = _folder_size_text(entries)

func _fill_grid(entries: Array[Dictionary]) -> void:
	_list.clear()
	for n in entries:
		var item_name := String(n["name"])
		var i := _list.add_item(item_name, _texture(_icon_path(n)))
		_list.set_item_metadata(i, n["id"])
		_list.set_item_tooltip(i, item_name)
	_relayout_grid()

func _fill_details(entries: Array[Dictionary]) -> void:
	_tree.clear()
	var root := _tree.create_item()
	for n in entries:
		var row := _tree.create_item(root)
		row.set_icon(0, _texture(_icon_path(n)))
		row.set_icon_max_width(0, 16)
		row.set_text(0, String(n["name"]))
		row.set_text(1, size_text(n))
		row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		row.set_text(2, type_label(n))
		row.set_text(3, format_mtime(String(n.get("mtime", ""))))
		row.set_metadata(0, n["id"])

static func path_text(id: String) -> String:
	if id == ROOT_ID:
		return ROOT_LABEL
	var parts: PackedStringArray = []
	var cur := id
	var guard := 0
	while cur != ROOT_ID and cur != "" and guard < 16:
		var n := ContentDB.fs_node(cur)
		if n.is_empty():
			break
		parts.insert(0, String(n["name"]))
		cur = String(n.get("parent", ROOT_ID))
		guard += 1
	return DRIVE + "\\" + "\\".join(parts)

func address_text() -> String:
	return _addr.text

func status_text() -> String:
	return _status_left.text

func item_count() -> int:
	return _list.item_count

func detail_row_count() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root != null else 0

func can_go_back() -> bool:
	return not _history.is_empty()

func cwd() -> String:
	return _cwd

func _go_back() -> void:
	if _history.is_empty():
		return
	_clear_pending_lock()
	_cwd = _history.pop_back()
	_refresh()

func _go_up() -> void:
	if _cwd == ROOT_ID:
		return
	_navigate(String(ContentDB.fs_node(_cwd).get("parent", ROOT_ID)))

func _navigate(id: String) -> void:
	if id == _cwd:
		return
	_history.append(_cwd)
	_clear_pending_lock()
	_cwd = id
	_refresh()

func _on_activated(index: int) -> void:
	_activate(String(_list.get_item_metadata(index)))

func _on_tree_activated() -> void:
	var row := _tree.get_selected()
	if row != null:
		_activate(String(row.get_metadata(0)))

func _activate(id: String) -> void:
	var n := ContentDB.fs_node(id)
	if n.is_empty():
		return
	if n["type"] == "folder":
		open_folder(id)
	else:
		open_file(id)

func _on_selected(index: int) -> void:
	_show_selection(String(_list.get_item_metadata(index)))

func _on_tree_selected() -> void:
	var row := _tree.get_selected()
	if row != null:
		_show_selection(String(row.get_metadata(0)))

func _show_selection(id: String) -> void:
	var n := ContentDB.fs_node(id)
	if n.is_empty():
		return
	_selected = id
	_status_left.text = "%s — %s" % [String(n["name"]), type_label(n)]
	_status_right.text = "" if n["type"] == "folder" else size_text(n)

# ── 열기 ──────────────────────────────────────────────────────────────────

func open_folder(id: String) -> bool:
	var n := ContentDB.fs_node(id)
	var lock: String = n.get("locked_by", "")
	if lock != "" and not GameState.has_flag(lock + "_solved"):
		_pending_locked = id
		_ask_password(String(n.get("name", "")))
		return false
	_dialog.close()
	_navigate(id)
	return true

func open_file(node_id: String) -> void:
	_clear_pending_lock()
	var n := ContentDB.fs_node(node_id)
	if n.is_empty():
		return
	if n.get("corrupt", false):
		_show_message("파일을 열 수 없습니다", "파일이 손상되어 열 수 없습니다.")
		return
	var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
	if n["type"] == "image":
		# 사진은 실제 OS처럼 별도 뷰어 창으로 연다
		if wm != null:
			wm.open_window("photo:" + node_id, String(n["name"]), _photo_view(String(n["image"])),
				Vector2(560, 470), ICON["photo"])
	elif wm != null:
		# 문서도 마찬가지 — 메모장 창이 열려야 여러 기록을 나란히 놓고 볼 수 있다
		var pad := Notepad.new()
		pad.body_text = String(ContentDB.doc(String(n["cid"])).get("body", ""))
		wm.open_window("doc:" + node_id, String(n["name"]), pad, Vector2(560, 470), ICON["doc"])
	if n.has("cid"):
		GameState.mark_read(String(n["cid"]))
	if node_id == "l_bowl":
		# 보기 설정을 켠 것만으로는 안 된다 — 이 게임의 판정은 언제나 "읽었는가"다
		GameState.set_flag("bowl_record_found")

func _photo_view(path: String) -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = "NuriField"
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.add_child(tr)
	return frame

# ── 암호 대화상자 ─────────────────────────────────────────────────────────

func _ask_password(folder_name: String) -> void:
	_dialog.ask_password("암호 입력", "'%s' 폴더는 암호로 보호되어 있습니다." % folder_name, ICON["folder_locked"])

func _show_message(title: String, body: String) -> void:
	_dialog.show_message(title, body, ICON["doc"])

func last_message() -> String:
	return _dialog.last_message() if is_instance_valid(_dialog) else ""

func submit_password(text: String) -> bool:
	if _pending_locked == "":
		return false
	var lock := String(ContentDB.fs_node(_pending_locked).get("locked_by", ""))
	if GameState.try_answer(lock, text):
		AudioDirector.play_sfx("unlock")
		var target := _pending_locked
		_pending_locked = ""
		_dialog.close()
		return open_folder(target)
	_dialog.show_error("비밀번호가 올바르지 않습니다.")
	return false

func _clear_pending_lock() -> void:
	_pending_locked = ""
	if is_instance_valid(_dialog):
		_dialog.close()

# ── 표시 규칙 ─────────────────────────────────────────────────────────────

static func type_label(node: Dictionary) -> String:
	if node.get("type", "") == "folder":
		return "파일 폴더"
	match String(node.get("name", "")).get_extension().to_lower():
		"txt":
			return "텍스트 문서"
		"jpg", "jpeg":
			return "JPEG 이미지"
		"dat":
			return "DAT 파일"
		_:
			return "파일"

static func size_text(node: Dictionary) -> String:
	if node.get("type", "") == "folder":
		return ""
	return format_size(int(node.get("size", 0)))

static func format_size(bytes: int) -> String:
	if bytes <= 0:
		return "0KB"
	var kb := int(ceil(bytes / 1024.0))
	if kb < 1024:
		return _grouped(kb) + "KB"
	return "%.1fMB" % (kb / 1024.0)

static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

static func format_mtime(raw: String) -> String:
	# "2002-11-02 03:52" → "2002-11-02 오전 3:52" (2002년 한국어 OS 표기)
	var parts := raw.split(" ")
	if parts.size() != 2:
		return raw
	var hm := parts[1].split(":")
	if hm.size() != 2:
		return raw
	var h := int(hm[0])
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%s %s %d:%s" % [parts[0], "오전" if h < 12 else "오후", h12, hm[1]]

func _icon_path(node: Dictionary) -> String:
	match String(node.get("type", "")):
		"folder":
			var lock: String = node.get("locked_by", "")
			if lock != "" and not GameState.has_flag(lock + "_solved"):
				return ICON["folder_locked"]
			return ICON["folder"]
		"image":
			return ICON["photo"]
		_:
			return ICON["doc"]

func _folder_size_text(entries: Array[Dictionary]) -> String:
	var total := 0
	for n in entries:
		total += int(n.get("size", 0))
	return "" if total == 0 else format_size(total)

func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = tex
	return tex
