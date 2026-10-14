param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$Templates,
    [string]$AndroidSdk,
    [string]$JavaSdk,
    [string]$WebOnlyFrom
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$templatesPath = (Resolve-Path -LiteralPath $Templates).Path
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Utf8([string]$Path,[string]$Text) {
    [IO.Directory]::CreateDirectory((Split-Path $Path -Parent)) | Out-Null
    [IO.File]::WriteAllText($Path,$Text,$utf8)
}
# Reuse the existing runner's clean copy, probe, imports and actual Dummy guard.
if ($WebOnlyFrom) {
    $runRoot = (Resolve-Path -LiteralPath $WebOnlyFrom).Path
    if ((Split-Path $runRoot -Leaf) -notmatch '^[0-9a-f]{32}$' -or (Split-Path $runRoot -Parent) -ne (Join-Path $projectRoot 'build/verification')) { throw 'Expected owned verification fixture.' }
    $metadata = Get-Content (Join-Path $runRoot 'exports/verification.json') -Raw | ConvertFrom-Json
    if ($metadata.root -ne $runRoot -or $metadata.source_head -ne (& git -C $projectRoot rev-parse HEAD)) { throw 'Fixture ownership/source revision mismatch.' }
    $token = $metadata.token
    foreach ($name in @('export_guard','export_runtime','test_web_music')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot "tests/$name.gd") -Destination (Join-Path $runRoot "project/tests/$name.gd")
        Copy-Item -LiteralPath (Join-Path $projectRoot "tests/$name.gd.uid") -Destination (Join-Path $runRoot "project/tests/$name.gd.uid")
    }
} else {
    $preparation = & "$PSScriptRoot/test_isolated.ps1" -Godot $godotPath -Scripts @()
    $preparation | Write-Output
    $match = [regex]::Match(($preparation -join "`n"),'Isolated verification: (.+)')
    if (-not $match.Success) { throw 'Missing isolated preparation directory.' }
    $runRoot = $match.Groups[1].Value.Trim()
    $token = [guid]::NewGuid().ToString('N')
}
$fixture = Join-Path $runRoot 'project'
$artifacts = Join-Path $runRoot 'exports'
$config = [IO.File]::ReadAllText((Join-Path $fixture 'project.godot'))
$config = [regex]::Replace($config,'(?m)^(TestIsolation|ExportVerification)=.*\r?\n?','')
$config = [regex]::Replace($config,'(?ms)^\[verification\].*\z','')
$config = $config.Replace('[autoload]',"[autoload]`nTestIsolation=`"*res://tests/export_guard.gd`"")
# Verification runs only after production autoloads; the guard must remain first.
$config = $config.Replace('[display]',"ExportVerification=`"*res://tests/export_runtime.gd`"`n`n[display]")
$config += "`n[verification]`ntoken=`"$token`"`n"
# Web's Sample backend requires a browser audio device. Dummy checks use CPU streams
# only in this disposable configuration. Production is unchanged.
$config += "`n[audio]`ngeneral/default_playback_type.web=0`n"
Write-Utf8 (Join-Path $fixture 'project.godot') $config
$presets = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg')).Replace("`r`n","`n")
$presets = $presets.Replace('tools/*, tests/*, store/*, build/*, *.md','tools/*, store/*, build/*, *.md')
$presets = $presets.Replace('include_filter=""','include_filter="i18n/*.csv"')
$webTemplate = (Join-Path $templatesPath 'web_nothreads_debug.zip').Replace('\','/')
$androidTemplate = (Join-Path $templatesPath 'android_debug.apk').Replace('\','/')
$presets = $presets.Replace("[preset.0.options]`n`ncustom_template/debug=`"`"","[preset.0.options]`n`ncustom_template/debug=`"$webTemplate`"")
$presets = $presets.Replace("[preset.1.options]`n`ncustom_template/debug=`"`"","[preset.1.options]`n`ncustom_template/debug=`"$androidTemplate`"")
$presets = $presets.Replace('package/unique_name="com.electrocrem.bizarregems"','package/unique_name="com.electrocrem.bizarregems.verification"')
# APK is for manual runtime, with no automatic verification autoloads or physical launch.
# Its unique package ID, test title, debug key and profile prevent touching the installed game.
$presets = [regex]::Replace($presets,'(?m)^package/name=.*$','package/name="Bizarre Gems Verification"')
$windowsTemplate = (Join-Path $templatesPath 'windows_debug_x86_64.exe').Replace('\','/')
$presets += @"

[preset.2]
name="Verification Windows"
platform="Windows Desktop"
runnable=false
export_filter="all_resources"
include_filter="i18n/*.csv"
exclude_filter="tools/*, store/*, build/*, *.md"
export_path=""
script_export_mode=2
[preset.2.options]
custom_template/debug="$windowsTemplate"
binary_format/architecture="x86_64"
binary_format/embed_pck=false
application/modify_resources=true
application/icon="res://icon.png"
debug/export_console_wrapper=1
codesign/enable=false
"@
Write-Utf8 (Join-Path $fixture 'export_presets.cfg') $presets
function Invoke-ExportProcess([string]$Name,[string]$Executable,[string[]]$Arguments,[bool]$Runtime=$false) {
    $case = Join-Path $runRoot $Name
    $roaming = Join-Path $case 'roaming'
    $profile = Join-Path $roaming 'profile'
    if ($Runtime) { $roaming = Join-Path $runRoot 'windows-profile'; $profile = Join-Path $roaming 'profile' }
    Write-Utf8 (Join-Path $profile '.test-profile') $token
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $fixture
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $launch = @('--audio-driver','Dummy','--log-file',(Join-Path $case 'engine.log')) + $Arguments
    Write-Utf8 (Join-Path $case 'launch.json') (ConvertTo-Json -InputObject $launch)
    foreach ($argument in $launch) { $start.ArgumentList.Add($argument) }
    foreach ($key in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
        $dir = if ($key -eq 'APPDATA') { $roaming } else { Join-Path $case $key.ToLowerInvariant() }
        [IO.Directory]::CreateDirectory($dir) | Out-Null
        $start.Environment[$key] = $dir
    }
    $start.Environment['BIZARRE_TEST_TOKEN'] = $token
    $start.Environment['BIZARRE_TEST_USER_DIR'] = $profile.Replace('\','/')
    # Private editor settings, without copying credentials or changing global settings.
    if ($AndroidSdk -and $JavaSdk) {
        $sdk = (Resolve-Path -LiteralPath $AndroidSdk).Path.Replace('\','/')
        $jdk = (Resolve-Path -LiteralPath $JavaSdk).Path.Replace('\','/')
        $settings = "[gd_resource type=`"EditorSettings`" format=3]`n[resource]`nexport/android/android_sdk_path = `"$sdk`"`nexport/android/java_sdk_path = `"$jdk`"`n"
        Write-Utf8 (Join-Path $roaming 'Godot/editor_settings-4.7.tres') $settings
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Cannot launch $Name" }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(300000)) { $process.Kill($true); throw "Timed out: $Name" }
        $out = $stdout.GetAwaiter().GetResult()
        $err = $stderr.GetAwaiter().GetResult()
        Write-Utf8 (Join-Path $case 'stdout.log') $out
        Write-Utf8 (Join-Path $case 'stderr.log') $err
        if ($process.ExitCode -ne 0 -or ($out + $err) -match '(SCRIPT ERROR:|ERROR:|\bFAIL\b)') { throw "Failed $Name; inspect $case" }
        if ($Runtime -and ($out -notmatch 'ISOLATED_AUDIO_DUMMY' -or $out -notmatch 'ISOLATED_PROFILE_READY' -or $out -notmatch 'EXPORT_RUNTIME_DONE')) { throw "Missing runtime guard/completion: $Name" }
        Write-Output "PASS $Name ($case)"
    } finally { $process.Dispose() }
}
[IO.Directory]::CreateDirectory((Join-Path $artifacts 'windows')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $artifacts 'web')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $artifacts 'android')) | Out-Null
if (-not $WebOnlyFrom) {
    Invoke-ExportProcess 'windows-export' $godotPath @('--headless','--path',$fixture,'--export-debug','Verification Windows',(Join-Path $artifacts 'windows/game.exe'))
    Invoke-ExportProcess 'windows-runtime' (Join-Path $artifacts 'windows/game.exe') @('--rendering-method','gl_compatibility') $true
    Invoke-ExportProcess 'windows-restart' (Join-Path $artifacts 'windows/game.exe') @('--rendering-method','gl_compatibility','--','--verify-reload') $true
}
Invoke-ExportProcess 'web-export' $godotPath @('--headless','--path',$fixture,'--export-debug','Yandex Web',(Join-Path $artifacts 'web/index.html'))
# Insert engine args before startup. Browser harness also mutes its own process as a second barrier.
$htmlPath = Join-Path $artifacts 'web/index.html'
$html = [IO.File]::ReadAllText($htmlPath)
$needle = 'const engine = new Engine(GODOT_CONFIG);'
if (-not $html.Contains($needle)) { throw 'Unexpected Godot web shell: cannot force Dummy before startup.' }
$html = $html.Replace($needle,"GODOT_CONFIG.args = ['--audio-driver','Dummy']; window.__bizarreVerification = '$token'; " + $needle)
Write-Utf8 $htmlPath $html
# Manual artifacts preserve production audio settings and have no verification autoloads.
# They are built with Dummy but are NEVER launched automatically by this runner.
$manual = [regex]::Replace($config,'(?m)^(TestIsolation|ExportVerification)=.*\r?\n?','')
$manual = [regex]::Replace($manual,'(?ms)^\[verification\].*\z','')
$manual = $manual.Replace('config/name="Bizarre Gems"','config/name="Bizarre Gems Verification"')
Write-Utf8 (Join-Path $fixture 'project.godot') $manual
$manualPresets = [IO.File]::ReadAllText((Join-Path $fixture 'export_presets.cfg'))
$manualPresets = $manualPresets.Replace('exclude_filter="tools/*, store/*, build/*, *.md"','exclude_filter="tools/*, tests/*, store/*, build/*, *.md"')
Write-Utf8 (Join-Path $fixture 'export_presets.cfg') $manualPresets
foreach ($name in @('windows-manual','web-manual')) { [IO.Directory]::CreateDirectory((Join-Path $artifacts $name)) | Out-Null }
if (-not $WebOnlyFrom) {
    Invoke-ExportProcess 'windows-manual-export' $godotPath @('--headless','--path',$fixture,'--export-debug','Verification Windows',(Join-Path $artifacts 'windows-manual/game.exe'))
    Invoke-ExportProcess 'web-manual-export' $godotPath @('--headless','--path',$fixture,'--export-debug','Yandex Web',(Join-Path $artifacts 'web-manual/index.html'))
}
if ($AndroidSdk -and $JavaSdk -and -not $WebOnlyFrom) {
    Invoke-ExportProcess 'android-export' $godotPath @('--headless','--path',$fixture,'--export-debug','Android',(Join-Path $artifacts 'android/bizarre-gems-verification.apk'))
}
Write-Utf8 (Join-Path $artifacts 'verification.json') (ConvertTo-Json @{root=$runRoot; token=$token; audio_driver='Dummy'; source_head=(& git -C $projectRoot rev-parse HEAD)} )
Write-Output "EXPORT_CHECKS_DONE $artifacts"
