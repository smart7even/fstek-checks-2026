#!/bin/bash
# check_zku2.sh - Обеспечение целостности ПО конечного устройства (ЗКУ.2)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zku2.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКУ.2" "Обеспечение целостности ПО конечного устройства"
check_zku2
finish_measure
