#!/bin/bash
# check_zbd2.sh - Управление доступом к беспроводной сети (ЗБД.2)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zbd2.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗБД.2" "Управление доступом к беспроводной сети"
check_zbd2
finish_measure
