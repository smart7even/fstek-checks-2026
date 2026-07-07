#!/bin/bash
# check_zbd5.sh - Ограничение уровней сигналов беспроводного доступа (ЗБД.5)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zbd5.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗБД.5" "Ограничение уровней сигналов беспроводного доступа"
check_zbd5
finish_measure
