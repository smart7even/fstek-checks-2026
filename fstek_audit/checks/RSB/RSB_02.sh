#!/usr/bin/env bash
# fstek_audit/checks/RSB/RSB_02.sh - migrated measure logic for РСБ.2.

run_check() {
    # check_rsb2.sh - РСБ.2 Анализ событий и реагирование

    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # Унифицированные функции вывода

    # РСБ.2.1 – Агенты анализа (HIDS/SIEM)
    AGENT_FOUND=false
    AGENT_NAME=""
    for agent in wazuh-agent ossec-hids-agent splunkd filebeat logstash; do
        if systemctl is-active --quiet "$agent" 2>/dev/null; then
            AGENT_FOUND=true
            AGENT_NAME="$agent"
            break
        fi
    done

    ANALYSIS_CONFIG_FOUND=false
    if grep -RIEq "rule|decoder|correlation|alert|sigma|threshold|frequency|if_sid|search|detection" /var/ossec/etc /etc/wazuh* /etc/ossec* /etc/filebeat /etc/auditbeat /etc/logstash /opt/splunk/etc 2>/dev/null; then
        ANALYSIS_CONFIG_FOUND=true
    fi

    if $AGENT_FOUND && $ANALYSIS_CONFIG_FOUND; then
        check_pass "РСБ.2.1" "Обнаружен агент и правила/настройки анализа событий безопасности ($AGENT_NAME)"
    elif $AGENT_FOUND; then
        check_fail "РСБ.2.1" "Обнаружен агент $AGENT_NAME, но не подтверждены правила/настройки анализа событий безопасности"
    elif fstek_component_expected siem; then
        check_fail "РСБ.2.1" "Профиль требует SIEM/HIDS-анализ, но локальный агент и правила анализа не найдены"
    else
        check_skip "РСБ.2.1" "Агенты HIDS/SIEM не найдены (возможен ручной анализ или сетевой SIEM)"
    fi

    # РСБ.2.2 – Организационная мера
    check_skip "РСБ.2.2" "Наличие регламента периодического анализа (Требует ручной проверки)"
    check_skip "РСБ.2.2a" "Порядок реагирования на признаки компьютерных атак и инциденты подтверждается регламентом и журналами реагирования"

    if fstek_enhancement_enabled "РСБ.2" "1"; then
        # РСБ.2.3 (Усиление 1, 2) – Корреляция и IDS
        if systemctl is-active --quiet suricata 2>/dev/null || \
           systemctl is-active --quiet snort 2>/dev/null || \
           [ -d /var/ossec/etc/rules ] || \
           [ -d /etc/filebeat ]; then
            check_pass "РСБ.2.3" "Обнаружены средства корреляции, IDS или настроенные правила SIEM"
        else
            check_fail "РСБ.2.3" "Средства автоматической корреляции и IDS не обнаружены"
        fi
    else
        # Унифицированный вывод для отключенных усилений (как в check_iaf1.sh)
        skip_enhancement "РСБ.2.3"
    fi

    # Унифицированная итоговая строка
    finish_legacy_measure "РСБ.2"
}
