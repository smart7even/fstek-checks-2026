#!/bin/bash
# check_zmu1.sh - Идентификация и аутентификация пользователей мобильных устройств (ЗМУ.1)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zmu1.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗМУ.1" "Идентификация и аутентификация пользователей мобильных устройств"
check_zmu1
finish_measure
