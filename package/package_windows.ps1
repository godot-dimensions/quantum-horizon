#Requires -Version 5.1
# Builds a custom Godot template and exports ../project/ as a Windows ZIP.
<#
.SYNOPSIS
Build and package Quantum Horizon for Windows.
.EXAMPLE
powershell -File ./package/package_windows.ps1
.EXAMPLE
powershell -File ./package/package_windows.ps1 -Debug -Architecture arm64 -Jobs 8
.NOTES
Defaults to Windows x86_64 and template_release. -Debug uses template_debug,
not an engine development build. -Dev implies -Debug and enables engine development
checks and debug symbols. Outputs package/bin/quantum-horizon-PLATFORM-ARCH-MODE.zip.
An existing host editor is reused; if missing, it is built with the same build script.
Uses ../project/export_presets.cfg, temporarily overriding the first Windows preset's
custom template paths and architecture. The original file is restored after export.
Close the project editor before packaging so it cannot save over the temporary preset.
#>

param(
    [switch]$Debug,
    [switch]$Dev,
    [Alias("OS")]
    [ValidateSet("windows")]
    [string]$Platform = "windows",
    [Alias("Arch")]
    [ValidateSet("x86_64", "x86_32", "arm64")]
    [string]$Architecture = "x86_64",
    [ValidateRange(1, 2147483647)]
    [int]$Jobs = [Environment]::ProcessorCount,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-WindowsCommandLineArgument {
    param([string]$Argument)

    # Windows treats backslashes specially before quotes and the closing quote.
    $escapedArgument = [regex]::Replace($Argument, '(\\*)("|$)', [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $backslashCount = $match.Groups[1].Length
        if ($match.Groups[2].Value -eq '"') {
            return ('\' * (2 * $backslashCount + 1)) + '"'
        }
        return '\' * (2 * $backslashCount)
    })
    return '"' + $escapedArgument + '"'
}

function Invoke-Godot {
    param([string]$Executable, [string[]]$Arguments)

    # Windows GUI executables must be explicitly waited for before checking their exit code.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.UseShellExecute = $false
    # Manual quoting is suboptimal but required by PowerShell 5.1's .NET Framework.
    # If support for 5.1 is dropped, replace this with ArgumentList on newer PowerShell versions.
    $quotedArguments = foreach ($argument in $Arguments) {
        ConvertTo-WindowsCommandLineArgument -Argument $argument
    }
    $startInfo.Arguments = $quotedArguments -join ' '
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "Godot failed with exit code $($process.ExitCode): $($Arguments -join ' ')"
        }
    }
    finally {
        $process.Dispose()
    }
}

$engineRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../engine"))
$projectDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../project"))
$buildScript = Join-Path $engineRoot "scripts/build_engine_windows.ps1"
$binDir = Join-Path $engineRoot "godot/bin"
$mode = if ($Debug -or $Dev) { "debug" } else { "release" }
$devSuffix = if ($Dev) { ".dev" } else { "" }
$packageMode = if ($Dev) { "dev" } else { $mode }
$target = "template_$mode"
$templatePath = Join-Path $binDir "godot.$Platform.$target$devSuffix.double.$Architecture.exe"
$outputDir = Join-Path $PSScriptRoot "bin"
$outputPath = Join-Path $outputDir "quantum-horizon-$Platform-$Architecture-$packageMode.zip"
$presetPath = Join-Path $projectDir "export_presets.cfg"

foreach ($requiredFile in @($buildScript, (Join-Path $projectDir "project.godot"), $presetPath)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required file not found: $requiredFile"
    }
}

Write-Host "Building $Platform $Architecture $packageMode template..." -ForegroundColor Cyan
& $buildScript -Target $target -Platform $Platform -Architecture $Architecture -Jobs $Jobs -Clean:$Clean -Dev:$Dev -DoNotRun
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "Built template not found: $templatePath"
}

# Exporting always runs the host editor, even when the template targets another architecture.
$hostArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
$editorArchitecture = switch ($hostArchitecture) {
    "x64" { "x86_64" }
    "x86" { "x86_32" }
    "arm64" { "arm64" }
    default { throw "Unsupported Windows host architecture: $hostArchitecture" }
}
$editorPath = Join-Path $binDir "godot.windows.editor$devSuffix.double.$editorArchitecture.exe"
if (-not (Test-Path -LiteralPath $editorPath -PathType Leaf)) {
    & $buildScript -Target editor -Platform windows -Architecture $editorArchitecture -Jobs $Jobs -Dev:$Dev -DoNotRun
}
if (-not (Test-Path -LiteralPath $editorPath -PathType Leaf)) {
    throw "Godot editor not found: $editorPath"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$backupPath = Join-Path $projectDir "export_presets.cfg.package-backup.tmp"
# CreateNew also prevents two packaging runs from replacing each other's presets.
$presetLock = [System.IO.File]::Open($backupPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
$presetBackedUp = $false
$temporaryDir = Join-Path $PSScriptRoot ".cache/package-$([guid]::NewGuid())"
$temporaryOutput = Join-Path $temporaryDir (Split-Path -Leaf $outputPath)
try {
    New-Item -ItemType Directory -Path $temporaryDir -Force | Out-Null
    $presetBytes = [System.IO.File]::ReadAllBytes($presetPath)
    $presetLock.Write($presetBytes, 0, $presetBytes.Length)
    $presetLock.Flush()
    $presetBackedUp = $true
    $templateConfigPath = $templatePath.Replace('\', '/').Replace('"', '\"')
    $originalConfig = [System.IO.File]::ReadAllText($presetPath)
    $sections = [regex]::Matches($originalConfig, '(?ms)^\[preset\.(?<index>\d+)\]\r?\n(?<settings>.*?)(?=^\[|\z)')
    $windowsSection = $null
    foreach ($section in $sections) {
        if ($section.Groups['settings'].Value -match '(?m)^platform="Windows Desktop"\r?$') {
            $windowsSection = $section
            break
        }
    }
    if ($null -eq $windowsSection) {
        throw "Windows Desktop export preset not found in: $presetPath"
    }
    $nameMatch = [regex]::Match($windowsSection.Groups['settings'].Value, '(?m)^name=(".*")\r?$')
    if (-not $nameMatch.Success) {
        throw "Windows export preset name not found in: $presetPath"
    }
    $presetName = $nameMatch.Groups[1].Value | ConvertFrom-Json
    $index = $windowsSection.Groups['index'].Value
    $optionsSection = [regex]::Match($originalConfig, "(?ms)^\[preset\.$index\.options\]\r?\n(?<options>.*?)(?=^\[|\z)")
    $options = $optionsSection.Groups['options'].Value
    $overrides = [ordered]@{
        "custom_template/debug" = '""'
        "custom_template/release" = '""'
        "binary_format/architecture" = "`"$Architecture`""
    }
    # Clear the unused template path to avoid validating a template for another architecture.
    $overrides["custom_template/$mode"] = "`"$templateConfigPath`""
    foreach ($key in $overrides.Keys) {
        $pattern = '(?m)^' + [regex]::Escape($key) + '=[^\r\n]*'
        if (-not [regex]::IsMatch($options, $pattern)) {
            throw "Windows export option '$key' not found in: $presetPath"
        }
        $replacement = "$key=$($overrides[$key])"
        $options = [regex]::Replace($options, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
    }
    $optionsGroup = $optionsSection.Groups['options']
    $presetConfig = $originalConfig.Substring(0, $optionsGroup.Index) + $options + $originalConfig.Substring($optionsGroup.Index + $optionsGroup.Length)
    [System.IO.File]::WriteAllText($presetPath, $presetConfig, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Importing project resources..." -ForegroundColor Cyan
    Invoke-Godot -Executable $editorPath -Arguments @("--headless", "--path", $projectDir, "--import")
    Write-Host "Exporting $packageMode package..." -ForegroundColor Cyan
    Invoke-Godot -Executable $editorPath -Arguments @("--headless", "--path", $projectDir, "--export-$mode", $presetName, $temporaryOutput)
    if (-not (Test-Path -LiteralPath $temporaryOutput -PathType Leaf) -or (Get-Item -LiteralPath $temporaryOutput).Length -eq 0) {
        throw "Export did not produce a nonempty ZIP: $temporaryOutput"
    }
    Move-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
}
finally {
    $presetLock.Dispose()
    if ($presetBackedUp) {
        [System.IO.File]::WriteAllBytes($presetPath, $presetBytes)
    }
    Remove-Item -LiteralPath $backupPath
    if (Test-Path -LiteralPath $temporaryOutput) {
        Remove-Item -LiteralPath $temporaryOutput
    }
    if (Test-Path -LiteralPath $temporaryDir) {
        Remove-Item -LiteralPath $temporaryDir
    }
}

Write-Host "Package ready: $outputPath" -ForegroundColor Green
