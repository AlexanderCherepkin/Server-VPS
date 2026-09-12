#Requires -Version 5.1
<#
.SYNOPSIS
    Автоматически коммитит и пушит изменения в репозиторий Server-VPS
    при изменении файлов в рабочей папке.
.DESCRIPTION
    Watcher с debounce: ждёт 10 секунд тишины после последнего изменения,
    затем делает git add, commit с timestamp и push в текущую ветку.
#>
param(
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot),
    [int]$DebounceSeconds = 10,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

Push-Location $RepoPath

try {
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "В папке $RepoPath не найден git-репозиторий"
    }

    $branch = git branch --show-current 2>$null
    if (-not $branch) {
        throw "Не удалось определить текущую git-ветку"
    }

    Write-Host "[auto-sync] Отслеживание: $RepoPath"
    Write-Host "[auto-sync] Ветка: $branch"
    Write-Host "[auto-sync] Debounce: ${DebounceSeconds}s"

    $syncScript = {
        param($path, $branch)
        Push-Location $path
        try {
            git add -A
            $status = git status --short
            if (-not $status) {
                Write-Host "[auto-sync] Нет изменений для синхронизации"
                return
            }

            $message = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            git commit -m "$message`n`nCo-Authored-By: Claude Code <noreply@anthropic.com>" | Out-Null
            git push origin $branch
            Write-Host "[auto-sync] Успешно синхронизировано: $message"
        }
        catch {
            Write-Host "[auto-sync] ОШИБКА: $_"
        }
        finally {
            Pop-Location
        }
    }

    $timer = $null
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $RepoPath
    $watcher.IncludeSubdirectories = $true
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor
                            [System.IO.NotifyFilters]::FileName -bor
                            [System.IO.NotifyFilters]::DirectoryName
    $watcher.Filter = "*"

    $onChange = {
        $evt = $Event.SourceEventArgs
        $relative = $evt.FullPath.Substring($watcher.Path.Length + 1)
        # Игнорируем события внутри .git
        if ($relative -like ".git*") { return }

        Write-Host "[auto-sync] Изменение: $relative"
        if ($timer) {
            $timer.Stop()
            $timer.Dispose()
        }
        $script:timer = New-Object System.Timers.Timer ($DebounceSeconds * 1000)
        $script:timer.AutoReset = $false
        Register-ObjectEvent -InputObject $script:timer -EventName Elapsed -Action {
            & $syncScript -path $RepoPath -branch $branch
            $Event.Sender.Dispose()
        } | Out-Null
        $script:timer.Start()
    }

    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $onChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $onChange | Out-Null

    $watcher.EnableRaisingEvents = $true
    Write-Host "[auto-sync] Watcher запущен. Нажмите Ctrl+C для остановки."

    if ($Once) {
        Start-Sleep -Seconds 2
        & $syncScript -path $RepoPath -branch $branch
        return
    }

    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Pop-Location
}
