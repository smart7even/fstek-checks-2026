#!/bin/bash
# check_zoo6.sh - Поддержка резерва пропускной способности и ресурсов (ЗОО.6)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zoo6.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗОО.6" "Поддержка резерва пропускной способности и ресурсов"
check_zoo6
finish_measure
