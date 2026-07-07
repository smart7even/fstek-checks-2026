#!/bin/bash
# check_zmu8.sh - Определение и контроль геопозиции мобильных устройств (ЗМУ.8)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zmu8.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗМУ.8" "Определение и контроль геопозиции мобильных устройств"
check_zmu8
finish_measure
