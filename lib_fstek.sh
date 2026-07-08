#!/bin/bash
# lib_fstek.sh - общие функции для проверок мер ФСТЭК 2026.
# Скрипты только читают конфигурацию и состояние ОС.

WITH_ENHANCEMENTS=false
FSTEK_SECURITY_CLASS=""

fstek_normalize_security_class() {
    case "$1" in
        k1|K1|к1|К1) printf 'K1' ;;
        k2|K2|к2|К2) printf 'K2' ;;
        k3|K3|к3|К3) printf 'K3' ;;
        *) return 1 ;;
    esac
}

fstek_set_security_class() {
    local class
    class="$(fstek_normalize_security_class "$1")" || {
        echo "Ошибка: неизвестный класс защищенности '$1'. Используйте K1, K2 или K3." >&2
        exit 2
    }
    FSTEK_SECURITY_CLASS="$class"
    WITH_ENHANCEMENTS=true
}

fstek_parse_cli() {
    local arg
    while [ "$#" -gt 0 ]; do
        arg="$1"
        case "$arg" in
            --with-enhancements|-e)
                WITH_ENHANCEMENTS=true
                ;;
            --class|--security-class|-c)
                shift
                [ "$#" -gt 0 ] || {
                    echo "Ошибка: для $arg нужно указать K1, K2 или K3." >&2
                    exit 2
                }
                fstek_set_security_class "$1"
                ;;
            --class=*|--security-class=*)
                fstek_set_security_class "${arg#*=}"
                ;;
            --k1|--K1|--к1|--К1)
                fstek_set_security_class "K1"
                ;;
            --k2|--K2|--к2|--К2)
                fstek_set_security_class "K2"
                ;;
            --k3|--K3|--к3|--К3)
                fstek_set_security_class "K3"
                ;;
        esac
        shift
    done
}

fstek_parse_cli "$@"

FAIL_COUNT=0
SKIP_COUNT=0
PASS_COUNT=0

fstek_required_enhancements() {
    case "$1:$2" in
        ИАФ.1:K2|ИАФ.1:K1) printf '1' ;;
        ИАФ.3:K1) printf '1' ;;
        УПД.1:K2|УПД.1:K1) printf '1 2' ;;
        УПД.2:K2) printf '1' ;;
        УПД.2:K1) printf '1 2' ;;
        УПД.3:K2) printf '1' ;;
        УПД.3:K1) printf '1 2' ;;
        УПД.4:K2|УПД.4:K1) printf '1 2' ;;
        УПД.7:K1) printf '1a 1а' ;;
        РСБ.1:K3) printf '1' ;;
        РСБ.1:K2) printf '1 2' ;;
        РСБ.1:K1) printf '1 2 3' ;;
        ЗСВ.1:K2) printf '1' ;;
        ЗСВ.1:K1) printf '1 2' ;;
        ЗСВ.2:K2|ЗСВ.2:K1) printf '1 2' ;;
        ЗСВ.6:K1) printf '1' ;;
        ЗКО.1:K2) printf '1 2' ;;
        ЗКО.1:K1) printf '1 2 3 4 5 6' ;;
        ЗКО.5:K2|ЗКО.5:K1) printf '1' ;;
        ЗКО.8:K2|ЗКО.8:K1) printf '1 2' ;;
        ЗЭП.4:K2|ЗЭП.4:K1) printf '1' ;;
        ЗВТ.2:K2|ЗВТ.2:K1) printf '1' ;;
        ЗВТ.3:K1) printf '1' ;;
        ЗПИ.1:K2|ЗПИ.1:K1) printf '1' ;;
        ЗПИ.3:K1) printf '1' ;;
        ЗКУ.3:K2|ЗКУ.3:K1) printf '1' ;;
        ЗКУ.6:K2|ЗКУ.6:K1) printf '1' ;;
        ЗМУ.1:K2|ЗМУ.1:K1) printf '1' ;;
        ЗМУ.3:K2) printf '1' ;;
        ЗМУ.3:K1) printf '1 2' ;;
        ЗМУ.4:K1) printf '1' ;;
        ЗМУ.9:K2|ЗМУ.9:K1) printf '1' ;;
        ЗИВ.3:K2|ЗИВ.3:K1) printf '1' ;;
        ЗИВ.5:K2|ЗИВ.5:K1) printf '1' ;;
        ЗБД.1:K1) printf '1' ;;
        ЗБД.6:K2|ЗБД.6:K1) printf '1' ;;
        СОВ.1:K2|СОВ.1:K1) printf '1' ;;
        МСЭ.1:K1) printf '1' ;;
        ЗОО.2:K1) printf '1' ;;
        *) printf '' ;;
    esac
}

fstek_measure_classes() {
    case "$1" in
        ИАФ.1|ИАФ.3|\
        УПД.1|УПД.2|УПД.3|УПД.4|УПД.8|УПД.9|\
        РСБ.1|РСБ.2|РСБ.3|РСБ.4|РСБ.5|\
        ЗСВ.1|ЗСВ.2|ЗСВ.3|ЗСВ.4|ЗСВ.5|ЗСВ.6|ЗСВ.7|ЗСВ.8|\
        ЗКО.1|ЗКО.2|ЗКО.3|ЗКО.4|ЗКО.5|ЗКО.6|ЗКО.7|ЗКО.8|\
        ЗЭП.1|ЗЭП.2|ЗЭП.3|ЗЭП.4|ЗЭП.5|ЗЭП.6|\
        ЗВТ.1|ЗВТ.2|ЗВТ.3|ЗВТ.4|ЗВТ.5|\
        ЗПИ.1|ЗПИ.2|ЗПИ.3|\
        ЗКУ.1|ЗКУ.2|ЗКУ.3|ЗКУ.4|ЗКУ.6|\
        ЗМУ.1|ЗМУ.2|ЗМУ.3|ЗМУ.4|ЗМУ.5|ЗМУ.6|ЗМУ.7|ЗМУ.9|\
        ЗИВ.1|ЗИВ.2|ЗИВ.3|ЗИВ.4|ЗИВ.5|\
        ЗБД.1|ЗБД.2|ЗБД.3|ЗБД.4|ЗБД.5|ЗБД.6|\
        АВЗ.1|АВЗ.2|АВЗ.3|\
        СОВ.1|СОВ.2|\
        МСЭ.1|МСЭ.2|МСЭ.3|\
        ЗОО.1|ЗОО.2|ЗОО.3|ЗОО.5|\
        ЗКС.1|ЗКС.2|ЗКС.3)
            printf 'K3 K2 K1'
            ;;
        УПД.7|ЗСВ.9|ЗОО.6)
            printf 'K2 K1'
            ;;
        *)
            printf ''
            ;;
    esac
}

fstek_measure_enabled() {
    local measure="$1" class="$2" enabled
    enabled="$(fstek_measure_classes "$measure")"
    [ -n "$enabled" ] || return 1
    for class in $enabled; do
        [ "$class" = "$2" ] && return 0
    done
    return 1
}

fstek_measure_code_from_script() {
    local script base prefix number code_prefix
    script="${1##*/}"
    base="${script#check_}"
    base="${base%.sh}"
    prefix="${base%%[0-9]*}"
    number="${base#$prefix}"

    case "$prefix" in
        iaf) code_prefix="ИАФ" ;;
        upd) code_prefix="УПД" ;;
        rsb) code_prefix="РСБ" ;;
        zsv) code_prefix="ЗСВ" ;;
        zko) code_prefix="ЗКО" ;;
        zep) code_prefix="ЗЭП" ;;
        zvt) code_prefix="ЗВТ" ;;
        zpi) code_prefix="ЗПИ" ;;
        zku) code_prefix="ЗКУ" ;;
        zmu) code_prefix="ЗМУ" ;;
        ziv) code_prefix="ЗИВ" ;;
        zbd) code_prefix="ЗБД" ;;
        avz) code_prefix="АВЗ" ;;
        sov) code_prefix="СОВ" ;;
        mse) code_prefix="МСЭ" ;;
        zoo) code_prefix="ЗОО" ;;
        zks) code_prefix="ЗКС" ;;
        *) return 1 ;;
    esac

    [ -n "$number" ] || return 1
    printf '%s.%s' "$code_prefix" "$number"
}

fstek_enhancement_enabled() {
    local measure="$1" required id want
    shift
    $WITH_ENHANCEMENTS || return 1
    [ -n "$FSTEK_SECURITY_CLASS" ] || return 0
    required="$(fstek_required_enhancements "$measure" "$FSTEK_SECURITY_CLASS")"
    [ -n "$required" ] || return 1
    for want in "$@"; do
        [ "$want" = "1а" ] && want="1a"
        for id in $required; do
            [ "$id" = "1а" ] && id="1a"
            [ "$id" = "$want" ] && return 0
        done
    done
    return 1
}

fstek_color_enabled() {
    case "${FSTEK_COLOR:-auto}" in
        always|yes|true|1) return 0 ;;
        never|no|false|0) return 1 ;;
    esac
    [ -n "${NO_COLOR:-}" ] && return 1
    [ -t 1 ]
}

fstek_init_colors() {
    if fstek_color_enabled; then
        FSTEK_C_PASS=$'\033[32m'
        FSTEK_C_FAIL=$'\033[31m'
        FSTEK_C_SKIP=$'\033[33m'
        FSTEK_C_RESET=$'\033[0m'
    else
        FSTEK_C_PASS=""
        FSTEK_C_FAIL=""
        FSTEK_C_SKIP=""
        FSTEK_C_RESET=""
    fi
}

fstek_status_color() {
    case "$1" in
        PASS) printf '%s' "$FSTEK_C_PASS" ;;
        FAIL) printf '%s' "$FSTEK_C_FAIL" ;;
        SKIP) printf '%s' "$FSTEK_C_SKIP" ;;
        *) printf '' ;;
    esac
}

fstek_status_line() {
    local code="$1" status="$2" text="$3" color
    color="$(fstek_status_color "$status")"
    printf '[%s] %b%s%b – %s\n' "$code" "$color" "$status" "$FSTEK_C_RESET" "$text"
}

fstek_colorize_statuses() {
    if fstek_color_enabled; then
        sed -E \
            -e $'s/(^|[^[:alnum:]_])(PASS)([^[:alnum:]_]|$)/\\1\033[32m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(FAIL)([^[:alnum:]_]|$)/\\1\033[31m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(SKIP)([^[:alnum:]_]|$)/\\1\033[33m\\2\033[0m\\3/g'
    else
        cat
    fi
}

fstek_init_colors

check_pass() { fstek_status_line "$1" "PASS" "$2"; ((PASS_COUNT++)); return 0; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); return 0; }
check_skip() { fstek_status_line "$1" "SKIP" "$2 (НЕВОЗМОЖНО ПРОВЕРИТЬ АВТОМАТИЧЕСКИ)"; ((SKIP_COUNT++)); return 0; }
check_na() { fstek_status_line "$1" "SKIP" "$2 (НЕПРИМЕНИМО)"; ((SKIP_COUNT++)); return 0; }
skip_enhancement() {
    local reason="проверка усилений отключена"
    [ -n "$FSTEK_SECURITY_CLASS" ] && reason="усиление не требуется для класса $FSTEK_SECURITY_CLASS"
    fstek_status_line "$1" "SKIP" "$reason"
    ((SKIP_COUNT++))
    return 0
}

init_measure() {
    MEASURE_CODE="$1"
    MEASURE_TITLE="$2"
    detect_os
    echo "=== МОДУЛЬ $MEASURE_CODE: $MEASURE_TITLE ==="
    fstek_print_os_info
}

finish_measure() {
    printf '=== ИТОГ МОДУЛЯ %s: PASS=%s, FAIL=%s, SKIP=%s ===\n' "$MEASURE_CODE" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" | fstek_colorize_statuses
    [ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
}

detect_os() {
    OS_NAME="Unknown"; OS_PRETTY="Unknown"; OS_VER=""; OS_ID=""; OS_ID_LIKE=""
    OS_TYPE="generic"; OS_LABEL="Unknown"; OS_SUPPORTED=false
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${NAME:-Unknown}"
        OS_PRETTY="${PRETTY_NAME:-$OS_NAME}"
        OS_VER="${VERSION_ID:-}"
        OS_ID="${ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
    fi

    local os_match
    os_match="$(printf '%s' "$OS_ID $OS_ID_LIKE $OS_NAME $OS_PRETTY" | tr '[:upper:]' '[:lower:]')"
    OS_LABEL="${OS_PRETTY:-$OS_NAME}"

    case "$os_match" in
        *astra*|*alse*)
            case "$OS_VER" in
                1.7*) OS_TYPE="astra17"; OS_SUPPORTED=true; OS_LABEL="Astra Linux Special Edition 1.7" ;;
                1.8*) OS_TYPE="astra18"; OS_SUPPORTED=true; OS_LABEL="Astra Linux Special Edition 1.8" ;;
                *) OS_TYPE="astra"; OS_LABEL="${OS_PRETTY:-Astra Linux}" ;;
            esac
            ;;
        *redos*|*"red os"*|*red-os*|*red_os*)
            OS_TYPE="redos"
            OS_SUPPORTED=true
            OS_LABEL="${OS_PRETTY:-RED OS}"
            ;;
        *altlinux*|*"alt linux"*|*alt*)
            OS_TYPE="alt"
            OS_SUPPORTED=true
            OS_LABEL="${OS_PRETTY:-ALT Linux}"
            ;;
    esac
}

fstek_print_os_info() {
    local supported_note=""
    [ "$OS_SUPPORTED" = true ] || supported_note=" (ОС не входит в целевой список: ALSE 1.7/1.8, RED OS, ALT Linux)"
    echo "ОС: ${OS_LABEL:-Unknown}${supported_note}"
}

is_linux() { [[ "$(uname -s 2>/dev/null)" == "Linux" ]]; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
systemctl_available() { have_cmd systemctl; }

service_active() {
    local svc
    for svc in "$@"; do
        if systemctl_available && systemctl is-active --quiet "$svc" 2>/dev/null; then return 0; fi
        if have_cmd service && service "$svc" status >/dev/null 2>&1; then return 0; fi
    done
    return 1
}

service_known() {
    local svc
    for svc in "$@"; do
        if systemctl_available && systemctl list-unit-files "$svc.service" "$svc" 2>/dev/null | grep -qi "$svc"; then return 0; fi
        if [ -x "/etc/init.d/$svc" ]; then return 0; fi
    done
    return 1
}

grep_any() {
    local pattern="$1"; shift
    grep -RIEq -- "$pattern" "$@" 2>/dev/null
}

file_any() {
    local f
    for f in "$@"; do [ -e "$f" ] && return 0; done
    return 1
}

has_web_stack() {
    have_cmd nginx || have_cmd apache2 || have_cmd httpd || service_known nginx apache2 httpd || file_any /etc/nginx /etc/apache2 /etc/httpd
}

has_mail_stack() {
    have_cmd postconf || have_cmd exim || have_cmd sendmail || service_known postfix exim dovecot sendmail || file_any /etc/postfix /etc/exim /etc/dovecot
}

has_api_stack() {
    has_web_stack || service_known kong tyk-gateway envoy traefik haproxy || file_any /etc/kong /etc/tyk /etc/envoy /etc/traefik /etc/haproxy
}

has_wireless_stack() {
    file_any /etc/hostapd /etc/wpa_supplicant || service_known hostapd wpa_supplicant NetworkManager || have_cmd iw || have_cmd nmcli
}

has_iot_stack() {
    service_known mosquitto emqx vernemq node-red zigbee2mqtt coap-server || file_any /etc/mosquitto /etc/emqx /etc/vernemq /opt/zigbee2mqtt
}

has_mdm_stack() {
    service_known micromdm mdmclient anydesk-mdm || file_any /etc/mdm /opt/mdm /var/lib/mdm
}

check_firewall_active() {
    local code="$1"
    if service_active firewalld ufw nftables netfilter-persistent || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qE "table|chain|hook") || (have_cmd iptables && iptables -S 2>/dev/null | grep -q "^-A"); then
        check_pass "$code" "Обнаружены активные правила межсетевого экранирования (nftables/iptables/firewalld/ufw)"
    else
        check_fail "$code" "Не обнаружены активные правила межсетевого экранирования"
    fi
}

check_firewall_logging() {
    local code="$1"
    if (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE " log |log prefix") || (have_cmd iptables && iptables -S 2>/dev/null | grep -qiE " -j LOG|NFLOG"); then
        check_pass "$code" "В правилах фильтрации обнаружена регистрация событий"
    else
        check_fail "$code" "В правилах фильтрации не обнаружена регистрация событий"
    fi
}

check_tls_config() {
    local code="$1"
    if grep_any "ssl_certificate|SSLCertificateFile|listen[[:space:]]+443|bind .*:443|cert_file|tls" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "В конфигурации обнаружено использование TLS/сертификатов"
    else
        check_fail "$code" "Не обнаружены признаки настройки TLS для защищенной передачи данных"
    fi
}

check_strong_tls() {
    local code="$1"
    if grep_any "ssl_protocols.*TLSv1\\.2|ssl_protocols.*TLSv1\\.3|SSLProtocol.*-all.*TLSv1\\.[23]|MinProtocol.*TLSv1\\.[23]|tls_min_version" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "Обнаружены ограничения небезопасных версий TLS"
    else
        check_fail "$code" "Не обнаружены явные ограничения небезопасных версий TLS"
    fi
}

check_web_auth_or_acl() {
    local code="$1"
    if grep_any "auth_basic|auth_request|Require[[:space:]]+valid-user|Require[[:space:]]+user|allow[[:space:]]|deny[[:space:]]|satisfy|oauth|oidc|jwt|ldap" /etc/nginx /etc/apache2 /etc/httpd /etc/kong /etc/tyk /etc/envoy 2>/dev/null; then
        check_pass "$code" "В конфигурации обнаружены механизмы аутентификации или разграничения доступа"
    else
        check_fail "$code" "Не обнаружены серверные механизмы аутентификации или разграничения доступа"
    fi
}

check_web_security_headers() {
    local code="$1"
    if grep_any "Content-Security-Policy|X-Frame-Options|frame-ancestors|X-Content-Type-Options|Referrer-Policy|Strict-Transport-Security" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "Обнаружены HTTP-заголовки безопасности"
    else
        check_fail "$code" "Не обнаружены HTTP-заголовки безопасности в конфигурации"
    fi
}

check_no_cache_headers() {
    local code="$1"
    if grep_any "Cache-Control.*(no-store|no-cache|private)|Pragma.*no-cache" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "Обнаружены директивы запрета кэширования пользовательских данных"
    else
        check_fail "$code" "Не обнаружены директивы Cache-Control/Pragma для запрета кэширования"
    fi
}

check_clickjacking_headers() {
    local code="$1"
    if grep_any "X-Frame-Options|frame-ancestors" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "Обнаружена защита от подмены интерфейса (X-Frame-Options/frame-ancestors)"
    else
        check_fail "$code" "Не обнаружена защита от clickjacking"
    fi
}

check_web_logs() {
    local code="$1"
    if grep_any "access_log|error_log|CustomLog|ErrorLog|log_format|accesslog|log" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null || file_any /var/log/nginx /var/log/apache2 /var/log/httpd; then
        check_pass "$code" "Обнаружена регистрация событий веб-сервера/прокси"
    else
        check_fail "$code" "Не обнаружена настройка или каталог журналов веб-сервера"
    fi
}

check_waf() {
    local code="$1"
    if service_active nginx apache2 httpd openresty && grep_any "modsecurity|security2_module|ModSecurityEnabled|SecRule|naxsi|coraza|app_protect|waf" /etc/nginx /etc/apache2 /etc/httpd /etc/kong /etc/traefik /etc/envoy 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки WAF/фильтрации веб-трафика"
    else
        check_fail "$code" "Не обнаружены признаки WAF/фильтрации веб-трафика"
    fi
}

check_rate_limit() {
    local code="$1"
    if grep_any "limit_req|limit_conn|mod_evasive|rate.?limit|request.?rate|connlimit|hashlimit|stick-table|http-request deny" /etc/nginx /etc/apache2 /etc/httpd /etc/haproxy /etc/traefik /etc/envoy 2>/dev/null || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qi " limit rate") || (have_cmd iptables && iptables -S 2>/dev/null | grep -qiE "hashlimit|connlimit|recent|limit"); then
        check_pass "$code" "Обнаружены ограничения частоты запросов/соединений"
    else
        check_fail "$code" "Не обнаружены ограничения частоты запросов или числа соединений"
    fi
}

check_siem_forwarding() {
    local code="$1"
    if grep_any "@@|omfwd|target=|action\\(type=\"omfwd\"|remote" /etc/rsyslog.conf /etc/rsyslog.d /etc/syslog-ng 2>/dev/null || service_active wazuh-agent ossec filebeat auditbeat fluent-bit vector; then
        check_pass "$code" "Обнаружена передача событий в централизованный сбор/мониторинг"
    else
        check_fail "$code" "Не обнаружена централизованная передача событий безопасности"
    fi
}

check_fail2ban_or_reaction() {
    local code="$1"
    if service_active fail2ban crowdsec || \
       grep_any "^[^#].*(banaction|action.*ban|decision|remediation)" /etc/fail2ban /etc/crowdsec 2>/dev/null || \
       grep_any "^[^#].*(drop|reject|block|ips|nfq|af-packet).*" /etc/suricata /etc/snort /etc/zeek /var/ossec/etc 2>/dev/null || \
       grep_any "^[^#].*(SecRule|ModSecurity).*\\b(deny|block|drop)\\b" /etc/nginx /etc/apache2 /etc/httpd /etc/modsecurity 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки автоматического реагирования/блокирования"
    else
        check_fail "$code" "Не обнаружены признаки автоматического реагирования на события"
    fi
}

check_av_installed() {
    local code="$1"
    if service_active clamav-daemon clamd freshclam drwebd drweb-configd kesl kav4fs-supervisor eset cagtd || have_cmd clamscan || have_cmd clamdscan || have_cmd kesl-control || have_cmd drweb-ctl; then
        check_pass "$code" "Обнаружены установленные или активные средства антивирусной защиты"
    else
        check_fail "$code" "Не обнаружены штатные признаки антивирусной защиты"
    fi
}

check_av_updates() {
    local code="$1"
    if service_active clamav-freshclam freshclam || grep_any "Database updated|daily.cvd|main.cvd|bytecode.cvd" /var/log/clamav /var/lib/clamav 2>/dev/null || have_cmd kesl-control || have_cmd drweb-ctl; then
        check_pass "$code" "Обнаружены признаки обновления антивирусных баз"
    else
        check_fail "$code" "Не обнаружены признаки обновления антивирусных баз"
    fi
}

check_av_scheduled_scan() {
    local code="$1"
    if grep_any "clamscan|clamdscan|kesl-control|drweb-ctl" /etc/cron.d /etc/crontab /var/spool/cron /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system 2>/dev/null || (systemctl_available && systemctl list-timers --all 2>/dev/null | grep -qiE "clam|virus|av|kesl|drweb"); then
        check_pass "$code" "Обнаружены задания регулярной антивирусной проверки"
    else
        check_fail "$code" "Не обнаружены задания регулярной антивирусной проверки"
    fi
}

check_av_on_access() {
    local code="$1"
    if service_active clamonacc clamav-clamonacc drweb-spider drweb-filecheck kesl-supervisor kesl || grep_any "ScanOnAccess[[:space:]]+yes|OnAccessIncludePath|OnAccessPrevention[[:space:]]+yes|fanotify|real.?time|on.?access" /etc/clamav /etc/kaspersky /etc/opt/kaspersky /etc/drweb /etc/opt/drweb.com 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки проверки файлов в режиме, близком к реальному времени"
    else
        check_fail "$code" "Не обнаружена on-access/real-time проверка объектов из внешних источников"
    fi
}

check_ids_installed() {
    local code="$1"
    if service_active suricata snort zeek wazuh-agent ossec falco auditd || have_cmd suricata || have_cmd snort || have_cmd zeek; then
        check_pass "$code" "Обнаружены средства обнаружения/предотвращения вторжений или host-аудита"
    else
        check_fail "$code" "Не обнаружены IDS/IPS/HIDS или auditd"
    fi
}

check_ids_rules_logs() {
    local code="$1"
    if file_any /etc/suricata/rules /etc/snort/rules /opt/zeek/share/zeek/site /var/log/suricata /var/log/snort /var/log/zeek /var/ossec/logs; then
        check_pass "$code" "Обнаружены правила или журналы IDS/IPS"
    else
        check_fail "$code" "Не обнаружены правила или журналы IDS/IPS"
    fi
}

check_ids_traffic_source() {
    local code="$1"
    if grep_any "af-packet|pcap|pfring|netmap|dpdk|copy-mode|SPAN|mirror|tap" /etc/suricata /etc/snort /etc/zeek /opt/zeek/etc 2>/dev/null; then
        check_pass "$code" "Обнаружена настройка источника сетевого трафика для IDS/IPS"
    else
        check_skip "$code" "Получение копии сетевого трафика для IDS проверяется по сетевой схеме/SPAN/TAP и конфигурации сенсоров"
    fi
}

check_ids_rule_updates() {
    local code="$1"
    if grep_any "suricata-update|pulledpork|oinkmaster|rule.?update|emerging.?threats|ETOPEN|snort.*rules|wazuh.*ruleset" /etc/cron.d /etc/crontab /var/spool/cron /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system /etc/suricata /etc/snort /var/ossec/etc 2>/dev/null || (systemctl_available && systemctl list-timers --all 2>/dev/null | grep -qiE "suricata|snort|rule|wazuh"); then
        check_pass "$code" "Обнаружены признаки автоматического обновления правил/индикаторов IDS"
    else
        check_fail "$code" "Не обнаружено автоматическое обновление баз решающих правил и индикаторов атак"
    fi
}

check_ids_custom_rules() {
    local code="$1"
    if grep_any "local.rules|site.rules|custom.rules|/etc/suricata/rules/local|/etc/snort/rules/local|user.rules" /etc/suricata /etc/snort /var/ossec/etc 2>/dev/null || file_any /etc/suricata/rules/local.rules /etc/snort/rules/local.rules /var/ossec/etc/rules/local_rules.xml; then
        check_pass "$code" "Обнаружены локальные/специфичные решающие правила IDS"
    else
        check_fail "$code" "Не обнаружены локальные правила для атак, специфичных для информационной системы"
    fi
}

check_auditd() {
    local code="$1"
    if service_active auditd && file_any /etc/audit/audit.rules /etc/audit/rules.d; then
        check_pass "$code" "auditd активен, правила аудита присутствуют"
    else
        check_fail "$code" "auditd не активен или правила аудита отсутствуют"
    fi
}

check_integrity_control() {
    local code="$1"
    if service_active aidecheck aide.timer aide tripwire afick || have_cmd aide || have_cmd tripwire || have_cmd afick || grep_any "ima_appraise|security\\.ima|security\\.evm" /proc/cmdline /etc/default/grub /boot/grub/grub.cfg 2>/dev/null; then
        check_pass "$code" "Обнаружены средства контроля целостности (AIDE/Tripwire/IMA/EVM)"
    else
        check_fail "$code" "Не обнаружены средства контроля целостности"
    fi
}

check_package_integrity_possible() {
    local code="$1"
    if have_cmd rpm || have_cmd dpkg; then
        check_pass "$code" "Пакетный менеджер поддерживает проверку целостности установленных файлов"
    else
        check_fail "$code" "Не обнаружен rpm/dpkg для проверки целостности установленных файлов"
    fi
}

check_pam_auth() {
    local code="$1"
    if grep_any "pam_unix\\.so|pam_sss\\.so|pam_faillock\\.so|pam_tally2\\.so|pam_parsec\\.so" /etc/pam.d 2>/dev/null; then
        check_pass "$code" "В PAM обнаружены модули аутентификации/контроля доступа"
    else
        check_fail "$code" "В PAM не обнаружены базовые модули аутентификации"
    fi
}

check_ssh_hardening() {
    local code="$1"
    if [ -f /etc/ssh/sshd_config ] && grep -Eiq "^[[:space:]]*PermitRootLogin[[:space:]]+(no|prohibit-password)" /etc/ssh/sshd_config; then
        check_pass "$code" "SSH root-вход ограничен"
    else
        check_fail "$code" "Не подтвержден запрет или ограничение SSH root-входа"
    fi
}

check_sudo_restricted() {
    local code="$1"
    if file_any /etc/sudoers /etc/sudoers.d && ! grep -RIEq "^[^#].*ALL=\\(ALL(:ALL)?\\)[[:space:]]+NOPASSWD:[[:space:]]*ALL" /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        check_pass "$code" "Не обнаружен полный NOPASSWD-доступ sudo для активных правил"
    else
        check_fail "$code" "Обнаружен или не исключен полный NOPASSWD-доступ sudo"
    fi
}

check_process_monitoring() {
    local code="$1"
    if service_active sysstat atop psacct acct auditd node_exporter zabbix-agent telegraf collectd; then
        check_pass "$code" "Обнаружен мониторинг процессов или состояния узла"
    else
        check_fail "$code" "Не обнаружены службы мониторинга процессов/состояния"
    fi
}

check_open_listeners() {
    local code="$1"
    if have_cmd ss; then
        local count
        count=$(ss -tuln 2>/dev/null | awk 'NR>1 {print}' | wc -l | tr -d ' ')
        if [ "${count:-0}" -gt 0 ]; then
            check_pass "$code" "Список сетевых служб может быть получен штатной командой ss ($count слушающих сокетов)"
        else
            check_pass "$code" "Открытые слушающие сетевые сокеты не обнаружены"
        fi
    else
        check_skip "$code" "Команда ss отсутствует, перечень сетевых служб не получен"
    fi
}

check_openapi_spec() {
    local code="$1"
    if find /etc /opt /srv /var/www -maxdepth 5 -type f \( -iname '*openapi*.yml' -o -iname '*openapi*.yaml' -o -iname '*swagger*.json' -o -iname '*openapi*.json' \) 2>/dev/null | grep -q .; then
        check_pass "$code" "Обнаружена спецификация OpenAPI/Swagger"
    else
        check_fail "$code" "Не обнаружена спецификация OpenAPI/Swagger"
    fi
}

check_api_gateway() {
    local code="$1"
    if service_active kong tyk-gateway envoy traefik haproxy nginx || file_any /etc/kong /etc/tyk /etc/envoy /etc/traefik; then
        check_pass "$code" "Обнаружен API-шлюз или reverse proxy"
    else
        check_fail "$code" "Не обнаружен API-шлюз или reverse proxy"
    fi
}

check_api_schema_validation() {
    local code="$1"
    if grep_any "schema|openapi|swagger|request-validation|validate|json_schema|grpc_json_transcoder" /etc/kong /etc/tyk /etc/envoy /etc/traefik /etc/nginx 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки проверки запросов по спецификации/схеме"
    else
        check_fail "$code" "Не обнаружены признаки проверки API-запросов по спецификации"
    fi
}

check_hostapd_secure() {
    local code="$1"
    if grep_any "wpa=2|wpa_key_mgmt=.*(WPA-PSK|SAE|WPA-EAP)|ieee8021x=1|rsn_pairwise=.*CCMP" /etc/hostapd /etc/NetworkManager/system-connections /etc/wpa_supplicant 2>/dev/null; then
        check_pass "$code" "Обнаружены защищенные параметры WPA2/WPA3/802.1X"
    else
        check_fail "$code" "Не обнаружены защищенные параметры WPA2/WPA3/802.1X"
    fi
}

check_wireless_acl() {
    local code="$1"
    if grep_any "macaddr_acl=1|accept_mac_file|deny_mac_file|ieee8021x=1|radius_server" /etc/hostapd /etc/NetworkManager/system-connections 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки контроля доступа клиентов беспроводной сети"
    else
        check_fail "$code" "Не обнаружены признаки контроля доступа клиентов беспроводной сети"
    fi
}

check_wireless_logs() {
    local code="$1"
    if service_active hostapd NetworkManager rsyslog && file_any /var/log/hostapd.log /var/log/syslog /var/log/messages /var/log/daemon.log; then
        check_pass "$code" "Обнаружены службы и журналы для регистрации событий беспроводного доступа"
    else
        check_fail "$code" "Не обнаружены журналы/службы регистрации событий беспроводного доступа"
    fi
}

check_network_segmentation() {
    local code="$1"
    local if_count=0
    if have_cmd ip; then if_count=$(ip -o link show 2>/dev/null | grep -vc " lo:" || true); fi
    if [ "${if_count:-0}" -gt 1 ] || (have_cmd ip && ip -d link show 2>/dev/null | grep -qiE "vlan|vxlan|bridge") || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE "iifname|oifname|zone"); then
        check_pass "$code" "Обнаружены признаки сетевой сегментации (несколько интерфейсов/VLAN/правила по интерфейсам)"
    else
        check_fail "$code" "Не обнаружены признаки сетевой сегментации"
    fi
}

check_segmentation_documentation() {
    local code="$1"
    check_skip "$code" "Схема сегментации, перечень сегментов и ежегодная проверка корректности подтверждаются эксплуатационной документацией"
}

check_microsegmentation() {
    local code="$1"
    if grep_any "micro.?segment|networkpolicy|calico|cilium|ovn|openvswitch|security.?group|isolate|isolation" /etc/kubernetes /etc/cni /etc/NetworkManager /etc/netplan /etc/openvswitch /etc/libvirt /etc/docker /etc/containerd /etc/nftables.conf /etc/firewalld 2>/dev/null || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE "ct mark|meta mark|iifname.*oifname|ip saddr.*ip daddr"); then
        check_pass "$code" "Обнаружены признаки микросегментации или изолирующих политик внутри сегментов"
    else
        check_fail "$code" "Не обнаружены признаки микросегментации, требуемой усилением МСЭ.1"
    fi
}

check_dmz() {
    local code="$1"
    if grep_any "dmz" /etc/firewalld /etc/nftables.conf /etc/iptables /etc/shorewall /etc/ufw 2>/dev/null || (have_cmd firewall-cmd && firewall-cmd --get-active-zones 2>/dev/null | grep -qi dmz); then
        check_pass "$code" "Обнаружена зона/правила DMZ"
    else
        check_fail "$code" "Не обнаружены признаки выделенной DMZ"
    fi
}

check_nat_masking() {
    local code="$1"
    if (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE "masquerade|snat") || (have_cmd iptables && iptables -t nat -S 2>/dev/null | grep -qiE "MASQUERADE|SNAT") || grep_any "masquerade|snat" /etc/firewalld /etc/nftables.conf /etc/iptables 2>/dev/null; then
        check_pass "$code" "Обнаружены правила NAT/маскирования"
    else
        check_fail "$code" "Не обнаружены правила NAT/маскирования"
    fi
}

check_honeypot() {
    local code="$1"
    if service_active cowrie dionaea honeyd opencanary glastopf || file_any /etc/opencanaryd /opt/cowrie /opt/dionaea; then
        check_pass "$code" "Обнаружены признаки ложных систем/honeypot"
    else
        check_fail "$code" "Не обнаружены ложные системы/honeypot"
    fi
}

check_syn_cookies() {
    local code="$1"
    if [ -r /proc/sys/net/ipv4/tcp_syncookies ] && [ "$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null)" = "1" ]; then
        check_pass "$code" "Включена защита TCP SYN cookies"
    else
        check_fail "$code" "TCP SYN cookies не включены или недоступны для проверки"
    fi
}

check_monitoring_stack() {
    local code="$1"
    if service_active prometheus-node-exporter node_exporter zabbix-agent nagios-nrpe-server telegraf collectd netdata keepalived monit; then
        check_pass "$code" "Обнаружены службы мониторинга состояния сервисов/интерфейсов"
    else
        check_fail "$code" "Не обнаружены службы мониторинга состояния сервисов/интерфейсов"
    fi
}

check_load_balancing() {
    local code="$1"
    if service_active haproxy nginx keepalived envoy traefik || grep_any "upstream|balance|backend|server .*:[0-9]+|virtual_server|real_server" /etc/nginx /etc/haproxy /etc/keepalived /etc/envoy /etc/traefik 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки балансировки нагрузки"
    else
        check_fail "$code" "Не обнаружены признаки балансировки нагрузки"
    fi
}

check_dns_rate_limit() {
    local code="$1"
    if grep_any "rate-limit[[:space:]]*\\{|responses-per-second[[:space:]]+[1-9][0-9]*|ip-ratelimit|ratelimit|RRL|response-rate-limiting|qps-limit|fetches-per-server[[:space:]]+[1-9][0-9]*" /etc/bind /etc/named /etc/unbound /etc/knot /etc/powerdns 2>/dev/null; then
        check_pass "$code" "Обнаружены ограничения скорости DNS-ответов"
    else
        check_fail "$code" "Не обнаружены корректные ограничения скорости DNS-ответов"
    fi
}

check_vpn_or_crypto() {
    local code="$1"
    if service_active openvpn strongswan ipsec wireguard wg-quick stunnel || have_cmd wg || file_any /etc/openvpn /etc/ipsec.conf /etc/wireguard /etc/stunnel; then
        check_pass "$code" "Обнаружены VPN/криптографические средства защиты каналов"
    else
        check_fail "$code" "Не обнаружены VPN/криптографические средства защиты каналов"
    fi
}

check_egress_control() {
    local code="$1"
    if grep_any "http_access|acl|deny|allow|whitelist|blacklist|url_rewrite|ssl_bump" /etc/squid /etc/tinyproxy /etc/privoxy 2>/dev/null || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE " dport | ip daddr | reject| drop") || (have_cmd iptables && iptables -S OUTPUT 2>/dev/null | grep -qiE "REJECT|DROP|--dport|--destination"); then
        check_pass "$code" "Обнаружены признаки контроля исходящего доступа к внешним ресурсам"
    else
        check_fail "$code" "Не обнаружены признаки контроля исходящего доступа к внешним ресурсам"
    fi
}

check_proxy_categories() {
    local code="$1"
    if grep_any "squidGuard|ufdbGuard|redirector|category|blacklist|whitelist|shallalist|url_rewrite_program" /etc/squid /etc/squidguard /etc/ufdbguard 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки категоризации/морфологического контроля ресурсов"
    else
        check_fail "$code" "Не обнаружены признаки категоризации или морфологического контроля ресурсов"
    fi
}

check_dlp() {
    local code="$1"
    if service_active solar-dozor infowatch searchinform zecurion deviceLock traffic-monitor squid c-icap || grep_any "dlp|icap|content.?inspection|data.?loss|casb|ssl_bump" /etc/squid /etc/c-icap /etc/icap /etc/nginx /etc/haproxy 2>/dev/null; then
        check_pass "$code" "Обнаружены признаки DLP/ICAP/контекстной проверки исходящего трафика"
    else
        check_fail "$code" "Не обнаружены признаки контекстной проверки исходящего трафика"
    fi
}

check_zvt1() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_tls_config "$MEASURE_CODE.1"
    check_web_auth_or_acl "$MEASURE_CODE.2"
    check_firewall_active "$MEASURE_CODE.3"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1" "2" "3" "4"; then
        check_no_cache_headers "$MEASURE_CODE.4"
        check_skip "$MEASURE_CODE.5" "Автозаполнение HTML-форм достоверно проверяется только по исходному коду веб-приложения"
        check_web_security_headers "$MEASURE_CODE.6"
        check_clickjacking_headers "$MEASURE_CODE.7"
    else
        skip_enhancement "$MEASURE_CODE.4"; skip_enhancement "$MEASURE_CODE.5"; skip_enhancement "$MEASURE_CODE.6"; skip_enhancement "$MEASURE_CODE.7"
    fi
}

check_zvt2() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_web_auth_or_acl "$MEASURE_CODE.1"
    check_fail2ban_or_reaction "$MEASURE_CODE.2"
    check_rate_limit "$MEASURE_CODE.3"
    check_skip "$MEASURE_CODE.4" "Проверка прав при каждом запросе определяется логикой приложения и требует анализа кода/настроек приложения"
    check_skip "$MEASURE_CODE.5" "Исключение client-side-only аутентификации требует анализа приложения"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_skip "$MEASURE_CODE.6" "MFA привилегированных веб-пользователей проверяется в IdP/приложении"; else skip_enhancement "$MEASURE_CODE.6"; fi
}

check_zvt3() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_waf "$MEASURE_CODE.1"
    check_rate_limit "$MEASURE_CODE.2"
    check_skip "$MEASURE_CODE.3" "Полнота сигнатур SQL/XSS/команд и проверка чувствительных данных в запросах требует анализа WAF-политик"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then
        check_waf "$MEASURE_CODE.4"
    else
        skip_enhancement "$MEASURE_CODE.4"
    fi
    if fstek_enhancement_enabled "$MEASURE_CODE" "2"; then
        check_api_schema_validation "$MEASURE_CODE.5"
    else
        skip_enhancement "$MEASURE_CODE.5"
    fi
}

check_zvt4() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_web_logs "$MEASURE_CODE.1"
    check_firewall_logging "$MEASURE_CODE.2"
    check_siem_forwarding "$MEASURE_CODE.3"
    check_fail2ban_or_reaction "$MEASURE_CODE.4"
}

check_zvt5() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_av_installed "$MEASURE_CODE.1"
    if grep_any "clamd|clamav|icap|virus|antivirus" /etc/nginx /etc/apache2 /etc/httpd /etc/squid /etc/c-icap 2>/dev/null; then
        check_pass "$MEASURE_CODE.2" "Обнаружена интеграция веб/прокси с антивирусной проверкой"
    else
        check_fail "$MEASURE_CODE.2" "Не обнаружена интеграция веб-приложения с антивирусной проверкой файлов"
    fi
    check_av_updates "$MEASURE_CODE.3"
}

check_zpi1() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_tls_config "$MEASURE_CODE.1"
    check_strong_tls "$MEASURE_CODE.2"
    check_api_gateway "$MEASURE_CODE.3"
    check_web_logs "$MEASURE_CODE.4"
}

check_zpi2() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_web_auth_or_acl "$MEASURE_CODE.1"
    check_rate_limit "$MEASURE_CODE.2"
    check_skip "$MEASURE_CODE.3" "Разграничение прав приложений и пользователей требует проверки IdP/API-приложения"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_skip "$MEASURE_CODE.4" "MFA/API access policy проверяется в IdP/API-шлюзе"; else skip_enhancement "$MEASURE_CODE.4"; fi
}

check_zpi3() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_openapi_spec "$MEASURE_CODE.1"
    check_api_schema_validation "$MEASURE_CODE.2"
    check_waf "$MEASURE_CODE.3"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_rate_limit "$MEASURE_CODE.4"; else skip_enhancement "$MEASURE_CODE.4"; fi
}

check_zku1() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_pam_auth "$MEASURE_CODE.1"; check_ssh_hardening "$MEASURE_CODE.2"; check_sudo_restricted "$MEASURE_CODE.3"; }
check_zku2() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_integrity_control "$MEASURE_CODE.1"; check_package_integrity_possible "$MEASURE_CODE.2"; check_skip "$MEASURE_CODE.3" "Эталонные контрольные суммы и утвержденный перечень ПО задаются оператором"; }
check_zku3() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_av_installed "$MEASURE_CODE.1"; check_av_updates "$MEASURE_CODE.2"; check_ids_installed "$MEASURE_CODE.3"; }
check_zku4() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_process_monitoring "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_monitoring_stack "$MEASURE_CODE.3"; }
check_zku5() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_firewall_active "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; }
check_zku6() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_auditd "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; check_fail2ban_or_reaction "$MEASURE_CODE.3"; }

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}
check_zmu1() { check_zmu_common || return; check_pam_auth "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Параметры мобильной аутентификации проверяются в MDM"; }
check_zmu2() { check_zmu_common || return; check_web_auth_or_acl "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Политики доступа мобильных устройств проверяются в MDM"; }
check_zmu3() { check_zmu_common || return; check_integrity_control "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Контроль root/jailbreak и целостности мобильной ОС проверяется средствами MDM"; }
check_zmu4() { check_zmu_common || return; check_tls_config "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Шифрование данных на мобильном устройстве проверяется в MDM"; }
check_zmu5() { check_zmu_common || return; check_av_installed "$MEASURE_CODE.1"; }
check_zmu6() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Белые/черные списки мобильных приложений проверяются в MDM"; }
check_zmu7() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Ограничения камер, Bluetooth, NFC, USB и иных функций проверяются в MDM"; }
check_zmu8() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Геопозиция мобильных устройств проверяется в MDM и требует согласованных политик"; }
check_zmu9() { check_zmu_common || return; check_siem_forwarding "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Состав мобильных событий безопасности проверяется в MDM"; }

check_ziv_common() {
    has_iot_stack || { check_na "$MEASURE_CODE" "IoT-шлюз/платформа на данной Linux-системе не обнаружены"; return 1; }
    return 0
}
check_ziv1() { check_ziv_common || return; check_tls_config "$MEASURE_CODE.1"; check_web_auth_or_acl "$MEASURE_CODE.2"; }
check_ziv2() { check_ziv_common || return; check_firewall_active "$MEASURE_CODE.1"; check_web_auth_or_acl "$MEASURE_CODE.2"; }
check_ziv3() { check_ziv_common || return; check_tls_config "$MEASURE_CODE.1"; check_strong_tls "$MEASURE_CODE.2"; }
check_ziv4() { check_ziv_common || return; check_integrity_control "$MEASURE_CODE.1"; check_package_integrity_possible "$MEASURE_CODE.2"; }
check_ziv5() { check_ziv_common || return; check_web_logs "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; check_fail2ban_or_reaction "$MEASURE_CODE.3"; }

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}
check_zbd1() { check_zbd_common || return; check_hostapd_secure "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Уникальность учетных данных пользователей Wi-Fi проверяется по RADIUS/IdP"; }
check_zbd2() { check_zbd_common || return; check_wireless_acl "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; }
check_zbd3() { check_zbd_common || return; check_hostapd_secure "$MEASURE_CODE.1"; check_tls_config "$MEASURE_CODE.2"; }
check_zbd4() { check_zbd_common || return; check_integrity_control "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Целостность прошивки точки доступа требует проверки средствами производителя"; }
check_zbd5() { check_zbd_common || return; if grep_any "tx_power|country_code|ieee80211d" /etc/hostapd /etc/NetworkManager/system-connections 2>/dev/null; then check_pass "$MEASURE_CODE.1" "Обнаружены параметры ограничения радиосигнала/регуляторного домена"; else check_fail "$MEASURE_CODE.1" "Не обнаружены параметры ограничения уровня сигнала"; fi; }
check_zbd6() { check_zbd_common || return; check_wireless_logs "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; }

check_avz1() { check_av_installed "$MEASURE_CODE.1"; check_av_updates "$MEASURE_CODE.2"; check_av_scheduled_scan "$MEASURE_CODE.3"; check_av_on_access "$MEASURE_CODE.4"; check_skip "$MEASURE_CODE.5" "Перечень устройств, порядок реагирования и проверка после обновления баз подтверждаются эксплуатационной документацией"; }
check_avz2() { has_mail_stack || { check_na "$MEASURE_CODE" "Почтовый сервер не обнаружен"; return; }; check_av_installed "$MEASURE_CODE.1"; if grep_any "clamav|clamd|amavis|rspamd.*antivirus|milter.*(clam|av|virus)|virus" /etc/postfix /etc/exim /etc/dovecot /etc/amavis /etc/rspamd 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружена интеграция почты с антивирусной проверкой"; else check_fail "$MEASURE_CODE.2" "Не обнаружена интеграция почты с антивирусной проверкой"; fi; }
check_avz3() { check_av_installed "$MEASURE_CODE.1"; if service_active squid c-icap havp privoxy || grep_any "icap|clamav|virus|av_" /etc/squid /etc/c-icap /etc/nginx /etc/haproxy 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружена антивирусная проверка сетевого трафика/ICAP"; else check_fail "$MEASURE_CODE.2" "Не обнаружена антивирусная проверка сетевого трафика"; fi; }
check_avz4() { if service_active cuckoo cape sandbox detonator || file_any /opt/cuckoo /opt/cape /etc/cuckoo; then check_pass "$MEASURE_CODE.1" "Обнаружена среда предварительного анализа файлов"; else check_skip "$MEASURE_CODE.1" "Замкнутая среда предварительного анализа файлов обычно реализуется отдельной песочницей/процессом"; fi; }

check_sov1() { check_ids_installed "$MEASURE_CODE.1"; check_ids_traffic_source "$MEASURE_CODE.2"; check_ids_rules_logs "$MEASURE_CODE.3"; check_fail2ban_or_reaction "$MEASURE_CODE.4"; check_ids_rule_updates "$MEASURE_CODE.5"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_ids_custom_rules "$MEASURE_CODE.6"; else skip_enhancement "$MEASURE_CODE.6"; fi; check_skip "$MEASURE_CODE.7" "Прикладной уровень, хранение фрагментов трафика, ретроанализ, песочница и репутационные базы относятся к усилениям 2-10 и проверяются по документации/конфигурации средств"; }
check_sov2() { check_ids_installed "$MEASURE_CODE.1"; check_network_segmentation "$MEASURE_CODE.2"; check_ids_rules_logs "$MEASURE_CODE.3"; check_ids_rule_updates "$MEASURE_CODE.4"; check_fail2ban_or_reaction "$MEASURE_CODE.5"; check_skip "$MEASURE_CODE.6" "Централизованное администрирование IDS в сегментах подтверждается эксплуатационной документацией и консолью управления"; }

check_mse1() { check_network_segmentation "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; check_segmentation_documentation "$MEASURE_CODE.4"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_microsegmentation "$MEASURE_CODE.5"; else skip_enhancement "$MEASURE_CODE.5"; fi; }
check_mse2() { check_dmz "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_network_segmentation "$MEASURE_CODE.3"; }
check_mse3() { check_firewall_active "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; }
check_mse4() { check_nat_masking "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Полнота маскирования топологии проверяется сетевой схемой и внешним сканированием"; }
check_mse5() { check_honeypot "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Сценарии эксплуатации ложных систем определяются оператором"; }

check_zoo1() { check_syn_cookies "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_rate_limit "$MEASURE_CODE.3"; }
check_zoo2() { check_firewall_active "$MEASURE_CODE.1"; check_rate_limit "$MEASURE_CODE.2"; check_waf "$MEASURE_CODE.3"; }
check_zoo3() { check_monitoring_stack "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_siem_forwarding "$MEASURE_CODE.3"; }
check_zoo4() { check_load_balancing "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Независимость физических каналов и провайдеров проверяется по сетевой документации"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_load_balancing "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }
check_zoo5() { check_rate_limit "$MEASURE_CODE.1"; check_dns_rate_limit "$MEASURE_CODE.2"; check_monitoring_stack "$MEASURE_CODE.3"; }
check_zoo6() { check_skip "$MEASURE_CODE.1" "Двукратный резерв полосы и ресурсов определяется по методике оператора и не выводится достоверно из ОС"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then if grep_any "xdp|dpdk|pf_ring|af_xdp" /etc /proc/cmdline 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружены признаки высокопроизводительной обработки пакетов"; else check_fail "$MEASURE_CODE.2" "Не обнаружены признаки XDP/DPDK/PF_RING"; fi; else skip_enhancement "$MEASURE_CODE.2"; fi; }

check_zks1() { check_vpn_or_crypto "$MEASURE_CODE.1"; check_tls_config "$MEASURE_CODE.2"; check_strong_tls "$MEASURE_CODE.3"; check_firewall_active "$MEASURE_CODE.4"; }
check_zks2() { check_firewall_active "$MEASURE_CODE.1"; check_firewall_logging "$MEASURE_CODE.2"; check_skip "$MEASURE_CODE.3" "Перечень атрибутов безопасности субъектов задается оператором и проверяется по правилам/документации"; }
check_zks3() { check_egress_control "$MEASURE_CODE.1"; check_firewall_logging "$MEASURE_CODE.2"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_proxy_categories "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }
check_zks4() { check_dlp "$MEASURE_CODE.1"; check_egress_control "$MEASURE_CODE.2"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_dlp "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }
