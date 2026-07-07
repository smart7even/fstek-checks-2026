#!/bin/bash
# check_mse3.sh - Контроль сетевого доступа и фильтрация трафика (МСЭ.3)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_mse3.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "МСЭ.3" "Контроль сетевого доступа и фильтрация трафика"
check_mse3
finish_measure
