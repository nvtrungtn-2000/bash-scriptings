#!/usr/bin/env bash
# Description: Nagios plugin to check the number of logged-in users
# Version: 1.0.0

set -euo pipefail
IFS=$'\n\t'

# Define constants
readonly OK=0
readonly WARNING=1
readonly CRITICAL=2
readonly UNKNOWN=3

# Default values
WARNING_THRESHOLD=5
CRITICAL_THRESHOLD=10
CHECK_TYPE="active"
VERSION="1.0.0"

# Define associative array for status
declare -A STATUS=(
    [OK]=$OK
    [WARNING]=$WARNING
    [CRITICAL]=$CRITICAL
    [UNKNOWN]=$UNKNOWN
)

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

usage() {
    cat << EOF
Usage: ${0##*/} [-w warning] [-c critical] [-t check_type] [-h] [-v]
  -w: Warning threshold (default: 5)
  -c: Critical threshold (default: 10)
  -t: Check type (active/all, default: active)
      active: Only count non-idle users
      all: Count all logged in users
  -h: Show this help message
  -v: Show version
Version: $VERSION
EOF
    exit "${UNKNOWN}"
}

show_version() {
    echo "Version: $VERSION"
    exit "$OK"
}

parse_arguments() {
    local OPTIND
    while getopts ":w:c:t:hv" opt; do
        case "${opt}" in
            w) WARNING_THRESHOLD="${OPTARG}" ;;
            c) CRITICAL_THRESHOLD="${OPTARG}" ;;
            t) CHECK_TYPE="${OPTARG}" ;;
            h) usage ;;
            v) show_version ;;
            :) log "Option -$OPTARG requires an argument."; usage ;;
            *) log "Unknown option: -$OPTARG"; usage ;;
        esac
    done
}

validate_input() {
    if ! [[ "${WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] || ! [[ "${CRITICAL_THRESHOLD}" =~ ^[0-9]+$ ]]; then
        log "Error: Thresholds must be positive integers"
        exit "${UNKNOWN}"
    fi
    if [[ "${WARNING_THRESHOLD}" -ge "${CRITICAL_THRESHOLD}" ]]; then
        log "Error: Warning threshold must be less than critical threshold"
        exit "${UNKNOWN}"
    fi
    if [[ "${CHECK_TYPE}" != "active" && "${CHECK_TYPE}" != "all" ]]; then
        log "Error: Invalid check type. Use 'active' or 'all'"
        exit "${UNKNOWN}"
    fi
}

get_active_users() {
    w -h | awk '$4 < "20:00" {count++} END {print count+0}'
}

get_all_users() {
    who | awk '{print $1" "$2}' | sort -u | wc -l
}

get_user_count() {
    if [[ "${CHECK_TYPE}" = "active" ]]; then
        get_active_users
    else
        get_all_users
    fi
}

generate_perfdata() {
    local user_count="$1"
    echo "users=${user_count};${WARNING_THRESHOLD};${CRITICAL_THRESHOLD}"
}

output_result() {
    local user_count="$1"
    local perfdata
    perfdata=$(generate_perfdata "${user_count}")
    local status="OK"
    
    if [[ "${user_count}" -ge "${CRITICAL_THRESHOLD}" ]]; then
        status="CRITICAL"
    elif [[ "${user_count}" -ge "${WARNING_THRESHOLD}" ]]; then
        status="WARNING"
    fi
    
    echo "${status} - ${user_count} users logged in | ${perfdata}"
    exit "${STATUS[$status]}"
}

check_dependencies() {
    local dependencies=("w" "who" "awk" "sort" "wc")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "Error: $cmd is required but not installed."
            exit "${UNKNOWN}"
        fi
    done
}

cleanup() {
    log "Cleaning up and exiting"
    # Add any necessary cleanup tasks here
}

main() {
    trap cleanup EXIT
    
    check_dependencies
    parse_arguments "$@"
    validate_input
    
    local user_count
    user_count=$(get_user_count)
    output_result "${user_count}"
}

main "$@"
