class_name MailApp
extends Control
## 누리메일: 좌측 메일 목록, 우측 본문. 첨부는 영숫자 암호 게이트(퍼즐2).

var _list: ItemList
var _view: RichTextLabel
var _pw_row: HBoxContainer
var _pw_edit: LineEdit
var _current_mail := ""
var _pending_attachment := ""

func _ready() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(240, 0)
	for m in ContentDB.mails():
		var i := _list.add_item("%s — %s" % [m["from"], m["subject"]])
		_list.set_item_metadata(i, m["id"])
	_list.item_activated.connect(func(i): open_mail(_list.get_item_metadata(i)))
	split.add_child(_list)
	var right := VBoxContainer.new()
	_view = RichTextLabel.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_view)
	_pw_row = HBoxContainer.new()
	_pw_row.visible = false
	_pw_edit = LineEdit.new()
	_pw_edit.placeholder_text = "첨부파일 암호 (영문/숫자)"
	_pw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := Button.new()
	ok.text = "열기"
	ok.pressed.connect(func(): submit_password(_pw_edit.text))
	_pw_row.add_child(_pw_edit)
	_pw_row.add_child(ok)
	right.add_child(_pw_row)
	var att := Button.new()
	att.text = "첨부파일"
	att.pressed.connect(func(): open_attachment(_current_mail))
	right.add_child(att)
	split.add_child(right)
	add_child(split)

func _mail(id: String) -> Dictionary:
	for m in ContentDB.mails():
		if m["id"] == id:
			return m
	return {}

func open_mail(id: String) -> void:
	_pending_attachment = ""
	_pw_row.visible = false
	var m := _mail(id)
	_current_mail = id
	_view.text = "보낸사람: %s\n날짜: %s\n제목: %s\n\n%s" % [m["from"], m["date"], m["subject"], m["body"]]
	if m.has("attachment"):
		_view.text += "\n\n[첨부: %s]" % m["attachment"]["name"]
	GameState.mark_read("mail:" + id)

func open_attachment(mail_id: String) -> bool:
	var m := _mail(mail_id)
	if not m.has("attachment"):
		return false
	var a: Dictionary = m["attachment"]
	if not GameState.has_flag(String(a["locked_by"]) + "_solved"):
		_pending_attachment = mail_id
		_pw_row.visible = true
		return false
	var d := ContentDB.doc(a["cid"])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	GameState.mark_read(a["cid"])
	return true

func submit_password(text: String) -> bool:
	if _pending_attachment == "":
		return false
	var a: Dictionary = _mail(_pending_attachment)["attachment"]
	if GameState.try_answer(a["locked_by"], text):
		_pw_row.visible = false
		AudioDirector.play_sfx("unlock")
		var t := _pending_attachment
		_pending_attachment = ""
		return open_attachment(t)
	return false
