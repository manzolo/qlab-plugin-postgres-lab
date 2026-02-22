#!/usr/bin/env bash
# run_all.sh — Run all postgres-lab exercise tests

set -euo pipefail
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/_common.sh"

SKIP_TESTS=()
while [[ $# -gt 0 ]]; do
    case "$1" in --skip) shift; SKIP_TESTS+=("$1"); shift ;; *) echo "Unknown option: $1"; exit 1 ;; esac
done
should_skip() { local num="$1"; for s in "${SKIP_TESTS[@]+"${SKIP_TESTS[@]}"}"; do [[ "$num" == "$s" ]] && return 0; done; return 1; }

echo ""
echo "${BOLD}=========================================${RESET}"
echo "${BOLD}  postgres-lab — Automated Test Suite${RESET}"
echo "${BOLD}=========================================${RESET}"
echo ""
log_info "Workspace: $WORKSPACE_DIR"
log_info "Server port: $SERVER_PORT"

log_info "Checking VM connectivity..."
assert "VM is reachable via SSH" ssh_vm "echo ok"
log_info "Checking cloud-init status..."
ci_status=$(ssh_vm "cloud-init status 2>/dev/null || echo done") || true
assert_contains "Cloud-init is done" "$ci_status" "done|status: done"
log_info "Checking PostgreSQL is ready..."
assert "PostgreSQL is running" ssh_vm "systemctl is-active postgresql"

cleanup_postgres

TOTAL_PASS=0; TOTAL_FAIL=0; TESTS_RUN=0; TESTS_SKIPPED=0; FAILED_EXERCISES=()
run_test() {
    local num="$1"; local files=($TESTS_DIR/test_${num}_*.sh)
    if [[ ! -f "${files[0]}" ]]; then log_info "Test not found: test_${num}_*"; return; fi
    if should_skip "$num"; then log_info "Skipping exercise $num"; TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); return; fi
    cleanup_postgres >/dev/null 2>&1
    local test_exit=0; bash "${files[0]}" || test_exit=$?
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$test_exit" -ne 0 ]]; then TOTAL_FAIL=$((TOTAL_FAIL + 1)); FAILED_EXERCISES+=("$num"); else TOTAL_PASS=$((TOTAL_PASS + 1)); fi
}

run_test "01"; run_test "02"; run_test "03"; run_test "04"; run_test "05"; run_test "06"

echo ""
echo "${BOLD}=========================================${RESET}"
echo "${BOLD}  Final Report${RESET}"
echo "${BOLD}=========================================${RESET}"
echo ""
echo "  Exercises run:     $TESTS_RUN"
echo "  Exercises passed:  $TOTAL_PASS"
echo "  Exercises failed:  $TOTAL_FAIL"
echo "  Exercises skipped: $TESTS_SKIPPED"
if [[ "$TOTAL_FAIL" -gt 0 ]]; then echo ""; printf "${RED}${BOLD}  FAILED exercises: %s${RESET}\n" "${FAILED_EXERCISES[*]}"; exit 1
else echo ""; printf "${GREEN}${BOLD}  All exercises passed!${RESET}\n"; exit 0; fi
