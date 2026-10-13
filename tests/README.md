# Safe native checks (Windows / PowerShell 7)

Run from the integration worktree, using the installed Godot 4.7.2 executable:

```powershell
./tools/test_isolated.ps1 -Godot 'G:/Software/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
```

The runner first proves the engine's actual `user://` path in a minimal project
without game autoloads. It then imports a fresh resource copy without Godot AI,
tests real Save/Progress persistence and disconnected native Yandex stubs, runs
`test_logic.gd` and `smoke_ui.gd`, and starts the main scene for 120 frames.
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
Do not run them against the original worktree. Existing `build.sh` and
`build_android.sh` execute tests directly in their project; do not use those scripts
for integration verification until their test commands are isolated as well.

Nonzero exit, Godot errors, failed assertions, `FAIL` output, missing known suite
completion markers and timeouts fail the runner. Custom suites must return a
nonzero exit or report an error on failure. This launcher is Windows-only and
does not cover Web, Android hardware, visual layout, export or live advertising.
Browser testing will require a separate origin/profile and local mock SDK; Android
testing will require an isolated application ID/data directory before installation.

Godot's directory settings are documented in
[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-config-custom-user-dir-name).
The Windows engine reads APPDATA in
[OS_Windows::get_config_path](https://github.com/godotengine/godot/blob/master/platform/windows/os_windows.cpp).
Isolation is also checked at runtime on the installed engine rather than assumed
from documentation or an unsupported command-line flag.
