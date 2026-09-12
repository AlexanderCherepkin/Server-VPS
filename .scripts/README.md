# Автосинхронизация Server-VPS

Скрипты автоматически коммитят и пушат изменения в репозиторий на GitHub.

## Быстрый старт

### Запуск watcher вручную (для теста)

```powershell
cd F:\Server_VPS
.\.scripts\auto-sync.ps1
```

Watcher будет отслеживать изменения файлов, ждать 10 секунд после последнего
сохранения и затем делать `git add -A`, `git commit` и `git push`.

### Установка автозапуска при входе в Windows

Запустите PowerShell **от имени администратора**:

```powershell
cd F:\Server_VPS
.\.scripts\install-watcher.ps1
```

После этого watcher будет запускаться автоматически при входе пользователя.

### Управление заданием

```powershell
# Запустить прямо сейчас
Start-ScheduledTask -TaskName "Server-VPS Auto Sync"

# Остановить
Stop-ScheduledTask -TaskName "Server-VPS Auto Sync"

# Удалить
Unregister-ScheduledTask -TaskName "Server-VPS Auto Sync" -Confirm:$false
```

## Как это работает

- Скрипт использует `System.IO.FileSystemWatcher`.
- При каждом изменении сбрасывается таймер на 10 секунд (debounce).
- Когда 10 секунд тишины прошло — создаётся коммит вида
  `Auto-sync: YYYY-MM-DD HH:MM:SS` и выполняется push.
- События внутри папки `.git` игнорируются.
