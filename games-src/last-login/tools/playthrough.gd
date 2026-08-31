extends SceneTree
## 완주 시뮬레이터 — 실제 ChatPlayer·GameState·ContentDB로 처음부터 엔딩까지 밟아본다.
##
##   godot --headless --path . -s tools/playthrough.gd
##
## 자물쇠 앞에 서면 "플레이어가 할 수 있는 일"만으로 연다. 열쇠를 미리 뿌리지 않는다 —
## 말해주기·물어보기의 require가 실제로 그 시점에 차 있는지가 이 도구의 핵심 검사다.
##
## 주의: `-s` 스크립트는 오토로드 등록 전에 컴파일된다. 전부 동적으로 다룰 것(shot.gd와 같은 규칙).

var _gs
var _db
var _cp
var _tells: Array = []
var _fail := 0
var _step := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_gs = root.get_node("/root/GameState")
	_db = root.get_node("/root/ContentDB")
	_gs.reset()
	var thread: Dictionary = _db.chat_thread()
	_tells = _db.tells()
	_cp = load("res://src/core/chat_player.gd").new(thread, _gs)

	print("=== LAST LOGIN 완주 시뮬레이션 ===\n")

	# 1막 — 슬기와 만나고 잠긴 폴더 앞까지
	_walk("도입")

	_solve("puzzle1", "20020316", "봄이 일지에서 찾은 날짜를 폴더 암호로")
	_walk("악장 2")
	_solve("puzzle2", "030703", "필사_2의 새빛력 날짜")
	_walk("악장 3")
	_solve("puzzle3", "cafe.nurinet.co.kr/saebit/gate", "초대 메일의 관문 주소를 직접 입력")
	_walk("관문 뒤")

	# 유서 — 휴지통 복원
	_solve("puzzle4", "t1", "휴지통에서 2002년 파일 t1을 복원")
	_gs.restore_node("t1")
	_read("doc:diary_final")
	_gs.set_flag("final_diary_read")
	_walk("종반 진입")

	# --- 여기부터가 이번에 새로 단 자물쇠 ---
	_gate_report("puzzle5")
	_read("mail:m_self")
	_tell("mail:m_self")                 # 슬기에게 말해주기
	_ask("birthday")                     # 연도는 슬기 입에서만 나온다
	_solve("puzzle5", "19810428", "슬기 생일 여덟 자리로 정리.zip")
	_walk("정리.zip 뒤")

	_gate_report("puzzle6")
	_read("doc:numbers")
	_tell("doc:numbers")                 # K2 — office_matched
	_read("doc:donation_ledger")
	_tell("doc:donation_ledger")
	_ask("office_man")
	_ask_choose("mailbox_name", "최영식")
	_walk("회계 이름 뒤")

	# 엔딩 — g4l에서 멈춰 있다
	_choose_first()
	_walk("엔딩", [])

	print("\n=== 결과 ===")
	print("마지막 노드: %s" % _cp.current_id())
	print("퍼즐 해결: %s" % _solved_list())
	print("기록물: %d/9" % _gs.records_count())
	var epi = load("res://src/ending/ending.gd").epilogue_lines()
	print("\n--- 이 플레이의 에필로그 ---")
	for l in epi:
		if String(l) != "":
			print("  " + String(l))
	_dup_scan()
	if _fail > 0:
		print("\n*** 막힌 곳 %d군데 ***" % _fail)
	else:
		print("\n막힌 곳 없음 — 완주 가능")
	quit(1 if _fail > 0 else 0)

# --- 진행 ---

func _walk(label: String, stop_at: Array = ["g4l", "g4m"]) -> void:
	var moved := 0
	while moved < 200:
		if stop_at.has(_cp.current_id()):
			break
		var cur = _cp.current()
		if cur.has("choices"):
			var picked := -1
			for i in cur["choices"].size():
				if _cp.gate_open(cur["choices"][i].get("require", "")):
					picked = i
					break
			if picked < 0:
				break
			print("  · (진행 선택) %s" % String(cur["choices"][picked]["text"]))
			_cp.choose(picked)
			moved += 1
			continue
		if not _cp.advance():
			break
		moved += 1
	_step += 1
	var cur = _cp.current()
	var kind := "선택지 %d개" % cur["choices"].size() if cur.has("choices") else ("자물쇠 대기: " + String(_next_req())) if cur.has("next") else "끝 노드"
	print("[%02d] %-14s %d줄 진행 → %s (%s)" % [_step, label, moved, _cp.current_id(), kind])

func _next_req() -> String:
	var cur = _cp.current()
	if not cur.has("next"):
		return ""
	return String(_db.chat_thread()["nodes"][cur["next"]].get("require", ""))

func _choose_first() -> void:
	var cur = _cp.current()
	if not cur.has("choices"):
		print("  !! 선택지를 기대했는데 없다 (%s)" % _cp.current_id())
		_fail += 1
		return
	for i in cur["choices"].size():
		if _cp.gate_open(cur["choices"][i].get("require", "")):
			print("  · 선택: %s" % String(cur["choices"][i]["text"]))
			_cp.choose(i)
			return
	print("  !! 고를 수 있는 선택지가 없다 (%s)" % _cp.current_id())
	_fail += 1

func _solve(pid: String, answer: String, how: String) -> void:
	var ok: bool = _gs.try_answer(pid, answer)
	if not ok and _db.puzzle(pid).get("answer", "") == "":
		ok = _gs.has_flag(pid + "_solved")
	print("  · %s ← %s %s" % [pid, how, "OK" if ok else "!! 실패"])
	if not ok:
		_fail += 1

func _read(cid: String) -> void:
	_gs.mark_read(cid)

# 말해주기 — require가 지금 차 있어야 하고, 응답 노드를 끝까지 밟고 돌아온다
func _tell(cid: String) -> void:
	_detour_entry("cid", cid)

func _ask(id: String) -> void:
	_detour_entry("id", id)

func _detour_entry(key: String, val: String) -> void:
	for t in _tells:
		if String(t.get(key, "")) != val:
			continue
		if not _cp.gate_open(t.get("require", "")):
			print("  !! '%s'를 말할/물을 수 없다 — require %s 미충족" % [val, JSON.stringify(t.get("require", ""))])
			_fail += 1
			return
		_cp.detour(String(t["node"]))
		_gs.set_flag("told:" + (val if key == "cid" else "ask:" + val))
		var guard := 0
		while _cp.advance() and guard < 40:
			guard += 1
		# 응답 안에 선택지가 있으면(예: 이름 고르기) 호출자가 따로 처리한다
		if not _cp.current().has("choices"):
			_cp.pop_detour()
		print("  · %s: \"%s\"" % ["물어봄" if key == "id" else "말해줌", String(t["say"])])
		return
	print("  !! 그런 말해주기 항목이 없다: %s=%s" % [key, val])
	_fail += 1

func _ask_choose(id: String, want: String) -> void:
	_detour_entry("id", id)
	var cur = _cp.current()
	if not cur.has("choices"):
		print("  !! %s 뒤에 선택지가 없다" % id)
		_fail += 1
		return
	for i in cur["choices"].size():
		if String(cur["choices"][i]["text"]).findn(want) >= 0:
			print("  · 고름: %s" % String(cur["choices"][i]["text"]))
			_cp.choose(i)
			var guard := 0
			while _cp.advance() and guard < 40:
				guard += 1
			if _cp.in_detour():
				_cp.pop_detour()
			return
	print("  !! '%s' 선택지가 없다" % want)
	_fail += 1

## Messenger._current_gate()와 같은 규칙 — 첫 미해결 퍼즐, hint_after 미충족은 건너뛴다
func _hint_gate() -> String:
	for pid in _db.puzzle_ids():
		if _gs.has_flag(String(pid) + "_solved"):
			continue
		var after = _db.puzzle(String(pid)).get("hint_after", "")
		if String(after) != "" and not _cp.gate_open(after):
			continue
		return String(pid)
	return ""

func _gate_report(pid: String) -> void:
	var req := _next_req()
	var hg := _hint_gate()
	print("  ── 본선이 %s에서 대기 (요구 %s) · 힌트가 가리키는 퍼즐: %s" % [_cp.current_id(), req, hg if hg != "" else "없음(!)"])
	if hg != pid:
		print("  !! 힌트가 %s를 가리켜야 하는데 '%s'다 — 막히면 힌트도 안 나온다" % [pid, hg])
		_fail += 1
	if req != pid + "_solved":
		print("  !! %s를 요구할 자리인데 '%s'다" % [pid, req])
		_fail += 1

func _solved_list() -> String:
	var out: Array[String] = []
	for pid in _db.puzzle_ids():
		if _gs.has_flag(pid + "_solved"):
			out.append(pid)
	return ", ".join(out)


## 대사·힌트끼리 8글자 넘게 겹치는 곳 — humanize는 새 글을 고립해서 보므로 이걸 못 잡는다.
## 새 대사를 넣고 나면 여기서 걸러진다(고유명사·주소는 겹쳐도 정상이라 눈으로 판단할 것).
const NGRAM := 8

func _dup_scan() -> void:
	var texts: Dictionary = {}
	for k in _db.chat_thread()["nodes"]:
		texts[k] = String(_db.chat_thread()["nodes"][k].get("text", ""))
	for pid in _db.puzzle_ids():
		var hs: Array = _db.puzzle(String(pid)).get("hints", [])
		for i in hs.size():
			var h = hs[i]
			texts["%s힌트%d" % [pid, i + 1]] = String(h) if typeof(h) == TYPE_STRING else String(h.get("text", ""))
	var seen: Dictionary = {}   # ngram -> 첫 주인
	var hits: Dictionary = {}   # ngram -> [주인들]
	for k in texts:
		var t: String = String(texts[k]).replace("
", " ")
		var i := 0
		while i + NGRAM <= t.length():
			var g := t.substr(i, NGRAM)
			if g.strip_edges().length() == NGRAM:
				if seen.has(g) and seen[g] != k:
					if not hits.has(g):
						hits[g] = [seen[g]]
					if not hits[g].has(k):
						hits[g].append(k)
				elif not seen.has(g):
					seen[g] = k
			i += 1
	print("
--- 대사 중복 스캔 (%d글자 이상) ---" % NGRAM)
	if hits.is_empty():
		print("  겹치는 곳 없음")
		return
	for g in hits:
		print("  \"%s\"  ← %s" % [g, ", ".join(PackedStringArray(hits[g]))])
