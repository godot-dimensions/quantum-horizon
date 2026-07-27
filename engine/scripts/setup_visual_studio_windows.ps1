# Generates a Visual Studio solution for the engine and adds the external 4D module files.

param(
    [switch]$Force,
    [switch]$SkipVSCodeSetup
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$scriptVersion = 6
$projectName = "QuantumHorizon"
$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$repositoryRoot = Split-Path -Parent $engineRoot
$engineDir = Join-Path $engineRoot "godot"
$modulesDir = Join-Path $engineRoot "modules"
$moduleDir = Join-Path $modulesDir "4d"
$cacheDir = Join-Path $scriptRoot ".cache"
$stateFile = Join-Path $cacheDir "visual_studio_setup.state"
$vscodeSetupScript = Join-Path $scriptRoot "setup_vscode_windows.ps1"
$vscodeStateFile = Join-Path $repositoryRoot ".vscode\quantum_horizon_vscode.state"
$compileCommandsFile = Join-Path $engineDir "compile_commands.json"
$generatedSolution = Join-Path $engineDir "$projectName.sln"
$generatedProject = Join-Path $engineDir "$projectName.vcxproj"
$generatedFilters = Join-Path $engineDir "$projectName.vcxproj.filters"
$generatedUserSettings = Join-Path $engineDir "$projectName.vcxproj.user"
$repositorySolution = Join-Path $repositoryRoot "$projectName.sln"

function Invoke-SCons {
    param([string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & scons @Arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Visual Studio project generation failed with exit code $exitCode."
    }
}

function Get-RelativeModulePath {
    param([string]$FullPath)

    $relativePath = $FullPath.Substring($moduleDir.Length).TrimStart([char[]]"\/")
    return "..\modules\4d\" + $relativePath.Replace("/", "\")
}

function Get-ModuleFilterPath {
    param([string]$FullPath)

    $relativePath = $FullPath.Substring($moduleDir.Length).TrimStart([char[]]"\/")
    $relativeDirectory = [System.IO.Path]::GetDirectoryName($relativePath)
    if ([string]::IsNullOrEmpty($relativeDirectory)) {
        return "4D Module"
    }
    return "4D Module\" + $relativeDirectory.Replace("/", "\")
}

function Get-GitFiles {
    param(
        [string]$RepoPath,
        [string[]]$Extensions
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $relativePaths = @(& git -C $RepoPath ls-files -co --exclude-standard 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0) {
        throw "Could not enumerate Git files in: $RepoPath"
    }

    $extensionPattern = '\.(' + (($Extensions | ForEach-Object { [regex]::Escape($_.TrimStart(".")) }) -join '|') + ')$'
    return @($relativePaths |
        ForEach-Object { "$_" } |
        Where-Object { $_ -match $extensionPattern } |
        ForEach-Object { Join-Path $RepoPath $_ } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { [System.IO.Path]::GetFullPath($_) } |
        Sort-Object -Unique)
}

function Get-VisualStudioSourceFiles {
    $database = Get-Content -LiteralPath $compileCommandsFile -Raw | ConvertFrom-Json
    $moduleRootWithSeparator = $moduleDir.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    $sourceFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $database) {
        $sourcePath = "$($entry.file)"
        if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
            $sourcePath = Join-Path "$($entry.directory)" $sourcePath
        }
        $sourcePath = [System.IO.Path]::GetFullPath($sourcePath)

        if ($sourcePath.StartsWith($moduleRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
            $sourceFiles.Add($sourcePath)
        }
    }

    return @($sourceFiles | Sort-Object -Unique)
}

function Get-VisualStudioHeaderFiles {
    return @(Get-GitFiles -RepoPath $moduleDir -Extensions @(".h", ".hh", ".hpp", ".hxx", ".inc") |
        Where-Object {
            $_ -notmatch '[\\/]addons[\\/]' -and
            $_ -notmatch '[\\/]__pycache__[\\/]'
        } |
        Sort-Object -Unique)
}

function Add-ExternalModuleFilesToProject {
    param(
        [string[]]$ModuleSources,
        [string[]]$ModuleHeaders
    )

    $escapedModuleDir = [System.Security.SecurityElement]::Escape($moduleDir)
    $items = [System.Collections.Generic.List[string]]::new()
    $items.Add("  <!-- Quantum Horizon external module IntelliSense settings. Builds are still delegated to SCons. -->")
    $items.Add("  <PropertyGroup>")
    $items.Add("    <NMakePreprocessorDefinitions>GODOT_MODULE;`$(NMakePreprocessorDefinitions)</NMakePreprocessorDefinitions>")
    $items.Add("    <NMakeIncludeSearchPath>$escapedModuleDir;`$(NMakeIncludeSearchPath)</NMakeIncludeSearchPath>")
    $items.Add("  </PropertyGroup>")
    $items.Add("  <ItemGroup>")
    foreach ($headerPath in $ModuleHeaders) {
        $relativePath = [System.Security.SecurityElement]::Escape((Get-RelativeModulePath -FullPath $headerPath))
        $items.Add("    <ClInclude Include=`"$relativePath`" />")
    }
    foreach ($sourcePath in $ModuleSources) {
        $relativePath = [System.Security.SecurityElement]::Escape((Get-RelativeModulePath -FullPath $sourcePath))
        $items.Add("    <ClCompile Include=`"$relativePath`" />")
    }
    $items.Add("  </ItemGroup>")

    $projectContents = [System.IO.File]::ReadAllText($generatedProject)
    if (-not $projectContents.Contains("</Project>")) {
        throw "Generated Visual Studio project has an unexpected format: $generatedProject"
    }

    $insertion = ($items -join [Environment]::NewLine) + [Environment]::NewLine
    $projectContents = $projectContents.Replace("</Project>", $insertion + "</Project>")
    [System.IO.File]::WriteAllText(
        $generatedProject,
        $projectContents,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Add-ExternalModuleFilesToFilters {
    param(
        [string[]]$ModuleSources,
        [string[]]$ModuleHeaders
    )

    $filterPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    [void]$filterPaths.Add("4D Module")

    foreach ($filePath in @($ModuleHeaders) + @($ModuleSources)) {
        $filterPath = Get-ModuleFilterPath -FullPath $filePath
        while ($filterPath.StartsWith("4D Module", [System.StringComparison]::OrdinalIgnoreCase)) {
            [void]$filterPaths.Add($filterPath)
            if ($filterPath -eq "4D Module") {
                break
            }
            $filterPath = Split-Path -Parent $filterPath
        }
    }

    $items = [System.Collections.Generic.List[string]]::new()
    $items.Add("  <!-- Quantum Horizon external module folder hierarchy. -->")
    $items.Add("  <ItemGroup>")
    foreach ($filterPath in @($filterPaths | Sort-Object)) {
        $escapedFilterPath = [System.Security.SecurityElement]::Escape($filterPath)
        $identifier = [guid]::NewGuid().ToString("B")
        $items.Add("    <Filter Include=`"$escapedFilterPath`">")
        $items.Add("      <UniqueIdentifier>$identifier</UniqueIdentifier>")
        $items.Add("    </Filter>")
    }
    $items.Add("  </ItemGroup>")

    $items.Add("  <ItemGroup>")
    foreach ($headerPath in $ModuleHeaders) {
        $relativePath = [System.Security.SecurityElement]::Escape((Get-RelativeModulePath -FullPath $headerPath))
        $filterPath = [System.Security.SecurityElement]::Escape((Get-ModuleFilterPath -FullPath $headerPath))
        $items.Add("    <ClInclude Include=`"$relativePath`">")
        $items.Add("      <Filter>$filterPath</Filter>")
        $items.Add("    </ClInclude>")
    }
    foreach ($sourcePath in $ModuleSources) {
        $relativePath = [System.Security.SecurityElement]::Escape((Get-RelativeModulePath -FullPath $sourcePath))
        $filterPath = [System.Security.SecurityElement]::Escape((Get-ModuleFilterPath -FullPath $sourcePath))
        $items.Add("    <ClCompile Include=`"$relativePath`">")
        $items.Add("      <Filter>$filterPath</Filter>")
        $items.Add("    </ClCompile>")
    }
    $items.Add("  </ItemGroup>")

    $filtersContents = [System.IO.File]::ReadAllText($generatedFilters)
    if (-not $filtersContents.Contains("</Project>")) {
        throw "Generated Visual Studio filters file has an unexpected format: $generatedFilters"
    }

    $insertion = ($items -join [Environment]::NewLine) + [Environment]::NewLine
    $filtersContents = $filtersContents.Replace("</Project>", $insertion + "</Project>")
    [System.IO.File]::WriteAllText(
        $generatedFilters,
        $filtersContents,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Disable-ShowAllFiles {
    $userSettingsContents = [System.IO.File]::ReadAllText($generatedUserSettings)
    $showAllFilesPattern = '<ShowAllFiles>[^<]*</ShowAllFiles>'
    if ($userSettingsContents -notmatch $showAllFilesPattern) {
        throw "Generated Visual Studio user settings have an unexpected format: $generatedUserSettings"
    }

    $userSettingsContents = [regex]::Replace(
        $userSettingsContents,
        $showAllFilesPattern,
        '<ShowAllFiles>false</ShowAllFiles>'
    )
    [System.IO.File]::WriteAllText(
        $generatedUserSettings,
        $userSettingsContents,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Test-FilteredSolutionExplorer {
    if (-not (Test-Path -LiteralPath $generatedUserSettings -PathType Leaf)) {
        return $false
    }
    $userSettingsContents = [System.IO.File]::ReadAllText($generatedUserSettings)
    return $userSettingsContents -match '<ShowAllFiles>false</ShowAllFiles>'
}

if ($env:OS -ne "Windows_NT") {
    throw "Visual Studio project generation is supported on Windows only."
}
if (-not (Get-Command scons -ErrorAction SilentlyContinue)) {
    throw "SCons was not found. Install SCons and make sure 'scons' is available in PATH."
}
if (-not (Test-Path -LiteralPath $vscodeSetupScript -PathType Leaf)) {
    throw "VS Code setup script not found: $vscodeSetupScript"
}
if (-not (Test-Path -LiteralPath $moduleDir -PathType Container)) {
    throw "4D module directory not found: $moduleDir"
}

# The compilation database provides the authoritative list of external module
# translation units and is shared with VS Code.
if (-not $SkipVSCodeSetup) {
    & $vscodeSetupScript
    if ($LASTEXITCODE -ne 0) {
        throw "VS Code metadata setup failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $compileCommandsFile -PathType Leaf)) {
    throw "Compilation database not found: $compileCommandsFile"
}
if (-not (Test-Path -LiteralPath $vscodeStateFile -PathType Leaf)) {
    throw "VS Code setup state not found: $vscodeStateFile"
}

$vscodeSignature = (Get-Content -LiteralPath $vscodeStateFile -Raw).Trim()
$currentSignature = "schema=$scriptVersion;vscode=$vscodeSignature"
$isCurrent = $false
if (-not $Force -and
    (Test-Path -LiteralPath $stateFile -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedSolution -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedProject -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedFilters -PathType Leaf) -and
    (Test-FilteredSolutionExplorer) -and
    (Test-Path -LiteralPath $repositorySolution -PathType Leaf)) {
    $savedSignature = (Get-Content -LiteralPath $stateFile -Raw).Trim()
    $isCurrent = $savedSignature -eq $currentSignature
}

if ($isCurrent) {
    Write-Host "[SKIP] Visual Studio is already configured." -ForegroundColor Green
    return
}

$moduleSources = Get-VisualStudioSourceFiles
$moduleHeaders = Get-VisualStudioHeaderFiles
if ($moduleSources.Count -eq 0) {
    throw "No 4D module source files were found in the compilation database."
}

Write-Host "Generating Visual Studio solution..." -ForegroundColor Cyan
$sconsArgs = @(
    "vsproj=yes"
    "vsproj_name=$projectName"
    "vsproj_gen_only=yes"
    "warnings=all"
    "werror=yes"
    "precision=double"
    "target=editor"
    "platform=windows"
    "arch=x86_64"
    "tests=yes"
    "custom_modules=../modules"
)

# Godot intentionally preserves this file when its engine-only checksum is
# unchanged. Remove it so stale external-module mappings cannot accumulate.
if (Test-Path -LiteralPath $generatedFilters -PathType Leaf) {
    Remove-Item -LiteralPath $generatedFilters -Force
}

Push-Location $engineDir
try {
    Invoke-SCons -Arguments $sconsArgs
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $generatedSolution -PathType Leaf)) {
    throw "Visual Studio solution was not generated: $generatedSolution"
}
if (-not (Test-Path -LiteralPath $generatedProject -PathType Leaf)) {
    throw "Visual Studio project was not generated: $generatedProject"
}
if (-not (Test-Path -LiteralPath $generatedFilters -PathType Leaf)) {
    throw "Visual Studio filters file was not generated: $generatedFilters"
}
if (-not (Test-Path -LiteralPath $generatedUserSettings -PathType Leaf)) {
    throw "Visual Studio user settings were not generated: $generatedUserSettings"
}

Add-ExternalModuleFilesToProject -ModuleSources $moduleSources -ModuleHeaders $moduleHeaders
Add-ExternalModuleFilesToFilters -ModuleSources $moduleSources -ModuleHeaders $moduleHeaders
Disable-ShowAllFiles

$solutionContents = [System.IO.File]::ReadAllText($generatedSolution)
$solutionContents = $solutionContents.Replace(
    "`"$projectName.vcxproj`"",
    "`"engine\godot\$projectName.vcxproj`""
)
[System.IO.File]::WriteAllText(
    $repositorySolution,
    $solutionContents,
    (New-Object System.Text.UTF8Encoding($false))
)

New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
[System.IO.File]::WriteAllText(
    $stateFile,
    $currentSignature + [Environment]::NewLine,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host "[OK] Visual Studio is configured for the engine and 4D module." -ForegroundColor Green
Write-Host "Solution: $repositorySolution"
