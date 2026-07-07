#!/bin/bash
# check_zpi2.sh - Управление доступом пользователей и приложений API (ЗПИ.2)
# Соответствие разделу 4 Методического документа ФСТЭК России от 12.04.2026.
# ОС: Astra Linux SE 1.7/1.8, ALT Linux, RED OS.
# Запуск: ./check_zpi2.sh [--with-enhancements|-e]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"

init_measure "ЗПИ.2" "Управление доступом пользователей и приложений API"
check_zpi2
finish_measure
