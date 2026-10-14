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
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Scripts 'res://tests/run_combo_suite.gd','res://tests/test_bright_run.gd','res://tests/run_flow_suite.gd'
```

These adapters exercise the integrated production scene contracts. The strike-accounting
suite has its own scene adapter:

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

Stage 8 media/resources/diagnostics:

```powershell
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Assets -Python 'path/to/python.exe' -Scripts 'res://tests/test_resources.gd','res://tests/run_media_suite.gd','res://tests/run_diagnostics_suite.gd' -TimeoutSeconds 600
./tools/test_isolated.ps1 -Godot 'path/to/Godot_console.exe' -Scripts 'res://tests/test_diagnostics_cli.gd' -UserArgs '--combo-ab=A','--combo-seed=42'
```

`-Assets` checks pinned SHA256, resource references/UIDs and the real generator in another
disposable copy. It tests default/repeat no-op, missing More/Share/SFX recovery and explicit
regeneration twice; authored OGG/icons must remain identical. Python needs Pillow/numpy;
the SVG renderer is rsvg-convert or Node.js with sharp (use that process's PATH/NODE_PATH
when sharp is provided externally). Neither renderer starts an audio process. Generated
resources and reports remain under ignored build/verification; no working-tree generation.
For an import-only follow-up, `-GeneratedAssetsFrom <verification/id/generated-assets>`
reuses that runner-owned output with current code/config and checks matching producer hashes.
It avoids repeating already-passing generator cases. Generated translations and Godot caches
are excluded from clean copies; both imports and the regenerated-resource runtime check use Dummy.

`run_media_suite.gd` ports pinned decoder/mixer/player checks, including real loops across
EOF under Dummy, same-theme pause/resume/restart/menu and a single background player.
It changes preferences only in the disposable process. Audible seams, subjective levels
and Android/Web playback remain manual stage 9 checks.

`run_diagnostics_suite.gd` retains pinned A/B boundaries/results/write locks and runs real
Classic/Run strikes for Precise/Perfect/Double Hit/Color Chain and recorded score/time
receipts. The trace simulator uses BoardLogic and ScoreKeeper, including destroyed colors
and actual mode reward configuration; it is a model comparison, not a human-play estimate.
Additional CLI cases: `--combo-ab=B`, `--special-combo=legacy`, `--special-combo=timed`,
`--combo-mode=bright`, optionally `--combo-seed=<integer>`. Run each in a fresh isolated
process. Explicit Classic A/B/special experiments retain refinement's historical reward
comparison; ordinary Classic and all Run rules stay unchanged. Never use live MCP game_eval
or real profiles for automatic simulations. The write lock survives menu/mode changes until
process exit; reports are local to that disposable user:// profile and never committed.

## Isolated Windows/Web/Android exports

```powershell
./tools/test_exports.ps1 -Godot 'path/to/Godot_console.exe' -Templates "$env:APPDATA/Godot/export_templates/4.7.2.stable" -AndroidSdk "$env:LOCALAPPDATA/Android/Sdk" -JavaSdk 'path/to/JDK17'
$env:NODE_PATH='path/to/node_modules' # Playwright, with an installed Chrome executable
node tools/test_web.cjs build/verification/<id>/exports
node tests/test_web_wrapper.cjs
```

The export runner calls `test_isolated.ps1` for its clean copy/profile/import checks.
All exporter and Windows runtime processes use Dummy; exported verification autoloads
check the actual driver and profile/origin ownership. Windows checks the real exported
main scene, all 20 lessons, the full music suite, then persistent data in another process.
Android uses a private debug key/settings, `com.electrocrem.bizarregems.verification`, and
a verification title. It is built only, never installed/launched. Templates/SDK are read-only.
No release signing, production package ID or global editor settings are modified.

Web uses the existing Yandex shell, a loopback-only server/mock SDK, a fresh browser
context and `--audio-driver Dummy` engine arguments. Chrome is additionally muted.
The first Godot autoload checks actual Dummy before any Sfx autoload. The harness checks
all 20 lessons, real canvas mouse/touch events, resize, HUD after tutorial, fullscreen,
clipboard fallback through an in-memory browser fixture (OS clipboard untouched),
debug safe area and IndexedDB persistence through page reload.
Screenshots are Windows Chrome/WebGL at desktop and portrait viewports, **not Android**.
The browser process belongs to the harness and is force-closed on completion/timeout.
`test_web_wrapper.cjs` separately tests production wrapper callbacks with in-memory fixtures.
Reports, screenshots, profiles, keys and builds stay ignored under build/verification.

The non-threaded Web Dummy driver reports mix_rate=0 and cannot check browser PCM/sample
playback. Web verification uses Stream playback only in its disposable config to avoid
unsupported Sample operations. Its 26 audio checks cover OGG metadata, mapping, one player,
settings and pause/resume; CPU/live PCM and audible loops are **not** claimed for Web.
The unchanged 61-check native suite verifies decoding, EOF looping and captured PCM.
The [Godot audio documentation](https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html)
describes the separate Sample/Stream backends. Manual artifacts preserve production settings.

For a focused Web-only rebuild after a verification-script change, `-WebOnlyFrom
build/verification/<id>` reuses a runner-owned project with matching HEAD and ownership
manifest; it does not rerun already-passing Windows/Android checks.

Manual artifacts are in `windows-manual`, `web-manual`, and `android`. They have no test
autoloads and are never launched automatically. User-only Windows launcher:

```powershell
./tools/launch_manual.ps1 -Artifacts build/verification/<id>/exports # silent Dummy, private persistent profile
# USER-RUN AUDIBLE CHECK ONLY, not an automated test:
./tools/launch_manual.ps1 -Artifacts build/verification/<id>/exports -AudioDriver WASAPI
```

The latter explicitly enables physical audio. It does not change global volume/settings.
Manual Web uses `tools/serve.py <port> build/verification/<id>/exports/web-manual` and a
fresh browser profile; it can produce sound after user interaction, so an agent must not
open it automatically. Physical APK installation requires explicit user approval first.
See [manual acceptance steps](../MANUAL_QA.md); platform tests/mocks do not establish real
Android or Yandex SDK acceptance.

Godot's directory settings are documented in
[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-config-custom-user-dir-name).
The Windows engine reads APPDATA in
[OS_Windows::get_config_path](https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp).
Isolation is also checked at runtime on the installed engine rather than assumed
from documentation or an unsupported command-line flag.
