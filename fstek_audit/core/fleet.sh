#!/bin/bash
# core/fleet.sh - fleet availability checks, SSH auth, and inventory parsing.

FLEET_HOSTNAME=""
FLEET_IP=""
FLEET_USER=""
FLEET_PORT=""
FLEET_REMOTE_REPO=""
FLEET_SSH_KEY=""
FLEET_PASSWORD_ENV=""
FLEET_AUTH_MODE=""
FLEET_AUTH_SOURCE=""

fstek_fleet_ping() {
    local ip="$1" timeout="${2:-2}"
    [ -n "$ip" ] || return 1
    if ping -c 1 -W "$timeout" "$ip" >/dev/null 2>&1; then
        return 0
    fi
    if ping -c 1 -t "$timeout" "$ip" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

fstek_fleet_key_usable() {
    local key_file="$1"
    [ -n "$key_file" ] && [ "$key_file" != "-" ] && [ -r "$key_file" ]
}

fstek_fleet_password_available() {
    local env_name="$1" value=""
    [ -n "$env_name" ] || return 1
    value="${!env_name-}"
    [ -n "$value" ]
}

fstek_fleet_parse_host_line() {
    local line="$1"
    local default_user="$2" default_port="$3" default_repo="$4"

    FLEET_SSH_KEY=""
    FLEET_PASSWORD_ENV=""

    IFS='|' read -r FLEET_HOSTNAME FLEET_IP FLEET_USER FLEET_PORT FLEET_REMOTE_REPO FLEET_SSH_KEY FLEET_PASSWORD_ENV <<<"$line"
    [ -n "$FLEET_USER" ] || FLEET_USER="$default_user"
    [ -n "$FLEET_PORT" ] || FLEET_PORT="$default_port"
    [ -n "$FLEET_REMOTE_REPO" ] || FLEET_REMOTE_REPO="$default_repo"
}

fstek_fleet_resolve_auth() {
    local global_key="$1" global_password_env="$2" auth_policy="${3:-auto}"
    local key_candidate="" pass_candidate=""

    if fstek_fleet_key_usable "$FLEET_SSH_KEY"; then
        key_candidate="$FLEET_SSH_KEY"
    elif fstek_fleet_key_usable "$global_key"; then
        key_candidate="$global_key"
    fi

    if [ -n "$FLEET_PASSWORD_ENV" ]; then
        pass_candidate="$FLEET_PASSWORD_ENV"
    elif [ -n "$global_password_env" ]; then
        pass_candidate="$global_password_env"
    fi

    case "$auth_policy" in
        key)
            if [ -n "$key_candidate" ]; then
                FLEET_AUTH_MODE="key"
                FLEET_AUTH_SOURCE="$key_candidate"
                FLEET_SSH_KEY="$key_candidate"
                return 0
            fi
            FLEET_AUTH_MODE=""
            FLEET_AUTH_SOURCE=""
            return 1
            ;;
        password)
            if fstek_fleet_password_available "$pass_candidate"; then
                FLEET_AUTH_MODE="password"
                FLEET_AUTH_SOURCE="$pass_candidate"
                FLEET_PASSWORD_ENV="$pass_candidate"
                return 0
            fi
            FLEET_AUTH_MODE=""
            FLEET_AUTH_SOURCE=""
            return 1
            ;;
        auto|*)
            if [ -n "$key_candidate" ]; then
                FLEET_AUTH_MODE="key"
                FLEET_AUTH_SOURCE="$key_candidate"
                FLEET_SSH_KEY="$key_candidate"
                return 0
            fi
            if fstek_fleet_password_available "$pass_candidate"; then
                FLEET_AUTH_MODE="password"
                FLEET_AUTH_SOURCE="$pass_candidate"
                FLEET_PASSWORD_ENV="$pass_candidate"
                return 0
            fi
            FLEET_AUTH_MODE=""
            FLEET_AUTH_SOURCE=""
            return 1
            ;;
    esac
}

fstek_fleet_ssh_opts() {
    local port="$1" auth_mode="$2" key_file="$3" connect_timeout="${4:-10}"

    if [ "$auth_mode" = "password" ]; then
        printf '%s' "-o BatchMode=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=${connect_timeout} -o StrictHostKeyChecking=accept-new -p ${port}"
        return 0
    fi

    printf '%s' "-o BatchMode=yes -o ConnectTimeout=${connect_timeout} -o StrictHostKeyChecking=accept-new -p ${port}"
    if [ -n "$key_file" ]; then
        printf ' -i %q' "$key_file"
    fi
}

fstek_fleet_scp_opts() {
    local port="$1" auth_mode="$2" key_file="$3" connect_timeout="${4:-10}"

    if [ "$auth_mode" = "password" ]; then
        printf '%s' "-o BatchMode=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=${connect_timeout} -o StrictHostKeyChecking=accept-new -P ${port}"
        return 0
    fi

    printf '%s' "-o BatchMode=yes -o ConnectTimeout=${connect_timeout} -o StrictHostKeyChecking=accept-new -P ${port}"
    if [ -n "$key_file" ]; then
        printf ' -i %q' "$key_file"
    fi
}

fstek_fleet_with_password_auth() {
    local password_env="$1"
    shift
    local askpass_script="" password_value=""

    password_value="${!password_env-}"
    [ -n "$password_value" ] || return 1

    askpass_script="$(mktemp "${TMPDIR:-/tmp}/fstek-askpass.XXXXXX")"
    cat >"$askpass_script" <<'EOF'
#!/bin/sh
printf '%s\n' "$FSTEK_SSH_ASKPASS_PASSWORD"
EOF
    chmod 700 "$askpass_script"

    FSTEK_SSH_ASKPASS_PASSWORD="$password_value" DISPLAY=:0 SSH_ASKPASS="$askpass_script" SSH_ASKPASS_REQUIRE=force "$@"
    local rc=$?
    rm -f "$askpass_script"
    unset FSTEK_SSH_ASKPASS_PASSWORD
    return "$rc"
}

fstek_fleet_ssh_test() {
    local user="$1" host="$2" port="$3" auth_mode="$4" key_file="$5" password_env="$6" connect_timeout="$7"
    local ssh_args

    ssh_args="$(fstek_fleet_ssh_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"
    if [ "$auth_mode" = "password" ]; then
        # shellcheck disable=SC2086
        fstek_fleet_with_password_auth "$password_env" ssh $ssh_args "${user}@${host}" "echo fstek-ok" >/dev/null 2>&1
        return $?
    fi
    # shellcheck disable=SC2086
    ssh $ssh_args "${user}@${host}" "echo fstek-ok" >/dev/null 2>&1
}

fstek_fleet_ssh_run() {
    local user="$1" host="$2" port="$3" auth_mode="$4" key_file="$5" password_env="$6" connect_timeout="$7" remote_cmd="$8"
    local ssh_args

    ssh_args="$(fstek_fleet_ssh_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"
    if [ "$auth_mode" = "password" ]; then
        # shellcheck disable=SC2086
        fstek_fleet_with_password_auth "$password_env" ssh $ssh_args "${user}@${host}" "$remote_cmd"
        return $?
    fi
    # shellcheck disable=SC2086
    ssh $ssh_args "${user}@${host}" "$remote_cmd"
}

fstek_fleet_scp_collect() {
    local user="$1" host="$2" port="$3" auth_mode="$4" key_file="$5" password_env="$6" connect_timeout="$7" remote_path="$8" local_dir="$9"
    local scp_args

    scp_args="$(fstek_fleet_scp_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"
    if [ "$auth_mode" = "password" ]; then
        # shellcheck disable=SC2086
        fstek_fleet_with_password_auth "$password_env" scp -r $scp_args "${user}@${host}:${remote_path}" "$local_dir/" 2>/dev/null
        return $?
    fi
    # shellcheck disable=SC2086
    scp -r $scp_args "${user}@${host}:${remote_path}" "$local_dir/" 2>/dev/null
}

fstek_fleet_write_unreachable_json() {
    local json_file="$1" batch_id="$2" hostname="$3" ip="$4" ping_ok="$5" ssh_ok="$6" message="$7"
    cat >"$json_file" <<EOF
{
  "schema": "fstek-audit-summary/v1",
  "batch_id": $(fstek_json_string "$batch_id"),
  "hostname": $(fstek_json_string "$hostname"),
  "primary_ip": $(fstek_json_string "$ip"),
  "scan_status": "unreachable",
  "ping_ok": $( [ "$ping_ok" = true ] && printf 'true' || printf 'false' ),
  "ssh_ok": $( [ "$ssh_ok" = true ] && printf 'true' || printf 'false' ),
  "overall_result": "UNREACHABLE",
  "exit_code": 3,
  "error_message": $(fstek_json_string "$message")
}
EOF
}

fstek_fleet_bool() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

fstek_fleet_rsync_e() {
    local port="$1" auth_mode="$2" key_file="$3" connect_timeout="$4"
    printf 'ssh %s' "$(fstek_fleet_ssh_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"
}

fstek_fleet_deploy_repo() {
    local user="$1" host="$2" port="$3" auth_mode="$4" key_file="$5" password_env="$6"
    local connect_timeout="$7" deploy_source="$8" remote_repo="$9" remote_sudo="${10}"
    local log_file="${11}"
    local rsync_e rsync_path="" rsync_cmd=()

    [ -d "$deploy_source" ] || {
        echo "    deploy: FAIL (local source missing: $deploy_source)" >>"$log_file"
        return 1
    }
    [ -x "$deploy_source/check_all.sh" ] || {
        echo "    deploy: FAIL (check_all.sh missing in $deploy_source)" >>"$log_file"
        return 1
    }

    rsync_e="$(fstek_fleet_rsync_e "$port" "$auth_mode" "$key_file" "$connect_timeout")"
    if fstek_fleet_bool "$remote_sudo"; then
        rsync_path="sudo rsync"
    fi

    rsync_cmd=(
        rsync -az --delete
        --exclude .git/
        --exclude fstek_audit/output/
        --exclude .env.local
        --exclude 'fstek_audit/config/inventory.lab.conf'
        -e "$rsync_e"
    )
    [ -n "$rsync_path" ] && rsync_cmd+=(--rsync-path="$rsync_path")
    rsync_cmd+=(
        "$deploy_source/"
        "${user}@${host}:${remote_repo}/"
    )

    echo "    deploy: rsync ${deploy_source}/ -> ${user}@${host}:${remote_repo}/" >>"$log_file"
    if [ "$auth_mode" = "password" ]; then
        if ! fstek_fleet_with_password_auth "$password_env" "${rsync_cmd[@]}" >>"$log_file" 2>&1; then
            echo "    deploy: FAIL" >>"$log_file"
            return 1
        fi
    elif ! "${rsync_cmd[@]}" >>"$log_file" 2>&1; then
        echo "    deploy: FAIL" >>"$log_file"
        return 1
    fi

    if fstek_fleet_bool "$remote_sudo"; then
        remote_chmod_cmd="$(fstek_fleet_remote_sudo_prefix true)chmod +x ${remote_repo}/check_all.sh ${remote_repo}/fleet_check.sh ${remote_repo}/fstek_audit/run.sh ${remote_repo}/fstek_audit/run_fleet.sh ${remote_repo}/fstek_audit/run_measure.sh 2>/dev/null || true"
        fstek_fleet_ssh_run "$user" "$host" "$port" "$auth_mode" "$key_file" "$password_env" "$connect_timeout" \
            "$remote_chmod_cmd" >>"$log_file" 2>&1 || true
    else
        fstek_fleet_ssh_run "$user" "$host" "$port" "$auth_mode" "$key_file" "$password_env" "$connect_timeout" \
            "chmod +x ${remote_repo}/check_all.sh ${remote_repo}/fleet_check.sh ${remote_repo}/fstek_audit/run.sh ${remote_repo}/fstek_audit/run_fleet.sh ${remote_repo}/fstek_audit/run_measure.sh 2>/dev/null || true" >>"$log_file" 2>&1 || true
    fi

    echo "    deploy: OK" >>"$log_file"
    return 0
}

fstek_fleet_remote_sudo_prefix() {
    if fstek_fleet_bool "$1"; then
        printf '%s' 'sudo -n '
    fi
}

fstek_fleet_process_host() {
    local host_line="$1"
    local batch_id="$2" output_dir="$3" scan_started_at="$4"
    local default_user="$5" default_port="$6" default_repo="$7"
    local global_key="$8" global_password_env="$9" auth_policy="${10}"
    local ping_timeout="${11}" connect_timeout="${12}" fleet_class="${13}"
    local remote_sudo="${14}" auto_deploy="${15}" deploy_source="${16}" row_file="${17}"

    local ping_ok=false ssh_ok=false scan_status="unreachable"
    local overall_result="UNREACHABLE" exit_code=3
    local log_file="" json_file="" error_message=""
    local host_token stamp host_dir remote_out remote_cmd remote_artifact_dir
    local rel_log rel_json auth_label remote_sudo_prefix

    fstek_fleet_parse_host_line "$host_line" "$default_user" "$default_port" "$default_repo"
    host_token="$(fstek_report_sanitize_token "$FLEET_HOSTNAME")"
    stamp="$(fstek_report_timestamp)"
    host_dir="$output_dir/$host_token"
    mkdir -p "$host_dir"

    {
        echo ">>> Host: $FLEET_HOSTNAME ($FLEET_IP)"
    } >>"$host_dir/fleet-host.log"

    if fstek_fleet_ping "$FLEET_IP" "$ping_timeout"; then
        ping_ok=true
        echo "    ping: OK" >>"$host_dir/fleet-host.log"
    else
        error_message="ping failed"
        echo "    ping: FAIL" >>"$host_dir/fleet-host.log"
    fi

    if $ping_ok; then
        if fstek_fleet_resolve_auth "$global_key" "$global_password_env" "$auth_policy"; then
            auth_label="$FLEET_AUTH_MODE ($FLEET_AUTH_SOURCE)"
            if fstek_fleet_ssh_test "$FLEET_USER" "$FLEET_IP" "$FLEET_PORT" "$FLEET_AUTH_MODE" "$FLEET_SSH_KEY" "$FLEET_PASSWORD_ENV" "$connect_timeout"; then
                ssh_ok=true
                echo "    ssh: OK ($auth_label)" >>"$host_dir/fleet-host.log"
            else
                error_message="ssh failed ($auth_label)"
                echo "    ssh: FAIL ($auth_label)" >>"$host_dir/fleet-host.log"
            fi
        else
            error_message="no SSH credentials configured"
            echo "    ssh: FAIL (no credentials)" >>"$host_dir/fleet-host.log"
        fi
    fi

    if $ping_ok && $ssh_ok; then
        if fstek_fleet_bool "$auto_deploy"; then
            if ! fstek_fleet_deploy_repo "$FLEET_USER" "$FLEET_IP" "$FLEET_PORT" "$FLEET_AUTH_MODE" "$FLEET_SSH_KEY" "$FLEET_PASSWORD_ENV" "$connect_timeout" "$deploy_source" "$FLEET_REMOTE_REPO" "$remote_sudo" "$host_dir/fleet-host.log"; then
                scan_status="deploy_failed"
                overall_result="FAIL"
                exit_code=2
                error_message="failed to deploy checks bundle to remote host"
            fi
        else
            echo "    deploy: skipped (FSTEK_AUTO_DEPLOY=false)" >>"$host_dir/fleet-host.log"
        fi
    fi

    if $ping_ok && $ssh_ok && [ "$scan_status" != "deploy_failed" ]; then
        remote_out="/tmp/fstek-audit-${batch_id}-${host_token}-$$"
        remote_sudo_prefix="$(fstek_fleet_remote_sudo_prefix "$remote_sudo")"
        remote_cmd="mkdir -p $(printf '%q' "$remote_out") && cd $(printf '%q' "$FLEET_REMOTE_REPO") && FSTEK_COLOR=never ${remote_sudo_prefix}./check_all.sh --class $(printf '%q' "$fleet_class") --output-dir $(printf '%q' "$remote_out") --batch-id $(printf '%q' "$batch_id") ; SCAN_RC=\$? ; ${remote_sudo_prefix}chmod -R a+rX $(printf '%q' "$remote_out") 2>/dev/null || true ; exit \$SCAN_RC"
        if fstek_fleet_ssh_run "$FLEET_USER" "$FLEET_IP" "$FLEET_PORT" "$FLEET_AUTH_MODE" "$FLEET_SSH_KEY" "$FLEET_PASSWORD_ENV" "$connect_timeout" "$remote_cmd" >>"$host_dir/fleet-host.log" 2>&1; then
            scan_status="scanned"
            exit_code=0
        else
            scan_rc=$?
            if [ "$scan_rc" -eq 1 ]; then
                scan_status="scanned"
                exit_code=1
            else
                scan_status="scan_failed"
                overall_result="FAIL"
                exit_code="$scan_rc"
                error_message="remote check_all.sh failed"
            fi
        fi

        if [ "$scan_status" = "scanned" ] || [ "$scan_status" = "scan_failed" ]; then
            remote_artifact_dir="$remote_out/$batch_id"
            if fstek_fleet_scp_collect "$FLEET_USER" "$FLEET_IP" "$FLEET_PORT" "$FLEET_AUTH_MODE" "$FLEET_SSH_KEY" "$FLEET_PASSWORD_ENV" "$connect_timeout" "${remote_artifact_dir}/" "$host_dir/"; then
                json_file="$(find "$host_dir" -type f -name '*.json' ! -name 'fleet-*.json' | sort | tail -n 1)"
                log_file="$(find "$host_dir" -type f -name '*.log' ! -name 'fleet-host.log' | sort | tail -n 1)"
                if [ -n "$json_file" ] && [ -r "$json_file" ]; then
                    overall_result="$(sed -n 's/.*"overall_result"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1)"
                    json_exit="$(sed -n 's/.*"exit_code"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$json_file" | head -n 1)"
                    [ -n "$json_exit" ] && exit_code="$json_exit"
                elif [ "$scan_status" = "scanned" ]; then
                    overall_result="OK"
                fi
            else
                scan_status="collect_failed"
                overall_result="FAIL"
                exit_code=2
                error_message="failed to collect remote artifacts"
            fi
        fi
    else
        json_file="$host_dir/${host_token}-${stamp}.json"
        fstek_fleet_write_unreachable_json "$json_file" "$batch_id" "$FLEET_HOSTNAME" "$FLEET_IP" "$ping_ok" "$ssh_ok" "$error_message"
    fi

    rel_log="${log_file#$output_dir/}"
    rel_json="${json_file#$output_dir/}"
    fstek_csv_row "$scan_started_at" "$batch_id" "$FLEET_HOSTNAME" "$FLEET_IP" "$ping_ok" "$ssh_ok" "$scan_status" "$overall_result" "$exit_code" "$rel_log" "$rel_json" "$error_message" >"$row_file"
    {
        printf 'ping_ok=%s\n' "$ping_ok"
        printf 'ssh_ok=%s\n' "$ssh_ok"
        printf 'scan_status=%s\n' "$scan_status"
        printf 'overall_result=%s\n' "$overall_result"
    } >"$host_dir/.fleet-status"

    if [ "$scan_status" = "scanned" ] && [ "$overall_result" = "OK" ]; then
        return 0
    fi
    return 1
}
