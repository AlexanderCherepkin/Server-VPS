#Requires -Version 5.1
<#
.SYNOPSIS
    Automatically commits and pushes changes in the Server-VPS repository
    whenever files in the working directory change.
.DESCRIPTION
    FileSystemWatcher with debounce: waits 10 seconds after the last change,
    then runs git add -A, commit with a timestamp, and push.
    Logs to .scripts\auto-sync.log
#>
param(
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
    [int]$DebounceSeconds = 10,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    # Keep the log outside the watched repository to avoid an infinite loop:
    # writing the log would trigger the FileSystemWatcher, which would write again.
    $logDir = Join-Path $env:LOCALAPPDATA "Server-VPS"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir "auto-sync.log"
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
    Write-Host $line
}

function Sync-Repository {
    param([string]$Path, [string]$Branch)
    Push-Location $Path
    try {
        # Wait up to 30 seconds if another git process holds index.lock.
        $lockFile = Join-Path $Path ".git\index.lock"
        $waited = 0
        while (Test-Path $lockFile) {
            if ($waited -ge 30) {
                throw "index.lock exists for more than 30 seconds, aborting sync"
            }
            Start-Sleep -Seconds 1
            $waited++
        }

        # Capture stderr separately so warnings do not pollute error handling.
        $addErr = git add -A 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git add failed (exit $LASTEXITCODE): $addErr" }

        $status = git status --short
        if (-not $status) {
            Write-Log "[auto-sync] No changes to sync"
            return
        }

        $message = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $commitErr = git commit -m "$message`n`nCo-Authored-By: Claude Code <noreply@anthropic.com>" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git commit failed (exit $LASTEXITCODE): $commitErr" }

        $pushErr = git push origin $Branch 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE): $pushErr" }

        Write-Log "[auto-sync] Synced: $message"
    }
    catch {
        Write-Log "[auto-sync] ERROR: $_"
    }
    finally {
        Pop-Location
    }
}

Push-Location $RepoPath

try {
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "Git repository not found at $RepoPath"
    }

    $branch = git branch --show-current 2>$null
    if (-not $branch) {
        throw "Could not determine current git branch"
    }

    Write-Log "[auto-sync] Watching: $RepoPath"
    Write-Log "[auto-sync] Branch: $branch"
    Write-Log "[auto-sync] Debounce: ${DebounceSeconds}s"

    if ($Once) {
        Start-Sleep -Seconds 1
        Sync-Repository -Path $RepoPath -Branch $branch
        return
    }

    $global:AutoSyncRepoPath = $RepoPath
    $global:AutoSyncBranch = $branch
    $global:AutoSyncDebounceMs = $DebounceSeconds * 1000
    $global:AutoSyncTimer = $null
    $global:AutoSyncLock = New-Object System.Object

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $RepoPath
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor
                            [System.IO.NotifyFilters]::FileName -bor
                            [System.IO.NotifyFilters]::DirectoryName
    $watcher.Filter = "*"

    $onChange = {
        $evt = $Event.SourceEventArgs
        $fullPath = $evt.FullPath
        $repoPath = $global:AutoSyncRepoPath
        if ($fullPath.StartsWith((Join-Path $repoPath ".git"))) { return }

        $relative = $fullPath.Substring($repoPath.Length + 1)

        # Ignore editor temp files and lock files to prevent race conditions.
        if ($relative -match '\.tmp\.[0-9a-f]+($|\.)' -or
            $relative -like '*.lock' -or
            $relative -like '*~') {
            return
        }

        Write-Log "[auto-sync] Change detected: $relative"

        $timer = $null
        [System.Threading.Monitor]::Enter($global:AutoSyncLock)
        try {
            if ($global:AutoSyncTimer) {
                try { $global:AutoSyncTimer.Stop() } catch {}
                try { $global:AutoSyncTimer.Dispose() } catch {}
            }
            $global:AutoSyncTimer = New-Object System.Timers.Timer($global:AutoSyncDebounceMs)
            $global:AutoSyncTimer.AutoReset = $false
            $timer = $global:AutoSyncTimer
        }
        finally {
            [System.Threading.Monitor]::Exit($global:AutoSyncLock)
        }

        Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            Sync-Repository -Path $global:AutoSyncRepoPath -Branch $global:AutoSyncBranch
            $Event.Sender.Dispose()
        } | Out-Null
        $timer.Start()
    }

    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $onChange | Out-Null

    $watcher.EnableRaisingEvents = $true
    Write-Log "[auto-sync] Watcher started. Press Ctrl+C to stop."

    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Pop-Location
}
