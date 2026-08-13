class_name BrowserApp
extends Control
## 누리서퍼: 주소창(영숫자+./), 즐겨찾기 바, 페이지 뷰. 캐시 게이트 URL = 퍼즐3.

var _addr: LineEdit
var _view: RichTextLabel

func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bar := HBoxContainer.new()
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.placeholder_text = "주소 입력"
	_addr.text_submitted.connect(navigate)
	bar.add_child(_addr)
	var go := Button.new()
	go.text = "이동"
	go.pressed.connect(func(): navigate(_addr.text))
	bar.add_child(go)
	box.add_child(bar)
	var favs := HBoxContainer.new()
	for bm in ContentDB.web_bookmarks():
		var b := Button.new()
		b.text = "★ " + bm["title"]
		b.pressed.connect(func():
			_addr.text = bm["url"]
			navigate(bm["url"]))
		favs.add_child(b)
	box.add_child(favs)
	_view = RichTextLabel.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_view)
	add_child(box)

func navigate(url: String) -> Dictionary:
	var u := url.strip_edges().to_lower()
	_addr.text = u
	var page := ContentDB.web_page(u)
	if page.is_empty():
		_view.text = "페이지를 찾을 수 없습니다. (404)"
		return {}
	if String(page.get("requires", "")) == "puzzle3":
		GameState.try_answer("puzzle3", u)
	_view.text = String(page["title"]) + "\n\n" + String(page["body"])
	if page.has("cid"):
		GameState.mark_read(page["cid"])
	return page
