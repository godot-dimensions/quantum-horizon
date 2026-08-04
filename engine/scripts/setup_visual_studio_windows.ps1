# Generates a Visual Studio solution for the engine and adds the custom module files.

param(
    [switch]$Force,
    [switch]$SkipVSCodeSetup,
    [switch]$Dev
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$scriptVersion = 8
$projectName = "QuantumHorizon"
$scriptRoot = $PSScriptRoot
$engineRoot = Split-Path -Parent $scriptRoot
$repositoryRoot = Split-Path -Parent $engineRoot
$engineDir = Join-Path $engineRoot "godot"
$modulesDir = Join-Path $engineRoot "modules"
$godotProjectDirectory = Join-Path $repositoryRoot "project"
$godotProjectFile = Join-Path $godotProjectDirectory "project.godot"
$moduleInfos = @(
    [pscustomobject]@{
        Directory = Join-Path $modulesDir "4d"
        ProjectRoot = "..\modules\4d"
        FilterRoot = "4D Module"
    }
    [pscustomobject]@{
        Directory = Join-Path $modulesDir "quantum_horizon"
        ProjectRoot = "..\modules\quantum_horizon"
        FilterRoot = "Quantum Horizon Module"
    }
)
$cacheDir = Join-Path $scriptRoot ".cache"
$stateFile = Join-Path $cacheDir "visual_studio_setup.state"
$vscodeSetupScript = Join-Path $scriptRoot "setup_vscode_windows.ps1"
$vscodeStateFile = Join-Path $repositoryRoot ".vscode\quantum_horizon_vscode.state"
$compileCommandsFile = Join-Path $engineDir "compile_commands.json"
$generatedSolution = Join-Path $engineDir "$projectName.sln"
$generatedProject = Join-Path $engineDir "$projectName.vcxproj"
$generatedFilters = Join-Path $engineDir "$projectName.vcxproj.filters"
$generatedUserSettings = Join-Path $engineDir "$projectName.vcxproj.user"
$generatedProps = Join-Path $engineDir "$projectName.windows.editor.x86_64.generated.props"
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

    $moduleInfo = Get-ModuleInfo -FullPath $FullPath
    $relativePath = $FullPath.Substring($moduleInfo.Directory.Length).TrimStart([char[]]"\/")
    return $moduleInfo.ProjectRoot + "\" + $relativePath.Replace("/", "\")
}

function Get-ModuleFilterPath {
    param([string]$FullPath)

    $moduleInfo = Get-ModuleInfo -FullPath $FullPath
    $relativePath = $FullPath.Substring($moduleInfo.Directory.Length).TrimStart([char[]]"\/")
    $relativeDirectory = [System.IO.Path]::GetDirectoryName($relativePath)
    if ([string]::IsNullOrEmpty($relativeDirectory)) {
        return $moduleInfo.FilterRoot
    }
    return $moduleInfo.FilterRoot + "\" + $relativeDirectory.Replace("/", "\")
}

function Get-ModuleInfo {
    param([string]$FullPath)

    $resolvedPath = [System.IO.Path]::GetFullPath($FullPath)
    foreach ($moduleInfo in $moduleInfos) {
        $moduleRoot = $moduleInfo.Directory.TrimEnd("\", "/")
        $moduleRootWithSeparator = $moduleRoot + [System.IO.Path]::DirectorySeparatorChar
        if ($resolvedPath.StartsWith($moduleRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $moduleInfo
        }
    }
    throw "File is not inside a configured custom module: $resolvedPath"
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
    $sourceFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $database) {
        $sourcePath = "$($entry.file)"
        if (-not [System.IO.Path]::IsPathRooted($sourcePath)) {
            $sourcePath = Join-Path "$($entry.directory)" $sourcePath
        }
        $sourcePath = [System.IO.Path]::GetFullPath($sourcePath)

        foreach ($moduleInfo in $moduleInfos) {
            $moduleRootWithSeparator = $moduleInfo.Directory.TrimEnd("\", "/") +
                [System.IO.Path]::DirectorySeparatorChar
            if ($sourcePath.StartsWith($moduleRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
                $sourceFiles.Add($sourcePath)
                break
            }
        }
    }

    return @($sourceFiles | Sort-Object -Unique)
}

function Get-VisualStudioHeaderFiles {
    $headerFiles = foreach ($moduleInfo in $moduleInfos) {
        Get-GitFiles -RepoPath $moduleInfo.Directory -Extensions @(".h", ".hh", ".hpp", ".hxx", ".inc")
    }
    return @($headerFiles |
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

    $escapedModuleIncludePaths = @($moduleInfos | ForEach-Object {
        [System.Security.SecurityElement]::Escape($_.Directory)
    }) -join ";"
    $items = [System.Collections.Generic.List[string]]::new()
    $items.Add("  <!-- Quantum Horizon custom module IntelliSense settings. Builds are still delegated to SCons. -->")
    $items.Add("  <PropertyGroup>")
    $items.Add("    <NMakePreprocessorDefinitions>GODOT_MODULE;`$(NMakePreprocessorDefinitions)</NMakePreprocessorDefinitions>")
    $items.Add("    <NMakeIncludeSearchPath>$escapedModuleIncludePaths;`$(NMakeIncludeSearchPath)</NMakeIncludeSearchPath>")
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
    foreach ($moduleInfo in $moduleInfos) {
        [void]$filterPaths.Add($moduleInfo.FilterRoot)
    }

    foreach ($filePath in @($ModuleHeaders) + @($ModuleSources)) {
        $moduleInfo = Get-ModuleInfo -FullPath $filePath
        $filterPath = Get-ModuleFilterPath -FullPath $filePath
        while ($filterPath.StartsWith($moduleInfo.FilterRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            [void]$filterPaths.Add($filterPath)
            if ($filterPath -eq $moduleInfo.FilterRoot) {
                break
            }
            $filterPath = Split-Path -Parent $filterPath
        }
    }

    $items = [System.Collections.Generic.List[string]]::new()
    $items.Add("  <!-- Quantum Horizon custom module folder hierarchy. -->")
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

function Get-VisualStudioUserSettings {
    return [ordered]@{
        ShowAllFiles = "false"
        LocalDebuggerCommandArguments = "--editor --path `"$godotProjectDirectory`""
        LocalDebuggerWorkingDirectory = $engineDir
        DebuggerFlavor = "WindowsLocalDebugger"
    }
}

function Configure-VisualStudioUserSettings {
    $settings = Get-VisualStudioUserSettings
    if (Test-Path -LiteralPath $generatedUserSettings -PathType Leaf) {
        $userSettingsContents = [System.IO.File]::ReadAllText($generatedUserSettings)
        if (-not $userSettingsContents.Contains("</Project>")) {
            throw "Visual Studio user settings have an unexpected format: $generatedUserSettings"
        }

        $missingSettings = [System.Collections.Generic.List[string]]::new()
        foreach ($setting in $settings.GetEnumerator()) {
            $escapedValue = [System.Security.SecurityElement]::Escape("$($setting.Value)")
            $settingPattern = "<$($setting.Key)>[^<]*</$($setting.Key)>"
            $settingElement = "<$($setting.Key)>$escapedValue</$($setting.Key)>"
            if ($userSettingsContents -match $settingPattern) {
                $userSettingsContents = [regex]::Replace(
                    $userSettingsContents,
                    $settingPattern,
                    $settingElement
                )
            }
            else {
                $missingSettings.Add("    $settingElement")
            }
        }

        if ($missingSettings.Count -gt 0) {
            $propertyGroup = @(
                "  <PropertyGroup>"
                $missingSettings
                "  </PropertyGroup>"
            ) -join [Environment]::NewLine
            $userSettingsContents = $userSettingsContents.Replace(
                "</Project>",
                $propertyGroup + [Environment]::NewLine + "</Project>"
            )
        }
    }
    else {
        $settingElements = @($settings.GetEnumerator() | ForEach-Object {
            $escapedValue = [System.Security.SecurityElement]::Escape("$($_.Value)")
            "    <$($_.Key)>$escapedValue</$($_.Key)>"
        })
        $userSettingsContents = @(
            '<?xml version="1.0" encoding="utf-8"?>'
            '<Project ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
            '  <PropertyGroup>'
            $settingElements
            '  </PropertyGroup>'
            '</Project>'
            ''
        ) -join [Environment]::NewLine
    }

    [System.IO.File]::WriteAllText(
        $generatedUserSettings,
        $userSettingsContents,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Test-VisualStudioUserSettings {
    if (-not (Test-Path -LiteralPath $generatedUserSettings -PathType Leaf)) {
        return $false
    }
    $userSettingsContents = [System.IO.File]::ReadAllText($generatedUserSettings)
    foreach ($setting in (Get-VisualStudioUserSettings).GetEnumerator()) {
        $escapedValue = [System.Security.SecurityElement]::Escape("$($setting.Value)")
        $settingElement = "<$($setting.Key)>$escapedValue</$($setting.Key)>"
        if (-not $userSettingsContents.Contains($settingElement)) {
            return $false
        }
    }
    return $true
}

function Test-VisualStudioBuildOutput {
    if (-not (Test-Path -LiteralPath $generatedProps -PathType Leaf)) {
        return $false
    }
    $devSuffix = if ($Dev) { ".dev" } else { "" }
    $expectedOutput = "bin\godot.windows.editor$devSuffix.double.x86_64.exe"
    $propsContents = [System.IO.File]::ReadAllText($generatedProps)
    return $propsContents.Contains(">$expectedOutput</NMakeOutput>")
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
foreach ($moduleInfo in $moduleInfos) {
    if (-not (Test-Path -LiteralPath $moduleInfo.Directory -PathType Container)) {
        throw "Custom module directory not found: $($moduleInfo.Directory)"
    }
}
if (-not (Test-Path -LiteralPath $godotProjectFile -PathType Leaf)) {
    throw "Godot project not found: $godotProjectFile"
}

# The compilation database provides the authoritative list of custom module
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
$devMode = if ($Dev) { "true" } else { "false" }
$currentSignature = "schema=$scriptVersion;dev=$devMode;vscode=$vscodeSignature"
$isCurrent = $false
if (-not $Force -and
    (Test-Path -LiteralPath $stateFile -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedSolution -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedProject -PathType Leaf) -and
    (Test-Path -LiteralPath $generatedFilters -PathType Leaf) -and
    (Test-VisualStudioUserSettings) -and
    (Test-VisualStudioBuildOutput) -and
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
    throw "No custom module source files were found in the compilation database."
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
if ($Dev) {
    $sconsArgs += @(
        "debug_symbols=yes"
        "dev_build=yes"
        "dev_mode=yes"
    )
}

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
if (-not (Test-VisualStudioBuildOutput)) {
    throw "Visual Studio build output does not match the requested development mode: $generatedProps"
}
Add-ExternalModuleFilesToProject -ModuleSources $moduleSources -ModuleHeaders $moduleHeaders
Add-ExternalModuleFilesToFilters -ModuleSources $moduleSources -ModuleHeaders $moduleHeaders
Configure-VisualStudioUserSettings

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

Write-Host "[OK] Visual Studio is configured for the engine and custom modules." -ForegroundColor Green
Write-Host "Solution: $repositorySolution"
