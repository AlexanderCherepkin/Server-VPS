# 3. Настройка VPS как endpoint

## Целевая архитектура

```text
локальные Claude Code и Codex
↓
клиент подключения с TUN
↓
VLESS + Reality по TCP/443
↓
sing-box на VPS
↓
интернет
```

**Жёсткий инвариант:** на VPS работает только sing-box и необходимые системные компоненты. Claude Code, Codex, Node.js, браузер, Git-проекты и файлы авторизации на сервер не устанавливаются и не копируются.

## Входные данные

Перед началом заполни (из [`01-requirements.md`](./01-requirements.md) и [`02-purchase-checklist.md`](./02-purchase-checklist.md)):

```text
VPS_PUBLIC_IPV4=138.124.92.11
VPS_INITIAL_SSH_USER=root
VPS_ADMIN_USER=adminproxy
VPS_SSH_PORT=22
LOCAL_SSH_PRIVATE_KEY_PATH=D:\Settings\Users\user\.ssh\id_ed25519
VPS_PROVIDER_FIREWALL=выключен
REALITY_HANDSHAKE_HOST=www.microsoft.com
```

## Фаза 1. Preflight

**Что проверяем:** доступ, состояние сервера, свободен ли TCP/443.

Подключись:

```bash
ssh root@138.124.92.11
```

На сервере:

```bash
uname -a
lsb_release -a
sudo ss -ltnp
sudo ufw status verbose
```

Проверь:

- [ ] Публичный IP совпадает с купленным VPS.
- [ ] SSH-доступ работает.
- [ ] Ubuntu 24.04 LTS.
- [ ] TCP/443 свободен.
- [ ] Текущие правила firewall понятны.
- [ ] Нет чужой действующей конфигурации sing-box.

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 2. Safety

**Принцип:** перед каждой мутацией — backup и rollback.

1. Не перезаписывай неизвестный работающий сервер.
2. Не удаляй существующие файлы.
3. Не закрывай исходную SSH-сессию, пока новый вход не проверен.
4. Не меняй несколько параметров одновременно.
5. После каждой фазы — PASS/FAIL.

Создай backup существующих конфигов:

```bash
sudo mkdir -p /root/backups/$(date +%Y%m%d-%H%M%S)
sudo cp -r /etc/ssh/sshd_config.d /root/backups/$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
sudo cp /etc/sing-box/config.json /root/backups/$(date +%Y%m%d-%H%M%S)/ 2>/dev/null || true
```

**Rollback:** восстановить из `/root/backups/YYYYMMDD-HHMMSS/`.

## Фаза 3. SSH hardening

**Что будет изменено:** создадим отдельного sudo-пользователя и отключим root/парольный вход.

### 3.1. Создать sudo-пользователя

```bash
sudo adduser adminproxy
sudo usermod -aG sudo adminproxy
sudo mkdir -p /home/adminproxy/.ssh
sudo cp /root/.ssh/authorized_keys /home/adminproxy/.ssh/authorized_keys
sudo chown -R adminproxy:adminproxy /home/adminproxy/.ssh
sudo chmod 700 /home/adminproxy/.ssh
sudo chmod 600 /home/adminproxy/.ssh/authorized_keys
```

### 3.2. Проверить свежий вход во втором терминале

Открой второе окно терминала и выполни:

```bash
ssh adminproxy@138.124.92.11
sudo whoami
```

Ожидаемый результат: `root`.

Только после успешного входа переходи к 3.3.

### 3.3. Усилить SSH

```bash
sudo nano /etc/ssh/sshd_config.d/00-hardening.conf
```

Вставь:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Проверь синтаксис:

```bash
sudo sshd -t
```

Если ошибок нет:

```bash
sudo systemctl reload ssh
```

### 3.4. Проверить вход ещё раз

В новом терминале:

```bash
ssh adminproxy@138.124.92.11
```

Только теперь можно закрыть старую root-сессию.

**Rollback:**

```bash
sudo rm /etc/ssh/sshd_config.d/00-hardening.conf
sudo systemctl reload ssh
```

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 4. Firewall

**Что будет изменено:** включим UFW, разрешим SSH и TCP/443.

```bash
sudo ufw allow OpenSSH
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

Если у провайдера есть отдельный firewall, открой в панели:

| Порт | Протокол | Зачем |
|---|---|---|
| 22 | TCP | SSH |
| 443 | TCP | VLESS + Reality |

Проверь, что текущая SSH-сессия жива и новый вход работает.

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 5. Установка sing-box

**Что будет изменено:** добавим официальный репозиторий SagerNet и установим sing-box.

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
```

Создай файл репозитория:

```bash
sudo nano /etc/apt/sources.list.d/sagernet.sources
```

Вставь:

```text
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
```

Установи:

```bash
sudo apt-get update
sudo apt-get install -y sing-box jq
sing-box version
```

Запиши установленную версию:

```text
SERVER_SING_BOX_VERSION=[вывод sing-box version]
```

**Rollback:**

```bash
sudo apt-get remove -y sing-box
sudo rm /etc/apt/sources.list.d/sagernet.sources
sudo rm /etc/apt/keyrings/sagernet.asc
```

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 6. Проверка Reality handshake host

Reality не требует собственного домена и сертификата. Нужен корректный handshake host, доступный с VPS по TCP/443.

```bash
curl -I https://www.microsoft.com
```

Пример:

```bash
curl -I https://www.microsoft.com
```

Правила:

- [ ] hostname корректен и доступен с VPS;
- [ ] `server_name` клиента будет совпадать с ним;
- [ ] `handshake.server` в серверном конфиге будет тем же hostname;
- [ ] не используем собственный домен/сертификат для Reality;
- [ ] никогда не включаем `insecure: true`.

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 7. Генерация секретов

**Важно:** настоящие секреты не выводи в чат, не копируй в мессенджеры, не коммить в Git.

Создай root-only директорию:

```bash
sudo install -d -m 700 /root/reality-setup
```

Сгенерируй UUID:

```bash
sing-box generate uuid
```

Сгенерируй Reality keypair:

```bash
sing-box generate reality-keypair
```

Сгенерируй short_id:

```bash
openssl rand -hex 4
```

Сохрани значения в root-only файл:

```bash
sudo nano /root/reality-setup/secrets.env
sudo chmod 600 /root/reality-setup/secrets.env
```

Формат:

```text
UUID=__UUID__
REALITY_PRIVATE_KEY=__REALITY_PRIVATE_KEY__
REALITY_PUBLIC_KEY=__REALITY_PUBLIC_KEY__
SHORT_ID=__SHORT_ID__
```

Правила:

- [ ] UUID совпадает на сервере и в клиентском профиле;
- [ ] `REALITY_PRIVATE_KEY` хранится только на сервере;
- [ ] `REALITY_PUBLIC_KEY` попадает только в клиентский профиль;
- [ ] `SHORT_ID` совпадает на сервере и клиенте;
- [ ] права на файл — `600`;
- [ ] секреты не в чате, не в логах, не в Git, не в QR/URI.

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 8. Серверный конфиг sing-box

Создай директорию и конфиг:

```bash
sudo mkdir -p /etc/sing-box
sudo nano /etc/sing-box/config.json
```

Содержимое:

```json
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 443,
      "users": [
        {
          "uuid": "__UUID__",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "__REALITY_HANDSHAKE_HOST__",
        "reality": {
          "enabled": true,
          "private_key": "__REALITY_PRIVATE_KEY__",
          "short_id": ["__SHORT_ID__"]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ]
}
```

Замени плейсхолдеры реальными значениями из `/root/reality-setup/secrets.env`.

Перед запуском обязательно:

```bash
sudo sing-box check -c /etc/sing-box/config.json
```

Если проверка не проходит — остановись. Не запускай service с невалидным конфигом.

**Вердикт:** [ ] PASS / [ ] FAIL

## Фаза 9. Запуск service

После успешного `sing-box check`:

```bash
sudo systemctl enable --now sing-box
sudo systemctl status sing-box --no-pager
sudo journalctl -u sing-box --output cat -e
sudo ss -ltnp | grep ':443'
```

Ожидаемый результат:

- [ ] service active;
- [ ] listener на TCP/443 есть;
- [ ] в журнале нет критических ошибок;
- [ ] `sing-box check` проходил.

**Не считай это полной проверкой подключения** — это только проверка сервера.

**Rollback:**

```bash
sudo systemctl stop sing-box
sudo systemctl disable sing-box
```

**Вердикт:** [ ] PASS / [ ] FAIL

## Итог серверной настройки

На VPS должно быть:

- Ubuntu 24.04 LTS;
- отдельный sudo-пользователь;
- SSH без root/пароля;
- UFW с OpenSSH и TCP/443;
- sing-box;
- VLESS + Reality inbound на TCP/443;
- root-only секреты в `/root/reality-setup/secrets.env`;
- валидный `/etc/sing-box/config.json`;
- работающий systemd-сервис.

Переходи к [`04-client-setup.md`](./04-client-setup.md) для создания клиентского профиля.
