#!/bin/bash
# check_zvt5.sh - Проверка файлов, передаваемых веб-приложениями, на вредоносное ПО (ЗВТ.5)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zvt5.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗВТ.5" "Проверка файлов, передаваемых веб-приложениями, на вредоносное ПО"
check_zvt5
finish_measure
