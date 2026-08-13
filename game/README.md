# LAST LOGIN — Godot project

Godot 4.3+ Standard (GDScript). Editor binary lives outside the repo at
`C:\Users\LeeDoik\tools\godot\godot_console.exe` ($GODOT below).

## Running tests (gdUnit4, headless)

On a fresh checkout (or whenever `game/.godot/` is missing), prime the
script-class cache first — without this, runtest fails with
`Could not find type "GdUnitTestCIRunner"`:

    & $GODOT --headless --editor --path game --quit

Then, from the `game/` directory:

    $env:GODOT_BIN = $GODOT
    cmd /c "addons\gdUnit4\runtest.cmd -a tests"

Expected: 0 errors / 0 failures, exit code 0.
