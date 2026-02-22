#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 3 — Data Manipulation${RESET}"
echo ""

# INSERT
psql_query "INSERT INTO users (name, email) VALUES ('TestUser', 'test@test.com');" >/dev/null
inserted=$(psql_query "SELECT name FROM users WHERE name='TestUser';")
assert_contains "INSERT adds a row" "$inserted" "TestUser"

# UPDATE
psql_query "UPDATE users SET email='updated@test.com' WHERE name='TestUser';" >/dev/null
updated=$(psql_query "SELECT email FROM users WHERE name='TestUser';")
assert_contains "UPDATE modifies data" "$updated" "updated@test.com"

# DELETE
psql_query "DELETE FROM users WHERE name='TestUser';" >/dev/null
deleted=$(psql_query "SELECT COUNT(*) FROM users WHERE name='TestUser';")
assert_contains "DELETE removes the row" "$deleted" "^0$"

# ROLLBACK
psql_query "BEGIN; INSERT INTO users (name, email) VALUES ('RollbackUser', 'rb@test.com'); ROLLBACK;" >/dev/null
rollback=$(psql_query "SELECT COUNT(*) FROM users WHERE name='RollbackUser';")
assert_contains "ROLLBACK undoes INSERT" "$rollback" "^0$"

# COMMIT
psql_query "BEGIN; INSERT INTO users (name, email) VALUES ('CommitUser', 'cm@test.com'); COMMIT;" >/dev/null
committed=$(psql_query "SELECT COUNT(*) FROM users WHERE name='CommitUser';")
assert_contains "COMMIT persists INSERT" "$committed" "^1$"

# Cleanup
psql_query "DELETE FROM users WHERE name IN ('TestUser','RollbackUser','CommitUser');" >/dev/null 2>&1

report_results "Exercise 3"
