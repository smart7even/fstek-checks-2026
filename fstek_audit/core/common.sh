#!/bin/bash
# core/common.sh - reusable read-only evidence helpers shared by measure files.

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
    fstek_component_expected web || have_cmd nginx || have_cmd apache2 || have_cmd httpd || service_known nginx apache2 httpd || file_any /etc/nginx /etc/apache2 /etc/httpd
}

has_mail_stack() {
    fstek_component_expected mail || have_cmd postconf || have_cmd exim || have_cmd sendmail || service_known postfix exim dovecot sendmail || file_any /etc/postfix /etc/exim /etc/dovecot
}

has_api_stack() {
    fstek_component_expected api || has_web_stack || service_known kong tyk-gateway envoy traefik haproxy || file_any /etc/kong /etc/tyk /etc/envoy /etc/traefik /etc/haproxy
}

has_wireless_stack() {
    fstek_component_expected wireless || file_any /etc/hostapd /etc/wpa_supplicant || service_known hostapd wpa_supplicant NetworkManager || have_cmd iw || have_cmd nmcli
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

sshd_config_files() {
    local f
    [ -r /etc/ssh/sshd_config ] && printf '%s\n' /etc/ssh/sshd_config
    if [ -d /etc/ssh/sshd_config.d ]; then
        find /etc/ssh/sshd_config.d -maxdepth 1 -type f -name '*.conf' -print 2>/dev/null | sort
    fi
}

sshd_config_grep() {
    local pattern="$1" file found=1
    while IFS= read -r file; do
        [ -r "$file" ] || continue
        if grep -Eiq "$pattern" "$file" 2>/dev/null; then
            printf '%s\n' "$file"
            found=0
        fi
    done <<EOF
$(sshd_config_files)
EOF
    return "$found"
}

sshd_config_present() {
    sshd_config_files | grep -q .
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
        check_pass_medium "$code" "Обнаружены признаки WAF/фильтрации веб-трафика"
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
    elif fstek_component_expected siem; then
        check_fail "$code" "Профиль требует SIEM/централизованную отправку, но локальная конфигурация forwarding/агент не обнаружены"
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
        check_pass_medium "$code" "Обнаружены признаки автоматического реагирования/блокирования"
    else
        check_fail "$code" "Не обнаружены признаки автоматического реагирования на события"
    fi
}

check_av_installed() {
    local code="$1"
    fstek_load_profile
    if [ -n "${FSTEK_EXPECT_AV_PRODUCT:-}" ]; then
        case "$FSTEK_EXPECT_AV_PRODUCT" in
            clamav|ClamAV)
                if service_active clamav-daemon clamd freshclam || have_cmd clamscan || have_cmd clamdscan; then
                    check_pass "$code" "Ожидаемый AV ClamAV обнаружен"
                else
                    check_fail "$code" "Профиль требует ClamAV, но clamd/freshclam/clamscan не обнаружены"
                fi
                return 0
                ;;
            kaspersky|kesl|Kaspersky)
                if service_active kesl kav4fs-supervisor || have_cmd kesl-control; then
                    check_pass "$code" "Ожидаемый AV Kaspersky/KESL обнаружен"
                else
                    check_fail "$code" "Профиль требует Kaspersky/KESL, но служба или kesl-control не обнаружены"
                fi
                return 0
                ;;
            drweb|DrWeb|Dr.Web)
                if service_active drwebd drweb-configd || have_cmd drweb-ctl; then
                    check_pass "$code" "Ожидаемый AV Dr.Web обнаружен"
                else
                    check_fail "$code" "Профиль требует Dr.Web, но служба или drweb-ctl не обнаружены"
                fi
                return 0
                ;;
        esac
    fi

    if service_active clamav-daemon clamd freshclam drwebd drweb-configd kesl kav4fs-supervisor eset cagtd || have_cmd clamscan || have_cmd clamdscan || have_cmd kesl-control || have_cmd drweb-ctl; then
        check_pass "$code" "Обнаружены установленные или активные средства антивирусной защиты"
    elif fstek_component_expected av; then
        check_fail "$code" "Профиль требует локальный AV, но штатные признаки AV не обнаружены"
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
        check_pass_medium "$code" "Обнаружены средства обнаружения/предотвращения вторжений или host-аудита"
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
    if service_active aidecheck aide.timer aide tripwire afick || grep_any "ima_appraise|security\\.ima|security\\.evm" /proc/cmdline /etc/default/grub /boot/grub/grub.cfg 2>/dev/null || file_any /etc/aide/aide.conf /etc/tripwire/twcfg.txt /etc/afick.conf; then
        check_pass_medium "$code" "Обнаружены средства контроля целостности (AIDE/Tripwire/IMA/EVM)"
    elif have_cmd aide || have_cmd tripwire || have_cmd afick; then
        check_info "$code" "Утилита контроля целостности установлена, но активная служба или конфигурация не подтверждены"
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
    local files
    if ! sshd_config_present; then
        check_fail "$code" "Файлы /etc/ssh/sshd_config и /etc/ssh/sshd_config.d/*.conf не найдены"
        return 0
    fi
    files="$(sshd_config_grep "^[[:space:]]*PermitRootLogin[[:space:]]+(no|prohibit-password)([[:space:]]|$)")"
    if [ -n "$files" ]; then
        check_pass "$code" "SSH root-вход ограничен: $(printf '%s' "$files" | paste -sd, -)"
    else
        check_fail "$code" "Не подтвержден запрет или ограничение SSH root-входа в /etc/ssh/sshd_config или /etc/ssh/sshd_config.d/*.conf"
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
        check_pass_medium "$code" "Обнаружен мониторинг процессов или состояния узла"
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
        check_pass_medium "$code" "Обнаружен API-шлюз или reverse proxy"
    else
        check_fail "$code" "Не обнаружен API-шлюз или reverse proxy"
    fi
}

check_api_schema_validation() {
    local code="$1"
    if grep_any "schema|openapi|swagger|request-validation|validate|json_schema|grpc_json_transcoder" /etc/kong /etc/tyk /etc/envoy /etc/traefik /etc/nginx 2>/dev/null; then
        check_pass_medium "$code" "Обнаружены признаки проверки запросов по спецификации/схеме"
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
        check_pass_medium "$code" "Обнаружены признаки сетевой сегментации (несколько интерфейсов/VLAN/правила по интерфейсам)"
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
        check_pass_medium "$code" "Обнаружены признаки микросегментации или изолирующих политик внутри сегментов"
    else
        check_fail "$code" "Не обнаружены признаки микросегментации, требуемой усилением МСЭ.1"
    fi
}

check_dmz() {
    local code="$1"
    if grep_any "dmz" /etc/firewalld /etc/nftables.conf /etc/iptables /etc/shorewall /etc/ufw 2>/dev/null || (have_cmd firewall-cmd && firewall-cmd --get-active-zones 2>/dev/null | grep -qi dmz); then
        check_pass_medium "$code" "Обнаружена зона/правила DMZ"
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
        check_pass_medium "$code" "Обнаружены признаки ложных систем/honeypot"
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
        check_pass_medium "$code" "Обнаружены службы мониторинга состояния сервисов/интерфейсов"
    else
        check_fail "$code" "Не обнаружены службы мониторинга состояния сервисов/интерфейсов"
    fi
}

check_load_balancing() {
    local code="$1"
    if service_active haproxy nginx keepalived envoy traefik || grep_any "upstream|balance|backend|server .*:[0-9]+|virtual_server|real_server" /etc/nginx /etc/haproxy /etc/keepalived /etc/envoy /etc/traefik 2>/dev/null; then
        check_pass_medium "$code" "Обнаружены признаки балансировки нагрузки"
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
        check_pass_medium "$code" "Обнаружены VPN/криптографические средства защиты каналов"
    else
        check_fail "$code" "Не обнаружены VPN/криптографические средства защиты каналов"
    fi
}

check_egress_control() {
    local code="$1"
    if grep_any "http_access|acl|deny|allow|whitelist|blacklist|url_rewrite|ssl_bump" /etc/squid /etc/tinyproxy /etc/privoxy 2>/dev/null || (have_cmd nft && nft list ruleset 2>/dev/null | grep -qiE " dport | ip daddr | reject| drop") || (have_cmd iptables && iptables -S OUTPUT 2>/dev/null | grep -qiE "REJECT|DROP|--dport|--destination"); then
        check_pass_medium "$code" "Обнаружены признаки контроля исходящего доступа к внешним ресурсам"
    else
        check_fail "$code" "Не обнаружены признаки контроля исходящего доступа к внешним ресурсам"
    fi
}

check_proxy_categories() {
    local code="$1"
    if grep_any "squidGuard|ufdbGuard|redirector|category|blacklist|whitelist|shallalist|url_rewrite_program" /etc/squid /etc/squidguard /etc/ufdbguard 2>/dev/null; then
        check_pass_medium "$code" "Обнаружены признаки категоризации/морфологического контроля ресурсов"
    else
        check_fail "$code" "Не обнаружены признаки категоризации или морфологического контроля ресурсов"
    fi
}

check_dlp() {
    local code="$1"
    if service_active solar-dozor infowatch searchinform zecurion deviceLock traffic-monitor || grep_any "dlp|content.?inspection|data.?loss|casb|classification|fingerprint|watermark" /etc/squid /etc/c-icap /etc/icap /etc/nginx /etc/haproxy 2>/dev/null; then
        check_pass_medium "$code" "Обнаружены признаки DLP/ICAP/контекстной проверки исходящего трафика"
    elif service_active squid c-icap || grep_any "icap|ssl_bump" /etc/squid /etc/c-icap /etc/icap /etc/nginx /etc/haproxy 2>/dev/null; then
        check_info "$code" "Обнаружены proxy/ICAP/ssl_bump признаки, но без явной DLP/контекстной политики этого недостаточно для PASS"
    else
        check_fail "$code" "Не обнаружены признаки контекстной проверки исходящего трафика"
    fi
}
