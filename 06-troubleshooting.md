# 6. Troubleshooting и safety

## Таблица типичных проблем

| Проблема | Что проверить |
|---|---|
| Клиент не запускает профиль | Журнал клиента, совместимость версии sing-box, лишние поля в JSON |
| Сервер active, но соединения нет | `sing-box check`, `systemctl status`, listener на TCP/443, firewall VPS и firewall провайдера |
| IP не изменился | Выбран ли новый профиль, нажата ли Play, есть ли `auto_route: true`, уходит ли final route в VLESS outbound |
| DNS перестал работать | Настройки DNS в клиентском JSON, detour через tunnel, правило DNS hijack, отсутствие несовместимых полей |
| `authentication failed` | UUID на сервере и клиенте, short_id, public/private key pair, не был ли пересоздан только один профиль |
| `TLS mismatch` | `REALITY_HANDSHAKE_HOST`, `server_name`, Reality public key, short_id, handshake server |
| Проверка 443 не проходит | Проверяй именно TCP/443, правила UFW, firewall провайдера и listener sing-box |
| Клиент ругается на поле | Убери поле, которое не поддерживает версия клиента, и снова проверь JSON |

**Главное правило:** не лечи TLS-ошибку через `insecure: true`. Это маскирует проблему, а не исправляет схему.

## Rollback по шагам

### Откат SSH hardening

Если потерял SSH-доступ:

1. Войди через web-console / rescue mode провайдера.
2. Удали файл:

```bash
sudo rm /etc/ssh/sshd_config.d/00-hardening.conf
sudo systemctl reload ssh
```

### Откат sing-box

```bash
sudo systemctl stop sing-box
sudo systemctl disable sing-box
sudo rm /etc/sing-box/config.json
sudo apt-get remove -y sing-box
sudo rm /etc/apt/sources.list.d/sagernet.sources
sudo rm /etc/apt/keyrings/sagernet.asc
```

### Откат firewall

```bash
sudo ufw disable
sudo ufw reset
sudo ufw allow OpenSSH
sudo ufw enable
```

### Восстановление конфигов из backup

```bash
sudo cp /root/backups/YYYYMMDD-HHMMSS/sshd_config.d/* /etc/ssh/sshd_config.d/ 2>/dev/null || true
sudo cp /root/backups/YYYYMMDD-HHMMSS/config.json /etc/sing-box/config.json 2>/dev/null || true
sudo systemctl reload ssh
sudo systemctl restart sing-box
```

## Управление секретами

### Где должны храниться секреты

- **UUID, private key, short_id** — в `/root/reality-setup/secrets.env` на сервере (права 600).
- **Public key и profile JSON** — в защищённом локальном хранилище (менеджер паролей, зашифрованная заметка).

### Чего не делать

- Не печатай UUID, Reality keys, short_id в чате.
- Не выводи их в публичный лог.
- Не помещай в shell history (используй `HISTCONTROL=ignorespace` перед командами с секретами).
- Не показывай на записи экрана.
- Не передавай через URI или QR.
- Не коммить profile JSON в Git.
- Не храни профиль в папке проекта.
- Не отправляй профиль в мессенджеры.

### Как сгенерировать новые секреты

Ели профиль скомпрометирован:

```bash
sing-box generate uuid
sing-box generate reality-keypair
openssl rand -hex 4
```

Затем обнови:

1. `/root/reality-setup/secrets.env` на сервере;
2. `/etc/sing-box/config.json` на сервере;
3. Клиентский JSON профиль;
4. Перезапусти sing-box;
5. Импортируй обновлённый профиль в клиент.

## Проверки безопасности

После настройки убедись:

- [ ] на VPS нет Claude Code, Codex, Node.js, Git-проектов, файлов авторизации;
- [ ] SSH работает только по ключу, root и пароль отключены;
- [ ] открыты только порты 22/TCP (SSH) и 443/TCP (VLESS + Reality);
- [ ] секреты имеют права 600 и хранятся root-only;
- [ ] профиль не остался во временных папках после импорта;
- [ ] `insecure: true` нигде не включён.

## Что в итоге должно получиться

На VPS:

- Ubuntu;
- sing-box;
- VLESS + Reality inbound;
- root-only секреты;
- минимальные firewall-правила.

На твоём устройстве:

- Claude Code, Codex, браузер и проекты;
- локальный клиент подключения;
- импортированный профиль;
- возможность нажать Play и Stop.

Главная проверка простая: после Play внешний IP становится IP твоего VPS, DNS и интернет работают, а после Stop возвращается обычное подключение.
