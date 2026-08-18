extends SceneTree
## 개발용 스크린샷 도구 — 바탕화면을 띄우고 몇 프레임 뒤 뷰포트를 PNG로 저장한다.
## 헤드리스로는 렌더가 안 되므로 실제 창을 잠깐 연다.
##
##   godot --path . -s tools/shot.gd -- <출력경로> [시나리오]
##
## 시나리오: explorer(기본) | details | locked | notepad | desktop
##
## 주의: `-s`로 실행되는 스크립트는 오토로드가 등록되기 전에 컴파일된다.
## 여기서 프로젝트 클래스를 정적 타입으로 참조하면 그 스크립트가 딸려 컴파일되면서
## "Identifier not found: ContentDB"로 죽는다 — 전부 동적으로 다룰 것.

const SETTLE_FRAMES := 12
const VIEW_DETAILS := 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "shot.png"
	var scenario: String = args[1] if args.size() > 1 else "explorer"
	var desktop: Node = load("res://src/desktop/desktop.tscn").instantiate()
	root.add_child(desktop)
	await _settle()
	var wm = desktop.wm
	if scenario != "desktop":
		wm.open_app("explorer")
		await _settle()
		var explorer = _find_by_script(wm, "res://src/apps/explorer.gd")
		match scenario:
			"details":
				explorer.set_view_mode(VIEW_DETAILS)
			"locked":
				explorer.open_folder("locked")
			"notepad":
				explorer.open_file("f_essay")
		await _settle()
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("shot: %s (%s) err=%d" % [out, scenario, err])
	quit(0 if err == OK else 1)

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame

func _find_by_script(from: Node, script_path: String):
	var want := load(script_path)
	for node in _walk(from):
		if node.get_script() == want:
			return node
	return null

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out
