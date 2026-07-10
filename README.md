# fstek-checks-2026

Bash-комплект для практической автоматизированной технической классификации части мер защиты информации по методическому документу ФСТЭК России от 12.04.2026 на Linux-системах.

Цель проекта - ответить на операционный вопрос: по локальным Linux-свидетельствам это похоже настроено правильно или нет? Это не юридическая аттестация и не итоговый вывод о полном соответствии ФСТЭК/FSTEC. Скрипты дают технический verdict по тому, что можно разумно проверить с самого узла.

Методический документ включен в репозиторий: `docs/fstek-methodology-2026.pdf`.

Структура проекта:

- основной запускатель: `check_all.sh`;
- audit-engine: `fstek_audit/`;
- режим усилений по классу защищенности: `--class K1|K2|K3`;
- режим всех усилений: `--with-enhancements` или `-e`;
- скрипты только читают состояние ОС и конфигурационные файлы.

## Audit-engine layout

```text
check_all.sh
fstek_audit/
├── run.sh
├── core/
├── adapters/
├── checks/
├── config/
├── output/
├── tests/
└── docs/
```

Общие helper-функции живут в `fstek_audit/core/`. Реализации мер — в
`fstek_audit/checks/<GROUP>/<CODE>.sh`. Единый реестр мер:
`fstek_audit/checks/manifest.tsv`.

Документы по структуре:

- `docs/architecture.md` — audit-engine и fleet pipeline;
- `docs/fleet_inventory.md` — inventory, SSH, SFTP, CSV;
- `docs/testing_lab.md` — lab на Mac + Ubuntu VM;
- `docs/statuses.md`;
- `docs/manual_controls.md`.

Для одиночной меры используйте `check_all.sh --measure <CODE>`.
Manifest-driven registry поддерживает фильтры `--list`, `--measure`, `--section`
и `--class`.

## Поддерживаемые ОС

- Astra Linux Special Edition 1.7
- Astra Linux Special Edition 1.8
- ALT Linux
- RED OS

ОС определяется по `/etc/os-release` с учетом полей `ID`, `ID_LIKE`, `NAME`, `PRETTY_NAME` и `VERSION_ID`.

## Запуск

### Один хост (локально на Linux)

Проверки читают конфигурацию ОС; для полного доступа к системным файлам обычно нужен `sudo`:

```bash
cd /path/to/fstek-checks-2026
sudo ./check_all.sh
sudo ./check_all.sh --list
sudo ./check_all.sh --class K1
sudo ./check_all.sh --section IAF
sudo ./check_all.sh --measure ИАФ.3
sudo ./check_all.sh --class K2
sudo ./check_all.sh --class K3
sudo ./check_all.sh --with-enhancements
```

Одиночная проверка:

```bash
sudo ./check_all.sh --measure ЗКС.1
sudo ./check_all.sh --measure ЗКС.1 --class K2
sudo ./check_all.sh --measure ЗКС.1 --with-enhancements
```

Класс можно указать как `--class K1`, `--class=K1`, `--security-class K1`, `-c K1` или коротко `--k1`/`--k2`/`--k3`.
Кириллическая `К` также принимается.

При запуске `check_all.sh` с `--class` сначала выполняется фильтрация мер: запускаются только модули, у которых в приложении N 2 для выбранного класса указан знак `+`. Внутри выбранных модулей выполняются только те усиления, которые указаны для этого класса цифрами или буквами в таблицах `Реализация в информационной системе` методического документа. Классы не суммируются: `K1` означает только колонку `K1`, а не `K1 + K2 + K3`.

Старый флаг `--with-enhancements` оставлен для совместимости и включает все реализованные проверки усилений без фильтрации мер и усилений по классу.

### Отчёт на одном хосте (log + JSON)

Чтобы сохранить артефакты сканирования в каталог (для CI, архива или fleet-сбора):

```bash
sudo ./check_all.sh --class K3 \
  --output-dir ./fstek_audit/output/host \
  --batch-id scan-2026-07-10
```

В каталоге появятся:

- `<hostname>-<timestamp>.log` — полный вывод проверок;
- `<hostname>-<timestamp>.json` — сводка формата `fstek-audit-summary/v1`.

### Fleet: проверка парка Linux-хостов по SSH

Fleet-режим запускает `check_all.sh` на удалённых VM с **контроллера** (Mac или Linux), автоматически доставляет bundle на цели, собирает артефакты и строит сводные CSV.

Точка входа:

```bash
./fleet_check.sh --inventory fstek_audit/config/inventory.example.conf --class K3 --batch-id prod-2026-07-10
```

Что делает один прогон:

1. **Ping + SSH** — доступность каждого хоста из inventory;
2. **Auto-deploy** — `rsync` локального репозитория на VM в `FSTEK_REMOTE_REPO` (по умолчанию включён);
3. **Remote scan** — `sudo -n ./check_all.sh` на цели;
4. **Сбор артефактов** — log/JSON скачиваются на контроллер;
5. **Агрегация** — `fleet-measures.csv` и `fleet-measure-rollups.csv`;
6. **SFTP upload** (опционально) — весь batch в центральный inbox.

Результат на контроллере:

```text
fstek_audit/output/fleet/<batch-id>/
  fleet-summary.csv           # статус по каждому хосту
  fleet-measures.csv          # все меры × все хосты
  fleet-measure-rollups.csv   # сводка FAIL/PASS/SKIP по мерам
  vm1.example.com/
    fleet-host.log
    <hostname>-<timestamp>.log
    <hostname>-<timestamp>.json
```

#### Подготовка inventory

Скопируйте шаблон и отредактируйте список хостов:

```bash
cp fstek_audit/config/inventory.example.conf my-inventory.conf
```

Формат строки хоста:

```text
hostname|ip|user|port|remote_repo|ssh_key|password_env
```

Обязательны `hostname` и `ip`; остальные поля берутся из глобальных переменных inventory-файла (`FSTEK_SSH_USER`, `FSTEK_REMOTE_REPO`, `FSTEK_SSH_KEY` и т.д.).

Подробнее: `docs/fleet_inventory.md`.

#### Требования на целевых VM

- SSH-доступ с контроллера (ключ или пароль через env);
- **passwordless sudo** для `./check_all.sh` после auto-deploy (или запуск от root);
- для auto-deploy — каталог `FSTEK_REMOTE_REPO` (по умолчанию `/opt/fstek-checks-2026`) и права на запись через `sudo rsync`.

Пароль SSH **не хранится** в inventory — экспортируйте переменную окружения перед запуском:

```bash
export FSTEK_SSH_PASSWORD='...'
./fleet_check.sh --inventory my-inventory.conf --class K3 --batch-id run1
```

#### Полезные флаги fleet

| Флаг | Назначение |
|---|---|
| `--class K1\|K2\|K3` | Класс защищённости для всего парка |
| `--batch-id <id>` | Идентификатор прогона (имя каталога артефактов) |
| `--output-dir <dir>` | Корень вывода (по умолчанию `fstek_audit/output/fleet`) |
| `--parallel N` | Параллелизм; `0` = все хосты сразу (по умолчанию) |
| `--no-deploy` | Не rsync-ить bundle — использовать уже разложенный на VM |
| `--no-sftp` | Не загружать batch по SFTP |

#### SFTP upload (опционально)

В inventory или отдельном конфиге (`fstek_audit/config/sftp.example.conf`):

```bash
FSTEK_SFTP_ENABLED=true
FSTEK_SFTP_HOST=sftp.example.com
FSTEK_SFTP_USER=fstek
FSTEK_SFTP_REMOTE_DIR=/var/inbox/fstek-fleet
FSTEK_SFTP_AUTH=key   # auto | key | password
FSTEK_KEEP_LOCAL=true # не удалять локальный batch после upload
```

На сервере batch распаковывается в `<remote_dir>/<batch-id>/`.

### Lab: Mac-контроллер → одна VM (быстрый старт)

Для отладки fleet на Yandex Cloud / любой Ubuntu-VM есть готовый lab-скрипт:

```bash
cp .env.local.example .env.local
cp fstek_audit/config/inventory.lab.example.conf fstek_audit/config/inventory.lab.conf
# отредактируйте IP в inventory.lab.conf и путь к SSH-ключу в .env.local

chmod +x fleet_lab.sh
./fleet_lab.sh --class K3 --batch-id lab1
```

На VM один раз:

```bash
mkdir -p ~/fstek-fleet-inbox
echo 'bob ALL=(ALL) NOPASSWD: /opt/fstek-checks-2026/check_all.sh' | sudo tee /etc/sudoers.d/fstek-lab
sudo chmod 440 /etc/sudoers.d/fstek-lab
```

Файлы `.env.local` и `inventory.lab.conf` в `.gitignore` — секреты не попадают в git.

Пошаговая инструкция: `docs/testing_lab.md`.

## Вывод и модель классификации

Используются статусы:

- `PASS (HIGH)` - есть прямое локальное свидетельство из конфигурации, службы, политики, правила, таймера, пакета или другого технического источника;
- `PASS (MEDIUM)` - зрелая практическая эвристика, которая покрывает большинство реальных Linux-инсталляций, но не является исчерпывающим доказательством;
- `FAIL` - ожидаемое локальное свидетельство отсутствует, отключено, небезопасно, противоречиво или настроено неверно;
- `SKIP` - локальный Linux-узел не дает достаточно свидетельств для классификации: нужны документы, исходный код, IdP/MDM/SIEM/СЗИ-консоль, сетевая схема, договоры, физическая проверка или регламент;
- `INFO` - слабый/низкоуверенный сигнал, контекстное наблюдение, рекомендация или недецизивное свидетельство;
- `NA` - компонент или стек на узле не обнаружен, и мера не применима к этому хосту.

Для локально проверяемых контролей проект предпочитает бинарный технический verdict `PASS` или `FAIL`, но только при уверенности уровня `HIGH` или `MEDIUM`. `PASS (MEDIUM)` остается практическим автоматизированным verdict, но не является юридическим подтверждением соответствия. Низкоуверенные признаки намеренно выводятся как `INFO`, а не как `PASS` или `FAIL`, чтобы не создавать ложного ощущения выполненной меры.

В интерактивном терминале статусы подсвечиваются цветом: `PASS` зеленым, `FAIL` красным, `SKIP` желтым. Цвет можно отключить через `NO_COLOR=1` или `FSTEK_COLOR=never`, а принудительно включить через `FSTEK_COLOR=always`.

Итог `check_all.sh` выводит:

- общий результат `ОК`/`НЕ ОК`;
- число выполненных технических проверок;
- число успешных проверок, отдельно `PASS HIGH` и `PASS MEDIUM`;
- число неуспешных проверок;
- процент невыполненных проверок;
- меры и параметры с `FAIL`;
- параметры `SKIP`;
- параметры `INFO`;
- параметры `NA`.

## Профиль ожиданий

По умолчанию отсутствующий необязательный стек дает `NA`: например, если на сервере нет libvirt, Docker/Podman, почты, веб/API или Wi-Fi, соответствующие стековые проверки не считаются `FAIL`.

Если оператор ожидает наличие компонента именно на этом хосте, можно добавить профиль:

- `./fstek_profile.conf`;
- `/etc/fstek-checks/profile.conf`.

Поддерживаемые ключи:

```bash
FSTEK_EXPECT_WEB=true
FSTEK_EXPECT_API=true
FSTEK_EXPECT_CONTAINERS=true
FSTEK_EXPECT_VIRTUALIZATION=true
FSTEK_EXPECT_MAIL=true
FSTEK_EXPECT_WIRELESS=true
FSTEK_EXPECT_SIEM=true
FSTEK_EXPECT_AV=true
FSTEK_EXPECT_AV_PRODUCT=clamav   # clamav, kaspersky/kesl, drweb
```

Если профиль требует компонент, а локальные признаки отсутствуют, проверка возвращает `FAIL`.

## Состав

В комплект входят уже подготовленные меры `ИАФ`, `УПД`, `РСБ`, `ЗСВ`, `ЗКО`, `ЗЭП` из примера и добавленные меры:

- `ЗВТ.1`-`ЗВТ.5`;
- `ЗПИ.1`-`ЗПИ.3`;
- `ЗКУ.1`-`ЗКУ.6`;
- `ЗМУ.1`-`ЗМУ.9`;
- `ЗИВ.1`-`ЗИВ.5`;
- `ЗБД.1`-`ЗБД.6`;
- `АВЗ.1`-`АВЗ.4`;
- `СОВ.1`-`СОВ.2`;
- `МСЭ.1`-`МСЭ.5`;
- `ЗОО.1`-`ЗОО.6`;
- `ЗКС.1`-`ЗКС.4`.

## Ограничения

Скрипты проверяют только то, что можно получить с самого Linux-узла штатными средствами: файлы конфигурации, службы, журналы, PAM, firewall, audit, SSH, сетевые параметры, признаки WAF/IDS/AV/SIEM/MDM/IoT/Wi-Fi.

`FAIL` используется, когда локальная конфигурация должна быть проверяема, но нужных свидетельств нет. `NA` используется, когда стек отсутствует и профиль не требует его на данном хосте. `SKIP` используется только когда сама природа контроля требует внешних свидетельств. `INFO` не влияет на код выхода и итоговые PASS/FAIL-счетчики.

Параметры, зависящие от утвержденных документов, сетевой архитектуры, внешних СЗИ, облачных сервисов, исходного кода приложения, IdP, MDM-консоли или фактических процедур персонала, намеренно помечаются как ручные.

Мероприятия из раздела III методического документа, а также организационные блоки физической защиты, непрерывности функционирования, повышения знаний пользователей, взаимодействия с подрядчиками и применения ИИ не считаются подтвержденными этими shell-проверками. Для них нужен отдельный чек-лист по документам, приказам, договорам, журналам работ и фактическим процедурам.

## Для Codex-агентов

В репозитории есть локальные инструкции:

- `AGENTS.md` - краткие правила работы над проектом;
- `.codex/skills/fstek-methodology/SKILL.md` - repo-local skill для задач по сверке скриптов с методичкой.

## Важно

Проект не изменяет настройки системы. Скрипты предназначены для технической классификации и инвентаризации признаков реализации мер. Они не заменяют экспертную оценку, анализ документации и проверку фактической реализации организационных мер.

## Проверка разработки

```bash
bash tests/syntax.sh
bash tests/smoke.sh
bash tests/registry_consistency.sh
bash tests/aggregate.sh
bash tests/fleet_inventory.sh
```

`tests/syntax.sh` выполняет `bash -n` для всех shell-скриптов. Smoke-тест
проверяет полноту class mapping, запускает все меры из manifest через
`check_all.sh --measure <CODE> --class K3` и `check_all.sh --class K1/K2/K3`,
а также `--output-dir` и fleet inventory parsing.
`tests/registry_consistency.sh` проверяет, что manifest и measure files
согласованы. `tests/aggregate.sh` — парсинг fleet CSV из fixture-логов.
`tests/fleet_inventory.sh` — разбор inventory и SSH auth policy.
Тесты безопасны и только читают локальное состояние.
