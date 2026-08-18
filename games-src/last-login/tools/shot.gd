extends SceneTree
## 개발용 스크린샷 도구 — 바탕화면을 띄우고 몇 프레임 뒤 뷰포트를 PNG로 저장한다.
## 헤드리스로는 렌더가 안 되므로 실제 창을 잠깐 연다.
##
##   godot --path . -s tools/shot.gd -- <출력경로> [시나리오]
##
## 시나리오: explorer(기본) | details | locked | notepad | desktop | stack | settings | boot | splash | start | maximize | shutdown | msg | msgchoice | msglogs | mail | maillock | web | webmyhome | webportal | web404
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
	if scenario == "boot" or scenario == "splash":
		root.add_child(load("res://src/boot/boot.tscn").instantiate())
		await _settle(120 if scenario == "boot" else 420)   # POST 도중 / 스플래시
		_save(out, scenario)
		return
	var desktop: Node = load("res://src/desktop/desktop.tscn").instantiate()
	root.add_child(desktop)
	await _settle()
	var wm = desktop.wm
	if scenario == "settings":
		# 오토로드도 이름으로 직접 쓰면 컴파일 시점에 없다 — 런타임에 노드로 집는다
		root.get_node("/root/Fx").set_volume(0.55)   # 홈과 손잡이가 둘 다 보이게
		root.get_node("/root/Fx").toggle_menu()
		await _settle()
	elif scenario == "msg" or scenario == "msgchoice" or scenario == "msglogs":
		wm.open_app("messenger")
		await _settle(60)          # 슬기의 첫 줄이 흘러나올 때까지
		if scenario == "msgchoice":
			# n01의 delay_ms(1600) 뒤 스크립트가 스스로 n02(선택지 노드)로 넘어간다
			await _settle(260)
		if scenario == "msglogs":
			var m = _find_by_script(wm, "res://src/apps/messenger.gd")
			for t in _walk(m):
				if t is TabContainer:
					t.current_tab = 1
					break
			var msg = _find_by_script(wm, "res://src/apps/messenger.gd")
			msg.open_log(2)          # 10-05 민규 — 시스템 줄이 섞인 가장 긴 로그
			await _settle()
	elif scenario == "mail" or scenario == "maillock":
		wm.open_app("mail")
		await _settle()
		var ml = _find_by_script(wm, "res://src/apps/mail.gd")
		ml.open_mail("m1")            # 첨부(퍼즐2)가 달린 메일
		if scenario == "maillock":
			ml.open_attachment("m1")   # 잠긴 첨부 → 암호 요구
		await _settle()
	elif scenario in ["web", "webmyhome", "webportal", "web404"]:
		wm.open_app("browser")
		await _settle()
		var br = _find_by_script(wm, "res://src/apps/browser.gd")
		var target := "cafe.nurinet.co.kr/gongsi9"
		if scenario == "webmyhome":
			target = "myhome.nurinet.co.kr/sj2002"
		elif scenario == "webportal":
			target = "portal.nurinet.co.kr"
		elif scenario == "web404":
			target = "cafe.nurinet.co.kr/saebit/list"
		br.navigate(target)
		await _settle()
	elif scenario == "shutdown":
		root.get_node("/root/GameState").set_flag("ending_start")
		await _settle(30)
	elif scenario == "start":
		desktop.select_icon("explorer")
		desktop._toggle_start_menu()
		await _settle()
	elif scenario == "maximize":
		wm.open_app("explorer")
		await _settle()
		wm.get_child(wm.get_child_count() - 1).toggle_maximize()
		await _settle()
	elif scenario == "stack":
		for app in ["explorer", "mail", "messenger"]:
			wm.open_app(app)
		await _settle()
	elif scenario != "desktop":
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
	_save(out, scenario)

func _save(out: String, scenario: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("shot: %s (%s) err=%d" % [out, scenario, err])
	quit(0 if err == OK else 1)

func _settle(frames: int = SETTLE_FRAMES) -> void:
	for i in frames:
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
