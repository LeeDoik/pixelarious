class_name MailApp
extends Control
## 누리메일: 도구모음 + 3열 목록(보낸사람·제목·날짜) + 읽기창 + 첨부 막대.
## 이 앱의 서사는 날짜순 압박 상승이라 목록이 날짜를 숨기면 안 된다.
## 첨부는 영숫자 암호 게이트(퍼즐2) — 탐색기와 같은 공용 대화상자를 쓴다.

const ICON := {
	"unread": "res://assets/img/icons/mail_unread.png",
	"read": "res://assets/img/icons/mail_read.png",
	"clip": "res://assets/img/icons/clip.png",
	"locked": "res://assets/img/icons/attach_locked.png",
	"doc": "res://assets/img/icons/doc.png",
}
const COL_STATE := 0
const COL_CLIP := 1
const COL_FROM := 2
const COL_SUBJECT := 3
const COL_DATE := 4

var _list: Tree
var _view: RichTextLabel
var _header: GridContainer
var _attach_bar: PanelContainer
var _attach_icon: TextureRect
var _attach_label: Label
var _status: Label
var _dialog: OSDialog
var _current_mail := ""
var _pending_attachment := ""
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	var split := VSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_build_list())
	split.add_child(_build_reader())
	col.add_child(split)
	col.add_child(_build_status_bar())
	_dialog = OSDialog.new()
	add_child(_dialog)
	_dialog.submitted.connect(submit_password)
	_dialog.closed.connect(func(): _pending_attachment = "")
	_refresh_list()
	_show_empty()

# ── 구성 ──────────────────────────────────────────────────────────────────

func _build_toolbar() -> Control:
	# 답장·전달·삭제는 이 게임에서 진짜로 동작할 수 없다. 죽은 버튼으로 두는 대신
	# 누르면 "왜 안 되는지"를 말하게 했다 — 남의 계정을 보고 있다는 사실이 한 번 더 드러난다.
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_tool_button("답장", func(): _explain(
		"보낼 수 없습니다",
		"이 계정으로는 메일을 보낼 수 없습니다.\n한성진 님의 비밀번호가 저장되어 있지 않습니다.")))
	row.add_child(_tool_button("전달", func(): _explain(
		"보낼 수 없습니다",
		"이 계정으로는 메일을 보낼 수 없습니다.\n한성진 님의 비밀번호가 저장되어 있지 않습니다.")))
	row.add_child(VSeparator.new())
	row.add_child(_tool_button("삭제", func(): _explain(
		"지울 수 없습니다",
		"받은 편지함이 읽기 전용으로 열려 있습니다.")))
	bar.add_child(row)
	return bar

func _tool_button(label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "NuriFlat"
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b

func _build_list() -> Control:
	_list = Tree.new()
	_list.columns = 5
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	_list.allow_reselect = true
	_list.custom_minimum_size = Vector2(0, 124)
	_list.add_theme_font_size_override("font_size", 14)
	_list.add_theme_font_size_override("title_button_font_size", 14)
	var titles := ["", "", "보낸사람", "제목", "날짜"]
	var widths := [26, 24, 150, 240, 90]
	for c in 5:
		_list.set_column_title(c, titles[c])
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_expand(c, c == COL_SUBJECT)
		_list.set_column_custom_minimum_width(c, widths[c])
	_list.set_column_clip_content(COL_SUBJECT, true)
	_list.item_selected.connect(_on_row_selected)
	return _list

func _build_reader() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(0, 150)
	var head_panel := PanelContainer.new()
	head_panel.theme_type_variation = "NuriToolbar"
	_header = GridContainer.new()
	_header.columns = 2
	_header.add_theme_constant_override("h_separation", 10)
	_header.add_theme_constant_override("v_separation", 2)
	head_panel.add_child(_header)
	box.add_child(head_panel)
	_view = RichTextLabel.new()
	_view.bbcode_enabled = false
	_view.selection_enabled = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_view)
	box.add_child(_build_attach_bar())
	return box

func _build_attach_bar() -> Control:
	_attach_bar = PanelContainer.new()
	_attach_bar.theme_type_variation = "NuriToolbar"
	_attach_bar.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_attach_icon = TextureRect.new()
	_attach_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attach_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_attach_icon.custom_minimum_size = Vector2(20, 20)
	_attach_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_attach_icon)
	_attach_label = Label.new()
	_attach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attach_label.add_theme_font_size_override("font_size", 14)
	row.add_child(_attach_label)
	var open := Button.new()
	open.text = "열기"
	open.focus_mode = Control.FOCUS_NONE
	open.add_theme_font_size_override("font_size", 14)
	open.pressed.connect(func(): open_attachment(_current_mail))
	row.add_child(open)
	_attach_bar.add_child(row)
	return _attach_bar

func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriStatusBar"
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	bar.add_child(_status)
	return bar

# ── 목록 ──────────────────────────────────────────────────────────────────

func _refresh_list() -> void:
	# 목록을 다시 그리며 선택을 되돌리면 item_selected가 다시 날아와
	# open_mail → _refresh_list 로 무한히 돈다. 그리는 동안은 신호를 막는다.
	var selected := _current_mail
	_list.set_block_signals(true)
	_list.clear()
	var root := _list.create_item()
	var unread := 0
	for m in ContentDB.mails():
		var id := String(m["id"])
		var read := GameState.is_read("mail:" + id)
		if not read:
			unread += 1
		var row := _list.create_item(root)
		row.set_icon(COL_STATE, _texture(ICON["read"] if read else ICON["unread"]))
		row.set_icon_max_width(COL_STATE, 16)
		if m.has("attachment"):
			row.set_icon(COL_CLIP, _texture(ICON["clip"]))
			row.set_icon_max_width(COL_CLIP, 16)
		row.set_text(COL_FROM, String(m["from"]))
		row.set_text(COL_SUBJECT, String(m["subject"]))
		row.set_text(COL_DATE, String(m["date"]).substr(5))
		row.set_metadata(COL_STATE, id)
		# 안 읽은 메일이 목록에서 먼저 눈에 띄어야 한다 (기록물 하나가 여기 있다)
		for c in 5:
			row.set_custom_color(c, NuriTheme.TEXT_DIM if read else NuriTheme.TEXT)
		if id == selected:
			row.select(COL_FROM)
			_list.scroll_to_item(row)   # 프로그램이 연 메일도 목록에서 보이게
	_list.set_block_signals(false)
	_status.text = "메일 %d통 · 안 읽음 %d통" % [ContentDB.mails().size(), unread]

func _on_row_selected() -> void:
	# 메일 프로그램은 고르는 순간 미리보기가 뜬다 (탐색기의 더블클릭과 다른 규칙)
	var row := _list.get_selected()
	if row != null:
		open_mail(String(row.get_metadata(COL_STATE)))

func mail_count() -> int:
	var root := _list.get_root()
	return root.get_child_count() if root != null else 0

func status_text() -> String:
	return _status.text

# ── 읽기 ──────────────────────────────────────────────────────────────────

func _mail(id: String) -> Dictionary:
	for m in ContentDB.mails():
		if m["id"] == id:
			return m
	return {}

func _show_empty() -> void:
	_set_header([])
	_view.text = ""
	_attach_bar.visible = false

func _set_header(rows: Array) -> void:
	for c in _header.get_children():
		_header.remove_child(c)
		c.queue_free()
	for r in rows:
		var key := Label.new()
		key.text = String(r[0])
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
		_header.add_child(key)
		var val := Label.new()
		val.text = String(r[1])
		val.add_theme_font_size_override("font_size", 14)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.clip_text = true
		_header.add_child(val)

func header_text() -> String:
	var out := ""
	for c in _header.get_children():
		out += (c as Label).text + " "
	return out.strip_edges()

func open_mail(id: String) -> void:
	_pending_attachment = ""
	_dialog.close()
	var m := _mail(id)
	if m.is_empty():
		return
	_current_mail = id
	_set_header([
		["보낸사람", String(m["from"])],
		["날짜", String(m["date"])],
		["제목", String(m["subject"])],
	])
	_view.text = String(m["body"])
	_show_attachment(m)
	GameState.mark_read("mail:" + id)
	_refresh_list()

func _show_attachment(m: Dictionary) -> void:
	if not m.has("attachment"):
		_attach_bar.visible = false
		return
	var a: Dictionary = m["attachment"]
	var locked := not GameState.has_flag(String(a["locked_by"]) + "_solved")
	_attach_bar.visible = true
	_attach_icon.texture = _texture(ICON["locked"] if locked else ICON["doc"])
	_attach_label.text = String(a["name"]) + ("  (암호 필요)" if locked else "")

func open_attachment(mail_id: String) -> bool:
	var m := _mail(mail_id)
	if not m.has("attachment"):
		return false
	var a: Dictionary = m["attachment"]
	if not GameState.has_flag(String(a["locked_by"]) + "_solved"):
		_pending_attachment = mail_id
		_dialog.ask_password("첨부파일 암호",
			"'%s' 파일은 암호로 보호되어 있습니다." % String(a["name"]), ICON["locked"])
		return false
	var d := ContentDB.doc(String(a["cid"]))
	_set_header([["첨부", String(a["name"])], ["보낸사람", String(m["from"])]])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	_show_attachment(m)
	GameState.mark_read(String(a["cid"]))
	return true

func submit_password(text: String) -> bool:
	if _pending_attachment == "":
		return false
	var a: Dictionary = _mail(_pending_attachment)["attachment"]
	if GameState.try_answer(String(a["locked_by"]), text):
		AudioDirector.play_sfx("unlock")
		var target := _pending_attachment
		_pending_attachment = ""
		_dialog.close()
		return open_attachment(target)
	_dialog.show_error("암호가 올바르지 않습니다.")
	return false

func _explain(title: String, body: String) -> void:
	_dialog.show_message(title, body, ICON["read"])

func last_message() -> String:
	return _dialog.last_message() if is_instance_valid(_dialog) else ""

func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = tex
	return tex
