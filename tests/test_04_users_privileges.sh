#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 4 — Users and Privileges${RESET}"
echo ""

# Create read-only user (clean up first in case it exists from a previous run)
ssh_vm "sudo -u postgres psql -d testdb -c 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reader;' 2>/dev/null || true; sudo -u postgres psql -c 'REVOKE ALL ON DATABASE testdb FROM reader;' 2>/dev/null || true; sudo -u postgres psql -c 'DROP USER IF EXISTS reader;'" >/dev/null 2>&1 || true
ssh_vm "sudo -u postgres psql -c \"CREATE USER reader WITH PASSWORD 'Reader123!'\"" >/dev/null
ssh_vm "sudo -u postgres psql -c 'GRANT CONNECT ON DATABASE testdb TO reader;'" >/dev/null
ssh_vm "sudo -u postgres psql -d testdb -c 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;'" >/dev/null

# reader can SELECT (connect via host to use password auth instead of peer)
read_result=$(ssh_vm "PGPASSWORD='Reader123!' psql -h 127.0.0.1 -U reader -d testdb -t -A -c 'SELECT COUNT(*) FROM users;'" 2>/dev/null)
assert_contains "Read-only user can SELECT" "$read_result" "[0-9]"

# reader cannot INSERT
insert_result=$(ssh_vm "PGPASSWORD='Reader123!' psql -h 127.0.0.1 -U reader -d testdb -c \"INSERT INTO users (name,email) VALUES ('hack','h@h');\" 2>&1") || true
assert_contains "Read-only user cannot INSERT" "$insert_result" "denied|ERROR|permission denied"

# Drop user
ssh_vm "sudo -u postgres psql -d testdb -c \"REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reader;\"" >/dev/null
ssh_vm "sudo -u postgres psql -c \"REVOKE ALL ON DATABASE testdb FROM reader;\"" >/dev/null
ssh_vm "sudo -u postgres psql -c \"DROP USER IF EXISTS reader;\"" >/dev/null

report_results "Exercise 4"
