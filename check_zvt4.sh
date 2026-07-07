#!/bin/bash
# check_zvt4.sh - Регистрация событий безопасности в веб-приложениях и реагирование на них (ЗВТ.4)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zvt4.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗВТ.4" "Регистрация событий безопасности в веб-приложениях и реагирование на них"
check_zvt4
finish_measure
