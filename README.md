# Реализация VPS.md: личный прокси на sing-box

Эта папка содержит рабочие артефакты по руководству `VPS.md`: шаблоны входных данных, runbook'и, готовые промпты, чек-листы и инструкции по troubleshooting.

## Архитектура

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

**Главный инвариант:** на VPS работает только sing-box и системные компоненты. Claude Code, Codex, Node.js, браузер, Git-проекты, токены и файлы авторизации остаются строго локально.

## Файлы

| Файл | Этап | Назначение |
|---|---|---|
| [`01-requirements.md`](./01-requirements.md) | Подготовка | Выбор страны под карту, заполняемый шаблон входных данных, Промпт 1 для сравнения VPS. |
| [`02-purchase-checklist.md`](./02-purchase-checklist.md) | Покупка | Чек-лист перед покупкой, генерация SSH-ключа, сохранение критичных полей. |
| [`03-server-setup.md`](./03-server-setup.md) | Настройка сервера | Server setup runbook: preflight, safety, SSH hardening, firewall, sing-box, Reality, secrets, config, service. |
| [`04-client-setup.md`](./04-client-setup.md) | Настройка клиента | Шаблон клиентского JSON, инструкция импорта в SFM, совместимость SFM 1.13.14. |
| [`05-verification.md`](./05-verification.md) | Проверка | End-to-end verification runbook, Промпт 3, PASS/FAIL таблица, sanitized-отчёт. |
| [`06-troubleshooting.md`](./06-troubleshooting.md) | Поддержка | Таблица проблем/решений, rollback-процедуры, управление секретами. |
| [`PLAN.md`](./PLAN.md) | План | План реализации, по которому созданы эти артефакты. |

## Quick start

1. Открой [`01-requirements.md`](./01-requirements.md) и заполни шаблон входных данных.
2. Используй **Промпт 1** из `01-requirements.md`, чтобы сравнить VPS-провайдеров.
3. Купи VPS, сгенерируй SSH-ключ, заполни критичные поля в `02-purchase-checklist.md`.
4. Следуй [`03-server-setup.md`](./03-server-setup.md) для настройки сервера.
5. Создай клиентский профиль по [`04-client-setup.md`](./04-client-setup.md).
6. Проверь всё end-to-end по [`05-verification.md`](./05-verification.md).
7. Если что-то не работает — [`06-troubleshooting.md`](./06-troubleshooting.md).

## Что я не могу сделать за тебя

- Купить VPS или провести оплату.
- Подключиться к твоему реальному серверу без предоставленных SSH-доступа и IP.
- Сгенерировать реальные секреты и вывести их в чат.

Поэтому эти артефакты — это пошаговая инструкция, которую ты выполняешь на своём устройстве и в панели хостинга.

## Безопасность

- Не публикуй IP, UUID, Reality keys, short_id, JSON-профиль, QR, URI, токены, полные логи, домашние пути.
- Никогда не включай `insecure: true`.
- Права на файлы с секретами и профилем — `600`.
- После импорта удали временные копии профиля.

## Источники для сверки

- [Anthropic Transparency Hub](https://www.anthropic.com/transparency/system-trust-reporting)
- [sing-box TLS / Reality fields](https://github.com/SagerNet/sing-box/blob/testing/docs/configuration/shared/tls.md)
- [sing-box VLESS outbound](https://www.singbox.ai/wiki/configuration/outbound/vless/)
- [sing-box for Apple platforms / SFM](https://sing-box.sagernet.org/clients/apple/)

---

Исходник: [`VPS.md`](./VPS.md)

<!-- watcher restart test -->
