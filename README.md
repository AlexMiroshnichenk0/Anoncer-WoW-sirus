# Anoncer-WoW-sirus

Аддон для WoW 3.3.5a (Sirus), который анонсирует начало каста враждебных заклинаний.

## Установка

1. Скопируйте папку `SirusHarmfulCastAnnouncer` в `World of Warcraft\Interface\AddOns`.
2. Запустите игру и включите аддон на экране выбора персонажа.

## Что делает аддон

- Слушает `COMBAT_LOG_EVENT_UNFILTERED` и реагирует на `SPELL_CAST_START`.
- Анонсирует в чат враждебные касты (по умолчанию канал выбирается автоматически: `RAID` → `PARTY` → `SAY`).
- Показывает предупреждение в центре экрана через `RaidWarningFrame`.
- Проигрывает звуковой сигнал при обнаружении враждебного каста.
- Имеет антиспам по одинаковым кастам.
- Добавляет небольшое окно настроек в `Esc -> Interface -> AddOns -> Sirus Harmful Cast Announcer`.

## Команды

- `/shca on` — включить.
- `/shca off` — выключить.
- `/shca rw on|off` — включить/выключить центральное предупреждение.
- `/shca sound on|off` — включить/выключить звуковой сигнал.
- `/shca soundfile <путь>` — задать путь к звуку (например `Sound\Interface\RaidWarning.ogg`).
- `/shca channel auto|say|party|raid` — выбрать канал анонса.
- `/shca throttle <секунды>` — интервал антиспама.
- `/shca config` — открыть окно настроек.
- `/shca status` — показать текущие настройки.
