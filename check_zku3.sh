#!/bin/bash
# check_zku3.sh - Антивирусная защита и обнаружение/предотвращение вторжений (ЗКУ.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zku3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗКУ.3" "Антивирусная защита и обнаружение/предотвращение вторжений"
check_zku3
finish_measure
