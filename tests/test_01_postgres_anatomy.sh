#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 1 — PostgreSQL Anatomy${RESET}"
echo ""

status=$(ssh_vm "systemctl is-active postgresql")
assert_contains "PostgreSQL service is active" "$status" "^active$"

dbs=$(psql_query "SELECT datname FROM pg_database;")
assert_contains "testdb database exists" "$dbs" "testdb"

tables=$(psql_query "\dt" 2>/dev/null || psql_query "SELECT tablename FROM pg_tables WHERE schemaname='public';")
assert_contains "users table exists" "$tables" "users"
assert_contains "orders table exists" "$tables" "orders"

version=$(psql_query "SELECT version();")
assert_contains "PostgreSQL version is available" "$version" "[0-9]+\."

users_data=$(psql_query "SELECT COUNT(*) FROM users;")
assert_contains "users table has data" "$users_data" "[1-9]"

report_results "Exercise 1"
