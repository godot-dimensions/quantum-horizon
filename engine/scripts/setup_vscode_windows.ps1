# Generates repository-root VS Code IntelliSense configuration for the engine and custom modules.

param(
    [switch]$Force
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$scriptVersion = 2
$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$repositoryRoot = Split-Path -Parent $engineRoot
$engineDir = Join-Path $engineRoot "godot"
$modulesDir = Join-Path $engineRoot "modules"
$vscodeDir = Join-Path $repositoryRoot ".vscode"
$compileCommandsFile = Join-Path $engineDir "compile_commands.json"
$cppPropertiesFile = Join-Path $vscodeDir "c_cpp_properties.json"
$settingsFile = Join-Path $vscodeDir "settings.json"
$extensionsFile = Join-Path $vscodeDir "extensions.json"
$stateFile = Join-Path $vscodeDir "quantum_horizon_vscode.state"
$workspaceCompileCommands = '${workspaceFolder}/engine/godot/compile_commands.json'

function Invoke-GitText {
    param(
        [string]$RepoPath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& git -C $RepoPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Git command failed in '$RepoPath': git $($Arguments -join ' ')`n$($output -join "`n")"
    }

    return @($output | ForEach-Object { "$_" })
}

function Get-DirectoryContentChecksum {
    param([string]$DirectoryPath)

    $resolvedDirectoryPath = (Resolve-Path -LiteralPath $DirectoryPath).Path.TrimEnd('\', '/')
    $checksumInput = [System.Text.StringBuilder]::new()

    Get-ChildItem -LiteralPath $resolvedDirectoryPath -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($resolvedDirectoryPath.Length).TrimStart('\', '/')
            $fileChecksum = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            [void]$checksumInput.Append($relativePath).Append("`0").Append($fileChecksum).Append("`n")
        }

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($checksumInput.ToString())
        return [System.BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace("-", "")
    }
    finally {
        $hasher.Dispose()
    }
}

function Get-SourceLayoutSignature {
    param([string[]]$RepositoryPaths)

    $signatureLines = [System.Collections.Generic.List[string]]::new()
    $signatureLines.Add("schema=$scriptVersion")
    $signatureLines.Add("platform=windows")
    $signatureLines.Add("target=editor")
    $signatureLines.Add("arch=x86_64")
    $signatureLines.Add("precision=double")
    $signatureLines.Add("custom_modules=../modules")

    foreach ($repositoryPath in $RepositoryPaths) {
        $resolvedPath = (Resolve-Path -LiteralPath $repositoryPath).Path
        $signatureLines.Add("repository=$resolvedPath")

        if (-not (Test-Path -LiteralPath (Join-Path $resolvedPath ".git"))) {
            $signatureLines.Add("content-checksum=$(Get-DirectoryContentChecksum -DirectoryPath $resolvedPath)")
            continue
        }

        $commit = Invoke-GitText -RepoPath $resolvedPath -Arguments @("rev-parse", "HEAD")
        $signatureLines.Add("commit=$($commit -join '')")

        $statusLines = Invoke-GitText -RepoPath $resolvedPath -Arguments @(
            "status", "--porcelain=v1", "--untracked-files=all"
        )
        foreach ($statusLine in $statusLines) {
            if ($statusLine -match '\.(c|cc|cpp|cxx|m|mm|h|hh|hpp|hxx|inc)$' -or
                $statusLine -match '(^|[\\/])(SConstruct|SCsub|config\.py)$') {
                $signatureLines.Add("status=$statusLine")
            }
        }

        $files = Invoke-GitText -RepoPath $resolvedPath -Arguments @(
            "ls-files", "-co", "--exclude-standard"
        )
        foreach ($relativePath in @($files | Sort-Object -Unique)) {
            $normalizedPath = $relativePath.Replace("\", "/")
            if ($normalizedPath -match '\.(c|cc|cpp|cxx|m|mm)$') {
                $signatureLines.Add("source=$normalizedPath")
            }
            if ($normalizedPath -match '\.(h|hh|hpp|hxx|inc)$') {
                $signatureLines.Add("header=$normalizedPath")
            }

            if ($normalizedPath -match '(^|/)(SConstruct|SCsub|config\.py)$') {
                $fullPath = Join-Path $resolvedPath $relativePath
                if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
                    $fileHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
                    $signatureLines.Add("build-file=$normalizedPath`:$fileHash")
                }
            }
        }
    }

    $signatureText = $signatureLines -join "`n"
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($signatureText)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Read-JsonMap {
    param([string]$Path)

    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $result
    }

    try {
        $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Could not parse '$Path'. The generated VS Code files must contain valid JSON.`n$($_.Exception.Message)"
    }

    foreach ($property in $value.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }
    return $result
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 100
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8WithoutBom)
}

function Test-CompilationDatabaseIncludesModules {
    if (-not (Test-Path -LiteralPath $compileCommandsFile -PathType Leaf)) {
        return $false
    }

    $contents = Get-Content -LiteralPath $compileCommandsFile -Raw
    $normalizedContents = $contents.Replace("\\", "/").Replace("\", "/")
    return $normalizedContents -match 'modules/4d/'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found. Install Git and make sure 'git' is available in PATH."
}
if (-not (Get-Command scons -ErrorAction SilentlyContinue)) {
    throw "SCons was not found. Install SCons and make sure 'scons' is available in PATH."
}
if (-not (Test-Path -LiteralPath $engineDir -PathType Container)) {
    throw "Engine directory not found: $engineDir"
}
if (-not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
    throw "Modules directory not found: $modulesDir"
}

$repositoryPaths = @($engineDir)
$repositoryPaths += @(Get-ChildItem -LiteralPath $modulesDir -Directory | Sort-Object Name | Select-Object -ExpandProperty FullName)
$currentSignature = Get-SourceLayoutSignature -RepositoryPaths $repositoryPaths

$isCurrent = $false
if (-not $Force -and
    (Test-Path -LiteralPath $stateFile -PathType Leaf) -and
    (Test-Path -LiteralPath $cppPropertiesFile -PathType Leaf) -and
    (Test-Path -LiteralPath $settingsFile -PathType Leaf) -and
    (Test-Path -LiteralPath $extensionsFile -PathType Leaf) -and
    (Test-CompilationDatabaseIncludesModules)) {
    $savedSignature = (Get-Content -LiteralPath $stateFile -Raw).Trim()
    $isCurrent = $savedSignature -eq $currentSignature
}

if ($isCurrent) {
    Write-Host "[SKIP] VS Code IntelliSense is already configured." -ForegroundColor Green
    return
}

Write-Host "Generating VS Code IntelliSense metadata..." -ForegroundColor Cyan
$sconsArgs = @(
    "compiledb=yes"
    "warnings=all"
    "werror=yes"
    "precision=double"
    "target=editor"
    "platform=windows"
    "arch=x86_64"
    "tests=yes"
    "custom_modules=../modules"
    "compile_commands.json"
)

Push-Location $engineDir
try {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & scons @sconsArgs
        $sconsExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($sconsExitCode -ne 0) {
        throw "VS Code compilation database generation failed with exit code $sconsExitCode."
    }
}
finally {
    Pop-Location
}

if (-not (Test-CompilationDatabaseIncludesModules)) {
    throw "The generated compilation database does not contain the 4D module: $compileCommandsFile"
}

New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null

$cppProperties = [ordered]@{
    configurations = @(
        [ordered]@{
            name = "Quantum Horizon"
            compileCommands = $workspaceCompileCommands
        }
    )
    version = 4
}
Write-JsonFile -Path $cppPropertiesFile -Value $cppProperties

$settings = Read-JsonMap -Path $settingsFile
$settings["C_Cpp.default.compileCommands"] = $workspaceCompileCommands
$clangdArguments = @()
if ($settings.Contains("clangd.arguments")) {
    $clangdArguments = @($settings["clangd.arguments"] | Where-Object {
        "$_" -notmatch '^--compile-commands-dir='
    })
}
$clangdArguments += '--compile-commands-dir=${workspaceFolder}/engine/godot'
$settings["clangd.arguments"] = $clangdArguments
Write-JsonFile -Path $settingsFile -Value $settings

$extensions = Read-JsonMap -Path $extensionsFile
$recommendations = @()
if ($extensions.Contains("recommendations")) {
    $recommendations = @($extensions["recommendations"])
}
$recommendations += "ms-vscode.cpptools"
$extensions["recommendations"] = @($recommendations | Sort-Object -Unique)
Write-JsonFile -Path $extensionsFile -Value $extensions

[System.IO.File]::WriteAllText(
    $stateFile,
    $currentSignature + [Environment]::NewLine,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host "[OK] VS Code IntelliSense is configured for the engine and 4D module." -ForegroundColor Green
Write-Host "Compilation database: $compileCommandsFile"
