#!/bin/bash
# check_zoo1.sh - Защита от атак, направленных на отказ в обслуживании (ЗОО.1)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zoo1.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗОО.1" "Защита от атак, направленных на отказ в обслуживании"
check_zoo1
finish_measure
