#!/bin/bash
# Lab fleet runner: loads .env.local + inventory.lab.conf, then fleet_check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.local"
INVENTORY="$SCRIPT_DIR/fstek_audit/config/inventory.lab.conf"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a
else
    echo "Подсказка: скопируйте .env.local.example → .env.local и укажите FSTEK_SSH_KEY." >&2
fi

if [ ! -r "$INVENTORY" ]; then
    echo "Ошибка: не найден $INVENTORY" >&2
    echo "Скопируйте fstek_audit/config/inventory.lab.example.conf → inventory.lab.conf" >&2
    exit 2
fi

if [ -z "${FSTEK_SSH_KEY:-}" ]; then
    echo "Ошибка: задайте FSTEK_SSH_KEY в .env.local" >&2
    exit 2
fi
if [ ! -r "$FSTEK_SSH_KEY" ]; then
    echo "Ошибка: ключ не найден или недоступен: $FSTEK_SSH_KEY" >&2
    exit 2
fi

exec "$SCRIPT_DIR/fleet_check.sh" --inventory "$INVENTORY" "$@"
