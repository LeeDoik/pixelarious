extends GdUnitTestSuite

## 이 스위트가 막는 사고: 문서는 본문에 자기가 쓰인 날짜를 적어두고, 탐색기 '자세히 보기'는
## 그 옆 칸에 파일 수정시각을 나란히 보여준다. 둘이 어긋나면 — 9월 22일에 옮겨 적었다는 글이
## 8월 25일에 저장돼 있으면 — 두 칸을 같이 보는 순간 세계가 무너진다.
##
## mtime은 UI 장식이 아니라 서사 데이터다. 그런데 화면을 봐서는 절대 안 잡힌다:
## 문서를 열어야 본문 날짜를 알고, 목록으로 돌아와야 파일 날짜를 안다.
## 실제로 '자세히 보기'를 만들면서 채워 넣은 mtime 중 11개가 본문과 어긋나 있었다.

const FS_PATH := "res://content/fs.json"
const CHAT_PATH := "res://content/chat.json"

## 각 문서가 본문에서 스스로 밝히는 "여기까지 썼다"는 시점.
## 빈 문자열 = 본문에 시점 표기가 없는 문서(검사 대상 아님).
## **새 문서를 추가하면 여기에도 한 줄 추가할 것** — 빠뜨리면 아래 테스트가 실패한다.
const WRITTEN := {
	"doc:essay_2001": "2002-04-09",       # 낙방 수기
	"doc:resume": "",
	"doc:resume_final": "2002-06-02",     # (파일 저장 : 2002-06-02)
	"doc:study_memo": "2002-08-06",       # 마지막 줄 "2002. 8. 6 — 안 나감."
	"doc:plan_2002": "2002-11-01",        # "* 11월 추가"
	"doc:jesa_memo": "2002-10-16",        # "10/16 추가" (제삿날 10/17은 미래 예정일)
	"doc:bomi_log": "2002-10-30",
	"doc:budget_2002": "",
	"doc:bookmarks_memo": "2002-08-20",   # "포맷하기 전에 백업 (2002. 8. 20)"
	"doc:doctrine_1": "2002-07-28",       # "(2002. 7. 28 옮겨 적음)"
	"doc:doctrine_2": "2002-08-11",
	"doc:doctrine_3": "2002-09-22",
	"doc:retreat_review": "2002-08-05",
	"doc:retreat_notes": "",
	"doc:vow": "2002-09-30",              # 새빛력 4년 9월 30일 = 2002-09-30
	"doc:donation_ledger": "2002-11-01",  # 표 마지막 행
	"doc:quit_plan": "2002-11-01",
	"doc:evidence_memo": "2002-11-01",    # "(11. 1 밤에 적음)"
	"doc:debt_note": "2002-11-01",        # "[11.1 추가]"
	"doc:letter_unsent": "2002-10-30",
	"doc:diary_final": "2002-11-02",      # "(마지막 저장 : 2002-11-02 23:38)"
	"doc:corrupt_0930": "",
	"doc:corrupt_1015": "",
	"doc:corrupt_doctrine4": "",
	"doc:corrupt_temp": "",
}

## 성진이 이 컴퓨터를 마지막으로 쓴 순간. 대화 로그의 시스템 줄과 같아야 한다.
const LAST_LOGIN := "2002-11-02 23:41"

func _nodes() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(FS_PATH))["nodes"]

func test_every_document_declares_when_it_was_written() -> void:
	# 표에 없는 문서가 생기면 아무도 본문과 대조하지 않은 채로 지나간다
	for n in _nodes():
		var cid := String(n.get("cid", ""))
		if not cid.begins_with("doc:"):
			continue
		assert_bool(WRITTEN.has(cid)).override_failure_message(
			"%s(%s)가 WRITTEN 표에 없다 — 본문의 마지막 날짜를 적어 넣을 것" % [n["name"], cid]
		).is_true()

func test_file_is_never_saved_before_its_own_text_was_written() -> void:
	for n in _nodes():
		var cid := String(n.get("cid", ""))
		var written: String = WRITTEN.get(cid, "")
		if written == "":
			continue
		var mtime := String(n.get("mtime", ""))
		assert_bool(mtime.substr(0, 10) >= written).override_failure_message(
			"%s: 본문은 %s에 썼다는데 파일 수정시각은 %s다" % [n["name"], written, mtime]
		).is_true()

func test_folder_is_never_older_than_what_it_holds() -> void:
	var nodes := _nodes()
	var newest := {}
	for n in nodes:
		var parent := String(n.get("parent", ""))
		var mtime := String(n.get("mtime", ""))
		if mtime > String(newest.get(parent, "")):
			newest[parent] = mtime
	for n in nodes:
		if String(n.get("type", "")) != "folder":
			continue
		var id := String(n["id"])
		if not newest.has(id):
			continue
		assert_bool(String(n.get("mtime", "")) >= String(newest[id])).override_failure_message(
			"폴더 %s(%s)가 그 안의 가장 최근 파일(%s)보다 과거다" % [n["name"], n.get("mtime"), newest[id]]
		).is_true()

func test_nothing_is_deleted_before_it_was_last_saved() -> void:
	for n in _nodes():
		if String(n.get("parent", "")) != "trash":
			continue
		var mtime := String(n.get("mtime", ""))
		var deleted := String(n.get("deleted", ""))
		assert_bool(deleted >= mtime).override_failure_message(
			"%s: 수정(%s)보다 삭제(%s)가 먼저다" % [n["name"], mtime, deleted]
		).is_true()

func test_the_last_session_ends_at_the_last_login() -> void:
	# 이 게임의 제목이 걸린 순간이다. 유서를 저장하고(23:38) 지운 뒤(23:40)
	# 슬기에게 마지막 말을 남기고 접속이 끊긴다(23:41). 이 순서가 뒤집히면 안 된다.
	var t1 := {}
	var temp := {}
	for n in _nodes():
		if String(n["id"]) == "t1":
			t1 = n
		elif String(n["id"]) == "t5":
			temp = n
	assert_str(String(t1.get("mtime", ""))).is_equal("2002-11-02 23:38")
	assert_bool(String(t1.get("deleted", "")) < LAST_LOGIN).override_failure_message(
		"유서는 마지막 접속 전에 지워져 있어야 한다").is_true()
	assert_bool(String(temp.get("mtime", "")) <= LAST_LOGIN).is_true()
	var chat := FileAccess.get_file_as_string(CHAT_PATH)
	assert_str(chat).override_failure_message(
		"대화 로그의 마지막 접속 시각이 바뀌었다 — LAST_LOGIN 상수와 맞출 것"
	).contains("11월 2일 오후 11시 41분")

func test_every_node_carries_a_usable_timestamp() -> void:
	var re := RegEx.new()
	re.compile("^20\\d{2}-\\d{2}-\\d{2} \\d{2}:\\d{2}$")
	for n in _nodes():
		var mtime := String(n.get("mtime", ""))
		assert_bool(re.search(mtime) != null).override_failure_message(
			"%s의 수정시각 '%s'이 'YYYY-MM-DD HH:MM' 꼴이 아니다 — 자세히 보기가 그대로 뱉는다"
				% [n.get("name", n.get("id")), mtime]
		).is_true()

## 사진은 찍힌 날짜를 가진다. 다섯 장 중 네은 사건 당일이고 둘은 파일명에
## 날짜가 박혀 있다(0804·1029). 탐색기 '자세히 보기'가 이 칸을 그대로 뿌리므로,
## 한 장만 다른 날짜를 가지면 목록에서 바로 틄린다.
##
## 봄이 사진은 한때 03-19였다 — 03-16이 퍼준1의 정답이라 날짜 칸에서 답이
## 읽힐까 봐 어긋낸 것이었다. 그런데 가리는 의미가 없었다 — `봄이 일지`는 잠기지
## 않은 파일이고 첫 줄이 "2002. 3. 16 (토) 데려왔다"다. 정답은 이미 평문으로
## 열려 있고, 남는 건 사진 한 장만 어긋난 모순뿐이었다. 그래서 맞췄다.
const PHOTO_TAKEN := {
	"p_family": "2001-01-24",    # 2001년 설
	"p_desk": "2002-02-11",
	"p_bomi": "2002-03-16",      # 봄이를 데려온 날 (= 퍼준1 정답)
	"p_retreat": "2002-08-04",   # 수련회 마지막 날
	"p_window": "2002-10-29",    # 봉고차가 집 앞에 서 있던 날
}

func test_every_photo_is_dated_the_day_it_was_taken() -> void:
	var seen := 0
	for n in _nodes():
		var id := String(n["id"])
		if not PHOTO_TAKEN.has(id):
			assert_bool(String(n.get("type", "")) != "image").override_failure_message(
				"새 사진 %s가 PHOTO_TAKEN 표에 없다 — 찍힌 날을 적어 넣을 것" % id).is_true()
			continue
		seen += 1
		assert_str(String(n.get("mtime", "")).substr(0, 10)).override_failure_message(
			"%s의 파일 날짜가 찍힌 날(%s)과 다르다" % [n.get("name", id), PHOTO_TAKEN[id]]
		).is_equal(String(PHOTO_TAKEN[id]))
	assert_int(seen).is_equal(PHOTO_TAKEN.size())

## 파일명에 날짜가 박힌 사진은 그 날짜와 파일 날짜가 같아야 한다
func test_photo_filename_dates_agree_with_the_file_date() -> void:
	for n in _nodes():
		if String(n.get("type", "")) != "image":
			continue
		var name := String(n.get("name", ""))
		var mtime := String(n.get("mtime", ""))
		var mmdd := mtime.substr(5, 2) + mtime.substr(8, 2)
		for part in name.split("_"):
			var digits := part.split(".")[0]
			if digits.length() == 4 and digits.is_valid_int():
				assert_str(digits).override_failure_message(
					"%s의 이름이 %s를 가리키는데 파일 날짜는 %s다" % [name, digits, mtime]
				).is_equal(mmdd)
