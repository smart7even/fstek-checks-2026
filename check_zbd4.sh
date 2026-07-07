#!/bin/bash
# check_zbd4.sh - Контроль целостности точек беспроводного доступа (ЗБД.4)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zbd4.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗБД.4" "Контроль целостности точек беспроводного доступа"
check_zbd4
finish_measure
