---
kicker: QLab · postgres-lab
title: |
  PostgreSQL, and the
  rows that do not change
subtitle: >
  A cluster of cooperating processes, an authentication file that decides who
  may connect from where, and MVCC shown directly — the same row before and
  after an UPDATE, with the transaction ids visible. Captured from a running lab.
facts:
  - [Command, "`qlab run postgres-lab`"]
  - [VM, "`postgres-lab`, 5432 on a dynamic host port"]
  - [Credentials, "`labuser` / `labpass`"]
  - [Outcome, "`qlab test postgres-lab` → 6 exercises, all passed"]
---

## 1. A cluster is several processes

{{evidence:version as=shell}}

{{evidence:processes}}

One supervisor and a set of specialists, each named after its job. They are
worth knowing by name, because they are what you see in `ps` when something is
wrong:

- **checkpointer** — flushes dirty pages and marks a point the database can
  recover from.
- **walwriter** — writes the write-ahead log. Every change is recorded there
  *before* it touches the data files, which is what makes crash recovery
  possible.
- **autovacuum launcher** — reclaims the dead row versions that section 4 is
  about. Left disabled, a busy table grows without bound.
- **background writer**, **stats collector**, **logical replication launcher**.

Postgres also calls a running instance a **cluster**: one server, one data
directory, many databases. That word does not mean several machines here.

{{evidence:listening}}

{{evidence:databases}}

`template0` and `template1` are not clutter: a new database is a copy of a
template. Anything you install into `template1` appears in every database
created afterwards; `template0` is the pristine one you can always fall back to.

## 2. Who may connect, from where, and how

{{evidence:hba}}

`pg_hba.conf` is read top to bottom and the **first matching line wins**. Each
line is: connection type, database, user, address, method.

- `local ... peer` — over the unix socket, PostgreSQL asks the kernel which OS
  user you are and matches it to a role of the same name. No password exists.
  This is why `sudo -u postgres psql` works and `psql -U postgres` as another OS
  user does not.
- `host ... 127.0.0.1/32 md5` — over TCP, a password is required.

{{evidence:peer-vs-md5 as=shell}}

The same server, two connections, two identities — and `inet_server_addr()`
returns NULL over the socket, which is a neat way to tell which path you took.

:::warn The last line of that file
`host all all 0.0.0.0/0 md5` accepts a password connection from any address on
earth, to any database, as any role. It is here so you can point a GUI at the
lab, and it is precisely the line to remove on anything real.
:::

{{evidence:roles}}

Postgres has no separate notion of "user" and "group": both are **roles**, and
a role that may log in is what other systems call a user. `postgres` is the
superuser; `labuser` may only create databases.

## 3. A join, and what the planner did with it

{{evidence:query as=shell}}

`EXPLAIN ANALYZE` does not estimate — it runs the query and reports what
actually happened, including real timings and row counts. The gap between
`rows=` estimated and `actual rows=` is the first thing to look at when a query
is slow: if the planner's estimate is far off, it chose its strategy from bad
information, and the fix is usually statistics rather than a different query.

## 4. MVCC, visible

{{evidence:mvcc as=shell}}

This is PostgreSQL's central design decision, and here it is in the open.

Every row carries two hidden columns. **`xmin`** is the transaction that created
this version of the row; **`xmax`** is the transaction that deleted or locked it,
or `0` if none has.

Look at row 1 before and after the `UPDATE`. Its `xmin` changed. Postgres did
not modify the row in place — it wrote a **new version** of it, and the old
version is still on disk, now invisible to new transactions. That is why an
`UPDATE` can be as expensive as an `INSERT`, and why readers never block
writers: a reader simply keeps seeing the version that was current when it
started.

The cost is that dead versions accumulate. Reclaiming them is exactly what
`VACUUM`, and the autovacuum launcher in the process list above, exists to do.

## 5. Verification

{{evidence:qlab-test grep="Exercise [0-9]+:|Exercises |All exercises" as=shell}}

## 6. What to take away

- A cluster is one server with many databases, not many machines.
- `pg_hba.conf`: first match wins. Order matters more than content.
- `peer` authenticates by OS identity over the socket; `md5` wants a password
  over TCP. Most "it works with sudo but not otherwise" confusion is this.
- Users and groups are both roles.
- `UPDATE` writes a new row version. Readers do not block writers, and `VACUUM`
  is what pays the bill.
- `EXPLAIN ANALYZE` runs the query. Compare estimated rows against actual.

`guide.md` in the plugin carries the exercises: queries, data manipulation,
roles and privileges, backup with `pg_dump`, and configuration.
