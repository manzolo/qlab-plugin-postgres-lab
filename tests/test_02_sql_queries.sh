#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 2 — SQL Queries${RESET}"
echo ""

all_users=$(psql_query "SELECT * FROM users;")
assert_contains "SELECT * returns data" "$all_users" "."

filtered=$(psql_query "SELECT name FROM users WHERE id = 1;")
assert_contains "WHERE clause filters correctly" "$filtered" "."

ordered=$(psql_query "SELECT name FROM users ORDER BY name ASC;")
assert_contains "ORDER BY returns results" "$ordered" "."

join_result=$(psql_query "SELECT u.name, o.product FROM users u JOIN orders o ON u.id = o.user_id;")
assert_contains "JOIN returns combined results" "$join_result" "."

count=$(psql_query "SELECT COUNT(*) FROM orders;")
assert_contains "COUNT aggregate works" "$count" "[0-9]"

sum_result=$(psql_query "SELECT SUM(amount) FROM orders;")
assert_contains "SUM aggregate works" "$sum_result" "[0-9]"

report_results "Exercise 2"
