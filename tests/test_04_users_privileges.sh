#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 4 — Users and Privileges${RESET}"
echo ""

# Create read-only user
ssh_vm "sudo -u postgres psql -c \"CREATE USER reader WITH PASSWORD 'Reader123!'; GRANT CONNECT ON DATABASE testdb TO reader;\"" >/dev/null
ssh_vm "sudo -u postgres psql -d testdb -c \"GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;\"" >/dev/null

# reader can SELECT
read_result=$(ssh_vm "PGPASSWORD='Reader123!' psql -U reader -d testdb -t -A -c 'SELECT COUNT(*) FROM users;'" 2>/dev/null)
assert_contains "Read-only user can SELECT" "$read_result" "[0-9]"

# reader cannot INSERT
insert_result=$(ssh_vm "PGPASSWORD='Reader123!' psql -U reader -d testdb -c \"INSERT INTO users (name,email) VALUES ('hack','h@h');\" 2>&1") || true
assert_contains "Read-only user cannot INSERT" "$insert_result" "denied|ERROR|permission denied"

# Drop user
ssh_vm "sudo -u postgres psql -d testdb -c \"REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reader;\"" >/dev/null
ssh_vm "sudo -u postgres psql -c \"DROP USER IF EXISTS reader;\"" >/dev/null

report_results "Exercise 4"
