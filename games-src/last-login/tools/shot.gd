extends SceneTree
## 개발용 스크린샷 도구 — 바탕화면을 띄우고 몇 프레임 뒤 뷰포트를 PNG로 저장한다.
## 헤드리스로는 렌더가 안 되므로 실제 창을 잠깐 연다.
##
##   godot --path . -s tools/shot.gd -- <출력경로> [시나리오]
##
## 시나리오: explorer(기본) | details | locked | notepad | desktop | stack | settings | boot | splash | start | maximize | shutdown | msg | msgroom | msgchoice | msgwhere | msglogs | msgmissed | msgtell | msgask | msgname | help | mailzip | mailspam | weblucky | ending | endingsent | photo | photozoom | photobieum | mail | maillist | maillock | mailattach | web | webmyhome | webportal | web404 | webgate | webnotice | webboard | webboard231 | webdiary10 | trash | trashdetails | trashfail | trashpurge | trashblocked | trashdone
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
	if scenario in ["ending", "endingsent"]:
		# 두터운 증거로 끝까지 간 뒤 — 인쇄 길(숨은 신 포함) / 원본 길(슬기 방)
		var gs = root.get_node("/root/GameState")
		for f in ["puzzle1_solved", "puzzle3_solved", "final_diary_read", "puzzle5_solved", "puzzle6_solved",
				"office_matched", "accountant_named", "letter_read_aloud", "pickup_told", "intruder_found"]:
			gs.set_flag(f)
		for cid in root.get_node("/root/ContentDB").records():
			gs.mark_read(cid)
		gs.set_flag("ending_original" if scenario == "endingsent" else "ending_print")
		var e = load("res://src/ending/ending.gd").new()
		e.line_delay = 0.05
		e.shutdown_hold = 0.2
		root.add_child(e)
		e.play(true)
		await _settle(1200)
	elif scenario == "help":
		desktop.open_help()
		await _settle()
	elif scenario == "settings":
		# 오토로드도 이름으로 직접 쓰면 컴파일 시점에 없다 — 런타임에 노드로 집는다
		root.get_node("/root/Fx").set_volume(0.55)   # 홈과 손잡이가 둘 다 보이게
		root.get_node("/root/Fx").toggle_menu()
		await _settle()
	elif scenario in ["photo", "photozoom", "photobieum"]:
		wm.open_app("explorer")
		await _settle()
		var ex = _find_by_script(wm, "res://src/apps/explorer.gd")
		ex.open_file("s_photo5" if scenario == "photobieum" else "s_photo1")   # 필사본 — 맞춤으로는 손글씨가 안 읽히는 크기
		await _settle()
		var pv = _find_by_script(wm, "res://src/apps/photo.gd")
		if scenario == "photozoom":
			pv.set_zoom(2.0, pv.view_size() * 0.5)
		await _settle()
	elif scenario in ["msg", "msgroom", "msgchoice", "msgwhere", "msglogs", "msgmissed", "msgtell", "msgask", "msgname"]:
		wm.open_app("messenger")
		await _settle(60)          # 슬기의 첫 줄이 흘러나올 때까지 (창은 대화 목록으로 열린다)
		var m = _find_by_script(wm, "res://src/apps/messenger.gd")
		if scenario == "msgroom":
			m.open_room("live")
			await _settle()
		if scenario == "msgchoice":
			# n01의 delay_ms(1600) 뒤 스크립트가 스스로 n02(선택지 노드)로 넘어간다
			m.open_room("live")
			await _settle(260)
		if scenario == "msgwhere":
			# n02에서 답하면 n03이 "어디서요"를 묻는다 — 선택지 셋이
			# "보낼 말" 칸에 들어가는지는 눈으로만 확인된다
			m.open_room("live")
			await _settle(260)
			m._on_choice(0)
			await _settle(120)
		if scenario == "msglogs":
			m.open_log(2)          # 10-05 민규 — 시스템 줄이 섞인 가장 긴 로그
			await _settle()
		if scenario == "msgmissed":
			m.open_log(4)          # 부재중 쪽지 — 날짜 시스템 줄로 끊긴 석 달치
			await _settle()
		if scenario == "msgask":
			# 내게 쓴 메일을 말해준 뒤 — "물어보기" 묶음이 본선 선택지 아래에 선다
			m.open_room("live")
			await _settle(260)
			root.get_node("/root/GameState").mark_read("mail:m_self")
			root.get_node("/root/GameState").set_flag("told:mail:m_self")
			await _settle(30)
		if scenario == "msgname":
			# 우편함 이름 대기 — 예금주 넷이 선택지로 선다
			m.open_room("live")
			await _settle(260)
			var gs = root.get_node("/root/GameState")
			for f in ["office_matched", "told:ask:office_man", "told:doc:donation_ledger"]:
				gs.set_flag(f)
			await _settle(10)
			m._refresh_choices()
			m._on_tell("ask:mailbox_name")
			await _settle(40)
		if scenario == "msgtell":
			# n02 선택지 아래 "찾은 것 말하기" — 파일 셋을 읽은 상태
			m.open_room("live")
			await _settle(260)
			for cid in ["doc:essay_2001", "doc:jesa_memo", "img:window_night"]:
				root.get_node("/root/GameState").mark_read(cid)
			await _settle(30)
	elif scenario == "mailzip":
		# 정리.zip을 푼 뒤 — 탐색기 창이 압축 폴더(섬)로 열린다
		root.get_node("/root/GameState").set_flag("puzzle5_solved")
		wm.open_app("mail")
		await _settle()
		var mail = _find_by_script(wm, "res://src/apps/mail.gd")
		mail.open_mail("m_self")
		await _settle()
		mail.open_attachment("m_self")
		await _settle()
	elif scenario == "mailspam":
		# 스팸 메일 — 본문 안의 "지금 바로 클릭"이 링크로 보인다
		wm.open_app("mail")
		await _settle()
		_find_by_script(wm, "res://src/apps/mail.gd").open_mail("m_spam_1")
		await _settle()
	elif scenario in ["mail", "maillist", "maillock", "mailattach"]:
		wm.open_app("mail")
		await _settle()
		var ml = _find_by_script(wm, "res://src/apps/mail.gd")
		if scenario != "maillist":        # maillist는 열자마자 뜨는 받은 편지함
			ml.open_mail("m1")            # 첨부(퍼즐2)가 달린 메일 — 목록 대신 이 한 장이 뜬다
		if scenario in ["maillock", "mailattach"]:
			ml.open_attachment("m1")      # 잠긴 첨부 → 암호 요구
		if scenario == "mailattach":
			ml.submit_password("030703")  # 암호를 풀면 첨부도 한 장으로 열린다
		await _settle()
	elif scenario in ["web", "webmyhome", "webportal", "web404", "webgate", "webnotice", "webboard", "webboard231", "webdiary10", "weblucky"]:
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
		elif scenario == "webgate":
			target = "cafe.nurinet.co.kr/saebit/gate"
		elif scenario == "webnotice":
			target = "cafe.nurinet.co.kr/saebit/notice"
		elif scenario == "webboard":
			target = "cafe.nurinet.co.kr/saebit/board"
		elif scenario == "webboard231":
			target = "cafe.nurinet.co.kr/saebit/board/231"
		elif scenario == "webdiary10":
			target = "myhome.nurinet.co.kr/sj2002/diary/10"
		elif scenario == "weblucky":
			target = "nurinet-event.co.kr/lucky3"
		br.navigate(target)
		await _settle()
	elif scenario in ["trash", "trashdetails", "trashfail", "trashpurge", "trashblocked", "trashdone"]:
		wm.open_app("trash")
		await _settle()
		var tr = _find_by_script(wm, "res://src/apps/trash.gd")
		if scenario == "trashdetails":
			tr.set_view_mode(VIEW_DETAILS)
			tr.select("t1")
		elif scenario == "trashfail":
			tr.restore_sec = 0.05
			tr._begin_restore("t2")      # 손상 파일 — 막대가 멈추고 오류창이 겹친다
			await _settle(90)
		elif scenario == "trashpurge":
			tr.ask_purge()
		elif scenario == "trashblocked":
			tr.purge()                   # 비운 뒤: 손상된 넷은 사라지고 유서 한 장만 남는다
		elif scenario == "trashdone":
			tr.restore("t1")             # 복원 뒤: 목록 4개 + 메모장 창
		else:
			tr.select("t1")
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
