#!/bin/bash
# check_zmu6.sh - Контроль приложений мобильных устройств (ЗМУ.6)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zmu6.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗМУ.6" "Контроль приложений мобильных устройств"
check_zmu6
finish_measure
