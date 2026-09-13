# 4. Клиентский профиль и импорт

## Входные данные

Заполни перед созданием профиля:

```text
VPS_PUBLIC_IPV4=[публичный IPv4]
REALITY_HANDSHAKE_HOST=[например www.microsoft.com]
UUID=[из /root/reality-setup/secrets.env]
REALITY_PUBLIC_KEY=[из /root/reality-setup/secrets.env]
SHORT_ID=[из /root/reality-setup/secrets.env]
LOCAL_PROFILE_OUTPUT_PATH=F:\Server_VPS\paris-reality.json
LOCAL_PROFILE_NAME=paris-vless-reality
```

## Логика клиентского профиля

- TUN inbound;
- `auto_route: true`;
- DNS направляется через туннель;
- private IP и локальная сеть идут через direct;
- final route идёт через VLESS outbound;
- `server` — публичный IPv4 VPS;
- `server_port` — 443;
- `uuid` совпадает с сервером;
- `flow` — `xtls-rprx-vision`;
- TLS enabled;
- `server_name` совпадает с `REALITY_HANDSHAKE_HOST`;
- uTLS fingerprint — `chrome`;
- Reality enabled;
- используется Reality public key;
- `short_id` совпадает с сервером.

## Шаблон клиентского JSON

Сохрани локально по пути `LOCAL_PROFILE_OUTPUT_PATH`:

```json
{
  "log": { "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "tag": "remote", "address": "tls://1.1.1.1", "detour": "proxy" },
      { "tag": "local", "address": "tls://8.8.8.8", "detour": "direct" }
    ],
    "rules": [
      { "rule_set": ["geosite-cn"], "server": "local" }
    ],
    "final": "remote"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": false,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "__VPS_PUBLIC_IPV4__",
      "server_port": 443,
      "uuid": "__UUID__",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "__REALITY_HANDSHAKE_HOST__",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": {
          "enabled": true,
          "public_key": "__REALITY_PUBLIC_KEY__",
          "short_id": "__SHORT_ID__"
        }
      }
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      { "ip_is_private": true, "outbound": "direct" },
      { "rule_set": ["geoip-private", "geosite-private"], "outbound": "direct" }
    ],
    "final": "proxy"
  },
  "experimental": {
    "cache_file": { "enabled": true }
  }
}
```

Замени плейсхолдеры:

- `__VPS_PUBLIC_IPV4__` — реальный публичный IP сервера.
- `__UUID__` — UUID из серверного конфига.
- `__REALITY_HANDSHAKE_HOST__` — handshake host.
- `__REALITY_PUBLIC_KEY__` — public key из keypair.
- `__SHORT_ID__` — short_id.

## Совместимость с SFM 1.13.14

Для SFM 1.13.14:

- не добавляй `dns_mode`;
- не используй Linux-only `auto_redirect`;
- не используй `insecure: true`;
- не добавляй `strict_route` без доказанной необходимости;
- не используй Linux/Android-only поля.

Перед импортом проверь клиентский JSON совместимой версией sing-box:

```bash
sing-box check -c [LOCAL_PROFILE_OUTPUT_PATH]
```

## Проверь файл

Установи права:

```bash
chmod 600 [LOCAL_PROFILE_OUTPUT_PATH]
```

Убедись, что:

- [ ] файл лежит локально;
- [ ] права `600`;
- [ ] профиль не в папке проекта;
- [ ] профиль не в мессенджере или облаке.

## Импорт в SFM

1. Открой SFM.
2. Панель → `+` → **Import from File**.
3. Выбери JSON.
4. **Type Local**.
5. **Create**.
6. Останови старый профиль, если активен.
7. Выбери новый профиль.
8. Нажми **Play**.
9. Не включай **Always On** до полного тестирования.
10. Если система просит Network Extension — разреши.

## Безопасность профиля

Профиль — это ключ от твоего сервера. Правила:

- не публикуй профиль;
- не коммить в Git;
- не вставляй содержимое в чат;
- не создавай QR или URI;
- не показывай JSON в публичной записи экрана;
- после импорта удали временные копии;
- храни секреты только в root-only файлах на сервере и в защищённом локальном хранилище.

## Перенос на другую Windows-машину

Если нужно настроить sing-box GUI на другом компьютере:

1. Безопасно перенеси `F:\Server_VPS\paris-reality.json` (зашифрованная флешка, менеджер паролей, локальная сеть).
2. Не используй мессенджеры, почту, облако, QR/URI.
3. Установи sing-box GUI для Windows: https://sing-box.sagernet.org/clients/windows/
4. Запусти от имени администратора.
5. **Profiles → Import →** выбери `paris-reality.json`.
6. Выбери профиль `paris-vless-reality`, нажми **Play**.
7. Разреши установку TUN/Network Adapter.
8. В PowerShell проверь:
   ```powershell
   curl -s https://www.cloudflare.com/cdn-cgi/trace | Select-String '^ip='
   curl -s https://www.cloudflare.com/cdn-cgi/trace | Select-String '^loc='
   ```
   Ожидаемо: `ip=138.124.92.11`, `loc=FR`.

## После импорта

Переходи к [`05-verification.md`](./05-verification.md) для end-to-end проверки.
