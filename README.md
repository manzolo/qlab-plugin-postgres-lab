# postgres-lab — PostgreSQL Database Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots a virtual machine with PostgreSQL pre-installed, a sample database with test data, pgAdmin for web-based management, and port forwarding for host access.

## Objectives

- Learn how to connect to PostgreSQL and explore databases
- Create databases, tables, and run SQL queries
- Manage users and permissions
- Perform backups and restores with pg_dump
- Access PostgreSQL from the host via port forwarding
- Use pgAdmin for web-based database management

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu 22.04 cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` with PostgreSQL installation and sample data setup
3. **ISO generation**: Packs cloud-init files into a small ISO (cidata)
4. **Overlay disk**: Creates a COW disk on top of the base image (original stays untouched)
5. **QEMU boot**: Starts the VM in background with SSH, PostgreSQL, and HTTP port forwarding

## Credentials

- **SSH Username:** `labuser`
- **SSH Password:** `labpass`
- **PostgreSQL superuser:** `sudo -u postgres psql` (peer auth, no password)
- **PostgreSQL labuser:** `labuser` / `labpass` (has privileges on `testdb`)
- **pgAdmin:** `labuser@lab.local` / `labpass`

## Ports

| Service    | Host Port | VM Port |
|------------|-----------|---------|
| SSH        | dynamic   | 22      |
| PostgreSQL | dynamic   | 5432    |
| pgAdmin    | dynamic   | 80      |

> All host ports are dynamically allocated. Use `qlab ports` to see the actual mappings.

## Usage

```bash
# Install the plugin
qlab install postgres-lab

# Run the lab
qlab run postgres-lab

# Wait ~90s for boot and package installation, then:

# Connect via SSH
qlab shell postgres-lab

# Inside the VM:
sudo -u postgres psql                           # connect as superuser
psql -U labuser -d testdb                       # connect as labuser
SELECT * FROM users;                            # query sample data

# From the host (check PostgreSQL port with 'qlab ports'):
psql -h 127.0.0.1 -p <pg_port> -U labuser -d testdb

# Stop the VM
qlab stop postgres-lab
```

## Exercises

> **New to PostgreSQL?** See the [Step-by-Step Guide](guide.md) for complete walkthroughs with full SQL examples.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **PostgreSQL Anatomy** | Explore PostgreSQL installation, connect, and navigate databases |
| 2 | **SQL Queries** | Run SELECT, WHERE, ORDER BY, JOIN on sample data |
| 3 | **Data Manipulation** | INSERT, UPDATE, DELETE rows and manage tables |
| 4 | **Users and Privileges** | Create users, GRANT/REVOKE permissions |
| 5 | **Database Administration** | Backup with pg_dump, restore, check status |
| 6 | **Security and Configuration** | Review listen_addresses, pg_hba.conf, and logging |

## Automated Tests

An automated test suite validates the exercises against a running VM:

```bash
# Start the lab first
qlab run postgres-lab
# Wait ~90s for cloud-init, then run all tests
qlab test postgres-lab
```

## Resetting

To start fresh, stop and re-run:

```bash
qlab stop postgres-lab
qlab run postgres-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
