# Forward engine and game arguments verbatim, including Godot's -- separator.
$GodotArguments = @($args)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @()
if ($env:GODOT_EXE) { $candidates += $env:GODOT_EXE }
$localConfig = Join-Path $projectRoot 'godot.local.txt'
if (Test-Path -LiteralPath $localConfig) {
    $candidates += (Get-Content -LiteralPath $localConfig -TotalCount 1).Trim().Trim('"')
}
foreach ($name in @('godot.exe', 'godot4.exe', 'Godot_v4.6-stable_win64.exe')) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
}
foreach ($folder in @((Join-Path $projectRoot 'tools\godot'), "$env:LOCALAPPDATA\Programs\Godot", 'C:\Program Files\Godot', 'D:\Steam\steamapps\common\Godot Engine')) {
    if (Test-Path -LiteralPath $folder) {
        $candidates += Get-ChildItem -LiteralPath $folder -Filter '*godot*.exe' -File |
            Sort-Object { $_.Name -notmatch 'console' }, Name | Select-Object -ExpandProperty FullName
    }
}
$engine = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $engine) {
    Write-Host 'Godot was not found. Put the full path to your Godot .exe in godot.local.txt in the project root, or set GODOT_EXE.'
    exit 1
}
$project = Join-Path $projectRoot 'game'
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
    Write-Host 'Missing game/project.godot.'
    exit 1
}
Write-Host "Starting Voxeloid with $engine"
& $engine --path $project @GodotArguments
exit $LASTEXITCODE
