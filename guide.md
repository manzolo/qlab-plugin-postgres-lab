# PostgreSQL Lab — Step-by-Step Guide

This guide walks you through understanding and managing **PostgreSQL**, a powerful open-source object-relational database system. PostgreSQL is known for its reliability, feature robustness, and standards compliance, and is used by organizations from startups to enterprises.

By the end of this lab you will understand SQL queries, data manipulation, user management, database administration, backups, and basic security practices with PostgreSQL.

## Prerequisites

Start the lab and wait for the VM to finish booting (~90 seconds):

```bash
qlab run postgres-lab
```

Connect to the VM:

```bash
qlab shell postgres-lab
```

Wait for cloud-init:

```bash
cloud-init status --wait
```

## Credentials

- **SSH:** `labuser` / `labpass`
- **PostgreSQL:** `labuser` / `labpass` (full access to `testdb`)
- **PostgreSQL superuser:** via `sudo -u postgres psql` (peer authentication)
- **pgAdmin:** `labuser@lab.local` / `labpass`

## Ports

| Service    | Host Port | VM Port |
|------------|-----------|---------|
| SSH        | dynamic   | 22      |
| PostgreSQL | dynamic   | 5432    |
| pgAdmin    | dynamic   | 80      |

---

## Exercise 01 — PostgreSQL Anatomy

**VM:** postgres-lab
**Goal:** Understand how PostgreSQL is structured.

PostgreSQL organizes data in a hierarchy: a cluster contains databases, databases contain schemas, schemas contain tables, tables contain rows and columns. The default schema is `public`. Understanding this structure is the foundation for everything else.

### 1.1 Check PostgreSQL is running

```bash
systemctl status postgresql
```

### 1.2 Connect to PostgreSQL

```bash
psql -U labuser -d testdb
```

If prompted for a password, enter `labpass`.

### 1.3 List databases

```sql
\l
```

**Expected output:** You should see `testdb`, `postgres`, `template0`, and `template1`.

### 1.4 List tables in testdb

```sql
\dt
```

**Expected output:**
```
          List of relations
 Schema |  Name  | Type  |  Owner
--------+--------+-------+---------
 public | orders | table | labuser
 public | users  | table | labuser
```

### 1.5 Describe table structure

```sql
\d users
\d orders
```

### 1.6 Check server status

```sql
SELECT version();
SELECT now() - pg_postmaster_start_time() AS uptime;
```

Type `\q` to leave the psql prompt.

**Verification:** You can connect, see `testdb` with `users` and `orders` tables.

---

## Exercise 02 — SQL Queries

**VM:** postgres-lab
**Goal:** Write SELECT queries to retrieve and analyze data.

SQL (Structured Query Language) is the universal language for relational databases. Reading data efficiently is the most common database operation — before you can modify data, you need to find it.

### 2.1 View all users

```sql
SELECT * FROM users;
```

### 2.2 Filter with WHERE

```sql
SELECT name, email FROM users WHERE id > 2;
```

### 2.3 Sort results

```sql
SELECT * FROM users ORDER BY name ASC;
SELECT * FROM users ORDER BY id DESC LIMIT 3;
```

### 2.4 Join tables

```sql
SELECT u.name, o.product, o.amount
FROM users u
JOIN orders o ON u.id = o.user_id;
```

This combines data from both tables — each order shown with the user's name.

### 2.5 Left Join (include users without orders)

```sql
SELECT u.name, COALESCE(o.product, 'No orders') AS product
FROM users u
LEFT JOIN orders o ON u.id = o.user_id;
```

### 2.6 Aggregate functions

```sql
SELECT COUNT(*) AS total_orders FROM orders;
SELECT SUM(amount) AS total_revenue FROM orders;
SELECT user_id, COUNT(*) AS order_count FROM orders GROUP BY user_id;
```

**Verification:** Queries return results from both tables, joins work, aggregates produce summaries.

---

## Exercise 03 — Data Manipulation

**VM:** postgres-lab
**Goal:** Insert, update, and delete data, and understand transactions.

Transactions ensure that a group of operations either all succeed or all fail — this is critical for data consistency. Imagine transferring money: you must debit one account AND credit another, never just one.

### 3.1 Insert a new user

```sql
INSERT INTO users (name, email) VALUES ('Diana', 'diana@example.com');
SELECT * FROM users WHERE name = 'Diana';
```

### 3.2 Update a record

```sql
UPDATE users SET email = 'diana.new@example.com' WHERE name = 'Diana';
SELECT * FROM users WHERE name = 'Diana';
```

### 3.3 Delete a record

```sql
DELETE FROM users WHERE name = 'Diana';
SELECT * FROM users WHERE name = 'Diana';
```

Should return zero rows.

### 3.4 Transactions — COMMIT

```sql
BEGIN;
INSERT INTO users (name, email) VALUES ('Eve', 'eve@example.com');
SELECT * FROM users WHERE name = 'Eve';  -- visible within transaction
COMMIT;
SELECT * FROM users WHERE name = 'Eve';  -- still visible after commit
```

### 3.5 Transactions — ROLLBACK

```sql
BEGIN;
INSERT INTO users (name, email) VALUES ('Frank', 'frank@example.com');
SELECT * FROM users WHERE name = 'Frank';  -- visible
ROLLBACK;
SELECT * FROM users WHERE name = 'Frank';  -- gone!
```

### 3.6 Clean up

```sql
DELETE FROM users WHERE name IN ('Eve', 'Frank', 'Diana');
```

**Verification:** INSERT adds rows, ROLLBACK undoes changes, COMMIT makes them permanent.

---

## Exercise 04 — Users and Privileges

**VM:** postgres-lab
**Goal:** Manage PostgreSQL users and the principle of least privilege.

Every application should connect to the database with its own user that has only the permissions it needs. This limits the damage if the application is compromised.

### 4.1 Check current user

```sql
SELECT current_user;
SELECT current_database();
```

### 4.2 Create a read-only user (as superuser)

```bash
sudo -u postgres psql
```

```sql
CREATE USER reader WITH PASSWORD 'Reader123!';
GRANT CONNECT ON DATABASE testdb TO reader;
\c testdb
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
\q
```

### 4.3 Test the read-only user

```bash
PGPASSWORD='Reader123!' psql -h 127.0.0.1 -U reader -d testdb
```

```sql
SELECT * FROM users;  -- works
INSERT INTO users (name, email) VALUES ('Hacker', 'hack@evil.com');  -- ERROR!
\q
```

**Expected error:**
```
ERROR:  permission denied for table users
```

### 4.4 Revoke and drop the user

```bash
sudo -u postgres psql
```

```sql
\c testdb
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reader;
\c postgres
REVOKE ALL ON DATABASE testdb FROM reader;
DROP USER reader;
\q
```

**Verification:** Read-only user can SELECT but not INSERT/UPDATE/DELETE.

---

## Exercise 05 — Database Administration

**VM:** postgres-lab
**Goal:** Create databases, modify tables, and perform backups.

### 5.1 Create a new database

Database creation requires the CREATEDB privilege (labuser has it):

```bash
PGPASSWORD=labpass psql -U labuser
```

```sql
CREATE DATABASE testlab;
\c testlab
CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    grade INT
);
INSERT INTO students (name, grade) VALUES ('Alice', 90), ('Bob', 85);
SELECT * FROM students;
```

### 5.2 Alter a table

```sql
ALTER TABLE students ADD COLUMN email VARCHAR(255);
\d students
```

### 5.3 Create an index

```sql
CREATE INDEX idx_name ON students(name);
\di
```

### 5.4 Backup with pg_dump

```bash
# Exit psql first, then:
PGPASSWORD=labpass pg_dump -U labuser testdb > /tmp/testdb_backup.sql
ls -la /tmp/testdb_backup.sql
head -20 /tmp/testdb_backup.sql
```

### 5.5 Restore from backup

```bash
PGPASSWORD=labpass psql -U labuser testlab < /tmp/testdb_backup.sql
```

### 5.6 Clean up

```bash
PGPASSWORD=labpass psql -U labuser -c "DROP DATABASE testlab;"
rm -f /tmp/testdb_backup.sql
```

**Verification:** Database creation, ALTER TABLE, indexes, and pg_dump all work.

---

## Exercise 06 — Security and Configuration

**VM:** postgres-lab
**Goal:** Understand PostgreSQL configuration and security settings.

### 6.1 Find configuration files

```bash
sudo -u postgres psql -c "SHOW config_file;"
sudo -u postgres psql -c "SHOW hba_file;"
```

### 6.2 Check listen_addresses

```bash
sudo -u postgres psql -c "SHOW listen_addresses;"
```

**Expected output:**
```
 listen_addresses
------------------
 *
```

This means PostgreSQL accepts connections from any IP (needed for host access via port forwarding).

### 6.3 Check pg_hba.conf

```bash
sudo cat $(sudo -u postgres psql -t -A -c "SHOW hba_file;")
```

This file controls client authentication — which users can connect from which hosts.

### 6.4 Check server variables

```bash
PGPASSWORD=labpass psql -U labuser -d testdb -c "SHOW max_connections;"
PGPASSWORD=labpass psql -U labuser -d testdb -c "SELECT version();"
```

### 6.5 Check active connections

```bash
PGPASSWORD=labpass psql -U labuser -d testdb -c "SELECT pid, usename, datname, state FROM pg_stat_activity WHERE state IS NOT NULL;"
```

### 6.6 Check error log location

```bash
sudo -u postgres psql -c "SHOW log_directory;"
sudo -u postgres psql -c "SHOW logging_collector;"
```

**Verification:** Configuration files exist, listen_addresses is set, server variables are queryable.

---

## Troubleshooting

### Can't connect to PostgreSQL
```bash
systemctl status postgresql
sudo journalctl -u postgresql --no-pager -n 20
```

### Access denied
```bash
# Try as superuser via peer auth
sudo -u postgres psql
# Check grants
\du                    -- list users
\l                     -- list databases with permissions
```

### Table doesn't exist
```sql
\c testdb
\dt
```

### Packages not installed
```bash
cloud-init status --wait
```
