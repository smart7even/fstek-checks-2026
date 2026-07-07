#!/bin/bash
# check_zbd6.sh - Регистрация, анализ и реагирование на события беспроводного доступа (ЗБД.6)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zbd6.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗБД.6" "Регистрация, анализ и реагирование на события беспроводного доступа"
check_zbd6
finish_measure
