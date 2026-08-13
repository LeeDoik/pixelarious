# LAST LOGIN (마지막 접속) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Godot 4 데스크톱 호러 어드벤처 LAST LOGIN을 만들어 웹으로 익스포트하고 NEO_KIDO 카트리지로 등록한다.

**Architecture:** Godot 4 Standard(GDScript) 단일 프로젝트(`game/`). 가짜 OS "누리OS 2002"는 Boot 씬 → Desktop 씬(창 관리자) → 프로그램별 앱 씬으로 구성. **씬 파일(.tscn)은 루트 노드+스크립트 연결만 담고, UI는 전부 GDScript 코드로 구성한다**(텍스트 기반 작업에 가장 안정적). 모든 서사 콘텐츠(파일트리·문서·채팅·메일·웹·퍼즐 정답)는 `game/content/*.json` 데이터. 웹 익스포트 산출물은 `public/games/last-login/`으로 떨어져 기존 iframe 카트리지 패턴에 꽂힌다.

**Tech Stack:** Godot 4.3+ Standard(GDScript, .NET 아님), gdUnit4(헤드리스 단위 테스트), Python(에셋 생성 스크립트), 기존 Next.js 사이트(레코드 등록만).

**Spec:** `docs/superpowers/specs/2026-08-13-last-login-design.md` (모든 요구사항의 원천)

## Global Constraints

스펙에서 그대로 옮긴 전 태스크 공통 제약:

- 엔진: **Godot 4.3+ Standard(GDScript)**. .NET 버전 금지(웹 익스포트 미지원). 웹 익스포트는 **스레드 비활성화**(COOP/COEP 헤더 불필요).
- 해상도 **1024×768 고정**, 브라우저에서 레터박스 스케일.
- **OS는 끝까지 정상 작동** — 글리치·점프스케어·가짜 오류 연출 금지. 공포는 기록의 내용에서.
- **플레이어 텍스트 입력은 영숫자만**(한글 IME 금지). 대화는 전부 선택지 클릭.
- 진행은 **플래그 기반 게이트**. 힌트: 같은 게이트 5분 정체 시 1단계, 이후 3분 간격 상승(3단계).
- 숨겨진 엔딩 조건: **기록물 9개** 전부 열람.
- 실존 브랜드(Windows/XP/Luna/버디버디/싸이월드 등) 이름·로고 사용 금지. 가상 브랜드: 누리OS 2002, 단짝, 누리메일, 누리서퍼, 마이홈, 한별컴퓨터, 새빛수련회.
- 폭력·자해 직접 묘사 없음. 협박·불안은 암시로(15세 내외).
- 에셋은 자작·AI 생성·CC0만. 출처는 `game/CREDITS.md`에 기록. 실존 인물 사진 금지.
- 모든 텍스트 콘텐츠는 JSON 데이터로(코드와 분리).
- 작업 디렉토리 경로에 공백(`2D PROJECT`) — 셸 명령의 경로는 항상 따옴표. 셸은 PowerShell.
- Godot 실행 파일 변수(전 태스크 공통): `$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"`
- 테스트 실행(전 태스크 공통, `game/` 디렉토리에서):
  `$env:GODOT_BIN = $GODOT; cmd /c "addons\gdUnit4\runtest.cmd -a tests"` → 기대: 실패 0, exit code 0.

## File Structure (최종)

```
game/project.godot                  ← 프로젝트 설정, 오토로드, 해상도/스트레치
game/export_presets.cfg             ← Web 프리셋 (Task 14)
game/CREDITS.md
game/addons/gdUnit4/                ← 테스트 프레임워크 (Task 1 설치)
game/assets/fonts/galmuri11.ttf, galmuri9.ttf
game/assets/img/                    ← 아이콘·사진 (Task 12 생성)
game/assets/sfx/                    ← 사운드 (Task 12 생성)
game/content/fs.json                ← 파일트리 (탐색기가 렌더)
game/content/docs.json              ← 문서 본문 { cid: {title, body} }
game/content/chat.json              ← 슬기 대화 스크립트 + 과거 로그
game/content/mail.json              ← 메일함
game/content/web.json               ← 즐겨찾기·웹페이지·미니홈피
game/content/puzzles.json           ← 퍼즐 정답·힌트 3단계
game/content/records.json           ← 기록물 9개 cid 목록
game/content/strings.json           ← UI 라벨
game/src/core/game_state.gd         ← 오토로드: 플래그·열람 기록·액트·세이브
game/src/core/content_db.gd         ← 오토로드: JSON 로드+검증
game/src/core/audio_director.gd     ← 오토로드: 앰비언트 레이어·SFX
game/src/core/hint_engine.gd        ← 힌트 타이머 (RefCounted, 시계 주입)
game/src/core/chat_player.gd        ← 채팅 스크립트 순회 (RefCounted)
game/src/theme/nuri_theme.gd        ← XP풍 Theme 빌더 (코드로 생성)
game/src/desktop/os_window.gd/.tscn ← 공통 창(타이틀바·드래그·닫기)
game/src/desktop/window_manager.gd  ← 창 열기/포커스/z-order/작업표시줄 연동
game/src/desktop/desktop.gd/.tscn   ← 바탕화면·아이콘·작업표시줄·시계·CRT
game/src/boot/boot.gd/.tscn         ← 부팅 연출(메인 씬), 이어하기
game/src/apps/explorer.gd           ← 파일 탐색기+뷰어+잠긴 폴더(퍼즐1)
game/src/apps/messenger.gd          ← 단짝: 실시간 대화·선택지·로그·힌트
game/src/apps/mail.gd               ← 누리메일: 첨부 암호(퍼즐2)
game/src/apps/browser.gd            ← 누리서퍼: 주소창·캐시(퍼즐3)·마이홈
game/src/apps/trash.gd              ← 휴지통: 복원(퍼즐4)
game/src/ending/ending.gd           ← 엔딩·숨겨진 엔딩 연출
game/tests/test_*.gd                ← gdUnit4 테스트
game/web/shell.html                 ← 부팅 룩 커스텀 HTML 셸 (Task 14)
scripts/gen_icons.py                ← 픽셀 아이콘 생성
scripts/gen_audio.py                ← 사운드 신디사이징
scripts/degrade_photo.py            ← 사진 디카 화질 열화
public/games/last-login/            ← 웹 익스포트 산출물 (커밋 대상)
content/games/last-login.json       ← NEO_KIDO 게임 레코드
```

---

### Task 1: 환경 구축 + Godot 프로젝트 스캐폴드 + 테스트 하네스

**Files:**
- Create: `C:\Users\LeeDoik\tools\godot\` (리포 밖), `game/project.godot`, `game/icon.svg`, `game/addons/gdUnit4/`, `game/tests/test_harness.gd`, `game/CREDITS.md`, `game/assets/fonts/*.ttf`, `.gitignore`(수정)

**Interfaces:**
- Produces: `$GODOT` 콘솔 실행 파일, 오토로드 3종이 등록된 project.godot, 동작하는 gdUnit4 테스트 커맨드 (Global Constraints 참고)

- [ ] **Step 1: Godot 최신 안정판 Standard 다운로드·설치**

```powershell
$rel = gh api repos/godotengine/godot/releases/latest --jq .tag_name   # 예: 4.5.1-stable
New-Item -ItemType Directory -Force "C:\Users\LeeDoik\tools\godot"
gh release download $rel -R godotengine/godot -p "Godot_v${rel}_win64.exe.zip" -D "C:\Users\LeeDoik\tools\godot"
Expand-Archive "C:\Users\LeeDoik\tools\godot\Godot_v${rel}_win64.exe.zip" -DestinationPath "C:\Users\LeeDoik\tools\godot" -Force
Rename-Item "C:\Users\LeeDoik\tools\godot\Godot_v${rel}_win64.exe" "godot.exe"
Rename-Item "C:\Users\LeeDoik\tools\godot\Godot_v${rel}_win64_console.exe" "godot_console.exe"
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
& $GODOT --version
```
Expected: `4.x.x.stable.official...` 출력. 4.3 미만이면 중단.

- [ ] **Step 2: 폰트 다운로드**

```powershell
gh release download -R quiple/galmuri -p "Galmuri*.zip" -D "$env:TEMP\galmuri"
Expand-Archive "$env:TEMP\galmuri\*.zip" -DestinationPath "$env:TEMP\galmuri\x" -Force
# 압축 해제 결과에서 Galmuri11.ttf, Galmuri9.ttf 를 찾아 복사
New-Item -ItemType Directory -Force "game\assets\fonts"
Get-ChildItem "$env:TEMP\galmuri\x" -Recurse -Include Galmuri11.ttf,Galmuri9.ttf | Copy-Item -Destination "game\assets\fonts\"
```
Expected: `game\assets\fonts\` 에 ttf 2개. (갈무리는 OFL 라이선스 — Step 6의 CREDITS에 기록)

- [ ] **Step 3: project.godot 작성**

`game/project.godot`:
```ini
; Engine configuration file.
config_version=5

[application]
config/name="LAST LOGIN"
run/main_scene="res://src/boot/boot.tscn"
config/features=PackedStringArray("4.3")
config/icon="res://icon.svg"

[autoload]
ContentDB="*res://src/core/content_db.gd"
GameState="*res://src/core/game_state.gd"
AudioDirector="*res://src/core/audio_director.gd"

[display]
window/size/viewport_width=1024
window/size/viewport_height=768
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

`game/icon.svg` (임시 아이콘):
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#0a2a3a"/><rect x="20" y="28" width="88" height="60" fill="#d8d0c0"/><rect x="28" y="36" width="72" height="44" fill="#123"/><text x="34" y="64" fill="#7fd" font-family="monospace" font-size="16">C:\_</text></svg>
```

오토로드 대상 스크립트가 아직 없으므로 **빈 스텁 3개**를 먼저 만든다(다음 태스크들이 채움):
`game/src/core/game_state.gd`, `game/src/core/content_db.gd`, `game/src/core/audio_director.gd` 각각:
```gdscript
extends Node
```
메인 씬 스텁 `game/src/boot/boot.tscn`(임시 — Task 6에서 교체):
```
[gd_scene format=3]

[node name="Boot" type="Control"]
```

- [ ] **Step 4: 헤드리스 스모크**

```powershell
& $GODOT --headless --path game --quit
```
Expected: 임포트 후 정상 종료(exit 0), 에러 없음.

- [ ] **Step 5: gdUnit4 설치 + 하네스 검증 테스트**

```powershell
git clone --depth 1 https://github.com/MikeSchulze/gdUnit4 "$env:TEMP\gdunit4"
Copy-Item -Recurse "$env:TEMP\gdunit4\addons\gdUnit4" "game\addons\gdUnit4"
```
`game/project.godot`에 추가:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")
```
`game/tests/test_harness.gd`:
```gdscript
extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_bool(true).is_true()
```
실행(game/ 디렉토리에서):
```powershell
& $GODOT --headless --path game --quit   # 애드온 임포트
$env:GODOT_BIN = $GODOT
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: 1 passed, exit 0. (gdUnit4 최신판이 현재 Godot 버전과 안 맞으면 gdUnit4 릴리스 중 엔진 버전에 맞는 태그로 재클론)

- [ ] **Step 6: .gitignore와 CREDITS**

리포 루트 `.gitignore`에 추가:
```
game/.godot/
```
`game/CREDITS.md`:
```markdown
# LAST LOGIN — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Engine: Godot Engine — MIT License
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio.py)
- 이미지: 자체 절차 생성 및 AI 생성 후 가공. 실존 인물 없음
```

- [ ] **Step 7: Commit**

```powershell
git add game .gitignore
git commit -m "feat(game): scaffold Godot project with test harness"
```

---

### Task 2: GameState — 플래그·열람 기록·액트·퍼즐 판정·세이브

**Files:**
- Modify: `game/src/core/game_state.gd`
- Test: `game/tests/test_game_state.gd`

**Interfaces:**
- Consumes: `ContentDB.puzzles` (Task 3 — 이 태스크에서는 주입 가능한 `puzzle_source`로 대체)
- Produces (이후 전 태스크가 사용):
  - `signal flag_changed(name: String)` / `signal act_changed(act: int)` / `signal record_read(cid: String, total: int)`
  - `func set_flag(name: String) -> void`, `func has_flag(name: String) -> bool`
  - `func mark_read(cid: String) -> void` (기록물이면 record_read 발신)
  - `func records_count() -> int`
  - `func current_act() -> int`  # 1=기본, 2=puzzle1_solved 이후, 3=puzzle3_solved 이후
  - `func try_answer(puzzle_id: String, input: String) -> bool`  # 대소문자 무시, 성공 시 "<id>_solved" 플래그
  - `func save_game() -> void` / `func load_game() -> bool` / `func has_save() -> bool` / `func reset() -> void`
  - `var puzzle_source: Callable`  # func(id) -> Dictionary {answer, hints[3], ...}
  - `var records_source: Callable` # func() -> Array[String] (기록물 cid 9개)

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_game_state.gd`:
```gdscript
extends GdUnitTestSuite

const GS := preload("res://src/core/game_state.gd")

func _make() -> Node:
	var gs: Node = auto_free(GS.new())
	gs.puzzle_source = func(id: String) -> Dictionary:
		return {"answer": "20020316"} if id == "puzzle1" else {}
	gs.records_source = func() -> Array:
		return ["doc:r1", "doc:r2", "doc:r3"]
	return gs

func test_flags() -> void:
	var gs := _make()
	assert_bool(gs.has_flag("booted")).is_false()
	gs.set_flag("booted")
	assert_bool(gs.has_flag("booted")).is_true()

func test_act_progression() -> void:
	var gs := _make()
	assert_int(gs.current_act()).is_equal(1)
	gs.set_flag("puzzle1_solved")
	assert_int(gs.current_act()).is_equal(2)
	gs.set_flag("puzzle3_solved")
	assert_int(gs.current_act()).is_equal(3)

func test_try_answer_case_insensitive_and_flag() -> void:
	var gs := _make()
	assert_bool(gs.try_answer("puzzle1", "wrong")).is_false()
	assert_bool(gs.has_flag("puzzle1_solved")).is_false()
	assert_bool(gs.try_answer("puzzle1", "20020316")).is_true()
	assert_bool(gs.has_flag("puzzle1_solved")).is_true()

func test_records_count_only_counts_records() -> void:
	var gs := _make()
	gs.mark_read("doc:r1")
	gs.mark_read("doc:not_a_record")
	gs.mark_read("doc:r1")  # 중복
	assert_int(gs.records_count()).is_equal(1)

func test_save_and_load_roundtrip() -> void:
	var gs := _make()
	gs.set_flag("puzzle1_solved")
	gs.mark_read("doc:r2")
	gs.save_game()
	var gs2 := _make()
	assert_bool(gs2.has_save()).is_true()
	assert_bool(gs2.load_game()).is_true()
	assert_bool(gs2.has_flag("puzzle1_solved")).is_true()
	assert_int(gs2.records_count()).is_equal(1)
	gs2.reset()
	assert_bool(gs2.has_save()).is_false()
```

- [ ] **Step 2: 실패 확인**

Run: 공통 테스트 커맨드. Expected: test_game_state 전부 FAIL(메서드 없음).

- [ ] **Step 3: 구현**

`game/src/core/game_state.gd`:
```gdscript
extends Node
## 진행 상태의 단일 소스. 플래그·열람 기록·액트·퍼즐 판정·세이브.

signal flag_changed(name: String)
signal act_changed(act: int)
signal record_read(cid: String, total: int)

const SAVE_PATH := "user://save.json"

var puzzle_source: Callable = func(id: String) -> Dictionary:
	return ContentDB.puzzle(id)
var records_source: Callable = func() -> Array:
	return ContentDB.records()

var _flags: Dictionary = {}
var _read: Dictionary = {}  # cid -> true

func set_flag(name: String) -> void:
	if _flags.has(name):
		return
	var before := current_act()
	_flags[name] = true
	flag_changed.emit(name)
	var after := current_act()
	if after != before:
		act_changed.emit(after)
	save_game()

func has_flag(name: String) -> bool:
	return _flags.has(name)

func current_act() -> int:
	if has_flag("puzzle3_solved"):
		return 3
	if has_flag("puzzle1_solved"):
		return 2
	return 1

func mark_read(cid: String) -> void:
	if _read.has(cid):
		return
	_read[cid] = true
	if cid in records_source.call():
		record_read.emit(cid, records_count())
	save_game()

func is_read(cid: String) -> bool:
	return _read.has(cid)

func records_count() -> int:
	var n := 0
	for cid in records_source.call():
		if _read.has(cid):
			n += 1
	return n

func try_answer(puzzle_id: String, input: String) -> bool:
	var p: Dictionary = puzzle_source.call(puzzle_id)
	if p.is_empty():
		return false
	if input.strip_edges().to_lower() == String(p["answer"]).to_lower():
		set_flag(puzzle_id + "_solved")
		return true
	return false

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"flags": _flags, "read": _read}))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_flags = data.get("flags", {})
	_read = data.get("read", {})
	return true

func reset() -> void:
	_flags = {}
	_read = {}
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
```

- [ ] **Step 4: 통과 확인** — 공통 테스트 커맨드, Expected: 전부 PASS.

- [ ] **Step 5: Commit** — `git add game; git commit -m "feat(game): GameState flags, acts, puzzle check, save"`

---

### Task 3: ContentDB — 콘텐츠 스키마 확정 + 로더/검증 + 샘플 콘텐츠

**Files:**
- Modify: `game/src/core/content_db.gd`
- Create: `game/content/fs.json`, `docs.json`, `chat.json`, `mail.json`, `web.json`, `puzzles.json`, `records.json`, `strings.json` (스키마 검증 가능한 샘플 — 본 콘텐츠는 Task 13)
- Test: `game/tests/test_content_db.gd`

**Interfaces:**
- Produces (이후 전 태스크가 사용):
  - `func load_all(base: String = "res://content") -> Array[String]`  # 반환: 검증 오류 목록(빈 배열이면 정상). 오토로드 _ready()에서 자동 호출
  - `func fs_children(parent_id: String) -> Array[Dictionary]`  # fs 노드: {id, parent, name, type: "folder"|"doc"|"image", cid?, locked_by?, record?}
  - `func doc(cid: String) -> Dictionary`  # {title, body}
  - `func chat_thread() -> Dictionary`  # {start, nodes: {id: {from, text, choices?, next?, require?, set?, delay_ms?}}}
  - `func chat_logs() -> Array`
  - `func mails() -> Array[Dictionary]`  # {id, from, subject, date, body, attachment?: {name, locked_by, cid}}
  - `func web_bookmarks() -> Array` / `func web_page(url: String) -> Dictionary`
  - `func puzzle(id: String) -> Dictionary`  # {answer, hints: [h1,h2,h3], ...}
  - `func records() -> Array`  # 기록물 cid 목록 (본 콘텐츠에서 정확히 9개)
  - `func ui(key: String) -> String`
  - `func trash_items() -> Array[Dictionary]`  # fs.json 중 parent=="trash" 노드

**콘텐츠 규칙(검증기가 강제):** 퍼즐 answer는 `^[A-Za-z0-9/.]+$`, chat의 next/choice 대상 노드 존재, fs/mail/web이 참조하는 cid는 docs.json에 존재, records의 cid는 전부 실제 콘텐츠에 존재, records는 정확히 9개(단, 샘플 단계에서는 `strings.json`의 `"dev_allow_partial_records": true`로 완화 — Task 13에서 제거).

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_content_db.gd`:
```gdscript
extends GdUnitTestSuite

const CDB := preload("res://src/core/content_db.gd")

func _make() -> Node:
	var db: Node = auto_free(CDB.new())
	var errors: Array = db.load_all("res://content")
	assert_array(errors).is_empty()
	return db

func test_fs_tree_and_doc_lookup() -> void:
	var db := _make()
	var root := db.fs_children("root")
	assert_int(root.size()).is_greater(0)
	var d := db.doc("doc:essay_2001")
	assert_str(String(d["title"])).is_not_empty()

func test_puzzle_answers_are_alnum() -> void:
	var db := _make()
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9/.]+$")
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		var p := db.puzzle(pid)
		assert_bool(re.search(String(p["answer"])) != null).is_true()

func test_chat_thread_targets_exist() -> void:
	var db := _make()
	var t := db.chat_thread()
	assert_bool(t["nodes"].has(t["start"])).is_true()

func test_validator_catches_missing_doc() -> void:
	var db: Node = auto_free(CDB.new())
	# 존재하지 않는 cid를 참조하는 fs를 메모리에서 주입
	var errors: Array = db.validate({
		"fs": {"nodes": [{"id": "x", "parent": "root", "name": "유령.txt", "type": "doc", "cid": "doc:ghost"}]},
		"docs": {}, "chat": {"start": "n1", "nodes": {"n1": {"from": "sys", "text": "hi"}}, "logs": []},
		"mail": [], "web": {"bookmarks": [], "pages": {}},
		"puzzles": {}, "records": {"records": []}, "strings": {"dev_allow_partial_records": true}
	})
	assert_array(errors).is_not_empty()
```

- [ ] **Step 2: 실패 확인** — 공통 커맨드, Expected: FAIL.

- [ ] **Step 3: 샘플 콘텐츠 작성**

`game/content/docs.json` (발췌 — 샘플은 각 유형 1개 이상):
```json
{
  "doc:essay_2001": {"title": "낙방 수기.txt", "body": "2001년 10월 14일.\n또 떨어졌다. 이번에는 정말 될 줄 알았는데."},
  "doc:diary_final": {"title": "(복원됨) 일기_1102.txt", "body": "샘플 — Task 13에서 본문 교체"}
}
```
`game/content/fs.json`:
```json
{"nodes": [
  {"id": "mydocs", "parent": "root", "name": "내 문서", "type": "folder"},
  {"id": "f_essay", "parent": "mydocs", "name": "낙방 수기.txt", "type": "doc", "cid": "doc:essay_2001", "record": true},
  {"id": "locked", "parent": "mydocs", "name": "성진이만", "type": "folder", "locked_by": "puzzle1"},
  {"id": "t1", "parent": "trash", "name": "backup_1102.txt", "type": "doc", "cid": "doc:diary_final", "record": true},
  {"id": "t2", "parent": "trash", "name": "backup_0930.txt", "type": "doc", "cid": "doc:corrupt", "corrupt": true}
]}
```
`game/content/chat.json`:
```json
{"start": "n1",
 "nodes": {
   "n1": {"from": "seulgi", "text": "…오빠? 오빠 컴퓨터 켜져 있는 거 보여", "next": "n2", "delay_ms": 1200},
   "n2": {"from": "seulgi", "text": "지금 집이야?", "choices": [
     {"text": "누구세요? 저는 이 컴퓨터를 주웠는데요", "next": "n3", "set": ["met_seulgi"]},
     {"text": "(대답하지 않는다)", "next": "n3b"}]},
   "n3": {"from": "seulgi", "text": "…주웠다고요? 그거 저희 오빠 컴퓨터예요.", "next": "end"},
   "n3b": {"from": "seulgi", "text": "…거기 있는 거 알아요.", "next": "n3"},
   "end": {"from": "sys", "text": "샘플 끝 — Task 13에서 본편 교체"}
 },
 "logs": [{"date": "2002-11-02", "with": "민규", "lines": [{"from": "민규", "text": "야 너 요즘 왜 그래"}]}]}
```
`game/content/mail.json`:
```json
[{"id": "m1", "from": "새빛수련회", "subject": "성진 님, 마음의 준비가 되셨나요", "date": "2002-09-14",
  "body": "샘플", "attachment": {"name": "새빛자료.zip", "locked_by": "puzzle2", "cid": "doc:doctrine_full"}}]
```
`game/content/web.json`:
```json
{"bookmarks": [{"title": "새빛수련회 카페", "url": "cafe.nurinet.co.kr/saebit"}],
 "pages": {
   "cafe.nurinet.co.kr/saebit": {"title": "카페를 찾을 수 없습니다", "body": "폐쇄된 카페입니다."},
   "cafe.nurinet.co.kr/saebit/gate": {"title": "(캐시) 새빛수련회", "body": "샘플", "requires": "puzzle3", "cid": "web:cafe_gate"},
   "myhome.nurinet.co.kr/sj2002": {"title": "성진의 마이홈", "body": "2002.03.16 봄이 온 날 — 우리 봄이 데려온 날!", "cid": "web:myhome_bomi"}
 }}
```
`game/content/puzzles.json` (정답은 스펙 §3.2 확정값):
```json
{
 "puzzle1": {"answer": "20020316", "hints": ["오빠가 뭘 제일 아꼈는지 미니홈피에 있을 거예요", "마이홈에서 봄이 게시글 날짜를 봐요", "봄이 온 날 — 8자리 숫자예요"]},
 "puzzle2": {"answer": "030703", "hints": ["그 사람들 문서에 이상한 날짜가 있었어요", "'새빛력'이라는 말 봤어요? 필사 문서요", "새빛력 3년 7월 3일 — 6자리로요"]},
 "puzzle3": {"answer": "cafe.nurinet.co.kr/saebit/gate", "hints": ["카페 주소가 완전히 죽은 건 아닐지도요", "메일에 '예전 주소 그대로'라는 말이 있었죠", "즐겨찾기 주소 뒤에 /gate 를 붙여봐요"]},
 "puzzle4": {"answer": "t1", "hints": ["휴지통 파일들, 날짜가 다 달라요", "오빠 마지막 접속이 언제였죠? 메신저 로그요", "11월 2일 백업 파일이에요"]}
}
```
`game/content/records.json`:
```json
{"records": ["doc:essay_2001", "doc:diary_final"]}
```
`game/content/strings.json`:
```json
{"dev_allow_partial_records": true, "app_explorer": "내 문서", "app_messenger": "단짝", "app_mail": "누리메일", "app_browser": "누리서퍼", "app_trash": "휴지통", "os_name": "누리OS 2002"}
```

- [ ] **Step 4: 구현**

`game/src/core/content_db.gd`:
```gdscript
extends Node
## content/*.json 로드와 스키마 검증. 게임의 모든 서사 데이터 접근 창구.

var _d: Dictionary = {}

func _ready() -> void:
	var errors := load_all()
	if not errors.is_empty():
		push_error("ContentDB validation failed: " + str(errors))

func load_all(base: String = "res://content") -> Array:
	var raw := {}
	for key in ["fs", "docs", "chat", "mail", "web", "puzzles", "records", "strings"]:
		var path := "%s/%s.json" % [base, key]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			return ["cannot parse " + path]
		raw[key] = parsed
	var errors := validate(raw)
	if errors.is_empty():
		_d = raw
	return errors

func validate(raw: Dictionary) -> Array:
	var errors: Array = []
	var docs: Dictionary = raw["docs"]
	var web_pages: Dictionary = raw["web"]["pages"]
	var known_cids := {}
	for cid in docs.keys():
		known_cids[cid] = true
	for url in web_pages.keys():
		if web_pages[url].has("cid"):
			known_cids[web_pages[url]["cid"]] = true
	# fs가 참조하는 cid 존재 확인 (image 유형은 파일 경로라 제외)
	for n in raw["fs"]["nodes"]:
		if n.get("type") == "doc" and not n.get("corrupt", false) and not docs.has(n.get("cid", "")):
			errors.append("fs node %s references missing doc %s" % [n["id"], n.get("cid", "?")])
	# mail 첨부 cid
	for m in raw["mail"]:
		if m.has("attachment") and not docs.has(m["attachment"].get("cid", "")):
			errors.append("mail %s attachment missing doc" % m["id"])
		known_cids["mail:" + m["id"]] = true
	# chat 노드 연결
	var nodes: Dictionary = raw["chat"]["nodes"]
	if not nodes.has(raw["chat"]["start"]):
		errors.append("chat start node missing")
	for id in nodes:
		var node: Dictionary = nodes[id]
		var targets: Array = []
		if node.has("next"):
			targets.append(node["next"])
		for c in node.get("choices", []):
			targets.append(c["next"])
		for t in targets:
			if not nodes.has(t):
				errors.append("chat node %s -> missing %s" % [id, t])
	# 퍼즐 정답 영숫자(+주소용 / .)
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9/.]+$")
	for pid in raw["puzzles"]:
		var p: Dictionary = raw["puzzles"][pid]
		if re.search(String(p.get("answer", ""))) == null:
			errors.append("puzzle %s answer not alnum" % pid)
		if p.get("hints", []).size() != 3:
			errors.append("puzzle %s needs exactly 3 hints" % pid)
	# 기록물 존재 + 9개 (개발 중 완화 플래그)
	var recs: Array = raw["records"]["records"]
	for cid in recs:
		if not known_cids.has(cid):
			errors.append("record cid missing: " + str(cid))
	if not raw["strings"].get("dev_allow_partial_records", false) and recs.size() != 9:
		errors.append("records must be exactly 9, got %d" % recs.size())
	return errors

func fs_children(parent_id: String) -> Array:
	var out: Array = []
	for n in _d["fs"]["nodes"]:
		if n.get("parent") == parent_id:
			out.append(n)
	return out

func fs_node(id: String) -> Dictionary:
	for n in _d["fs"]["nodes"]:
		if n["id"] == id:
			return n
	return {}

func trash_items() -> Array:
	return fs_children("trash")

func doc(cid: String) -> Dictionary:
	return _d["docs"].get(cid, {})

func chat_thread() -> Dictionary:
	return {"start": _d["chat"]["start"], "nodes": _d["chat"]["nodes"]}

func chat_logs() -> Array:
	return _d["chat"]["logs"]

func mails() -> Array:
	return _d["mail"]

func web_bookmarks() -> Array:
	return _d["web"]["bookmarks"]

func web_page(url: String) -> Dictionary:
	return _d["web"]["pages"].get(url, {})

func puzzle(id: String) -> Dictionary:
	return _d["puzzles"].get(id, {})

func records() -> Array:
	return _d["records"]["records"]

func ui(key: String) -> String:
	return String(_d["strings"].get(key, key))
```

- [ ] **Step 5: 통과 확인** — 공통 커맨드, Expected: 전부 PASS.
- [ ] **Step 6: Commit** — `git commit -m "feat(game): ContentDB loader, schema validation, sample content"`

---

### Task 4: 누리 Theme + OSWindow + WindowManager

**Files:**
- Create: `game/src/theme/nuri_theme.gd`, `game/src/desktop/os_window.gd`, `game/src/desktop/os_window.tscn`, `game/src/desktop/window_manager.gd`
- Test: `game/tests/test_window_manager.gd`

**Interfaces:**
- Produces:
  - `NuriTheme.build() -> Theme` (static) — XP 시대 디자인 언어: 그라데이션 타이틀바(#0a246a→#3a6ea5 유사 계열이되 독자 색), 베벨 버튼, 청록 작업표시줄 색 상수 `NuriTheme.TASKBAR_COLOR`, `NuriTheme.DESKTOP_COLOR`
  - `OSWindow` (class_name, extends Panel): `func setup(id: String, title: String, size: Vector2) -> void`, `func set_content(c: Control) -> void`, `signal request_close(id)`, `signal focused(id)`, 타이틀바 드래그 이동(데스크톱 영역 클램프)
  - `WindowManager` (class_name, extends Control): `func register_app(id: String, title: String, builder: Callable) -> void`, `func open_app(id: String) -> void`(이미 열려 있으면 포커스), `func close_app(id: String)`, `func focus_app(id: String)`(z-order 최상위), `func is_open(id: String) -> bool`, `func open_ids() -> Array`, `signal windows_changed(open_ids: Array)`, `signal app_focused(id: String)`

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_window_manager.gd`:
```gdscript
extends GdUnitTestSuite

const WM := preload("res://src/desktop/window_manager.gd")

func _make() -> Control:
	var wm: Control = auto_free(WM.new())
	add_child(wm)
	wm.register_app("memo", "메모장", func() -> Control: return Label.new())
	wm.register_app("mail", "누리메일", func() -> Control: return Label.new())
	return wm

func test_open_close_and_ids() -> void:
	var wm := _make()
	assert_bool(wm.is_open("memo")).is_false()
	wm.open_app("memo")
	assert_bool(wm.is_open("memo")).is_true()
	wm.open_app("mail")
	assert_array(wm.open_ids()).contains(["memo", "mail"])
	wm.close_app("memo")
	assert_bool(wm.is_open("memo")).is_false()

func test_reopen_focuses_instead_of_duplicating() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("memo")
	assert_int(wm.open_ids().size()).is_equal(1)

func test_focus_moves_to_front() -> void:
	var wm := _make()
	wm.open_app("memo")
	wm.open_app("mail")   # mail이 위
	wm.focus_app("memo")
	var top := wm.get_child(wm.get_child_count() - 1)
	assert_str(top.win_id).is_equal("memo")
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/theme/nuri_theme.gd`:
```gdscript
class_name NuriTheme
## 누리OS 2002 룩 — XP 시대 디자인 언어, 독자 색·이름 (실존 브랜드 모사 금지)

const TITLE_A := Color("1a3a8c")
const TITLE_B := Color("4a7ec2")
const TASKBAR_COLOR := Color("2a6a5a")
const DESKTOP_COLOR := Color("3a7a9c")
const FACE := Color("d8d4c8")      # 창 본체 베이지
const FACE_DARK := Color("8a867c")
const TEXT := Color("101418")

static func build() -> Theme:
	var t := Theme.new()
	var font := load("res://assets/fonts/Galmuri11.ttf")
	t.default_font = font
	t.default_font_size = 16
	var panel := StyleBoxFlat.new()
	panel.bg_color = FACE
	panel.border_color = FACE_DARK
	panel.set_border_width_all(2)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = FACE
	btn.border_color = FACE_DARK
	btn.set_border_width_all(2)
	btn.set_content_margin_all(6)
	t.set_stylebox("normal", "Button", btn)
	var btn_down := btn.duplicate()
	btn_down.bg_color = FACE.darkened(0.12)
	t.set_stylebox("pressed", "Button", btn_down)
	t.set_stylebox("hover", "Button", btn.duplicate())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_color", "Label", TEXT)
	var line := StyleBoxFlat.new()
	line.bg_color = Color.WHITE
	line.border_color = FACE_DARK
	line.set_border_width_all(2)
	line.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_color("font_color", "LineEdit", TEXT)
	return t

static func titlebar_style(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = TITLE_A if active else TITLE_A.lerp(Color.GRAY, 0.5)
	return s
```

`game/src/desktop/os_window.gd`:
```gdscript
class_name OSWindow
extends Panel
## 공통 창: 타이틀바(드래그·닫기) + 콘텐츠 슬롯

signal request_close(id: String)
signal focused(id: String)

var win_id := ""
var _dragging := false
var _drag_off := Vector2.ZERO
var _titlebar: Panel

func setup(id: String, title: String, win_size: Vector2) -> void:
	win_id = id
	custom_minimum_size = win_size
	size = win_size
	_titlebar = Panel.new()
	_titlebar.add_theme_stylebox_override("panel", NuriTheme.titlebar_style(true))
	_titlebar.custom_minimum_size = Vector2(0, 28)
	_titlebar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_titlebar.gui_input.connect(_on_titlebar_input)
	var tl := Label.new()
	tl.text = title
	tl.position = Vector2(8, 4)
	tl.add_theme_color_override("font_color", Color.WHITE)
	_titlebar.add_child(tl)
	var x := Button.new()
	x.text = "X"
	x.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	x.position = Vector2(-26, 3)
	x.size = Vector2(22, 22)
	x.pressed.connect(func(): request_close.emit(win_id))
	_titlebar.add_child(x)
	add_child(_titlebar)
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			focused.emit(win_id))

func set_content(c: Control) -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_top", 32)
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	add_child(m)

func _on_titlebar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		_drag_off = get_global_mouse_position() - global_position
		focused.emit(win_id)
	elif e is InputEventMouseMotion and _dragging:
		var p := get_global_mouse_position() - _drag_off
		var bounds := get_parent_area_size() - size
		global_position = p.clamp(Vector2.ZERO, Vector2(maxf(bounds.x, 0), maxf(bounds.y, 0)))
```

`game/src/desktop/os_window.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/desktop/os_window.gd" id="1"]

[node name="OSWindow" type="Panel"]
script = ExtResource("1")
```

`game/src/desktop/window_manager.gd`:
```gdscript
class_name WindowManager
extends Control
## 창 레지스트리와 z-order. 자식 = 열린 OSWindow들 (마지막 자식이 최상위).

signal windows_changed(open_ids: Array)
signal app_focused(id: String)

const OS_WINDOW := preload("res://src/desktop/os_window.tscn")

var _apps: Dictionary = {}     # id -> {title, builder}
var _windows: Dictionary = {}  # id -> OSWindow
var _cascade := 0

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
```

- [ ] **Step 4: 통과 확인** — Expected: 전부 PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): NuriTheme, OSWindow, WindowManager"`

---

### Task 5: Desktop 셸 — 아이콘·작업표시줄·시계·CRT 오버레이

**Files:**
- Create: `game/src/desktop/desktop.gd`, `game/src/desktop/desktop.tscn`
- Test: `game/tests/test_desktop.gd`

**Interfaces:**
- Consumes: `WindowManager`, `NuriTheme`, `ContentDB.ui()`, `GameState.act_changed`
- Produces: `Desktop` 씬(`res://src/desktop/desktop.tscn`) — Boot가 전환해 오는 목적지. 앱 빌더는 Task 7~11이 `APP_BUILDERS` 상수에 추가(각 태스크의 Produces 참고). `func clock_text() -> String` (액트별 시각: 1→"21:47", 2→"23:30", 3→"01:12")

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_desktop.gd`:
```gdscript
extends GdUnitTestSuite

const DESKTOP := preload("res://src/desktop/desktop.tscn")

func test_desktop_builds_icons_and_taskbar() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_object(d.wm).is_not_null()
	assert_int(d.icon_count()).is_greater(3)

func test_clock_follows_act() -> void:
	var d: Control = auto_free(DESKTOP.instantiate())
	add_child(d)
	assert_str(d.clock_text_for_act(1)).is_equal("21:47")
	assert_str(d.clock_text_for_act(3)).is_equal("01:12")
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/desktop/desktop.gd`:
```gdscript
extends Control
## 바탕화면: 배경색, 아이콘 그리드, 작업표시줄(열린 창 버튼 + 시계), CRT 오버레이

const ACT_CLOCK := {1: "21:47", 2: "23:30", 3: "01:12"}
# 앱 빌더 레지스트리 — Task 7~11이 여기에 앱을 추가한다
var APP_BUILDERS: Dictionary = {}

var wm: WindowManager
var _taskbar_box: HBoxContainer
var _clock: Label
var _icons: VBoxContainer

func _ready() -> void:
	theme = NuriTheme.build()
	var bg := ColorRect.new()
	bg.color = NuriTheme.DESKTOP_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	wm = WindowManager.new()
	wm.set_anchors_preset(Control.PRESET_FULL_RECT)
	wm.offset_bottom = -36  # 작업표시줄 높이만큼
	_register_apps()
	_build_icons()
	add_child(wm)
	_build_taskbar()
	_build_crt()
	GameState.act_changed.connect(func(_a): _clock.text = clock_text())
	_clock.text = clock_text()

func _register_apps() -> void:
	for id in APP_BUILDERS:
		wm.register_app(id, ContentDB.ui("app_" + id), APP_BUILDERS[id])

func _build_icons() -> void:
	_icons = VBoxContainer.new()
	_icons.position = Vector2(16, 12)
	_icons.add_theme_constant_override("separation", 14)
	for id in APP_BUILDERS:
		var b := Button.new()
		b.text = ContentDB.ui("app_" + id)
		b.flat = true
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(wm.open_app.bind(id))
		_icons.add_child(b)
	add_child(_icons)

func icon_count() -> int:
	return _icons.get_child_count()

func _build_taskbar() -> void:
	var bar := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = NuriTheme.TASKBAR_COLOR
	bar.add_theme_stylebox_override("panel", s)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, 36)
	bar.offset_top = -36
	var start := Label.new()
	start.text = " " + ContentDB.ui("os_name")
	start.add_theme_color_override("font_color", Color.WHITE)
	start.position = Vector2(8, 8)
	bar.add_child(start)
	_taskbar_box = HBoxContainer.new()
	_taskbar_box.position = Vector2(180, 4)
	bar.add_child(_taskbar_box)
	_clock = Label.new()
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-70, 8)
	_clock.add_theme_color_override("font_color", Color.WHITE)
	bar.add_child(_clock)
	add_child(bar)
	wm.windows_changed.connect(_refresh_taskbar)

func _refresh_taskbar(ids: Array) -> void:
	for c in _taskbar_box.get_children():
		c.queue_free()
	for id in ids:
		var b := Button.new()
		b.text = ContentDB.ui("app_" + id)
		b.pressed.connect(wm.focus_app.bind(id))
		_taskbar_box.add_child(b)

func clock_text() -> String:
	return clock_text_for_act(GameState.current_act())

func clock_text_for_act(act: int) -> String:
	return ACT_CLOCK[act]

func _build_crt() -> void:
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float scan = 0.04 * sin(UV.y * 768.0 * 3.14159);
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.85, 0.45, length(c)) * 0.12 + 0.88;
	COLOR = vec4(vec3(0.0), (0.04 + scan) * (1.0 - vig) + 0.05 * (1.0 - vig));
}
"""
	mat.shader = sh
	crt.material = mat
	add_child(crt)
```

`game/src/desktop/desktop.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/desktop/desktop.gd" id="1"]

[node name="Desktop" type="Control" anchors_preset=15 anchor_right=1.0 anchor_bottom=1.0]
script = ExtResource("1")
```

- [ ] **Step 4: 통과 확인** — Expected: PASS. (앱 미등록 상태에서 icon_count 테스트가 실패하면 테스트용으로 `APP_BUILDERS`에 스텁 4개를 desktop.gd 기본값으로: `{"explorer": func(): return Label.new(), "messenger": ..., "mail": ..., "trash": ...}` — Task 7~11이 실제 빌더로 교체)
- [ ] **Step 5: Commit** — `git commit -m "feat(game): desktop shell with taskbar, clock, CRT overlay"`

---

### Task 6: Boot 씬 — 부팅 연출(로딩 겸용), 이어하기

**Files:**
- Modify: `game/src/boot/boot.tscn`
- Create: `game/src/boot/boot.gd`
- Test: `game/tests/test_boot.gd`

**Interfaces:**
- Consumes: `GameState.has_save()/load_game()/reset()`, Desktop 씬 경로
- Produces: 메인 씬. `func post_lines() -> Array[String]`(연출 대사 목록), `func skip() -> void`(클릭/키 입력 시 즉시 완료), 완료 후 `res://src/desktop/desktop.tscn` 전환. 세이브 존재 시 [이어서 하기 / 처음부터] 선택지.

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_boot.gd`:
```gdscript
extends GdUnitTestSuite

const BOOT := preload("res://src/boot/boot.gd")

func test_post_lines_exist_and_korean_bios_flavor() -> void:
	var b: Node = auto_free(BOOT.new())
	var lines: Array = b.post_lines()
	assert_int(lines.size()).is_greater(4)
	assert_str(String(lines[0])).contains("HANBYUL")
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/boot/boot.gd`:
```gdscript
extends Control
## 부팅 연출: 검은 화면 → POST 텍스트 타이핑 → 부팅 로고 → Desktop 전환.
## 웹에서는 엔진 로딩(HTML 셸)이 끝난 직후라 "켜지는 중" 서사가 이어진다.

const DESKTOP_SCENE := "res://src/boot/../desktop/desktop.tscn"
const LINE_DELAY := 0.35

var _label: RichTextLabel
var _idx := 0
var _done := false

func post_lines() -> Array:
	return [
		"HANBYUL Computer BIOS v2.02",
		"Memory Test : 131072K OK",
		"Detecting IDE Drives ... HDD0: HB-D5400 (40GB)",
		"Boot from HDD ...",
		"",
		"누리OS 2002 시작하는 중...",
	]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label = RichTextLabel.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 24
	_label.offset_top = 24
	_label.add_theme_color_override("default_color", Color("9adfc0"))
	_label.add_theme_font_override("normal_font", load("res://assets/fonts/Galmuri11.ttf"))
	add_child(_label)
	_next_line()

func _next_line() -> void:
	if _done:
		return
	if _idx >= post_lines().size():
		_finish()
		return
	_label.append_text(post_lines()[_idx] + "\n")
	_idx += 1
	get_tree().create_timer(LINE_DELAY).timeout.connect(_next_line)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		skip()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		skip()

func skip() -> void:
	if _done:
		return
	_label.clear()
	for l in post_lines():
		_label.append_text(l + "\n")
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if GameState.has_save():
		_show_continue_menu()
	else:
		_go_desktop()

func _show_continue_menu() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	var cont := Button.new()
	cont.text = "이어서 하기"
	cont.pressed.connect(func():
		GameState.load_game()
		_go_desktop())
	var fresh := Button.new()
	fresh.text = "처음부터"
	fresh.pressed.connect(func():
		GameState.reset()
		_go_desktop())
	box.add_child(cont)
	box.add_child(fresh)
	add_child(box)

func _go_desktop() -> void:
	get_tree().change_scene_to_file("res://src/desktop/desktop.tscn")
```

`game/src/boot/boot.tscn` 교체:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/boot/boot.gd" id="1"]

[node name="Boot" type="Control" anchors_preset=15 anchor_right=1.0 anchor_bottom=1.0]
script = ExtResource("1")
```

- [ ] **Step 4: 통과 확인 + 수동 스모크**

공통 테스트 커맨드 PASS 후:
```powershell
& $GODOT --path game   # 창이 뜨면 부팅 연출 → 바탕화면 전환 확인, 클릭 스킵 확인
```
Expected: 부팅 텍스트가 줄 단위로 출력되고 완료 시(또는 클릭 시) 바탕화면 표시.

- [ ] **Step 5: Commit** — `git commit -m "feat(game): boot sequence with continue menu"`

---

### Task 7: 파일 탐색기 + 문서/사진 뷰어 + 잠긴 폴더(퍼즐1)

**Files:**
- Create: `game/src/apps/explorer.gd`
- Modify: `game/src/desktop/desktop.gd` (APP_BUILDERS의 "explorer" 스텁을 실제 빌더로)
- Test: `game/tests/test_explorer.gd`

**Interfaces:**
- Consumes: `ContentDB.fs_children/fs_node/doc`, `GameState.mark_read/has_flag/try_answer`
- Produces: `Explorer` (class_name, extends Control) — `func open_folder(id: String) -> bool`(잠긴 폴더는 해제 전 false), `func open_file(node_id: String) -> void`(문서 뷰어 표시 + `GameState.mark_read(cid)`), `func submit_password(text: String) -> bool`(퍼즐1 → GameState.try_answer). Desktop 등록: `APP_BUILDERS["explorer"] = func(): return Explorer.new()`

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_explorer.gd`:
```gdscript
extends GdUnitTestSuite

const Explorer := preload("res://src/apps/explorer.gd")

func _make() -> Control:
	var e: Control = auto_free(Explorer.new())
	add_child(e)
	return e

func test_locked_folder_blocks_until_solved() -> void:
	var e := _make()
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("nope")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()

func test_open_file_marks_read() -> void:
	var e := _make()
	e.open_file("f_essay")
	assert_bool(GameState.is_read("doc:essay_2001")).is_true()
```
(오토로드 GameState는 테스트 프로세스에서 살아 있으므로 테스트 시작 시 `GameState.reset()`을 `before_test()`에서 호출:)
```gdscript
func before_test() -> void:
	GameState.reset()
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/apps/explorer.gd`:
```gdscript
class_name Explorer
extends Control
## 파일 탐색기: 좌측 트리(리스트), 우측 뷰어. 잠긴 폴더는 영숫자 비번 입력.

var _cwd := "mydocs"
var _pending_locked := ""   # 비번 대기 중인 폴더 id
var _list: ItemList
var _viewer: RichTextLabel
var _pw_row: HBoxContainer
var _pw_edit: LineEdit

func _ready() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(220, 0)
	_list.item_activated.connect(_on_activate)
	split.add_child(_list)
	var right := VBoxContainer.new()
	_viewer = RichTextLabel.new()
	_viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer.bbcode_enabled = false
	right.add_child(_viewer)
	_pw_row = HBoxContainer.new()
	_pw_row.visible = false
	_pw_edit = LineEdit.new()
	_pw_edit.max_length = 24
	_pw_edit.placeholder_text = "비밀번호 (영문/숫자)"
	_pw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pw_edit.text_changed.connect(func(t: String):
		var filtered := ""
		for ch in t:
			if ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789":
				filtered += ch
		if filtered != t:
			_pw_edit.text = filtered
			_pw_edit.caret_column = filtered.length())
	var ok := Button.new()
	ok.text = "확인"
	ok.pressed.connect(func(): submit_password(_pw_edit.text))
	_pw_row.add_child(_pw_edit)
	_pw_row.add_child(ok)
	right.add_child(_pw_row)
	split.add_child(right)
	add_child(split)
	_refresh()

func _refresh() -> void:
	_list.clear()
	if _cwd != "root":
		_list.add_item("[..]")
		_list.set_item_metadata(0, "..")
	for n in ContentDB.fs_children(_cwd):
		var name: String = n["name"]
		if n["type"] == "folder":
			name = "[" + name + "]"
			if n.has("locked_by") and not GameState.has_flag(String(n["locked_by"]) + "_solved"):
				name += " *잠김*"
		var i := _list.add_item(name)
		_list.set_item_metadata(i, n["id"])

func _on_activate(i: int) -> void:
	var id: String = _list.get_item_metadata(i)
	if id == "..":
		_cwd = ContentDB.fs_node(_cwd).get("parent", "root")
		_refresh()
		return
	var n := ContentDB.fs_node(id)
	if n["type"] == "folder":
		open_folder(id)
	else:
		open_file(id)

func open_folder(id: String) -> bool:
	var n := ContentDB.fs_node(id)
	var lock: String = n.get("locked_by", "")
	if lock != "" and not GameState.has_flag(lock + "_solved"):
		_pending_locked = id
		_pw_row.visible = true
		_viewer.text = "이 폴더는 비밀번호로 보호되어 있습니다."
		return false
	_cwd = id
	_pw_row.visible = false
	_refresh()
	return true

func submit_password(text: String) -> bool:
	if _pending_locked == "":
		return false
	var lock := String(ContentDB.fs_node(_pending_locked).get("locked_by", ""))
	if GameState.try_answer(lock, text):
		_pw_row.visible = false
		AudioDirector.play_sfx("unlock")
		var target := _pending_locked
		_pending_locked = ""
		return open_folder(target)
	_viewer.text = "비밀번호가 올바르지 않습니다."
	return false

func open_file(node_id: String) -> void:
	var n := ContentDB.fs_node(node_id)
	if n.get("corrupt", false):
		_viewer.text = "파일이 손상되어 열 수 없습니다."
		return
	if n["type"] == "image":
		_viewer.text = "[사진: %s]" % n["name"]  # Task 12에서 TextureRect 표시로 확장
	else:
		var d := ContentDB.doc(n["cid"])
		_viewer.text = String(d["title"]) + "\n\n" + String(d["body"])
	if n.has("cid"):
		GameState.mark_read(n["cid"])
```
`desktop.gd`의 `APP_BUILDERS` 기본값에서 explorer 스텁 교체:
```gdscript
var APP_BUILDERS: Dictionary = {
	"explorer": func() -> Control: return Explorer.new(),
	# 나머지는 각 태스크에서 교체
}
```
(AudioDirector.play_sfx는 Task 12 전까지 스텁 필요 — `game/src/core/audio_director.gd`에 추가:)
```gdscript
extends Node

func play_sfx(_name: String) -> void:
	pass  # Task 12에서 구현
```

- [ ] **Step 4: 통과 확인** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): file explorer with viewer and locked folder (puzzle1)"`

---

### Task 8: 메신저 "단짝" — ChatPlayer·선택지·로그·힌트 엔진

**Files:**
- Create: `game/src/core/chat_player.gd`, `game/src/core/hint_engine.gd`, `game/src/apps/messenger.gd`
- Modify: `game/src/desktop/desktop.gd` (messenger 빌더 교체)
- Test: `game/tests/test_chat_player.gd`, `game/tests/test_hint_engine.gd`

**Interfaces:**
- Produces:
  - `ChatPlayer` (RefCounted): `_init(thread: Dictionary, state: Node)`, `func current() -> Dictionary`, `func advance() -> bool`(next 따라 이동, require 미충족 노드는 대기), `func choose(idx: int) -> void`(set 플래그 적용), `func at_end() -> bool`
  - `HintEngine` (RefCounted): `_init(time_source: Callable)`, `signal hint_ready(puzzle_id: String, level: int)`, `func set_gate(puzzle_id: String) -> void`, `func poll() -> void`, 상수 `FIRST_MS = 300000`, `STEP_MS = 180000`
  - `Messenger` (class_name, extends Control): 대화 탭 + 지난 대화 탭. Desktop 등록 `"messenger"`. 열람 시 로그 cid `mail:`식 대신 `chatlog:<date>` cid로 mark_read
- Consumes: `ContentDB.chat_thread/chat_logs/puzzle`, `GameState`

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_chat_player.gd`:
```gdscript
extends GdUnitTestSuite

const CP := preload("res://src/core/chat_player.gd")

func before_test() -> void:
	GameState.reset()

func test_linear_advance_and_choice_sets_flag() -> void:
	var cp := CP.new(ContentDB.chat_thread(), GameState)
	assert_str(String(cp.current()["text"])).contains("오빠")
	cp.advance()  # n2 (선택지 노드)
	assert_int(cp.current()["choices"].size()).is_equal(2)
	cp.choose(0)  # met_seulgi 플래그
	assert_bool(GameState.has_flag("met_seulgi")).is_true()
```

`game/tests/test_hint_engine.gd`:
```gdscript
extends GdUnitTestSuite

const HE := preload("res://src/core/hint_engine.gd")

var _now := 0

func _clock() -> int:
	return _now

func test_hint_levels_follow_spec_timing() -> void:
	var he := HE.new(Callable(self, "_clock"))
	var fired: Array = []
	he.hint_ready.connect(func(p, l): fired.append([p, l]))
	he.set_gate("puzzle1")
	_now = 4 * 60 * 1000
	he.poll()
	assert_array(fired).is_empty()          # 5분 전: 없음
	_now = 5 * 60 * 1000
	he.poll()
	assert_array(fired).is_equal([["puzzle1", 1]])   # 5분: 1단계
	_now = 8 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(2)    # +3분: 2단계
	_now = 11 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(3)    # +3분: 3단계
	_now = 30 * 60 * 1000
	he.poll()
	assert_int(fired.size()).is_equal(3)    # 3단계 초과 없음

func test_gate_change_resets_timer() -> void:
	var he := HE.new(Callable(self, "_clock"))
	var fired: Array = []
	he.hint_ready.connect(func(p, l): fired.append([p, l]))
	he.set_gate("puzzle1")
	_now = 4 * 60 * 1000
	he.set_gate("puzzle2")
	_now = 8 * 60 * 1000   # puzzle2 기준 4분
	he.poll()
	assert_array(fired).is_empty()
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/core/hint_engine.gd`:
```gdscript
class_name HintEngine
extends RefCounted
## 스펙 §3.2: 같은 게이트 5분 정체 → 1단계, 이후 3분 간격 상승, 최대 3단계.

signal hint_ready(puzzle_id: String, level: int)

const FIRST_MS := 5 * 60 * 1000
const STEP_MS := 3 * 60 * 1000

var _now: Callable
var _gate := ""
var _entered := 0
var _level := 0

func _init(time_source: Callable) -> void:
	_now = time_source

func set_gate(puzzle_id: String) -> void:
	if puzzle_id == _gate:
		return
	_gate = puzzle_id
	_entered = _now.call()
	_level = 0

func poll() -> void:
	if _gate == "" or _level >= 3:
		return
	var elapsed: int = _now.call() - _entered
	var target := 0
	if elapsed >= FIRST_MS + 2 * STEP_MS:
		target = 3
	elif elapsed >= FIRST_MS + STEP_MS:
		target = 2
	elif elapsed >= FIRST_MS:
		target = 1
	while _level < target:
		_level += 1
		hint_ready.emit(_gate, _level)
```

`game/src/core/chat_player.gd`:
```gdscript
class_name ChatPlayer
extends RefCounted
## chat.json 스크립트 순회. require 플래그 게이트, choices의 set 플래그 적용.

var _nodes: Dictionary
var _cur: String
var _state: Node

func _init(thread: Dictionary, state: Node) -> void:
	_nodes = thread["nodes"]
	_cur = thread["start"]
	_state = state

func current() -> Dictionary:
	return _nodes[_cur]

func at_end() -> bool:
	var n := current()
	return not n.has("next") and not n.has("choices")

func advance() -> bool:
	var n := current()
	if not n.has("next"):
		return false
	var nxt: String = n["next"]
	var req := String(_nodes[nxt].get("require", ""))
	if req != "" and not _state.has_flag(req):
		return false  # 플래그 충족 전 대기 (메신저가 flag_changed에서 재시도)
	_cur = nxt
	for f in current().get("set", []):
		_state.set_flag(f)
	return true

func choose(idx: int) -> void:
	var c: Dictionary = current()["choices"][idx]
	for f in c.get("set", []):
		_state.set_flag(f)
	_cur = c["next"]
```

`game/src/apps/messenger.gd`:
```gdscript
class_name Messenger
extends Control
## 단짝: 대화 탭(스크립트 재생 + 선택지) / 지난 대화 탭. 힌트는 슬기 말풍선으로.

var _cp: ChatPlayer
var _hints: HintEngine
var _chat_box: VBoxContainer
var _choice_box: HBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 대화 탭
	var live := VBoxContainer.new()
	live.name = "대화"
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_chat_box)
	live.add_child(_scroll)
	_choice_box = HBoxContainer.new()
	live.add_child(_choice_box)
	tabs.add_child(live)
	# 지난 대화 탭
	var logs := RichTextLabel.new()
	logs.name = "지난 대화"
	for lg in ContentDB.chat_logs():
		logs.append_text("[%s] %s\n" % [lg["date"], lg["with"]])
		for line in lg["lines"]:
			logs.append_text("  %s: %s\n" % [line["from"], line["text"]])
		GameState.mark_read("chatlog:" + String(lg["date"]))
	tabs.add_child(logs)
	add_child(tabs)
	# 스크립트 재생
	_cp = ChatPlayer.new(ContentDB.chat_thread(), GameState)
	_hints = HintEngine.new(func() -> int: return Time.get_ticks_msec())
	_hints.hint_ready.connect(_on_hint)
	GameState.flag_changed.connect(func(_n):
		_hints.set_gate(_current_gate())
		_try_continue())
	_hints.set_gate(_current_gate())
	_show_current()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_hints.poll)
	add_child(timer)

func _current_gate() -> String:
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		if not GameState.has_flag(pid + "_solved"):
			return pid
	return ""

func _bubble(from: String, text: String) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = ("슬기: " if from == "seulgi" else ("나: " if from == "player" else "")) + text
	_chat_box.add_child(l)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _show_current() -> void:
	var n := _cp.current()
	if n["from"] != "sys":
		AudioDirector.play_sfx("msg")
		_bubble(n["from"], n["text"])
	for c in _choice_box.get_children():
		c.queue_free()
	if n.has("choices"):
		for i in n["choices"].size():
			var b := Button.new()
			b.text = n["choices"][i]["text"]
			b.pressed.connect(_on_choice.bind(i))
			_choice_box.add_child(b)
	elif n.has("next"):
		get_tree().create_timer(n.get("delay_ms", 900) / 1000.0).timeout.connect(_try_continue)

func _on_choice(i: int) -> void:
	_bubble("player", _cp.current()["choices"][i]["text"])
	_cp.choose(i)
	_show_current()

func _try_continue() -> void:
	if _cp.advance():
		_show_current()

func _on_hint(puzzle_id: String, level: int) -> void:
	var hints: Array = ContentDB.puzzle(puzzle_id).get("hints", [])
	if level - 1 < hints.size():
		AudioDirector.play_sfx("msg")
		_bubble("seulgi", hints[level - 1])
```
`desktop.gd` APP_BUILDERS에 `"messenger": func() -> Control: return Messenger.new(),` 교체.

- [ ] **Step 4: 통과 확인** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): messenger with chat script, choices, spec-timed hints"`

---

### Task 9: 누리메일 — 메일함 + 첨부 암호(퍼즐2)

**Files:**
- Create: `game/src/apps/mail.gd`
- Modify: `game/src/desktop/desktop.gd` (mail 빌더)
- Test: `game/tests/test_mail.gd`

**Interfaces:**
- Consumes: `ContentDB.mails/doc`, `GameState.mark_read/try_answer/has_flag`
- Produces: `MailApp` (class_name, extends Control): `func open_mail(id: String) -> void`(본문 표시 + `mark_read("mail:"+id)`), `func open_attachment(mail_id: String) -> bool`(해제 전 false), `func submit_password(text: String) -> bool`(퍼즐2)

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_mail.gd`:
```gdscript
extends GdUnitTestSuite

const MailApp := preload("res://src/apps/mail.gd")

func before_test() -> void:
	GameState.reset()

func test_open_mail_marks_read() -> void:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	m.open_mail("m1")
	assert_bool(GameState.is_read("mail:m1")).is_true()

func test_attachment_locked_until_puzzle2() -> void:
	var m: Control = auto_free(MailApp.new())
	add_child(m)
	m.open_mail("m1")
	assert_bool(m.open_attachment("m1")).is_false()
	assert_bool(m.submit_password("030703")).is_true()
	assert_bool(m.open_attachment("m1")).is_true()
	assert_bool(GameState.is_read("doc:doctrine_full")).is_true()
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL. (docs.json에 `doc:doctrine_full` 샘플이 없으면 Task 3 샘플에 추가: `"doc:doctrine_full": {"title": "새빛자료", "body": "샘플"}`)

- [ ] **Step 3: 구현**

`game/src/apps/mail.gd`:
```gdscript
class_name MailApp
extends Control
## 누리메일: 좌측 메일 목록, 우측 본문. 첨부는 영숫자 암호 게이트(퍼즐2).

var _list: ItemList
var _view: RichTextLabel
var _pw_row: HBoxContainer
var _pw_edit: LineEdit
var _current_mail := ""
var _pending_attachment := ""

func _ready() -> void:
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(240, 0)
	for m in ContentDB.mails():
		var i := _list.add_item("%s — %s" % [m["from"], m["subject"]])
		_list.set_item_metadata(i, m["id"])
	_list.item_activated.connect(func(i): open_mail(_list.get_item_metadata(i)))
	split.add_child(_list)
	var right := VBoxContainer.new()
	_view = RichTextLabel.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_view)
	_pw_row = HBoxContainer.new()
	_pw_row.visible = false
	_pw_edit = LineEdit.new()
	_pw_edit.placeholder_text = "첨부파일 암호 (영문/숫자)"
	_pw_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := Button.new()
	ok.text = "열기"
	ok.pressed.connect(func(): submit_password(_pw_edit.text))
	_pw_row.add_child(_pw_edit)
	_pw_row.add_child(ok)
	right.add_child(_pw_row)
	var att := Button.new()
	att.text = "첨부파일"
	att.pressed.connect(func(): open_attachment(_current_mail))
	right.add_child(att)
	split.add_child(right)
	add_child(split)

func _mail(id: String) -> Dictionary:
	for m in ContentDB.mails():
		if m["id"] == id:
			return m
	return {}

func open_mail(id: String) -> void:
	var m := _mail(id)
	_current_mail = id
	_view.text = "보낸사람: %s\n날짜: %s\n제목: %s\n\n%s" % [m["from"], m["date"], m["subject"], m["body"]]
	if m.has("attachment"):
		_view.text += "\n\n[첨부: %s]" % m["attachment"]["name"]
	GameState.mark_read("mail:" + id)

func open_attachment(mail_id: String) -> bool:
	var m := _mail(mail_id)
	if not m.has("attachment"):
		return false
	var a: Dictionary = m["attachment"]
	if not GameState.has_flag(String(a["locked_by"]) + "_solved"):
		_pending_attachment = mail_id
		_pw_row.visible = true
		return false
	var d := ContentDB.doc(a["cid"])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	GameState.mark_read(a["cid"])
	return true

func submit_password(text: String) -> bool:
	if _pending_attachment == "":
		return false
	var a: Dictionary = _mail(_pending_attachment)["attachment"]
	if GameState.try_answer(a["locked_by"], text):
		_pw_row.visible = false
		AudioDirector.play_sfx("unlock")
		var t := _pending_attachment
		_pending_attachment = ""
		return open_attachment(t)
	return false
```
`desktop.gd` APP_BUILDERS에 `"mail"` 교체.

- [ ] **Step 4: 통과 확인** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): mail app with locked attachment (puzzle2)"`

---

### Task 10: 누리서퍼 — 주소창·즐겨찾기·캐시 페이지(퍼즐3)·마이홈

**Files:**
- Create: `game/src/apps/browser.gd`
- Modify: `game/src/desktop/desktop.gd` (browser 빌더 + 아이콘)
- Test: `game/tests/test_browser.gd`

**Interfaces:**
- Consumes: `ContentDB.web_bookmarks/web_page`, `GameState.mark_read/try_answer/set_flag`
- Produces: `BrowserApp` (class_name, extends Control): `func navigate(url: String) -> Dictionary`(페이지 dict 반환, 미존재 시 `{}` + "페이지를 찾을 수 없습니다" 표시). `requires: "puzzle3"` 페이지는 **주소 자체가 정답** — navigate가 정답 URL과 일치하면 `GameState.try_answer("puzzle3", url)` 후 표시. 페이지에 cid 있으면 mark_read.

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_browser.gd`:
```gdscript
extends GdUnitTestSuite

const BrowserApp := preload("res://src/apps/browser.gd")

func before_test() -> void:
	GameState.reset()

func test_dead_cafe_page_renders_closed_notice() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page := b.navigate("cafe.nurinet.co.kr/saebit")
	assert_str(String(page["title"])).contains("찾을 수 없습니다")

func test_gate_url_solves_puzzle3_and_marks_record() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page := b.navigate("cafe.nurinet.co.kr/saebit/gate")
	assert_bool(GameState.has_flag("puzzle3_solved")).is_true()
	assert_bool(GameState.is_read("web:cafe_gate")).is_true()
	assert_str(String(page["title"])).contains("새빛")

func test_unknown_url_returns_empty() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	assert_bool(b.navigate("nowhere.example").is_empty()).is_true()
```

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/apps/browser.gd`:
```gdscript
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
```
`desktop.gd` APP_BUILDERS에 `"browser"` 추가 (strings.json에 `"app_browser"` 라벨은 Task 3에서 이미 존재).

- [ ] **Step 4: 통과 확인** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): browser with address bar and cached cafe page (puzzle3)"`

---

### Task 11: 휴지통(퍼즐4) + 엔딩 2종

**Files:**
- Create: `game/src/apps/trash.gd`, `game/src/ending/ending.gd`
- Modify: `game/src/desktop/desktop.gd` (trash 빌더, 엔딩 트리거 연결)
- Test: `game/tests/test_trash_and_ending.gd`

**Interfaces:**
- Consumes: `ContentDB.trash_items/doc/puzzle`, `GameState`
- Produces:
  - `TrashApp` (class_name, extends Control): `func restore(node_id: String) -> bool` — 퍼즐4 target이 아니면 "파일이 손상되었습니다" false; target이면 `try_answer("puzzle4", node_id)` → 문서 표시 + mark_read + `GameState.set_flag("final_diary_read")`
  - `EndingScene` (class_name, extends CanvasLayer): `func play(hidden: bool) -> void` — 본편 에필로그 타이핑, hidden=true면 낯선 계정 신 추가. `static func should_show_hidden() -> bool` = `GameState.records_count() == 9`
  - 엔딩 트리거: 메신저 스크립트의 `set: ["ending_start"]` 플래그 → Desktop이 `flag_changed`에서 EndingScene 재생
- 주의: 퍼즐4는 try_answer의 대소문자 무시 비교를 그대로 쓰되 answer가 node id("t1")라는 점이 다른 퍼즐과 동일 구조임

- [ ] **Step 1: 실패하는 테스트 작성**

`game/tests/test_trash_and_ending.gd`:
```gdscript
extends GdUnitTestSuite

const TrashApp := preload("res://src/apps/trash.gd")
const EndingScene := preload("res://src/ending/ending.gd")

func before_test() -> void:
	GameState.reset()

func test_restore_decoy_fails_target_succeeds() -> void:
	var t: Control = auto_free(TrashApp.new())
	add_child(t)
	assert_bool(t.restore("t2")).is_false()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_false()
	assert_bool(t.restore("t1")).is_true()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_true()
	assert_bool(GameState.has_flag("final_diary_read")).is_true()
	assert_bool(GameState.is_read("doc:diary_final")).is_true()

func test_hidden_ending_gate_counts_records() -> void:
	# records_source를 좁혀 2개만 기록물로 두고 검증
	assert_bool(EndingScene.should_show_hidden()).is_false()
	for cid in ContentDB.records():
		GameState.mark_read(cid)
	# 샘플 콘텐츠는 기록물 2개 — 9개 규칙은 Task 13 콘텐츠 완성 후 유효
	assert_int(GameState.records_count()).is_equal(ContentDB.records().size())
```
(should_show_hidden의 9개 검증은 콘텐츠 완성 전이므로 `GameState.records_count() == ContentDB.records().size() and ContentDB.records().size() > 0` 로 구현 — Task 13에서 검증기가 9개를 강제하므로 결과적으로 스펙과 일치)

- [ ] **Step 2: 실패 확인** — Expected: FAIL.

- [ ] **Step 3: 구현**

`game/src/apps/trash.gd`:
```gdscript
class_name TrashApp
extends Control
## 휴지통: 삭제된 파일 목록. 올바른 파일 복원 = 퍼즐4.

var _list: ItemList
var _view: RichTextLabel

func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 160)
	for n in ContentDB.trash_items():
		var i := _list.add_item(n["name"])
		_list.set_item_metadata(i, n["id"])
	box.add_child(_list)
	var btn := Button.new()
	btn.text = "복원"
	btn.pressed.connect(func():
		var sel := _list.get_selected_items()
		if sel.size() > 0:
			restore(_list.get_item_metadata(sel[0])))
	box.add_child(btn)
	_view = RichTextLabel.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_view)
	add_child(box)

func restore(node_id: String) -> bool:
	if not GameState.try_answer("puzzle4", node_id):
		_view.text = "복원 실패: 파일이 손상되었습니다."
		return false
	var n := ContentDB.fs_node(node_id)
	var d := ContentDB.doc(n["cid"])
	_view.text = String(d["title"]) + "\n\n" + String(d["body"])
	GameState.mark_read(n["cid"])
	GameState.set_flag("final_diary_read")
	AudioDirector.play_sfx("unlock")
	return true
```

`game/src/ending/ending.gd`:
```gdscript
class_name EndingScene
extends CanvasLayer
## 엔딩: 페이드 아웃 → 에필로그 타이핑. 기록물 9개 전부 열람 시 숨겨진 신 추가.

const EPILOGUE := [
	"당신은 마지막 대화 내용을 저장하고, 컴퓨터를 껐다.",
	"다음 날, 슬기에게서 문자가 왔다.",
	"\"거기 가봤어요. 오빠 물건이 있었어요. 고마워요.\"",
	"", "LAST LOGIN",
]
const HIDDEN := [
	"…전원을 끄기 직전, 메신저가 울렸다.",
	"[알 수 없음]: 그 컴퓨터, 어디서 나셨어요?",
]

static func should_show_hidden() -> bool:
	return ContentDB.records().size() > 0 \
		and GameState.records_count() == ContentDB.records().size()

func play(hidden: bool) -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	add_child(bg)
	var label := RichTextLabel.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 120
	label.offset_top = 200
	label.offset_right = -120
	label.add_theme_color_override("default_color", Color("cfe8dc"))
	add_child(label)
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 2.0)
	tw.tween_callback(func(): _type_lines(label, EPILOGUE, hidden))

func _type_lines(label: RichTextLabel, lines: Array, then_hidden: bool) -> void:
	var i := 0
	var next: Callable
	next = func():
		if i < lines.size():
			label.append_text(lines[i] + "\n")
			i += 1
			get_tree().create_timer(1.4).timeout.connect(next)
		elif then_hidden and should_show_hidden():
			get_tree().create_timer(2.0).timeout.connect(
				func():
					AudioDirector.play_sfx("msg")
					_type_lines(label, HIDDEN, false))
	next.call()
```
`desktop.gd` `_ready()`에 엔딩 트리거 추가:
```gdscript
	GameState.flag_changed.connect(func(n):
		if n == "ending_start":
			var e := EndingScene.new()
			add_child(e)
			e.play(true))
```
APP_BUILDERS에 `"trash"` 교체.

- [ ] **Step 4: 통과 확인** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): trash restore (puzzle4), main and hidden endings"`

---

### Task 12: AudioDirector + 에셋 생성 파이프라인 (사운드·아이콘·사진)

**Files:**
- Modify: `game/src/core/audio_director.gd`, `game/src/apps/explorer.gd`(사진 표시), `game/CREDITS.md`
- Create: `scripts/gen_audio.py`, `scripts/gen_icons.py`, `scripts/degrade_photo.py`, `game/assets/sfx/*.wav`, `game/assets/img/icons/*.png`, `game/assets/img/photos/*.png`
- Test: `game/tests/test_audio_director.gd`

**Interfaces:**
- Consumes: `GameState.act_changed`
- Produces: `AudioDirector.play_sfx(name: String)` 구현("msg", "unlock", "click", "boot"), `func active_layers() -> int`(액트 n → 앰비언트 레이어 n개 재생), 사진 파일 규약 `res://assets/img/photos/<name>.png` (fs.json image 노드의 `image` 필드가 이 경로)

- [ ] **Step 1: 사운드 신디사이징 스크립트**

`scripts/gen_audio.py` — 표준 라이브러리만 사용(wave, math, random). 전량 자작 = 라이선스 청정:
```python
"""LAST LOGIN 사운드 전량 신디사이징. 사용: python scripts/gen_audio.py"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join("game", "assets", "sfx")

def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))

def env(i, n, a=0.01, r=0.3):
    t = i / SR
    dur = n / SR
    return min(t / a, 1.0, max(0.0, (dur - t) / (dur * r)))

def tone(freq, dur, vol=0.5):
    n = int(SR * dur)
    return [vol * env(i, n) * math.sin(2 * math.pi * freq * i / SR) for i in range(n)]

def noise(dur, vol=0.15, lp=0.02):
    n = int(SR * dur); out = []; acc = 0.0
    for _ in range(n):
        acc += lp * (random.uniform(-1, 1) - acc)   # 저역 통과 = 팬 소음 질감
        out.append(vol * acc / lp * 0.05)
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]

# SFX
write("msg.wav", tone(880, 0.09) + tone(1320, 0.12))          # 메신저 알림 두 음
write("unlock.wav", tone(523, 0.08) + tone(784, 0.16))
write("click.wav", tone(2000, 0.03, 0.2))
write("boot.wav", mix(tone(220, 0.8, 0.3), tone(331, 0.8, 0.2)))
# 앰비언트 루프 (act 1/2/3 겹침용)
write("amb_fan.wav", noise(6.0, 0.5))                          # 레이어 1: 팬
write("amb_hum.wav", tone(120, 6.0, 0.06) )                    # 레이어 2: 형광등 험
write("amb_drone.wav", mix(tone(55, 6.0, 0.10), tone(58, 6.0, 0.08)))  # 레이어 3: 불협 드론
print("ok")
```
Run: `python scripts/gen_audio.py` → Expected: `ok`, `game/assets/sfx/`에 wav 7개.

- [ ] **Step 2: 아이콘·사진 스크립트**

`scripts/gen_icons.py` — Pillow로 32×32 픽셀 아이콘(폴더/문서/메신저/메일/브라우저/휴지통/사진). 팔레트는 NuriTheme 색 계열. `pip install pillow` 후 실행:
```python
"""32x32 픽셀 아이콘 생성. 사용: python scripts/gen_icons.py"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join("game", "assets", "img", "icons")
os.makedirs(OUT, exist_ok=True)

def canvas():
    return Image.new("RGBA", (32, 32), (0, 0, 0, 0))

def save(img, name):
    img.save(os.path.join(OUT, name))

# 폴더
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([2, 10, 29, 27], fill=(216, 180, 96), outline=(96, 72, 24))
d.rectangle([2, 6, 14, 12], fill=(216, 180, 96), outline=(96, 72, 24))
save(img, "folder.png")
# 문서
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([6, 3, 25, 29], fill=(240, 240, 232), outline=(90, 90, 90))
for y in (9, 13, 17, 21):
    d.line([9, y, 22, y], fill=(120, 120, 140))
save(img, "doc.png")
# 메신저(말풍선), 메일(봉투), 브라우저(지구), 휴지통(통), 사진(산) — 같은 방식으로 각각 도형 조합
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([3, 5, 28, 23], fill=(120, 200, 240), outline=(30, 90, 130))
d.polygon([(10, 22), (12, 28), (16, 22)], fill=(120, 200, 240))
save(img, "messenger.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 8, 28, 24], fill=(240, 240, 232), outline=(90, 90, 90))
d.line([3, 8, 16, 17], fill=(90, 90, 90)); d.line([28, 8, 16, 17], fill=(90, 90, 90))
save(img, "mail.png")
img = canvas(); d = ImageDraw.Draw(img)
d.ellipse([4, 4, 27, 27], fill=(90, 170, 220), outline=(20, 70, 110))
d.line([4, 16, 27, 16], fill=(20, 70, 110)); d.arc([9, 4, 22, 27], 0, 360, fill=(20, 70, 110))
save(img, "browser.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([8, 8, 23, 28], fill=(160, 168, 176), outline=(70, 74, 80))
d.rectangle([6, 5, 25, 8], fill=(160, 168, 176), outline=(70, 74, 80))
save(img, "trash.png")
img = canvas(); d = ImageDraw.Draw(img)
d.rectangle([3, 5, 28, 26], fill=(200, 220, 240), outline=(80, 90, 100))
d.polygon([(6, 24), (14, 12), (20, 20), (24, 15), (27, 24)], fill=(80, 140, 90))
save(img, "photo.png")
print("ok")
```
`scripts/degrade_photo.py` — AI 생성 원본(`scripts/photo_src/*.png`)을 디카 화질로:
```python
"""사진 열화: 640x480 축소 → 노이즈 → JPEG q=35 재압축 → PNG 저장.
사용: python scripts/degrade_photo.py  (scripts/photo_src/ 의 모든 이미지 처리)"""
from PIL import Image
import io, os, random

SRC = os.path.join("scripts", "photo_src")
OUT = os.path.join("game", "assets", "img", "photos")
os.makedirs(OUT, exist_ok=True)
for name in os.listdir(SRC) if os.path.isdir(SRC) else []:
    img = Image.open(os.path.join(SRC, name)).convert("RGB").resize((640, 480))
    px = img.load()
    for _ in range(20000):
        x, y = random.randrange(640), random.randrange(480)
        r, g, b = px[x, y]
        n = random.randint(-14, 14)
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=35)
    Image.open(buf).save(os.path.join(OUT, os.path.splitext(name)[0] + ".png"))
print("ok")
```
Run: `python scripts/gen_icons.py` → Expected: `ok`, icons 7개. (사진 원본은 Task 13에서 AI 생성 후 이 스크립트로 처리 — higgsfield 스킬 사용, 불가 시 절차 생성 플레이스홀더)

- [ ] **Step 3: AudioDirector 테스트 작성 → 실패 확인**

`game/tests/test_audio_director.gd`:
```gdscript
extends GdUnitTestSuite

func test_layers_follow_act() -> void:
	GameState.reset()
	assert_int(AudioDirector.active_layers()).is_equal(1)
	GameState.set_flag("puzzle1_solved")
	assert_int(AudioDirector.active_layers()).is_equal(2)
	GameState.set_flag("puzzle3_solved")
	assert_int(AudioDirector.active_layers()).is_equal(3)
```
Run → Expected: FAIL.

- [ ] **Step 4: AudioDirector 구현**

`game/src/core/audio_director.gd` 교체:
```gdscript
extends Node
## 앰비언트 레이어(액트 수만큼 겹침) + SFX 원샷.

const SFX := {
	"msg": "res://assets/sfx/msg.wav", "unlock": "res://assets/sfx/unlock.wav",
	"click": "res://assets/sfx/click.wav", "boot": "res://assets/sfx/boot.wav",
}
const LAYERS := ["res://assets/sfx/amb_fan.wav", "res://assets/sfx/amb_hum.wav", "res://assets/sfx/amb_drone.wav"]

var _layer_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for path in LAYERS:
		var p := AudioStreamPlayer.new()
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = stream.data.size() / 2
			p.stream = stream
		p.volume_db = -14.0
		add_child(p)
		_layer_players.append(p)
	GameState.act_changed.connect(func(_a): _sync_layers())
	_sync_layers()

func _sync_layers() -> void:
	for i in _layer_players.size():
		var should := i < GameState.current_act()
		var p := _layer_players[i]
		if should and not p.playing and p.stream != null:
			p.play()
		elif not should and p.playing:
			p.stop()

func active_layers() -> int:
	return GameState.current_act()

func play_sfx(name: String) -> void:
	if not SFX.has(name) or not ResourceLoader.exists(SFX[name]):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(SFX[name])
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
```
`explorer.gd`의 image 분기 교체(사진 표시):
```gdscript
	if n["type"] == "image":
		_viewer.text = ""
		# 뷰어 위에 TextureRect를 임시 표시
		for c in get_children():
			if c is TextureRect:
				c.queue_free()
		var tr := TextureRect.new()
		tr.texture = load(n["image"])
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(tr)
		tr.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				tr.queue_free())
```
데스크톱 아이콘을 텍스트 버튼에서 아이콘+라벨로 업그레이드: `desktop.gd` `_build_icons()`의 Button에 `b.icon = load("res://assets/img/icons/<id에 맞는>.png")` (매핑: explorer→folder.png, messenger→messenger.png, mail→mail.png, browser→browser.png, trash→trash.png).

- [ ] **Step 5: 통과 확인 + 수동 사운드 스모크** — 공통 커맨드 PASS + `& $GODOT --path game`으로 알림음·앰비언트 확인.
- [ ] **Step 6: CREDITS 갱신 + Commit** — CREDITS.md에 "사운드/아이콘: scripts/로 자체 생성" 명시. `git commit -m "feat(game): audio director, synthesized sfx, pixel icons, photo pipeline"`

---

### Task 13: 시나리오 콘텐츠 풀 패스 (문서 40–60개 + 본편 대화 + 기록물 9개 확정)

**Files:**
- Modify: `game/content/*.json` 전체 교체(샘플 → 본편), `game/tests/test_content_db.gd`(9개 규칙 활성 검증 추가)
- Create: `scripts/photo_src/*.png` (AI 생성 사진 원본)

**Interfaces:**
- Consumes: 스펙 §2(스토리)·§3(퍼즐), Task 3 스키마, 퍼즐 정답(20020316 / 030703 / cafe.nurinet.co.kr/saebit/gate / t1 — **변경 금지**, 코드·테스트가 참조)
- Produces: 완성 콘텐츠. `strings.json`에서 `dev_allow_partial_records` 제거 → 검증기가 기록물 정확히 9개 강제

**콘텐츠 집필 지침** (스펙 §2 서사 원칙 준수 — 직접 묘사 없이 암시로):

| 그룹 | 수량 | 내용 |
|---|---|---|
| Act 1 일상 | 문서 8–12 | 낙방 수기, 이력서 hwp풍, 스터디 메모, 가족사진 3–4장, 어머니 제사 메모, 봄이(강아지) 사진 |
| Act 2 심취 | 문서 12–18 | 교리 필사 3편(새빛력 3년 7월 3일 포함), 헌금 입금내역표, 수련회 후기, 절교 채팅로그 2건, 헌금 요구 메일 4–6통, 스팸 2통(시대 유머) |
| Act 3 탈출 | 문서 6–10 | 탈퇴 시도 메모, 협박성 메일 2통, 마지막 일기(diary_final — 수련원 위치 단서), 부치지 못한 편지 |
| 웹 | 페이지 5–8 | 마이홈 미니홈피(봄이 게시글 = 퍼즐1 단서), 폐쇄 카페, 캐시 gate 페이지(교단 실체), 포털 메인 |
| 슬기 대화 | 노드 40–60 | 액트별 게이트: met_seulgi → 퍼즐별 보고 노드(require: puzzleN_solved) → ending_start 선택지 |

**기록물 9개 확정** (records.json — 각 파일이 이 cid를 실제로 갖도록):
```json
{"records": [
  "doc:essay_2001", "img:family_photo", "doc:donation_ledger",
  "chatlog:2002-10-05", "doc:doctrine_2", "mail:m_demand_3",
  "web:cafe_gate", "web:myhome_secret", "doc:diary_final"
]}
```
(mark_read 규약 재확인: 탐색기 doc/image → cid, 메신저 로그 → `chatlog:<date>`, 메일 → `mail:<id>`, 웹 → 페이지 cid. `img:` cid는 fs.json image 노드에 `"cid": "img:family_photo"` 부여)

- [ ] **Step 1: 검증 강화 테스트 추가** — `test_content_db.gd`에:
```gdscript
func test_exactly_nine_records_enforced() -> void:
	var db := _make()
	assert_int(db.records().size()).is_equal(9)
```
Run → Expected: FAIL(샘플은 2개).

- [ ] **Step 2: 본편 콘텐츠 집필** — 위 지침대로 8개 JSON 완성. 사진 원본은 higgsfield 이미지 생성(프롬프트 예: "2002 Korean family snapshot, film grain, no real person likeness") → `scripts/photo_src/` → `python scripts/degrade_photo.py`. AI 생성 불가 환경이면 단색+도형 플레이스홀더로 진행하고 후속 교체 태스크를 만든다.
- [ ] **Step 3: `dev_allow_partial_records` 제거** — strings.json에서 키 삭제.
- [ ] **Step 4: 전체 테스트** — 공통 커맨드. Expected: 전부 PASS(검증기·9개 규칙·기존 퍼즐 테스트 모두).
- [ ] **Step 5: 전체 플레이 수동 확인** — `& $GODOT --path game` 부팅→4퍼즐→엔딩. 숨겨진 엔딩: 기록물 9개 열람 후 확인.
- [ ] **Step 6: Commit** — `git commit -m "content(game): full scenario — 40+ documents, seulgi thread, 9 records"`

---

### Task 14: 웹 익스포트 + NEO_KIDO 카트리지 등록 + 최종 검증

**Files:**
- Create: `game/export_presets.cfg`, `game/web/shell.html`, `public/games/last-login/*`(익스포트 산출물), `content/games/last-login.json`, `docs/superpowers/specs/last-login-playtest.md`

**Interfaces:**
- Consumes: 사이트의 게임 레코드 스키마(`src/lib/games.ts` — **먼저 Read해서 필드명 확인**), 기존 레코드 예시(`content/games/*.json`)
- Produces: 브라우저에서 플레이되는 LAST LOGIN 카트리지

- [ ] **Step 1: 익스포트 템플릿 설치**

```powershell
$ver = (& $GODOT --version).Trim()            # 예: 4.5.1.stable.official.xxxx
$verDir = ($ver -split "\.official")[0]       # 4.5.1.stable
$rel = gh api repos/godotengine/godot/releases/latest --jq .tag_name
gh release download $rel -R godotengine/godot -p "Godot_v${rel}_export_templates.tpz" -D "$env:TEMP"
Rename-Item "$env:TEMP\Godot_v${rel}_export_templates.tpz" "templates.zip" -Force
Expand-Archive "$env:TEMP\templates.zip" -DestinationPath "$env:TEMP\godot_tpl" -Force
New-Item -ItemType Directory -Force "$env:APPDATA\Godot\export_templates\$verDir"
Copy-Item "$env:TEMP\godot_tpl\templates\*" "$env:APPDATA\Godot\export_templates\$verDir\" -Recurse -Force
```
Expected: `$env:APPDATA\Godot\export_templates\<ver>\web_nothreads_release.zip` 존재.

- [ ] **Step 2: 커스텀 HTML 셸 (부팅 룩)**

`$env:APPDATA\...\web_nothreads_release.zip` 안의 기본 셸을 기반으로 `game/web/shell.html` 생성: 압축에서 기본 html을 꺼내 **CSS만 수정** — `body { background:#000; }`, 로딩 진행 표시 위에 고정 텍스트 블록 추가:
```html
<div style="position:fixed;top:24px;left:24px;color:#9adfc0;font-family:monospace;white-space:pre">HANBYUL Computer BIOS v2.02
Memory Test : 131072K OK
Loading NURI-OS ...</div>
```
Godot 플레이스홀더(`$GODOT_CONFIG` 등)는 그대로 유지한다(삭제·개명 금지).

- [ ] **Step 3: export_presets.cfg**

`game/export_presets.cfg`:
```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
export_path="../public/games/last-login/index.html"

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
html/custom_html_shell="res://web/shell.html"
```

- [ ] **Step 4: 익스포트 실행**

```powershell
New-Item -ItemType Directory -Force "public\games\last-login"
& $GODOT --headless --path game --export-release "Web" "../public/games/last-login/index.html"
Get-ChildItem "public\games\last-login"
```
Expected: index.html, .js, .wasm, .pck 생성. 파일당 100MB 미만 확인(스펙 §8 Vercel 한도).

- [ ] **Step 5: 게임 레코드 등록**

먼저 `src/lib/games.ts`와 기존 `content/games/*.json` 하나를 Read해 정확한 필드명 확인 후, 같은 스키마로 `content/games/last-login.json` 작성. 내용 요구사항(스펙 §8): 제목 `LAST LOGIN`, 한글 부제 `마지막 접속`, 설명(한국어, 로그라인 기반), 태그에 `MOUSE REQUIRED` 포함, `playPath`는 `/games/last-login/index.html`.

- [ ] **Step 6: 사이트 통합 검증**

```powershell
npm test
npm run build
```
Expected: 게임 레코드 검증 포함 전부 PASS, 빌드 성공. 이어서 `npm run dev` → 브라우저에서 카트리지 확인 → PLAY → 게임 로드/부팅/저장(새로고침 후 이어하기) 확인.

- [ ] **Step 7: 플레이테스트 체크리스트 작성**

`docs/superpowers/specs/last-login-playtest.md`:
```markdown
# LAST LOGIN 플레이테스트 체크리스트
- [ ] 완주 시간 30–45분 이내 (측정값: ___분)
- [ ] 퍼즐 1–4 각각: 힌트 없이 풀리는가 / 막힌 지점 메모
- [ ] 힌트: 5분 정체 시 1단계, 3분 간격 상승 확인
- [ ] 저장: 브라우저 새로고침 후 이어하기 정상
- [ ] 숨겨진 엔딩: 기록물 9개 열람 시에만 발동
- [ ] OS 정상 원칙: 글리치·점프스케어 없음 확인
- [ ] 사운드: 액트별 앰비언트 레이어 증가 체감
- [ ] 1024×768 레터박스: 다양한 창 크기에서 왜곡 없음
```

- [ ] **Step 8: Commit**

```powershell
git add game public/games/last-login content/games/last-login.json docs/superpowers/specs/last-login-playtest.md
git commit -m "feat(game): web export pipeline and NEO_KIDO cartridge registration"
```

---

## Self-Review 기록

- **스펙 커버리지**: §2 스토리(Task 3 샘플→13 본편), §3 퍼즐 4종·힌트 타이밍(Task 2·8, 타이밍 상수는 스펙 값 그대로), §4 OS·프로그램 6종(Task 4–11; 메모장·그림판 소품은 Task 13 콘텐츠에서 fs 노드로 — 뷰어 재사용), §5 연출(Task 5 CRT·6 부팅·12 사운드), §6 에셋(Task 1 폰트·12 파이프라인), §7 기술(Task 1·14), §8 통합(Task 14), §9 검증(각 태스크 TDD + Task 14 체크리스트), §10 범위 제외 준수.
- **타입 일관성**: `try_answer(puzzle_id, input) -> bool`, `mark_read(cid)`, `records_count()`, `APP_BUILDERS`, `play_sfx(name)` — 전 태스크 동일 시그니처 확인.
- **알려진 유연점**: gdUnit4 API 상세(assert 체이닝 등)는 설치 버전에 따라 미세 조정 가능. 익스포트 템플릿 압축 내부 경로가 버전에 따라 다르면 Step 1에서 실제 구조를 확인하고 맞춘다.
