#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Exercise 5 — Database Administration${RESET}"
echo ""

# Create database and table
ssh_vm "sudo -u postgres psql -c 'CREATE DATABASE testlab OWNER labuser;'" >/dev/null
psql_query_db testlab "CREATE TABLE IF NOT EXISTS students (id SERIAL PRIMARY KEY, name VARCHAR(100), grade INT);" >/dev/null
psql_query_db testlab "INSERT INTO students (name, grade) VALUES ('Alice', 90);" >/dev/null

created=$(ssh_vm "PGPASSWORD=labpass psql -U labuser -t -A -c \"SELECT datname FROM pg_database WHERE datname='testlab';\"")
assert_contains "Database testlab created" "$created" "testlab"

data=$(psql_query_db testlab "SELECT name FROM students;")
assert_contains "Table has data" "$data" "Alice"

# ALTER TABLE
psql_query_db testlab "ALTER TABLE students ADD COLUMN email VARCHAR(255);" >/dev/null
columns=$(psql_query_db testlab "SELECT column_name FROM information_schema.columns WHERE table_name='students';")
assert_contains "ALTER TABLE added email column" "$columns" "email"

# INDEX
psql_query_db testlab "CREATE INDEX idx_name ON students(name);" >/dev/null 2>&1 || true
indexes=$(psql_query_db testlab "SELECT indexname FROM pg_indexes WHERE tablename='students';")
assert_contains "Index created" "$indexes" "idx_name"

# pg_dump
assert "pg_dump works" ssh_vm "PGPASSWORD=labpass pg_dump -U labuser testdb > /tmp/testdb_backup.sql"
assert "Backup file exists" ssh_vm "test -s /tmp/testdb_backup.sql"

# Cleanup
ssh_vm "sudo -u postgres psql -c 'DROP DATABASE IF EXISTS testlab;'" >/dev/null
ssh_vm "rm -f /tmp/testdb_backup.sql" >/dev/null

report_results "Exercise 5"
