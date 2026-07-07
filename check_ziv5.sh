#!/bin/bash
# check_ziv5.sh - Регистрация, анализ и реагирование на события безопасности IoT (ЗИВ.5)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_ziv5.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗИВ.5" "Регистрация, анализ и реагирование на события безопасности IoT"
check_ziv5
finish_measure
