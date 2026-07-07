#!/bin/bash
# check_sov1.sh - Обнаружение и предотвращение вторжений на периметре (СОВ.1)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_sov1.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "СОВ.1" "Обнаружение и предотвращение вторжений на периметре"
check_sov1
finish_measure
