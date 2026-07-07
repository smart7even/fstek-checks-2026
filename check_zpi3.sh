#!/bin/bash
# check_zpi3.sh - Проверка на соответствие спецификации API (ЗПИ.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zpi3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗПИ.3" "Проверка на соответствие спецификации API"
check_zpi3
finish_measure
