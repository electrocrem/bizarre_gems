# Safe native checks (Windows / PowerShell 7)

Run from the integration worktree, using the installed Godot 4.7.2 executable:

```powershell
./tools/test_isolated.ps1 -Godot 'G:/Software/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

The runner first proves the engine's actual `user://` path in a minimal project
without game autoloads. It then imports a fresh resource copy without Godot AI,
tests real Save/Progress persistence and disconnected native Yandex stubs, runs
`test_logic.gd` and `smoke_ui.gd`, and runs `smoke_startup.gd`: the main scene for
120 frames, a home-screen assertion, then explicit audio stop before engine exit.
Every process has its own profile, APPDATA, LOCALAPPDATA and temporary directories
under ignored `build/verification/<unique id>/`. The live editor and both real
player profiles are untouched. The first test-only autoload checks the project,
profile path and ownership marker before the game autoloads enter the tree.

The runner copies current tracked and unignored resources from this worktree,
including new tests. It excludes addons, tools, builds, Git metadata and editor
caches. Deleted files are omitted. Logs and profiles remain locally for diagnosis;
do not stage them. Native SDK calls use the game's existing stubs, so rewarded
advertising here does not validate browser SDK integration.

For an adapted regression suite:

```powershell
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Scripts 'res://tests/run_runtime_suite.gd' -UserArgs '--suite=test_bright_run'
```

That adapter and the refinement suites must first be ported to the new contracts.
The stage 1 strike-accounting suite already has a dedicated scene-based adapter:

```powershell
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Scripts 'res://tests/test_logic.gd','res://tests/run_strike_accounting.gd','res://tests/smoke_ui.gd'
```

It retains refinement's hit/removal expectations. Since stage 2 it uses the same
mode configuration as the game, including Classic's one-second tier reward.

For the complete stage 2 regression:

```powershell
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Scripts 'res://tests/test_logic.gd','res://tests/run_combo_suite.gd','res://tests/run_strike_accounting.gd','res://tests/smoke_ui.gd'
```

`run_combo_suite.gd` runs the pure special-combo, bonus-combo, balance and shared
Classic/Run rules from `refinement@bcee016`, with their original expectations.
Their runtime checks are adapted to upstream scenes in `test_combo_runtime.gd`:
real score/time receipts, destroyed colors, boxes/chains/jokers, finite Classic,
Challenge seeding, pause/transpose, transitions and deferred rewarded callbacks.
The phase 1 x2 expectation changed from +2 tier seconds to the approved +1;
legacy modes retain the default 3-second window and legacy special/reward rules.

Stage 7 practice now opts into the approved Classic/Run rules for each of the
20 pinned lessons. `run_tutorial_suite.gd` runs every lesson through production
strikes, obstacle ticks and transitions, then checks menu routes, CSV translations,
placeholder parity, language changes and every instruction/error/receipt/result
layout in RU/EN/TR across five viewport sizes. It uses the SDK fixture and the
same isolated profiles; practice may only change tutorial completion/skip flags.
Add `-Render` for actual exercise and screen captures. `-UserArgs '--menus-only'`
restricts a follow-up run to menu/localisation checks after a menu-only edit.

`-Render -ReferenceMenu -Scripts 'res://tests/test_menu_reference.gd'` compares
the scene-owned mode previews against drawing code read directly from pinned
refinement. `-ReferenceVisuals` and `-ReferenceHud` retain the prior renderer/HUD
comparisons. Reference modules and captures stay in the disposable verification
project, and no original worktree or live player profile is run.

Only the required Run combo contract is integrated in stage 2: transition clocks
freeze, a new board resets the pending Double Hit slot, eligible time-continue
keeps the same keeper, and callbacks from replaced games are rejected. The full
refinement Run/Daily generation, geometry, obstacles, transition reward schedule,
Daily date pinning and broader lifecycle regression are stage 3 work. The existing
transition economy is therefore not asserted as the final approved economy here.

Refinement's experiment-dependent startup checks, lesson-specific configuration,
HUD/layout/popup and platform input checks are outside this suite: stages 8, 7
and 6 respectively. Their original source remains pinned at `bcee016` for those
ports. The view now carries the keeper's receipt in each feedback packet; it
does not compute Double Hit or Color Chain rewards. No new HUD layout is tested.

Do not run them against the original worktree. Existing `build.sh` and
`build_android.sh` execute tests directly in their project; do not use those scripts
for integration verification until their test commands are isolated as well.

Every automatic Godot invocation must explicitly use `--audio-driver Dummy`,
including Windows/OpenGL captures, probe, editor imports, storage and startup.
The runner enforces this centrally, records each argument vector in `launch.json`,
and verifies `AudioServer.get_driver_name()` before loading game autoloads. Headless alone is
not the rule: rendered tests also need Dummy. Sound-event/music-selection tests
still run normally; only physical output is isolated. Do not change Windows volume,
real Save audio settings or production playback. Audible tests require a separate
explicitly agreed safe procedure; this runner has no physical-audio opt-out.

Nonzero exit, Godot errors, failed assertions, `FAIL` output, missing known suite
completion markers and timeouts fail the runner. Custom suites must return a
nonzero exit or report an error on failure. This launcher is Windows-only and
does not cover Web, Android hardware, visual layout, export or live advertising.
Browser testing will require a separate origin/profile and local mock SDK; Android
testing will require an isolated application ID/data directory before installation.

For the Run HUD navigation regression:

```powershell
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Render -Scripts 'res://tests/test_hud_routes.gd','res://tests/test_hud_runtime.gd','res://tests/test_hud_layout.gd' -TimeoutSeconds 600
```

`test_hud_routes.gd` compares the real scene after menu launches and tutorial
skip, exit, completion and replacement, for Bright Run, Daily and Run Challenge.
It uses identical seeded fields and viewport sizes, including narrow screens and
the Android layout fixture. It also covers restart, the mocked fullscreen-ad
callback, resize round trips, badge appearance/fade and, with `-Render`, native
window/fullscreen transitions. It checks the actual field frame and adaptive
header height without manually forcing a layout after starting a game; that
would hide a missing production relayout. Geometry comparisons tolerate normal
floating-point rounding. Rendered captures use Dummy too; browser fullscreen and
physical Android remain manual platform checks.

Godot's directory settings are documented in
[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-config-custom-user-dir-name).
The Windows engine reads APPDATA in
[OS_Windows::get_config_path](https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp).
Isolation is also checked at runtime on the installed engine rather than assumed
from documentation or an unsupported command-line flag.
