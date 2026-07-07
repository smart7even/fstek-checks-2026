#!/bin/bash
# check_zku6.sh - Анализ и реагирование на события безопасности (ЗКУ.6)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zku6.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКУ.6" "Анализ и реагирование на события безопасности"
check_zku6
finish_measure
