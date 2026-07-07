#!/bin/bash
# check_zku5.sh - Контроль и фильтрация трафика на конечном устройстве (ЗКУ.5)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zku5.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКУ.5" "Контроль и фильтрация трафика на конечном устройстве"
check_zku5
finish_measure
