#Requires -Version 5.1
<#
.SYNOPSIS
    Создаёт запланированное задание Windows, которое запускает auto-sync.ps1
    при входе пользователя и следит за изменениями в репозитории.
#>
param(
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepoPath ".scripts\auto-sync.ps1"
$taskName = "Server-VPS Auto Sync"

if (-not (Test-Path $scriptPath)) {
    throw "Не найден скрипт $scriptPath"
}

# Удаляем старое задание, если было
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Старое задание '$taskName' удалено"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Автоматический commit/push изменений в репозитории Server-VPS"

Write-Host "Задание '$taskName' создано. Watcher запустится при следующем входе в систему."
Write-Host "Для запуска прямо сейчас выполните: Start-ScheduledTask -TaskName '$taskName'"
