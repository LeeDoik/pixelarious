class_name WindowManager
extends Control
## 창 레지스트리와 z-order. 자식 = 열린 OSWindow들 (마지막 자식이 최상위).

signal windows_changed(open_ids: Array)
signal app_focused(id: String)

const OS_WINDOW := preload("res://src/desktop/os_window.tscn")

var _apps: Dictionary = {}     # id -> {title, builder}
var _windows: Dictionary = {}  # id -> OSWindow
var _titles: Dictionary = {}   # id -> 창 제목 (작업표시줄 표기)
var _win_icons: Dictionary = {}  # id -> 아이콘 경로 (작업표시줄 표기)
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
			if c is OSWindow and (c as OSWindow).visible and Rect2((c as OSWindow).position, (c as OSWindow).size).has_point(local):
				focus_app((c as OSWindow).win_id)
				break

func _ready() -> void:
	add_to_group("window_manager")

func register_app(id: String, title: String, builder: Callable, icon: String = "") -> void:
	_apps[id] = {"title": title, "builder": builder, "icon": icon}

func open_app(id: String) -> void:
	if _windows.has(id):
		focus_app(id)
		return
	var app: Dictionary = _apps[id]
	open_window(id, app["title"], app["builder"].call(), Vector2(640, 480), app.get("icon", ""))

func open_window(id: String, title: String, content: Control, win_size: Vector2 = Vector2(640, 480), icon: String = "") -> void:
	## 등록된 앱 외의 동적 창(사진 뷰어 등)도 이 경로로 연다
	if _windows.has(id):
		if content != null and not content.is_inside_tree():
			content.queue_free()
		focus_app(id)
		return
	var w: OSWindow = OS_WINDOW.instantiate()
	add_child(w)
	w.setup(id, title, win_size, icon)
	w.set_content(content)
	w.position = Vector2(60, 40) + Vector2(28, 28) * (_cascade % 8)
	_cascade += 1
	w.request_close.connect(close_app)
	w.request_minimize.connect(toggle_minimize)
	w.focused.connect(focus_app)
	_windows[id] = w
	_titles[id] = title
	_win_icons[id] = icon
	windows_changed.emit(open_ids())
	app_focused.emit(id)
	_update_active_states()

func close_app(id: String) -> void:
	if not _windows.has(id):
		return
	_windows[id].queue_free()
	_windows.erase(id)
	_titles.erase(id)
	_win_icons.erase(id)
	windows_changed.emit(open_ids())
	_update_active_states()

func window_title(id: String) -> String:
	return String(_titles.get(id, id))

func window_icon(id: String) -> String:
	return String(_win_icons.get(id, ""))

func active_id() -> String:
	## 최상위의 보이는 창 — 작업표시줄이 눌린 상태로 표시할 대상
	for i in range(get_child_count() - 1, -1, -1):
		var c := get_child(i)
		if c is OSWindow and (c as OSWindow).visible and not c.is_queued_for_deletion():
			return (c as OSWindow).win_id
	return ""

func toggle_minimize(id: String) -> void:
	if not _windows.has(id):
		return
	var w: OSWindow = _windows[id]
	w.visible = not w.visible
	if w.visible:
		focus_app(id)
	else:
		_update_active_states()

func is_minimized(id: String) -> bool:
	return _windows.has(id) and not _windows[id].visible

func taskbar_clicked(id: String) -> void:
	## 실제 OS처럼: 최소화된 창 → 복원, 최상위 활성 창 → 최소화, 그 외 → 앞으로
	if not _windows.has(id):
		return
	var w: OSWindow = _windows[id]
	if not w.visible:
		w.visible = true
		focus_app(id)
	elif get_child(get_child_count() - 1) == w:
		w.visible = false
		_update_active_states()
	else:
		focus_app(id)

func focus_app(id: String) -> void:
	if not _windows.has(id):
		return
	move_child(_windows[id], get_child_count() - 1)
	app_focused.emit(id)
	_update_active_states()

func _update_active_states() -> void:
	# 최상위의 보이는 창만 활성 타이틀바, 나머지는 비활성(회색조)
	var top := active_id()
	for id in _windows:
		var w: OSWindow = _windows[id]
		w.set_active(String(id) == top)

func is_open(id: String) -> bool:
	return _windows.has(id)

func open_ids() -> Array:
	return _windows.keys()
