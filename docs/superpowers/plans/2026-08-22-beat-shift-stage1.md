# BEAT SHIFT — 1단계 구현 플랜 (리듬 엔진 + 대장간)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 장면-큐 원버튼 리듬게임 BEAT SHIFT의 1단계 — 리듬 엔진 + 대장간 단일 장면 엔드리스(템포 상승 포함)를 Godot 4.7로 만들어 웹 익스포트하고 PIXELARIOUS 카트리지로 등록한다(hidden, 모바일 터치 필수).

**Architecture:** 박자의 진실은 오디오 재생 위치(컨덕터 패턴) — 시각 프레임이 아니다. 판정·패턴·게이지·스코어는 순수 로직(`ConductorMath`, `NoteJudge`, `Patterns`, `Groove`, `Scoring`)으로 분리해 gdUnit4 헤드리스 테스트한다. 씬 파일은 `main.tscn` 하나, 노드 트리는 전부 코드 구성(STARFALL DRIFT 관례). 백킹 루프는 정확히 1마디 길이 WAV — 루프 랩 카운트가 곧 마디 인덱스가 되어 일시정지 후 "현재 마디부터 재개"가 시킹 없이 성립한다. **스펙 §3 대비 1가지 조정**: 섹션 맨 앞에 쉼표 1마디(인트로)를 추가한다 — 첫 노트(0박)의 2박 예비 큐가 음악 시작 이전 시점이 되는 문제의 해결책. 섹션 = 인트로 1마디 + 패턴 8마디 + 징글 1마디 = 40박.

**Tech Stack:** Godot 4.7.1 Standard(GDScript), gdUnit4, Python 3 stdlib(오디오 합성)+PIL(검수 시트), PixelLab API(스프라이트), 기존 Next.js 사이트(커버 씬·레코드 등록).

**스펙:** `docs/superpowers/specs/2026-08-22-beat-shift-design.md` — 수치·규칙의 원본. 충돌 시 스펙이 우선(위 인트로 마디 조정만 예외).

## Global Constraints

- Godot 실행 파일(전 태스크 공통): `$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"` (4.7.1.stable, 웹 익스포트 템플릿 설치됨)
- 게임 프로젝트 루트: `games-src/beat-shift/`
- gdUnit4 테스트 실행(프로젝트 디렉토리에서): 첫 실행 또는 `.godot/` 삭제 후엔 반드시 캐시 프라이밍 후 실행 —
  ```powershell
  & $GODOT --headless --editor --path . --quit
  & $GODOT --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
  ```
  Expected: 0 errors / 0 failures, exit 0. (`--ignoreHeadlessMode` 없으면 exit 103) — 이하 "**runtest**"로 지칭
- 부트 스모크: `& $GODOT --headless --path games-src\beat-shift --quit-after 240` — 익스포트는 파스 에러여도 성공하므로 익스포트 전에 반드시 돌린다
- 뷰포트 270×480 (9:16 세로), `canvas_items` 스트레치 + `expand`, `gl_compatibility`, 텍스처 필터 nearest
- 인게임 팔레트(대장간): 배경 `#0C0A1C`, 벽 `#1D2B53`, 바닥 `#141127`, 불꽃 주황 `#FFA300`, 하이라이트 `#FFEC27`, 위험 `#FF004D`, 강철 `#FFF1E8`, 보조 `#29ADFF` — 전부 PICO-8 계열
- 튜닝 수치는 전부 `src/core/tuning.gd` 상수로만 존재 (매직 넘버 금지). 스펙 §3~§5 시작값 사용
- 조작은 액션 `"tap"` 하나 (Space, 마우스 좌클릭, 터치는 `emulate_mouse_from_touch`로 흡수)
- 판정창은 **초 단위 상수**(BPM 무관): PERFECT ±0.070s, GOOD ±0.140s. 전역 입력 보정 `Tuning.INPUT_OFFSET`(초, 기본 0.0)은 탭 시각에만 더한다 — 웹 오디오 레이턴시 튜닝 손잡이
- 웹 익스포트: Web 프리셋, 스레드 비활성화(nothreads), 파일당 100MB 미만
- 익스포트 후 `.import` 파일들이 줄바꿈만 바뀐 채 modified로 뜨면 `git checkout -- games-src/beat-shift/assets games-src/beat-shift/addons`로 되돌린다 (내용 동일)
- 웹 빌드 브라우저 검증 전 **포트 3000 stale 서버 대조 필수**: `curl -s -o /dev/null -w "%{size_download}" http://localhost:3000/games/beat-shift/index.pck` 값이 실제 `public/games/beat-shift/index.pck` 크기와 다르면 다른 워크트리의 서버다 — `npm run dev -- -p 3100`으로 새로 띄운다
- PixelLab API 키: 리포 루트 `.env.local`의 `PIXELLAB_API_KEY` (절대 커밋 금지 — .gitignore 등록됨)
- GDScript 들여쓰기는 탭. 커밋 메시지는 `feat(beatshift): ...` 형식

---

### Task 1: 스캐폴드 + 테스트 하네스

**Files:**
- Create: `games-src/beat-shift/project.godot`, `icon.svg`, `src/main.tscn`, `src/main.gd`(스텁), `src/core/game_state.gd`(스텁), `src/core/sfx.gd`(스텁), `src/core/conductor.gd`(스텁), `tests/test_harness.gd`, `CREDITS.md`, `assets/fonts/Galmuri9.ttf`, `assets/fonts/Galmuri11.ttf`, `addons/gdUnit4/`

**Interfaces:**
- Produces: 부팅되는 빈 Godot 프로젝트 + 동작하는 gdUnit4 테스트 커맨드. 오토로드 `GameState`·`Sfx`·`Conductor` 등록(본 구현은 Task 5·6)

- [ ] **Step 1: 디렉토리·설정 파일**

```powershell
New-Item -ItemType Directory -Force games-src\beat-shift\src\core, games-src\beat-shift\tests, games-src\beat-shift\assets\fonts, games-src\beat-shift\assets\img, games-src\beat-shift\assets\sfx
Copy-Item games-src\starfall-drift\assets\fonts\Galmuri9.ttf, games-src\starfall-drift\assets\fonts\Galmuri11.ttf games-src\beat-shift\assets\fonts\
```

`games-src/beat-shift/project.godot`:
```ini
; Engine configuration file.
config_version=5

[application]
config/name="BEAT SHIFT"
run/main_scene="res://src/main.tscn"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"

[autoload]
GameState="*res://src/core/game_state.gd"
Sfx="*res://src/core/sfx.gd"
Conductor="*res://src/core/conductor.gd"

[display]
window/size/viewport_width=270
window/size/viewport_height=480
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1

[input_devices]
pointing/emulate_touch_from_mouse=false
pointing/emulate_mouse_from_touch=true

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
environment/defaults/default_clear_color=Color(0.047, 0.039, 0.11, 1)
```

`games-src/beat-shift/icon.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#0C0A1C"/><rect x="30" y="88" width="68" height="14" fill="#1D2B53"/><rect x="42" y="76" width="44" height="12" fill="#FFF1E8"/><rect x="78" y="24" width="10" height="40" fill="#FFA300"/><rect x="64" y="14" width="38" height="18" fill="#FFF1E8"/><rect x="34" y="30" width="6" height="6" fill="#FFEC27"/><rect x="46" y="46" width="4" height="4" fill="#FFEC27"/><rect x="28" y="52" width="4" height="4" fill="#FF77A8"/></svg>
```

`games-src/beat-shift/src/main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

`games-src/beat-shift/src/main.gd` (스텁 — Task 9에서 교체):
```gdscript
extends Node2D
```

`games-src/beat-shift/src/core/game_state.gd` (스텁 — Task 5에서 교체):
```gdscript
extends Node
```

`games-src/beat-shift/src/core/sfx.gd` (스텁 — Task 6에서 교체):
```gdscript
extends Node
```

`games-src/beat-shift/src/core/conductor.gd` (스텁 — Task 6에서 교체):
```gdscript
extends Node
```

- [ ] **Step 2: 헤드리스 스모크**

```powershell
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
& $GODOT --headless --path games-src\beat-shift --quit
```
Expected: exit 0, 스크립트 에러 없음.

- [ ] **Step 3: gdUnit4 설치(기존 애드온 복사) + 하네스 테스트**

```powershell
Copy-Item -Recurse games-src\starfall-drift\addons games-src\beat-shift\addons
```
`project.godot`에 추가:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")
```
`games-src/beat-shift/tests/test_harness.gd`:
```gdscript
extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_bool(true).is_true()
```
실행:
```powershell
Set-Location games-src\beat-shift
& $GODOT --headless --editor --path . --quit
& $GODOT --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
Set-Location ..\..
```
Expected: 1 passed, exit 0.

- [ ] **Step 4: CREDITS + Commit**

`games-src/beat-shift/CREDITS.md`:
```markdown
# BEAT SHIFT — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Engine: Godot Engine — MIT License
- 스프라이트: AI 생성 픽셀 아트 (PixelLab) 후 가공
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio_beatshift.py)
```

```powershell
git add games-src\beat-shift
git commit -m "feat(beatshift): scaffold Godot project with test harness"
```

---

### Task 2: Tuning + ConductorMath + Motion — 박자·판정창 수학 (TDD)

**Files:**
- Create: `games-src/beat-shift/src/core/tuning.gd`, `games-src/beat-shift/src/core/conductor_math.gd`, `games-src/beat-shift/src/core/motion.gd`
- Test: `games-src/beat-shift/tests/test_conductor_math.gd`

**Interfaces:**
- Produces (전부 static, 이후 태스크가 사용):
  - `Tuning` — 전 상수 (아래 코드가 정본. 이후 태스크는 여기서만 수치 참조)
  - `ConductorMath.beats_from_time(t: float, bpm: float) -> float`
  - `ConductorMath.time_from_beats(beats: float, bpm: float) -> float`
  - `ConductorMath.wrapped_time(loop_len: float, loop_count: int, pos: float) -> float`
  - `ConductorMath.classify(delta: float, perfect_win: float, good_win: float) -> String` — `"perfect" | "good" | ""`
  - `ConductorMath.due_cues(note_times: Array, from_t: float, to_t: float, lead: float) -> Array` — 큐 시각(노트−lead)이 `(from_t, to_t]`에 든 노트들
  - `Motion.arc_pos(from: Vector2, to: Vector2, u: float, height: float) -> Vector2` — 포물선 보간(u 0→1)

- [ ] **Step 1: tuning.gd 작성 (테스트 대상 아님 — 상수 정본)**

`games-src/beat-shift/src/core/tuning.gd`:
```gdscript
class_name Tuning
## 전 게임플레이 수치의 단일 정본. 스펙 §3~§5 시작값. 튜닝은 여기서만.

const VIEW_W := 270.0
const VIEW_H := 480.0

# 리듬 구조 — 섹션 = 인트로 1마디 + 패턴 8마디 + 징글 1마디
const BPM_STEPS := [96.0, 112.0, 128.0, 144.0, 160.0]
const BEATS_PER_BAR := 4
const INTRO_BEATS := 4.0
const NOTE_BEATS := 32.0
const SECTION_BEATS := 40.0
const CUE_LEAD_BEATS := 2.0     # 예비 동작·예비음이 정박보다 앞서는 박

# 판정 (초 — BPM 무관)
const PERFECT_WIN := 0.070
const GOOD_WIN := 0.140
const INPUT_OFFSET := 0.0       # 전역 입력 보정(웹 레이턴시) — 플레이테스트로 튜닝

# 그루브 게이지
const GROOVE_START := 60.0
const GROOVE_MAX := 100.0
const PERFECT_GAIN := 4.0
const GOOD_GAIN := 2.0
const MISS_LOSS := 15.0
const STRAY_LOSS := 5.0         # 노트 없는 헛스윙
const SECTION_RECOVER := 10.0

# 스코어
const SCORE_PERFECT := 100
const SCORE_GOOD := 50
const COMBO_MAX := 5
const SECTION_BONUS := 500

# 연출
const DEATH_SLOWMO := 0.25
const DEATH_SLOWMO_SEC := 0.5
```

- [ ] **Step 2: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_conductor_math.gd`:
```gdscript
extends GdUnitTestSuite

func test_beats_time_roundtrip() -> void:
	assert_float(ConductorMath.beats_from_time(2.5, 96.0)).is_equal_approx(4.0, 0.0001)
	assert_float(ConductorMath.time_from_beats(4.0, 96.0)).is_equal_approx(2.5, 0.0001)
	assert_float(ConductorMath.time_from_beats(ConductorMath.beats_from_time(1.234, 128.0), 128.0)).is_equal_approx(1.234, 0.0001)

func test_wrapped_time() -> void:
	assert_float(ConductorMath.wrapped_time(2.5, 0, 0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(ConductorMath.wrapped_time(2.5, 3, 0.7)).is_equal_approx(8.2, 0.0001)

func test_classify_boundaries() -> void:
	assert_str(ConductorMath.classify(0.0, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(0.07, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(-0.07, 0.07, 0.14)).is_equal("perfect")
	assert_str(ConductorMath.classify(0.071, 0.07, 0.14)).is_equal("good")
	assert_str(ConductorMath.classify(-0.14, 0.07, 0.14)).is_equal("good")
	assert_str(ConductorMath.classify(0.141, 0.07, 0.14)).is_equal("")

func test_due_cues_window_semantics() -> void:
	# 노트 10.0, lead 1.25 → 큐 시각 8.75. (from, to] — from 배타, to 포함
	var notes := [10.0, 12.0, 20.0]
	assert_array(ConductorMath.due_cues(notes, 8.0, 8.75, 1.25)).contains_exactly([10.0])
	assert_array(ConductorMath.due_cues(notes, 8.75, 9.0, 1.25)).is_empty()
	assert_array(ConductorMath.due_cues(notes, 8.0, 11.0, 1.25)).contains_exactly([10.0, 12.0])

func test_arc_pos_endpoints_and_apex() -> void:
	var from := Vector2(0, 100)
	var to := Vector2(100, 100)
	assert_bool(Motion.arc_pos(from, to, 0.0, 40.0).is_equal_approx(from)).is_true()
	assert_bool(Motion.arc_pos(from, to, 1.0, 40.0).is_equal_approx(to)).is_true()
	assert_bool(Motion.arc_pos(from, to, 0.5, 40.0).is_equal_approx(Vector2(50, 60))).is_true()
```

- [ ] **Step 3: 테스트가 실패하는지 확인**

runtest(Global Constraints). Expected: FAIL — `ConductorMath`/`Motion` 미정의 파싱 에러.

- [ ] **Step 4: 구현**

`games-src/beat-shift/src/core/conductor_math.gd`:
```gdscript
class_name ConductorMath
## 박자·판정창 순수 수학. 시간 단위는 초.

static func beats_from_time(t: float, bpm: float) -> float:
	return t * bpm / 60.0

static func time_from_beats(beats: float, bpm: float) -> float:
	return beats * 60.0 / bpm

static func wrapped_time(loop_len: float, loop_count: int, pos: float) -> float:
	return float(loop_count) * loop_len + pos

static func classify(delta: float, perfect_win: float, good_win: float) -> String:
	var d := absf(delta)
	if d <= perfect_win:
		return "perfect"
	if d <= good_win:
		return "good"
	return ""

static func due_cues(note_times: Array, from_t: float, to_t: float, lead: float) -> Array:
	var due: Array = []
	for nt in note_times:
		var cue_t := float(nt) - lead
		if cue_t > from_t and cue_t <= to_t:
			due.append(nt)
	return due
```

`games-src/beat-shift/src/core/motion.gd`:
```gdscript
class_name Motion
## 장면 연출용 이동 수학.

static func arc_pos(from: Vector2, to: Vector2, u: float, height: float) -> Vector2:
	return from.lerp(to, u) + Vector2(0.0, -height * 4.0 * u * (1.0 - u))
```

- [ ] **Step 5: 통과 확인 후 Commit**

runtest — Expected: 전부 passed. (`class_name` 인식이 안 되면 프라이밍 커맨드 재실행)
```powershell
git add games-src\beat-shift\src\core\tuning.gd games-src\beat-shift\src\core\conductor_math.gd games-src\beat-shift\src\core\motion.gd games-src\beat-shift\tests\test_conductor_math.gd
git commit -m "feat(beatshift): tuning constants and beat/judgment math"
```

---

### Task 3: NoteJudge — 노트 판정 상태 머신 (TDD)

**Files:**
- Create: `games-src/beat-shift/src/core/note_judge.gd`
- Test: `games-src/beat-shift/tests/test_note_judge.gd`

**Interfaces:**
- Consumes: `ConductorMath.classify`
- Produces: `NoteJudge extends RefCounted` — 한 섹션의 노트 목록을 들고 판정:
  - `NoteJudge.new(note_times: Array, perfect_win: float, good_win: float)` — note_times는 초 단위, 내부에서 정렬·복사
  - `on_tap(t: float) -> Dictionary` — `{"result": "perfect"|"good"|"stray", "note_time": float}` (stray면 note_time = -1.0). 판정창 안의 **가장 가까운** 미판정 노트를 소비
  - `advance(t: float) -> Array` — t 시점까지 GOOD 창을 지나쳐버린 미판정 노트들을 미스로 확정해 시각 배열로 반환 (한 번만)
  - `remaining() -> int` — 미판정 노트 수
  - `remaining_after(t: float) -> Array` — t 이후의 미판정 노트 시각들 (일시정지 재개용)

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_note_judge.gd`:
```gdscript
extends GdUnitTestSuite

const P := 0.070
const G := 0.140

func _judge(notes: Array) -> NoteJudge:
	return NoteJudge.new(notes, P, G)

func test_perfect_and_good_windows() -> void:
	# 주의: 10.07 - 10.0 은 float에서 0.07을 살짝 넘는다 — 경계 정밀 검증은
	# test_conductor_math의 classify가 담당하고, 여기는 창 안팎만 검증한다
	assert_str(_judge([10.0]).on_tap(10.0).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(10.069).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(9.931).result).is_equal("perfect")
	assert_str(_judge([10.0]).on_tap(10.072).result).is_equal("good")
	assert_str(_judge([10.0]).on_tap(9.861).result).is_equal("good")
	assert_str(_judge([10.0]).on_tap(10.142).result).is_equal("stray")

func test_tap_far_from_any_note_is_stray() -> void:
	var r := _judge([10.0, 12.0]).on_tap(11.0)
	assert_str(r.result).is_equal("stray")
	assert_float(r.note_time).is_equal_approx(-1.0, 0.0001)

func test_nearest_note_wins_when_windows_overlap() -> void:
	# 160BPM 엇박 간격 0.1875s < GOOD 창 2배 — 겹칠 때 더 가까운 노트를 소비
	# 탭 10.10: 10.0까지 0.10, 10.1875까지 0.0875 → 더 가까운 10.1875가 GOOD
	var j := _judge([10.0, 10.1875])
	var r := j.on_tap(10.10)
	assert_str(r.result).is_equal("good")
	assert_float(r.note_time).is_equal_approx(10.1875, 0.0001)

func test_consumed_note_cannot_be_hit_twice() -> void:
	var j := _judge([10.0])
	assert_str(j.on_tap(10.0).result).is_equal("perfect")
	assert_str(j.on_tap(10.02).result).is_equal("stray")
	assert_int(j.remaining()).is_equal(0)

func test_advance_reports_each_miss_once() -> void:
	var j := _judge([10.0, 11.0])
	assert_array(j.advance(10.0)).is_empty()
	assert_array(j.advance(10.15)).contains_exactly([10.0])
	assert_array(j.advance(10.2)).is_empty()
	assert_array(j.advance(12.0)).contains_exactly([11.0])
	assert_int(j.remaining()).is_equal(0)

func test_hit_note_is_not_missed_later() -> void:
	var j := _judge([10.0, 11.0])
	j.on_tap(10.0)
	assert_array(j.advance(12.0)).contains_exactly([11.0])

func test_remaining_after_filters_judged_and_past() -> void:
	var j := _judge([10.0, 11.0, 12.0, 13.0])
	j.on_tap(11.0)
	assert_array(j.remaining_after(11.5)).contains_exactly([12.0, 13.0])
	assert_array(j.remaining_after(9.0)).contains_exactly([10.0, 12.0, 13.0])
```

- [ ] **Step 2: 실패 확인** — runtest. Expected: `NoteJudge` 미정의 FAIL.

- [ ] **Step 3: 구현**

`games-src/beat-shift/src/core/note_judge.gd`:
```gdscript
class_name NoteJudge
extends RefCounted
## 한 섹션의 노트 판정 상태 머신. 시간 단위는 초. Godot API 비의존 — 헤드리스 테스트 대상.

var _notes: Array = []
var _hit: Array = []
var _perfect_win: float
var _good_win: float
var _miss_idx := 0

func _init(note_times: Array, perfect_win: float, good_win: float) -> void:
	_notes = note_times.duplicate()
	_notes.sort()
	_hit.resize(_notes.size())
	_hit.fill(false)
	_perfect_win = perfect_win
	_good_win = good_win

func on_tap(t: float) -> Dictionary:
	var best := -1
	var best_d := INF
	for i in range(_notes.size()):
		if _hit[i]:
			continue
		var d: float = float(_notes[i]) - t
		if d > _good_win:
			break
		if absf(d) <= _good_win and absf(d) < best_d:
			best = i
			best_d = absf(d)
	if best == -1:
		return {"result": "stray", "note_time": -1.0}
	_hit[best] = true
	return {"result": ConductorMath.classify(best_d, _perfect_win, _good_win), "note_time": _notes[best]}

func advance(t: float) -> Array:
	var missed: Array = []
	while _miss_idx < _notes.size():
		if _hit[_miss_idx]:
			_miss_idx += 1
			continue
		if float(_notes[_miss_idx]) + _good_win < t:
			_hit[_miss_idx] = true
			missed.append(_notes[_miss_idx])
			_miss_idx += 1
		else:
			break
	return missed

func remaining() -> int:
	var n := 0
	for h in _hit:
		if not h:
			n += 1
	return n

func remaining_after(t: float) -> Array:
	var out: Array = []
	for i in range(_notes.size()):
		if not _hit[i] and float(_notes[i]) >= t:
			out.append(_notes[i])
	return out
```

- [ ] **Step 4: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\beat-shift\src\core\note_judge.gd games-src\beat-shift\tests\test_note_judge.gd
git commit -m "feat(beatshift): note judgment state machine with nearest-note pairing"
```

---

### Task 4: Patterns — 대장간 패턴 데이터와 티어 (TDD)

**Files:**
- Create: `games-src/beat-shift/src/core/patterns.gd`
- Test: `games-src/beat-shift/tests/test_patterns.gd`

**Interfaces:**
- Produces:
  - `Patterns.TIERS` — 티어별 패턴 풀. 패턴 = 8박(2마디) 프레이즈 내 비트 오프셋 배열
  - `Patterns.tier_for_section(section: int) -> int` — 섹션 인덱스 → 티어(상한 클램프)
  - `Patterns.section_notes(tier: int, rng: RandomNumberGenerator) -> Array` — 한 섹션(32박)의 노트 비트들. **인트로 오프셋은 미포함** — 호출자(Main)가 `Tuning.INTRO_BEATS`를 더해 초로 변환

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_patterns.gd`:
```gdscript
extends GdUnitTestSuite

func _rng(seed_v: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return rng

func test_tier_for_section_clamps() -> void:
	assert_int(Patterns.tier_for_section(0)).is_equal(0)
	assert_int(Patterns.tier_for_section(2)).is_equal(2)
	assert_int(Patterns.tier_for_section(99)).is_equal(Patterns.TIERS.size() - 1)

func test_pattern_data_invariants() -> void:
	# 모든 패턴: 0.0으로 시작, [0, 6.5] 범위, 오름차순, 최소 간격 0.5박
	for tier in Patterns.TIERS:
		for pattern in tier:
			assert_float(pattern[0]).is_equal_approx(0.0, 0.0001)
			for i in range(pattern.size()):
				assert_float(pattern[i]).is_between(0.0, 6.5)
				if i > 0:
					assert_float(float(pattern[i]) - float(pattern[i - 1])).is_greater_equal(0.5)

func test_section_notes_range_order_and_spacing() -> void:
	for tier in range(Patterns.TIERS.size()):
		var notes := Patterns.section_notes(tier, _rng(42 + tier))
		assert_int(notes.size()).is_between(12, 28)
		for i in range(notes.size()):
			assert_float(notes[i]).is_between(0.0, 31.9)
			if i > 0:
				assert_float(float(notes[i]) - float(notes[i - 1])).is_greater_equal(0.5)

func test_section_notes_phrase_alignment() -> void:
	# 패턴이 전부 0.0으로 시작하므로 각 프레이즈 시작박(0,8,16,24)은 항상 노트
	var notes := Patterns.section_notes(0, _rng(7))
	for start in [0.0, 8.0, 16.0, 24.0]:
		assert_bool(notes.has(start)).is_true()

func test_section_notes_deterministic_with_seed() -> void:
	assert_array(Patterns.section_notes(2, _rng(123))).is_equal(Patterns.section_notes(2, _rng(123)))
```

- [ ] **Step 2: 실패 확인** — runtest. Expected: `Patterns` 미정의 FAIL.

- [ ] **Step 3: 구현**

`games-src/beat-shift/src/core/patterns.gd`:
```gdscript
class_name Patterns
## 대장간 패턴 데이터. 패턴 = 8박(2마디) 프레이즈 내 비트 오프셋 배열.
## 데이터 규칙: 0.0으로 시작, 오프셋 [0, 6.5], 최소 간격 0.5박 —
## 마지막 노트(≤6.5)와 다음 프레이즈 첫 노트(8.0) 사이도 1.5박 이상 벌어진다.

const TIERS := [
	[  # tier 0 — 정박 4분음
		[0.0, 2.0, 4.0, 6.0],
		[0.0, 2.0, 4.0],
		[0.0, 4.0, 6.0],
		[0.0, 2.0, 6.0],
	],
	[  # tier 1 — 정박 조밀
		[0.0, 1.0, 2.0, 4.0, 6.0],
		[0.0, 2.0, 3.0, 4.0, 6.0],
		[0.0, 2.0, 4.0, 5.0, 6.0],
		[0.0, 1.0, 4.0, 5.0],
	],
	[  # tier 2 — 엇박 등장
		[0.0, 1.5, 2.0, 4.0, 6.0],
		[0.0, 2.0, 2.5, 4.0, 6.0],
		[0.0, 0.5, 2.0, 4.0, 4.5, 6.0],
		[0.0, 2.0, 3.5, 4.0, 6.0],
	],
	[  # tier 3 — 조밀 + 엇박
		[0.0, 1.0, 1.5, 2.0, 4.0, 5.5, 6.0],
		[0.0, 0.5, 1.0, 2.5, 4.0, 4.5, 6.0],
		[0.0, 1.5, 2.5, 4.0, 5.0, 5.5, 6.5],
		[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
	],
]

const PHRASE_BEATS := 8.0
const PHRASES_PER_SECTION := 4

static func tier_for_section(section: int) -> int:
	return mini(section, TIERS.size() - 1)

static func section_notes(tier: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = TIERS[mini(tier, TIERS.size() - 1)]
	var notes: Array = []
	for phrase in range(PHRASES_PER_SECTION):
		var pattern: Array = pool[rng.randi_range(0, pool.size() - 1)]
		for b in pattern:
			notes.append(float(b) + PHRASE_BEATS * float(phrase))
	return notes
```

- [ ] **Step 4: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\beat-shift\src\core\patterns.gd games-src\beat-shift\tests\test_patterns.gd
git commit -m "feat(beatshift): forge pattern data with difficulty tiers"
```

---

### Task 5: Groove + Scoring + Persistence + GameState (TDD)

**Files:**
- Create: `games-src/beat-shift/src/core/groove.gd`, `games-src/beat-shift/src/core/scoring.gd`, `games-src/beat-shift/src/core/persistence.gd`
- Modify: `games-src/beat-shift/src/core/game_state.gd` (스텁 → 본 구현)
- Test: `games-src/beat-shift/tests/test_groove_scoring.gd`

**Interfaces:**
- Consumes: `Tuning` 상수
- Produces:
  - `Groove.apply(gauge: float, event: String) -> float` — event는 `"perfect"|"good"|"miss"|"stray"`, 0~`GROOVE_MAX` 클램프
  - `Groove.recover(gauge: float) -> float` / `Groove.dead(gauge: float) -> bool`
  - `Scoring.hit(result: String, mult: int) -> Dictionary` — `{"points": int, "mult": int}`. 성공은 **현재 배수로 점수를 주고** 배수 +1(상한 `COMBO_MAX`), miss/stray는 points 0·배수 1로 리셋
  - `Scoring.section_bonus(section_index: int) -> int` — `SECTION_BONUS * (section_index + 1)`
  - `Persistence.save_best(path: String, best: int) -> void` / `Persistence.load_best(path: String) -> int`
  - 오토로드 `GameState`: `enum Phase { TITLE, PLAYING, GAME_OVER }`, 프로퍼티 `phase: int`, `mult: int`, `groove: float`, `best: int`, `quick_restart: bool`, 메서드 `start_run() -> void`, `register_hit(result: String) -> int`(획득 점수 반환), `register_fail(kind: String) -> void`, `register_section_clear(section_index: int) -> int`(보너스 반환), `is_dead() -> bool`, `score() -> int`, `end_run() -> void`. `_ready`에서 액션 `"tap"` 등록(Space + 마우스 좌클릭)

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_groove_scoring.gd`:
```gdscript
extends GdUnitTestSuite

func test_groove_apply_values_and_clamp() -> void:
	assert_float(Groove.apply(60.0, "perfect")).is_equal_approx(64.0, 0.001)
	assert_float(Groove.apply(60.0, "good")).is_equal_approx(62.0, 0.001)
	assert_float(Groove.apply(60.0, "miss")).is_equal_approx(45.0, 0.001)
	assert_float(Groove.apply(60.0, "stray")).is_equal_approx(55.0, 0.001)
	assert_float(Groove.apply(99.0, "perfect")).is_equal_approx(100.0, 0.001)
	assert_float(Groove.apply(10.0, "miss")).is_equal_approx(0.0, 0.001)

func test_groove_dead_boundary_and_recover() -> void:
	assert_bool(Groove.dead(0.0)).is_true()
	assert_bool(Groove.dead(0.1)).is_false()
	assert_float(Groove.recover(45.0)).is_equal_approx(55.0, 0.001)
	assert_float(Groove.recover(95.0)).is_equal_approx(100.0, 0.001)

func test_scoring_hit_multiplies_then_increments() -> void:
	var r := Scoring.hit("perfect", 1)
	assert_int(r.points).is_equal(100)
	assert_int(r.mult).is_equal(2)
	r = Scoring.hit("good", 3)
	assert_int(r.points).is_equal(150)
	assert_int(r.mult).is_equal(4)
	r = Scoring.hit("perfect", 5)
	assert_int(r.points).is_equal(500)
	assert_int(r.mult).is_equal(5)

func test_scoring_fail_resets() -> void:
	var r := Scoring.hit("miss", 4)
	assert_int(r.points).is_equal(0)
	assert_int(r.mult).is_equal(1)
	r = Scoring.hit("stray", 4)
	assert_int(r.mult).is_equal(1)

func test_section_bonus_scales() -> void:
	assert_int(Scoring.section_bonus(0)).is_equal(500)
	assert_int(Scoring.section_bonus(2)).is_equal(1500)

func test_persistence_roundtrip_missing_and_corrupt() -> void:
	var path := "user://test_best.json"
	Persistence.save_best(path, 777)
	assert_int(Persistence.load_best(path)).is_equal(777)
	DirAccess.remove_absolute(path)
	assert_int(Persistence.load_best("user://no_such_file.json")).is_equal(0)
	var f := FileAccess.open("user://corrupt.json", FileAccess.WRITE)
	f.store_string("not json{{")
	f.close()
	assert_int(Persistence.load_best("user://corrupt.json")).is_equal(0)
	DirAccess.remove_absolute("user://corrupt.json")

func test_game_state_run_flow() -> void:
	GameState.start_run()
	assert_int(GameState.score()).is_equal(0)
	assert_float(GameState.groove).is_equal_approx(60.0, 0.001)
	assert_int(GameState.register_hit("perfect")).is_equal(100)   # mult 1→2, groove 64
	assert_int(GameState.register_hit("perfect")).is_equal(200)   # mult 2→3, groove 68
	GameState.register_fail("miss")                               # mult 리셋, groove 53
	assert_int(GameState.mult).is_equal(1)
	assert_float(GameState.groove).is_equal_approx(53.0, 0.001)
	assert_int(GameState.register_section_clear(0)).is_equal(500) # groove 63
	assert_int(GameState.score()).is_equal(800)
	assert_bool(GameState.is_dead()).is_false()

func test_game_state_death() -> void:
	GameState.start_run()
	for i in range(4):
		GameState.register_fail("miss")   # 60 - 4*15 = 0
	assert_bool(GameState.is_dead()).is_true()

func test_tap_action_registered() -> void:
	assert_bool(InputMap.has_action("tap")).is_true()
```

- [ ] **Step 2: 실패 확인** — runtest. Expected: `Groove`/`Scoring`/`Persistence` 미정의 FAIL.

- [ ] **Step 3: 구현**

`games-src/beat-shift/src/core/groove.gd`:
```gdscript
class_name Groove
## 그루브 게이지 증감. 순수 static.

static func apply(gauge: float, event: String) -> float:
	var delta := 0.0
	match event:
		"perfect":
			delta = Tuning.PERFECT_GAIN
		"good":
			delta = Tuning.GOOD_GAIN
		"miss":
			delta = -Tuning.MISS_LOSS
		"stray":
			delta = -Tuning.STRAY_LOSS
	return clampf(gauge + delta, 0.0, Tuning.GROOVE_MAX)

static func recover(gauge: float) -> float:
	return clampf(gauge + Tuning.SECTION_RECOVER, 0.0, Tuning.GROOVE_MAX)

static func dead(gauge: float) -> bool:
	return gauge <= 0.0
```

`games-src/beat-shift/src/core/scoring.gd`:
```gdscript
class_name Scoring
## 판정 → 점수·콤보 배수. 성공은 현재 배수로 지불하고 배수를 올린다.

static func hit(result: String, mult: int) -> Dictionary:
	match result:
		"perfect":
			return {"points": Tuning.SCORE_PERFECT * mult, "mult": mini(mult + 1, Tuning.COMBO_MAX)}
		"good":
			return {"points": Tuning.SCORE_GOOD * mult, "mult": mini(mult + 1, Tuning.COMBO_MAX)}
	return {"points": 0, "mult": 1}

static func section_bonus(section_index: int) -> int:
	return Tuning.SECTION_BONUS * (section_index + 1)
```

`games-src/beat-shift/src/core/persistence.gd`:
```gdscript
class_name Persistence

static func save_best(path: String, best: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best}))

static func load_best(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY and data.has("best"):
		return int(data.best)
	return 0
```

`games-src/beat-shift/src/core/game_state.gd` (스텁 교체):
```gdscript
extends Node
## 세션 상태·점수·베스트. 씬 리로드에도 살아남는 오토로드.

enum Phase { TITLE, PLAYING, GAME_OVER }

const BEST_PATH := "user://best.json"

var phase: int = Phase.TITLE
var mult: int = 1
var groove: float = Tuning.GROOVE_START
var best: int = 0
var quick_restart: bool = false
var _score: int = 0

func _ready() -> void:
	best = Persistence.load_best(BEST_PATH)
	_register_input()

func _register_input() -> void:
	if InputMap.has_action("tap"):
		return
	InputMap.add_action("tap")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("tap", key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("tap", mouse)

func start_run() -> void:
	phase = Phase.PLAYING
	mult = 1
	groove = Tuning.GROOVE_START
	_score = 0

func register_hit(result: String) -> int:
	groove = Groove.apply(groove, result)
	var r := Scoring.hit(result, mult)
	mult = r.mult
	_score += r.points
	return r.points

func register_fail(kind: String) -> void:
	groove = Groove.apply(groove, kind)
	mult = 1

func register_section_clear(section_index: int) -> int:
	groove = Groove.recover(groove)
	var b := Scoring.section_bonus(section_index)
	_score += b
	return b

func is_dead() -> bool:
	return Groove.dead(groove)

func score() -> int:
	return _score

func end_run() -> void:
	phase = Phase.GAME_OVER
	if score() > best:
		best = score()
		Persistence.save_best(BEST_PATH, best)
```

- [ ] **Step 4: 통과 확인 후 Commit**

runtest — Expected: 전부 passed (하네스 포함 누적).
```powershell
git add games-src\beat-shift\src\core games-src\beat-shift\tests\test_groove_scoring.gd
git commit -m "feat(beatshift): groove gauge, scoring, persistence, GameState autoload"
```

---

### Task 6: 오디오 합성 + Sfx·Conductor 오토로드

**Files:**
- Create: `scripts/gen_audio_beatshift.py`, `games-src/beat-shift/assets/sfx/*.wav` (loop_96/112/128/144/160, anvil_1~4, good, precue, miss, whiff, jingle, gameover)
- Modify: `games-src/beat-shift/src/core/sfx.gd`, `games-src/beat-shift/src/core/conductor.gd` (스텁 → 본 구현)
- Test: `games-src/beat-shift/tests/test_audio.gd`

**Interfaces:**
- Consumes: `Tuning.BPM_STEPS`, `ConductorMath.wrapped_time/beats_from_time`
- Produces:
  - 백킹 루프 5종 — **정확히 1마디(4박) 길이**, 미니멀 퍼커션(킥·스네어·햇·베이스 펄스)
  - 오토로드 `Sfx`: `has_stream(name: String) -> bool`, `play(name: String, volume_db: float = 0.0) -> void`. 미등록 이름은 조용히 무시
  - 오토로드 `Conductor`: `signal beat(index: int)`, 프로퍼티 `bpm: float`, `running: bool`, 메서드 `start_section(bpm_step: int) -> void`(스텝 상한 클램프), `resume_at_bar(bar: int) -> void`, `stop() -> void`, `song_time() -> float`(섹션 시작 기준 연속 초 — 오디오 시계+레이턴시 보정, 단조 보장), `song_beats() -> float`

- [ ] **Step 1: 합성 스크립트 작성 (stdlib만 사용)**

`scripts/gen_audio_beatshift.py`:
```python
"""BEAT SHIFT 오디오 합성 (stdlib만). 실행: python scripts/gen_audio_beatshift.py"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "games-src", "beat-shift", "assets", "sfx")
BPMS = [96, 112, 128, 144, 160]

def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("OK", name, len(samples))

def env(i, n, a=0.005):
    t = i / n
    return t / a if t < a else max(0.0, 1.0 - (t - a) / (1.0 - a))

def kick(dur=0.12, vol=0.9):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = 150 - (150 - 45) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(vol * env(i, n) * math.sin(ph))
    return out

def snare(dur=0.10, vol=0.45):
    n = int(SR * dur)
    return [vol * env(i, n) * (0.7 * random.uniform(-1, 1) + 0.3 * math.sin(2 * math.pi * 190 * i / SR))
            for i in range(n)]

def hat(dur=0.03, vol=0.16):
    n = int(SR * dur)
    return [vol * env(i, n) * random.uniform(-1, 1) for i in range(n)]

def bell(freq, dur=0.5, vol=0.5):
    # 모루 벨 — 비화성 배음(금속성)
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        s = (math.sin(2 * math.pi * freq * t)
             + 0.6 * math.sin(2 * math.pi * freq * 2.76 * t)
             + 0.3 * math.sin(2 * math.pi * freq * 5.40 * t))
        out.append(vol * env(i, n, 0.002) * s / 1.9)
    return out

def place(buf, t_sec, samples):
    start = int(t_sec * SR)
    for j, s in enumerate(samples):
        k = start + j
        if 0 <= k < len(buf):
            buf[k] += s

def make_loop(bpm):
    spb = 60.0 / bpm
    n = int(round(SR * spb * 4))          # 정확히 1마디
    buf = [0.0] * n
    for b in [0, 2]:
        place(buf, b * spb, kick())
    for b in [1, 3]:
        place(buf, b * spb, snare())
    for e in range(8):
        place(buf, e * 0.5 * spb, hat())
    for e in [0, 3, 4, 7]:                # 얇은 8분 베이스 펄스
        t0 = e * 0.5 * spb
        m = int(SR * min(0.22, spb * 0.45))
        for i in range(m):
            k = int(t0 * SR) + i
            if k < n:
                buf[k] += 0.12 * env(i, m, 0.01) * (1.0 if math.sin(2 * math.pi * 55 * i / SR) >= 0 else -1.0)
    return [max(-1.0, min(1.0, s)) for s in buf]

def miss_sfx():
    n = int(SR * 0.3); out = []; ph = 0.0
    for i in range(n):
        f = 160 - 100 * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(env(i, n) * (0.45 * random.uniform(-1, 1) * (1 - i / n) + 0.35 * math.sin(ph)))
    return out

def whiff_sfx():
    n = int(SR * 0.12)
    return [0.15 * env(i, n, 0.3) * random.uniform(-1, 1) for i in range(n)]

def arp(freqs, step=0.09, dur=0.16, vol=0.4):
    total = int(SR * (step * (len(freqs) - 1) + dur))
    buf = [0.0] * total
    for k, f in enumerate(freqs):
        place(buf, k * step, bell(f, dur, vol))
    return [max(-1.0, min(1.0, s)) for s in buf]

random.seed(11)
for bpm in BPMS:
    save("loop_%d" % bpm, make_loop(bpm))
for i, f in enumerate([523.25, 587.33, 659.25, 783.99]):   # C5 D5 E5 G5 — PERFECT 멜로디 벨
    save("anvil_%d" % (i + 1), bell(f, 0.5, 0.55))
save("good", bell(392.0, 0.25, 0.4))
save("precue", bell(1567.98, 0.08, 0.25))
save("miss", miss_sfx())
save("whiff", whiff_sfx())
save("jingle", arp([523.25, 659.25, 783.99, 1046.5]))
save("gameover", arp([392.0, 329.63, 261.63, 196.0], 0.14, 0.3))
```

```powershell
python scripts\gen_audio_beatshift.py
```
Expected: 15개 wav 생성 로그. 루프 샘플 수 확인 — 96:55125, 112:47250, 128:41344, 144:36750, 160:33075.

- [ ] **Step 2: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_audio.gd`:
```gdscript
extends GdUnitTestSuite

func test_sfx_streams_loaded() -> void:
	for n in ["precue", "good", "miss", "whiff", "jingle", "gameover", "anvil_1", "anvil_2", "anvil_3", "anvil_4"]:
		assert_bool(Sfx.has_stream(n)).is_true()

func test_unknown_name_is_silent_noop() -> void:
	var before := Sfx.get_child_count()
	Sfx.play("no_such_sound")
	assert_int(Sfx.get_child_count()).is_equal(before)

func test_loop_assets_exist_for_all_bpm_steps() -> void:
	for bpm in Tuning.BPM_STEPS:
		assert_bool(ResourceLoader.exists("res://assets/sfx/loop_%d.wav" % int(bpm))).is_true()

func test_conductor_start_stop_and_clamp() -> void:
	Conductor.start_section(0)
	assert_float(Conductor.bpm).is_equal_approx(96.0, 0.001)
	assert_bool(Conductor.running).is_true()
	Conductor.start_section(99)
	assert_float(Conductor.bpm).is_equal_approx(160.0, 0.001)
	Conductor.stop()
	assert_bool(Conductor.running).is_false()

func test_conductor_resume_at_bar_offsets_time() -> void:
	Conductor.start_section(0)   # 96 BPM — 1마디 = 2.5s
	Conductor.stop()
	Conductor.resume_at_bar(3)
	assert_float(Conductor.song_time()).is_greater_equal(7.49)
	assert_float(Conductor.song_beats()).is_greater_equal(11.98)
	Conductor.stop()
```

runtest — Expected: `has_stream`/`start_section` 미정의 FAIL.

- [ ] **Step 3: Sfx 구현**

`games-src/beat-shift/src/core/sfx.gd` (스텁 교체):
```gdscript
extends Node
## 원샷 SFX. 스트림이 없으면 조용히 무시 — 에셋 없이도 게임이 동작한다.

const NAMES := ["precue", "good", "miss", "whiff", "jingle", "gameover",
	"anvil_1", "anvil_2", "anvil_3", "anvil_4"]

var _streams: Dictionary = {}

func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)

func has_stream(name: String) -> bool:
	return _streams.has(name)

func play(name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = _streams[name]
	pl.volume_db = volume_db
	add_child(pl)
	pl.finished.connect(pl.queue_free)
	pl.play()
```

- [ ] **Step 4: Conductor 구현**

`games-src/beat-shift/src/core/conductor.gd` (스텁 교체):
```gdscript
extends Node
## 박자 시계. 오디오 재생 위치가 진실 — 시각 프레임이 아니다.
## 백킹 루프는 정확히 1마디 → 루프 랩 카운트 = 마디 인덱스.

signal beat(index: int)

var bpm: float = 0.0
var running := false

var _player: AudioStreamPlayer
var _loop_len := 1.0
var _loop_count := 0
var _last_pos := 0.0
var _last_time := 0.0
var _last_beat := -1

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func start_section(bpm_step: int) -> void:
	bpm = Tuning.BPM_STEPS[mini(bpm_step, Tuning.BPM_STEPS.size() - 1)]
	var stream: AudioStreamWAV = load("res://assets/sfx/loop_%d.wav" % int(bpm))
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	_loop_len = float(stream.data.size() / 2) / float(stream.mix_rate)
	_player.stream = stream
	_loop_count = 0
	_last_pos = 0.0
	_last_time = 0.0
	_last_beat = -1
	running = true
	_player.play()

func resume_at_bar(bar: int) -> void:
	_loop_count = bar
	_last_pos = 0.0
	_last_time = float(bar) * _loop_len
	_last_beat = bar * Tuning.BEATS_PER_BAR - 1
	running = true
	_player.play(0.0)

func stop() -> void:
	running = false
	_player.stop()

func song_time() -> float:
	if not running:
		return _last_time
	var pos := _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	pos = maxf(pos, 0.0)
	if pos < _last_pos - _loop_len * 0.5:
		_loop_count += 1
	_last_pos = pos
	var t := ConductorMath.wrapped_time(_loop_len, _loop_count, pos)
	t = maxf(t, _last_time)
	_last_time = t
	return t

func song_beats() -> float:
	return ConductorMath.beats_from_time(song_time(), bpm)

func _process(_delta: float) -> void:
	if not running:
		return
	var b := int(floor(song_beats()))
	if b > _last_beat:
		_last_beat = b
		beat.emit(b)
```

- [ ] **Step 5: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add scripts\gen_audio_beatshift.py games-src\beat-shift\assets\sfx games-src\beat-shift\src\core\sfx.gd games-src\beat-shift\src\core\conductor.gd games-src\beat-shift\tests\test_audio.gd
git commit -m "feat(beatshift): synthesized percussion loops, SFX and beat-clock Conductor"
```

---

### Task 7: PixelLab 에셋 생성

**Files:**
- Create: `scripts/gen_pixellab_beatshift.py`, `games-src/beat-shift/assets/img/*.png` (smith_idle, smith_swing, assistant, ingot, blade, anvil, furnace, emblem), `scripts/pixellab_out/beatshift_sheet.png`(검수용, 커밋 안 함)

**Interfaces:**
- Consumes: `.env.local`의 `PIXELLAB_API_KEY`
- Produces: `res://assets/img/<이름>.png` — smith_idle(48×48), smith_swing(48×48), assistant(32×32), ingot(16×16), blade(24×24), anvil(48×24), furnace(64×64), emblem(48×48)

- [ ] **Step 1: 생성 스크립트 작성**

`scripts/gen_pixellab_beatshift.py` (`scripts/gen_pixellab.py`와 동일 골격 — API 필드가 실제와 다르면 gen_pixellab.py 최신 상태를 따른다):
```python
"""PixelLab으로 BEAT SHIFT 스프라이트 생성. 실행: python scripts/gen_pixellab_beatshift.py [이름...]"""
import base64, json, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "beat-shift", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro arcade sprite, warm forge night palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding"

SPRITES = {
    "smith_idle":  (48, 48, f"stocky pixel blacksmith holding hammer raised ready, orange #ffa300 apron, dark hair, side view facing left, {STYLE}"),
    "smith_swing": (48, 48, f"stocky pixel blacksmith mid downward hammer strike, dynamic lean, orange #ffa300 apron, dark hair, side view facing left, {STYLE}"),
    "assistant":   (32, 32, f"small pixel apprentice kid mid-throw gesture, teal #29adff cap and gloves, side view facing right, {STYLE}"),
    "ingot":       (16, 16, f"glowing hot metal ingot bar, orange #ffa300 core with yellow #ffec27 heat edges, {STYLE}"),
    "blade":       (24, 24, f"freshly forged short sword blade sparkling, pale #fff1e8 steel, diagonal orientation, {STYLE}"),
    "anvil":       (48, 24, f"sturdy iron blacksmith anvil, dark blue-gray #1d2b53 metal with lighter top face, side view, {STYLE}"),
    "furnace":     (64, 64, f"stone forge furnace with glowing orange #ffa300 fire mouth, dark brick, embers, {STYLE}"),
    "emblem":      (48, 48, f"emblem of pixel hammer crossed with a music note, yellow #ffec27 and orange #ffa300 on transparent, {STYLE}"),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_API_KEY not found in .env.local")

def find_base64(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "base64" and isinstance(v, str):
                return v
            r = find_base64(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_base64(v)
            if r:
                return r
    return None

def generate(key, name, w, h, desc):
    body = json.dumps({
        "description": desc,
        "negative_description": NEG,
        "image_size": {"width": w, "height": h},
        "no_background": True,
    }).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.load(resp)
    b64 = find_base64(data)
    if not b64:
        sys.exit(f"{name}: no image in response: {str(data)[:300]}")
    if "," in b64[:80]:
        b64 = b64.split(",", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"{name}.png"), "wb") as f:
        f.write(base64.b64decode(b64))
    print(f"OK {name}")

def main():
    key = read_key()
    for name in (sys.argv[1:] or list(SPRITES)):
        w, h, desc = SPRITES[name]
        generate(key, name, w, h, desc)
        time.sleep(1)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 생성 실행 + 검수 시트**

```powershell
python scripts\gen_pixellab_beatshift.py
python -c @"
from PIL import Image
import os
d = r'games-src\beat-shift\assets\img'
names = ['smith_idle','smith_swing','assistant','ingot','blade','anvil','furnace','emblem']
sheet = Image.new('RGBA', (len(names)*100, 100), (12,10,28,255))
for i,n in enumerate(names):
    im = Image.open(os.path.join(d, n+'.png')).convert('RGBA')
    im = im.resize((im.width*2, im.height*2), Image.NEAREST)
    sheet.paste(im, (i*100+4, 50-im.height//2), im)
os.makedirs(r'scripts\pixellab_out', exist_ok=True)
sheet.save(r'scripts\pixellab_out\beatshift_sheet.png')
print('sheet saved')
"@
```
Expected: 8개 PNG 생성, beatshift_sheet.png 저장. **beatshift_sheet.png를 Read 도구로 열어 눈으로 검수**:
- smith_idle과 smith_swing이 **같은 캐릭터로 읽히는가** — 다르면 두 장을 한 번에 재생성하거나, smith_idle 하나만 쓰고 스윙은 코드 회전(-25°, 0.12s)으로 대체하는 폴백 채택
- 실루엣이 안 읽히거나 팔레트가 튀면 해당 이름만 재생성 (`python scripts\gen_pixellab_beatshift.py ingot`)
- API가 특정 크기를 거부하면 2배 크기로 생성 후 PIL `Image.resize(..., Image.NEAREST)` 다운스케일

- [ ] **Step 3: 크기 검증 + Godot 임포트 스모크**

```powershell
python -c @"
from PIL import Image
import os
exp = {'smith_idle':(48,48),'smith_swing':(48,48),'assistant':(32,32),'ingot':(16,16),'blade':(24,24),'anvil':(48,24),'furnace':(64,64),'emblem':(48,48)}
d = r'games-src\beat-shift\assets\img'
for n,(w,h) in exp.items():
    s = Image.open(os.path.join(d, n+'.png')).size
    assert s == (w,h), f'{n}: {s} != {(w,h)}'
print('all sizes OK')
"@
& $GODOT --headless --path games-src\beat-shift --quit
```
Expected: `all sizes OK`, Godot 임포트 에러 없이 exit 0.

- [ ] **Step 4: Commit**

```powershell
git add scripts\gen_pixellab_beatshift.py games-src\beat-shift\assets\img
git commit -m "feat(beatshift): PixelLab-generated forge sprites"
```

---

### Task 8: ForgeScene + Ingot + Hud — 대장간 장면과 연출

**Files:**
- Create: `games-src/beat-shift/src/forge_scene.gd`, `games-src/beat-shift/src/ingot.gd`, `games-src/beat-shift/src/hud.gd`
- Test: `games-src/beat-shift/tests/test_forge_scene.gd`

**Interfaces:**
- Consumes: `Motion.arc_pos`, `Conductor.song_time()/beat`, `Sfx.play`, `Tuning.VIEW_*`
- Produces:
  - `ForgeScene extends Node2D` (`ForgeScene.new()`로 생성): `spawn_cue(note_time: float, cue_time: float) -> void`, `on_result(result: String, note_time: float) -> void`(result는 `"perfect"|"good"|"miss"|"stray"`, stray는 note_time -1.0), `set_heat(ratio: float) -> void`, `clear_cues() -> void`, `ingot_count() -> int`
  - `Ingot extends Sprite2D`: `setup(from: Vector2, to: Vector2, t0: float, t1: float) -> void`, `note_time() -> float`, `forge(perfect: bool) -> void`, `drop() -> void` — 비행은 Conductor 시간 기반(정박에 정확히 모루 도착), 판정 후 낙하/비상은 프레임 delta 기반(시각 연출)
  - `Hud extends CanvasLayer`: `set_groove(ratio: float) -> void`(0~1), `set_mult(m: int) -> void`, `flash(text: String) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/beat-shift/tests/test_forge_scene.gd`:
```gdscript
extends GdUnitTestSuite

func _scene() -> ForgeScene:
	var f: ForgeScene = auto_free(ForgeScene.new())
	add_child(f)
	return f

func test_spawn_cue_creates_ingot() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	assert_int(f.ingot_count()).is_equal(1)

func test_hit_consumes_matching_ingot() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.spawn_cue(12.0, 10.75)
	f.on_result("perfect", 10.0)
	assert_int(f.ingot_count()).is_equal(1)
	f.on_result("good", 12.0)
	assert_int(f.ingot_count()).is_equal(0)

func test_miss_consumes_ingot_and_stray_does_not() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.on_result("stray", -1.0)
	assert_int(f.ingot_count()).is_equal(1)
	f.on_result("miss", 10.0)
	assert_int(f.ingot_count()).is_equal(0)

func test_clear_cues() -> void:
	var f := _scene()
	f.spawn_cue(10.0, 8.75)
	f.spawn_cue(12.0, 10.75)
	f.clear_cues()
	assert_int(f.ingot_count()).is_equal(0)
```

runtest — Expected: `ForgeScene` 미정의 FAIL.

- [ ] **Step 2: Ingot 구현**

`games-src/beat-shift/src/ingot.gd`:
```gdscript
class_name Ingot
extends Sprite2D
## 조수가 던진 잉곳. 비행은 Conductor 시간으로 구동 — 정박에 정확히 모루 도착.

const ARC_HEIGHT := 46.0

var _from: Vector2
var _to: Vector2
var _t0 := 0.0
var _t1 := 1.0
var _state := "fly"
var _vel := Vector2.ZERO
var _life := 0.0

func setup(from: Vector2, to: Vector2, t0: float, t1: float) -> void:
	texture = load("res://assets/img/ingot.png")
	_from = from
	_to = to
	_t0 = t0
	_t1 = t1
	position = from

func note_time() -> float:
	return _t1

func forge(perfect: bool) -> void:
	_state = "done"
	texture = load("res://assets/img/blade.png")
	_vel = Vector2(150.0, -220.0) if perfect else Vector2(120.0, -140.0)
	if perfect:
		scale = Vector2(1.25, 1.25)

func drop() -> void:
	_state = "done"
	_vel = Vector2(40.0, 60.0)
	modulate = Color(0.6, 0.6, 0.7)

func _process(delta: float) -> void:
	match _state:
		"fly":
			var u := clampf((Conductor.song_time() - _t0) / maxf(_t1 - _t0, 0.001), 0.0, 1.0)
			position = Motion.arc_pos(_from, _to, u, ARC_HEIGHT)
		"done":
			_vel += Vector2(0.0, 500.0) * delta
			position += _vel * delta
			rotation += 6.0 * delta
			_life += delta
			if _life > 1.2:
				queue_free()
```

- [ ] **Step 3: ForgeScene 구현**

`games-src/beat-shift/src/forge_scene.gd`:
```gdscript
class_name ForgeScene
extends Node2D
## 대장간 장면 — 큐(잉곳 투척)와 판정 연출. 그루브가 높으면 화로가 살아난다.

const ANVIL_TOP := Vector2(150.0, 318.0)
const ASSIST_POS := Vector2(48.0, 310.0)
const SMITH_POS := Vector2(208.0, 302.0)
const FURNACE_POS := Vector2(62.0, 218.0)

var _smith: Sprite2D
var _assistant: Sprite2D
var _furnace: Sprite2D
var _sparks: CPUParticles2D
var _embers: CPUParticles2D
var _idle_tex: Texture2D
var _swing_tex: Texture2D
var _ingots: Array = []

func _ready() -> void:
	_build_backdrop()
	_furnace = Sprite2D.new()
	_furnace.texture = load("res://assets/img/furnace.png")
	_furnace.position = FURNACE_POS
	add_child(_furnace)
	_embers = CPUParticles2D.new()
	_embers.position = FURNACE_POS + Vector2(0, -20)
	_embers.amount = 12
	_embers.lifetime = 1.6
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2(0, -30)
	_embers.initial_velocity_min = 10.0
	_embers.initial_velocity_max = 30.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.0
	_embers.color = Color("#FFA300")
	add_child(_embers)
	var anvil := Sprite2D.new()
	anvil.texture = load("res://assets/img/anvil.png")
	anvil.position = ANVIL_TOP + Vector2(0, 14)
	add_child(anvil)
	_assistant = Sprite2D.new()
	_assistant.texture = load("res://assets/img/assistant.png")
	_assistant.position = ASSIST_POS
	add_child(_assistant)
	_idle_tex = load("res://assets/img/smith_idle.png")
	_swing_tex = load("res://assets/img/smith_swing.png")
	_smith = Sprite2D.new()
	_smith.texture = _idle_tex
	_smith.position = SMITH_POS
	add_child(_smith)
	_sparks = CPUParticles2D.new()
	_sparks.position = ANVIL_TOP
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 14
	_sparks.lifetime = 0.5
	_sparks.spread = 70.0
	_sparks.direction = Vector2(0, -1)
	_sparks.initial_velocity_min = 60.0
	_sparks.initial_velocity_max = 140.0
	_sparks.gravity = Vector2(0, 240)
	_sparks.color = Color("#FFEC27")
	add_child(_sparks)
	Conductor.beat.connect(_on_beat)

func _build_backdrop() -> void:
	var wall := ColorRect.new()
	wall.color = Color("#1D2B53")
	wall.position = Vector2(0, 150)
	wall.size = Vector2(Tuning.VIEW_W, 190)
	wall.z_index = -10
	add_child(wall)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color("#141127")
	floor_rect.position = Vector2(0, 340)
	floor_rect.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H - 340)
	floor_rect.z_index = -10
	add_child(floor_rect)

func _on_beat(_b: int) -> void:
	# 화로가 박자에 맞춰 맥동 — 장면 전체가 메트로놈
	_furnace.self_modulate = Color(1.35, 1.2, 1.0)
	var tw := create_tween()
	tw.tween_property(_furnace, "self_modulate", Color.WHITE, 0.18)

func spawn_cue(note_time: float, cue_time: float) -> void:
	var ing := Ingot.new()
	add_child(ing)
	ing.setup(ASSIST_POS + Vector2(10.0, -12.0), ANVIL_TOP + Vector2(0.0, -6.0), cue_time, note_time)
	_ingots.append(ing)
	_assistant.position = ASSIST_POS + Vector2(0, -6)
	var tw := create_tween()
	tw.tween_property(_assistant, "position", ASSIST_POS, 0.15)
	Sfx.play("precue", -8.0)

func ingot_count() -> int:
	return _ingots.size()

func clear_cues() -> void:
	for ing in _ingots:
		(ing as Ingot).queue_free()
	_ingots.clear()

func _take_ingot(note_time: float) -> Ingot:
	for i in range(_ingots.size()):
		var ing := _ingots[i] as Ingot
		if absf(ing.note_time() - note_time) < 0.001:
			_ingots.remove_at(i)
			return ing
	return null

func on_result(result: String, note_time: float) -> void:
	match result:
		"perfect", "good":
			_swing()
			var ing := _take_ingot(note_time)
			if ing:
				ing.forge(result == "perfect")
			_sparks.amount = 18 if result == "perfect" else 8
			_sparks.restart()
			_punch()
		"miss":
			var ing := _take_ingot(note_time)
			if ing:
				ing.drop()
		"stray":
			_swing()

func _swing() -> void:
	_smith.texture = _swing_tex
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: _smith.texture = _idle_tex)

func _punch() -> void:
	# 화면 미세 펀치 — 장면을 한 프레임 내려찍고 복귀
	position = Vector2(0, 3)
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2.ZERO, 0.1)

func set_heat(ratio: float) -> void:
	# 그루브 게이지가 곧 장면 연출 — 낮으면 화로가 식는다
	_embers.emitting = ratio > 0.25
	_furnace.modulate = Color.WHITE.lerp(Color(1.2, 1.05, 0.9), clampf(ratio, 0.0, 1.0))
```

- [ ] **Step 4: Hud 구현**

`games-src/beat-shift/src/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## 그루브 VU미터 + 콤보 배수. 숫자 최소주의 — 게이지가 곧 연출.

const SEGS := 10

var _blocks: Array = []
var _mult: Label
var _float: Label
var _float_tw: Tween

func _ready() -> void:
	for i in range(SEGS):
		var b := ColorRect.new()
		b.position = Vector2(10.0 + i * 15.0, 12.0)
		b.size = Vector2(11.0, 8.0)
		b.color = _seg_color(i)
		add_child(b)
		_blocks.append(b)
	_mult = _make_label(12, Vector2(228, 8), Color("#FFEC27"))
	_float = _make_label(10, Vector2(60, 34), Color("#FFA300"))
	_float.modulate.a = 0.0

func _make_label(size: int, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri9.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.position = pos
	add_child(l)
	return l

func _seg_color(i: int) -> Color:
	if i < 3:
		return Color("#FF004D")
	if i < 7:
		return Color("#FFA300")
	return Color("#FFEC27")

func set_groove(ratio: float) -> void:
	var lit := int(ceilf(clampf(ratio, 0.0, 1.0) * SEGS))
	for i in range(SEGS):
		(_blocks[i] as ColorRect).modulate.a = 1.0 if i < lit else 0.15

func set_mult(m: int) -> void:
	_mult.text = "x%d" % m if m > 1 else ""

func flash(text: String) -> void:
	_float.text = text
	_float.modulate.a = 1.0
	if _float_tw:
		_float_tw.kill()
	_float_tw = create_tween()
	_float_tw.tween_property(_float, "modulate:a", 0.0, 0.9).set_delay(0.5)
```

- [ ] **Step 5: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\beat-shift\src games-src\beat-shift\tests\test_forge_scene.gd
git commit -m "feat(beatshift): forge scene with conductor-driven ingot arcs, VU-meter HUD"
```

---

### Task 9: Main 배선 + Overlay — 세션 흐름 완성

**Files:**
- Create: `games-src/beat-shift/src/overlay.gd`
- Modify: `games-src/beat-shift/src/main.gd` (스텁 → 본 구현)

**Interfaces:**
- Consumes: Task 2~8의 전 API (`Conductor`, `NoteJudge`, `Patterns`, `GameState`, `ForgeScene`, `Hud`, `Sfx`, `ConductorMath`, `Tuning`)
- Produces: 완결된 세션 루프 — 타이틀("TAP TO GROOVE") → 인트로 1마디 → 패턴 8마디 → 징글 1마디("TEMPO UP") → 다음 섹션(BPM 상승) → … → 그루브 0 게임오버(슬로모 0.5s) → SCORE/BEST → 탭 즉시 재시작. 포커스 아웃 시 일시정지, 재개는 **현재 마디 처음부터**(스펙 §8)

- [ ] **Step 1: Overlay 구현**

`games-src/beat-shift/src/overlay.gd`:
```gdscript
class_name Overlay
extends CanvasLayer
## 타이틀/게임오버/일시정지 오버레이. 일시정지 중에도 입력을 받도록 ALWAYS.

var _lines: Array = []
var _emblem: Sprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_emblem = Sprite2D.new()
	_emblem.texture = load("res://assets/img/emblem.png")
	_emblem.position = Vector2(Tuning.VIEW_W / 2.0, 120.0)
	_emblem.scale = Vector2(2, 2)
	add_child(_emblem)

func _label(text: String, y: float, size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri11.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(Tuning.VIEW_W, 30)
	l.position = Vector2(0, y)
	add_child(l)
	_lines.append(l)
	return l

func clear() -> void:
	for l in _lines:
		(l as Label).queue_free()
	_lines.clear()
	_emblem.visible = false
	visible = false

func show_title() -> void:
	clear()
	visible = true
	_emblem.visible = true
	_label("BEAT SHIFT", 170, 22, Color("#FFEC27"))
	_label("TAP TO GROOVE", 220, 11, Color("#FFF1E8"))

func show_game_over(score: int, best: int, new_best: bool) -> void:
	clear()
	visible = true
	_label("SCORE  %d" % score, 160, 16, Color("#FFF1E8"))
	_label("BEST   %d" % best, 190, 16, Color("#FFEC27" if new_best else "#FFA300"))
	if new_best:
		_label("NEW RECORD!", 220, 11, Color("#FF77A8"))
	_label("TAP TO RETRY", 260, 11, Color("#FFF1E8"))

func show_paused() -> void:
	clear()
	visible = true
	_label("PAUSED", 200, 16, Color("#FFF1E8"))
	_label("TAP TO RESUME", 230, 11, Color("#FFA300"))
```

- [ ] **Step 2: Main 구현**

`games-src/beat-shift/src/main.gd` (스텁 교체):
```gdscript
extends Node2D
## 세션 상태 머신 + 리듬 판정 루프. 박자의 진실은 Conductor.

var scene_stage: ForgeScene
var hud: Hud
var overlay: Overlay
var rng := RandomNumberGenerator.new()

var section := 0
var judge: NoteJudge
var _note_times: Array = []
var _cue_cursor := 0.0
var _jingle_done := false
var _anvil_idx := 0
var _paused := false
var _dying := false

func _ready() -> void:
	rng.randomize()
	scene_stage = ForgeScene.new()
	add_child(scene_stage)
	hud = Hud.new()
	add_child(hud)
	overlay = Overlay.new()
	add_child(overlay)
	if GameState.quick_restart:
		GameState.quick_restart = false
		_begin_run()
	else:
		GameState.phase = GameState.Phase.TITLE
		overlay.show_title()

func _begin_run() -> void:
	overlay.clear()
	GameState.start_run()
	section = 0
	_anvil_idx = 0
	_start_section()

func _start_section() -> void:
	Conductor.start_section(section)
	var beats := Patterns.section_notes(Patterns.tier_for_section(section), rng)
	_note_times = []
	for b in beats:
		_note_times.append(ConductorMath.time_from_beats(Tuning.INTRO_BEATS + float(b), Conductor.bpm))
	judge = NoteJudge.new(_note_times, Tuning.PERFECT_WIN, Tuning.GOOD_WIN)
	_cue_cursor = 0.0
	_jingle_done = false

func _process(_delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING or _paused:
		return
	var t := Conductor.song_time()
	for m in judge.advance(t):
		GameState.register_fail("miss")
		scene_stage.on_result("miss", m)
		Sfx.play("miss")
	if GameState.is_dead():
		_game_over()
		return
	var lead := ConductorMath.time_from_beats(Tuning.CUE_LEAD_BEATS, Conductor.bpm)
	for nt in ConductorMath.due_cues(_note_times, _cue_cursor, t, lead):
		scene_stage.spawn_cue(nt, float(nt) - lead)
	_cue_cursor = t
	var beats := Conductor.song_beats()
	if not _jingle_done and beats >= Tuning.INTRO_BEATS + Tuning.NOTE_BEATS:
		_jingle_done = true
		var bonus := GameState.register_section_clear(section)
		Sfx.play("jingle")
		hud.flash("TEMPO UP  +%d" % bonus)
	if beats >= Tuning.SECTION_BEATS:
		section += 1
		_start_section()
	hud.set_groove(GameState.groove / Tuning.GROOVE_MAX)
	hud.set_mult(GameState.mult)
	scene_stage.set_heat(GameState.groove / Tuning.GROOVE_MAX)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("tap"):
		return
	if _paused:
		_resume()
		return
	match GameState.phase:
		GameState.Phase.TITLE:
			_begin_run()
		GameState.Phase.PLAYING:
			_on_tap()
		GameState.Phase.GAME_OVER:
			if not _dying:
				GameState.quick_restart = true
				get_tree().reload_current_scene()

func _on_tap() -> void:
	var r := judge.on_tap(Conductor.song_time() + Tuning.INPUT_OFFSET)
	match r.result:
		"perfect", "good":
			GameState.register_hit(r.result)
			scene_stage.on_result(r.result, r.note_time)
			if r.result == "perfect":
				Sfx.play("anvil_%d" % (_anvil_idx % 4 + 1))
				_anvil_idx += 1
			else:
				Sfx.play("good")
		"stray":
			GameState.register_fail("stray")
			scene_stage.on_result("stray", -1.0)
			Sfx.play("whiff")
	if GameState.is_dead():
		_game_over()

func _game_over() -> void:
	_dying = true
	var was_best := GameState.best
	GameState.end_run()
	Conductor.stop()
	scene_stage.clear_cues()
	Sfx.play("gameover")
	Engine.time_scale = Tuning.DEATH_SLOWMO
	var timer := get_tree().create_timer(Tuning.DEATH_SLOWMO_SEC * Tuning.DEATH_SLOWMO, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_dying = false
		overlay.show_game_over(GameState.score(), GameState.best, GameState.best > was_best)
	)

func _resume() -> void:
	# 박자 어긋남 방지 — 현재 마디 처음부터 다시 (루프 = 1마디라 시킹 불필요)
	_paused = false
	overlay.clear()
	var bar := int(floor(Conductor.song_beats() / float(Tuning.BEATS_PER_BAR)))
	var bar_start := ConductorMath.time_from_beats(float(bar * Tuning.BEATS_PER_BAR), Conductor.bpm)
	scene_stage.clear_cues()
	judge = NoteJudge.new(judge.remaining_after(bar_start), Tuning.PERFECT_WIN, Tuning.GOOD_WIN)
	_cue_cursor = bar_start
	Conductor.resume_at_bar(bar)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _paused:
		_paused = true
		Conductor.stop()
		overlay.show_paused()
```

- [ ] **Step 3: 헤드리스 스모크 + 회귀 테스트**

```powershell
& $GODOT --headless --path games-src\beat-shift --quit-after 240
Set-Location games-src\beat-shift
& $GODOT --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
Set-Location ..\..
```
Expected: 스모크 exit 0(240프레임 타이틀 구동), gdUnit 전부 passed.

- [ ] **Step 4: 수동 확인 (에디터 실행)**

```powershell
& "C:\Users\LeeDoik\tools\godot\godot.exe" --path games-src\beat-shift
```
수동 확인 항목:
- 타이틀 → 탭 → 인트로 1마디(비트만) → 잉곳이 날아오고 정박에 모루 도착
- 정박 탭 = 벨 멜로디(C→D→E→G 순환) + 불티, 놓치면 잉곳 낙하 + 게이지 하락
- 8마디 후 "TEMPO UP" + 징글 → 다음 섹션 BPM 상승 체감
- 게이지 0 → 슬로모 → SCORE/BEST → 탭 즉시 재시작
- 창 포커스 아웃 → PAUSED → 탭 재개 시 현재 마디 처음부터, 박자 일치

- [ ] **Step 5: Commit**

```powershell
git add games-src\beat-shift\src
git commit -m "feat(beatshift): session flow - sections, tempo up, game over, bar-accurate pause"
```

---

### Task 10: 웹 익스포트 + 카트리지 등록(hidden) + 사이트 검증

**Files:**
- Create: `games-src/beat-shift/export_presets.cfg`, `games-src/beat-shift/web/shell.html`, `public/games/beat-shift/*`(익스포트 산출물), `content/games/04-beat-shift.json`, `docs/superpowers/specs/beat-shift-playtest.md`
- Modify: `src/lib/scenes.ts`(coverScene `beatshift` 추가)

**Interfaces:**
- Consumes: 게임 레코드 스키마 `src/lib/games.ts`(coverScene은 `COVER_SCENES` 멤버여야 검증 통과), `src/lib/scenes.test.ts`(신규 씬도 자동 순회 검증)
- Produces: 브라우저에서 플레이되는 BEAT SHIFT 카트리지 — `hidden: true`로 등록(공개 라인업 제외, `/play/beat-shift` 라우트는 동작)

- [ ] **Step 1: 커스텀 셸**

```powershell
New-Item -ItemType Directory -Force games-src\beat-shift\web
Copy-Item games-src\starfall-drift\web\shell.html games-src\beat-shift\web\shell.html
```
`games-src/beat-shift/web/shell.html` 수정 — 2곳:
1. boot-text div 내용 교체 (PIXELARIOUS 브랜딩 유지):
```html
	<div id="boot-text">PIXELARIOUS ARCADE SYSTEM
CARTRIDGE: BEAT SHIFT
SYNCING METRONOME ...</div>
```
2. CSS의 액센트 색 `#29ADFF`가 있으면 전부 `#FFA300`으로 교체 (배경 `#0C0A1C`·progress `#FFEC27`은 유지). `$GODOT_CONFIG` 등 플레이스홀더는 삭제·개명 금지.

- [ ] **Step 2: export_presets.cfg**

`games-src/beat-shift/export_presets.cfg`:
```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="addons/gdUnit4/*"
export_path="../../public/games/beat-shift/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/export_icon=true
html/custom_html_shell="res://web/shell.html"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
```

- [ ] **Step 3: 부트 스모크 후 익스포트 실행**

```powershell
& $GODOT --headless --path games-src\beat-shift --quit-after 240
New-Item -ItemType Directory -Force public\games\beat-shift
& $GODOT --headless --path games-src\beat-shift --export-release "Web" "../../public/games/beat-shift/index.html"
Get-ChildItem public\games\beat-shift | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
git status --short games-src\beat-shift
```
Expected: index.html/.js/.wasm/.pck 생성, 전 파일 100MB 미만. `.import` 파일이 줄바꿈만 바뀌어 modified로 뜨면 `git checkout -- games-src/beat-shift/assets games-src/beat-shift/addons`.

- [ ] **Step 4: scenes.ts에 beatshift 커버 씬 추가**

`src/lib/scenes.ts` 수정 — 4곳:

1행·2행 교체:
```ts
export type CoverScene = 'starfall' | 'cave' | 'pong' | 'system' | 'lastlogin' | 'beatshift'
export const COVER_SCENES: CoverScene[] = ['starfall', 'cave', 'pong', 'system', 'lastlogin', 'beatshift']
```

`PALETTES.night`의 `lastlogin` 줄 다음에 추가:
```ts
    beatshift: { sky: '#0C0A1C', far: '#1D2B53', star: '#8E99D9', hi: '#FFEC27', obj: '#FF77A8', obj2: '#29ADFF' },
```
`PALETTES.dmg`의 `lastlogin` 줄 다음에 추가:
```ts
    beatshift: { sky: '#081820', far: '#346856', star: '#88C070', hi: '#E0F8D0', obj: '#88C070', obj2: '#E0F8D0' },
```

`SEEDS` 교체:
```ts
const SEEDS: Record<CoverScene, number> = { starfall: 7, cave: 23, pong: 41, system: 77, lastlogin: 59, beatshift: 91 }
```

`drawScene`의 `lastlogin` 블록 다음에 추가:
```ts
  if (scene === 'beatshift') {
    // 대장간 — 모루 위 망치, 박자 불티와 음표
    for (let i = 0; i < 18; i++) px((r() * W) | 0, (r() * (H - 14)) | 0, 1, 1, p.star)
    px(0, H - 5, W, 5, p.far)
    px(40, H - 16, 24, 4, p.star)
    px(46, H - 12, 12, 7, p.far)
    px(60, 10, 3, 12, p.obj)
    px(55, 6, 13, 6, p.star)
    for (let i = 0; i < 8; i++) px(44 + ((r() * 20) | 0), H - 24 + ((r() * 8) | 0), 1, 1, p.hi)
    px(20, 10, 2, 5, p.obj2)
    px(18, 13, 3, 3, p.obj2)
    px(80, 16, 2, 4, p.obj2)
    px(78, 18, 3, 3, p.obj2)
  }
```

- [ ] **Step 5: 카트리지 레코드 생성**

`content/games/04-beat-shift.json`:
```json
{
  "slug": "beat-shift",
  "order": 50,
  "title": "BEAT SHIFT",
  "description": "픽셀 장면이 곧 악보인 원버튼 리듬 아케이드.\n조수가 던진 쇳덩이가 모루에 닿는 순간, 탭 — 성공음이 멜로디를 완성합니다.\n템포는 계속 빨라집니다. 그루브가 꺼지기 전까지.",
  "tags": [
    "GODOT 4",
    "2D",
    "RHYTHM",
    "ONE BUTTON",
    "MOBILE OK"
  ],
  "coverScene": "beatshift",
  "playPath": "/games/beat-shift/index.html",
  "hidden": true
}
```

- [ ] **Step 6: 사이트 통합 검증**

```powershell
npm test
npm run build
```
Expected: vitest 전부 PASS(scenes.test.ts가 beatshift를 자동 순회 — night/dmg 색상·5회 이상 드로우·결정론 검증, games.ts가 playPath 실재 검증), 빌드 성공.

이어서 브라우저 확인 — **포트 3000 stale 검사 먼저**(Global Constraints):
```powershell
npm run dev
# 다른 셸에서:
curl -s -o /dev/null -w "%{size_download}" http://localhost:3000/games/beat-shift/index.pck
Get-Item public\games\beat-shift\index.pck | Select-Object Length
```
두 값이 같아야 함. 다르면 `npm run dev -- -p 3100`으로 재시작 후 그 포트 사용. `/play/beat-shift`에서 게임 로드·타이틀 탭·판정·사운드 확인. 브라우저 개발자 도구 모바일 에뮬레이션(iPhone/Galaxy)에서 터치 탭·세로 레이아웃 확인.

- [ ] **Step 7: 플레이테스트 체크리스트 작성**

`docs/superpowers/specs/beat-shift-playtest.md`:
```markdown
# BEAT SHIFT 플레이테스트 체크리스트 (1단계 — 대장간)

## 판정·싱크 (최우선)
- [ ] 데스크톱: 정박 탭이 PERFECT로 판정되는가 (체감 억울함 없음)
- [ ] 모바일 실기: 동일 — 밀린다면 Tuning.INPUT_OFFSET 조정값 메모: ___
- [ ] 잉곳 도착 시점과 비트가 시청각적으로 일치
- [ ] 예비음(2박 전)과 잉곳 투척이 항상 함께 옴

## 조작·루프
- [ ] 타이틀 첫 탭에 바로 시작, 인트로 1마디 안에 규칙 이해
- [ ] 성공음 벨 멜로디가 "음악을 완성하는" 느낌
- [ ] 사망 → 재시작 2초 이내
- [ ] 포커스 아웃 → PAUSED → 재개 시 현재 마디부터, 박자 일치

## 밸런스 (tuning.gd로 조정)
- [ ] 첫 섹션(96BPM, tier 0) 사망률 낮음
- [ ] 평균 런 길이 30초–2분 사이 (측정값: ___)
- [ ] TEMPO UP 후 난이도 상승이 체감되되 절벽이 아님
- [ ] 연타(스팸)로 이득 못 봄 — 헛스윙 페널티 체감: ___
- [ ] 그루브 회복(+10)이 "살아났다" 느낌을 주는가

## 모바일 (실기)
- [ ] Android Chrome: 로드·터치·오디오 지연 (기기: ___)
- [ ] iOS Safari: 로드·터치·오디오 재생 (기기: ___)
- [ ] 세로 화면비에서 UI 잘림 없음
- [ ] 베스트 스코어가 새로고침 후 유지

## 데스크톱
- [ ] 크롬/파이어폭스: 로드·플레이 정상
- [ ] 창 리사이즈 시 세로 캔버스 유지(expand)
```

- [ ] **Step 8: Commit**

```powershell
git add games-src\beat-shift\export_presets.cfg games-src\beat-shift\web public\games\beat-shift content\games\04-beat-shift.json src\lib\scenes.ts docs\superpowers\specs\beat-shift-playtest.md
git commit -m "feat(beatshift): web export, beatshift cover scene, hidden cartridge registration"
```

---

### Task 11: 플레이테스트·튜닝 패스

**Files:**
- Modify: `games-src/beat-shift/src/core/tuning.gd`(튜닝 결과), `docs/superpowers/specs/beat-shift-playtest.md`(체크 기록), `public/games/beat-shift/*`(재익스포트)

**Interfaces:**
- Consumes: Task 10의 체크리스트
- Produces: 판정 싱크·밸런스가 조정된 1단계 완성본 (hidden 유지 — 공개는 2~4단계 후 별도 결정)

- [ ] **Step 1: 플레이테스트 수행** — 체크리스트를 위에서부터 실행하며 파일에 체크 기록. 모바일 실기 항목은 사용자에게 로컬 네트워크 URL(`npm run dev` 후 `http://<PC IP>:<포트>/play/beat-shift`)로 요청. **판정 싱크 항목이 최우선** — 모바일에서 일관되게 늦으면 `Tuning.INPUT_OFFSET`을 음수(예: -0.04)로 조정.

- [ ] **Step 2: 튜닝 반영** — 수치는 `tuning.gd` 상수만 수정 → runtest 재실행(게이지·스코어 테스트가 상수 기반이라 함께 갱신 필요할 수 있음 — 스펙 §3~§5 수치도 동수 갱신) → 재익스포트(Task 10 Step 3 커맨드) → 재확인.

- [ ] **Step 3: 최종 검증**

```powershell
Set-Location games-src\beat-shift
& $GODOT --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
Set-Location ..\..
npm test
npm run build
```
Expected: 전부 PASS.

- [ ] **Step 4: 커밋 + 다음 단계 안내**

```powershell
git add -A -- games-src\beat-shift public\games\beat-shift docs\superpowers\specs\beat-shift-playtest.md
git commit -m "feat(beatshift): playtest tuning pass"
```
브랜치(`LeeDoik/new_snack_game`) → master 병합/PR은 사용자 확인 후 진행. 2단계(포장마차 장면 추가)는 별도 플랜으로.

---

## Self-Review 기록

- **스펙 커버리지**: §1 컨셉·§2 큐 문법(Task 8 잉곳 아크 + 2박 예비 = Task 2 `due_cues`·`CUE_LEAD_BEATS`), §3 코어 루프(판정창 Task 2·3, 섹션/템포 Task 6·9, 8마디+징글 구조 Task 9), §4 그루브(Task 5 + HUD VU미터 Task 8 + `set_heat` 연출), §5 스코어링(Task 5, 콤보 ×5 상한·섹션 보너스·베스트 영속), §6 미니멀 퍼커션(Task 6 — 루프 5종 + 벨 멜로디 성공음), §7 컨덕터·순수 함수 분리·INPUT_OFFSET(Task 2·6), §8 세션 흐름·마디 단위 재개(Task 9), §9 비주얼(Task 7·8, 팔레트·뷰포트는 Task 1), §10 아키텍처(Task 1 스캐폴드·10 익스포트/등록), §11 1단계 범위 준수(장면 1개·전환 시스템은 섹션 경계 징글로 한정), §12 테스트(각 태스크 TDD + 10·11), §13 성공 기준(Task 10–11), §14 YAGNI 준수(캘리브레이션 화면 없음 — INPUT_OFFSET 상수만).
- **스펙 §3 대비 조정 1건**: 섹션 앞 인트로 1마디 추가(첫 노트의 2박 예비 큐 성립을 위해). 스펙의 "장면 전환 시 +10 회복"은 1단계에서 "섹션 클리어 시 +10"으로 대응(장면이 1개이므로 동일 지점).
- **타입 일관성**: `NoteJudge.on_tap` 반환 `{"result","note_time"}`(Task 3 정의 ↔ 9 사용), `ForgeScene.spawn_cue(note_time, cue_time)/on_result/set_heat/clear_cues/ingot_count`(Task 8 정의 ↔ 9 사용), `Conductor.start_section/resume_at_bar/song_time/song_beats/bpm`(Task 6 정의 ↔ 8·9 사용), `GameState.register_hit/register_fail/register_section_clear/is_dead/mult/groove`(Task 5 정의 ↔ 9 사용), `Patterns.section_notes` 반환은 비트 배열이고 초 변환·인트로 오프셋은 Main이 담당(Task 4 명시 ↔ 9 구현) 확인.
- **알려진 주의점**: PixelLab 응답 스키마는 기존 `scripts/gen_pixellab.py`가 검증된 정본 — 다르면 그쪽을 따른다(Task 7). gdUnit에서 오디오 재생 위치 전진에 의존하는 단언 금지 — Conductor 테스트는 상태·클램프만 검증(Task 6). 헤드리스에서 `_process` 자동 구동에 의존하지 않도록 판정 로직은 `NoteJudge` 수동 호출로 테스트(Task 3).
