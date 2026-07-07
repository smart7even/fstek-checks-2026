#!/bin/bash
# check_zmu9.sh - Регистрация, анализ и реагирование на события безопасности мобильных устройств (ЗМУ.9)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zmu9.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗМУ.9" "Регистрация, анализ и реагирование на события безопасности мобильных устройств"
check_zmu9
finish_measure
