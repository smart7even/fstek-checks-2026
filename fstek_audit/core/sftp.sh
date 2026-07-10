#!/bin/bash
# core/sftp.sh - SFTP upload helpers for fleet batch artifacts.

fstek_sftp_bool() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

fstek_sftp_opts() {
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

fstek_sftp_resolve_auth() {
    local key="$1" password_env="$2" auth_policy="${3:-auto}"

    FSTEK_SFTP_AUTH_MODE=""
    FSTEK_SFTP_KEY=""
    FSTEK_SFTP_PASSWORD_ENV=""

    case "$auth_policy" in
        key)
            [ -n "$key" ] && [ -r "$key" ] || return 1
            FSTEK_SFTP_AUTH_MODE="key"
            FSTEK_SFTP_KEY="$key"
            return 0
            ;;
        password)
            [ -n "$password_env" ] && [ -n "${!password_env-}" ] || return 1
            FSTEK_SFTP_AUTH_MODE="password"
            FSTEK_SFTP_PASSWORD_ENV="$password_env"
            return 0
            ;;
        auto|*)
            if [ -n "$key" ] && [ -r "$key" ]; then
                FSTEK_SFTP_AUTH_MODE="key"
                FSTEK_SFTP_KEY="$key"
                return 0
            fi
            if [ -n "$password_env" ] && [ -n "${!password_env-}" ]; then
                FSTEK_SFTP_AUTH_MODE="password"
                FSTEK_SFTP_PASSWORD_ENV="$password_env"
                return 0
            fi
            return 1
            ;;
    esac
}

fstek_sftp_upload_batch() {
    local batch_dir="$1" user="$2" host="$3" port="$4" remote_base="$5"
    local key_file="$6" password_env="$7" auth_mode="$8" connect_timeout="$9"
    local batch_id remote_dir archive tmp_batch ssh_opts sftp_opts rc

    [ -d "$batch_dir" ] || return 1
    batch_id="$(basename "$batch_dir")"
    remote_dir="${remote_base%/}/${batch_id}"
    archive="$(mktemp "${TMPDIR:-/tmp}/fstek-batch.XXXXXX.tar.gz")"
    tmp_batch="$(mktemp "${TMPDIR:-/tmp}/fstek-sftp.XXXXXX")"

    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        COPYFILE_DISABLE=1 tar -C "$(dirname "$batch_dir")" -czf "$archive" "$batch_id" || {
            rm -f "$archive" "$tmp_batch"
            return 1
        }
    elif tar --no-xattrs -C "$(dirname "$batch_dir")" -czf "$archive" "$batch_id" 2>/dev/null; then
        :
    elif tar -C "$(dirname "$batch_dir")" -czf "$archive" "$batch_id"; then
        :
    else
        rm -f "$archive" "$tmp_batch"
        return 1
    fi

    ssh_opts="$(fstek_fleet_ssh_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"
    sftp_opts="$(fstek_sftp_opts "$port" "$auth_mode" "$key_file" "$connect_timeout")"

    {
        printf 'cd %s\n' "$remote_base"
        printf 'put %q %s.tar.gz\n' "$archive" "$batch_id"
    } >"$tmp_batch"

    if [ "$auth_mode" = "password" ]; then
        # shellcheck disable=SC2086
        fstek_fleet_with_password_auth "$password_env" sftp $sftp_opts -b "$tmp_batch" "${user}@${host}"
        rc=$?
    else
        # shellcheck disable=SC2086
        sftp $sftp_opts -b "$tmp_batch" "${user}@${host}"
        rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
        # shellcheck disable=SC2086
        ssh $ssh_opts "${user}@${host}" "cd $(printf '%q' "$remote_base") && tar --warning=no-unknown-keyword -xzf $(printf '%q' "${batch_id}.tar.gz") 2>/dev/null || tar -xzf $(printf '%q' "${batch_id}.tar.gz") 2>/dev/null; rm -f $(printf '%q' "${batch_id}.tar.gz")" || rc=$?
    fi

    rm -f "$archive" "$tmp_batch"
    return "$rc"
}
