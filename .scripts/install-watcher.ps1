#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a Windows scheduled task that runs auto-sync.ps1 at user logon
    to watch the Server-VPS repository and auto-commit/push changes.
#>
param(
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $RepoPath ".scripts\auto-sync.ps1"
$taskName = "Server-VPS Auto Sync"

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Old task '$taskName' removed"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy RemoteSigned -WindowStyle Hidden -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Auto commit/push changes for the Server-VPS repository"

Write-Host "Task '$taskName' created. Watcher will start at next logon."
Write-Host "To start now run: Start-ScheduledTask -TaskName '$taskName'"
