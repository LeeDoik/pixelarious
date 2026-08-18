# LAST LOGIN — Godot project

Godot 4.3+ Standard (GDScript). Editor binary lives outside the repo at
`C:\Users\LeeDoik\tools\godot\godot_console.exe` ($GODOT below).

## Running tests (gdUnit4, headless)

On a fresh checkout (or whenever `games-src/last-login/.godot/` is missing), prime the
script-class cache first — without this, runtest fails with
`Could not find type "GdUnitTestCIRunner"`:

    & $GODOT --headless --editor --path . --quit

Then, from the `games-src/last-login/` directory:

    $env:GODOT_BIN = $GODOT
    cmd /c "addons\gdUnit4\runtest.cmd -a tests"

Expected: 0 errors / 0 failures, exit code 0.

## 화면 확인 (개발용)

헤드리스로는 렌더가 안 되므로, 실제 창을 잠깐 띄워 뷰포트를 PNG로 저장하는 도구를 쓴다:

    & $GODOT --path . -s tools/shot.gd -- <출력경로.png> <시나리오>

시나리오: `desktop` | `explorer` | `details` | `locked` | `notepad`.
`tools/`는 웹 익스포트에서 제외된다 (`export_presets.cfg`의 `exclude_filter`).

`-s`로 실행되는 스크립트는 **오토로드가 등록되기 전에 컴파일된다.** 그 안에서
`Explorer` 같은 프로젝트 클래스를 정적 타입으로 참조하면 딸려 컴파일되면서
`Identifier not found: ContentDB`로 죽는다 — `tools/` 스크립트는 전부 동적으로 다룰 것.

## 익스포트 전 점검

    & $GODOT --headless --path . --quit-after 240          # 부트 스모크 (익스포트는 파스 에러여도 성공한다)
    & $GODOT --headless --path . --export-release "Web"
    & $GODOT --headless --main-pack ..\..\public\games\last-login\index.pck --quit-after 300

`exclude_filter`에서 `addons/gdUnit4/*`, `tools/*`, `reports/*`를 빼고 있다.
특히 `reports/*`(gdUnit 테스트 리포트)는 빼지 않으면 리포트를 쌓은 만큼
`logo.png` 사본이 pck에 딸려 들어가 빌드 크기가 실행 횟수에 따라 달라진다.
