class_name WindowManager
extends Control
## 창 레지스트리와 z-order. 자식 = 열린 OSWindow들 (마지막 자식이 최상위).

signal windows_changed(open_ids: Array)
signal app_focused(id: String)

const OS_WINDOW := preload("res://src/desktop/os_window.tscn")

var _apps: Dictionary = {}     # id -> {title, builder}
var _windows: Dictionary = {}  # id -> OSWindow
var _cascade := 0

func _init() -> void:
	# 전체 화면을 덮는 배치용 레이어 — 히트테스트에서 빠져야 아래의 바탕화면 아이콘이 클릭된다
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(e: InputEvent) -> void:
	# 창 내부 어디를 클릭해도(콘텐츠 위젯 포함) 그 창을 앞으로 — 실제 OS의 클릭-투-프런트.
	# 클릭 지점을 포함하는 창 중 최상위 하나만 올린다 (겹친 창에서 아래 창이 새치기하지 않게).
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (make_input_local(e) as InputEventMouseButton).position
		for i in range(get_child_count() - 1, -1, -1):
			var c := get_child(i)
			if c is OSWindow and Rect2((c as OSWindow).position, (c as OSWindow).size).has_point(local):
				focus_app((c as OSWindow).win_id)
				break

func register_app(id: String, title: String, builder: Callable) -> void:
	_apps[id] = {"title": title, "builder": builder}

func open_app(id: String) -> void:
	if _windows.has(id):
		focus_app(id)
		return
	var app: Dictionary = _apps[id]
	var w: OSWindow = OS_WINDOW.instantiate()
	add_child(w)
	w.setup(id, app["title"], Vector2(640, 480))
	w.set_content(app["builder"].call())
	w.position = Vector2(60, 40) + Vector2(28, 28) * (_cascade % 8)
	_cascade += 1
	w.request_close.connect(close_app)
	w.focused.connect(focus_app)
	_windows[id] = w
	windows_changed.emit(open_ids())
	app_focused.emit(id)

func close_app(id: String) -> void:
	if not _windows.has(id):
		return
	_windows[id].queue_free()
	_windows.erase(id)
	windows_changed.emit(open_ids())

func focus_app(id: String) -> void:
	if not _windows.has(id):
		return
	move_child(_windows[id], get_child_count() - 1)
	app_focused.emit(id)

func is_open(id: String) -> bool:
	return _windows.has(id)

func open_ids() -> Array:
	return _windows.keys()
