#!/bin/bash
# core/aggregate.sh - fleet batch aggregation from collected scan logs.

fstek_aggregate_host_meta() {
    local host_dir="$1"
    local json_file=""

    json_file="$(find "$host_dir" -type f -name '*.json' ! -name 'fleet-*.json' | sort | tail -n 1)"
    FSTEK_AGG_HOSTNAME=""
    FSTEK_AGG_IP=""
    FSTEK_AGG_OS=""
    FSTEK_AGG_OVERALL=""

    if [ -n "$json_file" ] && [ -r "$json_file" ]; then
        FSTEK_AGG_HOSTNAME="$(sed -n 's/.*"hostname"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1)"
        FSTEK_AGG_IP="$(sed -n 's/.*"primary_ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1)"
        FSTEK_AGG_OS="$(sed -n 's/.*"os_label"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1)"
        FSTEK_AGG_OVERALL="$(sed -n 's/.*"overall_result"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1)"
    fi

    if [ -z "$FSTEK_AGG_HOSTNAME" ]; then
        FSTEK_AGG_HOSTNAME="$(basename "$host_dir")"
    fi
}

fstek_aggregate_parse_log() {
    local log_file="$1"
    local batch_id="$2" host_token="$3"
    awk -v batch="$batch_id" -v host_token="$host_token" -v hostname="$FSTEK_AGG_HOSTNAME" -v ip="$FSTEK_AGG_IP" -v os_label="$FSTEK_AGG_OS" -v overall="$FSTEK_AGG_OVERALL" '
        BEGIN { FS=" – " }
        /^\[[^]]+\] PASS \(HIGH\) –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            split(param, segs, ".")
            if (length(segs) >= 3) {
                measure = param
                sub(/\.[^.]+$/, "", measure)
            } else {
                measure = param
            }
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,PASS,HIGH,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
        /^\[[^]]+\] PASS \(MEDIUM\) –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            split(param, segs, ".")
            if (length(segs) >= 3) {
                measure = param
                sub(/\.[^.]+$/, "", measure)
            } else {
                measure = param
            }
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,PASS,MEDIUM,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
        /^\[[^]]+\] FAIL –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            split(param, segs, ".")
            if (length(segs) >= 3) {
                measure = param
                sub(/\.[^.]+$/, "", measure)
            } else {
                measure = param
            }
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,FAIL,,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
        /^\[[^]]+\] SKIP –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            split(param, segs, ".")
            if (length(segs) >= 3) {
                measure = param
                sub(/\.[^.]+$/, "", measure)
            } else {
                measure = param
            }
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,SKIP,,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
        /^\[[^]]+\] INFO –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            split(param, segs, ".")
            if (length(segs) >= 3) {
                measure = param
                sub(/\.[^.]+$/, "", measure)
            } else {
                measure = param
            }
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,INFO,,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
        /^\[[^]]+\] NA –/ {
            split($0, parts, /[\[\]]/)
            param = parts[2]
            measure = param
            msg = $2
            gsub(/"/, "\"\"", msg)
            printf "%s,%s,%s,%s,%s,%s,%s,%s,NA,,\"%s\"\n", batch, host_token, hostname, ip, os_label, overall, measure, param, msg
        }
    ' "$log_file"
}

fstek_aggregate_batch() {
    local batch_dir="$1"
    local batch_id="$2"
    local measures_csv="$3" rollups_csv="$4"
    local host_dir log_file host_token

    [ -d "$batch_dir" ] || return 1

    {
        printf 'batch_id,host_token,hostname,ip,os_label,host_overall,measure,parameter,status,confidence,evidence\n'
    } >"$measures_csv"

    find "$batch_dir" -mindepth 1 -maxdepth 1 -type d ! -name '.rows' | sort | while IFS= read -r host_dir; do
        [ -d "$host_dir" ] || continue
        host_token="$(basename "$host_dir")"
        fstek_aggregate_host_meta "$host_dir"
        while IFS= read -r log_file; do
            [ -f "$log_file" ] || continue
            fstek_aggregate_parse_log "$log_file" "$batch_id" "$host_token" >>"$measures_csv"
        done < <(find "$host_dir" -type f -name '*.log' ! -name 'fleet-host.log' | sort)
    done

    {
        printf 'batch_id,measure,parameter,status,host_count\n'
        tail -n +2 "$measures_csv" | sed 's/,"\([^"]*\)"$//' | awk -F',' '
            NF >= 9 {
                key = $1 "," $7 "," $8 "," $9
                count[key]++
            }
            END {
                for (k in count) {
                    print k "," count[k]
                }
            }
        ' | sort -t, -k2,2 -k3,3 -k4,4
    } >"$rollups_csv"

    return 0
}
