#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 6 — Security and Configuration${RESET}"
echo ""

# Config files exist
assert "PostgreSQL config directory exists" ssh_vm "test -d /etc/postgresql"
assert "postgresql.conf exists" ssh_vm "find /etc/postgresql -name postgresql.conf | grep -q postgresql.conf"

# Listen addresses
listen=$(ssh_vm "grep listen_addresses /etc/postgresql/*/main/postgresql.conf | grep -v '^#'" 2>/dev/null || ssh_vm "sudo -u postgres psql -t -A -c \"SHOW listen_addresses;\"")
assert_contains "listen_addresses is configured" "$listen" "listen_addresses|\\*"

# Server variables
version=$(psql_query "SELECT version();")
assert_contains "Server version is queryable" "$version" "[0-9]"

max_conn=$(psql_query "SHOW max_connections;")
assert_contains "max_connections is queryable" "$max_conn" "[0-9]"

# Active connections
procs=$(psql_query "SELECT count(*) FROM pg_stat_activity;")
assert_contains "pg_stat_activity is queryable" "$procs" "[0-9]"

# Port 5432 is listening
ports=$(ssh_vm "sudo ss -tlnp | grep ':5432'")
assert_contains "PostgreSQL port 5432 is listening" "$ports" ":5432"

report_results "Exercise 6"
