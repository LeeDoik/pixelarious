class_name BrowserApp
extends Control
## 누리넷: 도구모음(뒤로·앞으로·새로고침·홈) + 주소줄 + 즐겨찾기 막대 + 페이지 + 상태표시줄.
##
## 이 브라우저는 네트워크에 못 나간다 — 전부 이 컴퓨터에 남은 오프라인 캐시다.
## 캐시가 주소 단위로 저장된다는 사실이 퍼즐3의 열쇠라, 그 설정을 화면에 계속 드러낸다.
## 본문은 손으로 짠 ASCII 격자라 TextGrid가 칸 단위로 그린다.

const ICON := {
	"back": "res://assets/img/icons/nav_back.png",
	"forward": "res://assets/img/icons/nav_forward.png",
	"reload": "res://assets/img/icons/nav_reload.png",
	"home": "res://assets/img/icons/nav_home.png",
	"star": "res://assets/img/icons/star.png",
	"offline": "res://assets/img/icons/offline.png",
	"cache": "res://assets/img/icons/cache.png",
	"portal": "res://assets/img/icons/site_portal.png",
	"cafe": "res://assets/img/icons/site_cafe.png",
	"myhome": "res://assets/img/icons/site_myhome.png",
}
## 본문 전용 고정폭 폰트. 페이지들이 한글 2칸/ASCII 1칸 격자로 짜여 있는데
## Galmuri는 그 비율이 아니라(ASCII가 한글의 0.8배) 표가 어긋난다.
const BODY_FONT := "res://assets/fonts/neodgm.ttf"
const BODY_FONT_SIZE := 16
const FALLBACK_FONT := "res://assets/fonts/Galmuri11.ttf"
const HOME_URL := "portal.nurinet.co.kr"
const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789.-/:"
const SAVED_PATTERN := "저장\\s*([0-9]{4}-[0-9]{2}-[0-9]{2}(?:\\s+[0-9]{2}:[0-9]{2})?)"

var _addr: LineEdit
var _grid: TextGrid
var _scroll: ScrollContainer
var _status_left: Label
var _status_right: Label
var _cache_icon: TextureRect
var _back_btn: Button
var _fwd_btn: Button
var _dialog: OSDialog
var _history: PackedStringArray = []
var _pos := -1
var _title := ""
var _tex_cache: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	col.add_child(_build_address_bar())
	col.add_child(_build_bookmarks())
	col.add_child(_build_page())
	col.add_child(_build_status_bar())
	_dialog = OSDialog.new()
	add_child(_dialog)
	navigate(HOME_URL)

# ── 구성 ──────────────────────────────────────────────────────────────────

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_back_btn = _tool_button("뒤로", ICON["back"], go_back)
	_fwd_btn = _tool_button("앞으로", ICON["forward"], go_forward)
	row.add_child(_back_btn)
	row.add_child(_fwd_btn)
	row.add_child(VSeparator.new())
	row.add_child(_tool_button("새로고침", ICON["reload"], _explain_offline))
	row.add_child(_tool_button("홈", ICON["home"], func(): navigate(HOME_URL)))
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
		b.add_theme_constant_override("icon_max_width", 16)
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
	# 이 브라우저가 네트워크에 못 나간다는 표시 — 주소 앞에 늘 붙어 있다
	var off := TextureRect.new()
	off.texture = _texture(ICON["offline"])
	off.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	off.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	off.custom_minimum_size = Vector2(16, 16)
	off.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	off.tooltip_text = "오프라인 — 캐시에서만 열립니다"
	row.add_child(off)
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.placeholder_text = "주소 입력"
	_addr.text_changed.connect(_filter_address)
	_addr.text_submitted.connect(func(t: String): navigate(t))
	row.add_child(_addr)
	var go := Button.new()
	go.text = "이동"
	go.focus_mode = Control.FOCUS_NONE
	go.add_theme_font_size_override("font_size", 14)
	go.pressed.connect(func(): navigate(_addr.text))
	row.add_child(go)
	bar.add_child(row)
	return bar

func _build_bookmarks() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var star := TextureRect.new()
	star.texture = _texture(ICON["star"])
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(16, 16)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	row.add_child(VSeparator.new())
	for bm in ContentDB.web_bookmarks():
		var url := String(bm["url"])
		var b := Button.new()
		b.theme_type_variation = "NuriFlat"
		b.text = String(bm["title"])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		var tex := _texture(_site_icon(url))
		if tex != null:
			b.icon = tex
			b.add_theme_constant_override("icon_max_width", 16)
		b.pressed.connect(func(): navigate(url))
		row.add_child(b)
	bar.add_child(row)
	return bar

func _body_font() -> Font:
	if not ResourceLoader.exists(BODY_FONT):
		return null
	var f: Font = load(BODY_FONT)
	# neodgm에 없는 글자(콘텐츠에서는 ※ 하나)는 본문 폰트로 떨어뜨린다.
	# 폴백은 없는 글자에만 쓰이므로 격자 정렬은 그대로다.
	if f.fallbacks.is_empty() and ResourceLoader.exists(FALLBACK_FONT):
		f.fallbacks = [load(FALLBACK_FONT)]
	return f

func _site_icon(url: String) -> String:
	if url.begins_with("myhome."):
		return ICON["myhome"]
	if url.begins_with("cafe."):
		return ICON["cafe"]
	return ICON["portal"]

func _build_page() -> Control:
	var field := PanelContainer.new()
	field.theme_type_variation = "NuriField"
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	_scroll = ScrollContainer.new()
	_grid = TextGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body_font := _body_font()
	if body_font != null:
		_grid.add_theme_font_override("font", body_font)
		_grid.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_grid.link_activated.connect(func(url: String): navigate(url))
	_grid.link_hovered.connect(_on_link_hovered)
	_scroll.add_child(_grid)
	pad.add_child(_scroll)
	field.add_child(pad)
	return field

func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriStatusBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_status_left = Label.new()
	_status_left.add_theme_font_size_override("font_size", 14)
	_status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_left.clip_text = true
	row.add_child(_status_left)
	_cache_icon = TextureRect.new()
	_cache_icon.texture = _texture(ICON["cache"])
	_cache_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cache_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cache_icon.custom_minimum_size = Vector2(16, 16)
	_cache_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cache_icon)
	_status_right = Label.new()
	_status_right.add_theme_font_size_override("font_size", 14)
	_status_right.add_theme_color_override("font_color", NuriTheme.TEXT_DIM)
	row.add_child(_status_right)
	bar.add_child(row)
	return bar

# ── 이동 ──────────────────────────────────────────────────────────────────

func navigate(url: String) -> Dictionary:
	var page := _render(url)
	# 같은 주소를 다시 누르면 기록을 쌓지 않는다
	if _pos < 0 or _history[_pos] != _current_url():
		_history.resize(_pos + 1)
		_history.append(_current_url())
		_pos = _history.size() - 1
	_sync_nav()
	return page

func _current_url() -> String:
	return _addr.text

func _render(url: String) -> Dictionary:
	var u := url.strip_edges().to_lower()
	_addr.text = u
	var page := ContentDB.web_page(u)
	if page.is_empty():
		_show_not_cached(u)
		return {}
	if String(page.get("requires", "")) == "puzzle3":
		GameState.try_answer("puzzle3", u)
	_title = String(page["title"])
	_grid.grid_text = String(page["body"])
	_set_window_title(_title)
	_status_left.text = "완료"
	_status_right.text = "오프라인 캐시 · %s 저장" % _saved_at(String(page["body"]))
	_cache_icon.visible = true
	if page.has("cid"):
		GameState.mark_read(String(page["cid"]))
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0
	return page

func _show_not_cached(u: String) -> void:
	# 캐시에 없는 주소. 퍼즐3에서 주소를 더듬는 플레이어에게 이 화면이 피드백이 된다.
	_title = "캐시에 없는 주소"
	_grid.grid_text = """■ 캐시에 없는 주소입니다

  이 컴퓨터에 저장된 오프라인 캐시에서 다음 주소를 찾을 수 없습니다.

     %s

  · 누리넷에 연결되어 있지 않으므로 서버에서 새로 받아올 수 없습니다.
  · 캐시는 주소 단위로 저장됩니다.
    상위 주소가 없어도 하위 주소는 남아 있을 수 있습니다.""" % u
	_set_window_title(_title)
	_status_left.text = "캐시 없음"
	_status_right.text = "저장된 사본 없음"
	_cache_icon.visible = false

func _saved_at(body: String) -> String:
	var re := RegEx.new()
	re.compile(SAVED_PATTERN)
	var m := re.search(body)
	return m.get_string(1) if m != null else "시각 미상"

func _set_window_title(page_title: String) -> void:
	var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
	if wm != null and wm.is_open("browser"):
		wm.set_window_title("browser", "%s — %s" % [page_title, ContentDB.ui("app_browser")])

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

func _sync_nav() -> void:
	_back_btn.disabled = _pos <= 0
	_fwd_btn.disabled = _pos >= _history.size() - 1

func _explain_offline() -> void:
	_dialog.show_message("새로고침할 수 없습니다",
		"이 페이지는 오프라인 캐시입니다.\n누리넷에 연결되어 있지 않아 서버에서 다시 받을 수 없습니다.",
		ICON["offline"])

func _on_link_hovered(url: String) -> void:
	_status_left.text = url if url != "" else "완료"

func _filter_address(t: String) -> void:
	# 스펙 §3: 플레이어 입력은 영숫자만 (주소라서 . - / : 은 허용)
	var filtered := ""
	for ch in t:
		if ch.to_lower() in ALLOWED:
			filtered += ch
	if filtered != t:
		_addr.text = filtered
		_addr.caret_column = filtered.length()

# --- 테스트용 접근자 ---

func page_title() -> String:
	return _title

func address_text() -> String:
	return _addr.text

func status_text() -> String:
	return _status_left.text

func cache_text() -> String:
	return _status_right.text

func can_go_back() -> bool:
	return _pos > 0

func can_go_forward() -> bool:
	return _pos >= 0 and _pos < _history.size() - 1

func link_count() -> int:
	return _grid.link_count()

func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = tex
	return tex
