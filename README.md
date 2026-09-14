# postgres-lab — PostgreSQL Database Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Walkthrough](https://img.shields.io/badge/walkthrough-EN%20%26%20IT-informational)](docs/walkthrough-en.pdf)

A single-VM [QLab](https://github.com/manzolo/qlab) lab with PostgreSQL and a web pgAdmin,
a sample database, and both ports forwarded to the host — for learning SQL, roles and
privileges, and backups by running them.

## Quick start

```bash
qlab install postgres-lab
qlab run postgres-lab       # boots 1 VM (~60s)
qlab shell postgres-lab     # log in: labuser / labpass
qlab test postgres-lab      # run the automated checks
qlab stop postgres-lab
```

Inside the VM: `sudo -u postgres psql` (superuser) or `psql -U labuser -d testdb`.
From the host: pgAdmin in a browser, or `psql -h 127.0.0.1 -p <port> -U labuser testdb`
— find the ports with `qlab ports`.

## What's inside

| # | Exercise | What you do |
|---|----------|-------------|
| 1 | PostgreSQL anatomy | connect, explore databases, navigate the server |
| 2 | SQL queries | `SELECT` / `WHERE` / `ORDER BY` / `JOIN` on sample data |
| 3 | Data manipulation | `INSERT` / `UPDATE` / `DELETE`, manage tables |
| 4 | Roles & privileges | create roles, `GRANT` / `REVOKE` |
| 5 | Administration | backup with `pg_dump`, restore, check status |
| 6 | Security & config | `listen_addresses`, `pg_hba.conf`, logging |

## Access

| | |
|---|---|
| **SSH** | `labuser` / `labpass` |
| **PostgreSQL superuser** | `sudo -u postgres psql` (peer auth) |
| **PostgreSQL user** | `labuser` / `labpass`, privileges on `testdb` |
| **pgAdmin** | `labuser@lab.example.com` / `labpass` |
| **Ports** | SSH + PostgreSQL (5432) + pgAdmin, dynamically allocated — see `qlab ports` |

## Learn more

- 📖 **[Step-by-step guide](guide.md)** — every exercise with full SQL and expected output
- 📄 **Illustrated walkthrough** — a real run, captured live: **[English](docs/walkthrough-en.pdf)** · **[Italiano](docs/walkthrough-it.pdf)**
- 🧩 **[QLab](https://github.com/manzolo/qlab)** — the plugin runner: how install, overlays and cloud-init work
