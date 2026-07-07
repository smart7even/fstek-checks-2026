#!/bin/bash
# check_zmu7.sh - Ограничение и контроль функциональности мобильных устройств (ЗМУ.7)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zmu7.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗМУ.7" "Ограничение и контроль функциональности мобильных устройств"
check_zmu7
finish_measure
