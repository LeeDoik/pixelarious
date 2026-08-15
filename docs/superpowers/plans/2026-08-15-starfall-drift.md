# STARFALL DRIFT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원버튼 궤도 호핑 아케이드 STARFALL DRIFT를 Godot 4.7로 만들어 웹 익스포트하고 NEO_KIDO 카트리지로 등록한다 (모바일 터치 필수).

**Architecture:** 물리 엔진을 쓰지 않는 커스텀 키네마틱 — 궤도/탄도/포획 수학과 절차 생성·스코어링을 순수 static 함수(`OrbitMath`, `Spawner`, `Scoring`)로 분리해 gdUnit4로 헤드리스 단위 테스트한다. 씬 파일은 `main.tscn` 하나뿐이며 모든 노드 트리는 코드로 구성한다(과거 tscn 수기 작성으로 히트테스트 버그를 겪음). 에셋은 PixelLab API로 생성(퀄리티 우선), SFX는 파이썬 stdlib 합성.

**Tech Stack:** Godot 4.7.1 Standard(GDScript), gdUnit4, Python 3(에셋/오디오 생성), PixelLab API, 기존 Next.js 사이트(레코드 등록만).

**스펙:** `docs/superpowers/specs/2026-08-15-starfall-drift-design.md` — 수치·규칙의 원본. 충돌 시 스펙이 우선.

## Global Constraints

- Godot 실행 파일(전 태스크 공통): `$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"` (4.7.1.stable, 웹 익스포트 템플릿 설치됨)
- 게임 프로젝트 루트: `games-src/starfall-drift/` (Task 1에서 기존 `game/` → `games-src/last-login/`로 재편)
- gdUnit4 테스트 실행(프로젝트 디렉토리에서): 첫 실행 또는 `.godot/` 삭제 후엔 반드시 캐시 프라이밍 `& $GODOT --headless --editor --path . --quit` 후 `$env:GODOT_BIN = $GODOT; cmd /c "addons\gdUnit4\runtest.cmd -a tests"` — Expected: 0 errors / 0 failures, exit 0
- 뷰포트 270×480 (9:16 세로), `canvas_items` 스트레치 + `expand`, `gl_compatibility`, 텍스처 필터 nearest
- 팔레트: 하늘 `#0C0A1C`, 원경 `#1D2B53`, 별빛 `#FFF1E8`, 하이라이트 `#FFEC27`, 핑크 `#FF77A8`, 시안 `#29ADFF`
- 튜닝 수치는 전부 `src/core/tuning.gd` 상수로만 존재 (매직 넘버 금지). 스펙 §3~§6의 시작값 사용
- 조작은 액션 `"drift"` 하나 (Space, 마우스 좌클릭, 터치는 `emulate_mouse_from_touch`로 흡수)
- 웹 익스포트: Web 프리셋, 스레드 비활성화(nothreads), 파일당 100MB 미만
- PixelLab API 키: 리포 루트 `.env.local`의 `PIXELLAB_API_KEY` (절대 커밋 금지 — .gitignore 등록됨)
- GDScript 들여쓰기는 탭. 커밋 메시지는 기존 관례(`feat(game): ...`) 따름
- `src/lib/dialogue.ts`·`src/lib/gamedocs.ts`·`src/components/GameEditorClient*` 는 **다른 작업의 미커밋 WIP** — Task 1의 경로 수정 외엔 건드리지 말고, 절대 git add 하지 않는다

---

### Task 1: 리포 재편 — `game/` → `games-src/last-login/`

**Files:**
- Move: `game/` → `games-src/last-login/` (git mv)
- Modify: `games-src/last-login/export_presets.cfg`(export_path), `games-src/last-login/README.md`(경로 문구), `.gitignore`
- Modify(커밋 금지, WIP): `src/lib/dialogue.ts:8`, `src/lib/gamedocs.ts:7`, `src/components/GameEditorClient.tsx:168`

**Interfaces:**
- Produces: `games-src/last-login/`(기존 LAST LOGIN 프로젝트, 테스트·익스포트 경로 정상), `games-src/` 밑에 게임별 프로젝트를 두는 구조

- [ ] **Step 1: git mv로 이동**

```powershell
git mv game games-src/last-login
git status --short | Select-Object -First 5
```
Expected: `R  game/... -> games-src/last-login/...` 형태의 rename 스테이징.

- [ ] **Step 2: export_path 수정**

`games-src/last-login/export_presets.cfg`의 `export_path` 줄을 다음으로 교체:
```ini
export_path="../../public/games/last-login/index.html"
```

- [ ] **Step 3: .gitignore 갱신**

리포 루트 `.gitignore`에서 아래 2줄을
```
game/.godot/
game/reports/
```
다음으로 교체:
```
games-src/*/.godot/
games-src/*/reports/
```

- [ ] **Step 4: 문서·WIP 경로 갱신**

`games-src/last-login/README.md`: 본문의 `game/` 경로 표기를 `games-src/last-login/`으로, `--path game`을 `--path .`(games-src/last-login에서 실행) 문구로 수정.

`src/lib/dialogue.ts:8`:
```ts
const CHAT_PATH = path.join(process.cwd(), 'games-src', 'last-login', 'content', 'chat.json')
```
`src/lib/gamedocs.ts:7`:
```ts
const DOCS_PATH = path.join(process.cwd(), 'games-src', 'last-login', 'content', 'docs.json')
```
`src/components/GameEditorClient.tsx:168`: 안내 문구 `game/content/` → `games-src/last-login/content/`.

- [ ] **Step 5: 검증 — LAST LOGIN 테스트·사이트 테스트 전부 통과**

```powershell
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
Set-Location "games-src\last-login"
& $GODOT --headless --editor --path . --quit
$env:GODOT_BIN = $GODOT
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
Set-Location "..\.."
npm test
```
Expected: gdUnit 0 failures(36개), vitest 전부 PASS. 실패 시 경로 수정 누락을 찾는다.

- [ ] **Step 6: Commit (WIP 파일 제외)**

```powershell
git add -u
git add .gitignore
git status --short   # src/lib/dialogue.ts 등 WIP가 ?? (untracked) 상태로 남아있는지 확인 — 스테이징돼 있으면 git restore --staged
git commit -m "refactor: move game/ to games-src/last-login for multi-game layout"
```

---

### Task 2: STARFALL DRIFT 스캐폴드 + 테스트 하네스

**Files:**
- Create: `games-src/starfall-drift/project.godot`, `icon.svg`, `src/main.tscn`, `src/main.gd`(스텁), `src/core/game_state.gd`(스텁), `src/core/sfx.gd`(스텁), `tests/test_harness.gd`, `CREDITS.md`, `assets/fonts/Galmuri9.ttf`, `assets/fonts/Galmuri11.ttf`, `addons/gdUnit4/`

**Interfaces:**
- Produces: 부팅되는 빈 Godot 프로젝트 + 동작하는 gdUnit4 테스트 커맨드. 오토로드 `GameState`, `Sfx` 등록(내용은 Task 5·7에서)

- [ ] **Step 1: 디렉토리·설정 파일**

```powershell
New-Item -ItemType Directory -Force games-src\starfall-drift\src\core, games-src\starfall-drift\tests, games-src\starfall-drift\assets\fonts, games-src\starfall-drift\assets\img, games-src\starfall-drift\assets\sfx
Copy-Item games-src\last-login\assets\fonts\Galmuri9.ttf, games-src\last-login\assets\fonts\Galmuri11.ttf games-src\starfall-drift\assets\fonts\
```

`games-src/starfall-drift/project.godot`:
```ini
; Engine configuration file.
config_version=5

[application]
config/name="STARFALL DRIFT"
run/main_scene="res://src/main.tscn"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"

[autoload]
GameState="*res://src/core/game_state.gd"
Sfx="*res://src/core/sfx.gd"

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
```

`games-src/starfall-drift/icon.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#0C0A1C"/><circle cx="64" cy="72" r="26" fill="#FFEC27"/><circle cx="64" cy="72" r="18" fill="#FFF1E8"/><rect x="88" y="20" width="8" height="8" fill="#FF77A8"/><rect x="30" y="30" width="5" height="5" fill="#29ADFF"/><rect x="98" y="30" width="20" height="4" fill="#29ADFF" transform="rotate(35 98 30)"/></svg>
```

`games-src/starfall-drift/src/main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

`games-src/starfall-drift/src/main.gd` (스텁 — Task 10에서 교체):
```gdscript
extends Node2D
```

`games-src/starfall-drift/src/core/game_state.gd` (스텁 — Task 5에서 교체):
```gdscript
extends Node
```

`games-src/starfall-drift/src/core/sfx.gd` (스텁 — Task 7에서 교체):
```gdscript
extends Node
```

- [ ] **Step 2: 헤드리스 스모크**

```powershell
$GODOT = "C:\Users\LeeDoik\tools\godot\godot_console.exe"
& $GODOT --headless --path games-src\starfall-drift --quit
```
Expected: exit 0, 스크립트 에러 없음.

- [ ] **Step 3: gdUnit4 설치(기존 애드온 복사) + 하네스 테스트**

```powershell
Copy-Item -Recurse games-src\last-login\addons games-src\starfall-drift\addons
```
`project.godot`에 추가:
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")
```
`games-src/starfall-drift/tests/test_harness.gd`:
```gdscript
extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_bool(true).is_true()
```
실행:
```powershell
Set-Location games-src\starfall-drift
& $GODOT --headless --editor --path . --quit
$env:GODOT_BIN = $GODOT
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
Set-Location ..\..
```
Expected: 1 passed, exit 0.

- [ ] **Step 4: CREDITS + Commit**

`games-src/starfall-drift/CREDITS.md`:
```markdown
# STARFALL DRIFT — Credits & Licenses

- Font: Galmuri (quiple/galmuri) — SIL Open Font License 1.1
- Engine: Godot Engine — MIT License
- 스프라이트: AI 생성 픽셀 아트 (PixelLab) 후 가공
- 사운드: 전량 자체 신디사이징 (scripts/gen_audio_starfall.py)
```

```powershell
git add games-src\starfall-drift
git commit -m "feat(starfall): scaffold Godot project with test harness"
```

---

### Task 3: OrbitMath — 궤도·탄도·포획 수학 (TDD)

**Files:**
- Create: `games-src/starfall-drift/src/core/orbit_math.gd`
- Test: `games-src/starfall-drift/tests/test_orbit_math.gd`

**Interfaces:**
- Produces (전부 static, 이후 태스크가 사용):
  - `OrbitMath.orbit_pos(center: Vector2, radius: float, angle: float) -> Vector2`
  - `OrbitMath.advance_angle(angle: float, angular_vel: float, dir: int, delta: float) -> float`
  - `OrbitMath.launch_velocity(center: Vector2, pos: Vector2, dir: int, speed: float) -> Vector2`
  - `OrbitMath.integrate_flight(pos: Vector2, vel: Vector2, gravity: float, delta: float) -> Array` — `[new_pos: Vector2, new_vel: Vector2]`
  - `OrbitMath.try_capture(pos: Vector2, star_center: Vector2, orbit_radius: float) -> bool`
  - `OrbitMath.entry_dir(center: Vector2, pos: Vector2, vel: Vector2) -> int` — +1/-1
  - `OrbitMath.entry_angle(center: Vector2, pos: Vector2) -> float`
  - `OrbitMath.bounce_x(pos: Vector2, vel: Vector2, min_x: float, max_x: float, damping: float) -> Array` — `[pos, vel]`
  - `OrbitMath.max_rise(speed: float, gravity: float) -> float`

좌표계 주의: 화면 y는 아래로 증가. 상승 = y 감소. `dir=+1`은 각도 증가 방향 공전.

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_orbit_math.gd`:
```gdscript
extends GdUnitTestSuite

func test_orbit_pos_angle_zero() -> void:
	var p := OrbitMath.orbit_pos(Vector2(100, 100), 10.0, 0.0)
	assert_bool(p.is_equal_approx(Vector2(110, 100))).is_true()

func test_orbit_pos_quarter_turn() -> void:
	var p := OrbitMath.orbit_pos(Vector2(100, 100), 10.0, PI / 2)
	assert_bool(p.is_equal_approx(Vector2(100, 110))).is_true()

func test_advance_angle_forward_and_reverse() -> void:
	assert_float(OrbitMath.advance_angle(0.0, 2.0, 1, 0.5)).is_equal_approx(1.0, 0.0001)
	assert_float(OrbitMath.advance_angle(0.0, 2.0, -1, 0.5)).is_equal_approx(-1.0, 0.0001)

func test_launch_velocity_is_tangent() -> void:
	# 별 중심 (0,0), 플레이어 오른쪽 (10,0), dir=+1 → 접선은 아래(+y)
	var v := OrbitMath.launch_velocity(Vector2.ZERO, Vector2(10, 0), 1, 5.0)
	assert_bool(v.is_equal_approx(Vector2(0, 5))).is_true()
	var v2 := OrbitMath.launch_velocity(Vector2.ZERO, Vector2(10, 0), -1, 5.0)
	assert_bool(v2.is_equal_approx(Vector2(0, -5))).is_true()

func test_integrate_flight_applies_gravity_then_moves() -> void:
	var r := OrbitMath.integrate_flight(Vector2.ZERO, Vector2(10, 0), 100.0, 0.1)
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(10, 10))).is_true()
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(1, 1))).is_true()

func test_try_capture_boundary() -> void:
	assert_bool(OrbitMath.try_capture(Vector2(3, 4), Vector2.ZERO, 5.0)).is_true()
	assert_bool(OrbitMath.try_capture(Vector2(3, 4.1), Vector2.ZERO, 5.0)).is_false()

func test_entry_dir_follows_rotation_sense() -> void:
	assert_int(OrbitMath.entry_dir(Vector2.ZERO, Vector2(10, 0), Vector2(0, 5))).is_equal(1)
	assert_int(OrbitMath.entry_dir(Vector2.ZERO, Vector2(10, 0), Vector2(0, -5))).is_equal(-1)

func test_entry_angle() -> void:
	assert_float(OrbitMath.entry_angle(Vector2(100, 100), Vector2(110, 100))).is_equal_approx(0.0, 0.0001)

func test_bounce_x_left_wall_reflects_and_damps() -> void:
	var r := OrbitMath.bounce_x(Vector2(5, 0), Vector2(-20, 0), 10.0, 260.0, 0.9)
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(15, 0))).is_true()
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(18, 0))).is_true()

func test_bounce_x_right_wall() -> void:
	var r := OrbitMath.bounce_x(Vector2(265, 0), Vector2(20, 0), 10.0, 260.0, 0.9)
	assert_bool((r[0] as Vector2).is_equal_approx(Vector2(255, 0))).is_true()
	assert_bool((r[1] as Vector2).is_equal_approx(Vector2(-18, 0))).is_true()

func test_max_rise() -> void:
	assert_float(OrbitMath.max_rise(260.0, 240.0)).is_equal_approx(140.833, 0.01)
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

```powershell
Set-Location games-src\starfall-drift
& $GODOT --headless --editor --path . --quit
$env:GODOT_BIN = $GODOT
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
```
Expected: FAIL — `OrbitMath` 미정의 파싱 에러.

- [ ] **Step 3: 구현**

`games-src/starfall-drift/src/core/orbit_math.gd`:
```gdscript
class_name OrbitMath
## 궤도·탄도·포획 순수 수학. 화면 y는 아래로 증가, dir=+1은 각도 증가 방향.

static func orbit_pos(center: Vector2, radius: float, angle: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * radius

static func advance_angle(angle: float, angular_vel: float, dir: int, delta: float) -> float:
	return angle + angular_vel * float(dir) * delta

static func launch_velocity(center: Vector2, pos: Vector2, dir: int, speed: float) -> Vector2:
	var radial := (pos - center).normalized()
	return Vector2(-radial.y, radial.x) * float(dir) * speed

static func integrate_flight(pos: Vector2, vel: Vector2, gravity: float, delta: float) -> Array:
	var new_vel := vel + Vector2(0.0, gravity) * delta
	return [pos + new_vel * delta, new_vel]

static func try_capture(pos: Vector2, star_center: Vector2, orbit_radius: float) -> bool:
	return pos.distance_to(star_center) <= orbit_radius

static func entry_dir(center: Vector2, pos: Vector2, vel: Vector2) -> int:
	var radial := pos - center
	return 1 if radial.x * vel.y - radial.y * vel.x >= 0.0 else -1

static func entry_angle(center: Vector2, pos: Vector2) -> float:
	return (pos - center).angle()

static func bounce_x(pos: Vector2, vel: Vector2, min_x: float, max_x: float, damping: float) -> Array:
	var p := pos
	var v := vel
	if p.x < min_x:
		p.x = min_x + (min_x - p.x)
		v.x = absf(v.x) * damping
	elif p.x > max_x:
		p.x = max_x - (p.x - max_x)
		v.x = -absf(v.x) * damping
	return [p, v]

static func max_rise(speed: float, gravity: float) -> float:
	return speed * speed / (2.0 * gravity)
```

- [ ] **Step 4: 테스트 통과 확인**

Step 2와 동일 커맨드. Expected: 전부 passed, exit 0. (`class_name` 인식이 안 되면 프라이밍 커맨드 재실행)

- [ ] **Step 5: Commit**

```powershell
Set-Location ..\..
git add games-src\starfall-drift\src\core\orbit_math.gd games-src\starfall-drift\tests\test_orbit_math.gd
git commit -m "feat(starfall): orbit/ballistic/capture math with unit tests"
```

---

### Task 4: Tuning + Spawner — 난이도 커브와 절차 생성 (TDD)

**Files:**
- Create: `games-src/starfall-drift/src/core/tuning.gd`, `games-src/starfall-drift/src/core/spawner.gd`
- Test: `games-src/starfall-drift/tests/test_spawner.gd`

**Interfaces:**
- Consumes: `OrbitMath.max_rise`
- Produces:
  - `Tuning` — 전 상수 (아래 코드가 정본. 이후 태스크는 여기서만 수치 참조)
  - `Spawner.params_for_height(h: float) -> Dictionary` — 키 `gap, dwarf_p, giant_p, collapse_mult, asteroid_p`
  - `Spawner.pick_type(p: Dictionary, roll: float) -> String` — `"standard" | "dwarf" | "giant"`
  - `Spawner.reachable(from_pos: Vector2, from_r: float, to_pos: Vector2, to_r: float) -> bool`
  - `Spawner.next_star(prev: Dictionary, h: float, rng: RandomNumberGenerator) -> Dictionary` — `prev`/반환 형식 `{"type": String, "pos": Vector2}`

- [ ] **Step 1: tuning.gd 작성 (테스트 대상 아님 — 상수 정본)**

`games-src/starfall-drift/src/core/tuning.gd`:
```gdscript
class_name Tuning
## 전 게임플레이 수치의 단일 정본. 스펙 §3~§6 시작값. 튜닝은 여기서만.

const VIEW_W := 270.0
const VIEW_H := 480.0
const WALL_MIN_X := 10.0
const WALL_MAX_X := 260.0
const WALL_DAMPING := 0.9

const GRAVITY := 240.0          # px/s^2 (하방)
const LAUNCH_SPEED := 260.0     # px/s (접선)
const KILL_MARGIN := 20.0       # 카메라 하단 밖 사망 여유
const CAM_LEAD := 40.0          # 플레이어를 화면 중앙보다 위에 두는 오프셋

const SWIFT_GAUGE := 0.30
const COMBO_MAX := 5
const SWIFT_BONUS := 25
const DWARF_BONUS := 50
const PX_PER_M := 10.0

const STAR_TYPES := {
	"standard": {"sprite": "star_standard", "size": 32.0, "orbit_r": 28.0, "ang_vel": 2.4, "collapse": 3.5},
	"dwarf": {"sprite": "star_dwarf", "size": 16.0, "orbit_r": 16.0, "ang_vel": 3.6, "collapse": 2.0},
	"giant": {"sprite": "star_giant", "size": 48.0, "orbit_r": 44.0, "ang_vel": 1.6, "collapse": 6.0},
}

# 난이도 커브 (h = 시작점 기준 상승 px)
const GAP_BASE := 90.0
const GAP_RANGE := 50.0
const RAMP_H := 10000.0             # 1000m에서 간격·확률 커브 최대
const DWARF_P_BASE := 0.10
const DWARF_P_RANGE := 0.35
const GIANT_P_BASE := 0.25
const GIANT_P_RANGE := -0.15
const COLLAPSE_MULT_RANGE := 0.5    # 최대 1.5배 빨리 붕괴
const COLLAPSE_RAMP_H := 12000.0
const ASTEROID_START_H := 3000.0    # 300m부터 소행성
const ASTEROID_P_BASE := 0.15
const ASTEROID_P_RANGE := 0.25
const ASTEROID_RAMP_H := 12000.0
const ASTEROID_KILL_DIST := 14.0
const ASTEROID_SPEED_MIN := 40.0
const ASTEROID_SPEED_MAX := 80.0
const ASTEROID_SINE_AMP := 20.0

const DEATH_SLOWMO := 0.25
const DEATH_SLOWMO_SEC := 0.5
```

- [ ] **Step 2: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_spawner.gd`:
```gdscript
extends GdUnitTestSuite

func test_params_at_ground() -> void:
	var p := Spawner.params_for_height(0.0)
	assert_float(p.gap).is_equal_approx(90.0, 0.001)
	assert_float(p.dwarf_p).is_equal_approx(0.10, 0.001)
	assert_float(p.giant_p).is_equal_approx(0.25, 0.001)
	assert_float(p.collapse_mult).is_equal_approx(1.0, 0.001)
	assert_float(p.asteroid_p).is_equal_approx(0.0, 0.001)

func test_params_at_ramp_max_and_clamped_beyond() -> void:
	var p := Spawner.params_for_height(10000.0)
	assert_float(p.gap).is_equal_approx(140.0, 0.001)
	assert_float(p.dwarf_p).is_equal_approx(0.45, 0.001)
	assert_float(p.giant_p).is_equal_approx(0.10, 0.001)
	var p2 := Spawner.params_for_height(99999.0)
	assert_float(p2.gap).is_equal_approx(140.0, 0.001)
	assert_float(p2.collapse_mult).is_equal_approx(1.5, 0.001)

func test_asteroid_prob_starts_at_300m() -> void:
	assert_float(Spawner.params_for_height(2999.0).asteroid_p).is_equal_approx(0.0, 0.001)
	assert_float(Spawner.params_for_height(3000.0).asteroid_p).is_equal_approx(0.15, 0.001)
	assert_float(Spawner.params_for_height(15000.0).asteroid_p).is_equal_approx(0.40, 0.001)

func test_pick_type_thresholds() -> void:
	var p := {"dwarf_p": 0.2, "giant_p": 0.3}
	assert_str(Spawner.pick_type(p, 0.19)).is_equal("dwarf")
	assert_str(Spawner.pick_type(p, 0.49)).is_equal("giant")
	assert_str(Spawner.pick_type(p, 0.50)).is_equal("standard")

func test_reachable_within_budget() -> void:
	# max_rise(260,240)=140.8, budget = 140.8+28+28-8 = 189.6
	assert_bool(Spawner.reachable(Vector2(135, 400), 28.0, Vector2(135, 220), 28.0)).is_true()
	assert_bool(Spawner.reachable(Vector2(135, 400), 28.0, Vector2(135, 200), 28.0)).is_false()
	assert_bool(Spawner.reachable(Vector2(30, 400), 28.0, Vector2(200, 350), 28.0)).is_false()  # dx 170 > 160

func test_next_star_always_reachable_and_in_walls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var prev := {"type": "giant", "pos": Vector2(135.0, 380.0)}
	for i in range(300):
		var h := float(i) * 40.0
		var s := Spawner.next_star(prev, h, rng)
		var to_r: float = Tuning.STAR_TYPES[s.type].orbit_r
		var prev_r: float = Tuning.STAR_TYPES[prev.type].orbit_r
		assert_bool(Spawner.reachable(prev.pos, prev_r, s.pos, to_r)).is_true()
		assert_float(s.pos.x).is_greater_equal(Tuning.WALL_MIN_X + to_r)
		assert_float(s.pos.x).is_less_equal(Tuning.WALL_MAX_X - to_r)
		assert_float(s.pos.y).is_less(prev.pos.y)
		prev = s
```

- [ ] **Step 3: 실패 확인**

runtest 커맨드(Global Constraints). Expected: `Spawner` 미정의로 FAIL.

- [ ] **Step 4: 구현**

`games-src/starfall-drift/src/core/spawner.gd`:
```gdscript
class_name Spawner
## 고도 기반 절차 생성. 순수 static — rng는 호출자가 주입(테스트 결정론).

static func params_for_height(h: float) -> Dictionary:
	var t := clampf(h / Tuning.RAMP_H, 0.0, 1.0)
	var asteroid_p := 0.0
	if h >= Tuning.ASTEROID_START_H:
		var ta := clampf((h - Tuning.ASTEROID_START_H) / Tuning.ASTEROID_RAMP_H, 0.0, 1.0)
		asteroid_p = Tuning.ASTEROID_P_BASE + Tuning.ASTEROID_P_RANGE * ta
	return {
		"gap": Tuning.GAP_BASE + Tuning.GAP_RANGE * t,
		"dwarf_p": Tuning.DWARF_P_BASE + Tuning.DWARF_P_RANGE * t,
		"giant_p": Tuning.GIANT_P_BASE + Tuning.GIANT_P_RANGE * t,
		"collapse_mult": 1.0 + Tuning.COLLAPSE_MULT_RANGE * clampf(h / Tuning.COLLAPSE_RAMP_H, 0.0, 1.0),
		"asteroid_p": asteroid_p,
	}

static func pick_type(p: Dictionary, roll: float) -> String:
	if roll < p.dwarf_p:
		return "dwarf"
	if roll < p.dwarf_p + p.giant_p:
		return "giant"
	return "standard"

static func reachable(from_pos: Vector2, from_r: float, to_pos: Vector2, to_r: float) -> bool:
	var rise := from_pos.y - to_pos.y
	var budget := OrbitMath.max_rise(Tuning.LAUNCH_SPEED, Tuning.GRAVITY) + from_r + to_r - 8.0
	return rise <= budget and absf(to_pos.x - from_pos.x) <= 160.0

static func next_star(prev: Dictionary, h: float, rng: RandomNumberGenerator) -> Dictionary:
	var p := params_for_height(h)
	var type := pick_type(p, rng.randf())
	var to_r: float = Tuning.STAR_TYPES[type].orbit_r
	var prev_r: float = Tuning.STAR_TYPES[prev.type].orbit_r
	var prev_pos: Vector2 = prev.pos
	for _i in range(20):
		var gap: float = p.gap * rng.randf_range(0.85, 1.15)
		var x := clampf(prev_pos.x + rng.randf_range(-120.0, 120.0), Tuning.WALL_MIN_X + to_r + 8.0, Tuning.WALL_MAX_X - to_r - 8.0)
		var pos := Vector2(x, prev_pos.y - gap)
		if reachable(prev_pos, prev_r, pos, to_r):
			return {"type": type, "pos": pos}
	return {"type": type, "pos": Vector2(clampf(prev_pos.x, Tuning.WALL_MIN_X + to_r + 8.0, Tuning.WALL_MAX_X - to_r - 8.0), prev_pos.y - Tuning.GAP_BASE)}
```

- [ ] **Step 5: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\starfall-drift\src\core\tuning.gd games-src\starfall-drift\src\core\spawner.gd games-src\starfall-drift\tests\test_spawner.gd
git commit -m "feat(starfall): tuning constants and reachability-guaranteed spawner"
```

---

### Task 5: Scoring + Persistence + GameState (TDD)

**Files:**
- Create: `games-src/starfall-drift/src/core/scoring.gd`, `games-src/starfall-drift/src/core/persistence.gd`
- Modify: `games-src/starfall-drift/src/core/game_state.gd` (스텁 → 본 구현)
- Test: `games-src/starfall-drift/tests/test_scoring.gd`

**Interfaces:**
- Consumes: `Tuning` 상수
- Produces:
  - `Scoring.hop_result(gauge_ratio: float, combo: int) -> Dictionary` — `{"combo": int, "bonus": int}`. combo 기본값 1(×1), 스위프트 시 +1(상한 `COMBO_MAX`), 아니면 1로 리셋
  - `Scoring.height_score(rise_px: float) -> int`
  - `Persistence.save_best(path: String, best: int) -> void` / `Persistence.load_best(path: String) -> int`
  - 오토로드 `GameState`: `enum Phase { TITLE, PLAYING, GAME_OVER }`, 프로퍼티 `phase: int`, `combo: int`, `best: int`, `quick_restart: bool`, 메서드 `start_run() -> void`, `register_hop(gauge_ratio: float) -> int`(획득 보너스 반환), `register_dwarf() -> void`, `update_rise(px: float) -> void`, `score() -> int`, `end_run() -> void`. `_ready`에서 액션 `"drift"` 등록(Space + 마우스 좌클릭)

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_scoring.gd`:
```gdscript
extends GdUnitTestSuite

func test_swift_hop_increments_combo_and_pays() -> void:
	var r := Scoring.hop_result(0.30, 1)
	assert_int(r.combo).is_equal(2)
	assert_int(r.bonus).is_equal(50)

func test_slow_hop_resets_combo_no_bonus() -> void:
	var r := Scoring.hop_result(0.31, 4)
	assert_int(r.combo).is_equal(1)
	assert_int(r.bonus).is_equal(0)

func test_combo_caps_at_max() -> void:
	var r := Scoring.hop_result(0.1, 5)
	assert_int(r.combo).is_equal(5)
	assert_int(r.bonus).is_equal(125)

func test_height_score_floors_and_clamps() -> void:
	assert_int(Scoring.height_score(1234.0)).is_equal(123)
	assert_int(Scoring.height_score(-5.0)).is_equal(0)

func test_persistence_roundtrip() -> void:
	var path := "user://test_best.json"
	Persistence.save_best(path, 777)
	assert_int(Persistence.load_best(path)).is_equal(777)
	DirAccess.remove_absolute(path)

func test_persistence_missing_and_corrupt() -> void:
	assert_int(Persistence.load_best("user://no_such_file.json")).is_equal(0)
	var f := FileAccess.open("user://corrupt.json", FileAccess.WRITE)
	f.store_string("not json{{")
	f.close()
	assert_int(Persistence.load_best("user://corrupt.json")).is_equal(0)
	DirAccess.remove_absolute("user://corrupt.json")

func test_game_state_run_flow() -> void:
	GameState.start_run()
	assert_int(GameState.score()).is_equal(0)
	GameState.update_rise(500.0)
	var bonus := GameState.register_hop(0.2)   # combo 1→2, +50
	assert_int(bonus).is_equal(50)
	GameState.register_dwarf()                 # +50
	assert_int(GameState.score()).is_equal(150)  # 50m + 50 + 50
	GameState.update_rise(400.0)               # 최대치 유지
	assert_int(GameState.score()).is_equal(150)

func test_drift_action_registered() -> void:
	assert_bool(InputMap.has_action("drift")).is_true()
```

- [ ] **Step 2: 실패 확인** — runtest. Expected: `Scoring`/`Persistence` 미정의 FAIL.

- [ ] **Step 3: 구현**

`games-src/starfall-drift/src/core/scoring.gd`:
```gdscript
class_name Scoring

static func hop_result(gauge_ratio: float, combo: int) -> Dictionary:
	if gauge_ratio <= Tuning.SWIFT_GAUGE:
		var new_combo := mini(combo + 1, Tuning.COMBO_MAX)
		return {"combo": new_combo, "bonus": Tuning.SWIFT_BONUS * new_combo}
	return {"combo": 1, "bonus": 0}

static func height_score(rise_px: float) -> int:
	return int(maxf(rise_px, 0.0) / Tuning.PX_PER_M)
```

`games-src/starfall-drift/src/core/persistence.gd`:
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

`games-src/starfall-drift/src/core/game_state.gd` (스텁 교체):
```gdscript
extends Node
## 세션 상태·점수·베스트. 씬 리로드에도 살아남는 오토로드.

enum Phase { TITLE, PLAYING, GAME_OVER }

const BEST_PATH := "user://best.json"

var phase: int = Phase.TITLE
var combo: int = 1
var best: int = 0
var quick_restart: bool = false
var _bonus: int = 0
var _rise_px: float = 0.0

func _ready() -> void:
	best = Persistence.load_best(BEST_PATH)
	_register_input()

func _register_input() -> void:
	if InputMap.has_action("drift"):
		return
	InputMap.add_action("drift")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("drift", key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("drift", mouse)

func start_run() -> void:
	phase = Phase.PLAYING
	combo = 1
	_bonus = 0
	_rise_px = 0.0

func register_hop(gauge_ratio: float) -> int:
	var r := Scoring.hop_result(gauge_ratio, combo)
	combo = r.combo
	_bonus += r.bonus
	return r.bonus

func register_dwarf() -> void:
	_bonus += Tuning.DWARF_BONUS

func update_rise(px: float) -> void:
	_rise_px = maxf(_rise_px, px)

func score() -> int:
	return Scoring.height_score(_rise_px) + _bonus

func end_run() -> void:
	phase = Phase.GAME_OVER
	if score() > best:
		best = score()
		Persistence.save_best(BEST_PATH, best)
```

- [ ] **Step 4: 통과 확인 후 Commit**

runtest — Expected: 전부 passed (하네스 포함 누적).
```powershell
git add games-src\starfall-drift\src\core games-src\starfall-drift\tests\test_scoring.gd
git commit -m "feat(starfall): scoring, persistence, and GameState autoload"
```

---

### Task 6: PixelLab 에셋 생성

**Files:**
- Create: `scripts/gen_pixellab.py`, `games-src/starfall-drift/assets/img/*.png` (player, star_standard, star_dwarf, star_giant, asteroid, cracks, nebula_a, nebula_b, emblem), `scripts/pixellab_out/contact_sheet.png`(검수용, 커밋 안 함)

**Interfaces:**
- Consumes: `.env.local`의 `PIXELLAB_API_KEY`
- Produces: `res://assets/img/<이름>.png` — 파일명은 `Tuning.STAR_TYPES[*].sprite` 값과 일치해야 함 (`star_standard.png`, `star_dwarf.png`, `star_giant.png`) + `player.png`, `asteroid.png`, `cracks.png`, `nebula_a.png`, `nebula_b.png`, `emblem.png`

- [ ] **Step 1: API 스키마 확인**

```powershell
curl -s https://api.pixellab.ai/v1/openapi.json -o "$env:TEMP\pixellab_openapi.json"
python -c "import json;d=json.load(open(r'$env:TEMP\pixellab_openapi.json'));print([p for p in d['paths'] if 'generate' in p]);print(json.dumps(d['paths']['/generate-image-pixflux']['post']['requestBody'],indent=1)[:1200])"
```
Expected: `generate-image-pixflux` 경로와 요청 필드(`description`, `image_size`, `no_background` 등) 확인. **필드명이 아래 스크립트와 다르면 스크립트 상수를 맞춘다.**

- [ ] **Step 2: 생성 스크립트 작성**

`scripts/gen_pixellab.py`:
```python
"""PixelLab으로 STARFALL DRIFT 스프라이트 생성. 실행: python scripts/gen_pixellab.py [이름...]"""
import base64, json, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "starfall-drift", "assets", "img")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

STYLE = ("pixel art, crisp 1px dark outline, retro arcade sprite, night sky palette, "
         "clean readable silhouette, centered, no background")
NEG = "blurry, anti-aliasing, photorealistic, text, watermark, gradient banding"

SPRITES = {
    "player":        (16, 16, f"tiny cute astronaut drifter, round pink #ff77a8 spacesuit, small white visor, {STYLE}"),
    "star_standard": (32, 32, f"round golden star planet, warm yellow #ffec27 glowing core, pale cream rim, subtle surface detail, {STYLE}"),
    "star_dwarf":    (16, 16, f"small dense blue-white dwarf star, bright cyan #29adff core, intense glow, {STYLE}"),
    "star_giant":    (48, 48, f"large soft pink-red giant star, gentle warm #ff77a8 glow, calm majestic sphere, {STYLE}"),
    "asteroid":      (24, 24, f"jagged rocky asteroid, gray-blue #1d2b53 shadows, menacing sharp edges, {STYLE}"),
    "cracks":        (32, 32, f"thin white crack fracture lines overlay, spiderweb cracks from center, transparent background, {STYLE}"),
    "nebula_a":      (64, 32, f"wispy translucent nebula cloud, deep indigo #1d2b53 and violet, soft dreamy, {STYLE}"),
    "nebula_b":      (64, 32, f"faint drifting cosmic dust cloud, dark blue #1d2b53, sparse tiny stars inside, {STYLE}"),
    "emblem":        (48, 48, f"shooting star emblem, yellow #ffec27 star head with pink #ff77a8 sparkling trail, dynamic diagonal, {STYLE}"),
}

def read_key():
    with open(os.path.join(ROOT, ".env.local"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("PIXELLAB_API_KEY not found in .env.local")

def find_base64(obj):
    """응답 어디에 있든 base64 이미지 문자열을 찾는다 (스키마 변화 방어)."""
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
    path = os.path.join(OUT, f"{name}.png")
    with open(path, "wb") as f:
        f.write(base64.b64decode(b64))
    print(f"OK {name} -> {path}")

def main():
    key = read_key()
    targets = sys.argv[1:] or list(SPRITES)
    for name in targets:
        w, h, desc = SPRITES[name]
        generate(key, name, w, h, desc)
        time.sleep(1)

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: 생성 실행 + 검수 시트**

```powershell
python scripts\gen_pixellab.py
python -c @"
from PIL import Image
import os
d = r'games-src\starfall-drift\assets\img'
names = ['player','star_standard','star_dwarf','star_giant','asteroid','cracks','nebula_a','nebula_b','emblem']
sheet = Image.new('RGBA', (len(names)*72, 72), (12,10,28,255))
for i,n in enumerate(names):
    im = Image.open(os.path.join(d, n+'.png')).convert('RGBA')
    im = im.resize((im.width*3, im.height*3), Image.NEAREST)
    sheet.paste(im, (i*72+4, 36-im.height//2), im)
os.makedirs(r'scripts\pixellab_out', exist_ok=True)
sheet.save(r'scripts\pixellab_out\contact_sheet.png')
print('sheet saved')
"@
```
Expected: 9개 PNG 생성, contact_sheet.png 저장. **contact_sheet.png를 Read 도구로 열어 눈으로 검수** — 실루엣이 안 읽히거나 팔레트가 튀는 스프라이트는 프롬프트를 다듬어 해당 이름만 재생성(`python scripts\gen_pixellab.py star_dwarf`). API가 16px 미지원 등으로 거부하면 32px로 생성 후 `Image.resize((16,16), Image.NEAREST)` 다운스케일을 스크립트에 추가.

- [ ] **Step 4: 크기 검증 + Godot 임포트 스모크**

```powershell
python -c @"
from PIL import Image
import os
exp = {'player':(16,16),'star_standard':(32,32),'star_dwarf':(16,16),'star_giant':(48,48),'asteroid':(24,24),'cracks':(32,32),'nebula_a':(64,32),'nebula_b':(64,32),'emblem':(48,48)}
d = r'games-src\starfall-drift\assets\img'
for n,(w,h) in exp.items():
    s = Image.open(os.path.join(d, n+'.png')).size
    assert s == (w,h), f'{n}: {s} != {(w,h)}'
print('all sizes OK')
"@
& $GODOT --headless --path games-src\starfall-drift --quit
```
Expected: `all sizes OK`, Godot 임포트 에러 없이 exit 0.

- [ ] **Step 5: Commit**

```powershell
git add scripts\gen_pixellab.py games-src\starfall-drift\assets\img
git commit -m "feat(starfall): PixelLab-generated sprites and asset pipeline"
```

---

### Task 7: 사운드 — SFX 합성 + Sfx 오토로드

**Files:**
- Create: `scripts/gen_audio_starfall.py`, `games-src/starfall-drift/assets/sfx/*.wav` (hop, capture, warn, death, combo, ambient)
- Modify: `games-src/starfall-drift/src/core/sfx.gd` (스텁 → 본 구현)
- Test: `games-src/starfall-drift/tests/test_sfx.gd`

**Interfaces:**
- Produces: 오토로드 `Sfx`: `play(name: String, volume_db: float = 0.0) -> void`, `start_ambient() -> void`, `stop_ambient() -> void`. 존재하지 않는 이름은 조용히 무시(에셋 없이도 게임 동작)

- [ ] **Step 1: 합성 스크립트 작성 (stdlib만 사용)**

`scripts/gen_audio_starfall.py`:
```python
"""STARFALL DRIFT SFX 합성 (stdlib만). 실행: python scripts/gen_audio_starfall.py"""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "games-src", "starfall-drift", "assets", "sfx")

def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print("OK", name)

def env(i, n, a=0.01, r=0.3):
    t = i / n
    if t < a: return t / a
    return max(0.0, 1.0 - (t - a) / max(1e-6, r))

def square(f, t): return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0

def blip(f0, f1, dur, vol=0.5, wave_fn=square):
    n = int(SR * dur)
    return [vol * env(i, n) * wave_fn(f0 + (f1 - f0) * (i / n), i / SR) for i in range(n)]

def noise(dur, vol=0.5, decay=0.9995):
    n = int(SR * dur); a = vol; out = []
    for i in range(n):
        out.append(a * env(i, n, 0.005, 0.9) * random.uniform(-1, 1)); a *= decay
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]

random.seed(7)
save("hop", blip(600, 950, 0.09, 0.45))
save("capture", mix(blip(523, 523, 0.07, 0.35), [0.0] * int(SR * 0.06) + blip(784, 784, 0.10, 0.35)))
save("warn", blip(180, 140, 0.12, 0.4))
save("death", mix(noise(0.5, 0.5), blip(300, 60, 0.5, 0.3)))
save("combo", mix(*[[0.0] * int(SR * 0.05 * k) + blip(660 + 110 * k, 660 + 110 * k, 0.06, 0.3) for k in range(3)]))
amb_n = int(SR * 8.0)
amb = [0.10 * math.sin(2 * math.pi * 55 * i / SR) + 0.05 * math.sin(2 * math.pi * 82.5 * i / SR + 0.5)
       + 0.02 * random.uniform(-1, 1) for i in range(amb_n)]
fade = int(SR * 0.05)
for i in range(fade):  # 루프 이음새 클릭 제거용 크로스페이드
    amb[i] = amb[i] * (i / fade) + amb[amb_n - fade + i] * (1 - i / fade)
save("ambient", amb[: amb_n - fade])
```

```powershell
python scripts\gen_audio_starfall.py
```
Expected: 6개 wav 생성 로그.

- [ ] **Step 2: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_sfx.gd`:
```gdscript
extends GdUnitTestSuite

func test_streams_loaded() -> void:
	for n in ["hop", "capture", "warn", "death", "combo", "ambient"]:
		assert_bool(Sfx.has_stream(n)).is_true()

func test_unknown_name_is_silent_noop() -> void:
	Sfx.play("no_such_sound")   # 크래시 없이 통과하면 성공
	assert_bool(true).is_true()
```

runtest — Expected: `has_stream` 미정의 FAIL.

- [ ] **Step 3: Sfx 구현**

`games-src/starfall-drift/src/core/sfx.gd` (스텁 교체):
```gdscript
extends Node
## 원샷 SFX + 앰비언트 루프. 스트림이 없으면 조용히 무시.

var _streams: Dictionary = {}
var _ambient: AudioStreamPlayer

func _ready() -> void:
	for n in ["hop", "capture", "warn", "death", "combo", "ambient"]:
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

func start_ambient() -> void:
	if _ambient != null or not _streams.has("ambient"):
		return
	var stream: AudioStreamWAV = _streams["ambient"]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = stream
	_ambient.volume_db = -10.0
	add_child(_ambient)
	_ambient.play()

func stop_ambient() -> void:
	if _ambient:
		_ambient.queue_free()
		_ambient = null
```

- [ ] **Step 4: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add scripts\gen_audio_starfall.py games-src\starfall-drift\assets\sfx games-src\starfall-drift\src\core\sfx.gd games-src\starfall-drift\tests\test_sfx.gd
git commit -m "feat(starfall): synthesized SFX and Sfx autoload"
```

---

### Task 8: Star — 별 노드와 붕괴 연출

**Files:**
- Create: `games-src/starfall-drift/src/star.gd`
- Test: `games-src/starfall-drift/tests/test_star.gd`

**Interfaces:**
- Consumes: `Tuning.STAR_TYPES`, `GameState.phase`
- Produces: `Star extends Node2D` (씬 파일 없음 — `Star.new()`로 생성, 자식은 `_ready`에서 구성):
  - `signal collapsed(star: Star)`
  - `setup(t: String, collapse_mult: float) -> void` — 반드시 add_child 후(또는 _ready 이후) 호출
  - 프로퍼티: `type: String`, `orbit_r: float`, `ang_vel: float`, `collapse_time: float`, `gauge: float`, `occupied: bool`, `alive: bool`
  - `gauge_ratio() -> float`
  - 붕괴 연출: 게이지 25%부터 크랙 오버레이 페이드인, 40%부터 흔들림, 60%부터 파편 방출, 60% 최초 도달 시 `Sfx.play("warn")`, 100%에서 `collapsed` emit 후 파편 버스트와 함께 소멸

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_star.gd`:
```gdscript
extends GdUnitTestSuite

func test_setup_reads_tuning() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	assert_float(s.orbit_r).is_equal_approx(16.0, 0.001)
	assert_float(s.ang_vel).is_equal_approx(3.6, 0.001)
	assert_float(s.collapse_time).is_equal_approx(2.0, 0.001)

func test_collapse_mult_shortens_life() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.5)
	assert_float(s.collapse_time).is_equal_approx(3.5 / 1.5, 0.001)

func test_gauge_advances_only_when_occupied_playing() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("standard", 1.0)
	GameState.phase = GameState.Phase.PLAYING
	s.occupied = false
	s.tick(1.0)
	assert_float(s.gauge).is_equal_approx(0.0, 0.001)
	s.occupied = true
	s.tick(1.0)
	assert_float(s.gauge_ratio()).is_equal_approx(1.0 / 3.5, 0.001)

func test_full_gauge_emits_collapsed() -> void:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup("dwarf", 1.0)
	GameState.phase = GameState.Phase.PLAYING
	s.occupied = true
	var got: Array = []
	s.collapsed.connect(func(star): got.append(star))
	s.tick(2.5)
	assert_int(got.size()).is_equal(1)
	assert_bool(s.alive).is_false()
```

runtest — Expected: `Star` 미정의 FAIL.

- [ ] **Step 2: 구현**

`games-src/starfall-drift/src/star.gd`:
```gdscript
class_name Star
extends Node2D
## 별 하나. 잡히면 붕괴 게이지가 차고, 다 차면 collapsed를 emit하고 소멸.

signal collapsed(star: Star)

var type: String = "standard"
var orbit_r: float = 28.0
var ang_vel: float = 2.4
var collapse_time: float = 3.5
var gauge: float = 0.0
var occupied := false
var alive := true

var _body: Sprite2D
var _cracks: Sprite2D
var _debris: CPUParticles2D
var _warned := false

func _ready() -> void:
	_body = Sprite2D.new()
	_cracks = Sprite2D.new()
	_cracks.modulate.a = 0.0
	_debris = CPUParticles2D.new()
	_debris.emitting = false
	_debris.amount = 8
	_debris.lifetime = 0.6
	_debris.spread = 180.0
	_debris.initial_velocity_min = 20.0
	_debris.initial_velocity_max = 60.0
	_debris.gravity = Vector2(0, 120)
	_debris.scale_amount_min = 1.0
	_debris.scale_amount_max = 2.0
	_debris.color = Color("#FFF1E8")
	add_child(_body)
	add_child(_cracks)
	add_child(_debris)

func setup(t: String, collapse_mult: float) -> void:
	type = t
	var d: Dictionary = Tuning.STAR_TYPES[t]
	orbit_r = d.orbit_r
	ang_vel = d.ang_vel
	collapse_time = d.collapse / collapse_mult
	_body.texture = load("res://assets/img/%s.png" % d.sprite)
	_cracks.texture = load("res://assets/img/cracks.png")
	_cracks.scale = Vector2.ONE * (d.size / 32.0)

func gauge_ratio() -> float:
	return gauge / collapse_time

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not alive or not occupied or GameState.phase != GameState.Phase.PLAYING:
		return
	gauge += delta
	var r := gauge_ratio()
	_cracks.modulate.a = clampf((r - 0.25) / 0.75, 0.0, 1.0)
	var shake := 2.5 * maxf(r - 0.4, 0.0)
	_body.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	_cracks.position = _body.position
	if r >= 0.6:
		_debris.emitting = true
		if not _warned:
			_warned = true
			Sfx.play("warn")
	if gauge >= collapse_time:
		_collapse()

func _collapse() -> void:
	alive = false
	collapsed.emit(self)
	_body.visible = false
	_cracks.visible = false
	_debris.one_shot = true
	_debris.amount = 24
	_debris.emitting = true
	var t := get_tree().create_timer(0.8)
	t.timeout.connect(queue_free)
```

- [ ] **Step 3: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\starfall-drift\src\star.gd games-src\starfall-drift\tests\test_star.gd
git commit -m "feat(starfall): star node with collapse gauge and crumble effects"
```

---

### Task 9: Player — 궤도/비행/사망 상태 머신

**Files:**
- Create: `games-src/starfall-drift/src/player.gd`
- Test: `games-src/starfall-drift/tests/test_player.gd`

**Interfaces:**
- Consumes: `OrbitMath.*`, `Tuning.*`, `Star`(orbit_r/ang_vel/gauge_ratio/occupied/alive/global_position), `GameState.register_hop/register_dwarf`
- Produces: `Player extends Node2D` (씬 파일 없음):
  - `signal died` / `signal hopped(bonus: int)` / `signal captured(star: Star)`
  - `enum State { ORBITING, FLYING, DEAD }`, 프로퍼티 `state: int`, `star: Star`, `vel: Vector2`, `last_star: Star`(재포획 방지)
  - `attach_to(s: Star, entry_pos: Vector2, entry_vel: Vector2) -> void` — 궤도 스냅 + 방향 결정, 왜성이면 `GameState.register_dwarf()`
  - `launch() -> void` — ORBITING에서만. `GameState.register_hop(게이지)` 정산 후 접선 발사
  - `die() -> void`, `tick(delta: float) -> void`(_process가 위임 — 테스트에서 직접 구동)

- [ ] **Step 1: 실패하는 테스트 작성**

`games-src/starfall-drift/tests/test_player.gd`:
```gdscript
extends GdUnitTestSuite

func _mk_star(t: String, pos: Vector2) -> Star:
	var s: Star = auto_free(Star.new())
	add_child(s)
	s.setup(t, 1.0)
	s.global_position = pos
	return s

func _mk_player() -> Player:
	var p: Player = auto_free(Player.new())
	add_child(p)
	return p

func test_attach_snaps_to_ring_and_sets_dir() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	# 오른쪽에서 아래로 향하는 진입 → dir +1
	p.attach_to(s, Vector2(130, 100), Vector2(0, 50))
	assert_int(p.state).is_equal(Player.State.ORBITING)
	assert_bool(s.occupied).is_true()
	assert_float(p.global_position.distance_to(s.global_position)).is_equal_approx(28.0, 0.01)
	assert_int(p.dir).is_equal(1)

func test_orbiting_follows_ring() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	p.tick(0.25)
	assert_float(p.global_position.distance_to(s.global_position)).is_equal_approx(28.0, 0.01)

func test_launch_releases_star_and_flies() -> void:
	GameState.start_run()
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	p.launch()
	assert_int(p.state).is_equal(Player.State.FLYING)
	assert_bool(s.occupied).is_false()
	assert_bool(p.vel.length() > 0.0).is_true()
	assert_int(GameState.combo).is_equal(2)   # 게이지 0% 스위프트

func test_flight_gravity_pulls_down() -> void:
	var p := _mk_player()
	p.state = Player.State.FLYING
	p.global_position = Vector2(135, 200)
	p.vel = Vector2(0, -100)
	p.tick(0.1)
	assert_bool(p.vel.y > -100.0).is_true()

func test_dwarf_capture_pays_bonus() -> void:
	GameState.start_run()
	var s := _mk_star("dwarf", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(116, 100), Vector2(0, 50))
	assert_int(GameState.score()).is_equal(50)

func test_die_is_idempotent_and_frees_star() -> void:
	var s := _mk_star("standard", Vector2(100, 100))
	var p := _mk_player()
	p.attach_to(s, Vector2(128, 100), Vector2(0, 50))
	var count: Array = []
	p.died.connect(func(): count.append(1))
	p.die()
	p.die()
	assert_int(count.size()).is_equal(1)
	assert_bool(s.occupied).is_false()
```

runtest — Expected: `Player` 미정의 FAIL.

- [ ] **Step 2: 구현**

`games-src/starfall-drift/src/player.gd`:
```gdscript
class_name Player
extends Node2D
## 표류자. ORBITING(별 공전) → FLYING(접선 발사·포물선) → 포획 반복. 실패 시 DEAD.

signal died
signal hopped(bonus: int)
signal captured(star: Star)

enum State { ORBITING, FLYING, DEAD }

var state: int = State.ORBITING
var star: Star = null
var last_star: Star = null
var angle := 0.0
var dir := 1
var vel := Vector2.ZERO

var _sprite: Sprite2D
var _trail: CPUParticles2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/img/player.png")
	_trail = CPUParticles2D.new()
	_trail.amount = 12
	_trail.lifetime = 0.4
	_trail.local_coords = false
	_trail.scale_amount_min = 1.0
	_trail.scale_amount_max = 1.5
	_trail.color = Color("#FF77A8")
	_trail.emitting = true
	add_child(_trail)
	add_child(_sprite)

func attach_to(s: Star, entry_pos: Vector2, entry_vel: Vector2) -> void:
	star = s
	star.occupied = true
	last_star = s
	dir = OrbitMath.entry_dir(s.global_position, entry_pos, entry_vel)
	angle = OrbitMath.entry_angle(s.global_position, entry_pos)
	global_position = OrbitMath.orbit_pos(s.global_position, s.orbit_r, angle)
	state = State.ORBITING
	if s.type == "dwarf":
		GameState.register_dwarf()
	Sfx.play("capture")
	captured.emit(s)

func launch() -> void:
	if state != State.ORBITING or star == null:
		return
	var bonus := GameState.register_hop(star.gauge_ratio())
	vel = OrbitMath.launch_velocity(star.global_position, global_position, dir, Tuning.LAUNCH_SPEED)
	star.occupied = false
	star = null
	state = State.FLYING
	Sfx.play("hop")
	if bonus > 0 and GameState.combo >= 3:
		Sfx.play("combo")
	hopped.emit(bonus)

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if star:
		star.occupied = false
		star = null
	_sprite.visible = false
	_trail.emitting = false
	Sfx.play("death")
	died.emit()

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	match state:
		State.ORBITING:
			if star == null or not star.alive:
				return
			angle = OrbitMath.advance_angle(angle, star.ang_vel, dir, delta)
			global_position = OrbitMath.orbit_pos(star.global_position, star.orbit_r, angle)
			_sprite.rotation = angle + (PI / 2.0 if dir == 1 else -PI / 2.0)
		State.FLYING:
			var r := OrbitMath.integrate_flight(global_position, vel, Tuning.GRAVITY, delta)
			var b := OrbitMath.bounce_x(r[0], r[1], Tuning.WALL_MIN_X, Tuning.WALL_MAX_X, Tuning.WALL_DAMPING)
			global_position = b[0]
			vel = b[1]
			_sprite.rotation = vel.angle() + PI / 2.0
			if last_star != null and (not is_instance_valid(last_star) or global_position.distance_to(last_star.global_position) > last_star.orbit_r + 4.0):
				last_star = null
```

- [ ] **Step 3: 통과 확인 후 Commit**

runtest — Expected: 전부 passed.
```powershell
git add games-src\starfall-drift\src\player.gd games-src\starfall-drift\tests\test_player.gd
git commit -m "feat(starfall): player orbit/flight/death state machine"
```

---

### Task 10: Main — 월드 조립·카메라·스폰·충돌·HUD·배경

**Files:**
- Create: `games-src/starfall-drift/src/asteroid.gd`, `games-src/starfall-drift/src/starfield.gd`, `games-src/starfall-drift/src/hud.gd`
- Modify: `games-src/starfall-drift/src/main.gd` (스텁 → 본 구현)

**Interfaces:**
- Consumes: `Player`, `Star`, `Spawner`, `Tuning`, `GameState`, `Sfx`
- Produces: 실행 가능한 게임플레이(타이틀·게임오버는 Task 11). `Main`은 그룹 노드 `"stars"`·`"asteroids"`를 관리. `Hud extends CanvasLayer`: `set_altitude(m: int) -> void`, `set_combo(mult: int) -> void`, `show_bonus(text: String) -> void`. `Asteroid extends Node2D`: `setup(y: float, rng_seed: int) -> void`, `tick(delta)`. `Starfield extends Node2D`: 카메라 자식으로 배치, 스크린 공간 별똥별 2겹

- [ ] **Step 1: Asteroid 구현**

`games-src/starfall-drift/src/asteroid.gd`:
```gdscript
class_name Asteroid
extends Node2D
## 좌우로 흐르며 사인 진동하는 즉사 장애물.

var _speed := 60.0
var _dir := 1.0
var _base_y := 0.0
var _phase := 0.0
var _t := 0.0

func _ready() -> void:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/img/asteroid.png")
	add_child(sp)

func setup(y: float, rng: RandomNumberGenerator) -> void:
	_base_y = y
	_speed = rng.randf_range(Tuning.ASTEROID_SPEED_MIN, Tuning.ASTEROID_SPEED_MAX)
	_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_phase = rng.randf_range(0.0, TAU)
	global_position = Vector2(Tuning.WALL_MIN_X if _dir > 0.0 else Tuning.WALL_MAX_X, y)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING:
		return
	_t += delta
	global_position.x += _speed * _dir * delta
	global_position.y = _base_y + sin(_t * 2.0 + _phase) * Tuning.ASTEROID_SINE_AMP
	rotation += delta * _dir * 1.5
	if global_position.x < Tuning.WALL_MIN_X - 30.0 or global_position.x > Tuning.WALL_MAX_X + 30.0:
		_dir *= -1.0
```

- [ ] **Step 2: Starfield 구현**

`games-src/starfall-drift/src/starfield.gd`:
```gdscript
class_name Starfield
extends Node2D
## 카메라에 붙는 배경: 아래로 쏟아지는 별똥별 2겹 + 성운. "거슬러 오른다"의 그림.

func _ready() -> void:
	z_index = -10
	for cfg in [
		{"amount": 30, "vel": 40.0, "alpha": 0.35, "size": 1.0},
		{"amount": 16, "vel": 90.0, "alpha": 0.7, "size": 2.0},
	]:
		var p := CPUParticles2D.new()
		p.amount = cfg.amount
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(Tuning.VIEW_W / 2.0 + 20.0, Tuning.VIEW_H / 2.0 + 40.0)
		p.direction = Vector2(0, 1)
		p.spread = 5.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = cfg.vel * 0.7
		p.initial_velocity_max = cfg.vel
		p.scale_amount_min = cfg.size
		p.scale_amount_max = cfg.size
		p.color = Color(1.0, 0.95, 0.91, cfg.alpha)   # #FFF1E8
		add_child(p)
	for i in range(2):
		var neb := Sprite2D.new()
		neb.texture = load("res://assets/img/nebula_%s.png" % ["a", "b"][i])
		neb.modulate.a = 0.5
		neb.position = Vector2([-60.0, 70.0][i], [-140.0, 100.0][i])
		neb.z_index = -5
		add_child(neb)
```

- [ ] **Step 3: HUD 구현**

`games-src/starfall-drift/src/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## 고도·콤보 최소 표시 + 보너스 플로터.

var _alt: Label
var _combo: Label
var _bonus: Label
var _bonus_tw: Tween

func _make_label(size: int, pos: Vector2, color := Color("#FFF1E8")) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Galmuri9.ttf")
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.position = pos
	add_child(l)
	return l

func _ready() -> void:
	_alt = _make_label(18, Vector2(10, 8))
	_combo = _make_label(9, Vector2(10, 30), Color("#FFEC27"))
	_bonus = _make_label(9, Vector2(180, 8), Color("#29ADFF"))
	_bonus.modulate.a = 0.0

func set_altitude(m: int) -> void:
	_alt.text = "%dm" % m

func set_combo(mult: int) -> void:
	_combo.text = "x%d" % mult if mult > 1 else ""

func show_bonus(text: String) -> void:
	_bonus.text = text
	_bonus.modulate.a = 1.0
	if _bonus_tw:
		_bonus_tw.kill()
	_bonus_tw = create_tween()
	_bonus_tw.tween_property(_bonus, "modulate:a", 0.0, 0.8).set_delay(0.4)
```

- [ ] **Step 4: Main 게임플레이 배선**

`games-src/starfall-drift/src/main.gd` (스텁 교체 — 타이틀/게임오버 오버레이는 Task 11에서 추가):
```gdscript
extends Node2D
## 월드 조립: 스폰·카메라·충돌·낙사 판정. 상태 오버레이는 task 11.

var cam: Camera2D
var hud: Hud
var player: Player
var stars_root: Node2D
var asteroids_root: Node2D
var rng := RandomNumberGenerator.new()

var start_y := 0.0
var top_star: Dictionary = {}   # {"type": String, "pos": Vector2} — 스포너 체인의 최상단
var cam_target_y := 0.0

func _ready() -> void:
	rng.randomize()
	stars_root = Node2D.new()
	asteroids_root = Node2D.new()
	add_child(stars_root)
	add_child(asteroids_root)
	cam = Camera2D.new()
	cam.position = Vector2(Tuning.VIEW_W / 2.0, Tuning.VIEW_H / 2.0)
	add_child(cam)
	cam.make_current()
	cam.add_child(Starfield.new())
	hud = Hud.new()
	add_child(hud)
	_build_world()
	Sfx.start_ambient()

func _build_world() -> void:
	start_y = Tuning.VIEW_H - 100.0
	var first := _spawn_star("giant", Vector2(Tuning.VIEW_W / 2.0, start_y), 1.0)
	top_star = {"type": "giant", "pos": first.global_position}
	player = Player.new()
	add_child(player)
	player.died.connect(_on_player_died)
	player.hopped.connect(func(bonus: int) -> void:
		if bonus > 0:
			hud.show_bonus("+%d" % bonus)
	)
	player.attach_to(first, first.global_position + Vector2(first.orbit_r, 0), Vector2(0, 10))
	cam_target_y = cam.position.y

func _spawn_star(type: String, pos: Vector2, collapse_mult: float) -> Star:
	var s := Star.new()
	stars_root.add_child(s)
	s.setup(type, collapse_mult)
	s.global_position = pos
	s.add_to_group("stars")
	s.collapsed.connect(_on_star_collapsed)
	return s

func _height() -> float:
	return start_y - player.global_position.y if player else 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	_handle_capture()
	_handle_asteroid_hit()
	_stream_spawn()
	_update_camera(delta)
	_check_fall_death()
	GameState.update_rise(_height())
	hud.set_altitude(Scoring.height_score(_height()))
	hud.set_combo(GameState.combo)

func _handle_capture() -> void:
	if player.state != Player.State.FLYING:
		return
	for s in stars_root.get_children():
		var star := s as Star
		if star == null or not star.alive or star == player.last_star:
			continue
		if OrbitMath.try_capture(player.global_position, star.global_position, star.orbit_r):
			player.attach_to(star, player.global_position, player.vel)
			return

func _handle_asteroid_hit() -> void:
	if player.state == Player.State.DEAD:
		return
	for a in asteroids_root.get_children():
		if player.global_position.distance_to((a as Node2D).global_position) < Tuning.ASTEROID_KILL_DIST:
			player.die()
			return

func _stream_spawn() -> void:
	var view_top := cam.position.y - Tuning.VIEW_H / 2.0
	while (top_star.pos as Vector2).y > view_top - 200.0:
		var h: float = start_y - (top_star.pos as Vector2).y
		var next := Spawner.next_star(top_star, h, rng)
		var p := Spawner.params_for_height(h)
		_spawn_star(next.type, next.pos, p.collapse_mult)
		if rng.randf() < p.asteroid_p:
			var ast := Asteroid.new()
			asteroids_root.add_child(ast)
			ast.add_to_group("asteroids")
			ast.setup((next.pos as Vector2).y + 45.0, rng)
		top_star = next
	var view_bottom := cam.position.y + Tuning.VIEW_H / 2.0
	for s in stars_root.get_children():
		if (s as Node2D).global_position.y > view_bottom + 100.0:
			s.queue_free()
	for a in asteroids_root.get_children():
		if (a as Node2D).global_position.y > view_bottom + 100.0:
			a.queue_free()

func _update_camera(delta: float) -> void:
	cam_target_y = minf(cam_target_y, player.global_position.y + Tuning.CAM_LEAD)
	cam.position.y = lerpf(cam.position.y, cam_target_y, minf(6.0 * delta, 1.0))

func _check_fall_death() -> void:
	if player.state == Player.State.FLYING and player.global_position.y > cam.position.y + Tuning.VIEW_H / 2.0 + Tuning.KILL_MARGIN:
		player.die()

func _on_star_collapsed(s: Star) -> void:
	if player and player.star == s:
		player.die()

func _on_player_died() -> void:
	GameState.end_run()   # 게임오버 연출·오버레이는 Task 11

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drift") and GameState.phase == GameState.Phase.PLAYING:
		player.launch()
```

- [ ] **Step 5: 헤드리스 스모크 + 수동 확인**

```powershell
& $GODOT --headless --path games-src\starfall-drift --quit-after 300
```
Expected: exit 0, 스크립트 에러 없음 (300프레임 동안 스폰·카메라 로직 구동).

```powershell
& "C:\Users\LeeDoik\tools\godot\godot.exe" --path games-src\starfall-drift
```
수동 확인: 거성 공전 → 스페이스/클릭으로 이탈 → 포획 → 위로 진행 → 낙하/붕괴/소행성 사망 시 화면 정지(오버레이는 다음 태스크). 기존 gdUnit 스위트도 재실행해 회귀 없음 확인.

- [ ] **Step 6: Commit**

```powershell
git add games-src\starfall-drift\src
git commit -m "feat(starfall): world assembly - camera, streaming spawn, collisions, HUD, starfield"
```

---

### Task 11: 세션 흐름 — 타이틀·게임오버·일시정지·주스

**Files:**
- Create: `games-src/starfall-drift/src/overlay.gd`
- Modify: `games-src/starfall-drift/src/main.gd`

**Interfaces:**
- Consumes: `GameState.phase/quick_restart/score()/best`, `Tuning.DEATH_SLOWMO*`
- Produces: 완결된 세션 루프 — 타이틀("TAP TO DRIFT", 첫 별 공전 대기) → 플레이 → 사망 슬로모 0.5s → 게임오버(SCORE/BEST/"TAP TO RETRY") → 탭 → 즉시 재시작(타이틀 스킵). 포커스 아웃 시 일시정지 오버레이("PAUSED — TAP TO RESUME")

- [ ] **Step 1: Overlay 구현**

`games-src/starfall-drift/src/overlay.gd`:
```gdscript
class_name Overlay
extends CanvasLayer
## 타이틀/게임오버/일시정지 텍스트 오버레이. 일시정지 중에도 입력을 받도록 ALWAYS.

var _lines: Array[Label] = []
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
		l.queue_free()
	_lines.clear()
	_emblem.visible = false
	visible = false

func show_title() -> void:
	clear()
	visible = true
	_emblem.visible = true
	_label("STARFALL DRIFT", 170, 22, Color("#FFEC27"))
	_label("TAP TO DRIFT", 220, 11, Color("#FFF1E8"))

func show_game_over(score: int, best: int, new_best: bool) -> void:
	clear()
	visible = true
	_label("SCORE  %d" % score, 160, 16, Color("#FFF1E8"))
	_label("BEST   %d" % best, 190, 16, Color("#FFEC27" if new_best else "#29ADFF"))
	if new_best:
		_label("NEW RECORD!", 220, 11, Color("#FF77A8"))
	_label("TAP TO RETRY", 260, 11, Color("#FFF1E8"))

func show_paused() -> void:
	clear()
	visible = true
	_label("PAUSED", 200, 16, Color("#FFF1E8"))
	_label("TAP TO RESUME", 230, 11, Color("#29ADFF"))
```

- [ ] **Step 2: Main에 상태 흐름 연결**

`games-src/starfall-drift/src/main.gd` 수정 — 멤버 추가:
```gdscript
var overlay: Overlay
var _paused := false
```
`_ready()` 끝에 추가:
```gdscript
	overlay = Overlay.new()
	add_child(overlay)
	if GameState.quick_restart:
		GameState.quick_restart = false
		GameState.start_run()
		overlay.clear()
	else:
		GameState.phase = GameState.Phase.TITLE
		overlay.show_title()
```
`_on_player_died()`를 다음으로 교체:
```gdscript
func _on_player_died() -> void:
	var was_best := GameState.best
	GameState.end_run()
	Engine.time_scale = Tuning.DEATH_SLOWMO
	var t := get_tree().create_timer(Tuning.DEATH_SLOWMO_SEC * Tuning.DEATH_SLOWMO, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		overlay.show_game_over(GameState.score(), GameState.best, GameState.best > was_best)
	)
```
`_unhandled_input()`을 다음으로 교체:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("drift"):
		return
	if _paused:
		_paused = false
		get_tree().paused = false
		overlay.clear()
		return
	match GameState.phase:
		GameState.Phase.TITLE:
			overlay.clear()
			GameState.start_run()
			player.launch()
		GameState.Phase.PLAYING:
			player.launch()
		GameState.Phase.GAME_OVER:
			if Engine.time_scale == 1.0:
				GameState.quick_restart = true
				get_tree().reload_current_scene()
```
`_notification` 추가:
```gdscript
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _paused:
		_paused = true
		get_tree().paused = true
		overlay.show_paused()
```

- [ ] **Step 3: 검증**

```powershell
& $GODOT --headless --path games-src\starfall-drift --quit-after 300
Set-Location games-src\starfall-drift
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
Set-Location ..\..
& "C:\Users\LeeDoik\tools\godot\godot.exe" --path games-src\starfall-drift
```
수동 확인: 타이틀 → 탭 시작 → 사망 슬로모 → 게임오버 스코어/베스트 → 탭 즉시 재시작(타이틀 스킵) → 창 포커스 아웃 시 PAUSED → 탭 재개. 베스트가 재시작 후에도 유지.

- [ ] **Step 4: Commit**

```powershell
git add games-src\starfall-drift\src
git commit -m "feat(starfall): title/game-over/pause flow with death slow-mo"
```

---

### Task 12: 웹 익스포트 + 카트리지 등록 + 검증

**Files:**
- Create: `games-src/starfall-drift/export_presets.cfg`, `games-src/starfall-drift/web/shell.html`, `public/games/starfall-drift/*`(익스포트 산출물), `docs/superpowers/specs/starfall-drift-playtest.md`
- Modify: `content/games/01-starfall-drift.json`

**Interfaces:**
- Consumes: 게임 레코드 스키마 `src/lib/games.ts`(slug/order/title/description/tags/coverScene/playPath)
- Produces: 브라우저에서 플레이되는 STARFALL DRIFT 카트리지 (모바일 터치 포함)

- [ ] **Step 1: 커스텀 셸**

```powershell
New-Item -ItemType Directory -Force games-src\starfall-drift\web
Copy-Item games-src\last-login\web\shell.html games-src\starfall-drift\web\shell.html
```
`games-src/starfall-drift/web/shell.html` 수정 — 2곳:
1. `#boot-text` CSS의 `color: #9adfc0` → `color: #29ADFF`, `body`의 `background-color: #000` → `background-color: #0C0A1C`, progress 바 색 `#9adfc0` 3곳 → `#FFEC27`
2. boot-text div 내용 교체:
```html
	<div id="boot-text">NEO_KIDO ARCADE SYSTEM
CARTRIDGE: STARFALL DRIFT
CALIBRATING GRAVITY ...</div>
```
(`$GODOT_CONFIG` 등 플레이스홀더는 유지 — 삭제·개명 금지)

- [ ] **Step 2: export_presets.cfg**

`games-src/starfall-drift/export_presets.cfg`:
```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="addons/gdUnit4/*"
export_path="../../public/games/starfall-drift/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/export_icon=true
html/custom_html_shell="res://web/shell.html"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
```

- [ ] **Step 3: 익스포트 실행**

```powershell
Get-ChildItem "$env:APPDATA\Godot\export_templates\4.7.1.stable\web_nothreads_release.zip"   # 템플릿 존재 확인
New-Item -ItemType Directory -Force public\games\starfall-drift
& $GODOT --headless --path games-src\starfall-drift --export-release "Web" "../../public/games/starfall-drift/index.html"
Get-ChildItem public\games\starfall-drift | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
```
Expected: index.html/.js/.wasm/.pck 생성, 전 파일 100MB 미만.

- [ ] **Step 4: 카트리지 레코드 갱신**

`content/games/01-starfall-drift.json` 전체 교체:
```json
{
  "slug": "starfall-drift",
  "order": 10,
  "title": "STARFALL DRIFT",
  "description": "붕괴하는 별을 갈아타며 쏟아지는 별똥별을 거슬러 오르는 원버튼 아케이드.\n탭 한 번으로 궤도 이탈 — 별이 부서지기 전에 다음 별로.\n얼마나 높이 표류할 수 있는지 기록에 도전하세요.",
  "tags": [
    "GODOT 4",
    "2D",
    "ARCADE",
    "ONE BUTTON",
    "MOBILE OK"
  ],
  "coverScene": "starfall",
  "playPath": "/games/starfall-drift/index.html"
}
```

- [ ] **Step 5: 사이트 통합 검증**

```powershell
npm test
npm run build
```
Expected: vitest 전부 PASS(games.ts가 playPath 실재 검증), 빌드 성공. 이어서 `npm run dev` → 카트리지 열기 → PLAY → 게임 로드·플레이 확인. 브라우저 개발자 도구 모바일 에뮬레이션(iPhone/Galaxy 프로파일)에서 터치 탭 동작·세로 레이아웃 확인.

- [ ] **Step 6: 플레이테스트 체크리스트 작성**

`docs/superpowers/specs/starfall-drift-playtest.md`:
```markdown
# STARFALL DRIFT 플레이테스트 체크리스트

## 조작·루프
- [ ] 타이틀 첫 탭에 바로 발사 (설명 없이 이해되는가)
- [ ] 탭 반응 지연 없음 (터치/스페이스/클릭 동일)
- [ ] 사망 → 재시작 2초 이내, 게임오버 탭이 곧 재도전
- [ ] 붕괴 게이지: 크랙→흔들림→파편→경고음 순서 체감

## 밸런스 (tuning.gd로 조정)
- [ ] 첫 30초 사망률 낮음 (거성·표준성 위주 확인)
- [ ] 평균 런 길이 30초–2분 사이 (측정값: ___)
- [ ] 300m 근처에서 소행성 첫 등장 확인
- [ ] 스위프트 콤보 유지가 "빠듯하지만 가능"한가
- [ ] 도달 불가능 배치 없음 (막힌 지점 메모: ___)

## 모바일 (실기)
- [ ] Android Chrome: 로드·터치·60fps 근접 (기기: ___)
- [ ] iOS Safari: 로드·터치·오디오 재생 (기기: ___)
- [ ] 세로 화면비에서 UI 잘림 없음, 가로 회전 시에도 동작
- [ ] 탭 전환 시 PAUSED, 복귀 후 재개 정상
- [ ] 베스트 스코어가 새로고침 후 유지

## 데스크톱
- [ ] 크롬/파이어폭스: 로드·플레이 정상
- [ ] 창 리사이즈 시 세로 캔버스 유지(expand)
```

- [ ] **Step 7: Commit**

```powershell
git add games-src\starfall-drift\export_presets.cfg games-src\starfall-drift\web public\games\starfall-drift content\games\01-starfall-drift.json docs\superpowers\specs\starfall-drift-playtest.md
git commit -m "feat(starfall): web export and NEO_KIDO cartridge registration"
```

---

### Task 13: 플레이테스트·튜닝·배포

**Files:**
- Modify: `games-src/starfall-drift/src/core/tuning.gd`(튜닝 결과), `docs/superpowers/specs/starfall-drift-playtest.md`(체크 기록), `public/games/starfall-drift/*`(재익스포트)

**Interfaces:**
- Consumes: Task 12의 체크리스트
- Produces: 프로덕션 배포된 STARFALL DRIFT

- [ ] **Step 1: 플레이테스트 수행** — 체크리스트를 위에서부터 실행하며 파일에 체크 기록. 모바일 실기 항목은 사용자에게 로컬 네트워크 URL(`npm run dev` 후 `http://<PC IP>:3000`)로 요청.

- [ ] **Step 2: 튜닝 반영** — 밸런스 문제는 `tuning.gd` 상수만 수정 → gdUnit 재실행(커브 테스트가 상수 기반이라 함께 갱신 필요할 수 있음 — 스펙 §3·§6 표도 동수 갱신) → 재익스포트(Task 12 Step 3 커맨드) → 재확인.

- [ ] **Step 3: 최종 검증**

```powershell
Set-Location games-src\starfall-drift
cmd /c "addons\gdUnit4\runtest.cmd -a tests"
Set-Location ..\..
npm test
npm run build
```
Expected: 전부 PASS.

- [ ] **Step 4: 배포 (사용자 확인 후 푸시)**

```powershell
git add -A -- games-src\starfall-drift public\games\starfall-drift docs\superpowers\specs\starfall-drift-playtest.md
git commit -m "feat(starfall): playtest tuning pass"
git push origin master
```
푸시 → Vercel 자동 배포. 배포 후 https://neo-kido.vercel.app 에서 카트리지 PLAY 확인(데스크톱 + 모바일 실기).

---

## Self-Review 기록

- **스펙 커버리지**: §1–2 코어 루프·조작(Task 3·9·10), §3 엔티티 표(Task 4 Tuning + 8·10), §4 죽음 3종(Task 8 붕괴→10 `_on_star_collapsed`·낙사·소행성), §5 스코어링(Task 5), §6 커브·도달 보장(Task 4), §7 세션·UI·일시정지(Task 10 HUD·11), §8 비주얼·오디오(Task 6·7, 팔레트·뷰포트는 Task 2), §9 아키텍처(Task 1 재편·2 구조·12 익스포트/등록), §10 테스트(각 태스크 TDD + 12·13), §11 성공 기준(Task 12–13), §12 YAGNI 준수.
- **타입 일관성**: `Star.setup/gauge_ratio/occupied/alive`(Task 8 정의 ↔ 9·10 사용), `Spawner.next_star` 반환 `{"type","pos"}`(Task 4 ↔ 10), `GameState` API(Task 5 ↔ 9·10·11), `Hud.set_altitude/set_combo/show_bonus`(Task 10 정의·사용) 확인.
- **알려진 주의점**: PixelLab 응답 스키마는 Task 6 Step 1에서 실측 확인 후 스크립트 상수 조정. gdUnit4에서 `_process` 자동 구동에 의존하지 않도록 로직은 `tick(delta)` 수동 호출로 테스트.
