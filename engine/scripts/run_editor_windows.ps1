# Updates the engine dependencies, builds Godot, and opens the editor.

param(
    [string]$ProjectPath, # Path to the Godot project (optional).
    [switch]$Dev, # Pass -Dev to build script (development build).
    [switch]$DoNotUpdate # Skip the update script.
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$updateScript = Join-Path $scriptRoot "update_submodules_windows.ps1"
$vscodeSetupScript = Join-Path $scriptRoot "setup_vscode_windows.ps1"
$visualStudioSetupScript = Join-Path $scriptRoot "setup_visual_studio_windows.ps1"
$buildScript = Join-Path $scriptRoot "build_engine_windows.ps1"

if (-not (Test-Path -LiteralPath $updateScript -PathType Leaf)) {
    throw "Update script not found: $updateScript"
}
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Build script not found: $buildScript"
}
if (-not (Test-Path -LiteralPath $vscodeSetupScript -PathType Leaf)) {
    throw "VS Code setup script not found: $vscodeSetupScript"
}
if (-not (Test-Path -LiteralPath $visualStudioSetupScript -PathType Leaf)) {
    throw "Visual Studio setup script not found: $visualStudioSetupScript"
}

$resolvedProjectDirectory = $null
if ($ProjectPath) {
    if (-not (Test-Path -LiteralPath $ProjectPath)) {
        throw "Godot project not found: $ProjectPath"
    }

    $projectItem = Get-Item -LiteralPath $ProjectPath
    if ($projectItem.PSIsContainer) {
        $projectFile = Join-Path $projectItem.FullName "project.godot"
        $resolvedProjectDirectory = $projectItem.FullName
    }
    else {
        if ($projectItem.Name -ne "project.godot") {
            throw "ProjectPath must be a project directory or a project.godot file: $ProjectPath"
        }
        $projectFile = $projectItem.FullName
        $resolvedProjectDirectory = $projectItem.Directory.FullName
    }

    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
        throw "project.godot not found: $projectFile"
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Quantum Horizon Editor Launcher" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

if (-not $DoNotUpdate) {
    Write-Host "`nStep 1 of 4: Checking for engine updates..." -ForegroundColor Yellow
    & $updateScript
    if ($LASTEXITCODE -ne 0) {
        throw "Engine update failed with exit code $LASTEXITCODE."
    }
}
else {
    Write-Host "`nStep 1 of 4: Update skipped." -ForegroundColor Yellow
}

Write-Host "`nStep 2 of 4: Setting up developer tools..." -ForegroundColor Yellow
& $vscodeSetupScript
if ($LASTEXITCODE -ne 0) {
    throw "VS Code setup failed with exit code $LASTEXITCODE."
}
& $visualStudioSetupScript -SkipVSCodeSetup
if ($LASTEXITCODE -ne 0) {
    throw "Visual Studio setup failed with exit code $LASTEXITCODE."
}

Write-Host "`nStep 3 of 4: Making sure the engine is built..." -ForegroundColor Yellow
$buildArgs = @{ DoNotRun = $true }
if ($Dev) {
    $buildArgs.Dev = $true
}
& $buildScript @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "Engine build failed with exit code $LASTEXITCODE."
}

Write-Host "`nStep 4 of 4: Opening the editor..." -ForegroundColor Yellow
$devSuffix = if ($Dev) { ".dev" } else { "" }
$executablePath = Join-Path $engineRoot "godot\bin\godot.windows.editor$devSuffix.double.x86_64.exe"
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Godot executable not found: $executablePath"
}

Write-Host "Running: $executablePath" -ForegroundColor Cyan
if ($resolvedProjectDirectory) {
    Write-Host "Project: $resolvedProjectDirectory" -ForegroundColor Green
    & $executablePath --path $resolvedProjectDirectory --editor
}
else {
    Write-Host "Opening the project manager." -ForegroundColor Green
    & $executablePath --project-manager
}

if ($LASTEXITCODE -ne 0) {
    throw "Godot exited with code $LASTEXITCODE."
}
