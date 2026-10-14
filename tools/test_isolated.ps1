param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string[]]$Scripts = @('res://tests/test_logic.gd', 'res://tests/smoke_ui.gd'),
    [string[]]$UserArgs = @(),
    [switch]$Render,
    [switch]$ReferenceVisuals,
    [ValidateSet('none', 'cosmetics-enabled', 'double-reward')][string]$Mutation = 'none',
    [ValidateRange(1, 1800)][int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:OS -ne 'Windows_NT') { throw 'This runner supports native Windows Godot only.' }
$projectRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$utf8 = [Text.UTF8Encoding]::new($false)
$verificationRoot = Join-Path $projectRoot 'build/verification'
[IO.Directory]::CreateDirectory($verificationRoot) | Out-Null
# Prevent the live editor from importing disposable projects and duplicate class names.
[IO.File]::WriteAllText((Join-Path $verificationRoot '.gdignore'), '', $utf8)
$runRoot = Join-Path $verificationRoot ([guid]::NewGuid().ToString('N'))
$fixture = Join-Path $runRoot 'project'
[IO.Directory]::CreateDirectory($fixture) | Out-Null
Write-Output "Isolated verification: $runRoot"

function Write-Utf8([string]$Path, [string]$Content) {
    [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Invoke-IsolatedGodot([string]$Name, [string[]]$Arguments, [string]$Completion = '', [bool]$Rendered = $false) {
    $caseRoot = Join-Path $runRoot $Name
    $roaming = Join-Path $caseRoot 'roaming'
    $userDir = Join-Path $roaming 'profile'
    $token = [guid]::NewGuid().ToString('N')
    Write-Utf8 (Join-Path $userDir '.test-profile') $token
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $fixture
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    # Only explicitly requested suites render; probe/import/storage/startup stay headless.
    [string[]]$driverArgs = if ($Rendered) { @('--rendering-method', 'gl_compatibility') } else { @('--headless') }
    foreach ($arg in $driverArgs + @('--path', $fixture, '--log-file', (Join-Path $caseRoot 'engine.log')) + $Arguments) {
        $start.ArgumentList.Add($arg)
    }
    foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP')) {
        $dir = if ($key -eq 'APPDATA') { $roaming } else { Join-Path $caseRoot $key.ToLowerInvariant() }
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $start.Environment[$key] = $dir
    }
    $start.Environment['BIZARRE_TEST_PROJECT'] = $fixture.Replace('\', '/')
    $start.Environment['BIZARRE_TEST_USER_DIR'] = $userDir.Replace('\', '/')
    $start.Environment['BIZARRE_TEST_TOKEN'] = $token
    $start.Environment['RUNTIME_TEST_OUTPUT'] = Join-Path $caseRoot 'runtime.json'
    $start.Environment['VISUAL_CAPTURE_DIR'] = $caseRoot
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Cannot launch Godot: $Name" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Write-Utf8 (Join-Path $caseRoot 'stdout.log') $stdout
        Write-Utf8 (Join-Path $caseRoot 'stderr.log') $stderr
        $log = $stdout + "`n" + $stderr
        if ($timedOut) { throw "Godot timed out: $Name (logs: $caseRoot)" }
        if ($process.ExitCode -ne 0 -or $log -match '(?m)(SCRIPT ERROR:|ERROR:|\bFAIL\b|Assertion failed)') {
            $log -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR:|ERROR:|\bFAIL\b|Assertion failed' } | Select-Object -First 20 | Write-Output
            throw "Godot verification failed: $Name, exit $($process.ExitCode) (logs: $caseRoot)"
        }
        if ($Completion -and -not $log.Contains($Completion)) { throw "Missing completion marker: $Name (logs: $caseRoot)" }
        if ($Name -notin @('probe', 'resources-import', 'project-import') -and -not $log.Contains('ISOLATED_PROFILE_READY')) {
            throw "Missing isolation guard: $Name (logs: $caseRoot)"
        }
        Write-Output "PASS $Name (logs: $caseRoot)"
    } finally {
        $process.Dispose()
    }
}

# Probe actual OS.get_user_data_dir() before importing or starting any game code.
# APPDATA is read by OS_Windows::get_config_path(); no invented CLI path override.
$minimal = @'
config_version=5
[application]
config/name="Bizarre Gems Verification"
config/use_custom_user_dir=true
config/custom_user_dir_name="profile"
[rendering]
renderer/rendering_method="gl_compatibility"
'@
Write-Utf8 (Join-Path $fixture 'project.godot') $minimal
[IO.Directory]::CreateDirectory((Join-Path $fixture 'tests')) | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'tests/test_profile_isolation.gd') -Destination (Join-Path $fixture 'tests')
Invoke-IsolatedGodot 'probe' @('--script', 'res://tests/test_profile_isolation.gd', '--', '--profile-probe') 'PROFILE_PROBE_DONE'

# Copy current tracked/unignored resources, including new tests, without Git metadata,
# editor caches, addons, credentials, builds, tools or source-worktree modifications.
$paths = & git -C $projectRoot -c core.quotepath=false ls-files --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate project files.' }
foreach ($relative in $paths | Sort-Object -Unique) {
    if ($relative -notmatch '^(assets/|i18n/|scenes/|scripts/|ui/|tests/|icon\.png(\.import)?$|default_bus_layout\.tres$)') { continue }
    $source = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    if ((Get-Item -LiteralPath $source).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked resource refused: $relative" }
    $target = Join-Path $fixture $relative
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')).Replace("`r`n", "`n")
if ($ReferenceVisuals) {
    # Read pinned renderers directly from Git; never run or modify the source worktree.
    foreach ($name in @('board_view', 'ambient', 'special_gem_art')) {
        $referenceText = (& git -C $projectRoot show "bcee01634740130b6f2bf8f1193adc49e3f68e1f:scripts/$name.gd") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Missing pinned visual source: $name" }
        $referenceText = [regex]::Replace($referenceText, '(?m)^class_name .*\n?', '')
        $referenceText = $referenceText.Replace('res://scripts/special_gem_art.gd', 'res://tests/reference_visuals/special_gem_art.gd')
        Write-Utf8 (Join-Path $fixture "tests/reference_visuals/$name.gd") ($referenceText + "`n")
    }
}
if ($Mutation -ne 'none') {
    # Deliberate negative checks change ONLY the disposable project, never the worktree.
    $mutationCase = switch ($Mutation) {
        'cosmetics-enabled' { @('scripts/progress.gd', 'const COSMETICS_ENABLED := false', 'const COSMETICS_ENABLED := true') }
        'double-reward' { @('scripts/main.gd', 'Progress.add_crystals(earned)', 'Progress.add_crystals(earned * 2)') }
    }
    $mutationPath = Join-Path $fixture $mutationCase[0]
    $mutationText = [IO.File]::ReadAllText($mutationPath)
    if ([regex]::Matches($mutationText, [regex]::Escape($mutationCase[1])).Count -ne 1) {
        throw "Mutation target is not unique: $Mutation"
    }
    Write-Utf8 $mutationPath ($mutationText.Replace($mutationCase[1], $mutationCase[2]))
    Write-Output "Controlled mutation in disposable copy: $Mutation (a failing suite is expected)"
}
# Strip local editor/runtime integration ONLY in the disposable copy.
$config = [regex]::Replace($config, '(?m)^_mcp_game_helper=.*\n?', '')
$config = [regex]::Replace($config, '(?ms)^\[editor_plugins\]\n.*?(?=^\[|\z)', '')
$config = [regex]::Replace($config, '(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\n?', '')
$config = $config.Replace("[application]`n", "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"profile`"`n")
$config = $config.Replace("[autoload]`n", "[autoload]`nTestIsolation=`"*res://tests/isolation_guard.gd`"`n")
if ($config -match 'godot_ai|\[editor_plugins\]' -or -not $config.Contains('TestIsolation=')) { throw 'Cannot sanitize disposable project configuration.' }
# A clean project has no generated translations/fonts/textures yet. Import them
# before enabling startup settings that immediately load the theme/translations.
# Check BOTH import passes for errors; never accept or filter bootstrap errors.
$importConfig = [regex]::Replace($config, '(?m)^(theme/custom|locale/translations)=.*\n?', '')
Write-Utf8 (Join-Path $fixture 'project.godot') $importConfig
Invoke-IsolatedGodot 'resources-import' @('--editor', '--import')
Write-Utf8 (Join-Path $fixture 'project.godot') $config
Invoke-IsolatedGodot 'project-import' @('--editor', '--import')
Invoke-IsolatedGodot 'storage' @('--script', 'res://tests/test_profile_isolation.gd') 'PROFILE_ISOLATION_DONE'
$index = 0
foreach ($script in $Scripts) {
    if ($script -notmatch '^res://tests/[a-zA-Z0-9_/]+\.gd$' -or $script.Contains('..')) { throw "Expected a res://tests/*.gd script: $script" }
    if (-not (Test-Path -LiteralPath (Join-Path $fixture $script.Substring(6)) -PathType Leaf)) { throw "Missing test script: $script" }
    $completion = switch ($script) {
        'res://tests/test_logic.gd' { 'all passed' }
        'res://tests/smoke_ui.gd' { 'smoke test done' }
        'res://tests/run_runtime_suite.gd' { 'RUNTIME_SUITE ' }
        'res://tests/run_strike_accounting.gd' { 'STRIKE_ACCOUNTING_DONE' }
        'res://tests/run_combo_suite.gd' { 'COMBO_SUITE_DONE' }
        'res://tests/test_bright_run.gd' { 'BRIGHT_RUN ' }
        'res://tests/run_flow_suite.gd' { 'RUN_FLOW_DONE' }
        'res://tests/run_progress_suite.gd' { 'PROGRESS_SUITE_DONE' }
        'res://tests/run_visual_suite.gd' { 'VISUAL_SUITE_DONE' }
        'res://tests/test_visual_reference.gd' { 'VISUAL_REFERENCE_DONE' }
        default { '' }
    }
    $argsForTest = @('--script', $script)
    if ($UserArgs.Count) { $argsForTest += @('--') + $UserArgs }
    Invoke-IsolatedGodot ("suite-$index") $argsForTest $completion $Render.IsPresent
    $index++
}
Invoke-IsolatedGodot 'startup' @('--script', 'res://tests/smoke_startup.gd') 'STARTUP_SMOKE_DONE'
Write-Output "All isolated checks passed. Profiles and logs retained: $runRoot"
