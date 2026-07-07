#!/bin/bash
# check_avz4.sh - Замкнутая среда предварительного анализа файлов (АВЗ.4)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_avz4.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "АВЗ.4" "Замкнутая среда предварительного анализа файлов"
check_avz4
finish_measure
