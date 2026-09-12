# 5. Проверка готовой схемы

## Архитектура для проверки

```text
локальные Claude Code и Codex -> клиент подключения с TUN -> VLESS + Reality -> sing-box на VPS -> интернет
```

## Принцип

Это **read-only диагностический прогон**. Не исправляй конфигурацию, не обновляй пакеты, не перезапускай службы и не меняй firewall без отдельного разрешения.

Сначала собери доказательства, затем поставь вердикт.

## Входные данные

```text
VPS_HOSTING_NAME=[название хостинга]
VPS_PLAN_NAME=[название тарифа]
VPS_COUNTRY=[ожидаемая страна]
VPS_CITY=[ожидаемый город]
VPS_PUBLIC_IPV4=[публичный IPv4]
VPS_SSH_USER=[sudo-пользователь]
VPS_SSH_PORT=[22]
LOCAL_SSH_PRIVATE_KEY_PATH=[локальный путь, не содержимое]
SFM_APP_VERSION=[версия]
SFM_PROFILE_NAME=[имя профиля]
LOCAL_DEMO_PROJECT_PATH=[безопасная demo-папка]
TEST_NETWORK_1=[домашний Wi-Fi]
TEST_NETWORK_2=[мобильный hotspot или НЕТ]
```

## Правила работы с секретами

Не проси и не печатай:

- UUID;
- Reality private/public keys;
- short_id;
- содержимое profile JSON;
- QR или URI;
- токены Claude/Codex;
- файлы авторизации;
- полные логи.

Реальный IP можно использовать для машинного сравнения, но в итоговом отчёте и публичных командах его необходимо замаскировать.

## Тест 1. Baseline на локальном устройстве (Stop в клиенте)

Зафиксируй:

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep '^ip='
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep '^loc='
curl -I https://example.com
nslookup example.com
pwd
git rev-parse --show-toplevel 2>/dev/null || echo "not in git"
which claude
which codex
```

Запиши:

```text
BASELINE_IP=[замаскированный]
BASELINE_COUNTRY=[страна]
BASELINE_HTTPS=[OK / FAIL]
BASELINE_DNS=[OK / FAIL]
LOCAL_PWD=[путь]
LOCAL_GIT_ROOT=[путь или none]
LOCAL_CLAUDE_PATH=[путь]
LOCAL_CODEX_PATH=[путь]
```

## Тест 2. Static checks на VPS

По SSH:

```bash
ssh [VPS_SSH_USER]@[VPS_PUBLIC_IPV4]
```

На сервере:

```bash
sing-box version
sudo sing-box check -c /etc/sing-box/config.json
sudo systemctl is-active sing-box
sudo journalctl -u sing-box --output cat -e | tail -n 20
sudo ss -ltnp | grep ':443'
sudo ufw status verbose
which node 2>/dev/null || echo "node not installed"
which claude 2>/dev/null || echo "claude not installed"
which codex 2>/dev/null || echo "codex not installed"
ls -la /var/www 2>/dev/null || echo "no /var/www"
```

Проверь:

- [ ] sing-box установлен;
- [ ] `sing-box check` проходит;
- [ ] service active;
- [ ] listener TCP/443 есть;
- [ ] UFW разрешает OpenSSH и TCP/443;
- [ ] на VPS нет Claude Code, Codex, Node.js, project directories.

## Тест 3. Client start gate

Вручную:

1. Открой SFM.
2. Нажми **Stop**, если активен другой профиль.
3. Выбери нужный Local profile.
4. Нажми **Play**.

После этого проверь:

```bash
ifconfig | grep -i utun
# или на Linux:
ip link show | grep -i tun
```

И в Journal SFM проверь:

- [ ] запустился ли Network Extension;
- [ ] появился ли utun/tun-интерфейс;
- [ ] нет ли `fatal`;
- [ ] нет ли `parse error`;
- [ ] нет ли `authentication failed`;
- [ ] нет ли `TLS mismatch`;
- [ ] выбран правильный профиль.

Показывай только безопасные строки журнала.

## Тест 4. End-to-end route

При включённом профиле:

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep '^ip='
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep '^loc='
curl -I https://example.com
nslookup example.com
```

Проверь:

- [ ] внешний IP совпадает с `VPS_PUBLIC_IPV4`;
- [ ] страна соответствует `VPS_COUNTRY`;
- [ ] обычный HTTPS-сайт открывается;
- [ ] DNS работает;
- [ ] маршрут до публичного адреса идёт через utun/tun;
- [ ] локальная сеть продолжает работать;
- [ ] private IP не отправляются через VPS.

Открытый TCP/443 и active service не считать достаточным доказательством.

## Тест 5. Проверки в браузере

Открой в браузере при включённом профиле:

- `https://browserleaks.com/dns`
- `https://browserleaks.com/webrtc`

Проверь:

- [ ] нет ли неожиданного DNS-маршрута;
- [ ] не показывается ли нежелательный публичный адрес;
- [ ] совпадает ли наблюдаемая страна с `VPS_COUNTRY`.

Не объявляй эти пункты PASS, пока не подтвердишь результат визуально. Не публикуй полный IP или список DNS-серверов.

## Тест 6. Проверка локальных агентов

В `LOCAL_DEMO_PROJECT_PATH`:

```bash
cd [LOCAL_DEMO_PROJECT_PATH]
pwd
git rev-parse --show-toplevel
which claude
which codex
```

Запусти Claude Code и дай read-only задачу прочитать demo README. Запусти Codex и дай такую же задачу.

Проверь:

- [ ] оба агента читают локальные demo-файлы;
- [ ] на VPS нет проекта и агентов (проверено в тесте 2).

Не выполняй повторный login. Не показывай auth-файлы, токены, реальные проекты или клиентские данные.

## Тест 7. Stop и проверка отката

В клиенте нажми **Stop**.

Снова проверь:

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep '^ip='
curl -I https://example.com
nslookup example.com
```

Проверь:

- [ ] IP вернулся к baseline;
- [ ] обычный маршрут восстановлен;
- [ ] DNS работает;
- [ ] локальная сеть работает;
- [ ] интернет продолжает работать;
- [ ] Claude Code и Codex остаются локальными.

Не включай **Always On**, пока не проверены Play, Stop, DNS и внешний IP.

## Тест 8. Вторая сеть

Повтори ключевые проверки через `TEST_NETWORK_2`:

- запуск SFM;
- внешний IP;
- страна;
- DNS;
- HTTPS;
- Stop.

Если вторая сеть недоступна, поставь `MANUAL_PENDING`, а не `PASS`.

## Формат отчёта

### 1. Общий вердикт

- **GREEN** — сервер, клиент, end-to-end маршрут, DNS, локальные агенты и Stop доказаны.
- **YELLOW** — основная схема работает, но остались ручные или сетевые проверки.
- **RED** — профиль не стартует, IP не совпадает, DNS не работает, есть ошибки Reality/TLS/authentication либо Stop не восстанавливает маршрут.

**Критерий GREEN:**

1. Живое подключение SFM.
2. Совпадение внешнего IP с VPS.
3. Рабочий DNS и HTTPS.
4. Локальный запуск Claude Code и Codex.
5. Доказательство, что проект остаётся на локальном устройстве.
6. Успешный возврат маршрута после Stop.

### 2. Таблица проверок

| Тест | Ожидаемый результат | Фактический результат | PASS / FAIL / MANUAL_PENDING | Безопасное доказательство |
|---|---|---|---|---|
| Baseline IP | Отличается от VPS |  |  |  |
| Static checks | sing-box active, 443 слушает, нет node/claude/codex |  |  |  |
| Client start | Профиль Play, utun/tun появился, нет fatal |  |  |  |
| End-to-end route | IP = VPS, страна = VPS_COUNTRY |  |  |  |
| Browser DNS/WebRTC | Страна совпадает, нет утечек |  |  |  |
| Local agents | claude/codex локально читают demo |  |  |  |
| Stop rollback | IP вернулся к baseline |  |  |  |
| Second network | Повторены ключевые проверки |  |  |  |

### 3. Первая точка отказа

Назови только самую раннюю подтверждённую проблему. Не перечисляй десять возможных причин без доказательств.

### 4. Следующее одно действие

Одно минимальное действие для диагностики. Ничего не исправляй автоматически.

### 5. Что можно показать в публичной записи

- версия sing-box;
- `sing-box check` PASS;
- active service;
- замаскированный listener TCP/443;
- страна до и после;
- безопасная строка SFM Journal;
- локальный pwd в demo-папке;
- локальные пути claude и codex;
- успешная read-only задача;
- возврат маршрута после Stop.

### 6. Что обязательно скрыть

- полный IP;
- UUID;
- private/public Reality keys;
- short_id;
- server config;
- profile JSON;
- QR;
- URI;
- токены;
- auth-файлы;
- полные логи;
- реальные домашние пути;
- названия клиентских проектов.

## Промпт 3: Проверить готовую схему

```text
Ты - независимый проверяющий. Проведи read-only тест готовой схемы:
локальные Claude Code и Codex -> клиент подключения с TUN -> VLESS + Reality -> sing-box на VPS -> интернет.

Это диагностический прогон.
Не исправляй конфигурацию, не обновляй пакеты, не перезапускай службы и не меняй firewall без отдельного разрешения.
Сначала собери доказательства, затем поставь вердикт.

ВХОДНЫЕ ДАННЫЕ
VPS_HOSTING_NAME=[НАЗВАНИЕ_ХОСТИНГА]
VPS_PLAN_NAME=[НАЗВАНИЕ_ТАРИФА]
VPS_COUNTRY=[ОЖИДАЕМАЯ_СТРАНА]
VPS_CITY=[ОЖИДАЕМЫЙ_ГОРОД]
VPS_PUBLIC_IPV4=[ПУБЛИЧНЫЙ_IPV4]
VPS_SSH_USER=[SUDO_ПОЛЬЗОВАТЕЛЬ]
VPS_SSH_PORT=[22]
LOCAL_SSH_PRIVATE_KEY_PATH=[ЛОКАЛЬНЫЙ_ПУТЬ, НЕ СОДЕРЖИМОЕ]
SFM_APP_VERSION=[ВЕРСИЯ]
SFM_PROFILE_NAME=[ИМЯ_ПРОФИЛЯ]
LOCAL_DEMO_PROJECT_PATH=[БЕЗОПАСНАЯ_DEMO_ПАПКА]
TEST_NETWORK_1=[ДОМАШНИЙ_WIFI]
TEST_NETWORK_2=[МОБИЛЬНЫЙ_HOTSPOT_ИЛИ_НЕТ]

ПРАВИЛА РАБОТЫ С СЕКРЕТАМИ
Не проси и не печатай:
- UUID;
- Reality private/public keys;
- short_id;
- содержимое profile JSON;
- QR или URI;
- токены Claude/Codex;
- файлы авторизации;
- полные логи.

Реальный IP можно использовать для машинного сравнения, но в итоговом отчёте и публичных командах его необходимо замаскировать.

ТЕСТ-ПЛАН

1. BASELINE НА ЛОКАЛЬНОМ УСТРОЙСТВЕ ПРИ STOP В КЛИЕНТЕ
Зафиксировать:
- внешний IP;
- страну;
- работоспособность обычного HTTPS;
- работоспособность DNS;
- локальный pwd;
- локальный Git root;
- локальный путь команды claude;
- локальный путь команды codex.

Полный IP в отчёте не показывать.

2. STATIC CHECKS НА VPS
По SSH проверить:
- установленную версию sing-box;
- результат sing-box check для активного server config;
- systemctl is-active sing-box;
- последние безопасные строки Journal;
- listener на TCP/443;
- правила UFW для OpenSSH и TCP/443;
- отсутствие Claude Code, Codex, Node.js и project directories на VPS.

Ничего не перезапускать и не исправлять.

3. CLIENT START GATE
Попросить пользователя вручную:
1. Открыть SFM.
2. Нажать Stop, если активен другой профиль.
3. Выбрать нужный Local profile.
4. Нажать Play.

После этого проверить:
- запустился ли Network Extension;
- появился ли utun-интерфейс;
- нет ли в Journal SFM ошибок fatal;
- нет ли parse error;
- нет ли authentication error;
- нет ли Reality/TLS error;
- какой профиль фактически выбран.

Показывать только безопасные строки журнала.

4. END-TO-END ROUTE
Проверить:
- внешний IP после Play совпадает с VPS_PUBLIC_IPV4;
- страна соответствует VPS_COUNTRY;
- обычный HTTPS-сайт открывается;
- DNS работает;
- маршрут до публичного адреса идёт через utun-интерфейс клиента;
- локальная сеть продолжает работать;
- private IP не отправляются через VPS.

Открытый TCP/443 и active service не считать достаточным доказательством.

5. ПРОВЕРКИ В БРАУЗЕРЕ
Дай пользователю ручной чек-лист для:
- browserleaks.com/dns;
- browserleaks.com/webrtc.

Проверить:
- нет ли неожиданного DNS-маршрута;
- не показывается ли нежелательный публичный адрес;
- совпадает ли наблюдаемая страна с VPS_COUNTRY.

Не объявлять эти пункты PASS, пока пользователь не подтвердил результат.
Не публиковать полный IP или список DNS-серверов.

6. ПРОВЕРКА ЛОКАЛЬНЫХ АГЕНТОВ
В LOCAL_DEMO_PROJECT_PATH:
- показать локальный pwd;
- показать локальный Git root;
- подтвердить локальный путь команды claude;
- подтвердить локальный путь команды codex;
- запустить Claude Code;
- дать Claude Code read-only задачу прочитать demo README;
- запустить Codex;
- дать Codex такую же read-only задачу;
- подтвердить, что оба агента читают локальные файлы;
- подтвердить, что на VPS нет проекта и агентов.

Не выполнять повторный login.
Не показывать auth-файлы, токены, реальные проекты или клиентские данные.

7. STOP И ПРОВЕРКА ОТКАТА
Попросить пользователя нажать Stop в SFM.
После Stop проверить:
- внешний IP вернулся к baseline;
- обычный маршрут восстановлен;
- DNS работает;
- локальная сеть работает;
- интернет продолжает работать;
- Claude Code и Codex остаются установленными и локальными.

8. ВТОРАЯ СЕТЬ
Повторить ключевые проверки через TEST_NETWORK_2:
- запуск SFM;
- внешний IP;
- страна;
- DNS;
- HTTPS;
- Stop.

Если вторая сеть недоступна, поставить MANUAL_PENDING, а не PASS.

ФОРМАТ ОТЧЁТА

1. ОБЩИЙ ВЕРДИКТ
GREEN - сервер, клиент, end-to-end маршрут, DNS, локальные агенты и Stop доказаны.
YELLOW - основная схема работает, но остались ручные или сетевые проверки.
RED - профиль не стартует, IP не совпадает, DNS не работает, есть ошибки Reality/TLS/authentication либо Stop не восстанавливает маршрут.

2. ТАБЛИЦА ПРОВЕРОК
Колонки:
| Тест | Ожидаемый результат | Фактический результат | PASS / FAIL / MANUAL_PENDING | Безопасное доказательство |

3. ПЕРВАЯ ТОЧКА ОТКАЗА
Назови только самую раннюю подтверждённую проблему. Не перечисляй десять возможных причин без доказательств.

4. СЛЕДУЮЩЕЕ ОДНО ДЕЙСТВИЕ
Дай один минимальный следующий шаг для диагностики. Ничего автоматически не исправляй.

5. ЧТО МОЖНО ПОКАЗАТЬ В ПУБЛИЧНОЙ ЗАПИСИ
Составь список sanitized-доказательств:
- версия sing-box;
- sing-box check PASS;
- active service;
- замаскированный listener TCP/443;
- страна до и после;
- безопасная строка SFM Journal;
- локальный pwd в demo-папке;
- локальные пути claude и codex;
- успешная read-only задача;
- возврат маршрута после Stop.

6. ЧТО ОБЯЗАТЕЛЬНО СКРЫТЬ
- полный IP;
- UUID;
- private/public Reality keys;
- short_id;
- server config;
- profile JSON;
- QR;
- URI;
- токены;
- auth-файлы;
- полные логи;
- реальные домашние пути;
- названия клиентских проектов.
```

Если вердикт GREEN — можно включать Always On. Если YELLOW или RED — переходи к [`06-troubleshooting.md`](./06-troubleshooting.md).
