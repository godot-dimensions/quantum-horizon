# Opens and re-saves every text scene through the Godot editor.

param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath, # Path to the Godot project.
    [switch]$Dev # Use the development editor build.
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$engineDir = Join-Path $engineRoot "godot"
$resaveScript = Join-Path $scriptRoot "resave_scenes.gd"

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Godot project not found: $ProjectPath"
}

$projectItem = Get-Item -LiteralPath $ProjectPath
if ($projectItem.PSIsContainer) {
    $projectDirectory = $projectItem.FullName
    $projectFile = Join-Path $projectDirectory "project.godot"
}
else {
    if ($projectItem.Name -ne "project.godot") {
        throw "ProjectPath must be a project directory or a project.godot file: $ProjectPath"
    }
    $projectDirectory = $projectItem.Directory.FullName
    $projectFile = $projectItem.FullName
}

if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    throw "project.godot not found: $projectFile"
}
if (-not (Test-Path -LiteralPath $resaveScript -PathType Leaf)) {
    throw "Scene re-save script not found: $resaveScript"
}

$devSuffix = if ($Dev) { ".dev" } else { "" }
$executableName = "godot.windows.editor$devSuffix.double.x86_64.console.exe"
$executablePath = Join-Path $engineDir "bin\$executableName"
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Godot editor executable not found: $executablePath`nRun run_editor_windows.bat first to build the engine."
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Quantum Horizon Scene Re-saver" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Project: $projectDirectory" -ForegroundColor Green
Write-Host "Editor:  $executablePath" -ForegroundColor Green

$godotArguments = @(
    "--headless"
    "--editor"
    "--path"
    $projectDirectory
    "--script"
    $resaveScript
)

# Windows PowerShell reports native stderr as PowerShell errors. Godot may use
# stderr for non-fatal diagnostics, so determine success from its exit code.
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $executablePath @godotArguments
    $resaveExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($resaveExitCode -ne 0) {
    throw "Godot scene re-save failed with exit code $resaveExitCode."
}

Write-Host "[OK] All project scenes were re-saved." -ForegroundColor Green
