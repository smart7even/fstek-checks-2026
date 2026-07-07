#!/bin/bash
# check_avz3.sh - Антивирусная проверка сетевого трафика (АВЗ.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_avz3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "АВЗ.3" "Антивирусная проверка сетевого трафика"
check_avz3
finish_measure
