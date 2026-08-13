class_name TrashApp
extends Control
## 휴지통: 삭제된 파일 목록. 올바른 파일 복원 = 퍼즐4.

var _list: ItemList
var _view: RichTextLabel

func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 160)
	for n in ContentDB.trash_items():
		var i := _list.add_item(n["name"])
		_list.set_item_metadata(i, n["id"])
	box.add_child(_list)
	var btn := Button.new()
	btn.text = "복원"
	btn.pressed.connect(func():
		var sel := _list.get_selected_items()
		if sel.size() > 0:
			restore(_list.get_item_metadata(sel[0])))
	box.add_child(btn)
	_view = RichTextLabel.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_view)
	add_child(box)

func restore(node_id: String) -> bool:
	if not GameState.try_answer("puzzle4", node_id):
		_view.text = "복원 실패: 파일이 손상되었습니다."
		return false
	var n := ContentDB.fs_node(node_id)
	var d := ContentDB.doc(n["cid"])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	GameState.mark_read(n["cid"])
	GameState.set_flag("final_diary_read")
	AudioDirector.play_sfx("unlock")
	return true
