---
kicker: QLab · postgres-lab
title: |
  PostgreSQL, e le righe
  che non cambiano
subtitle: >
  Un gruppo di processi che cooperano, un file di autenticazione che decide chi
  può connettersi e da dove, e l'MVCC mostrato direttamente — la stessa riga
  prima e dopo un UPDATE, con gli id di transazione in chiaro. Da un lab acceso.
facts:
  - [Comando, "`qlab run postgres-lab`"]
  - [VM, "`postgres-lab`, 5432 su porta host dinamica"]
  - [Credenziali, "`labuser` / `labpass`"]
  - [Esito, "`qlab test postgres-lab` → 6 esercizi, tutti superati"]
---

## 1. Un cluster sono più processi

{{evidence:version as=shell}}

{{evidence:processes}}

Un supervisore e una serie di specialisti, ciascuno chiamato col proprio
mestiere. Vale la pena conoscerli per nome, perché sono quello che si vede in
`ps` quando qualcosa non va:

- **checkpointer** — scarica le pagine sporche e segna un punto da cui il
  database può ripartire.
- **walwriter** — scrive il write-ahead log. Ogni modifica viene registrata lì
  *prima* di toccare i file dati, ed è ciò che rende possibile il recupero dopo
  un crash.
- **autovacuum launcher** — recupera le versioni di riga morte di cui parla la
  sezione 4. Lasciato spento, una tabella movimentata cresce senza limite.
- **background writer**, **stats collector**, **logical replication launcher**.

Postgres chiama **cluster** un'istanza in esecuzione: un server, una directory
dati, molti database. Qui quella parola non significa più macchine.

{{evidence:listening}}

{{evidence:databases}}

`template0` e `template1` non sono ingombro: un database nuovo è una copia di un
template. Tutto ciò che si installa in `template1` comparirà in ogni database
creato dopo; `template0` è quello intatto a cui si può sempre tornare.

## 2. Chi può connettersi, da dove e come

{{evidence:hba}}

`pg_hba.conf` si legge dall'alto in basso e **vince la prima riga che
corrisponde**. Ogni riga è: tipo di connessione, database, utente, indirizzo,
metodo.

- `local ... peer` — sul socket unix, PostgreSQL chiede al kernel quale utente
  di sistema siete e lo fa corrispondere a un ruolo con lo stesso nome. Non
  esiste alcuna password. È per questo che `sudo -u postgres psql` funziona e
  `psql -U postgres` da un altro utente di sistema no.
- `host ... 127.0.0.1/32 md5` — via TCP, serve una password.

{{evidence:peer-vs-md5 as=shell}}

Lo stesso server, due connessioni, due identità — e `inet_server_addr()`
restituisce NULL sul socket, che è un modo elegante di sapere quale strada si è
presa.

:::warn L'ultima riga di quel file
`host all all 0.0.0.0/0 md5` accetta una connessione con password da qualsiasi
indirizzo della Terra, verso qualsiasi database, come qualsiasi ruolo. È lì
perché si possa puntare un'interfaccia grafica al laboratorio, ed è esattamente
la riga da togliere su qualunque cosa di vero.
:::

{{evidence:roles}}

Postgres non distingue fra «utente» e «gruppo»: sono entrambi **ruoli**, e un
ruolo che può fare login è ciò che altri sistemi chiamano utente. `postgres` è
il superutente; `labuser` può solo creare database.

## 3. Una join, e cosa ne ha fatto il planner

{{evidence:query as=shell}}

`EXPLAIN ANALYZE` non stima: esegue la query e riferisce cosa è successo
davvero, tempi e conteggi reali compresi. Lo scarto fra le righe stimate
(`rows=`) e quelle effettive (`actual rows=`) è la prima cosa da guardare quando
una query è lenta: se la stima del planner è molto sbagliata, ha scelto la
strategia su informazioni sbagliate, e il rimedio di solito sono le statistiche,
non una query diversa.

## 4. L'MVCC, in chiaro

{{evidence:mvcc as=shell}}

È la decisione di progetto centrale di PostgreSQL, ed eccola allo scoperto.

Ogni riga porta due colonne nascoste. **`xmin`** è la transazione che ha creato
questa versione della riga; **`xmax`** è quella che l'ha cancellata o bloccata,
oppure `0` se nessuna l'ha fatto.

Si guardi la riga 1 prima e dopo l'`UPDATE`. Il suo `xmin` è cambiato. Postgres
non ha modificato la riga sul posto: ne ha scritto una **nuova versione**, e la
vecchia è ancora su disco, ora invisibile alle nuove transazioni. È per questo
che un `UPDATE` può costare quanto un `INSERT`, e per cui i lettori non bloccano
mai gli scrittori: un lettore continua semplicemente a vedere la versione che
era corrente quando è partito.

Il prezzo è che le versioni morte si accumulano. Recuperarle è esattamente ciò
per cui esistono `VACUUM` e l'autovacuum launcher visto sopra.

## 5. Verifica

{{evidence:qlab-test grep="Exercise [0-9]+:|Exercises |All exercises" as=shell}}

## 6. Cosa portarsi via

- Un cluster è un server con molti database, non molte macchine.
- `pg_hba.conf`: vince la prima corrispondenza. L'ordine conta più del
  contenuto.
- `peer` autentica tramite l'identità di sistema sul socket; `md5` vuole una
  password via TCP. Quasi tutta la confusione del tipo «con sudo funziona,
  altrimenti no» è questa.
- Utenti e gruppi sono entrambi ruoli.
- `UPDATE` scrive una nuova versione di riga. I lettori non bloccano gli
  scrittori, e il conto lo paga `VACUUM`.
- `EXPLAIN ANALYZE` esegue la query. Confrontate righe stimate ed effettive.

`guide.md` del plugin porta gli esercizi: interrogazioni, manipolazione dei
dati, ruoli e privilegi, backup con `pg_dump`, configurazione.
