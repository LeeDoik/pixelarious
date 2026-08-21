class_name TrashApp
extends Control
## 휴지통: 탐색기와 같은 껍데기(도구모음·주소줄·아이콘/자세히 보기·상태표시줄)에
## 휴지통 전용 열(원래 위치·삭제한 날짜)을 얹은 창. 그 시절 휴지통은 별도 프로그램이
## 아니라 탐색기 창이었다 — 두 창이 같은 OS로 보이려면 부품을 같이 써야 한다.
##
## 올바른 파일 복원 = 퍼즐4. 복원하면 파일은 휴지통을 떠나 원래 폴더로 간다
## (자리는 ContentDB.effective_parent가 GameState에 물어 정한다).

enum ViewMode { ICONS, DETAILS }

const ICON := {
	"doc": "res://assets/img/icons/doc.png",
	"bin": "res://assets/img/icons/trash_bin.png",
	"trash": "res://assets/img/icons/trash.png",
	"restore": "res://assets/img/icons/restore.png",
	"purge": "res://assets/img/icons/purge.png",
	"warn": "res://assets/img/icons/warn.png",
	"view_icons": "res://assets/img/icons/view_icons.png",
	"view_details": "res://assets/img/icons/view_details.png",
}
const TITLE := "휴지통"
const GRID_COLUMN_W := 148.0
const EMPTY_TEXT := "휴지통이 비어 있습니다."
const FAIL_AT := 0.62          # 손상된 파일에서 진행률이 멈추는 지점
const FAIL_HOLD := 0.45        # 멈춘 채로 버티는 시간 — 곧바로 오류창이 뜨면 안 읽힌다
const DOC_WIN_SIZE := Vector2(560, 470)
const PROGRESS_LIFT := 330     # 진행률 창을 가운데에서 위로 밀어 올리는 양
const PROGRESS_SHIFT := 56     # 왼쪽으로 비끼는 양

var restore_sec := 1.1         # 테스트에서 줄인다

var _view_mode := ViewMode.ICONS
var _selected := ""
var _busy := false

var _list: ItemList
var _tree: Tree
var _empty: Label
var _addr: Label
var _status_left: Label
var _status_right: Label
var _restore_btn: Button
var _purge_btn: Button
var _icons_btn: Button
var _details_btn: Button
var _dialog: OSDialog
var _progress: Control
var _bar: ProgressBar
var _progress_from: Label
var _progress_to: Label
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	col.add_child(_build_address_bar())
	col.add_child(_build_body())
	col.add_child(_build_status_bar())
	# 진행률 창이 먼저 붙어야 한다 — 뒤에 붙이면 실패했을 때 오류 대화상자를 덮어 가린다
	_progress = _build_progress()
	add_child(_progress)
	_dialog = OSDialog.new()
	add_child(_dialog)
	_dialog.confirmed.connect(purge)
	_dialog.closed.connect(_on_dialog_closed)
	set_view_mode(ViewMode.ICONS)
	_refresh()

# ── 구성 ──────────────────────────────────────────────────────────────────

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_restore_btn = _tool_button("복원", ICON["restore"], _restore_selected)
	_purge_btn = _tool_button("휴지통 비우기", ICON["purge"], ask_purge)
	row.add_child(_restore_btn)
	row.add_child(_purge_btn)
	row.add_child(VSeparator.new())
	_icons_btn = _tool_button("아이콘", ICON["view_icons"], set_view_mode.bind(ViewMode.ICONS))
	_details_btn = _tool_button("자세히", ICON["view_details"], set_view_mode.bind(ViewMode.DETAILS))
	_icons_btn.toggle_mode = true
	_details_btn.toggle_mode = true
	row.add_child(_icons_btn)
	row.add_child(_details_btn)
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
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _texture(ICON["bin"])
	inner.add_child(icon)
	_addr = Label.new()
	_addr.text = TITLE
	_addr.add_theme_font_size_override("font_size", 14)
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_addr)
	field.add_child(inner)
	row.add_child(field)
	bar.add_child(row)
	return bar

func _build_body() -> Control:
	# 목록 두 형태와 "비어 있습니다" 안내가 같은 자리를 겹쳐 쓴다
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	_list = ItemList.new()
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.fixed_icon_size = Vector2i(32, 32)
	_list.fixed_column_width = int(GRID_COLUMN_W)
	_list.same_column_width = true
	_list.max_columns = 1
	_list.max_text_lines = 2
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_activated)
	_list.resized.connect(_relayout_grid)
	body.add_child(_list)
	_tree = Tree.new()
	_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_reselect = true
	_tree.add_theme_font_size_override("font_size", 14)
	_tree.add_theme_font_size_override("title_button_font_size", 14)
	var titles := ["이름", "원래 위치", "삭제한 날짜", "크기"]
	var widths := [186, 178, 180, 76]
	for c in 4:
		_tree.set_column_title(c, titles[c])
		_tree.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_tree.set_column_expand(c, c == 0)
		_tree.set_column_custom_minimum_width(c, widths[c])
	_tree.set_column_clip_content(0, true)
	_tree.set_column_clip_content(1, true)
	_tree.item_selected.connect(_on_tree_selected)
	_tree.item_activated.connect(_on_tree_activated)
	body.add_child(_tree)
	_empty = Label.new()
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	_empty.text = EMPTY_TEXT
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.visible = false
	body.add_child(_empty)
	return body

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

func _build_progress() -> Control:
	## 그 시절 파일 복사 창의 축소판. 손상된 파일에서는 여기가 중간에 멈춘 채로 남고,
	## 그 위에 오류 대화상자가 겹쳐 뜬다 — 멈춘 막대가 보여야 시도했다는 게 읽힌다.
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.22)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 한가운데 두면 오류 대화상자가 통째로 덮어 멈춘 막대가 안 보인다. 위-왼쪽으로
	# 비켜 세워 창 두 개가 겹친 모양으로 만든다 (그 시절 복사 창이 그랬다)
	var offset := MarginContainer.new()
	offset.add_theme_constant_override("margin_bottom", PROGRESS_LIFT)
	offset.add_theme_constant_override("margin_right", PROGRESS_SHIFT)
	offset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	var titlebar := Panel.new()
	titlebar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(true))
	titlebar.custom_minimum_size = Vector2(0, 24)
	var title := Label.new()
	title.text = "복원 중"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(8, 3)
	titlebar.add_child(title)
	shell.add_child(titlebar)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_progress_from = Label.new()
	_progress_from.add_theme_font_size_override("font_size", 14)
	col.add_child(_progress_from)
	_progress_to = Label.new()
	_progress_to.add_theme_font_size_override("font_size", 14)
	_progress_to.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	col.add_child(_progress_to)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 20)
	_bar.show_percentage = false
	_bar.max_value = 100.0
	col.add_child(_bar)
	pad.add_child(col)
	shell.add_child(pad)
	box.add_child(shell)
	offset.add_child(box)
	center.add_child(offset)
	layer.add_child(center)
	return layer

# ── 보기 전환 ─────────────────────────────────────────────────────────────

func set_view_mode(mode: ViewMode) -> void:
	_view_mode = mode
	var icons := mode == ViewMode.ICONS
	_list.visible = icons
	_tree.visible = not icons
	_icons_btn.button_pressed = icons
	_details_btn.button_pressed = not icons
	if icons:
		_relayout_grid()
	_apply_selection()

func view_mode() -> ViewMode:
	return _view_mode

func _relayout_grid() -> void:
	if not is_instance_valid(_list):
		return
	_list.max_columns = maxi(1, int((_list.size.x - 32.0) / GRID_COLUMN_W))

# ── 목록 ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var entries := ContentDB.trash_items()
	_list.clear()
	_tree.clear()
	var root := _tree.create_item()
	var total := 0
	for n in entries:
		var item_name := String(n["name"])
		var i := _list.add_item(item_name, _texture(ICON["doc"]))
		_list.set_item_metadata(i, n["id"])
		_list.set_item_tooltip(i, item_name)
		var row := _tree.create_item(root)
		row.set_icon(0, _texture(ICON["doc"]))
		row.set_icon_max_width(0, 16)
		row.set_text(0, item_name)
		row.set_text(1, origin_text(n))
		row.set_text(2, Explorer.format_mtime(String(n.get("deleted", ""))))
		row.set_text(3, Explorer.size_text(n))
		row.set_text_alignment(3, HORIZONTAL_ALIGNMENT_RIGHT)
		row.set_metadata(0, n["id"])
		total += int(n.get("size", 0))
	_relayout_grid()
	_empty.visible = entries.is_empty()
	_selected = ""
	_status_left.text = "개체 %d개" % entries.size()
	_status_right.text = "" if total == 0 else Explorer.format_size(total)
	_restore_btn.disabled = true
	_purge_btn.disabled = entries.is_empty()

func _on_selected(index: int) -> void:
	_show_selection(String(_list.get_item_metadata(index)))

func _on_tree_selected() -> void:
	var row := _tree.get_selected()
	if row != null:
		_show_selection(String(row.get_metadata(0)))

func _on_activated(index: int) -> void:
	_begin_restore(String(_list.get_item_metadata(index)))

func _on_tree_activated() -> void:
	var row := _tree.get_selected()
	if row != null:
		_begin_restore(String(row.get_metadata(0)))

func _show_selection(id: String) -> void:
	var n := ContentDB.fs_node(id)
	if n.is_empty():
		return
	_selected = id
	_restore_btn.disabled = _busy
	_status_left.text = "%s — %s에서 삭제됨" % [String(n["name"]), origin_text(n)]
	_status_right.text = Explorer.size_text(n)

func select(id: String) -> void:
	_show_selection(id)
	_apply_selection()

func _apply_selection() -> void:
	## 보기를 바꿔도 고른 파일은 그대로 눌려 있어야 한다 — 안 그러면 상태표시줄에는
	## 이름이 떠 있는데 목록에는 아무것도 안 눌린 창이 된다
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

func item_count() -> int:
	return _list.item_count

func detail_row_count() -> int:
	var root := _tree.get_root()
	return root.get_child_count() if root != null else 0

func address_text() -> String:
	return _addr.text

func status_text() -> String:
	return _status_left.text

func is_empty_shown() -> bool:
	return _empty.visible

func last_message() -> String:
	return _dialog.last_message() if is_instance_valid(_dialog) else ""

func is_busy() -> bool:
	return _busy

func progress_value() -> float:
	return _bar.value if is_instance_valid(_bar) else 0.0

func progress_visible() -> bool:
	return is_instance_valid(_progress) and _progress.visible

static func origin_text(n: Dictionary) -> String:
	## 파일 시스템에 없는 자리(윈도 임시 폴더)에서 온 것만 경로를 직접 갖는다
	var explicit := String(n.get("origin_path", ""))
	if explicit != "":
		return explicit
	return Explorer.path_text(String(n.get("origin", "mydocs")))

# ── 복원 ──────────────────────────────────────────────────────────────────

func _restore_selected() -> void:
	if _selected != "":
		_begin_restore(_selected)

func _begin_restore(node_id: String) -> void:
	## 눈에 보이는 쪽. 상태를 바꾸는 일은 restore()가 하고, 여기서는 그 앞뒤로
	## 진행률과 오류창을 붙인다 (테스트는 restore()를 직접 부른다).
	if _busy:
		return
	var n := ContentDB.fs_node(node_id)
	if n.is_empty():
		return
	_busy = true
	_set_tools_enabled(false)
	var corrupt: bool = n.get("corrupt", false)
	var target := FAIL_AT if corrupt else 1.0
	_show_progress(n)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_bar, "value", target * 100.0, restore_sec * target)
		await tw.finished
	else:
		_bar.value = target * 100.0
	if corrupt:
		await get_tree().create_timer(FAIL_HOLD).timeout
		AudioDirector.play_sfx("error")
		_dialog.show_message("복원할 수 없습니다",
			"%s\n\n파일의 일부를 읽을 수 없습니다.\n이 파일은 복원할 수 없습니다.\n\n섹터 오류 : %s"
				% [String(n["name"]), String(n.get("error", "0x00000000"))],
			ICON["warn"])
		# 멈춘 막대는 대화상자를 닫을 때까지 남는다 — _on_dialog_closed가 치운다
		return
	_hide_progress()
	restore(node_id)
	_busy = false
	_set_tools_enabled(true)

func restore(node_id: String) -> bool:
	## 퍼즐4의 판정과 복원 자체. 성공하면 파일은 휴지통을 떠나 원래 폴더로 간다.
	## 유서(t1)만 퍼즐이다. restorable이 붙은 파일은 판정 없이 복원된다 —
	## 침입자가 지운 점검표가, 성진이 믿었던 바로 그 트릭으로 돌아온다.
	var n := ContentDB.fs_node(node_id)
	if n.is_empty() or n.get("corrupt", false):
		return false
	var is_answer := GameState.try_answer("puzzle4", node_id)
	if not is_answer and not n.get("restorable", false):
		return false
	GameState.restore_node(node_id)
	GameState.mark_read(String(n["cid"]))
	if is_answer:
		GameState.set_flag("final_diary_read")
	if String(n.get("cid", "")) == "doc:sweep_checklist":
		GameState.set_flag("intruder_found")
	AudioDirector.play_sfx("unlock")
	if is_instance_valid(_list):
		_refresh()
	_open_restored(n)
	return true

func _open_restored(n: Dictionary) -> void:
	# 탐색기가 문서를 여는 것과 같은 창 id를 쓴다 — 나중에 '내 문서'에서 다시 열면
	# 새 창이 뜨지 않고 이미 열린 창이 앞으로 온다
	if not is_inside_tree():
		return
	var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
	if wm == null:
		return
	var pad := Notepad.new()
	pad.body_text = String(ContentDB.doc(String(n["cid"])).get("body", ""))
	wm.open_window("doc:" + String(n["id"]), String(n["name"]), pad, DOC_WIN_SIZE, ICON["doc"])

func _show_progress(n: Dictionary) -> void:
	_bar.value = 0.0
	_progress_from.text = String(n["name"])
	_progress_to.text = "%s (으)로 복원하는 중..." % origin_text(n)
	_progress.visible = true

func _hide_progress() -> void:
	_progress.visible = false
	_bar.value = 0.0

func _set_tools_enabled(on: bool) -> void:
	_restore_btn.disabled = not on or _selected == ""
	_purge_btn.disabled = not on or ContentDB.trash_items().is_empty()

# ── 휴지통 비우기 ─────────────────────────────────────────────────────────

func ask_purge() -> void:
	var items := ContentDB.trash_items()
	if items.is_empty() or _busy:
		return
	_dialog.ask_confirm("항목 삭제 확인",
		"이 %d개 항목을 영구적으로 삭제하시겠습니까?" % items.size(), ICON["trash"])

func purge() -> bool:
	## 손상된 파일만 지워진다. 성진이 마지막으로 지운 파일은 열려 있는 무언가가
	## 붙들고 있어서 안 지워진다 — 실수로 게임이 막히지 않고, 남은 한 장이 도드라진다.
	var blocked := _blocked_item()
	GameState.set_flag("trash_purged")
	_refresh()
	if blocked.is_empty():
		return true
	AudioDirector.play_sfx("error")
	_dialog.show_message("삭제할 수 없습니다",
		"%s 은(는)\n\n다른 프로그램이 사용 중이라\n삭제할 수 없습니다." % String(blocked["name"]),
		ICON["warn"])
	return false

func _blocked_item() -> Dictionary:
	for n in ContentDB.trash_items():
		if not n.get("corrupt", false):
			return n
	return {}

func _on_dialog_closed() -> void:
	if _busy:
		_hide_progress()
		_busy = false
	_set_tools_enabled(true)

func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = tex
	return tex
