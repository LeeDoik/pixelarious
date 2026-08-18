class_name TextGrid
extends Control
## 한글 2칸 / ASCII 1칸 터미널 격자로 텍스트를 그린다. 본문 안의 주소는 링크가 된다.
##
## web.json의 페이지들은 이 격자를 가정하고 손으로 짜였다 — 게시판 표, 점선 리더,
## 박스 그리기. 칸 수를 폰트 자체의 글자폭에서 계산하므로 어떤 글리프가 와도 열이 맞는다.
##
## 다만 폰트가 실제로 2:1이어야 한다. 이 앱이 neodgm(Neo둥근모)을 따로 쓰는 이유가
## 그것이다 — Galmuri는 ASCII 최대폭이 한글의 0.8배라(모든 크기에서) 숫자·영문이
## 다음 칸을 3px씩 침범한다. 폰트 크기로는 해결되지 않는다.

signal link_activated(url: String)
signal link_hovered(url: String)

## 호스트처럼 생긴 토큰. 날짜(2002.11.02)가 걸리지 않게 뒤에서 한 번 더 거른다.
const HOST_PATTERN := "[a-zA-Z0-9][a-zA-Z0-9\\-]*(\\.[a-zA-Z0-9\\-]+)+(/[a-zA-Z0-9._~%/\\-]*)?"
const MIN_HOST_DOTS := 2

@export var link_color := Color("1b4d8f")

var grid_text := "":
	set(value):
		grid_text = value
		_rebuild()

var _font: Font
var _font_size := 16
var _cell := Vector2(8, 20)
var _lines: PackedStringArray = []
var _line_cols: Array[PackedInt32Array] = []
var _links: Array[Dictionary] = []
var _width_cache: Dictionary = {}
var _hovered := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_metrics()
	_rebuild()

func _refresh_metrics() -> void:
	# add_theme_font_override("font", ...)가 있으면 그것을, 없으면 테마 기본을 쓴다
	_font = get_theme_font("font") if has_theme_font_override("font") else get_theme_default_font()
	_font_size = get_theme_font_size("font_size") if has_theme_font_size_override("font_size") else get_theme_default_font_size()
	if _font == null:
		return
	# 한 칸 = 한글 글자 폭의 절반. 이 폰트에서 한글은 항상 폰트 크기와 같은 폭이다.
	var wide := _font.get_string_size("가", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	_cell = Vector2(maxf(wide * 0.5, 1.0), _font.get_height(_font_size) + 2.0)
	_width_cache.clear()

func _cells_for(ch: String) -> int:
	if _width_cache.has(ch):
		return _width_cache[ch]
	var n := 1
	if _font != null:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		n = maxi(1, int(round(w / _cell.x)))
	_width_cache[ch] = n
	return n

func _rebuild() -> void:
	_lines = grid_text.split("\n")
	_line_cols.clear()
	_links.clear()
	if _font == null:
		return
	var re := RegEx.new()
	re.compile(HOST_PATTERN)
	var widest := 0
	for row in _lines.size():
		var line := _lines[row]
		var cols := PackedInt32Array()
		var col := 0
		for i in line.length():
			cols.append(col)
			col += _cells_for(line[i])
		cols.append(col)          # 끝 경계 (링크 폭 계산용)
		_line_cols.append(cols)
		widest = maxi(widest, col)
		for m in re.search_all(line):
			var url := m.get_string()
			if not _is_url(url):
				continue
			var c0 := cols[m.get_start()]
			var c1 := cols[m.get_end()]
			_links.append({
				"url": url,
				"rect": Rect2(c0 * _cell.x, row * _cell.y, (c1 - c0) * _cell.x, _cell.y),
			})
	custom_minimum_size = Vector2(widest * _cell.x, _lines.size() * _cell.y)
	queue_redraw()

func _is_url(s: String) -> bool:
	# "2002.11.02" 같은 날짜를 링크로 만들지 않기 위한 검사 — 마지막 라벨이 글자여야 한다
	var host := s.split("/")[0]
	var labels := host.split(".")
	if labels.size() < MIN_HOST_DOTS + 1:
		return false
	var last: String = labels[labels.size() - 1]
	if last.length() < 2:
		return false
	for i in last.length():
		if not (last[i] >= "a" and last[i] <= "z") and not (last[i] >= "A" and last[i] <= "Z"):
			return false
	return true

func _draw() -> void:
	if _font == null:
		return
	var ascent := _font.get_ascent(_font_size)
	var body := get_theme_color("font_color", "Label")
	for row in _lines.size():
		var line := _lines[row]
		var cols := _line_cols[row] if row < _line_cols.size() else PackedInt32Array()
		var y := row * _cell.y + ascent
		for i in line.length():
			var ch := line[i]
			if ch == " ":
				continue
			var col: int = cols[i] if i < cols.size() else 0
			var pos := Vector2(col * _cell.x, y)
			_font.draw_char(get_canvas_item(), pos, ch.unicode_at(0), _font_size,
				link_color if _in_link(row, col) else body)
	for link in _links:
		var r: Rect2 = link["rect"]
		draw_line(Vector2(r.position.x, r.end.y - 3.0), Vector2(r.end.x, r.end.y - 3.0), link_color, 1.0)

func _in_link(row: int, col: int) -> bool:
	var y := row * _cell.y
	for link in _links:
		var r: Rect2 = link["rect"]
		if is_equal_approx(r.position.y, y) and col * _cell.x >= r.position.x and col * _cell.x < r.end.x:
			return true
	return false

func _link_at(p: Vector2) -> String:
	for link in _links:
		if (link["rect"] as Rect2).has_point(p):
			return String(link["url"])
	return ""

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var url := _link_at((e as InputEventMouseMotion).position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if url != "" else Control.CURSOR_ARROW
		if url != _hovered:
			_hovered = url
			link_hovered.emit(url)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var url := _link_at((e as InputEventMouseButton).position)
		if url != "":
			link_activated.emit(url)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_metrics()
		_rebuild()
	elif what == NOTIFICATION_MOUSE_EXIT and _hovered != "":
		_hovered = ""
		link_hovered.emit("")

# --- 테스트용 접근자 ---

func cell_size() -> Vector2:
	return _cell

func line_count() -> int:
	return _lines.size()

func link_count() -> int:
	return _links.size()

func links() -> Array[Dictionary]:
	return _links

func column_of(row: int, index: int) -> int:
	## row행 index번째 글자가 놓이는 칸 번호 (열 정렬 회귀 테스트용)
	if row < 0 or row >= _line_cols.size():
		return -1
	var cols := _line_cols[row]
	return cols[index] if index < cols.size() else -1
