#!/usr/bin/env bash
# Common helpers for postgres-lab test suite

set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
PASS_COUNT=0; FAIL_COUNT=0

log_ok()   { printf "${GREEN}  [PASS]${RESET} %s\n" "$*"; }
log_fail() { printf "${RED}  [FAIL]${RESET} %s\n" "$*"; }
log_info() { printf "${YELLOW}  [INFO]${RESET} %s\n" "$*"; }

assert() {
    local description="$1"; shift
    if "$@" >/dev/null 2>&1; then log_ok "$description"; PASS_COUNT=$((PASS_COUNT + 1))
    else log_fail "$description"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
assert_fail() {
    local description="$1"; shift
    if "$@" >/dev/null 2>&1; then log_fail "$description"; FAIL_COUNT=$((FAIL_COUNT + 1))
    else log_ok "$description"; PASS_COUNT=$((PASS_COUNT + 1)); fi
}
assert_contains() {
    local description="$1" output="$2" pattern="$3"
    if echo "$output" | grep -qE "$pattern"; then log_ok "$description"; PASS_COUNT=$((PASS_COUNT + 1))
    else log_fail "$description (expected pattern: $pattern)"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}
assert_not_contains() {
    local description="$1" output="$2" pattern="$3"
    if echo "$output" | grep -qE "$pattern"; then log_fail "$description (unexpected pattern: $pattern)"; FAIL_COUNT=$((FAIL_COUNT + 1))
    else log_ok "$description"; PASS_COUNT=$((PASS_COUNT + 1)); fi
}

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$TESTS_DIR/.." && pwd)"

_find_workspace() {
    local dir="$PLUGIN_DIR"
    if [[ -d "$dir/../../.qlab" ]]; then echo "$(cd "$dir/../.." && pwd)"; return; fi
    local d="$dir"
    while [[ "$d" != "/" ]]; do
        if [[ -d "$d/.qlab" ]]; then echo "$d"; return; fi
        d="$(dirname "$d")"
    done
    echo ""
}

WORKSPACE_DIR="$(_find_workspace)"
if [[ -z "$WORKSPACE_DIR" ]]; then echo "ERROR: Cannot find qlab workspace."; exit 1; fi
STATE_DIR="$WORKSPACE_DIR/.qlab/state"
SSH_KEY="$WORKSPACE_DIR/.qlab/ssh/qlab_id_rsa"

_get_port() {
    local port_file="$STATE_DIR/${1}.port"
    if [[ -f "$port_file" ]]; then cat "$port_file"; else echo ""; fi
}

SERVER_PORT="$(_get_port postgres-lab)"
if [[ -z "$SERVER_PORT" ]]; then echo "ERROR: Cannot find VM port. Is postgres-lab running?"; exit 1; fi

_ssh_base_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
ssh_vm() { ssh "${_ssh_base_opts[@]}" -i "$SSH_KEY" -p "$SERVER_PORT" labuser@localhost "$@"; }

psql_query() { ssh_vm "PGPASSWORD=labpass psql -U labuser -d testdb -t -A -c \"$1\""; }
psql_query_db() { ssh_vm "PGPASSWORD=labpass psql -U labuser -d $1 -t -A -c \"$2\""; }

cleanup_postgres() {
    log_info "Cleaning up postgres test artifacts..."
    ssh_vm "PGPASSWORD=labpass psql -U labuser -d testdb -c \"DROP TABLE IF EXISTS students;\" 2>/dev/null; sudo -u postgres psql -d testdb -c \"REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reader;\" 2>/dev/null; sudo -u postgres psql -c \"DROP DATABASE IF EXISTS testlab;\" 2>/dev/null; sudo -u postgres psql -c \"DROP USER IF EXISTS reader;\" 2>/dev/null; rm -f /tmp/testdb_backup.sql" 2>/dev/null || true
}

report_results() {
    local test_name="${1:-Test}"; echo ""
    if [[ "$FAIL_COUNT" -eq 0 ]]; then
        printf "${GREEN}${BOLD}  %s: All %d checks passed${RESET}\n" "$test_name" "$PASS_COUNT"
    else
        printf "${RED}${BOLD}  %s: %d passed, %d failed${RESET}\n" "$test_name" "$PASS_COUNT" "$FAIL_COUNT"
    fi
    return "$FAIL_COUNT"
}
