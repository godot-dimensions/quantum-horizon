param(
    [string]$GodotVersion = "4.5"
)

Set-StrictMode -Version Latest
# Stop on first error.
$ErrorActionPreference = "Stop"

$hostRepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
$engineRepoPath = Join-Path $PSScriptRoot "../godot"
$modulesDir = Join-Path $PSScriptRoot "../modules"
$cacheDir = Join-Path $PSScriptRoot ".cache"
$updateCacheFile = Join-Path $cacheDir "update_cache.json"

function Invoke-Git {
    param(
        [string]$RepoPath,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    # Windows PowerShell 5.1 turns native stderr into error records. Git writes
    # routine messages such as "Already on ..." to stderr, so temporarily keep
    # those records non-terminating and decide success from Git's exit code.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& git -C $RepoPath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $details = $output -join "`n"
        throw "Git command failed in '$RepoPath': git $($Arguments -join ' ')`n$details"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Test-LocalBranch {
    param(
        [string]$RepoPath,
        [string]$BranchName
    )

    $result = Invoke-Git -RepoPath $RepoPath -Arguments @(
        "show-ref", "--verify", "--quiet", "refs/heads/$BranchName"
    ) -AllowFailure
    return $result.ExitCode -eq 0
}

function Get-RepositorySnapshot {
    param([string]$RepoPath)

    $head = Invoke-Git -RepoPath $RepoPath -Arguments @("rev-parse", "HEAD")
    return @($head.Output) -join "`n"
}

function Update-Repository {
    param(
        [string]$RepoPath,
        [string]$DefaultBranch
    )

    $resolvedRepoPath = (Resolve-Path -LiteralPath $RepoPath).Path
    Write-Host "===== Updating: $resolvedRepoPath ====="

    if (-not (Test-Path -LiteralPath (Join-Path $resolvedRepoPath ".git"))) {
        $hostPrefix = "$hostRepoPath$([IO.Path]::DirectorySeparatorChar)"
        if ($resolvedRepoPath.StartsWith($hostPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $submodulePath = $resolvedRepoPath.Substring($hostPrefix.Length).Replace('\\', '/')
            Write-Host "  Missing .git metadata. Attempting to initialize host submodule: $submodulePath"
            Invoke-Git -RepoPath $hostRepoPath -Arguments @(
                "submodule", "update", "--init", "--recursive", "--", $submodulePath
            ) | Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath (Join-Path $resolvedRepoPath ".git"))) {
        Write-Host "  No Git repository metadata found; skipping parent-tracked directory.`n"
        return [pscustomobject]@{
            Changed = $false
        }
    }

    $status = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
    if ($status.Output.Count -gt 0) {
        throw "Repository has uncommitted changes. Commit or discard them before updating:`n$($status.Output -join "`n")"
    }
    Write-Host "  Working tree is clean."

    Write-Host "  Checking for updates..."
    $fetch = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "fetch", "--all", "--prune"
    ) -AllowFailure
    if ($fetch.ExitCode -ne 0) {
        Write-Warning "Could not contact the remote. Cached remote information will be used."
    }

    $currentBranchResult = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "branch", "--show-current"
    )
    $currentBranch = (@($currentBranchResult.Output) -join "").Trim()

    $switchBranch = $DefaultBranch
    $remoteRef = "origin/$DefaultBranch"

    if ($currentBranch) {
        $upstream = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
            "rev-parse", "--abbrev-ref", "$currentBranch@{upstream}"
        ) -AllowFailure
        if ($upstream.ExitCode -eq 0) {
            $upstreamName = (@($upstream.Output) -join "").Trim()
            if ($upstreamName) {
                $switchBranch = $currentBranch
                $remoteRef = $upstreamName
                Write-Host "  Using tracked branch: $switchBranch -> $remoteRef"
            }
        }
    }

    $remoteCommitResult = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "rev-parse", "--verify", "$remoteRef`^{commit}"
    ) -AllowFailure
    if ($remoteCommitResult.ExitCode -ne 0) {
        throw "Remote branch '$remoteRef' is unavailable. Connect to the internet and try again."
    }
    $remoteCommit = (@($remoteCommitResult.Output) -join "").Trim()

    $snapshotBefore = Get-RepositorySnapshot -RepoPath $resolvedRepoPath

    if (Test-LocalBranch -RepoPath $resolvedRepoPath -BranchName $switchBranch) {
        $localCommitResult = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
            "rev-parse", "refs/heads/$switchBranch"
        )
        $localCommit = (@($localCommitResult.Output) -join "").Trim()

        $isAncestor = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
            "merge-base", "--is-ancestor", $localCommit, $remoteCommit
        ) -AllowFailure
        if ($isAncestor.ExitCode -ne 0) {
            $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
            $backupBranch = "$switchBranch-backup-$timestamp"
            Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
                "branch", $backupBranch, $localCommit
            ) | Out-Null
            Write-Host "  Preserved local commits on: $backupBranch" -ForegroundColor Yellow
        }

        $switch = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
            "switch", $switchBranch
        ) -AllowFailure
    }
    else {
        $switch = Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
            "switch", "--create", $switchBranch, "--track", $remoteRef
        ) -AllowFailure
    }

    if ($switch.ExitCode -ne 0) {
        throw "Could not switch to '$switchBranch':`n$($switch.Output -join "`n")"
    }

    Write-Host "  Synchronizing $switchBranch with $remoteRef..."
    Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "reset", "--hard", $remoteRef
    ) | Out-Null
    Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "submodule", "sync", "--recursive"
    ) | Out-Null
    Invoke-Git -RepoPath $resolvedRepoPath -Arguments @(
        "submodule", "update", "--init", "--recursive"
    ) | Out-Null

    $snapshotAfter = Get-RepositorySnapshot -RepoPath $resolvedRepoPath
    $changed = $snapshotBefore -ne $snapshotAfter

    Write-Host "  [OK] Repository is up to date.`n" -ForegroundColor Green
    return [pscustomobject]@{
        Changed = $changed
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git was not found. Install Git and make sure 'git' is available in PATH."
}
if (-not (Test-Path -LiteralPath (Join-Path $hostRepoPath ".git"))) {
    throw "Host Git repository not found: $hostRepoPath"
}
if (-not (Test-Path -LiteralPath $engineRepoPath)) {
    throw "Engine repository not found: $engineRepoPath"
}
if (-not (Test-Path -LiteralPath $modulesDir)) {
    throw "Modules directory not found: $modulesDir"
}

$engineBranch = "dimensions-fixes-$GodotVersion"
Write-Host "Engine target branch: $engineBranch`n"

$engineResult = Update-Repository -RepoPath $engineRepoPath -DefaultBranch $engineBranch
$reposChanged = $engineResult.Changed

$modules = @(Get-ChildItem -LiteralPath $modulesDir -Directory | Sort-Object Name)
if ($modules.Count -eq 0) {
    Write-Warning "No modules found in $modulesDir"
}
else {
    foreach ($module in $modules) {
        $moduleResult = Update-Repository -RepoPath $module.FullName -DefaultBranch "main"
        if ($moduleResult.Changed) {
            $reposChanged = $true
        }
    }
}

New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
[ordered]@{
    reposChanged = $reposChanged
    lastUpdateTime = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content -LiteralPath $updateCacheFile -Encoding UTF8

Write-Host "[OK] All engine repositories are up to date." -ForegroundColor Green
if ($reposChanged) {
    Write-Host "New source revisions were downloaded." -ForegroundColor Yellow
}
else {
    Write-Host "No source revisions changed." -ForegroundColor Green
}
