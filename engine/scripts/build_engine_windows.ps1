# Godot Engine build script with custom modules.
# Compiles engine/godot with the modules in engine/modules.

param(
    [string]$Target = "editor",
    [string]$Platform = "windows",
    [string]$Architecture = "x86_64",
    [int]$Jobs = [Environment]::ProcessorCount,
    [switch]$Dev, # Development build.
    [switch]$Clean, # Clean before building.
    [switch]$DoNotRun # If not specified, run the built executable after building.
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$engineDir = Join-Path $engineRoot "godot"
$modulesDir = Join-Path $engineRoot "modules"
$cacheDir = Join-Path $scriptRoot ".cache"
$buildCacheFile = Join-Path $cacheDir "build_cache.json"

function Get-RepositoryBuildState {
    param([string[]]$RepositoryPaths)

    $state = @()

    foreach ($repositoryPath in $RepositoryPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath ".git"))) {
            throw "Git repository not found: $repositoryPath"
        }

        $commit = & git -C $repositoryPath rev-parse HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the Git revision for: $repositoryPath`n$commit"
        }

        $workingTreeChanges = @(& git -C $repositoryPath status --porcelain=v1 --untracked-files=all 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the Git status for: $repositoryPath`n$($workingTreeChanges -join "`n")"
        }

        # A dirty tree is intentionally never cacheable. A status marker alone
        # cannot detect a second edit to a file that was already modified.
        if ($workingTreeChanges.Count -gt 0) {
            return $null
        }

        $state += [ordered]@{
            path = (Resolve-Path -LiteralPath $repositoryPath).Path
            commit = "$commit".Trim()
        }
    }

    return @($state)
}

if ($Jobs -lt 1) {
    throw "Jobs must be at least 1."
}
if (-not (Test-Path -LiteralPath $engineDir)) {
    throw "Engine directory not found: $engineDir"
}
if (-not (Test-Path -LiteralPath $modulesDir)) {
    throw "Modules directory not found: $modulesDir"
}
if (-not (Get-Command scons -ErrorAction SilentlyContinue)) {
    throw "SCons was not found. Install SCons and make sure 'scons' is available in PATH."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found. Install Git and make sure 'git' is available in PATH."
}

$devSuffix = if ($Dev) { ".dev" } else { "" }
$executableFilename = "godot.$Platform.$Target$devSuffix.double.$Architecture.exe"
$executablePath = Join-Path $engineDir "bin\$executableFilename"

$sconsArgs = @(
    "compiledb=yes"
    "warnings=all"
    "werror=yes"
    "precision=double"
    "d3d12=no"
    "target=$Target"
    "platform=$Platform"
)
if ($Target -eq "editor") {
    $sconsArgs += "tests=yes"
}
$sconsArgs += "-j$Jobs"
$sconsArgs += "custom_modules=../modules"
if ($Dev) {
    $sconsArgs += @(
        "debug_symbols=yes"
        "dev_build=yes"
        "dev_mode=yes"
    )
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Godot Engine Build" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Engine:       $engineDir" -ForegroundColor Green
Write-Host "Modules:      $modulesDir" -ForegroundColor Green
Write-Host "Target:       $Target" -ForegroundColor Green
Write-Host "Platform:     $Platform" -ForegroundColor Green
Write-Host "Architecture: $Architecture" -ForegroundColor Green
Write-Host "Jobs:         $Jobs" -ForegroundColor Green

$repositoryPaths = @($engineDir)
$repositoryPaths += @(Get-ChildItem -LiteralPath $modulesDir -Directory | Sort-Object Name | Select-Object -ExpandProperty FullName)
$repositoryState = Get-RepositoryBuildState -RepositoryPaths $repositoryPaths

$buildInputs = [ordered]@{
    arguments = @($sconsArgs | Sort-Object)
    repositories = $repositoryState
}
$currentBuildKey = $buildInputs | ConvertTo-Json -Depth 8 -Compress
$shouldSkipBuild = $false

if (-not $Clean -and $null -ne $repositoryState -and (Test-Path -LiteralPath $buildCacheFile)) {
    try {
        $buildCache = Get-Content -LiteralPath $buildCacheFile -Raw | ConvertFrom-Json
        if (($buildCache.lastBuildKey -eq $currentBuildKey) -and (Test-Path -LiteralPath $executablePath)) {
            $shouldSkipBuild = $true
        }
    }
    catch {
        Write-Warning "The build cache could not be read. A normal build will run."
    }
}

Push-Location $engineDir
try {
    if ($Clean) {
        Write-Host "`nCleaning this build configuration..." -ForegroundColor Yellow
        & scons @sconsArgs --clean
        if ($LASTEXITCODE -ne 0) {
            throw "Clean failed with exit code $LASTEXITCODE."
        }
    }

    if ($shouldSkipBuild) {
        Write-Host "`n[SKIP] Sources and build options have not changed." -ForegroundColor Yellow
        Write-Host "Using: $executablePath" -ForegroundColor Green
    }
    else {
        if ($null -eq $repositoryState) {
            Write-Host "`nUncommitted source changes detected; the build cache will not be used." -ForegroundColor Yellow
        }

        Write-Host "`nStarting build..." -ForegroundColor Cyan
        Write-Host "Command: scons $($sconsArgs -join ' ')" -ForegroundColor DarkGray
        & scons @sconsArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Engine build failed with exit code $LASTEXITCODE."
        }

        if (-not (Test-Path -LiteralPath $executablePath)) {
            throw "The build finished, but the expected executable was not found: $executablePath"
        }

        # Only clean repository states are safe to reuse later.
        if ($null -ne $repositoryState) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            [ordered]@{
                lastBuildKey = $currentBuildKey
                lastBuildTime = (Get-Date).ToString("o")
            } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $buildCacheFile -Encoding UTF8
        }
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $executablePath)) {
    throw "Godot executable not found: $executablePath"
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "Engine is ready." -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green

if (-not $DoNotRun) {
    Write-Host "Running: $executablePath" -ForegroundColor Cyan
    & $executablePath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot exited with code $LASTEXITCODE."
    }
}
