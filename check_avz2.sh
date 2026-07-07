#!/bin/bash
# check_avz2.sh - Антивирусная защита электронной почты (АВЗ.2)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_avz2.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "АВЗ.2" "Антивирусная защита электронной почты"
check_avz2
finish_measure
