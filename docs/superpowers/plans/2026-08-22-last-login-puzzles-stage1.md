# LAST LOGIN 데스크톱 조작형 퍼즐 — 1·2단계 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** '성진이만' 폴더에 숨겨진 `그릇기록_0803.txt`를 탐색기 보기 메뉴로 드러내고, 그 손글씨 제출본 사진과 맞대어 성진이 자기 사본에서 지운 한 문단(조 소견)을 플레이어가 찾아내게 한다.

**Architecture:** 새 앱을 만들지 않는다. `ContentDB.fs_children()`에 숨김 필터를 넣고, 탐색기 도구모음의 보기 버튼 두 개를 `PopupMenu` 드롭다운으로 승격한다. 사진 뷰어를 `explorer.gd` 안의 인라인 함수에서 `PhotoView` 클래스로 추출해 확대(1x/2x)와 히트 영역을 붙인다. 대조 판정은 `WindowManager.is_open()`이 이미 제공하므로 새 창 시스템 작업이 없다. 퍼즐 판정은 정답 문자열이 아니라 플래그이므로 `puzzles.json`에 `kind: "action"`을 도입하고 `ContentDB.validate()`가 그 종류를 통과시키게 한다.

**Tech Stack:** Godot 4.7.1 (GDScript), gdUnit4, Python 3 + Pillow (손글씨 사진 생성)

## Global Constraints

- Godot 실행 파일: `$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"` (4.7.1.stable)
- 게임 프로젝트 루트: `games-src/last-login` — 모든 Godot 명령은 `--path games-src/last-login`
- 테스트 실행(게임 프로젝트 디렉토리에서): `$env:GODOT_BIN = $GODOT; cmd /c "addons\gdUnit4\runtest.cmd -a tests"` — Expected: 0 errors / 0 failures, exit 0. `.godot/`를 지웠다면 먼저 캐시 프라이밍 `& $GODOT --headless --editor --path . --quit`
- **익스포트는 파스 에러여도 성공한다.** 웹 재익스포트 전에 반드시 부트 스모크를 돌린다: `& $GODOT --headless --path games-src/last-login --quit`
- GDScript 함정: 비타입 배열 for 루프 변수는 Variant다. `for x in [...]` 안에서 `var y := x + 1` 같은 타입 추론은 워닝=에러로 파스 실패한다 — `for x: Vector2i in [...]`처럼 타입을 명시할 것
- 기록물은 이 플랜에서 **9개 그대로 둔다.** `records.json`을 건드리지 않는다 (12개 전환은 6단계 별도 플랜)
- 퍼즐 1~4의 정답·힌트·판정을 건드리지 않는다
- 새 문서·대사는 인물 설정집 §7 목소리 대조표와 맞춘다: 성진은 짧은 문장, `<< >>` 자기 검열 괄호, 마지막에 한 발 물러섬. 슬기는 `??`·`;;`·`ㅋㅋ` 없이 2003년 문체(마침표, 짧게)
- 성진의 생사를 확정하는 문장을 쓰지 않는다. `○○ 님`에 이름·이니셜을 주지 않는다
- 스펙: `docs/superpowers/specs/2026-08-22-last-login-desktop-puzzles-design.md`

---

## File Structure

| 파일 | 책임 | 이 플랜에서 |
|---|---|---|
| `games-src/last-login/content/fs.json` | 파일 트리·서사 시간표 | `l_bowl`(숨김) · `s_photo4` 노드 추가 |
| `games-src/last-login/content/docs.json` | 문서 본문 | `doc:bowl_record` 추가 · `doc:evidence_memo` 한 줄 추가 |
| `games-src/last-login/content/puzzles.json` | 퍼즐 정답·힌트 | `hidden_file` · `bowl_diff` (kind: action) 추가 |
| `games-src/last-login/content/chat.json` | 슬기 대화·힌트 | 힌트 6줄 · 분기 1건 |
| `games-src/last-login/src/core/content_db.gd` | 콘텐츠 로드·검증·질의 | 숨김 필터 · `fs_children_all()` · action 퍼즐 검증 |
| `games-src/last-login/src/core/game_state.gd` | 진행 상태 | `clear_flag()` |
| `games-src/last-login/src/apps/explorer.gd` | 탐색기 | 보기 드롭다운 · 상태표시줄 전체 개수 · `PhotoView` 사용 |
| `games-src/last-login/src/apps/photo_view.gd` | **신규** — 사진 창 내용물 | 확대 1x/2x · 히트 영역 · uv 계산 |
| `scripts/gen_pilsa_photos.py` | 손글씨 사진 생성 | 제출본 전용 페이지 추가 · 히트 bbox 출력 |
| `games-src/last-login/assets/img/photos/bowl_record.png` | **신규 아트** | 그릇기록 제출본 |
| `games-src/last-login/tests/test_content_db.gd` | | 숨김 필터 · action 퍼즐 검증 테스트 |
| `games-src/last-login/tests/test_explorer.gd` | | 보기 메뉴 · 상태표시줄 · 대조 판정 테스트 |
| `games-src/last-login/tests/test_photo_view.gd` | **신규** | uv 계산 · 히트 영역 순수 테스트 |

---

### Task 1: 그릇기록 콘텐츠 — 숨겨진 문서와 그것을 가리키는 한 줄

**Files:**
- Modify: `games-src/last-login/content/docs.json`
- Modify: `games-src/last-login/content/fs.json`
- Test: `games-src/last-login/tests/test_content_db.gd`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: fs 노드 id `l_bowl`, cid `doc:bowl_record`. 이후 태스크가 이 두 문자열을 쓴다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`games-src/last-login/tests/test_content_db.gd` 끝에 추가:

```gdscript
func test_bowl_record_is_hidden_inside_locked_folder() -> void:
	var n := ContentDB.fs_node("l_bowl")
	assert_dict(n).is_not_empty()
	assert_str(String(n.get("parent", ""))).is_equal("locked")
	assert_bool(n.get("hidden", false)).is_true()
	assert_str(String(n.get("cid", ""))).is_equal("doc:bowl_record")

func test_bowl_record_body_has_no_observation_paragraph() -> void:
	## 제출본에만 있는 문단이다 — 사본에 있으면 퍼즐6이 성립하지 않는다
	var body := String(ContentDB.doc("doc:bowl_record").get("body", ""))
	assert_str(body).is_not_empty()
	assert_str(body).not_contains("○○ 님은")

func test_evidence_memo_points_at_the_hidden_file() -> void:
	var body := String(ContentDB.doc("doc:evidence_memo").get("body", ""))
	assert_str(body).contains("안 보이게 해놨다")
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_content_db.gd"
```
Expected: FAIL — `test_bowl_record_is_hidden_inside_locked_folder`에서 `is_not_empty()` 실패(빈 Dictionary)

- [ ] **Step 3: `docs.json`에 `doc:bowl_record`를 추가한다**

`docs.json`의 `"doc:vow"` 항목 **뒤에** 추가한다(새빛수련회 문서들이 모여 있는 자리):

```json
  "doc:bowl_record": {
    "title": "그릇기록_0803.txt",
    "body": "2002. 8. 3 (토) 수련회 셋째 날 밤\n\n그릇 문답을 했다. 조원 여섯이 둘러앉아서 한 사람씩 말한다.\n조장님이 종이를 나눠 주면서, 오늘 말한 것을 자기 손으로 적어 두라고 하셨다.\n말로 하면 흘러가는데 적으면 남는다고 하셨다.\n\n내 차례에서 어머니 얘기가 나왔다.\n할 생각이 없었는데 앞사람이 아버지 얘기를 하니까 나도 모르게 나왔다.\n어머니가 조용한 분이셨다는 것.\n기일이 음력 구월 열이틀이라는 것.\n그날 형네 집에 가면 형수님이 밥을 차리신다는 것.\n그런 얘기를 처음부터 끝까지 한 건 삼 년 만이다.\n\n나는 울었다.\n우는 게 창피했는데 아무도 안 쳐다봐서 괜찮았다.\n<< 이건 안 적어도 되는 건가. 근데 적으라고 하셨으니까 >>\n\n조장님이 잘했다고 하셨다.\n그릇이 크다고, 인도자님께서도 그렇게 말씀하셨다고 하셨다.\n나는 그 말이 좋았다.\n\n내일은 각자 한 사람씩 맡아서 본다고 한다.\n보는 게 아니라 기다려 주는 거라고 하셨다.\n기다리는 건 나도 할 수 있을 것 같다."
  },
```

> 마지막 세 줄이 제출본의 관찰 문단으로 이어지는 다리다. 사본은 여기서 끊긴다.

- [ ] **Step 4: `doc:evidence_memo` 본문 끝에 한 줄을 넣는다**

`docs.json`의 `doc:evidence_memo` `body` 마지막 두 줄

```
이걸 어디다 둬야해..
여기는 안돼. 여기는 그 사람들도 볼 수 있으니까..
```

**앞에** 한 문단을 끼운다. `body` 문자열이 다음으로 끝나도록 고친다:

```
...

[따로 둔 것]
· 8월에 쓴 건 따로 뒀다. 보이면 안 되니까 안 보이게 해놨다.

이걸 어디다 둬야해..
여기는 안돼. 여기는 그 사람들도 볼 수 있으니까..
```

JSON 이스케이프로는 기존 `\n\n이걸 어디다 둬야해..` 를 다음으로 치환한다:

```
\n\n[따로 둔 것]\n· 8월에 쓴 건 따로 뒀다. 보이면 안 되니까 안 보이게 해놨다.\n\n이걸 어디다 둬야해..
```

- [ ] **Step 5: `fs.json`에 `l_bowl` 노드를 추가한다**

`nodes` 배열에서 `l_letter`(슬기에게(부치지못함).txt) **뒤에** 추가한다. `locked` 폴더의 마지막 항목이 되게 둔다 — 숨김을 켰을 때 목록 맨 아래에 나타나는 편이 "원래 있었는데 안 보였다"로 읽힌다.

```json
    {"id": "l_bowl", "parent": "locked", "name": "그릇기록_0803.txt", "type": "doc",
     "cid": "doc:bowl_record", "hidden": true, "size": 1136, "mtime": "2002-08-03 23:41"},
```

> `record: true`를 넣지 않는다. 기록물 12 전환은 6단계다 (Global Constraints).

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_content_db.gd"
```
Expected: PASS, 0 failures. `ContentDB.validate()`도 통과해야 한다 — `doc:bowl_record`가 `docs`에 있으므로 "references missing doc" 오류가 나오면 안 된다

- [ ] **Step 7: 커밋**

```bash
git add games-src/last-login/content/docs.json games-src/last-login/content/fs.json games-src/last-login/tests/test_content_db.gd
git commit -m "feat(last-login): 그릇기록 — 성진이 자기에 대해 쓴 것, 안 보이게 해둔 것"
```

---

### Task 2: 숨김 필터와 상태표시줄의 어긋난 숫자

**Files:**
- Modify: `games-src/last-login/src/core/content_db.gd:129-134` (`fs_children`)
- Modify: `games-src/last-login/src/core/game_state.gd` (`clear_flag` 추가)
- Modify: `games-src/last-login/src/apps/explorer.gd:237` (`_refresh`의 상태표시줄)
- Test: `games-src/last-login/tests/test_content_db.gd`, `games-src/last-login/tests/test_explorer.gd`

**Interfaces:**
- Consumes: `l_bowl` 노드 (Task 1)
- Produces:
  - `ContentDB.fs_children_all(parent_id: String) -> Array[Dictionary]` — 숨김 포함 전체
  - `ContentDB.fs_children(parent_id: String) -> Array[Dictionary]` — `view_hidden` 플래그 없으면 숨김 제외 (시그니처 무변경)
  - `GameState.clear_flag(name: String) -> void`
  - 플래그 이름 `view_hidden`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_content_db.gd`에 추가:

```gdscript
func test_hidden_node_is_filtered_until_view_flag() -> void:
	GameState.reset()
	var ids: Array[String] = []
	for n in ContentDB.fs_children("locked"):
		ids.append(String(n["id"]))
	assert_array(ids).not_contains(["l_bowl"])
	assert_int(ContentDB.fs_children_all("locked").size()).is_equal(ids.size() + 1)
	GameState.set_flag("view_hidden")
	ids = []
	for n in ContentDB.fs_children("locked"):
		ids.append(String(n["id"]))
	assert_array(ids).contains(["l_bowl"])

func test_clear_flag_hides_it_again() -> void:
	GameState.reset()
	GameState.set_flag("view_hidden")
	GameState.clear_flag("view_hidden")
	assert_bool(GameState.has_flag("view_hidden")).is_false()
	var ids: Array[String] = []
	for n in ContentDB.fs_children("locked"):
		ids.append(String(n["id"]))
	assert_array(ids).not_contains(["l_bowl"])
```

`tests/test_explorer.gd`에 추가:

```gdscript
func test_status_bar_counts_hidden_files_the_list_does_not_show() -> void:
	## 상태표시줄이 목록보다 하나 더 안다 — 이것이 퍼즐5의 확인용 단서다
	var e := _make()
	assert_bool(e.submit_password("20020316")).is_false()
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()
	assert_str(e.status_text()).is_equal("개체 6개")
	assert_int(e.item_count()).is_equal(5)
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: FAIL — `fs_children_all`가 없어 파스 에러, `clear_flag`도 없음

- [ ] **Step 3: `content_db.gd`의 `fs_children`을 둘로 가른다**

`content_db.gd:129`의 기존 함수를 다음으로 교체한다:

```gdscript
func fs_children(parent_id: String) -> Array[Dictionary]:
	## 숨김 특성이 붙은 노드는 보기 설정을 켜야 목록에 나온다.
	## effective_parent가 이미 GameState를 물어보고 있으므로 같은 결을 따른다.
	var out: Array[Dictionary] = []
	for n in fs_children_all(parent_id):
		if n.get("hidden", false) and not GameState.has_flag("view_hidden"):
			continue
		out.append(n)
	return out

func fs_children_all(parent_id: String) -> Array[Dictionary]:
	## 숨김 포함. 탐색기 상태표시줄만 이걸 쓴다 — 목록보다 하나 더 아는 자리다.
	var out: Array[Dictionary] = []
	for n in _d["fs"]["nodes"]:
		if effective_parent(n) == parent_id:
			out.append(n)
	return out
```

- [ ] **Step 4: `game_state.gd`에 `clear_flag`를 넣는다**

`func has_flag(name: String) -> bool:` **바로 앞에** 추가:

```gdscript
func clear_flag(name: String) -> void:
	## 보기 설정처럼 껐다 켰다 하는 플래그가 있다. 막(act)은 다시 계산하지 않는다 —
	## 되돌릴 수 있는 설정이 이야기를 되감으면 안 된다.
	if not _flags.has(name):
		return
	_flags.erase(name)
	save_game()
```

- [ ] **Step 5: 탐색기 상태표시줄이 전체 개수를 쓰게 한다**

`explorer.gd:237`의

```gdscript
	_status_left.text = "개체 %d개" % entries.size()
```

를 다음으로 바꾼다:

```gdscript
	# 목록은 보이는 것만, 상태표시줄은 폴더에 있는 것 전부를 센다.
	# 두 숫자가 어긋나는 순간이 '성진이만' 폴더에 딱 한 번 있다.
	_status_left.text = "개체 %d개" % ContentDB.fs_children_all(_cwd).size()
```

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures (기존 테스트 전부 포함)

- [ ] **Step 7: 커밋**

```bash
git add games-src/last-login/src/core/content_db.gd games-src/last-login/src/core/game_state.gd games-src/last-login/src/apps/explorer.gd games-src/last-login/tests/
git commit -m "feat(last-login): 숨긴 파일 — 상태표시줄만 아는 여섯 번째 개체"
```

---

### Task 3: 보기 드롭다운 메뉴

**Files:**
- Modify: `games-src/last-login/src/apps/explorer.gd:62-77` (`_build_toolbar`), `:180-189` (`set_view_mode`)
- Test: `games-src/last-login/tests/test_explorer.gd`

**Interfaces:**
- Consumes: `GameState.clear_flag`, `view_hidden` 플래그 (Task 2)
- Produces:
  - `Explorer.MENU_ICONS := 0`, `MENU_DETAILS := 1`, `MENU_HIDDEN := 3` (구분선이 2번)
  - `Explorer.view_menu() -> PopupMenu`
  - `Explorer.select_view_menu(id: int) -> void` — 테스트와 UI가 같이 쓰는 진입점

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_explorer.gd`에 추가:

```gdscript
func test_view_menu_toggles_hidden_files() -> void:
	var e := _make()
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()
	assert_int(e.item_count()).is_equal(5)
	e.select_view_menu(e.MENU_HIDDEN)
	assert_bool(GameState.has_flag("view_hidden")).is_true()
	assert_int(e.item_count()).is_equal(6)
	e.select_view_menu(e.MENU_HIDDEN)
	assert_bool(GameState.has_flag("view_hidden")).is_false()
	assert_int(e.item_count()).is_equal(5)

func test_view_menu_still_switches_icon_and_detail_modes() -> void:
	var e := _make()
	e.select_view_menu(e.MENU_DETAILS)
	assert_int(e.view_mode()).is_equal(e.ViewMode.DETAILS)
	e.select_view_menu(e.MENU_ICONS)
	assert_int(e.view_mode()).is_equal(e.ViewMode.ICONS)

func test_view_menu_checkbox_reflects_flag_on_open() -> void:
	var e := _make()
	e.select_view_menu(e.MENU_HIDDEN)
	var m: PopupMenu = e.view_menu()
	e.sync_view_menu()
	assert_bool(m.is_item_checked(m.get_item_index(e.MENU_HIDDEN))).is_true()
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_explorer.gd"
```
Expected: FAIL — `select_view_menu`가 없어 파스 에러

- [ ] **Step 3: 도구모음을 드롭다운으로 바꾼다**

`explorer.gd` 상단 상수 블록(`const GRID_COLUMN_W := 148.0` 아래)에 추가:

```gdscript
## 보기 드롭다운 항목 id. 2번은 구분선이라 비어 있다.
const MENU_ICONS := 0
const MENU_DETAILS := 1
const MENU_HIDDEN := 3
```

변수 선언에서 `_icons_btn`·`_details_btn`을 지우고 다음으로 바꾼다:

```gdscript
var _view_btn: MenuButton
```

`_build_toolbar()`의 뒷부분(`row.add_child(VSeparator.new())` 이후)을 다음으로 교체한다:

```gdscript
	row.add_child(VSeparator.new())
	_view_btn = MenuButton.new()
	_view_btn.theme_type_variation = "NuriFlat"
	_view_btn.text = "보기"
	_view_btn.focus_mode = Control.FOCUS_NONE
	_view_btn.add_theme_font_size_override("font_size", 14)
	var vtex := _texture(ICON["view_details"])
	if vtex != null:
		_view_btn.icon = vtex
	var menu := _view_btn.get_popup()
	menu.add_theme_font_size_override("font_size", 14)
	menu.add_radio_check_item("큰 아이콘", MENU_ICONS)
	menu.add_radio_check_item("자세히", MENU_DETAILS)
	menu.add_separator()
	menu.add_check_item("숨긴 파일 보기", MENU_HIDDEN)
	menu.id_pressed.connect(select_view_menu)
	menu.about_to_popup.connect(sync_view_menu)
	row.add_child(_view_btn)
	bar.add_child(row)
	return bar
```

> 메뉴 막대(파일·편집·보기·도움말)는 만들지 않는다. 크롬 수준 "중간"(도구모음 + 주소줄 + 상태표시줄)을 메일·브라우저와 맞춘다.

- [ ] **Step 4: 진입점과 체크 동기화를 넣는다**

`# ── 보기 전환 ──` 구획의 `set_view_mode` **앞에** 추가:

```gdscript
func view_menu() -> PopupMenu:
	return _view_btn.get_popup()

func select_view_menu(id: int) -> void:
	match id:
		MENU_ICONS:
			set_view_mode(ViewMode.ICONS)
		MENU_DETAILS:
			set_view_mode(ViewMode.DETAILS)
		MENU_HIDDEN:
			if GameState.has_flag("view_hidden"):
				GameState.clear_flag("view_hidden")
			else:
				GameState.set_flag("view_hidden")
			_refresh()
	sync_view_menu()

func sync_view_menu() -> void:
	var m := view_menu()
	m.set_item_checked(m.get_item_index(MENU_ICONS), _view_mode == ViewMode.ICONS)
	m.set_item_checked(m.get_item_index(MENU_DETAILS), _view_mode == ViewMode.DETAILS)
	m.set_item_checked(m.get_item_index(MENU_HIDDEN), GameState.has_flag("view_hidden"))
```

`set_view_mode`에서 사라진 버튼을 참조하는 두 줄

```gdscript
	_icons_btn.button_pressed = icons
	_details_btn.button_pressed = not icons
```

를 다음 한 줄로 바꾼다:

```gdscript
	sync_view_menu()
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures. 기존 `test_desktop.gd`·`test_explorer.gd`가 `_icons_btn`을 참조하지 않는지 확인 — 참조가 남아 있으면 파스 에러가 난다

- [ ] **Step 6: 커밋**

```bash
git add games-src/last-login/src/apps/explorer.gd games-src/last-login/tests/test_explorer.gd
git commit -m "feat(last-login): 보기를 드롭다운으로 — 숨긴 파일 보기가 들어갈 자리"
```

---

### Task 4: 퍼즐5 판정과 슬기의 힌트 3단

**Files:**
- Modify: `games-src/last-login/content/puzzles.json`
- Modify: `games-src/last-login/content/chat.json`
- Modify: `games-src/last-login/src/core/content_db.gd:96-104` (퍼즐 검증)
- Modify: `games-src/last-login/src/apps/explorer.gd` (`open_file`, `_navigate`)
- Test: `games-src/last-login/tests/test_content_db.gd`, `games-src/last-login/tests/test_explorer.gd`

**Interfaces:**
- Consumes: `l_bowl`, `view_hidden`, `Explorer.select_view_menu`
- Produces:
  - 퍼즐 id `hidden_file` (`kind: "action"`)
  - 플래그 `bowl_record_found`
  - `ContentDB.validate()`가 `kind == "action"`인 퍼즐의 `answer` 부재를 허용
  - `Messenger.current_gate() -> String` — 테스트용 공개 접근자

> **힌트 배선은 새로 만들지 않는다.** `messenger.gd:300`의 `_current_gate()`가 이미
> puzzle1~4를 차례로 훑어 첫 미해결을 돌려주고, `flag_changed`마다 다시 계산된다
> (`messenger.gd:286`). 조작형 퍼즐은 그 목록 뒤에 붙이면 된다 — 탐색기가 게이트를
> 알릴 필요가 없다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_content_db.gd`에 추가:

```gdscript
func test_action_puzzle_needs_no_answer_but_needs_three_hints() -> void:
	var p := ContentDB.puzzle("hidden_file")
	assert_str(String(p.get("kind", ""))).is_equal("action")
	assert_bool(p.has("answer")).is_false()
	assert_int((p.get("hints", []) as Array).size()).is_equal(3)

func test_validate_rejects_action_puzzle_without_three_hints() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://content/fs.json"))
	assert_object(raw).is_not_null()
	var bad := {
		"fs": {"nodes": []}, "docs": {}, "chat": {"start": "a", "nodes": {"a": {}}},
		"mail": [], "web": {"pages": {}},
		"puzzles": {"x": {"kind": "action", "hints": ["one"]}},
		"records": {"records": []}, "strings": {"dev_allow_partial_records": true},
	}
	var errors := ContentDB.validate(bad)
	assert_array(errors).contains(["puzzle x needs exactly 3 hints"])
```

`tests/test_explorer.gd`에 추가:

```gdscript
func test_opening_the_hidden_file_sets_the_flag() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()
	e.select_view_menu(e.MENU_HIDDEN)
	assert_bool(GameState.has_flag("bowl_record_found")).is_false()
	e.open_file("l_bowl")
	assert_bool(GameState.has_flag("bowl_record_found")).is_true()

func test_turning_the_setting_on_is_not_enough() -> void:
	## 판정은 여는 것이다 — 이 게임의 다른 퍼즐도 전부 "읽었는가"로 끝난다
	var e := _make()
	e.select_view_menu(e.MENU_HIDDEN)
	assert_bool(GameState.has_flag("bowl_record_found")).is_false()

```

`tests/test_messenger.gd`에 추가:

```gdscript
func test_hidden_file_becomes_the_gate_after_the_four_locks() -> void:
	GameState.reset()
	var m: Control = auto_free(Messenger.new())
	add_child(m)
	assert_str(m.current_gate()).is_equal("puzzle1")
	for pid: String in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		GameState.set_flag(pid + "_solved")
	assert_str(m.current_gate()).is_equal("hidden_file")
	GameState.set_flag("bowl_record_found")
	assert_str(m.current_gate()).is_not_equal("hidden_file")
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: FAIL — `hint_gate`가 없어 파스 에러, `puzzle("hidden_file")`은 빈 Dictionary

- [ ] **Step 3: `puzzles.json`에 action 퍼즐을 추가한다**

`"puzzle4"` 항목 뒤에 추가:

```json
 ,
 "hidden_file": {
   "kind": "action",
   "hints": [
     "오빠는 겁이 많아서 뭐든 두 군데에 적어요. 한 군데는 벌써 찾으셨잖아요.",
     "그 폴더에 파일이 다섯 개 맞아요? 오빠가 안 보이게 해놓는 법 알았어요. 예전에 저한테 자랑했거든요.",
     "탐색기 보기 메뉴에 숨긴 파일 보기가 있어요. 그거 켜보세요."
   ]
 }
```

- [ ] **Step 4: `validate()`가 action 퍼즐을 통과시키게 한다**

`content_db.gd`의 퍼즐 검증 블록

```gdscript
	for pid in raw["puzzles"]:
		var p: Dictionary = raw["puzzles"][pid]
		if re.search(String(p.get("answer", ""))) == null:
			errors.append("puzzle %s answer not alnum" % pid)
		if p.get("hints", []).size() != 3:
			errors.append("puzzle %s needs exactly 3 hints" % pid)
```

를 다음으로 바꾼다:

```gdscript
	for pid in raw["puzzles"]:
		var p: Dictionary = raw["puzzles"][pid]
		# 조작형 퍼즐은 정답 문자열이 없다 — 앱 코드가 플래그를 직접 세운다.
		# 힌트 3단은 종류와 상관없이 슬기가 주므로 여기서만 검사한다.
		if String(p.get("kind", "password")) != "action":
			if re.search(String(p.get("answer", ""))) == null:
				errors.append("puzzle %s answer not alnum" % pid)
		if p.get("hints", []).size() != 3:
			errors.append("puzzle %s needs exactly 3 hints" % pid)
```

- [ ] **Step 5: 탐색기가 파일을 열 때 플래그를 세우게 한다**

`explorer.gd`의 `open_file`에서 `if n.has("cid"):` 블록 **뒤에** 추가:

```gdscript
	if node_id == "l_bowl":
		# 보기 설정을 켠 것만으로는 안 된다 — 이 게임의 판정은 언제나 "읽었는가"다
		GameState.set_flag("bowl_record_found")
```

- [ ] **Step 6: 메신저의 게이트 목록에 조작형 퍼즐을 붙인다**

`messenger.gd:300`의 `_current_gate()`를 다음으로 바꾼다:

```gdscript
func _current_gate() -> String:
	for pid in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		if not GameState.has_flag(pid + "_solved"):
			return pid
	# 조작형 퍼즐은 잠금이 아니라 상태로 열린다. 잠금 넷이 다 풀린 뒤에야
	# "폴더 안에 안 보이는 게 있다"는 질문이 성립한다.
	if not GameState.has_flag("bowl_record_found"):
		return "hidden_file"
	return ""

func current_gate() -> String:
	return _current_gate()
```

`_hints.set_gate()`는 이미 `flag_changed`마다 다시 불리므로(`messenger.gd:286`) 추가 배선이 없다. `hint_ready(puzzle_id, level)` → `ContentDB.puzzle(puzzle_id)["hints"][level-1]` 경로도 그대로다.

- [ ] **Step 7: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures

- [ ] **Step 8: 부트 스모크와 커밋**

```powershell
& "C:\Users\LeeDoik\tools\godot\godot_console.exe" --headless --path games-src/last-login --quit
```
Expected: 파스 에러 없이 종료(exit 0)

```bash
git add games-src/last-login/content/puzzles.json games-src/last-login/src games-src/last-login/tests
git commit -m "feat(last-login): 퍼즐5 판정과 힌트 — 조작형 퍼즐에 정답 문자열이 없다"
```

---

### Task 5: 사진 뷰어를 클래스로 뽑고 확대를 붙인다

**Files:**
- Create: `games-src/last-login/src/apps/photo_view.gd`
- Create: `games-src/last-login/tests/test_photo_view.gd`
- Modify: `games-src/last-login/src/apps/explorer.gd:363-396` (`open_file`, `_photo_view` 삭제)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `class_name PhotoView extends Control`
  - `PhotoView.image_path: String` — `_ready` 전에 세팅
  - `PhotoView.zoom() -> float` (1.0 또는 2.0), `PhotoView.toggle_zoom() -> void`
  - `static PhotoView.uv_at(local_pos: Vector2, tex_size: Vector2, zoom: float) -> Vector2` — 바깥이면 `Vector2(-1, -1)`
  - `signal region_clicked(uv: Vector2)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`games-src/last-login/tests/test_photo_view.gd` 생성:

```gdscript
extends GdUnitTestSuite

const PhotoViewScript := preload("res://src/apps/photo_view.gd")

func test_uv_at_maps_click_to_normalized_coords() -> void:
	var uv: Vector2 = PhotoViewScript.uv_at(Vector2(100, 200), Vector2(200, 400), 1.0)
	assert_float(uv.x).is_equal_approx(0.5, 0.001)
	assert_float(uv.y).is_equal_approx(0.5, 0.001)

func test_uv_at_accounts_for_zoom() -> void:
	var uv: Vector2 = PhotoViewScript.uv_at(Vector2(200, 400), Vector2(200, 400), 2.0)
	assert_float(uv.x).is_equal_approx(0.5, 0.001)
	assert_float(uv.y).is_equal_approx(0.5, 0.001)

func test_uv_at_returns_sentinel_outside_the_image() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2(-1, 10), Vector2(200, 400), 1.0)).is_equal(Vector2(-1, -1))
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 500), Vector2(200, 400), 1.0)).is_equal(Vector2(-1, -1))

func test_uv_at_guards_against_zero_texture() -> void:
	assert_vector(PhotoViewScript.uv_at(Vector2(10, 10), Vector2.ZERO, 1.0)).is_equal(Vector2(-1, -1))

func test_toggle_zoom_cycles_between_fit_and_double() -> void:
	var v: Control = auto_free(PhotoViewScript.new())
	v.image_path = "res://assets/img/photos/bomi_2002.png"
	add_child(v)
	assert_float(v.zoom()).is_equal_approx(1.0, 0.001)
	v.toggle_zoom()
	assert_float(v.zoom()).is_equal_approx(2.0, 0.001)
	v.toggle_zoom()
	assert_float(v.zoom()).is_equal_approx(1.0, 0.001)
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_photo_view.gd"
```
Expected: FAIL — `res://src/apps/photo_view.gd` 없음

- [ ] **Step 3: `photo_view.gd`를 만든다**

```gdscript
class_name PhotoView
extends Control
## 사진 창의 내용물. 창에 맞추기(1x)와 실제 크기 2배(2x) 두 단계.
## 2x에서는 스크롤로 훑고, 클릭 위치를 사진 좌표(0~1)로 돌려준다 —
## 종이에 적힌 것을 손가락으로 짚는 동작이 이 게임에서 처음 생기는 자리다.

signal region_clicked(uv: Vector2)

const ZOOM_FIT := 1.0
const ZOOM_NEAR := 2.0

var image_path := ""

var _zoom := ZOOM_FIT
var _tex: Texture2D
var _scroll: ScrollContainer
var _rect: TextureRect
var _zoom_btn: Button

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if image_path != "":
		_tex = load(image_path)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_build_toolbar())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.theme_type_variation = "NuriField"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rect = TextureRect.new()
	_rect.texture = _tex
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.gui_input.connect(_on_image_input)
	frame.add_child(_rect)
	_scroll.add_child(frame)
	col.add_child(_scroll)
	_apply_zoom()

func _build_toolbar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "NuriToolbar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_zoom_btn = Button.new()
	_zoom_btn.theme_type_variation = "NuriFlat"
	_zoom_btn.focus_mode = Control.FOCUS_NONE
	_zoom_btn.add_theme_font_size_override("font_size", 14)
	_zoom_btn.pressed.connect(toggle_zoom)
	row.add_child(_zoom_btn)
	bar.add_child(row)
	return bar

func zoom() -> float:
	return _zoom

func toggle_zoom() -> void:
	_zoom = ZOOM_NEAR if is_equal_approx(_zoom, ZOOM_FIT) else ZOOM_FIT
	_apply_zoom()

func _apply_zoom() -> void:
	if not is_instance_valid(_rect):
		return
	var near := not is_equal_approx(_zoom, ZOOM_FIT)
	_zoom_btn.text = "창에 맞추기" if near else "확대"
	if near and _tex != null:
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.custom_minimum_size = Vector2(_tex.get_size()) * ZOOM_NEAR
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.custom_minimum_size = Vector2.ZERO
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _on_image_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton):
		return
	var mb := e as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_equal_approx(_zoom, ZOOM_FIT) or _tex == null:
		return
	var uv := uv_at(mb.position, Vector2(_tex.get_size()), ZOOM_NEAR)
	if uv.x >= 0.0:
		region_clicked.emit(uv)

static func uv_at(local_pos: Vector2, tex_size: Vector2, zoom: float) -> Vector2:
	## 2x에서는 TextureRect가 tex_size * zoom 크기로 고정되므로 나눗셈 한 번이면 된다.
	## 창에 맞추기 상태의 여백 계산이 필요 없도록 클릭 판정을 2x에서만 받는다.
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or zoom <= 0.0:
		return Vector2(-1, -1)
	var uv := local_pos / (tex_size * zoom)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv
```

- [ ] **Step 4: 탐색기가 이 클래스를 쓰게 한다**

`explorer.gd`의 `_photo_view()` 함수를 통째로 지우고, `open_file`의 이미지 분기를 다음으로 바꾼다:

```gdscript
	if n["type"] == "image":
		# 사진은 실제 OS처럼 별도 뷰어 창으로 연다
		if wm != null:
			var view := PhotoView.new()
			view.image_path = String(n["image"])
			wm.open_window("photo:" + node_id, String(n["name"]), view,
				Vector2(560, 470), ICON["photo"])
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures. 기존 `test_opening_photo_spawns_viewer_window_and_marks_read`도 그대로 통과해야 한다

- [ ] **Step 6: 커밋**

```bash
git add games-src/last-login/src/apps/photo_view.gd games-src/last-login/src/apps/explorer.gd games-src/last-login/tests/test_photo_view.gd
git commit -m "refactor(last-login): 사진 뷰어를 클래스로 — 확대와 짚기가 들어갈 자리"
```

---

### Task 6: 그릇기록 제출본 사진을 만든다

**Files:**
- Modify: `scripts/gen_pilsa_photos.py`
- Create: `games-src/last-login/assets/img/photos/bowl_record.png`
- Modify: `games-src/last-login/content/fs.json`
- Test: `games-src/last-login/tests/test_content_db.gd`

**Interfaces:**
- Consumes: 없음
- Produces:
  - fs 노드 id `s_photo4`, cid `img:bowl_record_photo`
  - 생성 스크립트가 stdout에 출력하는 관찰 문단 정규화 bbox — Task 7의 `HIT_REGION` 상수가 된다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_content_db.gd`에 추가:

```gdscript
func test_bowl_record_photo_sits_with_the_other_submissions() -> void:
	var n := ContentDB.fs_node("s_photo4")
	assert_dict(n).is_not_empty()
	assert_str(String(n.get("parent", ""))).is_equal("saebit")
	assert_str(String(n.get("cid", ""))).is_equal("img:bowl_record_photo")
	assert_bool(n.get("hidden", false)).is_false()
	assert_bool(FileAccess.file_exists(String(n.get("image", "")))).is_true()
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_content_db.gd"
```
Expected: FAIL — `s_photo4` 노드 없음

- [ ] **Step 3: 생성 스크립트에 제출본 전용 페이지를 추가한다**

`scripts/gen_pilsa_photos.py`의 `PAGES` 정의 **뒤에** 추가한다. 본문을 `docs.json`에서 읽지 않는 것이 요점이다 — **제출본에만 있는 문단은 게임 문서에 존재하지 않는다.**

```python
# 제출본 전용 페이지: 본문을 docs.json에서 읽지 않는다.
# 마지막 문단이 사본에 없다는 것이 퍼즐이라서, 여기가 그 문단의 유일한 출처다.
BOWL_TEXT = [
    "그릇 문답 기록",
    "",
    "그릇 문답을 했다. 조원 여섯이 둘러앉아서 한 사람씩 말한다.",
    "조장님이 종이를 나눠 주면서, 오늘 말한 것을",
    "자기 손으로 적어 두라고 하셨다.",
    "",
    "내 차례에서 어머니 얘기가 나왔다.",
    "어머니가 조용한 분이셨다는 것.",
    "기일이 음력 구월 열이틀이라는 것.",
    "그런 얘기를 처음부터 끝까지 한 건 삼 년 만이다.",
    "",
    "나는 울었다. 우는 게 창피했는데 아무도 안 쳐다봐서 괜찮았다.",
    "조장님이 잘했다고 하셨다. 그릇이 크다고 하셨다.",
    "나는 그 말이 좋았다.",
    "",
    "내일은 각자 한 사람씩 맡아서 본다고 한다.",
    "보는 게 아니라 기다려 주는 거라고 하셨다.",
    "",
    "○○ 님은 아직 어머니 얘기를 못 꺼내십니다.",
    "조금 더 기다리면 될 것 같습니다.",
]
# 위 목록에서 이 인덱스부터가 사본에 없는 관찰 문단이다 (마지막 두 줄). bbox 출력에 쓴다.
BOWL_OBSERVATION_FROM = 18

RAW_PAGES = [
    ("bowl_record", BOWL_TEXT, "새빛력 4년 8월 3일  성진", 20020803, BOWL_OBSERVATION_FROM),
]
```

히트 영역은 `make_page`의 내부를 뜯지 않고 **두 번 그려서 차이를 본다.** 글자 지터는
`random`을 순서대로 소비하므로, 같은 시드로 앞부분이 같은 두 장을 그리면 뒤에 붙은
관찰 문단만 달라진다. 그 차이의 경계상자가 곧 히트 영역이다.

`main()`의 서원문 블록 **앞에** 추가한다 (`make_page`·`degrade`는 기존 함수를 그대로 쓴다):

```python
    # 그릇기록 제출본 — 마지막 두 줄은 사본에 없다.
    # 히트 영역은 "관찰 문단이 있는 그림"과 "없는 그림"의 차이로 구한다.
    # 지터가 random을 순서대로 먹으므로 앞부분은 두 장이 픽셀 단위로 같다.
    for stem, lines, sign, seed, obs_from in RAW_PAGES:
        random.seed(seed)
        full = make_page(lines[0], lines[2:], sign)
        random.seed(seed)
        short = make_page(lines[0], lines[2:obs_from], sign)
        from PIL import ImageChops
        box = ImageChops.difference(full.convert("RGB"), short.convert("RGB")).getbbox()
        if box is None:
            raise SystemExit("관찰 문단이 그림에 안 나타났다 — BOWL_OBSERVATION_FROM 확인")
        w, h = full.size
        pad = 0.015
        rx = max(0.0, box[0] / w - pad)
        ry = max(0.0, box[1] / h - pad)
        rw = min(1.0, box[2] / w + pad) - rx
        rh = min(1.0, box[3] / h + pad) - ry
        print("HIT_REGION %s = Rect2(%.3f, %.3f, %.3f, %.3f)" % (stem, rx, ry, rw, rh))
        if clean_dir:
            full.save(os.path.join(clean_dir, stem + "_clean.png"))
        out = os.path.join(OUT, stem + ".png")
        random.seed(seed)
        degrade(make_page(lines[0], lines[2:], sign)).save(out)
        print(stem, "->", out, os.path.getsize(out), "bytes")
```

> `lines[0]`이 제목, `lines[1]`은 빈 줄이라 본문은 `lines[2:]`부터다. `degrade`가
> `random`을 더 먹으므로 저장용 그림은 시드를 다시 심고 새로 그린다 — 그래야 diff에
> 쓴 그림과 파일에 남는 그림의 글자 위치가 같다.

- [ ] **Step 4: 사진을 생성하고 bbox를 받아 적는다**

```powershell
python scripts/gen_pilsa_photos.py
```
Expected: stdout에 `HIT_REGION bowl_record = Rect2(0.xxx, 0.xxx, 0.xxx, 0.xxx)` 한 줄과 `wrote ...bowl_record.png (W, H)`. **이 Rect2 네 숫자를 그대로 적어 둔다 — Task 7의 `HIT_REGION` 상수가 된다.**

생성된 `games-src/last-login/assets/img/photos/bowl_record.png`를 눈으로 확인한다:
- 마지막 두 줄(`○○ 님은…`)이 종이 아래쪽에 다른 문단과 한 줄 띄고 붙어 있을 것
- 필사 1~3과 같은 종이·같은 필체·같은 조명일 것
- **지장이 없을 것** — 지장은 서원문에만 찍는다

- [ ] **Step 5: `fs.json`에 노드를 추가한다**

`s_photo3`(필사_3_제출본.jpg) 뒤에 추가한다:

```json
    {"id": "s_photo4", "parent": "saebit", "name": "그릇기록_제출본.jpg", "type": "image",
     "cid": "img:bowl_record_photo", "image": "res://assets/img/photos/bowl_record.png",
     "size": 271104, "mtime": "2002-08-03 23:52"},
```

`size`는 실제 생성물 크기와 무관한 서사용 가짜 메타데이터다 — 다른 제출본 사진들과 같은 자릿수로 맞춘다.

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures

- [ ] **Step 7: 커밋**

```bash
git add scripts/gen_pilsa_photos.py games-src/last-login/assets/img/photos/bowl_record.png games-src/last-login/content/fs.json games-src/last-login/tests/test_content_db.gd
git commit -m "feat(last-login): 그릇기록 제출본 사진 — 사본에 없는 문단이 여기 적혀 있다"
```

---

### Task 7: 퍼즐6 — 짚으면 확정, 혼자면 방향만

**Files:**
- Modify: `games-src/last-login/src/apps/explorer.gd`
- Modify: `games-src/last-login/content/puzzles.json`
- Test: `games-src/last-login/tests/test_explorer.gd`

**Interfaces:**
- Consumes: `PhotoView.region_clicked`, `WindowManager.is_open`, `OSDialog.show_message`, 노드 `s_photo4`·`l_bowl`
- Produces:
  - `Explorer.HIT_REGION_BOWL: Rect2` (Task 6 출력값)
  - 플래그 `bowl_diff_found`
  - 퍼즐 id `bowl_diff`
  - `Explorer.on_photo_region_clicked(node_id: String, uv: Vector2) -> bool` — 확정됐으면 true

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_explorer.gd`에 추가. `HIT_CENTER`는 Task 6이 출력한 Rect2의 중심이다 — 그 값으로 고친다:

```gdscript
const HIT_CENTER := Vector2(0.5, 0.86)   # Task 6의 HIT_REGION 중심

func _open_locked_and_reveal(e: Control) -> void:
	assert_bool(e.open_folder("locked")).is_false()
	assert_bool(e.submit_password("20020316")).is_true()
	assert_bool(e.open_folder("locked")).is_true()
	e.select_view_menu(e.MENU_HIDDEN)

func test_pointing_at_the_paragraph_alone_only_gives_direction() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	_open_locked_and_reveal(e)
	e.open_file("s_photo4")
	assert_bool(e.on_photo_region_clicked("s_photo4", HIT_CENTER)).is_false()
	assert_bool(GameState.has_flag("bowl_diff_found")).is_false()
	assert_str(e.last_message()).contains("사본에는 이런 게 있었나")

func test_pointing_with_the_copy_open_confirms() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	_open_locked_and_reveal(e)
	e.open_file("l_bowl")
	e.open_file("s_photo4")
	assert_bool(e.on_photo_region_clicked("s_photo4", HIT_CENTER)).is_true()
	assert_bool(GameState.has_flag("bowl_diff_found")).is_true()
	assert_str(e.last_message()).contains("성진은 제출하고 나서")

func test_pointing_elsewhere_on_the_page_does_nothing() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	_open_locked_and_reveal(e)
	e.open_file("l_bowl")
	e.open_file("s_photo4")
	assert_bool(e.on_photo_region_clicked("s_photo4", Vector2(0.5, 0.2))).is_false()
	assert_bool(GameState.has_flag("bowl_diff_found")).is_false()

func test_other_photos_have_no_hit_region() -> void:
	var pair := _make_with_wm()
	var e: Control = pair[0]
	e.open_file("p_bomi")
	assert_bool(e.on_photo_region_clicked("p_bomi", HIT_CENTER)).is_false()

```

`tests/test_messenger.gd`에 추가:

```gdscript
func test_bowl_diff_becomes_the_gate_once_the_copy_is_found() -> void:
	GameState.reset()
	var m: Control = auto_free(Messenger.new())
	add_child(m)
	for pid: String in ["puzzle1", "puzzle2", "puzzle3", "puzzle4"]:
		GameState.set_flag(pid + "_solved")
	GameState.set_flag("bowl_record_found")
	assert_str(m.current_gate()).is_equal("bowl_diff")
	GameState.set_flag("bowl_diff_found")
	assert_str(m.current_gate()).is_empty()
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_explorer.gd"
```
Expected: FAIL — `on_photo_region_clicked`가 없어 파스 에러

- [ ] **Step 3: `puzzles.json`에 `bowl_diff`를 추가한다**

`hidden_file` 항목 뒤에 추가:

```json
 ,
 "bowl_diff": {
   "kind": "action",
   "hints": [
     "오빠는 뭐든 두 번 써요. 손으로 한 번, 컴퓨터로 한 번. 그럼 둘이 같아야 하는 거 아니에요?",
     "사진이랑 파일이랑 같이 띄워놓고 보세요. 마지막 쪽에 뭐가 더 있는 것 같은데.",
     "제출본 마지막 문단이요. 그거 사본에는 없어요. 오빠가 지운 거예요."
   ]
 }
```

- [ ] **Step 4: 탐색기에 히트 영역과 판정을 넣는다**

`explorer.gd` 상수 블록에 추가한다. **Rect2 값은 Task 6이 출력한 것으로 바꾼다:**

```gdscript
## 그릇기록 제출본에서 사본에 없는 관찰 문단이 앉은 자리 (사진 정규화 좌표).
## scripts/gen_pilsa_photos.py가 렌더할 때 계산해 출력한 값이다 — 사진을
## 다시 만들면 그 출력으로 갱신할 것.
const HIT_REGION_BOWL := Rect2(0.08, 0.78, 0.84, 0.16)
```

`open_file`의 이미지 분기를 다음으로 바꾼다(Task 5에서 넣은 세 줄을 확장):

```gdscript
	if n["type"] == "image":
		# 사진은 실제 OS처럼 별도 뷰어 창으로 연다
		if wm != null:
			var view := PhotoView.new()
			view.image_path = String(n["image"])
			# 시그널은 uv 하나를, 핸들러는 (node_id, uv)를 받는다.
			# bind/unbind 조합보다 람다가 읽기 쉽고 인자 순서를 틀릴 여지가 없다.
			view.region_clicked.connect(func(uv: Vector2) -> void:
				on_photo_region_clicked(node_id, uv))
			wm.open_window("photo:" + node_id, String(n["name"]), view,
				Vector2(560, 470), ICON["photo"])
```

`# ── 암호 대화상자 ──` 구획 **앞에** 판정을 추가한다:

```gdscript
func on_photo_region_clicked(node_id: String, uv: Vector2) -> bool:
	## 종이에 적힌 것을 손가락으로 짚는 동작. 짚을 것이 있는 사진은 하나뿐이다.
	if node_id != "s_photo4" or not HIT_REGION_BOWL.has_point(uv):
		return false
	if GameState.has_flag("bowl_diff_found"):
		return true
	var wm := get_tree().get_first_node_in_group("window_manager") as WindowManager
	var copy_open := wm != null and wm.is_open("doc:l_bowl")
	if not copy_open:
		# 실패해도 다음 행동을 알려준다 — 두 창을 나란히 두는 것을 강제하지 않고 보상한다
		_show_message("그릇기록_제출본.jpg", "이 문단이 낯설다.\n사본에는 이런 게 있었나.")
		return false
	GameState.set_flag("bowl_diff_found")
	_show_message("그릇기록_제출본.jpg",
		"이 문단은 사본에 없다.\n성진은 제출하고 나서 자기 것에서만 지웠다.")
	return true
```

- [ ] **Step 5: 메신저 게이트 목록에 `bowl_diff`를 붙인다**

Task 4에서 고친 `messenger.gd`의 `_current_gate()` 끝부분을 다음으로 바꾼다:

```gdscript
	if not GameState.has_flag("bowl_record_found"):
		return "hidden_file"
	if not GameState.has_flag("bowl_diff_found"):
		return "bowl_diff"
	return ""
```

`on_photo_region_clicked`가 `GameState.set_flag("bowl_diff_found")`을 부르면
`flag_changed`가 메신저의 `set_gate`를 다시 태우므로(`messenger.gd:286`) 추가 배선이 없다.

- [ ] **Step 6: 테스트가 통과하는지 확인한다. HIT_CENTER가 안 맞으면 여기서 잡힌다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures. `test_pointing_elsewhere_on_the_page_does_nothing`이 실패하면 `HIT_REGION_BOWL`이 페이지의 너무 넓은 영역을 덮은 것이다 — Task 6의 출력값을 다시 확인한다

- [ ] **Step 7: 커밋**

```bash
git add games-src/last-login/src/apps/explorer.gd games-src/last-login/content/puzzles.json games-src/last-login/tests/test_explorer.gd
git commit -m "feat(last-login): 퍼즐6 — 사본과 제출본을 맞대면 지운 문단이 나온다"
```

---

### Task 8: 슬기의 반응과 웹 재익스포트

**Files:**
- Modify: `games-src/last-login/content/chat.json`
- Test: `games-src/last-login/tests/test_messenger.gd`
- Modify: `public/games/last-login/` (익스포트 산출물)

**Interfaces:**
- Consumes: 플래그 `bowl_diff_found`
- Produces: chat 노드 `bq1`~`bq3`, 종반 허브 게이트 선택지

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_messenger.gd`에 추가:

```gdscript
func test_bowl_branch_is_hidden_without_the_flag() -> void:
	GameState.reset()
	var thread := ContentDB.chat_thread()
	var hub: Dictionary = thread["nodes"]["g4m"]
	var texts: Array[String] = []
	for c in hub.get("choices", []):
		if String(c.get("require", "")) == "":
			texts.append(String(c["text"]))
	assert_array(texts).not_contains(["오빠가 남에 대해 쓴 게 있어요"])

func test_bowl_branch_chain_reaches_the_hub_again() -> void:
	var nodes: Dictionary = ContentDB.chat_thread()["nodes"]
	assert_dict(nodes).contains_keys(["bq1", "bq2", "bq3"])
	assert_str(String(nodes["bq1"].get("next", ""))).is_equal("bq2")
	assert_str(String(nodes["bq2"].get("next", ""))).is_equal("bq3")
	var last_targets: Array[String] = []
	for c in nodes["bq3"].get("choices", []):
		last_targets.append(String(c["next"]))
	assert_array(last_targets).contains(["g4m"])
```

- [ ] **Step 2: 실패를 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests/test_messenger.gd"
```
Expected: FAIL — `bq1` 노드 없음

- [ ] **Step 3: 분기 노드 셋을 추가한다**

`chat.json`의 `nodes`에 추가한다. 슬기는 오빠를 변호하지 않는다 — 그게 이 장면의 전부다.

```json
    "bq1": {"from": "seulgi", "text": "그거… 오빠 글씨 맞아요.", "next": "bq2"},
    "bq2": {"from": "seulgi", "text": "○○ 님은 아직 어머니 얘기를 못 꺼내십니다.\n조금 더 기다리면 될 것 같습니다.\n\n오빠가 이걸 왜 써요.", "next": "bq3"},
    "bq3": {"from": "seulgi", "text": "…컴퓨터에 있는 건 그 부분만 없더라고요.\n그러니까 오빠도 알았던 거예요.\n\n그래도 냈잖아요.", "choices": [
      {"text": "그때는 돕는 일이라고 믿었을 거예요", "next": "g4m"},
      {"text": "…", "next": "g4m"}
    ]}
```

- [ ] **Step 4: 종반 허브에 게이트 선택지를 단다**

`g4l`·`g4m`·`iq4` 세 노드의 `choices` 배열 각각에 다음 항목을 추가한다(침입자 게이트 선택지와 같은 문법 — `require`가 없으면 표시되지 않는다):

```json
      {"text": "오빠가 남에 대해 쓴 게 있어요", "next": "bq1", "require": "bowl_diff_found"}
```

`iq4`에는 `잠깐만요` 선택지가 없으므로 이 항목만 더한다.

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```powershell
cd "games-src\last-login"
$env:GODOT_BIN = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: PASS, 0 failures. `ContentDB.validate()`의 "chat node X -> missing Y" 검사가 `bq1`~`bq3` 연결을 잡아준다

- [ ] **Step 6: 부트 스모크 → 웹 재익스포트 → 확인**

```powershell
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
& $GODOT --headless --path games-src/last-login --quit
```
Expected: 파스 에러 없이 exit 0. **여기서 통과해야만 익스포트한다 — 익스포트는 파스 에러여도 성공한다**

```powershell
cd "games-src\last-login"
& $GODOT --headless --export-release "Web" --path .
```
Expected: `public/games/last-login/index.wasm`·`index.pck`·`index.html` 갱신

브라우저에서 확인한다(포트 3000의 stale 서버 주의 — 새로 띄운다):

```powershell
npx --yes serve -l 3100 public
```

`http://localhost:3100/games/last-login/` 에서:
1. 퍼즐1을 풀어 '성진이만' 폴더를 연다 → 상태표시줄이 `개체 6개`인데 목록은 5개
2. 보기 ▾ → 숨긴 파일 보기 → `그릇기록_0803.txt`가 나타난다. 열면 한글이 두부 없이 보인다
3. 새빛수련회 폴더에서 `그릇기록_제출본.jpg`를 연다 → 확대 → 마지막 문단을 클릭
4. 사본 창을 열어두고 다시 클릭 → 확정 대화상자
5. 메신저 종반 허브에 새 선택지가 뜬다

- [ ] **Step 7: 커밋**

```bash
git add games-src/last-login/content/chat.json games-src/last-login/tests/test_messenger.gd public/games/last-login
git commit -m "feat(last-login): 오빠가 남에 대해 쓴 것 — 슬기는 변호하지 않는다"
```

---

## 이 플랜이 끝나면

- 조작형 퍼즐 문법 둘(숨긴 것 드러내기 · 두 창 맞대기)이 게임에 들어간다
- 관계도에서 비어 있던 자리 — 성진이 내보내는 유일한 화살표 — 가 물증이 된다
- 기록물은 여전히 9개다. `doc:bowl_record`와 `img:bowl_record_photo`는 읽히지만 세어지지 않는다

## 남은 단계 (각각 별도 플랜)

| 단계 | 내용 | 신규 기반 |
|---|---|---|
| 3 | 액세스한 날짜 열 (퍼즐7) | 열 추가·정렬 · `atime` 전수 생성 스크립트 |
| 4 | 관문 캐시 2판 (퍼즐8) | 판본 링크 · 두 번째 브라우저 창 |
| 5 | 끌어놓기 진술서 | 창 사이 드래그앤드롭 · 바탕화면 동적 아이콘 |
| 6 | 기록물 12 전환 + 전체 회귀 + 재익스포트 | — |
