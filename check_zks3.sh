#!/bin/bash
# check_zks3.sh - Контроль доступа к внешним ресурсам (ЗКС.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zks3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКС.3" "Контроль доступа к внешним ресурсам"
check_zks3
finish_measure
