param(
    [Parameter(Mandatory=$true)][string]$Artifacts,
    [ValidateSet('Dummy','WASAPI')][string]$AudioDriver='Dummy'
)
# USER-RUN ONLY. Default is silent; selecting WASAPI explicitly starts audible manual QA.
# Do not invoke this from an automatic test or an agent.
$ErrorActionPreference='Stop'
$root = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$artifactsPath = (Resolve-Path -LiteralPath $Artifacts).Path
$parent = Split-Path $artifactsPath -Parent
if ((Split-Path $artifactsPath -Leaf) -ne 'exports' -or (Split-Path $parent -Leaf) -notmatch '^[0-9a-f]{32}$' -or (Split-Path $parent -Parent) -ne (Join-Path $root 'build/verification')) { throw 'Expected owned isolated export directory.' }
if (-not (Test-Path -LiteralPath (Join-Path $artifactsPath 'verification.json'))) { throw 'Missing export ownership manifest.' }
$profileRoot = Join-Path $parent 'manual-windows-profile'
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = Join-Path $artifactsPath 'windows-manual/game.exe'
$start.WorkingDirectory = Split-Path $start.FileName -Parent
$start.UseShellExecute = $false
foreach($name in @('APPDATA','LOCALAPPDATA','TEMP','TMP')) {
    $dir = Join-Path $profileRoot $name.ToLowerInvariant()
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    $start.Environment[$name] = $dir
}
foreach($arg in @('--audio-driver',$AudioDriver,'--log-file',(Join-Path $profileRoot 'engine.log'))) { $start.ArgumentList.Add($arg) }
Write-Output "Manual runtime: audio=$AudioDriver; isolated profile=$profileRoot"
$process = [Diagnostics.Process]::Start($start)
try { $process.WaitForExit(); if($process.ExitCode) { throw "Game exited with code $($process.ExitCode)" } } finally { $process.Dispose() }
