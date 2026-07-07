#!/bin/bash
# check_zoo3.sh - Мониторинг состояния сервисов и интерфейсов (ЗОО.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zoo3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗОО.3" "Мониторинг состояния сервисов и интерфейсов"
check_zoo3
finish_measure
