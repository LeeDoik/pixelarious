class_name MailApp
extends Control
## 누리메일: 도구모음(뒤로·앞으로·받은 편지함) + 위치줄 + 한 장짜리 본문 + 상태표시줄.
##
## 메일을 고르면 미리보기 칸이 열리는 게 아니라 화면이 통째로 그 메일로 넘어간다.
## 누리넷(브라우저)과 같은 이동 규칙이라 뒤로·앞으로가 지나온 자리를 되짚고,
## 첨부를 연 것도 한 자리로 친다. 좁은 창에서 목록과 본문이 서로 자리를 뺏지 않는다.
##
## 이 앱의 서사는 날짜순 압박 상승이라 목록이 날짜를 숨기면 안 된다.
## 첨부는 영숫자 암호 게이트(퍼즐2) — 탐색기와 같은 공용 대화상자를 쓴다.

const ICON := {
	"unread": "res://assets/img/icons/mail_unread.png",
	"read": "res://assets/img/icons/mail_read.png",
	"clip": "res://assets/img/icons/clip.png",
	"locked": "res://assets/img/icons/attach_locked.png",
	"doc": "res://assets/img/icons/doc.png",
	"inbox": "res://assets/img/icons/mail.png",
	"back": "res://assets/img/icons/nav_back.png",
	"forward": "res://assets/img/icons/nav_forward.png",
	"home": "res://assets/img/icons/nav_home.png",
}
const COL_STATE := 0
const COL_CLIP := 1
const COL_FROM := 2
const COL_SUBJECT := 3
const COL_DATE := 4

## 기록에 쌓이는 "자리" 이름. 메일 자리는 GameState의 읽음 표시(cid)와 같은 문자열이다.
const INBOX := "inbox"
const MAIL_PREFIX := "mail:"
const ATTACH_PREFIX := "attach:"
const INBOX_LABEL := "받은 편지함"
const INBOX_NOTE := "읽기 전용으로 열림"
const SEP := " > "

var _list: Tree
var _reader: Control
var _view: RichTextLabel
var _header: GridContainer
var _attach_bar: PanelContainer
var _attach_icon: TextureRect
var _attach_label: Label
var _loc: Label
var _loc_icon: TextureRect
var _status: Label
var _status_note: Label
var _back_btn: Button
var _fwd_btn: Button
var _dialog: OSDialog
var _current_mail := ""
var _pending_attachment := ""
var _history: PackedStringArray = []
var _pos := -1
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	col.add_child(_build_location_bar())
	col.add_child(_build_content())
	col.add_child(_build_status_bar())
	_dialog = OSDialog.new()
	add_child(_dialog)
	_dialog.submitted.connect(submit_password)
	_dialog.closed.connect(func(): _pending_attachment = "")
	navigate(INBOX)
	# 창 제목은 창 관리자가 이 창을 등록한 뒤에야 바뀐다 — _ready는 아직 그 전이다
	_set_window_title.call_deferred(INBOX_LABEL)

# ── 구성 ──────────────────────────────────────────────────────────────────

func _build_toolbar() -> Control:
	# 답장·전달·삭제는 이 게임에서 진짜로 동작할 수 없다. 죽은 버튼으로 두는 대신
	# 누르면 "왜 안 되는지"를 말하게 했다 — 남의 계정을 보고 있다는 사실이 한 번 더 드러난다.
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_back_btn = _tool_button("뒤로", ICON["back"], go_back)
	_fwd_btn = _tool_button("앞으로", ICON["forward"], go_forward)
	row.add_child(_back_btn)
	row.add_child(_fwd_btn)
	row.add_child(VSeparator.new())
	row.add_child(_tool_button(INBOX_LABEL, ICON["home"], open_inbox))
	row.add_child(VSeparator.new())
	row.add_child(_tool_button("답장", "", func(): _explain(
		"보낼 수 없습니다",
		"이 계정으로는 메일을 보낼 수 없습니다.\n한성진 님의 비밀번호가 저장되어 있지 않습니다.")))
	row.add_child(_tool_button("전달", "", func(): _explain(
		"보낼 수 없습니다",
		"이 계정으로는 메일을 보낼 수 없습니다.\n한성진 님의 비밀번호가 저장되어 있지 않습니다.")))
	row.add_child(_tool_button("삭제", "", func(): _explain(
		"지울 수 없습니다",
		"받은 편지함이 읽기 전용으로 열려 있습니다.")))
	bar.add_child(row)
	return bar

func _tool_button(label: String, icon_path: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "NuriFlat"
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	var tex: Texture2D = _texture(icon_path) if icon_path != "" else null
	if tex != null:
		b.icon = tex
		b.add_theme_constant_override("icon_max_width", 16)
	b.pressed.connect(cb)
	return b

func _build_location_bar() -> Control:
	## 지금 어느 자리에 있는지 — 탐색기 주소줄과 같은 자리, 같은 생김새.
	## 여기는 주소를 칠 수 없다. 이 계정으로 갈 수 있는 곳은 받은 편지함뿐이다.
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = "위치"
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	_loc_icon = TextureRect.new()
	_loc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_loc_icon.custom_minimum_size = Vector2(16, 16)
	_loc_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(_loc_icon)
	_loc = Label.new()
	_loc.add_theme_font_size_override("font_size", 14)
	_loc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loc.clip_text = true
	inner.add_child(_loc)
	field.add_child(inner)
	row.add_child(field)
	bar.add_child(row)
	return bar

func _build_content() -> Control:
	## 목록과 읽기 화면은 한 자리를 번갈아 쓴다 (탐색기의 아이콘/자세히와 같은 방식).
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	box.add_child(_build_list())
	box.add_child(_build_reader())
	return box

func _build_list() -> Control:
	_list = Tree.new()
	_list.columns = 5
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	_list.allow_reselect = true
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	# 링크처럼, 얹기만 해도 그 줄이 무엇인지 상태표시줄에 뜬다 (누리넷과 같은 규칙)
	_list.gui_input.connect(_on_list_hover)
	_list.mouse_exited.connect(func(): _status_note.text = INBOX_NOTE)
	return _list

func _build_reader() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.visible = false
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
	_reader = box
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_status_note = Label.new()
	_status_note.add_theme_font_size_override("font_size", 14)
	_status_note.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_status_note)
	bar.add_child(row)
	return bar

# ── 이동 ──────────────────────────────────────────────────────────────────

func navigate(view: String) -> void:
	## 자리를 옮기고 기록에 쌓는다. 같은 자리를 다시 열면 기록은 늘지 않는다.
	var target := _render(view)
	if _pos < 0 or _history[_pos] != target:
		_history.resize(_pos + 1)
		_history.append(target)
		_pos = _history.size() - 1
	_sync_nav()

func go_back() -> void:
	if _pos <= 0:
		return
	_pos -= 1
	_render(_history[_pos])
	_sync_nav()

func go_forward() -> void:
	if _pos < 0 or _pos >= _history.size() - 1:
		return
	_pos += 1
	_render(_history[_pos])
	_sync_nav()

func open_inbox() -> void:
	navigate(INBOX)

func open_mail(id: String) -> void:
	navigate(MAIL_PREFIX + id)

func _sync_nav() -> void:
	_back_btn.disabled = _pos <= 0
	_fwd_btn.disabled = _pos >= _history.size() - 1

func _render(view: String) -> String:
	## 실제로 그려낸 자리를 돌려준다 — 없는 메일로 가면 받은 편지함으로 떨어진다.
	_pending_attachment = ""
	_dialog.close()
	if view.begins_with(MAIL_PREFIX):
		var m := _mail(view.substr(MAIL_PREFIX.length()))
		if not m.is_empty():
			_show_mail(m)
			return view
	elif view.begins_with(ATTACH_PREFIX):
		var id := view.substr(ATTACH_PREFIX.length())
		var m := _mail(id)
		if not m.is_empty():
			# 잠긴 첨부는 자리로 칠 수 없다 (기록을 되짚다 잠긴 자리에 닿는 경우)
			if _attachment_open(m):
				_show_attachment_page(m)
				return view
			_show_mail(m)
			return MAIL_PREFIX + id
	_show_inbox()
	return INBOX

func _show_inbox() -> void:
	_list.visible = true
	_reader.visible = false
	_refresh_list()
	_set_location(ICON["inbox"], INBOX_LABEL)
	_status_note.text = INBOX_NOTE
	_set_window_title(INBOX_LABEL)

func _show_mail(m: Dictionary) -> void:
	var id := String(m["id"])
	_current_mail = id
	_list.visible = false
	_reader.visible = true
	_set_header([
		["보낸사람", String(m["from"])],
		["날짜", String(m["date"])],
		["제목", String(m["subject"])],
	])
	_view.text = String(m["body"])
	_view.scroll_to_line(0)
	_show_attachment(m)
	GameState.mark_read("mail:" + id)
	# 목록은 받은 편지함으로 돌아올 때 다시 그린다. 여기서 그리면 방금 누른 줄을
	# Tree가 아직 붙들고 있는 채로 지우게 되어 엔진이 발밑을 잃는다(크래시).
	_update_count()
	_set_location(ICON["read"], INBOX_LABEL + SEP + String(m["subject"]))
	_status_note.text = String(m["date"]) + ("  ·  첨부 1개" if m.has("attachment") else "")
	_set_window_title(String(m["subject"]))

func _show_attachment_page(m: Dictionary) -> void:
	var a: Dictionary = m["attachment"]
	var d := ContentDB.doc(String(a["cid"]))
	_current_mail = String(m["id"])
	_list.visible = false
	_reader.visible = true
	_set_header([["첨부", String(a["name"])], ["보낸사람", String(m["from"])]])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	_view.scroll_to_line(0)
	_attach_bar.visible = false   # 이미 그 첨부를 보고 있다 — 여는 막대를 또 달지 않는다
	GameState.mark_read(String(a["cid"]))
	_set_location(ICON["doc"],
		INBOX_LABEL + SEP + String(m["subject"]) + SEP + String(a["name"]))
	_status_note.text = "첨부 문서"
	_set_window_title(String(a["name"]))

func _set_location(icon_path: String, text: String) -> void:
	_loc_icon.texture = _texture(icon_path)
	_loc.text = text

func _set_window_title(here: String) -> void:
	var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
	if wm != null and wm.is_open("mail"):
		wm.set_window_title("mail", "%s — %s" % [here, ContentDB.ui("app_mail")])

# ── 목록 ──────────────────────────────────────────────────────────────────

func _refresh_list() -> void:
	# 목록을 다시 그리며 선택을 되돌리면 item_selected가 다시 날아와
	# open_mail → _refresh_list 로 무한히 돈다. 그리는 동안은 신호를 막는다.
	var selected := _current_mail
	_list.set_block_signals(true)
	_list.clear()
	var root := _list.create_item()
	for m in ContentDB.mails():
		var id := String(m["id"])
		var read := GameState.is_read("mail:" + id)
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
			_list.scroll_to_item(row)   # 읽고 돌아온 자리가 목록에서 바로 보이게
	_list.set_block_signals(false)
	_update_count()

func _update_count() -> void:
	## 상태표시줄은 목록을 안 보고 있을 때도 안 읽은 통수를 들고 있어야 한다
	var unread := 0
	for m in ContentDB.mails():
		if not GameState.is_read("mail:" + String(m["id"])):
			unread += 1
	_status.text = "메일 %d통 · 안 읽음 %d통" % [ContentDB.mails().size(), unread]

func _on_row_selected() -> void:
	# 목록의 한 줄은 링크다 — 누르면 화면이 통째로 그 메일로 넘어간다
	var row := _list.get_selected()
	if row != null:
		open_mail(String(row.get_metadata(COL_STATE)))

func _on_list_hover(e: InputEvent) -> void:
	if not (e is InputEventMouseMotion):
		return
	var row := _list.get_item_at_position((e as InputEventMouseMotion).position)
	if row == null:
		_status_note.text = INBOX_NOTE
		return
	var m := _mail(String(row.get_metadata(COL_STATE)))
	_status_note.text = "%s  ·  %s" % [String(m.get("from", "")), String(m.get("date", ""))]

func mail_count() -> int:
	var root := _list.get_root()
	return root.get_child_count() if root != null else 0

func status_text() -> String:
	return _status.text

func status_note() -> String:
	return _status_note.text

func location_text() -> String:
	return _loc.text

func view_id() -> String:
	return _history[_pos] if _pos >= 0 else ""

func can_go_back() -> bool:
	return _pos > 0

func can_go_forward() -> bool:
	return _pos >= 0 and _pos < _history.size() - 1

func is_reading() -> bool:
	return _reader.visible

# ── 읽기 ──────────────────────────────────────────────────────────────────

func _mail(id: String) -> Dictionary:
	for m in ContentDB.mails():
		if m["id"] == id:
			return m
	return {}

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

func _show_attachment(m: Dictionary) -> void:
	if not m.has("attachment"):
		_attach_bar.visible = false
		return
	var a: Dictionary = m["attachment"]
	var locked := not _attachment_open(m)
	_attach_bar.visible = true
	_attach_icon.texture = _texture(ICON["locked"] if locked else ICON["doc"])
	_attach_label.text = String(a["name"]) + ("  (암호 필요)" if locked else "")

func _attachment_open(m: Dictionary) -> bool:
	if not m.has("attachment"):
		return false
	var a: Dictionary = m["attachment"]
	return GameState.has_flag(String(a["locked_by"]) + "_solved")

func open_attachment(mail_id: String) -> bool:
	var m := _mail(mail_id)
	if not m.has("attachment"):
		return false
	if not _attachment_open(m):
		_pending_attachment = mail_id
		var a: Dictionary = m["attachment"]
		_dialog.ask_password("첨부파일 암호",
			"'%s' 파일은 암호로 보호되어 있습니다." % String(a["name"]), ICON["locked"])
		return false
	navigate(ATTACH_PREFIX + mail_id)
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
