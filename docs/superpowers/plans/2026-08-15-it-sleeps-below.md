# IT SLEEPS BELOW Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 왕복 채굴 로그라이크 코즈믹 호러 IT SLEEPS BELOW를 Godot 4.7로 만들어 웹 익스포트하고 NEO_KIDO 카트리지로 등록한다 (모바일 터치 필수, 서사 텍스트 KO/EN 토글 + 로컬 텍스트 에디터).

**Architecture:** 물리 엔진 없는 그리드 게임 — 월드 생성·이코노미·램프·러커 AI·이상 현상·피날레 뒤틀림을 순수 static 함수(`WorldGen`, `Economy`, `Oil`, `LurkerLogic`, `AnomalyPool`, `Lore`, `Finale`)로 분리해 gdUnit4로 헤드리스 단위 테스트한다. 씬 파일은 `main.tscn` 하나, 모든 노드 트리는 코드로 구성(STARFALL 관례 — 과거 tscn 수기 작성으로 히트테스트 버그를 겪음). 아트는 PixelLab API, 오디오는 VARCO Sound API(text2sound + looping), 서사 텍스트는 게임 팩 외부 JSON(런타임 로드) + 사이트 `/editor` 확장으로 편집.

**Tech Stack:** Godot 4.7.1 Standard(GDScript), gdUnit4, Python 3(에셋/오디오 생성), PixelLab API, VARCO Sound API, ffmpeg(ogg 인코딩), 기존 Next.js 사이트(레코드 등록 + 텍스트 에디터).

**스펙:** `docs/superpowers/specs/2026-08-15-down-the-cave-design.md` — 수치·규칙의 원본. 충돌 시 스펙이 우선. (파일명은 구 가제이나 내용은 IT SLEEPS BELOW 확정본)

## Global Constraints

- Godot 실행 파일(전 태스크 공통): `$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"` (4.7.1.stable, 웹 익스포트 템플릿 설치됨)
- 게임 프로젝트 루트: `games-src/it-sleeps-below/`
- gdUnit4 테스트 실행(프로젝트 디렉토리에서): 첫 실행 또는 `.godot/` 삭제 후엔 반드시 캐시 프라이밍 후 실행:
  ```powershell
  $GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
  Set-Location "games-src\it-sleeps-below"
  & $GODOT --headless --editor --path . --quit
  $env:GODOT_BIN = $GODOT
  cmd /c "addons\gdUnit4\runtest.cmd -a tests"
  ```
  Expected: 0 errors / 0 failures, exit 0. 이하 각 태스크의 "runtest"는 이 명령을 뜻한다.
- 뷰포트 270×480 (9:16 세로), `canvas_items` 스트레치 + `expand`, `gl_compatibility`, 텍스처 필터 nearest
- 타일 16px, 월드 폭 16타일(x 0..15, 양끝은 경계석), 1타일 = 1m, 최심부 400m
- 튜닝 수치는 전부 `src/core/tuning.gd` 상수로만 존재 (매직 넘버 금지). 스펙 §2~§10의 시작값 사용
- 팔레트(NIGHT 계열에서 출발): 하늘 `#0C0A1C`, 표토 갈색 `#8A5A44`/`#5C3A2E`, 암반 `#4A4E6D`/`#1D2B53`, 균열대 `#3A2E4A`, 심층 검붉음 `#4A1E2E`/발광 `#FF77A8`, 텍스트 `#FFF1E8`, 골드 `#FFEC27`
- 서사 텍스트는 코드에 넣지 않는다 — `public/games/it-sleeps-below/text/text.json`(ko/en 키 쌍)이 단일 소스. 웹 빌드는 상대 경로 HTTPRequest, 에디터 실행은 `ProjectSettings.globalize_path("res://") + "../../public/games/it-sleeps-below/text/text.json"`을 FileAccess로 읽는다
- API 키: 리포 루트 `.env.local`의 `PIXELLAB_API_KEY`, `VARCO_API_KEY` (절대 커밋 금지 — .gitignore 등록됨)
- VARCO Sound API: `POST https://openapi.ai.nc.com/sound/varco/v1/api/text2sound` body `{"prompt": str, "num_sample": 1..5}`, `POST .../api/looping` body `{"source": base64wav}` — 둘 다 헤더 `OPENAPI_KEY: <키>`, 응답의 `audio` 필드가 base64 WAV(44.1kHz/16bit, text2sound는 10초 고정)
- GDScript 들여쓰기는 탭. 커밋 메시지는 기존 관례(`feat(isb): ...` 형식, isb = it-sleeps-below 축약) 따름
- 웹 익스포트: Web 프리셋, 스레드 비활성화, `exclude_filter="addons/gdUnit4/*,tests/*"` (STARFALL 팔로업 반영 — pck에 tests 포함 금지)
- `starfall-drift` 브랜치의 미커밋 STARFALL 파일들(git status의 M 파일)은 건드리지도, git add 하지도 않는다

---

### Task 1: 스캐폴드 + 테스트 하네스

**Files:**
- Create: `games-src/it-sleeps-below/project.godot`, `icon.svg`, `src/main.tscn`, `src/main.gd`(스텁), `src/core/game_state.gd`(스텁), `src/core/sfx.gd`(스텁), `tests/test_harness.gd`, `CREDITS.md`
- Copy: `games-src/starfall-drift/addons/gdUnit4/` → `games-src/it-sleeps-below/addons/gdUnit4/`, `games-src/starfall-drift/assets/fonts/Galmuri9.ttf`·`Galmuri11.ttf` → `games-src/it-sleeps-below/assets/fonts/`, `games-src/starfall-drift/icon.svg` → 동일 경로 (임시 아이콘)

**Interfaces:**
- Produces: 부팅 가능한 Godot 프로젝트 + gdUnit4 하네스. 오토로드 `GameState`(`src/core/game_state.gd`), `Sfx`(`src/core/sfx.gd`)

- [ ] **Step 1: 디렉토리·복사**

```powershell
New-Item -ItemType Directory -Force "games-src\it-sleeps-below\src\core","games-src\it-sleeps-below\tests","games-src\it-sleeps-below\assets\fonts","games-src\it-sleeps-below\assets\img","games-src\it-sleeps-below\assets\sfx","games-src\it-sleeps-below\web"
Copy-Item -Recurse "games-src\starfall-drift\addons" "games-src\it-sleeps-below\addons"
Copy-Item "games-src\starfall-drift\assets\fonts\*" "games-src\it-sleeps-below\assets\fonts\"
Copy-Item "games-src\starfall-drift\icon.svg" "games-src\it-sleeps-below\icon.svg"
Copy-Item "games-src\starfall-drift\web\shell.html" "games-src\it-sleeps-below\web\shell.html"
```
(폰트가 없으면 `games-src/last-login/assets/fonts/`에서 복사)

- [ ] **Step 2: project.godot 작성**

`games-src/it-sleeps-below/project.godot`:
```ini
; Engine configuration file.
config_version=5

[application]
config/name="IT SLEEPS BELOW"
run/main_scene="res://src/main.tscn"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"

[autoload]
GameState="*res://src/core/game_state.gd"
Sfx="*res://src/core/sfx.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")

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
environment/defaults/default_clear_color=Color(0.0471, 0.0392, 0.1098, 1)
```

- [ ] **Step 3: 스텁·씬·하네스 작성**

`src/main.gd`:
```gdscript
extends Node2D
```
`src/core/game_state.gd`:
```gdscript
extends Node
```
`src/core/sfx.gd`:
```gdscript
extends Node
```
`src/main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```
`tests/test_harness.gd`:
```gdscript
extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_bool(true).is_true()
```
`CREDITS.md`:
```markdown
# IT SLEEPS BELOW — Credits

- 개발: LeeDoik (NEO_KIDO)
- 아트: PixelLab 생성 후 수작업 보정
- 사운드: VARCO Sound(NC AI) 생성 — 라이선스 조건 확인 후 이 줄을 갱신할 것
- 폰트: Galmuri (SIL OFL)
```

- [ ] **Step 4: .gitignore 확인**

리포 루트 `.gitignore`에 `games-src/*/.godot/`, `games-src/*/reports/`가 이미 있는지 확인. 없으면 추가.

- [ ] **Step 5: runtest — 하네스 통과 확인**

Global Constraints의 runtest 명령 실행. Expected: 1 test, 0 failures.

- [ ] **Step 6: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): scaffold IT SLEEPS BELOW project with gdUnit4 harness"
```

---

### Task 2: Tuning + WorldGen (시드 절차 생성)

**Files:**
- Create: `games-src/it-sleeps-below/src/core/tuning.gd`, `src/core/worldgen.gd`
- Test: `tests/test_worldgen.gd`

**Interfaces:**
- Produces (후속 태스크가 의존하는 시그니처):
  - `Tuning` — 모든 상수 (아래 코드 그대로)
  - `WorldGen.W: int = 16`, `WorldGen.DEPTH: int = 401`
  - 타일 코드 상수: `T_EMPTY=0, T_DIRT=1, T_ROCK=2, T_CRACK=3, T_DEEP=4, T_FLESH=5, T_BORDER=6, T_OIL=7, T_JOURNAL=8, T_RELIC=9, T_HEART=10`, 광석 = `ORE_BASE(100) + ore_id(0..6)`
  - `WorldGen.idx(x: int, y: int) -> int` (= y * W + x)
  - `WorldGen.strata_of(row: int) -> int` (0 표토 / 1 암반 / 2 균열대 / 3 심층 / 4 최심부)
  - `WorldGen.generate(seed: int, ctx: Dictionary) -> Dictionary` — ctx = `{"journals_found": Array[String], "relic": {"row": int, "items": Array} 또는 {}}`, 반환 = `{"cells": PackedInt32Array, "journal_spots": [{"id": String, "x": int, "y": int}], "relic_spot": {"x","y"} 또는 {}}`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_worldgen.gd`:
```gdscript
extends GdUnitTestSuite

func _gen(seed_v: int) -> Dictionary:
	return WorldGen.generate(seed_v, {"journals_found": [], "relic": {}})

func test_same_seed_same_world() -> void:
	assert_that(_gen(42).cells).is_equal(_gen(42).cells)

func test_different_seed_differs() -> void:
	assert_bool(_gen(1).cells == _gen(2).cells).is_false()

func test_borders_and_surface() -> void:
	var cells: PackedInt32Array = _gen(7).cells
	for y in range(WorldGen.DEPTH):
		assert_int(cells[WorldGen.idx(0, y)]).is_equal(WorldGen.T_BORDER)
		assert_int(cells[WorldGen.idx(WorldGen.W - 1, y)]).is_equal(WorldGen.T_BORDER)
	for x in range(1, WorldGen.W - 1):
		assert_int(cells[WorldGen.idx(x, 0)]).is_equal(WorldGen.T_EMPTY)

func test_strata_of() -> void:
	assert_int(WorldGen.strata_of(10)).is_equal(0)
	assert_int(WorldGen.strata_of(80)).is_equal(1)
	assert_int(WorldGen.strata_of(200)).is_equal(2)
	assert_int(WorldGen.strata_of(300)).is_equal(3)
	assert_int(WorldGen.strata_of(400)).is_equal(4)

func test_strata_base_tiles() -> void:
	var cells: PackedInt32Array = _gen(7).cells
	var fam := {0: WorldGen.T_DIRT, 1: WorldGen.T_ROCK, 2: WorldGen.T_DEEP, 3: WorldGen.T_FLESH}
	for row in [20, 80, 180, 320]:
		var base_count := 0
		for x in range(1, WorldGen.W - 1):
			var c: int = cells[WorldGen.idx(x, row)]
			if c == fam[WorldGen.strata_of(row)]:
				base_count += 1
		assert_int(base_count).is_greater(5)  # 행의 과반은 지층 기본 타일

func test_ore_depth_gating() -> void:
	var cells: PackedInt32Array = _gen(11).cells
	for y in range(1, 40):
		for x in range(1, WorldGen.W - 1):
			var c: int = cells[WorldGen.idx(x, y)]
			if c >= WorldGen.ORE_BASE:
				assert_int(c - WorldGen.ORE_BASE).is_less_equal(1)  # 표토엔 석탄(0)/구리(1)만

func test_heart_chamber() -> void:
	var cells: PackedInt32Array = _gen(3).cells
	var found_heart := false
	for x in range(1, WorldGen.W - 1):
		if cells[WorldGen.idx(x, 400)] == WorldGen.T_HEART:
			found_heart = true
	assert_bool(found_heart).is_true()

func test_journal_spots_follow_series_order() -> void:
	var g := _gen(5)
	assert_int(g.journal_spots.size()).is_greater(0)
	var first: Dictionary = g.journal_spots[0]
	assert_str(first.id).is_equal(Lore.series()[0].id)
	# 이미 주운 일지는 배치되지 않는다
	var g2: Dictionary = WorldGen.generate(5, {"journals_found": [first.id], "relic": {}})
	for s in g2.journal_spots:
		assert_str(s.id).is_not_equal(first.id)

func test_relic_placement() -> void:
	var g: Dictionary = WorldGen.generate(9, {"journals_found": [], "relic": {"row": 150, "items": [2, 2, 3]}})
	assert_bool(g.relic_spot.has("x")).is_true()
	assert_int(abs(int(g.relic_spot.y) - 150)).is_less_equal(Tuning.RELIC_ROW_JITTER)
```

주의: `Lore`는 Task 5에서 구현된다. 이 테스트 파일을 지금 작성하되, Step 2 실패 확인 시 `Lore` 미정의 파스 에러가 함께 나는 것이 정상. Task 5 완료 전까지는 `test_journal_spots_follow_series_order`를 `func skip_test_...`로 이름 바꿔 비활성화해 두고, Task 5의 마지막 스텝에서 되살린다.

- [ ] **Step 2: runtest — 실패 확인**

Expected: `WorldGen`/`Tuning` 미정의로 FAIL (하네스 1개만 통과).

- [ ] **Step 3: tuning.gd 작성**

`src/core/tuning.gd`:
```gdscript
class_name Tuning
## 모든 게임플레이 시작값. 스펙 §2~§10. 플레이테스트에서 이 파일만 만진다.

# ── 월드 ──
const TILE_PX := 16
const STRATA_BOUNDS := [40, 120, 240, 400]  # 표토<40 ≤암반<120 ≤균열대<240 ≤심층<400, 400=최심부
const RELIC_ROW_JITTER := 3

# ── 이동/채굴 (초 단위, 타일당) ──
const WALK_TIME := 0.15
const CLIMB_TIME := 0.35
const FALL_TIME := 0.07
const DIG_TIME_BASE := [0.35, 0.55, 0.8, 1.1]  # 지층별 (곡괭이 보정 전)
const PICK_SPEED_MULT := [1.0, 0.85, 0.7, 0.55]  # 곡괭이 Lv1..4
const QUIET_GAP := 0.6      # 이 간격 이상 끊어 파면 조용한 채굴
const NOISE_LOUD := 1.0
const NOISE_QUIET := 0.35
const FALL_SAFE_BASE := 3   # 장화 Lv1

# ── 램프/기름 ──
const OIL_TANK := [60.0, 80.0, 100.0, 120.0]      # 램프 Lv1..4 (초)
const OIL_PICKUP_RATIO := 0.25
const LIGHT_STAGES := [[0.6, 4.5], [0.3, 3.5], [0.1, 2.5], [0.0, 1.5]]  # [잔량비 초과, 반경(타일)]
const LIGHT_OFF_RADIUS := 0.75   # 램프 오프/기름 소진 잔광

# ── 러커/디렉터 ──
const LURKER_SPEED := 2.2         # 타일/초 (어둠에서)
const LURKER_MIN_DEPTH := 240     # 실체 스폰 시작 (심층)
const DIRECTOR_BASE := {"hunt": 18.0, "retreat": 8.0, "silence": 30.0}
const DIRECTOR_SILENCE_MIN := 10.0
const DIRECTOR_DEPTH_SCALE := 0.05  # 100m당 침묵 -5초

# ── 이코노미 ──
const ORE_VALUES := [5, 10, 25, 50, 100, 150, 300]
const BAG_SLOTS := [8, 12, 16, 20]
const MAX_HEARTS := [3, 4, 5]
const FALL_TOLERANCE := [3, 4, 5]
const OIL_BOTTLE_PRICE := 60
const OIL_BOTTLE_CARRY_MAX := 2
const UPGRADE_COSTS := {
	"pick": [150, 400, 900],
	"lamp": [120, 300, 700],
	"bag": [100, 250, 600],
	"boots": [150, 400],
	"helmet": [200, 500],
}

# ── 생성 밀도 (타일당 확률) ──
const ORE_CHANCE := [0.06, 0.07, 0.075, 0.08]     # 지층별
const OIL_CHANCE := [0.004, 0.005, 0.006, 0.007]
const CRACK_CHANCE := [0.0, 0.02, 0.035, 0.05]

# ── 피날레 ──
const FINALE_BLOCKS := 6
const FINALE_SHAFT_LIMIT := 12
const HEART_PULSE_SEC := 2.4
```

- [ ] **Step 4: worldgen.gd 작성**

`src/core/worldgen.gd`:
```gdscript
class_name WorldGen
## 시드 절차 생성 — 순수 함수. 씬/노드 접근 금지.

const W := 16
const DEPTH := 401

const T_EMPTY := 0
const T_DIRT := 1
const T_ROCK := 2
const T_CRACK := 3
const T_DEEP := 4
const T_FLESH := 5
const T_BORDER := 6
const T_OIL := 7
const T_JOURNAL := 8
const T_RELIC := 9
const T_HEART := 10
const ORE_BASE := 100

const STRATA_BASE_TILE := [T_DIRT, T_ROCK, T_DEEP, T_FLESH]
const STRATA_ORES := [[0, 1], [2, 3], [4, 5], [6]]  # 광석 id: 0석탄 1구리 2철 3은 4금 5자수정 6발광

static func idx(x: int, y: int) -> int:
	return y * W + x

static func strata_of(row: int) -> int:
	for i in range(Tuning.STRATA_BOUNDS.size()):
		if row < Tuning.STRATA_BOUNDS[i]:
			return i
	return 4

static func generate(seed_v: int, ctx: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cells := PackedInt32Array()
	cells.resize(W * DEPTH)

	for y in range(DEPTH):
		for x in range(W):
			if x == 0 or x == W - 1:
				cells[idx(x, y)] = T_BORDER
				continue
			if y == 0:
				cells[idx(x, y)] = T_EMPTY
				continue
			var s := strata_of(y)
			if s == 4:
				cells[idx(x, y)] = T_FLESH
				continue
			var roll := rng.randf()
			if roll < Tuning.ORE_CHANCE[s]:
				var ores: Array = STRATA_ORES[s]
				cells[idx(x, y)] = ORE_BASE + ores[rng.randi_range(0, ores.size() - 1)]
			elif roll < Tuning.ORE_CHANCE[s] + Tuning.OIL_CHANCE[s]:
				cells[idx(x, y)] = T_OIL
			elif roll < Tuning.ORE_CHANCE[s] + Tuning.OIL_CHANCE[s] + Tuning.CRACK_CHANCE[s]:
				cells[idx(x, y)] = T_CRACK
			else:
				cells[idx(x, y)] = STRATA_BASE_TILE[s]

	_carve_chamber(cells)
	var journal_spots := _place_journals(cells, rng, ctx.get("journals_found", []))
	var relic_spot := _place_relic(cells, rng, ctx.get("relic", {}))
	return {"cells": cells, "journal_spots": journal_spots, "relic_spot": relic_spot}

static func _carve_chamber(cells: PackedInt32Array) -> void:
	for y in range(396, DEPTH):
		for x in range(5, 11):
			cells[idx(x, y)] = T_EMPTY
	cells[idx(8, 400)] = T_HEART

static func _place_journals(cells: PackedInt32Array, rng: RandomNumberGenerator, found: Array) -> Array:
	var spots: Array = []
	for entry in Lore.series():
		if found.has(entry.id):
			continue
		var y: int = clampi(entry.row + rng.randi_range(-2, 2), 1, 395)
		var x: int = rng.randi_range(1, W - 2)
		cells[idx(x, y)] = T_JOURNAL
		spots.append({"id": entry.id, "x": x, "y": y})
	return spots

static func _place_relic(cells: PackedInt32Array, rng: RandomNumberGenerator, relic: Dictionary) -> Dictionary:
	if not relic.has("row"):
		return {}
	var y: int = clampi(int(relic.row) + rng.randi_range(-Tuning.RELIC_ROW_JITTER, Tuning.RELIC_ROW_JITTER), 1, 395)
	var x: int = rng.randi_range(1, W - 2)
	cells[idx(x, y)] = T_RELIC
	return {"x": x, "y": y}
```

주의: `Lore.series()` 의존 — Task 5 전까지 임시 브리지로 `src/core/lore.gd`에 스텁을 만든다:
```gdscript
class_name Lore

static func series() -> Array:
	return [{"id": "j1a", "row": 130}]  # Task 5에서 실제 시리즈로 교체
```

- [ ] **Step 5: runtest — 통과 확인**

Expected: skip 처리한 1개 제외 전부 passed.

- [ ] **Step 6: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): tuning constants and seeded worldgen with strata, ores, journals, relic"
```

---

### Task 3: Economy + Oil (순수 함수)

**Files:**
- Create: `games-src/it-sleeps-below/src/core/economy.gd`, `src/core/oil.gd`
- Test: `tests/test_economy.gd`, `tests/test_oil.gd`

**Interfaces:**
- Consumes: `Tuning`, `WorldGen` 타일 코드
- Produces:
  - `Economy.ore_value(ore_id: int) -> int`
  - `Economy.settle(bag: Array) -> int` — bag은 ore_id 배열, 합산 골드
  - `Economy.upgrade_cost(track: String, next_level: int) -> int` — next_level은 2부터. 상한 초과 시 -1
  - `Economy.max_level(track: String) -> int`
  - `Economy.bag_slots(level) / max_hearts(level) / fall_tolerance(level) -> int` (level은 1부터)
  - `Economy.dig_allowed(pick_level: int, row: int) -> bool` — 지층 게이트: strata s는 pick_level ≥ s+1 필요 (표토=Lv1, 암반=Lv2, 균열대=Lv3, 심층=Lv4)
  - `Economy.dig_time(pick_level: int, row: int) -> float`
  - `Oil.drain(oil: float, dt: float, lamp_on: bool) -> float`
  - `Oil.radius(oil: float, tank: float, lamp_on: bool) -> float` (타일 단위)
  - `Oil.tank(lamp_level: int) -> float`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_economy.gd`:
```gdscript
extends GdUnitTestSuite

func test_settle_sums_ore_values() -> void:
	assert_int(Economy.settle([0, 0, 6])).is_equal(5 + 5 + 300)

func test_upgrade_cost_curve_and_cap() -> void:
	assert_int(Economy.upgrade_cost("pick", 2)).is_equal(150)
	assert_int(Economy.upgrade_cost("pick", 4)).is_equal(900)
	assert_int(Economy.upgrade_cost("pick", 5)).is_equal(-1)
	assert_int(Economy.upgrade_cost("boots", 3)).is_equal(400)
	assert_int(Economy.upgrade_cost("boots", 4)).is_equal(-1)

func test_track_tables() -> void:
	assert_int(Economy.bag_slots(1)).is_equal(8)
	assert_int(Economy.bag_slots(4)).is_equal(20)
	assert_int(Economy.max_hearts(3)).is_equal(5)
	assert_int(Economy.fall_tolerance(2)).is_equal(4)

func test_strata_gate() -> void:
	assert_bool(Economy.dig_allowed(1, 20)).is_true()    # 표토
	assert_bool(Economy.dig_allowed(1, 80)).is_false()   # 암반은 Lv2
	assert_bool(Economy.dig_allowed(2, 80)).is_true()
	assert_bool(Economy.dig_allowed(3, 320)).is_false()  # 심층은 Lv4
	assert_bool(Economy.dig_allowed(4, 320)).is_true()

func test_dig_time_scales() -> void:
	assert_float(Economy.dig_time(1, 20)).is_equal_approx(0.35, 0.001)
	assert_float(Economy.dig_time(4, 320)).is_equal_approx(1.1 * 0.55, 0.001)
```

`tests/test_oil.gd`:
```gdscript
extends GdUnitTestSuite

func test_tank_by_level() -> void:
	assert_float(Oil.tank(1)).is_equal_approx(60.0, 0.001)
	assert_float(Oil.tank(4)).is_equal_approx(120.0, 0.001)

func test_drain_only_when_on() -> void:
	assert_float(Oil.drain(50.0, 2.0, true)).is_equal_approx(48.0, 0.001)
	assert_float(Oil.drain(50.0, 2.0, false)).is_equal_approx(50.0, 0.001)
	assert_float(Oil.drain(1.0, 5.0, true)).is_equal_approx(0.0, 0.001)  # 음수 금지

func test_radius_stages() -> void:
	assert_float(Oil.radius(61.0, 100.0, true)).is_equal_approx(4.5, 0.001)
	assert_float(Oil.radius(31.0, 100.0, true)).is_equal_approx(3.5, 0.001)
	assert_float(Oil.radius(11.0, 100.0, true)).is_equal_approx(2.5, 0.001)
	assert_float(Oil.radius(5.0, 100.0, true)).is_equal_approx(1.5, 0.001)
	assert_float(Oil.radius(0.0, 100.0, true)).is_equal_approx(Tuning.LIGHT_OFF_RADIUS, 0.001)
	assert_float(Oil.radius(90.0, 100.0, false)).is_equal_approx(Tuning.LIGHT_OFF_RADIUS, 0.001)
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `Economy`/`Oil` 미정의 FAIL.

- [ ] **Step 3: 구현**

`src/core/economy.gd`:
```gdscript
class_name Economy
## 광석 가치·업그레이드 커브·정산·지층 게이트 — 순수 함수.

static func ore_value(ore_id: int) -> int:
	return Tuning.ORE_VALUES[ore_id]

static func settle(bag: Array) -> int:
	var total := 0
	for ore_id in bag:
		total += ore_value(ore_id)
	return total

static func max_level(track: String) -> int:
	return Tuning.UPGRADE_COSTS[track].size() + 1

static func upgrade_cost(track: String, next_level: int) -> int:
	var costs: Array = Tuning.UPGRADE_COSTS[track]
	if next_level < 2 or next_level > costs.size() + 1:
		return -1
	return costs[next_level - 2]

static func bag_slots(level: int) -> int:
	return Tuning.BAG_SLOTS[level - 1]

static func max_hearts(level: int) -> int:
	return Tuning.MAX_HEARTS[level - 1]

static func fall_tolerance(level: int) -> int:
	return Tuning.FALL_TOLERANCE[level - 1]

static func dig_allowed(pick_level: int, row: int) -> bool:
	var s := WorldGen.strata_of(row)
	if s >= 4:
		return true  # 최심부 챔버는 이미 뚫려 있음 (심장만 별도 처리)
	return pick_level >= s + 1

static func dig_time(pick_level: int, row: int) -> float:
	var s: int = mini(WorldGen.strata_of(row), 3)
	return Tuning.DIG_TIME_BASE[s] * Tuning.PICK_SPEED_MULT[pick_level - 1]
```

`src/core/oil.gd`:
```gdscript
class_name Oil
## 기름 = 시간 = 안전. 소모·빛 반경 단계 — 순수 함수.

static func tank(lamp_level: int) -> float:
	return Tuning.OIL_TANK[lamp_level - 1]

static func drain(oil: float, dt: float, lamp_on: bool) -> float:
	if not lamp_on:
		return oil
	return maxf(0.0, oil - dt)

static func radius(oil: float, tank_size: float, lamp_on: bool) -> float:
	if not lamp_on or oil <= 0.0:
		return Tuning.LIGHT_OFF_RADIUS
	var ratio := oil / tank_size
	for stage in Tuning.LIGHT_STAGES:
		if ratio > stage[0]:
			return stage[1]
	return Tuning.LIGHT_OFF_RADIUS
```

- [ ] **Step 4: runtest — 통과 확인**

Expected: 전부 passed.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): economy (settle, upgrades, strata gate) and oil (drain, light stages)"
```

---

### Task 4: LurkerLogic — 위핑 엔젤 + 파도형 디렉터

**Files:**
- Create: `games-src/it-sleeps-below/src/core/lurker_logic.gd`
- Test: `tests/test_lurker_logic.gd`

**Interfaces:**
- Consumes: `Tuning`, `WorldGen`
- Produces:
  - 디렉터 모드 상수: `M_SILENCE=0, M_HUNT=1, M_RETREAT=2`
  - `LurkerLogic.cycle_lengths(depth_m: int) -> Dictionary` — `{"hunt","retreat","silence"}` (침묵은 깊이에 따라 감소, 하한 `DIRECTOR_SILENCE_MIN`)
  - `LurkerLogic.director_step(d: Dictionary, dt: float, depth_m: int) -> Dictionary` — d = `{"mode": int, "t": float}`, t 소진 시 SILENCE→HUNT→RETREAT→SILENCE 순환
  - `LurkerLogic.is_frozen(lurker: Vector2i, player: Vector2i, radius: float, lamp_on: bool) -> bool` — 유클리드 거리 ≤ radius && lamp_on
  - `LurkerLogic.hear(state: Dictionary, noise_pos: Vector2i, noise_level: float) -> Dictionary` — noise_level ≥ 0.5면 target 갱신 + `"alert": true`
  - `LurkerLogic.next_step(lurker: Vector2i, target: Vector2i, is_open: Callable) -> Vector2i` — 파낸 공간(EMPTY)만 통과하는 BFS 한 걸음. 경로 없으면 제자리
  - `LurkerLogic.arrived_wander(state: Dictionary, rng_pick: Vector2i) -> Dictionary` — target 도달 시 배회 지점으로 전환(지나침 규칙)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_lurker_logic.gd`:
```gdscript
extends GdUnitTestSuite

func _open_all(_p: Vector2i) -> bool:
	return true

func _open_corridor(p: Vector2i) -> bool:
	return p.y == 0 and p.x >= 0 and p.x <= 5  # 가로 복도만

func test_frozen_in_light_only_when_lamp_on() -> void:
	assert_bool(LurkerLogic.is_frozen(Vector2i(3, 0), Vector2i(0, 0), 3.5, true)).is_true()
	assert_bool(LurkerLogic.is_frozen(Vector2i(3, 0), Vector2i(0, 0), 3.5, false)).is_false()
	assert_bool(LurkerLogic.is_frozen(Vector2i(5, 0), Vector2i(0, 0), 3.5, true)).is_false()

func test_next_step_moves_through_open_cells_only() -> void:
	var step := LurkerLogic.next_step(Vector2i(0, 0), Vector2i(5, 0), _open_corridor)
	assert_that(step).is_equal(Vector2i(1, 0))
	# 목표가 막힌 영역이면 제자리
	var stuck := LurkerLogic.next_step(Vector2i(0, 0), Vector2i(0, 5), _open_corridor)
	assert_that(stuck).is_equal(Vector2i(0, 0))

func test_hear_updates_target_on_loud_noise() -> void:
	var s := {"target": Vector2i(9, 9), "alert": false}
	s = LurkerLogic.hear(s, Vector2i(2, 3), Tuning.NOISE_LOUD)
	assert_that(s.target).is_equal(Vector2i(2, 3))
	assert_bool(s.alert).is_true()
	var quiet := LurkerLogic.hear({"target": Vector2i(9, 9), "alert": false}, Vector2i(2, 3), Tuning.NOISE_QUIET)
	assert_that(quiet.target).is_equal(Vector2i(9, 9))

func test_director_cycle_order_and_depth_pressure() -> void:
	var lens := LurkerLogic.cycle_lengths(240)
	var deep := LurkerLogic.cycle_lengths(390)
	assert_float(deep.silence).is_less(lens.silence)
	assert_float(LurkerLogic.cycle_lengths(4000).silence).is_equal_approx(Tuning.DIRECTOR_SILENCE_MIN, 0.001)
	var d := {"mode": LurkerLogic.M_SILENCE, "t": 0.5}
	d = LurkerLogic.director_step(d, 1.0, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_HUNT)
	d.t = 0.0
	d = LurkerLogic.director_step(d, 0.1, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_RETREAT)
	d.t = 0.0
	d = LurkerLogic.director_step(d, 0.1, 240)
	assert_int(d.mode).is_equal(LurkerLogic.M_SILENCE)

func test_arrived_wander_switches_target() -> void:
	var s := {"target": Vector2i(1, 1), "alert": true}
	s = LurkerLogic.arrived_wander(s, Vector2i(7, 7))
	assert_that(s.target).is_equal(Vector2i(7, 7))
	assert_bool(s.alert).is_false()
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `LurkerLogic` 미정의 FAIL.

- [ ] **Step 3: 구현**

`src/core/lurker_logic.gd`:
```gdscript
class_name LurkerLogic
## '그것'의 규칙 전부 — 순수 함수. 빛 안 정지 / 어둠 접근 / 소리 반응 / 파도형 디렉터.

const M_SILENCE := 0
const M_HUNT := 1
const M_RETREAT := 2

static func cycle_lengths(depth_m: int) -> Dictionary:
	var base: Dictionary = Tuning.DIRECTOR_BASE
	var over := maxf(0.0, float(depth_m - Tuning.LURKER_MIN_DEPTH))
	var silence: float = maxf(Tuning.DIRECTOR_SILENCE_MIN, base.silence - over * Tuning.DIRECTOR_DEPTH_SCALE)
	return {"hunt": base.hunt, "retreat": base.retreat, "silence": silence}

static func director_step(d: Dictionary, dt: float, depth_m: int) -> Dictionary:
	var out := {"mode": d.mode, "t": d.t - dt}
	if out.t > 0.0:
		return out
	var lens := cycle_lengths(depth_m)
	match int(d.mode):
		M_SILENCE:
			return {"mode": M_HUNT, "t": lens.hunt}
		M_HUNT:
			return {"mode": M_RETREAT, "t": lens.retreat}
		_:
			return {"mode": M_SILENCE, "t": lens.silence}

static func is_frozen(lurker: Vector2i, player: Vector2i, radius: float, lamp_on: bool) -> bool:
	if not lamp_on:
		return false
	return Vector2(lurker).distance_to(Vector2(player)) <= radius

static func hear(state: Dictionary, noise_pos: Vector2i, noise_level: float) -> Dictionary:
	var out := state.duplicate()
	if noise_level >= 0.5:
		out.target = noise_pos
		out.alert = true
	return out

static func arrived_wander(state: Dictionary, rng_pick: Vector2i) -> Dictionary:
	var out := state.duplicate()
	out.target = rng_pick
	out.alert = false
	return out

static func next_step(lurker: Vector2i, target: Vector2i, is_open: Callable) -> Vector2i:
	if lurker == target:
		return lurker
	# BFS — 파낸 공간만 통과. 그리드가 작아(16×401) 전수 탐색 허용.
	var q: Array[Vector2i] = [lurker]
	var prev := {lurker: lurker}
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == target:
			# 역추적으로 첫걸음 복원
			while prev[cur] != lurker:
				cur = prev[cur]
			return cur
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if prev.has(nxt) or not is_open.call(nxt):
				continue
			prev[nxt] = cur
			q.append(nxt)
	return lurker
```

- [ ] **Step 4: runtest — 통과 확인**

Expected: 전부 passed.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): lurker logic — weeping-angel freeze, sound tracking, wave director"
```

---

### Task 5: Lore + AnomalyPool (일지 시리즈 · 이상 현상 카탈로그)

**Files:**
- Modify: `games-src/it-sleeps-below/src/core/lore.gd` (Task 2의 스텁 → 실제 시리즈)
- Create: `src/core/anomaly_pool.gd`
- Test: `tests/test_lore.gd`, `tests/test_anomaly_pool.gd`
- Modify: `tests/test_worldgen.gd` — `skip_test_journal_spots_follow_series_order` → `test_...`로 복원

**Interfaces:**
- Consumes: `Tuning`
- Produces:
  - `Lore.series() -> Array` — `[{id: String, author: String, row: int}]` 깊이 오름차순. 저자 3명 × 3~4장 = 10장. **id는 텍스트 JSON의 키와 1:1** (Task 8)
  - `Lore.next_unfound(found: Array) -> Dictionary` — 없으면 `{}`
  - `Lore.collection_rate(found: Array) -> float` — 0.0~1.0
  - `AnomalyPool.catalog() -> Array` — `[{id, kind("diegetic"|"meta"|"encounter"), min_depth, once(bool), realized(bool)}]`
  - `AnomalyPool.eligible(entry: Dictionary, flags: Array, depth_m: int, corruption: int) -> bool` — once && flags 포함 → false; depth < min_depth → false; realized && corruption < 3 → false
  - `AnomalyPool.pick(flags: Array, depth_m: int, corruption: int, rng: RandomNumberGenerator) -> Dictionary` — 자격 있는 항목 중 무작위 1개, 없으면 `{}`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_lore.gd`:
```gdscript
extends GdUnitTestSuite

func test_series_is_depth_ordered_and_ids_unique() -> void:
	var s := Lore.series()
	assert_int(s.size()).is_greater_equal(9)
	var seen := {}
	for i in range(1, s.size()):
		assert_int(s[i].row).is_greater_equal(s[i - 1].row)
	for e in s:
		assert_bool(seen.has(e.id)).is_false()
		seen[e.id] = true

func test_next_unfound_and_rate() -> void:
	var s := Lore.series()
	assert_str(Lore.next_unfound([]).id).is_equal(s[0].id)
	assert_str(Lore.next_unfound([s[0].id]).id).is_equal(s[1].id)
	assert_float(Lore.collection_rate([])).is_equal_approx(0.0, 0.001)
	var all_ids: Array = []
	for e in s:
		all_ids.append(e.id)
	assert_float(Lore.collection_rate(all_ids)).is_equal_approx(1.0, 0.001)
```

`tests/test_anomaly_pool.gd`:
```gdscript
extends GdUnitTestSuite

func test_catalog_has_three_kinds_and_min_sizes() -> void:
	var kinds := {"diegetic": 0, "meta": 0, "encounter": 0}
	for e in AnomalyPool.catalog():
		kinds[e.kind] += 1
	assert_int(kinds.diegetic).is_greater_equal(8)
	assert_int(kinds.meta).is_greater_equal(4)
	assert_int(kinds.encounter).is_greater_equal(4)

func test_once_per_save_excluded() -> void:
	var e := {"id": "x", "kind": "diegetic", "min_depth": 0, "once": true, "realized": false}
	assert_bool(AnomalyPool.eligible(e, [], 100, 0)).is_true()
	assert_bool(AnomalyPool.eligible(e, ["x"], 100, 0)).is_false()

func test_depth_and_realized_gates() -> void:
	var e := {"id": "y", "kind": "diegetic", "min_depth": 240, "once": false, "realized": true}
	assert_bool(AnomalyPool.eligible(e, [], 100, 5)).is_false()   # 깊이 미달
	assert_bool(AnomalyPool.eligible(e, [], 300, 0)).is_false()   # 실체화는 오염 3+ 필요
	assert_bool(AnomalyPool.eligible(e, [], 300, 3)).is_true()

func test_pick_respects_flags() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var flags: Array = []
	for i in range(200):
		var p := AnomalyPool.pick(flags, 400, 4, rng)
		if p.is_empty():
			break
		if p.once:
			assert_bool(flags.has(p.id)).is_false()
			flags.append(p.id)
	assert_int(flags.size()).is_greater(0)
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `AnomalyPool` 미정의 FAIL, `Lore` 테스트는 스텁이라 FAIL.

- [ ] **Step 3: 구현**

`src/core/lore.gd` (스텁 교체):
```gdscript
class_name Lore
## 광부 일지 시리즈 — id는 text.json의 journals 키와 1:1.
## 저자: han(신중한 선배) / baek(탐욕에 먹힌 자) / seo(산을 연구한 학자)

const SERIES := [
	{"id": "han_1", "author": "han", "row": 50},
	{"id": "baek_1", "author": "baek", "row": 70},
	{"id": "han_2", "author": "han", "row": 100},
	{"id": "seo_1", "author": "seo", "row": 140},
	{"id": "baek_2", "author": "baek", "row": 170},
	{"id": "han_3", "author": "han", "row": 210},   # han의 마지막 — 미완
	{"id": "seo_2", "author": "seo", "row": 260},
	{"id": "baek_3", "author": "baek", "row": 300}, # baek의 마지막 — 미완
	{"id": "seo_3", "author": "seo", "row": 350},
	{"id": "seo_4", "author": "seo", "row": 390},   # seo의 마지막 — 심장 직전
]

static func series() -> Array:
	return SERIES

static func next_unfound(found: Array) -> Dictionary:
	for e in SERIES:
		if not found.has(e.id):
			return e
	return {}

static func collection_rate(found: Array) -> float:
	var n := 0
	for e in SERIES:
		if found.has(e.id):
			n += 1
	return float(n) / float(SERIES.size())
```

`src/core/anomaly_pool.gd`:
```gdscript
class_name AnomalyPool
## 이상 현상·연출 조우 카탈로그 — 데이터 주도. 연출 실행은 AnomalyDirector(씬)가 담당.
## realized=true 항목은 오염(corruption) 3 이상에서만 — "학습된 안전감의 배신" (스펙 §7).

const CATALOG := [
	# ── 다이제틱 ──
	{"id": "lamp_blink", "kind": "diegetic", "min_depth": 40, "once": false, "realized": false},
	{"id": "tunnel_sealed", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "echo_pick", "kind": "diegetic", "min_depth": 40, "once": true, "realized": false},
	{"id": "edge_silhouette", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "ore_whisper", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "merchant_gone", "kind": "diegetic", "min_depth": 240, "once": true, "realized": false},
	{"id": "side_tunnel", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "rhythm_continues", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "ore_resealed", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "false_heartbeat", "kind": "diegetic", "min_depth": 240, "once": false, "realized": false},
	{"id": "black_sky", "kind": "diegetic", "min_depth": 240, "once": true, "realized": false},
	# ── 실체화 변형 (오염 3+) ──
	{"id": "lamp_blink_real", "kind": "diegetic", "min_depth": 240, "once": true, "realized": true},
	{"id": "tunnel_sealed_real", "kind": "diegetic", "min_depth": 240, "once": true, "realized": true},
	# ── 가벼운 메타 (캔버스 안 한정) ──
	{"id": "depth_999", "kind": "meta", "min_depth": 120, "once": true, "realized": false},
	{"id": "depth_rises", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "gauge_zero", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "black_ore", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "pause_message", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	# ── 연출 조우 (러커) ──
	{"id": "back_turned", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "silent_mimic", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "parallel_steps", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "other_lamp", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
]

static func catalog() -> Array:
	return CATALOG

static func eligible(entry: Dictionary, flags: Array, depth_m: int, corruption: int) -> bool:
	if entry.once and flags.has(entry.id):
		return false
	if depth_m < entry.min_depth:
		return false
	if entry.realized and corruption < 3:
		return false
	return true

static func pick(flags: Array, depth_m: int, corruption: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	for e in CATALOG:
		if eligible(e, flags, depth_m, corruption):
			pool.append(e)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]
```

- [ ] **Step 4: worldgen 스킵 테스트 복원 + runtest**

`tests/test_worldgen.gd`의 `skip_test_journal_spots_follow_series_order`를 `test_journal_spots_follow_series_order`로 되돌린다.
runtest — Expected: 전부 passed.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): journal series (3 authors) and anomaly catalog with realization gate"
```

---

### Task 6: Finale — 탈출로 뒤틀림 + 도달 가능성 보장

**Files:**
- Create: `games-src/it-sleeps-below/src/core/finale.gd`
- Test: `tests/test_finale.gd`

**Interfaces:**
- Consumes: `WorldGen`, `Tuning`
- Produces:
  - `Finale.reachable(cells: PackedInt32Array) -> bool` — 심장 챔버(8,399)에서 지표(row 0)까지 T_EMPTY(및 T_HEART) 4방향 BFS 연결 여부
  - `Finale.twist(cells: PackedInt32Array, seed_v: int) -> Dictionary` — `{"cells": 수정본, "blocked": [Vector2i], "ramps": [Vector2i]}`. 규칙: ① 최대 `FINALE_BLOCKS`개 통로 셀을 T_FLESH로 봉쇄(우회 강제) ② `FINALE_SHAFT_LIMIT` 초과 수직갱 옆에 붕괴 경사(EMPTY 대각 카브) 추가 ③ 각 봉쇄 후 `reachable` 재검증 — 깨지면 해당 봉쇄 롤백. **최종 결과는 항상 reachable == true**

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_finale.gd`:
```gdscript
extends GdUnitTestSuite

func _dug_world() -> PackedInt32Array:
	# 실제 생성 월드에 "플레이어가 판 길"을 흉내: 중앙 col 8을 지표까지 수직 개통
	var g: Dictionary = WorldGen.generate(77, {"journals_found": [], "relic": {}})
	var cells: PackedInt32Array = g.cells
	for y in range(0, 400):
		cells[WorldGen.idx(8, y)] = WorldGen.T_EMPTY
	return cells

func test_reachable_on_open_shaft() -> void:
	assert_bool(Finale.reachable(_dug_world())).is_true()

func test_unreachable_when_sealed() -> void:
	var cells := _dug_world()
	for x in range(1, WorldGen.W - 1):
		cells[WorldGen.idx(x, 200)] = WorldGen.T_FLESH
	assert_bool(Finale.reachable(cells)).is_false()

func test_twist_always_reachable_and_applies_ops() -> void:
	for seed_v in [1, 22, 333]:
		var out: Dictionary = Finale.twist(_dug_world(), seed_v)
		assert_bool(Finale.reachable(out.cells)).is_true()
		assert_int(out.blocked.size() + out.ramps.size()).is_greater(0)
		assert_int(out.blocked.size()).is_less_equal(Tuning.FINALE_BLOCKS)
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `Finale` 미정의 FAIL.

- [ ] **Step 3: 구현**

`src/core/finale.gd`:
```gdscript
class_name Finale
## 피날레 — "네가 판 길"을 산이 뒤튼다. 뒤튼 뒤에도 반드시 오를 수 있어야 한다 (스펙 §9).

const HEART_POS := Vector2i(8, 399)

static func _passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY or c == WorldGen.T_HEART

static func reachable(cells: PackedInt32Array) -> bool:
	var q: Array[Vector2i] = [HEART_POS]
	var seen := {HEART_POS: true}
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur.y == 0:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= WorldGen.W or n.y < 0 or n.y >= WorldGen.DEPTH:
				continue
			if seen.has(n) or not _passable(cells[WorldGen.idx(n.x, n.y)]):
				continue
			seen[n] = true
			q.append(n)
	return false

static func twist(cells: PackedInt32Array, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := PackedInt32Array(cells)
	var blocked: Array[Vector2i] = []
	var ramps: Array[Vector2i] = []

	# ② 긴 수직갱 옆 붕괴 경사 — 오를 수 없는 갱을 나눠준다
	var run := 0
	for x in range(1, WorldGen.W - 1):
		run = 0
		for y in range(1, 396):
			if out[WorldGen.idx(x, y)] == WorldGen.T_EMPTY:
				run += 1
				if run >= Tuning.FINALE_SHAFT_LIMIT:
					var side := 1 if x < WorldGen.W - 2 else -1
					var p := Vector2i(x + side, y - int(Tuning.FINALE_SHAFT_LIMIT / 2.0))
					if out[WorldGen.idx(p.x, p.y)] != WorldGen.T_BORDER:
						out[WorldGen.idx(p.x, p.y)] = WorldGen.T_EMPTY
						ramps.append(p)
					run = 0
			else:
				run = 0

	# ① 통로 봉쇄 — 우회 강제. 봉쇄마다 도달 가능성 재검증, 깨지면 롤백
	var candidates: Array[Vector2i] = []
	for y in range(40, 396):
		for x in range(1, WorldGen.W - 1):
			if out[WorldGen.idx(x, y)] == WorldGen.T_EMPTY:
				candidates.append(Vector2i(x, y))
	# 수동 Fisher-Yates (전역 shuffle은 시드 재현성이 없다)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	for p in candidates:
		if blocked.size() >= Tuning.FINALE_BLOCKS:
			break
		var prev := out[WorldGen.idx(p.x, p.y)]
		out[WorldGen.idx(p.x, p.y)] = WorldGen.T_FLESH
		if reachable(out):
			blocked.append(p)
		else:
			out[WorldGen.idx(p.x, p.y)] = prev

	return {"cells": out, "blocked": blocked, "ramps": ramps}
```

- [ ] **Step 4: runtest — 통과 확인**

Expected: 전부 passed.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): finale twist — blocks and ramps with guaranteed reachability"
```

---

### Task 7: GameState + Persistence (세이브)

**Files:**
- Modify: `games-src/it-sleeps-below/src/core/game_state.gd` (스텁 → 구현)
- Create: `src/core/persistence.gd`
- Test: `tests/test_persistence.gd`

**Interfaces:**
- Consumes: `Economy`, `Oil`, `Lore`
- Produces:
  - `Persistence.default_profile() -> Dictionary` — 아래 필드 전부
  - `Persistence.save_profile(path: String, p: Dictionary) -> void` / `load_profile(path: String) -> Dictionary` (없거나 깨지면 default 반환, 누락 키는 default로 채움)
  - 오토로드 `GameState` — `profile: Dictionary`, `run: Dictionary`(런 임시 상태), `save() / load()` (`user://isb_save.json`), `start_run() -> Dictionary`(worldgen ctx 조립), `end_run_death(depth_m: int) -> void`(유품 기록: 가방+깊이, 이전 유품 소멸), `end_run_settle() -> int`(정산+골드 반영+가방 비움), `corruption() -> int`(최고 깊이 → 0~4 지층 인덱스)

**프로필 스키마 (버전 1):**
```gdscript
{
  "version": 1, "gold": 0,
  "upgrades": {"pick": 1, "lamp": 1, "bag": 1, "boots": 1, "helmet": 1},
  "oil_bottles": 0,
  "journals_found": [], "anomaly_flags": [],
  "relic": {},                       # {"row": int, "items": [ore_id...]} — 최근 1개만
  "best_depth": 0, "ending_seen": false, "opening_seen": false,
  "miner_no": 1,                     # '다음 광부' 카운터
  "settings": {"lang": "ko", "haptics": true, "reduced_flash": false}
}
```

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_persistence.gd`:
```gdscript
extends GdUnitTestSuite

const P := "user://test_isb_save.json"

func after_test() -> void:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(P)

func test_default_profile_schema() -> void:
	var p := Persistence.default_profile()
	assert_int(p.version).is_equal(1)
	assert_int(p.upgrades.pick).is_equal(1)
	assert_str(p.settings.lang).is_equal("ko")
	assert_int(p.miner_no).is_equal(1)

func test_roundtrip() -> void:
	var p := Persistence.default_profile()
	p.gold = 777
	p.journals_found = ["han_1"]
	p.relic = {"row": 150, "items": [2, 3]}
	Persistence.save_profile(P, p)
	var q := Persistence.load_profile(P)
	assert_int(q.gold).is_equal(777)
	assert_that(q.journals_found).contains(["han_1"])
	assert_int(int(q.relic.row)).is_equal(150)

func test_load_missing_returns_default() -> void:
	assert_int(Persistence.load_profile("user://no_such_file.json").gold).is_equal(0)

func test_load_fills_missing_keys() -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "gold": 5}))
	f.close()
	var q := Persistence.load_profile(P)
	assert_int(q.gold).is_equal(5)
	assert_int(q.upgrades.lamp).is_equal(1)  # 누락 키가 default로 채워짐
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `Persistence` 미정의 FAIL.

- [ ] **Step 3: 구현**

`src/core/persistence.gd`:
```gdscript
class_name Persistence
## 프로필 저장/로드 — 웹에서는 user://가 IndexedDB로 영속된다.

static func default_profile() -> Dictionary:
	return {
		"version": 1, "gold": 0,
		"upgrades": {"pick": 1, "lamp": 1, "bag": 1, "boots": 1, "helmet": 1},
		"oil_bottles": 0,
		"journals_found": [], "anomaly_flags": [],
		"relic": {},
		"best_depth": 0, "ending_seen": false, "opening_seen": false,
		"miner_no": 1,
		"settings": {"lang": "ko", "haptics": true, "reduced_flash": false},
	}

static func save_profile(path: String, p: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))
		f.close()

static func load_profile(path: String) -> Dictionary:
	var base := default_profile()
	if not FileAccess.file_exists(path):
		return base
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return base
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return base
	return _merge(base, data)

static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY and typeof(over[k]) == TYPE_DICTIONARY:
			out[k] = _merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out
```

`src/core/game_state.gd` (스텁 교체):
```gdscript
extends Node
## 오토로드 — 프로필(영속) + 런 상태(휘발). 씬들은 이 노드만 본다.

const SAVE_PATH := "user://isb_save.json"

var profile: Dictionary = Persistence.default_profile()
var run: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	profile = Persistence.load_profile(SAVE_PATH)

func save() -> void:
	Persistence.save_profile(SAVE_PATH, profile)

func corruption() -> int:
	return WorldGen.strata_of(profile.best_depth)

func start_run() -> Dictionary:
	run = {
		"seed": randi(),
		"bag": [], "hearts": Economy.max_hearts(profile.upgrades.helmet),
		"oil": Oil.tank(profile.upgrades.lamp), "lamp_on": true,
		"depth": 0, "bottles": profile.oil_bottles,
	}
	return {"journals_found": profile.journals_found, "relic": profile.relic}

func end_run_death(depth_m: int) -> void:
	profile.relic = {"row": depth_m, "items": run.bag.duplicate()}  # 이전 유품은 덮어써 소멸
	profile.oil_bottles = 0
	profile.miner_no += 1
	profile.best_depth = maxi(profile.best_depth, depth_m)
	save()

func end_run_settle() -> int:
	var earned := Economy.settle(run.bag)
	profile.gold += earned
	profile.oil_bottles = run.bottles
	profile.best_depth = maxi(profile.best_depth, run.depth)
	run.bag = []
	save()
	return earned
```

- [ ] **Step 4: runtest — 통과 확인**

Expected: 전부 passed.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): profile persistence with defaults merge, GameState run lifecycle and relic rule"
```

---

### Task 8: 서사 텍스트 JSON + 사이트 텍스트 에디터

**Files:**
- Create: `public/games/it-sleeps-below/text/text.json`, `src/lib/gametext.ts`, `src/lib/gametext.test.ts`, `src/app/editor/text/page.tsx`, `src/components/GameTextEditorClient.tsx`
- Modify: `src/app/api/editor/route.ts` (target `'gametext'` 추가)

**Interfaces:**
- Produces:
  - `text.json` 스키마: `{ "journals" | "merchant" | "ui" | "opening" | "ending": { key: {"ko": string, "en": string} } }`
  - `gametext.ts`: `JOURNAL_IDS: string[]`(lore.gd SERIES와 1:1 — 주석으로 동기화 명시), `getGameText(): GameText`, `updateGameText(doc: unknown): GameText`(검증 후 전체 문서 저장), `validateGameText(raw): GameText`(모든 leaf에 ko/en 비어있지 않음 + journals가 JOURNAL_IDS 전부 포함)
  - `/api/editor` POST body `{target: 'gametext', patch: <전체 문서>}` → 검증 실패 시 400, 성공 시 저장
  - `/editor/text` — KO/EN 나란히 편집하는 로컬 페이지 (dev 전용, 프로덕션 404는 기존 라우트 가드가 담당)

- [ ] **Step 1: 실패하는 테스트 작성**

`src/lib/gametext.test.ts`:
```ts
import { describe, expect, it } from 'vitest'
import { JOURNAL_IDS, getGameText, validateGameText } from './gametext'

describe('gametext', () => {
  it('loads the real text.json and validates', () => {
    const doc = getGameText()
    expect(Object.keys(doc.journals)).toEqual(expect.arrayContaining(JOURNAL_IDS))
  })

  it('every leaf has non-empty ko and en', () => {
    const doc = getGameText()
    for (const cat of Object.values(doc)) {
      for (const entry of Object.values(cat)) {
        expect(entry.ko.trim().length).toBeGreaterThan(0)
        expect(entry.en.trim().length).toBeGreaterThan(0)
      }
    }
  })

  it('rejects missing journal key', () => {
    const doc = JSON.parse(JSON.stringify(getGameText()))
    delete doc.journals[JOURNAL_IDS[0]]
    expect(() => validateGameText(doc)).toThrow(/journal/)
  })

  it('rejects empty translation', () => {
    const doc = JSON.parse(JSON.stringify(getGameText()))
    doc.ui.tap_to_descend.en = ''
    expect(() => validateGameText(doc)).toThrow(/en/)
  })
})
```

- [ ] **Step 2: `npm test` — 실패 확인**

Expected: `gametext` 모듈 없음 FAIL (기존 스위트는 통과 유지).

- [ ] **Step 3: text.json 작성 (초안 전문)**

`public/games/it-sleeps-below/text/text.json` — 일지 초안은 아래 전문을 그대로 넣는다 (이후 `/editor/text`에서 다듬는다). 각 저자의 마지막 장은 문장이 끊긴 채 끝난다:

```json
{
  "journals": {
    "han_1": {
      "ko": "한씨의 일지 (1)\n\n규칙을 적어둔다. 후임자가 있다면 읽어라.\n하나. 기름은 절반이 되면 돌아선다.\n둘. 갱도에서 다른 불빛을 봐도 부르지 마라.\n셋. 곡괭이 소리가 메아리로 두 번 울리면, 두 번째는 네가 낸 소리가 아니다.",
      "en": "Han's Journal (1)\n\nI write down the rules. If there is a successor, read this.\nOne. Turn back when the oil is half gone.\nTwo. If you see another light in the shaft, do not call out.\nThree. If your pickaxe echoes twice, the second one was not yours."
    },
    "baek_1": {
      "ko": "백가의 기록 (1)\n\n한씨는 겁쟁이다. 절반은 무슨. 은맥이 코앞인데.\n오늘 은 아홉 덩이. 상인은 값을 안 깎는다. 이상한 노인네지만 돈은 확실해.\n내일은 더 내려간다.",
      "en": "Baek's Log (1)\n\nHan is a coward. Half tank, nonsense. The silver vein is right there.\nNine chunks of silver today. The merchant never haggles. Strange old one, but the money is real.\nTomorrow I go deeper."
    },
    "han_2": {
      "ko": "한씨의 일지 (2)\n\n백가가 내 경고를 비웃었다. 그러라지.\n오늘 균열대 근처에서 벽에 긁힌 자국을 봤다. 곡괭이 자국이 아니다. 안쪽에서 긁은 자국이다.\n규칙 넷. 벽이 따뜻하면 파지 마라.",
      "en": "Han's Journal (2)\n\nBaek laughed at my warnings. Let him.\nNear the fissures today I found scratches on the wall. Not pickaxe marks. Scratched from the inside.\nRule four. If the wall is warm, do not dig."
    },
    "seo_1": {
      "ko": "서 연구원의 수기 (1)\n\n이 산의 광맥 분포는 지질학적으로 불가능하다. 광맥이 아니라... 관(管)에 가깝다.\n표본 채취를 위해 더 내려가야 한다. 광부들은 입을 다물었다. 128미터부터는 안내를 거부했다.",
      "en": "Researcher Seo's Notes (1)\n\nThe ore distribution in this mountain is geologically impossible. Not veins... closer to vessels.\nI must descend further for samples. The miners have gone quiet. Below 128 meters, they refused to guide me."
    },
    "baek_2": {
      "ko": "백가의 기록 (2)\n\n금이다. 금맥을 찾았다.\n한씨가 사라졌다고 다들 수군댄다. 겁쟁이니까 도망쳤겠지.\n...근데 오늘 아래쪽 갱도에서 한씨의 램프를 봤다. 분명 한씨의 초록 램프였다. 불렀는데 대답이 없었다.",
      "en": "Baek's Log (2)\n\nGold. I found the gold vein.\nEveryone whispers that Han disappeared. Coward probably ran.\n...But today, down the lower shaft, I saw Han's lamp. It was his green lamp, I am certain. I called out. No answer."
    },
    "han_3": {
      "ko": "한씨의 일지 (3)\n\n내 일지 두 권이 사라졌다. 아니, 옮겨져 있었다. 더 깊은 곳으로.\n산이 나를 아래로 부르고 있다. 규칙 다섯. 부름에는\n",
      "en": "Han's Journal (3)\n\nTwo of my journals are gone. No — moved. Deeper.\nThe mountain is calling me down. Rule five. When it calls\n"
    },
    "seo_2": {
      "ko": "서 연구원의 수기 (2)\n\n표본이 맥동한다. 상자 안에서. 채취한 지 사흘이 지났는데.\n광부 백씨가 며칠째 보이지 않는다. 그의 텐트는 그대로다. 장화도 그대로다.\n가설: 이 산은 광물을 만드는 것이 아니라, 광물로 유인한다.",
      "en": "Researcher Seo's Notes (2)\n\nThe sample pulses. Inside the box. Three days after extraction.\nMiner Baek has not been seen for days. His tent is untouched. His boots, untouched.\nHypothesis: the mountain does not form minerals. It baits with them."
    },
    "baek_3": {
      "ko": "백가의 기록 (3)\n\n발광 광석이 이렇게 많은데 왜 아무도 안 캐는 거지. 전부 내 거다.\n등 뒤에서 곡괭이 소리가 난다. 내 리듬이랑 똑같은데. 뒤돌아보면 아무도 없고.\n하나만 더 캐고 올라간다. 하나만 더",
      "en": "Baek's Log (3)\n\nSo much glowing ore and no one digs it. It is all mine.\nI hear a pickaxe behind me. Same rhythm as mine. When I turn, nothing.\nOne more and I go up. Just one more"
    },
    "seo_3": {
      "ko": "서 연구원의 수기 (3)\n\n이제 확신한다. 이 산은 살아 있다. 우리가 파는 것은 갱도가 아니라 상처다.\n그리고 저 실루엣들 — 광부의 형상을 한 것들 — 은 침입자를 막는 면역 반응이다.\n그들이 곡괭이 소리를 내는 이유: 아직 기억하기 때문이다.",
      "en": "Researcher Seo's Notes (3)\n\nI am certain now. This mountain is alive. What we dig are not shafts but wounds.\nAnd those silhouettes — the ones shaped like miners — are an immune response against intruders.\nWhy they mimic pickaxe sounds: because they still remember."
    },
    "seo_4": {
      "ko": "서 연구원의 수기 (4)\n\n심장이 있다. 최심부에. 맥동이 벽을 타고 올라온다.\n그것들이 나를 막지 않는다. 오히려 길을 비켜준다. 산이 나를 초대하고 있다.\n왜인지 이제 알겠다. 산은 보여주고 싶은 것이다. 자신이 무엇인지. 우리가 무엇을\n",
      "en": "Researcher Seo's Notes (4)\n\nThere is a heart. At the deepest point. Its pulse climbs the walls.\nThey do not stop me. They step aside. The mountain is inviting me.\nAnd now I understand why. It wants to show us. What it is. What we\n"
    }
  },
  "merchant": {
    "opening": { "ko": "갱도는 저쪽이야.", "en": "The shaft is that way." },
    "settle_1": { "ko": "좋은 광석이군. 산이 후하게 내어줬어.", "en": "Fine ore. The mountain gave generously." },
    "settle_2": { "ko": "더 깊은 곳엔 더 좋은 게 있지. 언제나 그래.", "en": "There is always better, deeper down. Always." },
    "settle_3": { "ko": "자네 전에도 광부들이 있었네. 다들 부지런했지.", "en": "There were miners before you. Diligent, all of them." },
    "settle_4": { "ko": "산이 자네를 마음에 들어해.", "en": "The mountain likes you." },
    "next_miner": { "ko": "…다음 분이신가.", "en": "...You must be the next one." },
    "memo_gone": { "ko": "잠시 자리를 비운다. 광석은 두고 가면 셈해두지. — 상인", "en": "Away for a while. Leave your ore, I will keep count. — The Merchant" }
  },
  "ui": {
    "tap_to_descend": { "ko": "탭하여 내려가기", "en": "TAP TO DESCEND" },
    "strata_0": { "ko": "표토", "en": "TOPSOIL" },
    "strata_1": { "ko": "암반", "en": "BEDROCK" },
    "strata_2": { "ko": "균열대", "en": "THE FISSURES" },
    "strata_3": { "ko": "심층", "en": "THE DEEP" },
    "strata_4": { "ko": "최심부", "en": "THE BOTTOM" },
    "paused": { "ko": "일시정지", "en": "PAUSED" },
    "pause_dont_go": { "ko": "나가지 마", "en": "DON'T LEAVE" },
    "retry": { "ko": "탭하여 계속", "en": "TAP TO CONTINUE" },
    "notebook": { "ko": "수첩", "en": "NOTEBOOK" },
    "shop": { "ko": "상점", "en": "SHOP" },
    "death_fall": { "ko": "떨어졌다", "en": "YOU FELL" },
    "death_lurker": { "ko": "그것이 너를 데려갔다", "en": "IT TOOK YOU" },
    "death_generic": { "ko": "광부 하나가 산에 남았다", "en": "ANOTHER MINER STAYS BELOW" }
  },
  "opening": {
    "arrive": { "ko": "산 아래, 광부 하나가 도착했다.", "en": "At the foot of the mountain, a miner arrives." }
  },
  "ending": {
    "awaken": { "ko": "산이 깨어난다.", "en": "The mountain wakes." },
    "caption": { "ko": "네가 판 것은 산이 아니라, 잠든 것의 살갗이었다.", "en": "What you dug was never a mountain. It was the skin of something asleep." },
    "credits_thanks": { "ko": "IT SLEEPS BELOW — 플레이해 주셔서 감사합니다", "en": "IT SLEEPS BELOW — Thank you for playing" }
  }
}
```

- [ ] **Step 4: gametext.ts 작성**

`src/lib/gametext.ts`:
```ts
import fs from 'node:fs'
import path from 'node:path'

/** games-src/it-sleeps-below/src/core/lore.gd 의 SERIES id와 1:1 동기화.
 *  한쪽을 바꾸면 반드시 다른 쪽도 바꾼다. */
export const JOURNAL_IDS = [
  'han_1', 'baek_1', 'han_2', 'seo_1', 'baek_2',
  'han_3', 'seo_2', 'baek_3', 'seo_3', 'seo_4',
] as const

export interface TextEntry {
  ko: string
  en: string
}
export type GameText = Record<string, Record<string, TextEntry>>

export const GAMETEXT_PATH = path.join(
  process.cwd(), 'public', 'games', 'it-sleeps-below', 'text', 'text.json',
)

export function validateGameText(raw: unknown): GameText {
  if (typeof raw !== 'object' || raw === null) throw new Error('text.json must be an object')
  const doc = raw as GameText
  for (const [cat, entries] of Object.entries(doc)) {
    if (typeof entries !== 'object' || entries === null) throw new Error(`${cat}: must be an object`)
    for (const [key, entry] of Object.entries(entries)) {
      for (const lang of ['ko', 'en'] as const) {
        if (typeof entry[lang] !== 'string' || entry[lang].trim() === '')
          throw new Error(`${cat}.${key}: ${lang} is missing or empty`)
      }
    }
  }
  if (!doc.journals) throw new Error('journals category required')
  for (const id of JOURNAL_IDS) {
    if (!doc.journals[id]) throw new Error(`journal key missing: ${id}`)
  }
  return doc
}

export function getGameText(): GameText {
  return validateGameText(JSON.parse(fs.readFileSync(GAMETEXT_PATH, 'utf-8')))
}

export function updateGameText(raw: unknown): GameText {
  const doc = validateGameText(raw)
  fs.writeFileSync(GAMETEXT_PATH, JSON.stringify(doc, null, 2) + '\n', 'utf-8')
  return doc
}
```

- [ ] **Step 5: API 라우트 확장**

`src/app/api/editor/route.ts` — import에 `updateGameText` 추가:
```ts
import { updateGameText } from '@/lib/gametext'
```
`target === 'game'` 분기 위에 추가:
```ts
    if (body.target === 'gametext') {
      return Response.json({ text: updateGameText(body.patch) })
    }
```
마지막 에러 문구를 `"target은 'game', 'profile', 'gametext' 중 하나여야 합니다."`로 갱신.

- [ ] **Step 6: 에디터 페이지 작성**

`src/app/editor/text/page.tsx`:
```tsx
import { getGameText } from '@/lib/gametext'
import GameTextEditorClient from '@/components/GameTextEditorClient'

/** dev 전용 게임 텍스트 에디터. 프로덕션 가드는 /api/editor가 담당하고,
 *  이 페이지 자체도 프로덕션 빌드에서 노출되면 저장이 404로 거부된다. */
export const dynamic = 'force-dynamic'

export default function GameTextEditorPage() {
  return <GameTextEditorClient initial={getGameText()} />
}
```

`src/components/GameTextEditorClient.tsx`:
```tsx
'use client'
import { useMemo, useState } from 'react'
import type { GameText } from '@/lib/gametext'

/** 카테고리별 목록 + KO/EN 나란히 편집. 저장은 전체 문서 POST — 서버가 검증한다. */
export default function GameTextEditorClient({ initial }: { initial: GameText }) {
  const [doc, setDoc] = useState<GameText>(initial)
  const [cat, setCat] = useState<string>(Object.keys(initial)[0])
  const [status, setStatus] = useState<string>('')
  const keys = useMemo(() => Object.keys(doc[cat] ?? {}), [doc, cat])

  const edit = (key: string, lang: 'ko' | 'en', value: string) =>
    setDoc((d) => ({ ...d, [cat]: { ...d[cat], [key]: { ...d[cat][key], [lang]: value } } }))

  const save = async () => {
    setStatus('저장 중…')
    const res = await fetch('/api/editor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ target: 'gametext', patch: doc }),
    })
    const body = await res.json()
    setStatus(res.ok ? '저장됨' : `오류: ${body.error}`)
  }

  return (
    <main style={{ padding: 24, fontFamily: 'monospace', maxWidth: 960, margin: '0 auto' }}>
      <h1>IT SLEEPS BELOW — 텍스트 에디터</h1>
      <nav style={{ display: 'flex', gap: 8, margin: '16px 0' }}>
        {Object.keys(doc).map((c) => (
          <button key={c} onClick={() => setCat(c)} disabled={c === cat}>{c}</button>
        ))}
      </nav>
      {keys.map((key) => (
        <fieldset key={key} style={{ marginBottom: 12 }}>
          <legend>{key}</legend>
          <textarea rows={4} style={{ width: '48%' }} value={doc[cat][key].ko}
            onChange={(e) => edit(key, 'ko', e.target.value)} />
          <textarea rows={4} style={{ width: '48%', float: 'right' }} value={doc[cat][key].en}
            onChange={(e) => edit(key, 'en', e.target.value)} />
        </fieldset>
      ))}
      <button onClick={save}>저장</button> <span>{status}</span>
    </main>
  )
}
```

- [ ] **Step 7: `npm test` — 통과 확인 + 수동 확인**

```powershell
npm test
```
Expected: gametext 4개 포함 전부 PASS.

수동: `npm run dev` → `http://localhost:3000/editor/text` 접속 → journals 카테고리에서 한 글자 수정 → 저장 → `public/games/it-sleeps-below/text/text.json` diff 확인 → 원복.

- [ ] **Step 8: Commit**

```powershell
git add public/games/it-sleeps-below/text src/lib/gametext.ts src/lib/gametext.test.ts src/app/editor/text src/components/GameTextEditorClient.tsx src/app/api/editor/route.ts
git commit -m "feat(isb): narrative text.json (ko/en) with validation lib and /editor/text page"
```

---

### Task 9: 아트 에셋 생성 — PixelLab

**Files:**
- Create: `scripts/gen_pixellab_isb.py`, 생성물 `games-src/it-sleeps-below/assets/img/*.png`

**Interfaces:**
- Consumes: `.env.local`의 `PIXELLAB_API_KEY`
- Produces: 아래 스프라이트 PNG 전부 (파일명 = 키 이름). 후속 태스크는 `res://assets/img/<이름>.png`로 참조

- [ ] **Step 1: 생성 스크립트 작성**

`scripts/gen_pixellab_isb.py` — `scripts/gen_pixellab.py`와 같은 구조(MIN_AREA 32×32 우회, find_base64, NEAREST 다운스케일 재사용). SPRITES 정의만 교체:

```python
"""PixelLab으로 IT SLEEPS BELOW 스프라이트 생성. 실행: python scripts/gen_pixellab_isb.py [이름...]"""
import base64, io, json, os, sys, time, urllib.request

from PIL import Image

MIN_AREA = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "it-sleeps-below", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro game sprite, dark cave palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding, gore, blood"

SPRITES = {
    # 광부 (16x16 프레임별 생성 — 동일 문구 접두로 스타일 고정)
    "miner_idle":   (16, 16, f"small miner in brown overalls holding lantern, standing, warm lamp glow, {STYLE}"),
    "miner_walk1":  (16, 16, f"small miner in brown overalls holding lantern, walking left foot forward, {STYLE}"),
    "miner_walk2":  (16, 16, f"small miner in brown overalls holding lantern, walking right foot forward, {STYLE}"),
    "miner_climb1": (16, 16, f"small miner in brown overalls climbing rock wall, reaching up left arm, seen from behind, {STYLE}"),
    "miner_climb2": (16, 16, f"small miner in brown overalls climbing rock wall, reaching up right arm, seen from behind, {STYLE}"),
    "miner_dig1":   (16, 16, f"small miner in brown overalls swinging pickaxe raised, {STYLE}"),
    "miner_dig2":   (16, 16, f"small miner in brown overalls pickaxe striking down, small debris, {STYLE}"),
    "miner_death":  (16, 16, f"small miner in brown overalls collapsed on ground, dropped lantern dim, {STYLE}"),
    # '그것' — 키가 너무 큰 광부 실루엣 (16x32) + 램프
    "lurker":       (16, 32, f"unnaturally tall thin miner silhouette, pitch black body, faintly glowing pale green lantern held low, elongated limbs, no face, unsettling, {STYLE}"),
    "lurker_frozen":(16, 32, f"unnaturally tall thin miner silhouette frozen mid-step, pitch black, pale green lantern, rigid pose, {STYLE}"),
    # 지층 타일 (16x16)
    "tile_dirt":    (16, 16, f"seamless brown soil block texture with small pebbles, {STYLE}"),
    "tile_rock":    (16, 16, f"seamless dark blue-grey bedrock block texture, {STYLE}"),
    "tile_deep":    (16, 16, f"seamless dark purple cracked rock texture, faint vein patterns like blood vessels, wrong-looking, {STYLE}"),
    "tile_flesh":   (16, 16, f"seamless dark crimson organic rock texture, subtle rib-like ridges, breathing surface, disturbing but not gory, {STYLE}"),
    "tile_crack":   (16, 16, f"cracked fragile rock block with visible fracture lines, about to collapse, {STYLE}"),
    "tile_border":  (16, 16, f"impenetrable obsidian black rock block, dense, {STYLE}"),
    "tile_bg":      (16, 16, f"very dark excavated tunnel background wall, subtle depth, almost black, {STYLE}"),
    # 광석 7종 + 심장 + 픽업 (16x16)
    "ore_coal":     (16, 16, f"coal chunks embedded in rock block, matte black lumps, {STYLE}"),
    "ore_copper":   (16, 16, f"copper ore embedded in rock block, orange metallic specks, {STYLE}"),
    "ore_iron":     (16, 16, f"iron ore embedded in rock block, silver-grey metallic specks, {STYLE}"),
    "ore_silver":   (16, 16, f"silver ore embedded in rock block, bright white metallic veins, {STYLE}"),
    "ore_gold":     (16, 16, f"gold ore embedded in rock block, warm yellow glittering veins, {STYLE}"),
    "ore_amethyst": (16, 16, f"amethyst crystals embedded in rock block, purple glowing crystals, {STYLE}"),
    "ore_glow":     (16, 16, f"pulsing pink glowing ore embedded in dark rock, heartbeat glow, organic, {STYLE}"),
    "heart":        (48, 48, f"giant pulsing crystal heart embedded in flesh-like rock, pink inner glow, veins spreading outward, majestic and terrifying, {STYLE}"),
    "oil_bottle":   (16, 16, f"small glass bottle of golden lamp oil with cork, {STYLE}"),
    "journal":      (16, 16, f"weathered leather journal with strap on cave floor, {STYLE}"),
    "relic_bag":    (16, 16, f"abandoned worn leather mining bag with rope handle, sitting upright, {STYLE}"),
    # 거점/로어 오브젝트
    "merchant":     (24, 24, f"hooded merchant figure sitting by small stall, face hidden in shadow, single visible pale eye glint, {STYLE}"),
    "tent":         (32, 24, f"abandoned weathered canvas mining tent, slightly torn, {STYLE}"),
    "lamp_ui":      (16, 16, f"brass miner lantern icon, warm flame, ui icon, {STYLE}"),
    "heart_ui":     (8, 8, f"tiny pixel heart icon, red, ui, {STYLE}"),
    # 원경 2버전 (수미상관) + 로고
    "vista_calm":   (135, 80, f"distant mountain landscape at dusk, single dark mountain silhouette, tiny camp light at base, quiet somber sky, {STYLE}"),
    "vista_alive":  (135, 80, f"endless mountain range at night, every peak faintly pulsing with pink inner light like hearts, mountains subtly breathing, cosmic horror scale, {STYLE}"),
    "logo":         (96, 48, f"game logo text style carved stone letters IT SLEEPS BELOW, moss and cracks, faint pink glow from cracks, {STYLE}"),
}
```
`read_key / find_base64 / generate / main` 함수는 `scripts/gen_pixellab.py`에서 그대로 복사한다 (OUT 경로만 다름).

- [ ] **Step 2: 실행**

```powershell
python scripts/gen_pixellab_isb.py
```
Expected: `OK <이름> -> ...png` × 34. 실패 항목은 개별 재실행(`python scripts/gen_pixellab_isb.py lurker`). 결과 품질이 나쁜 항목은 프롬프트를 다듬어 재생성 — **프롬프트 수정은 이 스크립트 파일에 반영해 커밋** (재현 가능성).

- [ ] **Step 3: 검수 체크리스트**

- `vista_calm`과 `vista_alive`는 같은 구도로 읽히는가 (수미상관) — 아니면 vista_alive 프롬프트에 "same composition as a single mountain view" 추가 후 재생성
- `lurker`가 16×32에서 실루엣으로 읽히는가
- 타일 4종을 나란히 놓았을 때 지층 진행(흙→암반→균열→살)이 느껴지는가
- 고어 금지 확인 (NEG에 gore, blood 포함됨)

- [ ] **Step 4: Commit**

```powershell
git add scripts/gen_pixellab_isb.py games-src/it-sleeps-below/assets/img
git commit -m "feat(isb): PixelLab art assets — miner, lurker, strata tiles, ores, vistas"
```

---

### Task 10: 오디오 생성 — VARCO Sound

**Files:**
- Create: `scripts/gen_audio_isb.py`, 생성물 `games-src/it-sleeps-below/assets/sfx/*.ogg`
- Modify: `games-src/it-sleeps-below/CREDITS.md` (라이선스 확정 문구)

**Interfaces:**
- Consumes: `.env.local`의 `VARCO_API_KEY`, ffmpeg(경로에 있어야 함)
- Produces: 아래 사운드 ogg 전부. `Sfx` 오토로드(Task 11)는 `res://assets/sfx/<이름>.ogg`로 로드

- [ ] **Step 1: ffmpeg 확인**

```powershell
ffmpeg -version
```
Expected: 버전 출력. 없으면 `winget install Gyan.FFmpeg` 후 새 셸에서 재확인.

- [ ] **Step 2: 생성 스크립트 작성**

`scripts/gen_audio_isb.py`:
```python
"""VARCO Sound로 IT SLEEPS BELOW 오디오 생성.
실행: python scripts/gen_audio_isb.py [이름...]
- text2sound: 프롬프트 -> 10초 WAV (base64)
- looping: 앰비언트를 심리스 루프로 변환
- ffmpeg: 트리밍 + ogg 인코딩 (wav는 커밋하지 않는다)
"""
import base64, json, os, subprocess, sys, tempfile, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "it-sleeps-below", "assets", "sfx")
T2S = "https://openapi.ai.nc.com/sound/varco/v1/api/text2sound"
LOOP = "https://openapi.ai.nc.com/sound/varco/v1/api/looping"

# (프롬프트, loop 여부, 최대 길이 초 — 0이면 자동 트림 없이 전체)
SOUNDS = {
    # ── SFX (트림) ──
    "dig_dirt":    ("shovel digging into soft soil, single strike, short", False, 0.8),
    "dig_rock":    ("pickaxe striking hard rock, single sharp impact with small debris, short", False, 0.8),
    "dig_flesh":   ("pickaxe striking something dense and wet, muffled organic thud, unsettling, short", False, 0.8),
    "ore_pickup":  ("small crystal chime pickup, bright short glassy note", False, 0.6),
    "land":        ("soft thud of boots landing on stone, short", False, 0.5),
    "fall_hurt":   ("heavy body impact on rock with grunt-like air burst, no voice, short", False, 0.7),
    "rockfall":    ("rocks crumbling and falling in a cave, collapse rumble, short", False, 1.5),
    "lamp_toggle": ("old brass lantern metal click and small flame whoosh, very short", False, 0.4),
    "lamp_flicker":("oil lamp flame sputtering and flickering, short", False, 0.8),
    "oil_warning": ("low ominous single bell tone, muffled, short", False, 1.0),
    "climb":       ("hands and boots scraping on rock wall, single scrape, short", False, 0.5),
    "settle":      ("coins pouring onto wooden table, cheerful short jingle", False, 1.2),
    "journal_get": ("old paper page turning with soft dusty rustle, short", False, 0.8),
    "whisper":     ("faint unintelligible whisper echoing in a cave, breathy, creepy, short", False, 2.0),
    "echo_pick":   ("distant pickaxe echo in deep cave, two delayed strikes, eerie", False, 2.0),
    "steps_wall":  ("muffled footsteps behind a stone wall walking in rhythm, unsettling", False, 2.5),
    "heartbeat":   ("slow deep heartbeat thumping, organic, ominous", True, 0),
    "awaken":      ("massive deep rumble of a mountain waking, sub bass groan rising, terrifying", False, 6.0),
    "pulse":       ("single deep organic heart pulse with pink glow feeling, sub bass thump", False, 1.5),
    # ── 앰비언트 (looping API로 루프화) ──
    "amb_surface": ("quiet mountain camp at dusk, soft wind, sparse distant birds, lonely", True, 0),
    "amb_rock":    ("deep cave ambience, water droplets echoing, distant hollow drips", True, 0),
    "amb_fissure": ("very low ominous drone in deep cave, faint sub bass hum, oppressive silence", True, 0),
    "amb_finale":  ("deep pulsing organic drone, heartbeat rhythm inside living cavern, dread", True, 0),
    "bgm_camp":    ("slow melancholic music box lullaby, sparse notes, quiet and slightly sad", True, 0),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("VARCO_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("VARCO_API_KEY not found in .env.local")

def call(url, payload, key):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST",
        headers={"OPENAPI_KEY": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)

def first_audio(data):
    if isinstance(data, list):
        return data[0]["audio"]
    return data["audio"]

def generate(key, name, prompt, loop, max_len):
    data = call(T2S, {"prompt": prompt, "num_sample": 1}, key)
    wav = base64.b64decode(first_audio(data))
    if loop:
        data = call(LOOP, {"source": base64.b64encode(wav).decode()}, key)
        wav = base64.b64decode(data["audio"])
    os.makedirs(OUT, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tf.write(wav)
        tmp = tf.name
    ogg = os.path.join(OUT, f"{name}.ogg")
    cmd = ["ffmpeg", "-y", "-i", tmp]
    if not loop and max_len > 0:
        # 선행 무음 제거 후 max_len으로 컷
        cmd += ["-af", "silenceremove=start_periods=1:start_threshold=-45dB", "-t", str(max_len)]
    cmd += ["-c:a", "libvorbis", "-qscale:a", "4", ogg]
    subprocess.run(cmd, check=True, capture_output=True)
    os.unlink(tmp)
    print(f"OK {name} -> {ogg}")

def main():
    key = read_key()
    targets = sys.argv[1:] or list(SOUNDS)
    for name in targets:
        prompt, loop, max_len = SOUNDS[name]
        generate(key, name, prompt, loop, max_len)
        time.sleep(1)

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: 실행 + 검수**

```powershell
python scripts/gen_audio_isb.py
```
Expected: `OK <이름> -> ...ogg` × 24. 실패 시 응답 본문을 출력해 원인 확인(크레딧 부족/키 오류/스키마 차이 — `first_audio`가 리스트·딕셔너리 둘 다 다루지만, 다른 구조면 스크립트의 해당 함수를 응답에 맞춰 수정하고 커밋).

검수: 각 ogg를 재생해 (1) SFX가 잘려 있지 않은지 (2) 루프 앰비언트의 이음새가 매끄러운지 (3) `dig_flesh`·`whisper`가 고어하지 않고 불쾌-불안 톤인지. 어색한 항목은 프롬프트 수정 후 개별 재생성.

- [ ] **Step 4: 총 용량 확인**

```powershell
Get-ChildItem "games-src\it-sleeps-below\assets\sfx" | Measure-Object -Property Length -Sum | ForEach-Object { "{0:N1} MB" -f ($_.Sum / 1MB) }
```
Expected: 5MB 미만. 초과 시 `-qscale:a`를 3으로 낮춰 재인코딩.

- [ ] **Step 5: CREDITS 갱신 + Commit**

VARCO 이용약관(terms.varco.ai)에서 생성물 상업 이용 조건을 확인하고 `CREDITS.md`의 사운드 줄을 확정 문구로 교체한다 (예: "사운드: VARCO Sound(NC AI) 생성 — 상업 이용 허용 조건 명시"). 조건이 불명확하면 support-ncai@ncsoft.com 문의를 팔로업으로 남기고 진행.

```powershell
git add scripts/gen_audio_isb.py games-src/it-sleeps-below/assets/sfx games-src/it-sleeps-below/CREDITS.md
git commit -m "feat(isb): VARCO Sound audio — sfx, looped ambience, camp music box"
```

---

### Task 11: 갱도 씬 — 이동·채굴·중력·픽업 + Sfx/TextDb

**Files:**
- Create: `games-src/it-sleeps-below/src/core/move_rules.gd`, `src/core/text_db.gd`, `src/mine.gd`, `src/mine_view.gd`, `src/player.gd`
- Modify: `src/core/sfx.gd`(스텁 → 구현), `src/main.gd`(임시 부팅: 갱도 직행), `project.godot`(오토로드 `TextDb` 추가)
- Test: `tests/test_move_rules.gd`

**Interfaces:**
- Consumes: `WorldGen`, `Economy`, `Oil`, `Tuning`, `GameState`
- Produces:
  - `MoveRules.A_BLOCKED=0, A_WALK=1, A_CLIMB=2, A_DIG=3`
  - `MoveRules.classify(cells: PackedInt32Array, pos: Vector2i, dir: Vector2i, pick_level: int) -> int`
  - `MoveRules.passable(c: int) -> bool` (T_EMPTY만)
  - `MoveRules.fall_landing(cells: PackedInt32Array, pos: Vector2i) -> Vector2i` — 낙하 착지점
  - `Sfx.play(name: String)` / `Sfx.ambience(name: String)` (크로스 전환, ""이면 정지) / `Sfx.heartbeat(rate: float)` (0이면 정지)
  - `TextDb.t(cat: String, key: String) -> String` — 프로필 언어 반영, 미로드/미존재 시 `"[cat.key]"` / `TextDb.loaded: bool` / signal `text_loaded`
  - `Mine` 씬(코드 조립): signal `run_ended(reason: String, depth: int)` (reason: "death_fall"|"death_lurker"|"surfaced"|"finale_escaped"(Task 15)), `노드 구성: MineView / Player / (Task 12) LightRig·HUD / (Task 13) Lurker·AnomalyDirector`
  - `Mine.noise_event(pos: Vector2i, level: float)` — 채굴 소음 발생 시 내부 브로드캐스트 (Task 13의 러커가 구독)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_move_rules.gd`:
```gdscript
extends GdUnitTestSuite

func _world() -> PackedInt32Array:
	var cells := PackedInt32Array()
	cells.resize(WorldGen.W * WorldGen.DEPTH)
	cells.fill(WorldGen.T_DIRT)
	for y in range(WorldGen.DEPTH):
		cells[WorldGen.idx(0, y)] = WorldGen.T_BORDER
		cells[WorldGen.idx(WorldGen.W - 1, y)] = WorldGen.T_BORDER
	# (5,10)~(5,12) 수직 통로
	for y in range(10, 13):
		cells[WorldGen.idx(5, y)] = WorldGen.T_EMPTY
	return cells

func test_walk_into_empty() -> void:
	var c := _world()
	c[WorldGen.idx(6, 10)] = WorldGen.T_EMPTY
	assert_int(MoveRules.classify(c, Vector2i(5, 10), Vector2i(1, 0), 1)).is_equal(MoveRules.A_WALK)

func test_climb_up_empty() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(5, 12), Vector2i(0, -1), 1)).is_equal(MoveRules.A_CLIMB)

func test_dig_solid_with_gate() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(5, 10), Vector2i(1, 0), 1)).is_equal(MoveRules.A_DIG)
	# 암반(row 80)은 곡괭이 Lv1로 못 판다
	var c := _world()
	c[WorldGen.idx(5, 80)] = WorldGen.T_EMPTY
	assert_int(MoveRules.classify(c, Vector2i(5, 80), Vector2i(1, 0), 1)).is_equal(MoveRules.A_BLOCKED)
	assert_int(MoveRules.classify(c, Vector2i(5, 80), Vector2i(1, 0), 2)).is_equal(MoveRules.A_DIG)

func test_border_blocked() -> void:
	assert_int(MoveRules.classify(_world(), Vector2i(1, 10), Vector2i(-1, 0), 4)).is_equal(MoveRules.A_BLOCKED)

func test_fall_landing() -> void:
	var c := _world()
	for y in range(10, 20):
		c[WorldGen.idx(7, y)] = WorldGen.T_EMPTY
	assert_that(MoveRules.fall_landing(c, Vector2i(7, 10))).is_equal(Vector2i(7, 19))
	assert_that(MoveRules.fall_landing(_world(), Vector2i(5, 12))).is_equal(Vector2i(5, 12))
```

- [ ] **Step 2: runtest — 실패 확인**

Expected: `MoveRules` 미정의 FAIL.

- [ ] **Step 3: move_rules.gd 구현**

`src/core/move_rules.gd`:
```gdscript
class_name MoveRules
## 인접 탭 → 행동 분류. 순수 함수.

const A_BLOCKED := 0
const A_WALK := 1
const A_CLIMB := 2
const A_DIG := 3

static func passable(c: int) -> bool:
	return c == WorldGen.T_EMPTY

static func classify(cells: PackedInt32Array, pos: Vector2i, dir: Vector2i, pick_level: int) -> int:
	var t := pos + dir
	if t.x < 1 or t.x > WorldGen.W - 2 or t.y < 0 or t.y >= WorldGen.DEPTH:
		return A_BLOCKED
	var c := cells[WorldGen.idx(t.x, t.y)]
	if c == WorldGen.T_BORDER:
		return A_BLOCKED
	if passable(c):
		return A_CLIMB if dir.y < 0 else A_WALK
	if not Economy.dig_allowed(pick_level, t.y):
		return A_BLOCKED
	return A_DIG

static func fall_landing(cells: PackedInt32Array, pos: Vector2i) -> Vector2i:
	var p := pos
	while p.y + 1 < WorldGen.DEPTH and passable(cells[WorldGen.idx(p.x, p.y + 1)]):
		p.y += 1
	return p
```

- [ ] **Step 4: Sfx / TextDb 구현 + 오토로드 등록**

`src/core/sfx.gd` (스텁 교체):
```gdscript
extends Node
## 사운드 재생 — 이름으로 재생, 앰비언트 1채널, 심박 1채널.

var _players: Array[AudioStreamPlayer] = []
var _amb := AudioStreamPlayer.new()
var _beat := AudioStreamPlayer.new()
var _amb_name := ""

func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	add_child(_amb)
	add_child(_beat)
	_amb.volume_db = -6.0

func _stream(name: String) -> AudioStream:
	var path := "res://assets/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func play(name: String) -> void:
	var s := _stream(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.play()
			return

func ambience(name: String) -> void:
	if name == _amb_name:
		return
	_amb_name = name
	if name == "":
		_amb.stop()
		return
	var s := _stream(name)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	_amb.stream = s
	_amb.play()

func heartbeat(rate: float) -> void:
	if rate <= 0.0:
		_beat.stop()
		return
	if not _beat.playing:
		var s := _stream("heartbeat")
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			s.loop = true
		_beat.stream = s
		_beat.play()
	_beat.pitch_scale = clampf(rate, 0.8, 2.2)
```

`src/core/text_db.gd`:
```gdscript
extends Node
## 서사 텍스트 — 게임 팩 외부 text.json 런타임 로드 (스펙 §15).

signal text_loaded

var loaded := false
var _doc: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("web"):
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(_on_http)
		req.request("text/text.json")
	else:
		var path := ProjectSettings.globalize_path("res://").path_join("../../public/games/it-sleeps-below/text/text.json")
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			_parse(f.get_as_text())

func _on_http(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		_parse(body.get_string_from_utf8())

func _parse(raw: String) -> void:
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) == TYPE_DICTIONARY:
		_doc = data
		loaded = true
		text_loaded.emit()

func t(cat: String, key: String) -> String:
	var lang: String = GameState.profile.settings.lang
	if _doc.has(cat) and _doc[cat].has(key) and _doc[cat][key].has(lang):
		return _doc[cat][key][lang]
	return "[%s.%s]" % [cat, key]
```

`project.godot` [autoload] 섹션에 추가 (GameState보다 뒤):
```ini
TextDb="*res://src/core/text_db.gd"
```

- [ ] **Step 5: Player / MineView / Mine 구현**

`src/player.gd`:
```gdscript
class_name Player
extends Node2D
## 광부 비주얼 — 그리드 좌표는 Mine이 관리, 여기는 표시·애니만.

var sprites := {}
var _frame := 0
var _anim := "idle"
var _t := 0.0

func _ready() -> void:
	for n in ["idle", "walk1", "walk2", "climb1", "climb2", "dig1", "dig2", "death"]:
		sprites[n] = load("res://assets/img/miner_%s.png" % n)
	z_index = 10

func set_anim(anim: String) -> void:
	_anim = anim
	_t = 0.0

func _process(delta: float) -> void:
	_t += delta
	_frame = int(_t / 0.14) % 2
	queue_redraw()

func _draw() -> void:
	var tex: Texture2D
	match _anim:
		"walk": tex = sprites["walk1"] if _frame == 0 else sprites["walk2"]
		"climb": tex = sprites["climb1"] if _frame == 0 else sprites["climb2"]
		"dig": tex = sprites["dig1"] if _frame == 0 else sprites["dig2"]
		"death": tex = sprites["death"]
		_: tex = sprites["idle"]
	draw_texture(tex, Vector2(-8, -8))
```

`src/mine_view.gd`:
```gdscript
class_name MineView
extends Node2D
## 보이는 타일만 그린다 + 미탐사 완전 검정 (fog). TileSet 리소스 대신 직접 드로우.

var cells: PackedInt32Array
var explored: Dictionary = {}
var camera_row := 0
var _tex := {}

const ORE_TEX := ["ore_coal", "ore_copper", "ore_iron", "ore_silver", "ore_gold", "ore_amethyst", "ore_glow"]

func _ready() -> void:
	for n in ["tile_dirt", "tile_rock", "tile_deep", "tile_flesh", "tile_crack", "tile_border", "tile_bg",
			"oil_bottle", "journal", "relic_bag", "heart"] + ORE_TEX:
		_tex[n] = load("res://assets/img/%s.png" % n)

func tile_texture(c: int, row: int) -> Texture2D:
	if c >= WorldGen.ORE_BASE:
		return _tex[ORE_TEX[c - WorldGen.ORE_BASE]]
	match c:
		WorldGen.T_DIRT: return _tex["tile_dirt"]
		WorldGen.T_ROCK: return _tex["tile_rock"]
		WorldGen.T_DEEP: return _tex["tile_deep"]
		WorldGen.T_FLESH: return _tex["tile_flesh"]
		WorldGen.T_CRACK: return _tex["tile_crack"]
		WorldGen.T_BORDER: return _tex["tile_border"]
		WorldGen.T_OIL: return _tex["oil_bottle"]
		WorldGen.T_JOURNAL: return _tex["journal"]
		WorldGen.T_RELIC: return _tex["relic_bag"]
		WorldGen.T_HEART: return _tex["heart"]
	return null

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if cells == null or cells.is_empty():
		return
	var top: int = maxi(0, camera_row - 16)
	var bottom: int = mini(WorldGen.DEPTH - 1, camera_row + 17)
	for y in range(top, bottom + 1):
		for x in range(WorldGen.W):
			var pos := Vector2(x * Tuning.TILE_PX, y * Tuning.TILE_PX)
			var c := cells[WorldGen.idx(x, y)]
			if not explored.has(Vector2i(x, y)):
				draw_rect(Rect2(pos, Vector2(16, 16)), Color.BLACK)
				continue
			if c == WorldGen.T_EMPTY:
				draw_texture(_tex["tile_bg"], pos)
			else:
				var t := tile_texture(c, y)
				if t:
					if c == WorldGen.T_OIL or c == WorldGen.T_JOURNAL or c == WorldGen.T_RELIC:
						draw_texture(_tex["tile_bg"], pos)  # 픽업은 배경 위에
					draw_texture(t, pos)

func reveal(center: Vector2i, radius: float) -> void:
	var r := int(ceilf(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() <= radius + 0.5:
				explored[center + Vector2i(dx, dy)] = true
```

`src/mine.gd`:
```gdscript
class_name Mine
extends Node2D
## 갱도 컨트롤러 — 입력, 채굴/이동/중력, 기름, 픽업, 죽음. 러커·이상현상은 Task 13에서 붙인다.

signal run_ended(reason: String, depth: int)
signal noise_event(pos: Vector2i, level: float)
signal journal_found(id: String)
signal strata_entered(strata: int)

var cells: PackedInt32Array
var journal_spots: Array = []
var view: MineView
var player: Player
var camera: Camera2D

var ppos := Vector2i(8, 0)
var busy := false
var lamp_on := true
var oil := 0.0
var hearts := 3
var held_dir := Vector2i.ZERO
var _last_dig_end := -10.0
var _last_strata := -1
var alive := true

func _ready() -> void:
	var ctx: Dictionary = GameState.start_run()
	var g := WorldGen.generate(GameState.run.seed, ctx)
	cells = g.cells
	journal_spots = g.journal_spots
	oil = GameState.run.oil
	hearts = GameState.run.hearts

	view = MineView.new()
	view.cells = cells
	add_child(view)
	player = Player.new()
	add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	_sync_positions(true)

func light_radius() -> float:
	return Oil.radius(oil, Oil.tank(GameState.profile.upgrades.lamp), lamp_on)

func is_open_cell(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= WorldGen.W or p.y < 0 or p.y >= WorldGen.DEPTH:
		return false
	return MoveRules.passable(cells[WorldGen.idx(p.x, p.y)])

func bag_capacity() -> int:
	# 기름병은 가방 슬롯을 차지한다 — 보험 한 칸 = 광석 한 칸 (스펙 §10)
	return Economy.bag_slots(GameState.profile.upgrades.bag) - GameState.run.bottles

func _process(delta: float) -> void:
	if not alive:
		return
	oil = Oil.drain(oil, delta, lamp_on)
	if oil <= 0.0 and GameState.run.bottles > 0:
		GameState.run.bottles -= 1
		oil = Oil.tank(GameState.profile.upgrades.lamp) * Tuning.OIL_PICKUP_RATIO
		Sfx.play("lamp_toggle")
	GameState.run.oil = oil
	view.reveal(ppos, light_radius())
	view.camera_row = ppos.y
	if held_dir != Vector2i.ZERO and not busy:
		_try_move(held_dir)
	var s := WorldGen.strata_of(ppos.y)
	if s != _last_strata:
		_last_strata = s
		strata_entered.emit(s)
		Sfx.ambience(["amb_surface", "amb_rock", "amb_fissure", "", ""][mini(s, 4)])

func toggle_lamp() -> void:
	lamp_on = not lamp_on
	GameState.run.lamp_on = lamp_on
	Sfx.play("lamp_toggle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: toggle_lamp()
			KEY_LEFT, KEY_A: held_dir = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D: held_dir = Vector2i(1, 0)
			KEY_UP, KEY_W: held_dir = Vector2i(0, -1)
			KEY_DOWN, KEY_S: held_dir = Vector2i(0, 1)
	elif event is InputEventKey and not event.pressed:
		held_dir = Vector2i.ZERO
	elif event is InputEventMouseButton:
		if event.pressed:
			var world := get_canvas_transform().affine_inverse() * event.position
			var tile := Vector2i(int(world.x / 16.0), int(world.y / 16.0))
			var d := tile - ppos
			if abs(d.x) + abs(d.y) == 1:
				held_dir = d
		else:
			held_dir = Vector2i.ZERO

func _try_move(dir: Vector2i) -> void:
	var act := MoveRules.classify(cells, ppos, dir, GameState.profile.upgrades.pick)
	match act:
		MoveRules.A_WALK, MoveRules.A_CLIMB:
			_step(ppos + dir, act)
		MoveRules.A_DIG:
			_dig(ppos + dir)
		_:
			pass

func _step(target: Vector2i, act: int) -> void:
	busy = true
	player.set_anim("climb" if act == MoveRules.A_CLIMB else "walk")
	if act == MoveRules.A_CLIMB:
		Sfx.play("climb")
	var dur := Tuning.CLIMB_TIME if act == MoveRules.A_CLIMB else Tuning.WALK_TIME
	var tw := create_tween()
	tw.tween_property(player, "position", Vector2(target * 16) + Vector2(8, 8), dur)
	await tw.finished
	ppos = target
	GameState.run.depth = maxi(GameState.run.depth, ppos.y)
	_after_move()

func _dig(target: Vector2i) -> void:
	busy = true
	player.set_anim("dig")
	var strata_row: int = target.y
	# 조심 채굴 판정은 채굴 "시작" 시점의 간격으로 — 홀드 연속은 간격≈0이라 항상 LOUD,
	# 끊어 파기(직전 채굴 종료 후 QUIET_GAP 이상 쉼)만 QUIET (스펙 §11)
	var gap := Time.get_ticks_msec() / 1000.0 - _last_dig_end
	var level: float = Tuning.NOISE_QUIET if gap >= Tuning.QUIET_GAP else Tuning.NOISE_LOUD
	await get_tree().create_timer(Economy.dig_time(GameState.profile.upgrades.pick, strata_row)).timeout
	_last_dig_end = Time.get_ticks_msec() / 1000.0
	noise_event.emit(target, level)
	_collect(target)
	cells[WorldGen.idx(target.x, target.y)] = WorldGen.T_EMPTY
	view.cells = cells
	var s: int = mini(WorldGen.strata_of(strata_row), 3)
	Sfx.play(["dig_dirt", "dig_rock", "dig_rock", "dig_flesh"][s])
	_after_move()

func _collect(target: Vector2i) -> void:
	var c := cells[WorldGen.idx(target.x, target.y)]
	if c >= WorldGen.ORE_BASE:
		if GameState.run.bag.size() < bag_capacity():
			GameState.run.bag.append(c - WorldGen.ORE_BASE)
			Sfx.play("ore_pickup")
	elif c == WorldGen.T_OIL:
		oil = minf(Oil.tank(GameState.profile.upgrades.lamp), oil + Oil.tank(GameState.profile.upgrades.lamp) * Tuning.OIL_PICKUP_RATIO)
		Sfx.play("ore_pickup")
	elif c == WorldGen.T_JOURNAL:
		for spot in journal_spots:
			if Vector2i(spot.x, spot.y) == target and not GameState.profile.journals_found.has(spot.id):
				GameState.profile.journals_found.append(spot.id)
				GameState.save()
				Sfx.play("journal_get")
				journal_found.emit(spot.id)
	elif c == WorldGen.T_RELIC:
		for item in GameState.profile.relic.get("items", []):
			if GameState.run.bag.size() < bag_capacity():
				GameState.run.bag.append(int(item))
		GameState.profile.relic = {}
		GameState.save()
		Sfx.play("ore_pickup")

func _after_move() -> void:
	player.set_anim("idle")
	# 금 간 타일 — 머리 위가 CRACK이면 0.4초 뒤 붕괴 (그 자리에 있으면 데미지)
	var above := ppos + Vector2i(0, -1)
	if is_open_cell(ppos) and cells[WorldGen.idx(above.x, above.y)] == WorldGen.T_CRACK:
		var crack_pos := above
		var stood_at := ppos
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if cells[WorldGen.idx(crack_pos.x, crack_pos.y)] != WorldGen.T_CRACK:
				return
			cells[WorldGen.idx(crack_pos.x, crack_pos.y)] = WorldGen.T_EMPTY
			view.cells = cells
			Sfx.play("rockfall")
			if ppos == stood_at and alive:
				_damage(1, "death_fall"))
	# 중력
	var land := MoveRules.fall_landing(cells, ppos)
	if land != ppos:
		var fall := land.y - ppos.y
		var tw := create_tween()
		tw.tween_property(player, "position", Vector2(land * 16) + Vector2(8, 8), Tuning.FALL_TIME * fall)
		await tw.finished
		ppos = land
		GameState.run.depth = maxi(GameState.run.depth, ppos.y)
		Sfx.play("land")
		if fall > Economy.fall_tolerance(GameState.profile.upgrades.boots):
			_damage(1, "death_fall")
	_sync_positions(false)
	# 지표 복귀
	if ppos.y == 0 and alive:
		alive = false
		run_ended.emit("surfaced", GameState.run.depth)
		return
	busy = false

func _damage(n: int, reason: String) -> void:
	hearts -= n
	GameState.run.hearts = hearts
	Sfx.play("fall_hurt")
	if hearts <= 0:
		die(reason)

func die(reason: String) -> void:
	if not alive:
		return
	alive = false
	player.set_anim("death")
	GameState.end_run_death(GameState.run.depth)
	await get_tree().create_timer(1.2).timeout
	run_ended.emit(reason, GameState.run.depth)

func _sync_positions(snap: bool) -> void:
	var p := Vector2(ppos * 16) + Vector2(8, 8)
	player.position = p
	camera.position = Vector2(WorldGen.W * 8, p.y)
	if snap:
		camera.reset_smoothing()
```

`src/main.gd` (임시 — Task 14에서 상태 머신으로 교체):
```gdscript
extends Node2D

func _ready() -> void:
	var mine := Mine.new()
	add_child(mine)
	mine.run_ended.connect(func(reason: String, depth: int) -> void:
		print("run ended: ", reason, " @", depth, "m")
		get_tree().reload_current_scene())
```

- [ ] **Step 6: runtest + 수동 스모크**

runtest — Expected: 전부 passed (move_rules 5개 포함).
수동: `& $GODOT --path games-src/it-sleeps-below` 실행 → 방향키로 파며 내려가기·클라이밍 복귀·Space 램프 토글·광석 획득이 동작하는지, 마우스 클릭 탭도 동일한지 확인. (조명은 다음 태스크라 아직 화면 전체가 보임 — fog만 동작)

- [ ] **Step 7: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): mine scene — tap/hold movement, dig, gravity, pickups, sfx, runtime text db"
```

---

### Task 12: 조명 + HUD

**Files:**
- Create: `games-src/it-sleeps-below/src/light_rig.gd`, `src/hud.gd`
- Modify: `src/mine.gd` (LightRig·HUD 부착, 죽음 메시지 연동)

**Interfaces:**
- Consumes: `Mine`(oil/lamp_on/light_radius/hearts/bag/depth), `TextDb`, `Oil`
- Produces:
  - `LightRig` — `CanvasModulate`(암전 `Color(0.08,0.07,0.12)`) + 플레이어 추적 `PointLight2D`(코드 생성 라디얼 그라데이션 텍스처, 반경 = `light_radius()` 타일×16px, 0.12s 러프 추종 + 3% 진폭 깜빡임). `set_radius_tiles(r: float)`
  - `HUD` — `CanvasLayer`: 상단 중앙 램프 게이지(오프 시 잿빛), 좌상 하트, 우상 가방 n/슬롯, 우측 깊이 m, 좌하 램프 토글 버튼(64px 터치 타깃), 지층 진입 배너(2초 페이드), 일시정지 버튼 + 포커스 상실 자동 일시정지(`NOTIFICATION_APPLICATION_FOCUS_OUT`). `flash_bag_full()`
  - 폰트: `assets/fonts/Galmuri9.ttf` 사용, UI 라벨은 TextDb의 `ui.*`

- [ ] **Step 1: light_rig.gd 구현**

`src/light_rig.gd`:
```gdscript
class_name LightRig
extends Node2D
## 화면 암전 + 플레이어 라디얼 라이트. 반경 변화는 러프하게 따라간다.

var light := PointLight2D.new()
var modulate_node := CanvasModulate.new()
var _target_scale := 1.0
var _flicker := 0.0

func _ready() -> void:
	modulate_node.color = Color(0.08, 0.07, 0.12)
	add_child(modulate_node)
	light.texture = _radial_texture(128)
	light.energy = 1.3
	add_child(light)

func _radial_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 0.95, 0.85, pow(a, 1.5)))
	return ImageTexture.create_from_image(img)

func set_radius_tiles(r: float) -> void:
	_target_scale = r * Tuning.TILE_PX * 2.0 / 128.0

func follow(pos: Vector2) -> void:
	light.position = pos

func _process(delta: float) -> void:
	_flicker += delta * 7.0
	var flick := 1.0 + sin(_flicker) * 0.03
	light.scale = light.scale.lerp(Vector2.ONE * _target_scale * flick, minf(1.0, delta * 8.0))

func blackout(sec: float) -> void:
	var prev := light.energy
	light.energy = 0.05
	await get_tree().create_timer(sec).timeout
	light.energy = prev
```

- [ ] **Step 2: hud.gd 구현**

`src/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## 최소주의 HUD — 갱도에서는 생존 정보만 (스펙 §12).

signal lamp_pressed
signal pause_pressed

var oil_bar := ColorRect.new()
var oil_back := ColorRect.new()
var hearts_label := Label.new()
var bag_label := Label.new()
var depth_label := Label.new()
var strata_banner := Label.new()
var lamp_btn := Button.new()
var pause_btn := Button.new()
var _font: FontFile

func _ready() -> void:
	_font = load("res://assets/fonts/Galmuri9.ttf")
	oil_back.color = Color(0.1, 0.1, 0.15)
	oil_back.position = Vector2(85, 6)
	oil_back.size = Vector2(100, 10)
	add_child(oil_back)
	oil_bar.color = Color("#FFEC27")
	oil_bar.position = Vector2(86, 7)
	oil_bar.size = Vector2(98, 8)
	add_child(oil_bar)
	for l in [hearts_label, bag_label, depth_label, strata_banner]:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 8)
		add_child(l)
	hearts_label.position = Vector2(6, 4)
	bag_label.position = Vector2(210, 4)
	depth_label.position = Vector2(232, 230)
	strata_banner.position = Vector2(0, 100)
	strata_banner.size = Vector2(270, 20)
	strata_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strata_banner.modulate.a = 0.0
	lamp_btn.text = "LAMP"
	lamp_btn.position = Vector2(6, 410)
	lamp_btn.size = Vector2(64, 64)
	lamp_btn.pressed.connect(func() -> void: lamp_pressed.emit())
	add_child(lamp_btn)
	pause_btn.text = "II"
	pause_btn.position = Vector2(238, 28)
	pause_btn.size = Vector2(26, 26)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause_btn)

func update_state(oil_ratio: float, lamp_on: bool, hearts: int, bag: int, slots: int, depth: int) -> void:
	oil_bar.size.x = 98.0 * clampf(oil_ratio, 0.0, 1.0)
	oil_bar.color = Color("#FFEC27") if lamp_on else Color(0.4, 0.4, 0.4)
	hearts_label.text = "♥".repeat(hearts)
	bag_label.text = "%d/%d" % [bag, slots]
	depth_label.text = "%dm" % depth

func show_strata(strata: int) -> void:
	strata_banner.text = "─ %s ─" % TextDb.t("ui", "strata_%d" % strata)
	var tw := create_tween()
	strata_banner.modulate.a = 0.0
	tw.tween_property(strata_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(strata_banner, "modulate:a", 0.0, 0.6)
```

- [ ] **Step 3: Mine에 부착**

`src/mine.gd` `_ready()` 끝에 추가:
```gdscript
	light_rig = LightRig.new()
	add_child(light_rig)
	hud = Hud.new()
	add_child(hud)
	hud.lamp_pressed.connect(toggle_lamp)
	hud.pause_pressed.connect(func() -> void: get_tree().paused = not get_tree().paused)
	strata_entered.connect(hud.show_strata)
```
멤버 추가:
```gdscript
var light_rig: LightRig
var hud: Hud
```
`_process()` 끝에 추가:
```gdscript
	light_rig.follow(player.position)
	light_rig.set_radius_tiles(light_radius())
	hud.update_state(oil / Oil.tank(GameState.profile.upgrades.lamp), lamp_on, hearts,
		GameState.run.bag.size(), Economy.bag_slots(GameState.profile.upgrades.bag), ppos.y)
```
포커스 자동 일시정지 — `Mine`에 추가:
```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and alive:
		get_tree().paused = true
```
(일시정지 오버레이·재개 탭은 Task 14의 Main 상태 머신에서 PAUSED 라벨과 함께 처리. `process_mode` — HUD의 pause_btn과 Main 오버레이는 `PROCESS_MODE_ALWAYS`로 설정해 일시정지 중에도 입력을 받는다.)

- [ ] **Step 4: runtest + 수동 스모크**

runtest — Expected: 기존 전부 passed (이 태스크는 씬 전용이라 신규 단위 테스트 없음).
수동: 실행 → 어둠 속 라디얼 라이트, 기름이 줄며 반경이 계단식으로 줄어드는지, 램프 토글 시 잔광만 남는지, HUD 게이지·하트·가방·깊이·지층 배너 확인. 창 포커스 아웃 → 일시정지 확인.

- [ ] **Step 5: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): canvas darkness with radial lamp light and minimal survival HUD"
```

---

### Task 13: Lurker 씬 + AnomalyDirector (연출 통합)

**Files:**
- Create: `games-src/it-sleeps-below/src/lurker.gd`, `src/anomaly_director.gd`
- Modify: `src/mine.gd` (부착·이벤트 배선), `src/hud.gd` (메타 연출 훅: 깊이계 거짓말·게이지 거짓말)

**Interfaces:**
- Consumes: `LurkerLogic`, `AnomalyPool`, `Mine.noise_event`, `Sfx.heartbeat`, `LightRig.blackout`
- Produces:
  - `Lurker`(Node2D) — 스폰/디스폰, 매 0.35초 그리드 한 걸음(`LurkerLogic.next_step`, 통과 판정은 Mine의 `is_open` 콜백 = 파낸 EMPTY만), 빛 안이면 정지(`lurker_frozen` 텍스처), 플레이어와 같은 칸 → `caught` signal. 프리즈 중에는 걸음 타이머도 정지
  - `AnomalyDirector`(Node) — 45~90초 간격(rng)으로 `AnomalyPool.pick` → 연출 실행. 각 id의 연출은 아래 매핑 표대로. `flags`는 `GameState.profile.anomaly_flags`에 기록·저장
  - `Hud.lie_depth(value: int, sec: float)` / `Hud.lie_oil_zero(sec: float)` — 메타 연출용 (원래 값 자동 복귀)

**이상 현상 id → 연출 매핑 (AnomalyDirector 구현 기준):**

| id | 연출 |
|---|---|
| lamp_blink | `LightRig.blackout(2.0)` + `Sfx.play("lamp_flicker")` |
| lamp_blink_real | blackout(2.0) 하는 동안 러커를 플레이어 6타일 이내 어둠에 스폰 |
| tunnel_sealed | 플레이어 위쪽 파낸 통로 중 화면 밖 셀 1개를 지층 기본 타일로 되메움 (시각만 — 파면 다시 뚫림) |
| tunnel_sealed_real | 위와 같되 3칸 되메움 — 실제 우회 강제 |
| echo_pick | `Sfx.play("echo_pick")` |
| edge_silhouette | 러커 스프라이트를 빛 반경 바로 밖에 1.2초 표시 후 제거 (AI 없음) |
| ore_whisper | `Sfx.play("whisper")` |
| rhythm_continues | 마지막 채굴 사운드를 0.6초 간격 2회 재생 |
| ore_resealed | 시야 밖 광석 셀 1개를 기본 타일로 교체 |
| false_heartbeat | `Sfx.heartbeat(1.6)` 4초 후 정지 (러커 없음) |
| black_sky | 플래그만 기록 — Surface가 다음 지상 복귀 때 하늘을 1초 검게 (Task 14) |
| merchant_gone | 플래그만 기록 — Surface가 다음 복귀 때 상인 대신 memo_gone 표시 (Task 14) |
| side_tunnel | 플레이어 근처 벽 3~5칸을 EMPTY로 파냄 + 끝에 T_RELIC이 없으면 journal 스프라이트 소품 배치 |
| depth_999 | `Hud.lie_depth(999, 1.2)` |
| depth_rises | 상승 중 3초간 깊이 표시가 +1씩 증가 (`Hud.lie_depth` 연속 호출) |
| gauge_zero | `Hud.lie_oil_zero(1.5)` |
| black_ore | `Hud` 가방 카운트를 1.5초간 `+1` 표기 후 복귀 |
| pause_message | 다음 일시정지 1회에서 PAUSED 대신 `ui.pause_dont_go` 표시 (Main이 플래그 소비) |
| back_turned / silent_mimic / parallel_steps / other_lamp | 러커 스프라이트·사운드를 스크립트 배치(각 3~6초): 등 돌린 정지 → 빛 비추면 벽으로 스며듦 / 광석 앞 무음 곡괭이질 프레임 / `Sfx.play("steps_wall")` + 벽 너머 실루엣 이동 / 아래쪽 갱도에 램프 광점이 3초간 상승 후 소등 |

**러커 스폰 규칙 (Mine 배선):**
- `depth ≥ Tuning.LURKER_MIN_DEPTH`이고 디렉터 모드가 `M_HUNT`일 때 1개체 스폰 (빛 반경 밖 파낸 셀 중 가장 가까운 곳), `M_RETREAT`면 목표를 화면 밖으로, `M_SILENCE`면 디스폰
- 유품(`relic_spot`)이 있으면 스폰 위치는 유품 6타일 이내 우선 — "내 가방을 지키는 건 어제의 나"
- 심박: 러커 활성 중 거리 → `Sfx.heartbeat(0.8 + 8.0/max(dist,1))`, 디스폰 시 0
- 햅틱: `GameState.profile.settings.haptics`면 심박 비트마다 `Input.vibrate_handheld(40)` (웹 Android만 동작 — 실패는 무시됨)
- **첫 심층 진입 스크립트 조우 (스테이징 ②)**: `anomaly_flags`에 `first_deep`이 없을 때 심층 진입 → 디렉터 무시하고 전방 8타일에 러커 배치, 플레이어 방향으로 3걸음 접근 후 (빛에 걸리면 정지 연출) 옆 통로로 스며들며 소멸 → 플래그 기록. 균열대 기척(스테이징 ①)은 `edge_silhouette`가 담당
- **마지막 일지의 작성자**: 시리즈 마지막 일지(`han_3`, `baek_3`, `seo_4`) 스팟 8타일 이내에 플레이어가 들어오면 디렉터 모드와 무관하게 `steps_wall` 사운드 + 빛 밖 실루엣 1회 — "작성자가 배회한다" (스펙 §8)
- **지연 소비형 이상 현상**: `black_sky`·`merchant_gone`·`pause_message`는 발동 시 `anomaly_flags`에 id를 기록하고(1회성 보장), 연출을 소비하는 쪽(Surface/Main)이 `<id>_done`을 추가로 기록한다. 소비 조건 = `id` 있음 && `<id>_done` 없음. **id를 제거하는 방식 금지** — 제거하면 1회성이 깨진다
- 잡히면(`caught`) `Mine.die("death_lurker")`

- [ ] **Step 1: lurker.gd 구현**

```gdscript
class_name Lurker
extends Node2D
## '그것' — 규칙은 LurkerLogic, 여기는 스폰·걸음·표시·포획만.

signal caught

var grid_pos := Vector2i.ZERO
var target := Vector2i.ZERO
var is_open: Callable
var frozen := false
var _tex_walk: Texture2D
var _tex_frozen: Texture2D
var _step_t := 0.0

func _ready() -> void:
	_tex_walk = load("res://assets/img/lurker.png")
	_tex_frozen = load("res://assets/img/lurker_frozen.png")
	z_index = 9

func setup(pos: Vector2i, open_cb: Callable) -> void:
	grid_pos = pos
	is_open = open_cb
	position = Vector2(pos * 16) + Vector2(8, 0)

func tick(delta: float, player_pos: Vector2i, radius: float, lamp_on: bool) -> void:
	frozen = LurkerLogic.is_frozen(grid_pos, player_pos, radius, lamp_on)
	queue_redraw()
	if frozen:
		return
	_step_t += delta
	if _step_t < 0.35:
		return
	_step_t = 0.0
	grid_pos = LurkerLogic.next_step(grid_pos, target, is_open)
	position = Vector2(grid_pos * 16) + Vector2(8, 0)
	if grid_pos == player_pos:
		caught.emit()
	elif grid_pos == target:
		# 목표 도달 + 새 소음 없음 → 배회로 전환 (지나침 규칙, 스펙 §6)
		var s := LurkerLogic.arrived_wander({"target": target, "alert": false},
			grid_pos + Vector2i([-4, 4].pick_random(), [-3, 0, 3].pick_random()))
		target = s.target

func hear(pos: Vector2i, level: float) -> void:
	var s := LurkerLogic.hear({"target": target, "alert": false}, pos, level)
	target = s.target

func _draw() -> void:
	draw_texture(_tex_frozen if frozen else _tex_walk, Vector2(-8, -16))
```

- [ ] **Step 2: anomaly_director.gd 구현**

핵심 골격 (연출 케이스는 위 매핑 표 전부 구현):
```gdscript
class_name AnomalyDirector
extends Node
## 이상 현상 — 풀에서 뽑아 연출 실행. 1회성은 프로필 플래그로 영속.

var mine: Mine
var rng := RandomNumberGenerator.new()
var _next_t := 0.0

func _ready() -> void:
	rng.randomize()
	_arm()

func _arm() -> void:
	_next_t = rng.randf_range(45.0, 90.0)

func _process(delta: float) -> void:
	if not mine.alive or mine.ppos.y < 40:
		return
	_next_t -= delta
	if _next_t > 0.0:
		return
	_arm()
	var e := AnomalyPool.pick(GameState.profile.anomaly_flags, mine.ppos.y, GameState.corruption(), rng)
	if e.is_empty():
		return
	if e.once:
		GameState.profile.anomaly_flags.append(e.id)
		GameState.save()
	_run(e.id)

func _run(id: String) -> void:
	match id:
		"lamp_blink":
			Sfx.play("lamp_flicker")
			mine.light_rig.blackout(2.0)
		"echo_pick":
			Sfx.play("echo_pick")
		_:
			pass
```
`_run()`의 나머지 케이스는 **위 매핑 표의 각 행을 그대로 케이스로 구현**한다 — 표가 명세다. 지연 소비형 3종(black_sky/merchant_gone/pause_message)은 플래그 기록 외에 `_run`에서 할 일이 없다(케이스 생략 가능 — pick 시점에 이미 기록됨).
```gdscript
# (참고: 케이스 구현 예 — edge_silhouette)
		"edge_silhouette":
			var ghost := Sprite2D.new()
			ghost.texture = load("res://assets/img/lurker.png")
			var dir := [-1, 1].pick_random()
			ghost.position = Vector2(mine.player.position) + Vector2(dir * (mine.light_radius() + 1.5) * 16.0, 0)
			mine.add_child(ghost)
			get_tree().create_timer(1.2).timeout.connect(ghost.queue_free)
```

- [ ] **Step 3: mine.gd 배선**

`Mine`에 멤버·로직 추가:
```gdscript
var lurker: Lurker
var director := {"mode": LurkerLogic.M_SILENCE, "t": 20.0}
var anomalies: AnomalyDirector
```
`_ready()`: `anomalies = AnomalyDirector.new(); anomalies.mine = self; add_child(anomalies)`
`_process()`에 디렉터·러커 틱 추가:
```gdscript
	if ppos.y >= Tuning.LURKER_MIN_DEPTH:
		director = LurkerLogic.director_step(director, delta, ppos.y)
		_update_lurker(delta)
```
`_update_lurker` — 스폰 규칙(위 명세) 구현, `noise_event.connect(lurker.hear)` 배선, `caught` → `die("death_lurker")`, 심박·햅틱 갱신. 첫 심층 스크립트 조우는 `strata_entered(3)`에서 실행.

- [ ] **Step 4: hud 거짓말 훅**

`src/hud.gd`에 추가:
```gdscript
var _depth_lie := -1
var _oil_lie := false

func lie_depth(value: int, sec: float) -> void:
	_depth_lie = value
	get_tree().create_timer(sec).timeout.connect(func() -> void: _depth_lie = -1)

func lie_oil_zero(sec: float) -> void:
	_oil_lie = true
	get_tree().create_timer(sec).timeout.connect(func() -> void: _oil_lie = false)
```
`update_state()` 첫 줄에서 `if _oil_lie: oil_ratio = 0.0`, depth 표시는 `_depth_lie if _depth_lie >= 0 else depth`.

- [ ] **Step 5: runtest + 수동 스모크**

runtest — Expected: 전부 passed.
수동: 세이브를 지우고(`user://` — `%APPDATA%\Godot\app_userdata\IT SLEEPS BELOW\`) 곡괭이 레벨을 tuning에서 임시 4로 올려 심층 직행 → 첫 조우 스크립트 → 파도 사이클(사냥 때 심박·접근, 빛 비추면 정지, 램프 끄면 접근) 확인 → 임시 수치 원복.

- [ ] **Step 6: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): lurker scene with staging and anomaly director incl. HUD lies"
```

---

### Task 14: Surface 거점 + Main 상태 머신 + 오프닝

**Files:**
- Create: `games-src/it-sleeps-below/src/surface.gd`
- Modify: `src/main.gd` (임시 부팅 → 타이틀/거점/갱도/일시정지/게임오버 상태 머신)

**Interfaces:**
- Consumes: `Economy`, `Lore`, `TextDb`, `GameState`, `Mine.run_ended`
- Produces:
  - `Surface`(Node2D) — 거점 화면: `vista` 원경(오염 단계별 틴트), 상인(+상점 패널), 수첩 패널, 갱도 입구. signal `descend_pressed`
  - 상점: 업그레이드 5트랙(현재 Lv/비용/구매 버튼, `Economy.upgrade_cost`, 골드 차감) + 기름병(`Tuning.OIL_BOTTLE_PRICE`, 보유 `Tuning.OIL_BOTTLE_CARRY_MAX` 상한). 구매 즉시 `GameState.save()`
  - 수첩: `Lore.series()` 순서로 찾은 일지 목록(`TextDb.t("journals", id)` 전문 오버레이) + 수집률
  - 오염 연출(코드 기준 `GameState.corruption()`): 0=기본 / 1=하늘 틴트 어둡게·새소리 볼륨 −6dB / 2=`bgm_camp` `pitch_scale 0.98` / 3=상인 위치가 미묘하게 이동 + `settle_4` 대사 사용 / 4=하늘 틴트 검붉음·bgm 0.95. `black_sky`는 지연 소비형(Task 13 규칙): 미소비 상태면 진입 1초 하늘 검정 후 `black_sky_done` 기록. `merchant_gone`도 동일 — 미소비면 상인 대신 `memo_gone` 텍스트, 확인 시 `merchant_gone_done` 기록 (다음 복귀에 상인 정상)
  - `Main` 상태 머신: `TITLE → (opening_seen? 거점 : OPENING) → SURFACE ↔ MINE → (death) DEATH_MSG → SURFACE`, PAUSE 오버레이(탭 재개, `pause_message` 플래그 시 `pause_dont_go` 1회), 사망 메시지는 `ui.death_*` + `merchant.next_miner`(첫 사망 1회)
  - 오프닝: `vista_calm` 정적 화면 + `opening.arrive` 자막 3.5초(탭 스킵) → `merchant.opening` → 거점. `profile.opening_seen = true` 저장
  - 언어 토글: 타이틀에 `KO/EN` 버튼 → `profile.settings.lang` 교체·저장
  - 설정 토글 2종(타이틀 하단, 같은 패턴): `HAPTICS ON/OFF` → `settings.haptics`, `FLASH ON/REDUCED` → `settings.reduced_flash` — 저장 즉시 반영

- [ ] **Step 1: surface.gd 구현**

구현 골격 (패널은 `PanelContainer`+`VBoxContainer` 코드 조립, 폰트 Galmuri9, 골드는 여기서만 표시):
```gdscript
class_name Surface
extends Node2D

signal descend_pressed

var vista: Sprite2D
var gold_label := Label.new()

func _ready() -> void:
	vista = Sprite2D.new()
	vista.texture = load("res://assets/img/vista_calm.png")
	vista.centered = false
	add_child(vista)
	_apply_corruption()
	Sfx.ambience("amb_surface")
	_build_ui()  # 골드 라벨, SHOP/NOTEBOOK/DESCEND 버튼 3개, 상인 스프라이트

func _apply_corruption() -> void:
	var c := GameState.corruption()
	var tints := [Color.WHITE, Color(0.85, 0.8, 0.85), Color(0.75, 0.7, 0.8), Color(0.65, 0.55, 0.65), Color(0.55, 0.35, 0.45)]
	vista.modulate = tints[c]
	# bgm — 오염될수록 음정이 틀어진다
	Sfx.ambience("bgm_camp")
	# Sfx._amb.pitch_scale 직접 제어 대신 Sfx에 ambience_pitch(p) 헬퍼를 추가해 사용
	Sfx.ambience_pitch([1.0, 1.0, 0.98, 0.98, 0.95][c])
```
(`Sfx`에 `ambience_pitch(p: float)` 한 줄 헬퍼 추가: `_amb.pitch_scale = p`)

상점 패널 — 트랙별 행: `"%s Lv%d → %d G"`, 구매 시:
```gdscript
func _buy(track: String) -> void:
	var next: int = GameState.profile.upgrades[track] + 1
	var cost := Economy.upgrade_cost(track, next)
	if cost < 0 or GameState.profile.gold < cost:
		return
	GameState.profile.gold -= cost
	GameState.profile.upgrades[track] = next
	GameState.save()
	Sfx.play("settle")
	_refresh_shop()
```

- [ ] **Step 2: main.gd 상태 머신 교체**

```gdscript
extends Node2D
## TITLE → OPENING → SURFACE ↔ MINE → DEATH_MSG → SURFACE. 씬 전환은 자식 교체.

enum S { TITLE, OPENING, SURFACE, MINE, DEATH }

var state: int = S.TITLE
var current: Node

func _ready() -> void:
	_show_title()

func _swap(node: Node) -> void:
	if current:
		current.queue_free()
	current = node
	add_child(node)

func _show_title() -> void:
	state = S.TITLE
	# 로고 스프라이트 + "탭하여 내려가기"(TextDb ui.tap_to_descend) + KO/EN 버튼
	# 탭 → opening_seen ? _show_surface() : _show_opening()

func _show_opening() -> void:
	state = S.OPENING
	# vista_calm 풀스크린 + opening.arrive 자막, 3.5s 후(또는 탭) merchant.opening 1.5s → 완료:
	GameState.profile.opening_seen = true
	GameState.save()
	_show_surface()

func _show_surface() -> void:
	state = S.SURFACE
	var s := Surface.new()
	s.descend_pressed.connect(_show_mine)
	_swap(s)

func _show_mine() -> void:
	state = S.MINE
	var m := Mine.new()
	m.run_ended.connect(_on_run_ended)
	_swap(m)

func _on_run_ended(reason: String, depth: int) -> void:
	if reason == "surfaced":
		var earned := GameState.end_run_settle()
		_show_surface()  # Surface가 정산 결과 + merchant.settle_N 대사 표시
	else:
		state = S.DEATH
		# 검은 화면 + ui.death_<reason> + (첫 사망이면 merchant.next_miner) → 탭 → _show_surface()
```
일시정지 오버레이: `Main`에 `CanvasLayer` + 반투명 검정 + `PAUSED` 라벨(`process_mode = PROCESS_MODE_ALWAYS`), `get_tree().paused` 변화 감시. `pause_message` 플래그가 있으면 1회 `pause_dont_go`로 표기 후 플래그 제거.

- [ ] **Step 3: runtest + 수동 풀 루프 확인**

runtest — Expected: 전부 passed.
수동: 세이브 삭제 후 실행 — 타이틀 → 오프닝(스킵 확인) → 거점 → 하강 → 광석 → 복귀 → 정산·상점 구매 → 재하강 → 사망 → "…다음 분이신가." → 유품 회수까지 한 사이클. EN 토글 후 일지·HUD 라벨 영어 확인.

- [ ] **Step 4: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): surface camp with shop/notebook/corruption, main state machine, opening"
```

---

### Task 15: 피날레 + 코즈믹 리빌 엔딩

**Files:**
- Create: `games-src/it-sleeps-below/src/finale_director.gd`, `src/ending.gd`
- Modify: `src/mine.gd` (심장 채굴 트리거), `src/main.gd` (ENDING 상태)

**Interfaces:**
- Consumes: `Finale`, `LightRig`, `Lurker`, `TextDb`, `Sfx`
- Produces:
  - 심장 채굴(`T_HEART` dig 완료) → `Mine`이 `FinaleDirector` 기동: ① `ending.awaken` 자막 + `Sfx.play("awaken")` + 화면 셰이크 1.5초(유일한 충격 연출 — `reduced_flash`면 셰이크·플래시 절반) ② `Finale.twist(cells, run.seed)` 적용 ③ 램프 무력화(`lamp_on=false` 고정), 조명은 심장 펄스만: `Tuning.HEART_PULSE_SEC` 주기로 라이트 반경 0.75↔5.0 사인 펄스 ④ 러커 3개체 스폰(동시 1개체 규칙의 명시적 예외), **펄스 밝은 반주기 동안만 전원 정지** ⑤ 탈출로 곳곳 `ore_glow` 유혹 배치(채굴 가능 — 소리에 러커 반응)
  - 지표 도달 → `run_ended("finale_escaped", depth)` → Main이 ENDING으로
  - `Ending`(Node2D) — 코즈믹 리빌: `vista_alive`를 카메라 줌아웃(스케일 1.0→0.25, 8초, 심장 펄스와 동기화된 봉우리 불빛) → `ending.caption` 자막 5초 → `ending.credits_thanks` + 크레딧 스크롤 → 탭 → 거점. `profile.ending_seen = true` 저장
  - 피날레 중 사망 → 일반 사망 흐름 (산은 다시 잠듦 — 플래그 없음, 재도전 가능). 엔딩 후 자유 플레이: 심장 챔버는 비어 있음(`ending_seen`이면 worldgen 후 `T_HEART`를 `T_EMPTY`로)

- [ ] **Step 1: finale_director.gd 구현**

```gdscript
class_name FinaleDirector
extends Node
## 산이 깨어난다 — 피날레 시퀀스 전부.

var mine: Mine
var _pulse_t := 0.0
var lurkers: Array[Lurker] = []

func start() -> void:
	Sfx.ambience("amb_finale")
	Sfx.play("awaken")
	# 자막 + 셰이크 (reduced_flash 반영)
	var out: Dictionary = Finale.twist(mine.cells, GameState.run.seed)
	mine.cells = out.cells
	mine.view.cells = mine.cells
	mine.lamp_on = false
	mine.finale_mode = true
	_scatter_temptation()
	for i in range(3):
		var l := Lurker.new()
		mine.add_child(l)
		l.setup(_spawn_pos(i), mine.is_open_cell)
		l.caught.connect(func() -> void: mine.die("death_lurker"))
		lurkers.append(l)

func _process(delta: float) -> void:
	if not mine.finale_mode:
		return
	_pulse_t += delta
	var phase := sin(_pulse_t * TAU / Tuning.HEART_PULSE_SEC)
	var bright := phase > 0.0
	mine.light_rig.set_radius_tiles(0.75 + (5.0 - 0.75) * maxf(0.0, phase))
	Sfx.heartbeat(1.4)
	for l in lurkers:
		# 펄스 밝은 반주기 = 전원 정지 (빛 규칙의 피날레 버전)
		if not bright:
			l.tick(delta, mine.ppos, 0.0, false)
		else:
			l.frozen = true
			l.queue_redraw()
```
`_scatter_temptation()`: 챔버~지표 사이 파낸 통로 인접 벽 12곳에 `ORE_BASE+6` 심기. `_spawn_pos(i)`: 챔버 위 20·60·100m 지점의 파낸 셀.

- [ ] **Step 2: mine.gd 트리거 + ending.gd**

`Mine`에 멤버 추가:
```gdscript
var finale_mode := false
var finale: FinaleDirector
```
`Mine._collect()`의 심장 케이스:
```gdscript
	elif c == WorldGen.T_HEART:
		GameState.run.bag.append(6)  # 발광 광석 취급 + 서사상 '심장 하나'
		finale = FinaleDirector.new()
		finale.mine = self
		add_child(finale)
		finale.start()
```
`_after_move()`의 지표 복귀 분기에서 `finale_mode`면 `run_ended.emit("finale_escaped", GameState.run.depth)`.

`src/ending.gd` — 줌아웃 트윈 + 자막 2단 + 크레딧, 종료 탭에서:
```gdscript
	GameState.profile.ending_seen = true
	GameState.save()
	finished.emit()
```
`Main`: `"finale_escaped"` → `_show_ending()` → `finished` → `_show_surface()`. `_show_mine()`에서 `ending_seen`이면 심장 좌표를 EMPTY로.

- [ ] **Step 3: runtest + 수동 확인**

runtest — Expected: 전부 passed (`Finale.twist` 재검증 포함).
수동: tuning 임시 수정(심장을 30m로)으로 피날레 전체 — 각성 연출 → 펄스 등반 → 유혹 광석 채굴 시 러커 반응 → 탈출 → 줌아웃 리빌 → 크레딧 → 거점 복귀 → 재하강 시 챔버 빈 것 확인 → 임시 수치 원복.

- [ ] **Step 4: Commit**

```powershell
git add games-src/it-sleeps-below
git commit -m "feat(isb): finale — awakening, pulse-lit escape, temptation ores, cosmic reveal ending"
```

---

### Task 16: 웹 익스포트 + 사이트 등록 + 플레이테스트 문서

**Files:**
- Create: `games-src/it-sleeps-below/export_presets.cfg`, `public/games/it-sleeps-below/`(익스포트 산출물), `docs/superpowers/specs/it-sleeps-below-playtest.md`
- Rename+Modify: `content/games/02-down-the-cave.json` → `content/games/02-it-sleeps-below.json`

**Interfaces:**
- Produces: 프로덕션 배포 가능한 웹 빌드 + 카트리지 등록. vitest·gdUnit 전체 그린

- [ ] **Step 1: export_presets.cfg 작성**

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="addons/gdUnit4/*,tests/*"
export_path="../../public/games/it-sleeps-below/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/export_icon=true
html/custom_html_shell="res://web/shell.html"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
```

- [ ] **Step 2: 익스포트 실행**

```powershell
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
New-Item -ItemType Directory -Force "public\games\it-sleeps-below"
Set-Location "games-src\it-sleeps-below"
& $GODOT --headless --export-release "Web" --path .
Set-Location "..\.."
Get-ChildItem "public\games\it-sleeps-below"
```
Expected: index.html, .wasm(~40MB), .pck, .js. 100MB 초과 파일 없음. `text/` 폴더가 함께 있는지 확인(Task 8에서 생성됨 — 익스포트가 지우지 않았는지).

- [ ] **Step 3: 카트리지 JSON 교체**

```powershell
git mv content/games/02-down-the-cave.json content/games/02-it-sleeps-below.json
```
내용 전체 교체:
```json
{
  "slug": "it-sleeps-below",
  "order": 20,
  "title": "IT SLEEPS BELOW",
  "subtitle": "아래에 잠든 것",
  "description": "곡괭이 하나로 시작하는 로그라이크 채굴 어드벤처.\n내려갈수록 어두워지고,\n어두울수록 반짝이는 것이 많아집니다.\n램프 기름이 떨어지기 전에 돌아올 수 있을까요?",
  "tags": [
    "GODOT 4",
    "2D",
    "ROGUELIKE",
    "HORROR",
    "MOBILE",
    "PC"
  ],
  "coverScene": "cave",
  "playPath": "/games/it-sleeps-below/index.html"
}
```
주의: `coverScene: "cave"`는 기존 절차 커버 씬 재사용(scenes.ts의 유효값). 슬러그 변경으로 커버 캔버스 시드가 달라질 수 있으나 문제없음.

- [ ] **Step 4: 전체 테스트 + 로컬 플레이 확인**

```powershell
npm test
```
Expected: gametext·games 포함 전부 PASS (playPath 파일 존재 검증이 이제 통과).
```powershell
npm run dev
```
`http://localhost:3000` 카트리지에서 PLAY → iframe 임베드로 타이틀 표시·터치(모바일 에뮬레이션)·세이브 영속(새로고침 후 골드 유지) 확인.

- [ ] **Step 5: 플레이테스트 체크리스트 작성**

`docs/superpowers/specs/it-sleeps-below-playtest.md` — STARFALL 체크리스트 패턴:
```markdown
# IT SLEEPS BELOW 플레이테스트 체크리스트

환경: 데스크톱 크롬 / 파이어폭스, 모바일 안드로이드 크롬(실기) / iOS 사파리(실기)

## 조작
- [ ] 인접 탭 채굴/이동, 길게 눌러 연속, 비인접 무시 (터치·마우스·키보드)
- [ ] 램프 버튼·Space 토글, 조심 채굴(끊어 파기) 소음 차이 체감
## 코어 루프
- [ ] 하강→채굴→복귀→정산, 상승이 하강보다 확실히 느림
- [ ] 사망 → 다음 광부 → 유품 회수(지킴이 조우 포함)
- [ ] 업그레이드 5트랙 + 기름병(슬롯 차지) 구매·효과
## 공포
- [ ] 지층 앰비언트 전환, 심층 무음+심박, 하강할수록 음악 소멸
- [ ] 스테이징 ①②, 파도 리듬(침묵 창 체감), 빛 정지/램프 오프 대치
- [ ] 이상 현상 발화·1회성, 메타(깊이 999 등) 캔버스 안 한정
- [ ] 지상 오염 단계 변화, 상인 부재/복귀
## 엔딩
- [ ] 피날레 각성→펄스 탈출→유혹 광석→리빌 줌아웃→크레딧→자유 플레이
- [ ] reduced_flash 설정 시 연출 완화
## 웹/모바일
- [ ] 30fps 이상(조명 켠 심층 기준), 세이브 영속(IndexedDB), 포커스 아웃 일시정지
- [ ] KO/EN 토글 즉시 반영, 텍스트 렌더링 두부 없음
- [ ] 햅틱(안드로이드) 동작·설정 오프
```

- [ ] **Step 6: Commit**

```powershell
git add games-src/it-sleeps-below/export_presets.cfg public/games/it-sleeps-below content/games docs/superpowers/specs/it-sleeps-below-playtest.md
git commit -m "feat(isb): web export, cartridge registration as IT SLEEPS BELOW, playtest checklist"
```

이후: 사용자 플레이테스트(체크리스트) → master 머지 → push → Vercel 자동 배포. (STARFALL DRIFT의 미완 Task 13 플레이테스트와 별개 트랙 — 머지 순서는 사용자와 협의)





