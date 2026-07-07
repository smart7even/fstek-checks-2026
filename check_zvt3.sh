#!/bin/bash
# check_zvt3.sh - Контроль и фильтрация трафика веб-приложений (ЗВТ.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zvt3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗВТ.3" "Контроль и фильтрация трафика веб-приложений"
check_zvt3
finish_measure
