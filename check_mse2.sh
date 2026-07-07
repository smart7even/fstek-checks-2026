#!/bin/bash
# check_mse2.sh - Организация демилитаризованной зоны (МСЭ.2)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_mse2.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "МСЭ.2" "Организация демилитаризованной зоны"
check_mse2
finish_measure
