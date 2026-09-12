#Requires -Version 5.1
<#
.SYNOPSIS
    Автоматически коммитит и пушит изменения в репозиторий Server-VPS
    при изменении файлов в рабочей папке.
.DESCRIPTION
    Watcher с debounce: ждёт 10 секунд тишины после последнего изменения,
    затем делает git add, commit с timestamp и push в текущую ветку.
    Лог пишется в .scripts/auto-sync.log
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
    $logFile = Join-Path $RepoPath ".scripts\auto-sync.log"
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
    Write-Host $line
}

function Sync-Repository {
    param([string]$Path, [string]$Branch)
    Push-Location $Path
    try {
        git add -A | Out-Null
        $status = git status --short
        if (-not $status) {
            Write-Log "[auto-sync] Нет изменений для синхронизации"
            return
        }

        $message = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m "$message`n`nCo-Authored-By: Claude Code <noreply@anthropic.com>" | Out-Null
        git push origin $Branch | Out-Null
        Write-Log "[auto-sync] Успешно синхронизировано: $message"
    }
    catch {
        Write-Log "[auto-sync] ОШИБКА: $_"
    }
    finally {
        Pop-Location
    }
}

Push-Location $RepoPath

try {
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "В папке $RepoPath не найден git-репозиторий"
    }

    $branch = git branch --show-current 2>$null
    if (-not $branch) {
        throw "Не удалось определить текущую git-ветку"
    }

    Write-Log "[auto-sync] Отслеживание: $RepoPath"
    Write-Log "[auto-sync] Ветка: $branch"
    Write-Log "[auto-sync] Debounce: ${DebounceSeconds}s"

    if ($Once) {
        Start-Sleep -Seconds 1
        Sync-Repository -Path $RepoPath -Branch $branch
        return
    }

    # Глобальное состояние для событий watcher
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
        Write-Log "[auto-sync] Изменение: $relative"

        # Безопасный сброс таймера
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
    Write-Log "[auto-sync] Watcher запущен. Нажмите Ctrl+C для остановки."

    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Pop-Location
}
