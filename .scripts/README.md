# Server-VPS Auto Sync

These scripts automatically commit and push changes to the GitHub repository
whenever files in `F:\Server_VPS` are modified.

## Quick start

### Run watcher manually (for testing)

```powershell
cd F:\Server_VPS
.\.scripts\auto-sync.ps1
```

The watcher will track file changes, wait 10 seconds after the last save, then
run `git add -A`, `git commit`, and `git push`.

### Install auto-start on Windows logon

Open **PowerShell as Administrator** and run:

```powershell
cd F:\Server_VPS
.\.scripts\install-watcher.ps1
```

After that, the watcher starts automatically every time you log in.

### Manage the scheduled task

```powershell
# Start now
Start-ScheduledTask -TaskName "Server-VPS Auto Sync"

# Stop
Stop-ScheduledTask -TaskName "Server-VPS Auto Sync"

# Remove
Unregister-ScheduledTask -TaskName "Server-VPS Auto Sync" -Confirm:$false
```

## How it works

- Uses `System.IO.FileSystemWatcher` to watch the repository.
- Resets a 10-second timer (debounce) on every change.
- When 10 seconds of inactivity pass, creates a commit like
  `Auto-sync: YYYY-MM-DD HH:MM:SS` and pushes it.
- Events inside the `.git` folder are ignored.
- Logs are written to `.scripts\auto-sync.log`.
