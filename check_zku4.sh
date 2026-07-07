#!/bin/bash
# check_zku4.sh - Мониторинг процессов и состояния устройства (ЗКУ.4)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zku4.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКУ.4" "Мониторинг процессов и состояния устройства"
check_zku4
finish_measure
