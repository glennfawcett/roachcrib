# CockroachDB Cribsheet
Roachcrib is a "Crib Sheet" for Cockroach database commands.  This is a parking lot for various commands to navigate through the roach universe.  This is an ever evolving crib sheet that I initially created when developing a workshop.

Enjoy!!!

## Geo Partitioning

I seperated out the CribSheet commands specific to Geo Partitioning as it a pretty detailed topic.

* [Geo CribSheet](Geo.md)

## Tracing Golang /w pprof

* [tracing_golang.md](tracing_golang.md)

## Database Level Configuration 
```
root@localhost:26257/kv> show zone configuration for database mydatabase;
     target     |              raw_config_sql
+---------------+------------------------------------------+
  RANGE default | ALTER RANGE default CONFIGURE ZONE USING
                |     range_min_bytes = 16777216,
                |     range_max_bytes = 67108864,
                |     gc.ttlseconds = 90000,
                |     num_replicas = 3,
                |     constraints = '[]',
                |     lease_preferences = '[]'

ALTER DATABASE mydatabase CONFIGURE ZONE USING
  range_min_bytes = 0, 
  range_max_bytes = 90000, 
  gc.ttlseconds = 89999, 
  num_replicas = 5,
  constraints = '[-region=west]';
```

## EXPLAIN, ANALYZE, VECTORIZE
```
-- Explain Plan
EXPLAIN SELECT city, count(*) FROM rides;

-- Explain Analyze
EXPLAIN ANALYZE SELECT city, count(*) FROM rides;

-- Explain (opt,env) :: Gather formatted information
--   ddl, stats, query, explain 
EXPLAIN (opt,env) SELECT id FROM mytable where city = 'salem';

-- Explain (vec) :: Shows if Vectorization is possible
--
EXPLAIN (vec) SELECT city, state, count(*) from line_order group by 1,2;

-- Show Vectorize
SHOW session vectorize;

-- Enable/Disable Vectorize
SET session vectorize='auto';
SET session vectorize='experimental_on';
SET session vectorize='off';

-- Vectorize ON for Cluster
SET CLUSTER SETTING sql.defaults.vectorize=on

```

## Tracing 
```
root@:26257/tpcc> \set auto_trace on,kv
root@:26257/tpcc> select * from item limit 2;
  i_id | i_im_id |          i_name          | i_price | i_data
+------+---------+--------------------------+---------+--------+
     1 |    1122 | 9cdLXe0YhgLRrwsmd68P2bEl |   50.85 | Mask
     2 |    3335 | 1fcW8RsaCXoEzmssaF9m9cd  |    5.40 | Mask
(2 rows)

Time: 1.453325ms

             timestamp             |       age       |                                                 message                                                 |                tag                | location |    operation     | span
+----------------------------------+-----------------+---------------------------------------------------------------------------------------------------------+-----------------------------------+----------+------------------+------+
  2020-04-20 16:55:30.23844+00:00  | 00:00:00.000291 | querying next range at /Table/62/1                                                                      | [n1,client=[::1]:32906,user=root] |          | exec stmt        |    4
  2020-04-20 16:55:30.23893+00:00  | 00:00:00.00078  | Scan /Table/62/{1-2}                                                                                    | [n3]                              |          | table reader     |   10
  2020-04-20 16:55:30.238971+00:00 | 00:00:00.000822 | querying next range at /Table/62/1                                                                      | [n3,txn=b962ed40]                 |          | dist sender send |   12
  2020-04-20 16:55:30.238993+00:00 | 00:00:00.000844 | r93: sending batch 1 Scan to (n3,s3):3                                                                  | [n3,txn=b962ed40]                 |          | dist sender send |   12
  2020-04-20 16:55:30.239151+00:00 | 00:00:00.001002 | fetched: /item/primary/1/i_im_id/i_name/i_price/i_data -> /1122/'9cdLXe0YhgLRrwsmd68P2bEl'/50.85/'Mask' | [n3]                              |          | table reader     |   10
  2020-04-20 16:55:30.239169+00:00 | 00:00:00.001019 | fetched: /item/primary/2/i_im_id/i_name/i_price/i_data -> /3335/'1fcW8RsaCXoEzmssaF9m9cd'/5.40/'Mask'   | [n3]                              |          | table reader     |   10
  2020-04-20 16:55:30.239522+00:00 | 00:00:00.001372 | rows affected: 2                                                                                        | [n1,client=[::1]:32906,user=root] |          | exec stmt        |    4
(7 rows)
```

## JSON Tips

[JSON functions](https://www.cockroachlabs.com/docs/v19.2/functions-and-operators.html#jsonb-functions) are documented in details in our [doucmentation](https://www.cockroachlabs.com/docs/v19.2/functions-and-operators.html#jsonb-functions).  Please provide feedback via [github](https://github.com/cockroachdb/docs).
```
-- IMPORT / CREATE table from CSV
--
IMPORT TABLE myjson_table (
id INT PRIMARY KEY,
name STRING,
state STRING,
myjsoncol JSONB
) CSV DATA ('gs://mybucket/subdir/jsonfile.tsv')
WITH
    delimiter = e'\t';

-- IMPORT CSV data into existing table
--
IMPORT INTO myjson_table (id, name, state, myjsoncol)
CSV DATA (
    'gs://mybucket/subdir/jsonfile2.tsv'
)
WITH
    delimiter = e'\t';

-- JSON function for pretty print
--
select jsonb_pretty(myjsoncol) from myjson_table where name = 'Rosie';

-- Extract values from JSON object
--
select myjsoncol::JSONB->>'customer_id' from myjson_table;

-- Filter based on JSON values
--
select * from myjson_table where myjsoncol::JSONB->>'customer_id' ='429908572';
select * from myjson_table where myjsoncol::JSONB @> '{"customer_id": "429908572"}';


-- Index JSON column to improve JSON queries
--
CREATE INVERTED INDEX idx_myjson_table ON myjson_table(myjsoncol);

-- Create JSON table with Computed Columns to extract values 
--    Store JSON column in separate FAMILY
--
create table myjson_stored (
    id INT PRIMARY KEY,
    myjsoncol JSONB,
    cid STRING AS (myjsoncol::JSONB->>'customer_id') STORED,
    name STRING AS (myjsoncol::JSONB->>'name') STORED,
    amount INT AS (CAST(myjsoncol::JSONB->>'amount' as INT)) STORED,
    FAMILY "nonjsonvals" (id, customer_id, name, amount),
    FAMILY "blob" (myjsoncol)
);
```

## CANCEL runaway Queries
Our docs, have a great description on how to [manage](https://www.cockroachlabs.com/docs/stable/manage-long-running-queries.html) long running queries.  Regardless, you must first identify the query to be killed.

```
-- Show all Currently running queries
--
SQL> SHOW QUERIES;

              query_id             | node_id | user_name |              start               |                           query                            | client_address  | application_name | distributed |   phase
+----------------------------------+---------+-----------+----------------------------------+------------------------------------------------------------+-----------------+------------------+-------------+-----------+
  16066ceaa78da3240000000000000001 |       1 | root      | 2020-04-16 22:21:13.783805+00:00 | SHOW CLUSTER QUERIES                                       | 127.0.0.1:43064 | $ cockroach sql  |    false    | executing
  16066ce888ed70f40000000000000004 |       4 | root      | 2020-04-16 22:21:04.680043+00:00 | SELECT count(*) FROM order_line AS a CROSS JOIN order_line | 127.0.0.1:33746 | $ cockroach sql  |    true     | executing
(2 rows)

-- Show all queries running longer than 10 minutes running queries
--
SELECT * FROM [SHOW CLUSTER QUERIES]
      WHERE start < (now() - INTERVAL '10 minutes');
```
Once you find the culprit, simply supply the query_id to the cancel command making sure to quote the string:
```

SQL> CANCEL QUERY '16066ce888ed70f40000000000000004';

CANCEL QUERIES 1
```

## Primary Key != Distribution Key
CockroachDB creates ranges of data to distrubte data across the cluster.  These ranges are all based on the Primary Key.  First off, the primary key doesn't deteriming the distribution of data, the range size does.  Active ranges will be split and re-distributed based on load so as to best spread the activity.  This is all done for you so you don't have to worry about picking the proper distirbution key.  With CockroachDB, *Primary Key != Distibution Key*.

If you don't pick a primary key, CockroachDB will assign values. See the following example:

```
root@localhost:26257/kv> create table foo(id int);
CREATE TABLE
```
Notice that their is an extra *rowid* column embedded in the actual table.
```
root@localhost:26257/kv> show create table foo;
  table_name |         create_statement
+------------+----------------------------------+
  foo        | CREATE TABLE foo (
             |     id INT8 NULL,
             |     FAMILY "primary" (id, rowid)
             | )
(1 row)
```

This *rowid* column does not have to be considered for SQL operations.
```
root@localhost:26257/kv> insert into foo values (1),(2),(3);
INSERT 3

Time: 10.217799ms

root@localhost:26257/kv> select * from foo;
  id
+----+
   1
   2
   3
(3 rows)

Time: 792.589µs
```
CockroachDB does however allow the user to query the *rowid* values.
```

root@localhost:26257/kv> select id, rowid from foo;
  id |       rowid
+----+--------------------+
   1 | 547249987223158785
   2 | 547249987223224321
   3 | 547249987223257089
(3 rows)

Time: 807.845µs
```

## MISC Tidbits
```
-- Change Database Focus
--
USE mytest;

-- Show DDL for a Table /w Indexes
--
SHOW CREATE TABLE rides;
SELECT create_statement FROM [SHOW CREATE TABLE rides];

-- Show Running Queries
--
SHOW QUERIES;

-- Show Running Jobs
--
SHOW JOBS;
SELECT * FROM [SHOW JOBS] WHERE status='running';

-- Restore Database into different database name
--
CREATE DATABASE testmovr1;
RESTORE movr1.* FROM 'gs://geolabs/backup1' WITH into_db ='testmovr1';

-- Show Cluster Settings
--
select variable,value from [show cluster setting all];
select variable,value from [show cluster setting all] where variable like '%range%';

-- Disable Telemetry Diagnostics
--
SET CLUSTER SETTING diagnostics.reporting.enabled = false;
SET CLUSTER SETTING diagnostics.reporting.send_crash_reports = false;

-- Create Indexes that STORE values that are not part of the index or primary key
--   This is useful for WIDE tables.  It is a "consolidated view"  of a table fragment
--
CREATE INDEX idx_wide_storing ON big_measures(city, measure_id) storing (myval1, myval2, myval3);

--  TIME travel with Queries
--
SELECT id, fname, lname  
FROM customer AS OF SYSTEM TIME INTERVAL '-10m' 
WHERE id = 42;

-- Config for single node unit testing, NOT for production
--
ALTER RANGE default CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 120;
ALTER DATABASE system CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 120;
SET CLUSTER SETTING jobs.retention_time = '180s'
```

## Workload Edge Binary
There are a few workloads included in the Cockroach binary:

```
$ cockroach workload init
Usage:
  cockroach workload init [flags]
  cockroach workload init [command]

Available Commands:
  bank        [experimental] Bank models a set of accounts with currency balances
  intro       [experimental] Intro contains a single table with a hidden message
  kv          [experimental] KV reads and writes to keys spread randomly across the cluster.
  movr        [experimental] MovR is a fictional vehicle sharing company
  startrek    [experimental] Star Trek models episodes and quotes from the tv show
  tpcc        [experimental] TPC-C simulates a transaction processing workload using a rich schema of multiple tables
  ycsb        [experimental] YCSB is the Yahoo! Cloud Serving Benchmark
```

However, there are more in the shared github repository.  The latest Edge binary for the full compliment of workloads can be retrieved using:

```
wget https://edge-binaries.cockroachdb.com/cockroach/workload.LATEST
chmod 755 workload.LATEST
cp -i workload.LATEST /usr/local/bin/workload  
chmod u+x /usr/local/bin/workload
```

This binary includes the following workloads:
```
$ workload init
Usage:
  workload init [flags]
  workload init [command]

Available Commands:
  bank                   Bank models a set of accounts with currency balances
  bulkingest             bulkingest testdata is designed to produce a skewed distribution of KVs when ingested (in initial import or during later indexing)
  indexes                Indexes writes to a table with a variable number of secondary indexes
  interleavedpartitioned Tests the performance of tables that are both interleaved and partitioned
  intro                  Intro contains a single table with a hidden message
  json                   JSON reads and writes to keys spread (by default, uniformly at random) across the cluster
  kv                     KV reads and writes to keys spread randomly across the cluster.
  ledger                 Ledger simulates an accounting system using double-entry bookkeeping
  movr                   MovR is a fictional ride sharing company
  querybench             QueryBench runs queries from the specified file. The queries are run sequentially in each concurrent worker.
  querylog               Querylog is a tool that produces a workload based on the provided query log.
  queue                  A simple queue-like application load: inserts into a table in sequence (ordered by primary key), followed by the deletion of inserted rows starting from the beginning of the sequence.
  rand                   random writes to table
  roachmart              Roachmart models a geo-distributed online storefront with users and orders
  sqlsmith               sqlsmith is a random SQL query generator
  startrek               Star Trek models episodes and quotes from the tv show
  tpcc                   TPC-C simulates a transaction processing workload using a rich schema of multiple tables
  tpcds                  TPC-DS is a read-only workload of "decision support" queries on large datasets.
  tpch                   TPC-H is a read-only workload of "analytics" queries on large datasets.
  ycsb                   YCSB is the Yahoo! Cloud Serving Benchmark
```

## Java Hybernate Dialect for CockroachDB
The Cockroach Dialect for Java / Hybernate is currently under review.  Information regarding the CockroachDB dialect for Hybernate can be found here:
* [Documentation @CockroachDB](https://www.cockroachlabs.com/docs/stable/build-a-java-app-with-cockroachdb-hibernate.html)
* [https://github.com/hibernate/hibernate-orm/pull/3280](https://github.com/hibernate/hibernate-orm/pull/3280)

## Export Table Data

Example shows export 1000 rows from the customer table to a **tab** separated file:
```
root@:26257/tpcc> export into CSV 'nodelocal://1/custsamp' WITH delimiter = e'\t' from select * from customer limit 1000;
  filename | rows | bytes
-----------+------+---------
  n3.0.csv | 1000 | 578191

15:38 $ pwd
/Users/glenn/local/1/data/extern/custsamp
✔ ~/local/1/data/extern/custsamp
15:39 $ ls -ltrh
total 1136
-rw-------  1 glenn  staff   565K Jul 16 15:36 n3.0.csv

15:39 $ cat n3.0.csv |wc -l
    1000

15:40 $ head -1 n3.0.csv
1	1	0	y3v1U5yraPxxELo	OE	BARBARBAR	mssaF9m9cdLXe	lAgrnp8ueWN	ZrKB2O3Hzk13xW	OZ	077611111	5580696790858719	2006-01-02 15:04:05+00:00	GC	50000.00	0.4714	-10.00	10.00	1	0	haRF4E9zNHsJ7ZvyiJ3n2X1f4fJoMgn5buTDyUmQupcYMoPylHqYo89SqHqQ4HFVNpmnIWHyIowzQN2r4uSQJ8PYVLLLZk9Epp6cNEnaVrN3JXcrBCOuRRSlC0zvh9lctkhRvAvE5H6TtiDNPEJrcjAUOegvQ1Ol7SuF7jPf275wNDlEbdC58hrunlPfhoY1dORoIgb0VnxqkqbEWTXujHUOvCRfqCdVyc8gRGMfAd4nWB1rXYANQ0fa6ZQJJI2uTeFFazaVwxnN13XunKGV6AwCKxhJQVgXWaljKLJ7r175FAuGY
```

## Show grants from ALL databases
```
set sql_safe_updates=false;
set database to "";
show grants;

select distinct grantee, database_name from [show grants] order by 1 ;

select distinct grantee, database_name, privilege_type from [show grants] where grantee not in ('admin','root','public') order by 1;

    grantee   | database_name | privilege_type
--------------+---------------+-----------------
  admin2      | defaultdb     | ALL
  glennf      | bank          | ALL
  jpatutorial | springbootjpa | ALL
  maxroach    | bank          | ALL
  myuser      | customers     | ALL
  postgres    | defaultdb     | ALL
(6 rows)

```

## Session Level Application Setting 
Using this session level setting you can filter from within the statements page based on the application name.  A power tool to find the queries and compute the amount of work performed by each application.
 
`SET application_name = 'TAG YOUR APPLICATION'`


## Modify FK Constraints for UPDATE CASCADE

This example uses the `movr` DDL which is a workload included in the cockroach binary "`cockroach workload init movr`".

```sql
ALTER TABLE rides
DROP CONSTRAINT fk_city_ref_users,
 ADD CONSTRAINT fk_city_ref_users_cascasde FOREIGN KEY (city, rider_id) REFERENCES users(city, id)
              ON UPDATE CASCADE;

ALTER TABLE rides
DROP CONSTRAINT fk_vehicle_city_ref_vehicles,
 ADD CONSTRAINT fk_vehicle_city_ref_vehicles_cascade FOREIGN KEY (vehicle_city, vehicle_id) REFERENCES vehicles(city, id)
              ON UPDATE CASCADE;

ALTER TABLE vehicle_location_histories
DROP CONSTRAINT fk_city_ref_rides,
 ADD CONSTRAINT fk_city_ref_rides_cascade FOREIGN KEY (city, ride_id) REFERENCES rides(city, id)
              ON UPDATE CASCADE;
```

## How many vCPUs are in the cluster?

```sql
SELECT 
((SELECT value FROM crdb_internal.node_metrics WHERE name = 'sys.cpu.user.percent')
+
(SELECT value FROM crdb_internal.node_metrics WHERE name = 'sys.cpu.sys.percent'))
*
(SELECT value FROM crdb_internal.node_metrics WHERE name = 'liveness.livenodes')
/
(SELECT value FROM crdb_internal.node_metrics WHERE name = 'sys.cpu.combined.percent-normalized')
AS cluster_vcpus
;
```

## MASSIVE Truncate / Delete
Massive truncate/delete operations can cause pressure on GC operations.  
To address the following is helpful:
* Lower `gc.ttlseconds` on the object to be truncated
* Decrease retention period by splitting DDL into multiple objects
* Slow range operations
* * Decrease `kv.snapshot_rebalance.max_rate`... `8.0 MiB` -> `1.0 MiB` 

## JAVA tips!!
* `setReWriteBatchedInserts=true` for in JDBC connection string
* [Getting Started Docs](https://www.cockroachlabs.com/docs/stable/build-a-java-app-with-cockroachdb.html)
https://www.cockroachlabs.com/docs/stable/build-a-java-app-with-cockroachdb.html

## COMMIT Timestamp Embedded in hidden column :: `crdb_internal_mvcc_timestamp`
```
root@:26257/defaultdb> select *, crdb_internal_mvcc_timestamp from a;
  id |  b1  |  b2  |  crdb_internal_mvcc_timestamp
-----+------+------+---------------------------------
   1 | NULL | NULL | 1610313263319124000.0000000000
   2 |    2 | NULL | 1610313263319124000.0000000000
   3 | NULL |    3 | 1610313263319124000.0000000000
   4 |    4 |    4 | 1610313263319124000.0000000000
(4 rows)
```

## SQL TOP sessions
Count the number of top sessions running transactions with the same profile:

```sql
select substring(active_queries for 40) as SQL_snipit, 
       count(*) 
from [show sessions] 
group by 1
order by 2 desc;
```

## NODE_ID from SQL

The shifting of bits uses the method baked into CRDB for creating `unique_rowid()`.  A coleague then pointed out there is a `node_id()` function that can be used as well.

```sql
-- get node_id
--
SELECT (((unique_rowid()::bit(64))<<(64-15))>>(64-15))::INT;
  int8
--------
     4
     
SELECT crdb_internal.node_id();
  crdb_internal.node_id
-------------------------
                      4
```

## DELETE with LIMIT
If you have millions of rows to delete, it is not a good idea to 
run this as one statement in CockroachDB.  It is best to run
`DELETE` in a loop until the critera is deleting ZERO rows.
This can be done with the `cockroach` binary using the `--watch`
clause to repeat the statement.  When wrapped around a simple 
bash shell, it is pretty easy to do this on the fly.

```bash
cockroach sql --insecure --format csv --execute """
  DELETE FROM mybigtable
  WHERE my_timestamp < '_some_time_value'
  LIMIT 100
""" --watch 0.0001s |
while read d
do
  echo $d
  if [[ "$d" == "DELETE 0" ]]; then
     echo "DONE"
     exit
  fi
done
```

## EPOCH to TIMESTAMP conversion
Every row has a hidden column, `crdb_internal_mvcc_timestamp`, which is epoch nanoseconds 
used as a transaction timestamp.  This can be converted to TIMESTAMP like so:

```sql
SELECT * FROM t;

  a |  ts
----+-------
  1 | NULL

SELECT 
  experimental_strptime((crdb_internal_mvcc_timestamp/10^9)::string, '%s')::timestamp, *
FROM t;

  experimental_strptime | a |  ts
------------------------+---+-------
  2021-06-16 19:05:58   | 1 | NULL

```

## Orphan Ranges without Leases
These ranges will be cleaned up after GC, but end up hanging out as Orphans until that time.

```sql
root@:26257/defaultdb> SELECT *
  FROM crdb_internal.ranges_no_leases,
       (SELECT descriptor_id, index_id FROM crdb_internal.table_indexes WHERE descriptor_name like '%') AS ids
 WHERE start_pretty LIKE '/Table/' || descriptor_id || '/' || index_id || '%';
  range_id | start_key | start_pretty | end_key | end_pretty | table_id | database_name | schema_name | table_name |  index_name  | replicas |                                                 replica_localities                                                  | voting_replicas | non_voting_replicas | learner_replicas |   split_enforced_until    | descriptor_id | index_id
-----------+-----------+--------------+---------+------------+----------+---------------+-------------+------------+--------------+----------+---------------------------------------------------------------------------------------------------------------------+-----------------+---------------------+------------------+---------------------------+---------------+-----------
       225 | \361\212  | /Table/105/2 | \362    | /Table/106 |      105 | defaultdb     |             | jsontable  | in_jsontable | {1,2,3}  | {"cloud=local,region=local,zone=local","cloud=local,region=local,zone=local","cloud=local,region=local,zone=local"} | {1,3,2}         | {}                  | {}               | 2021-07-23 01:43:26.42477 |           105 |        2
(1 row)
```

## Statement Timeout 
To prevent runway queries, the `statement_timeout` session variable should be set.
The following example will timeout in 30 seconds:

```sql
set statement_timeout='30s'
```

## Trace all Sessions
How to turn in tracing for all sessions.  Output will be werittern to log
directories. Details are in the [code](https://github.com/cockroachdb/cockroach/blob/master/pkg/sql/exec_util.go)

```sql
SET CLUSTER SETTING sql.trace.txn.enable_threshold = '1s';
```

## Fully qualified connect strings and Environment Variables for jump server

```bash
export COCKROACH_URL=postgresql://root@localhost:26257/
export COCKROACH_CERTS_DIR=/home/ubuntu/certs
export connStr="postgresql://root@localhost:26257/defaultdb?sslmode=require&sslrootcert=/home/ubuntu/certs/ca.crt&sslcert=/home/ubuntu/certs/client.root.crt&sslkey=/home/ubuntu/certs/client.root.key"
```
## Monitor Contention by Object SQL
```sql
WITH c AS (
			SELECT DISTINCT ON (table_id, index_id)
			       table_id,
			       index_id,
			       num_contention_events AS events,
			       cumulative_contention_time AS time
			  FROM crdb_internal.cluster_contention_events
         )
SELECT i.descriptor_name, i.index_name, c.events, c.time
  FROM crdb_internal.table_indexes AS i
  JOIN c ON i.descriptor_id = c.table_id
        AND i.index_id = c.index_id
ORDER BY c.time DESC LIMIT 10;
```

## Index Usage Query

This functionality is evolving and will eventually be in the DB console.

```sql
SELECT ti.descriptor_name AS table_name, ti.index_name, total_reads, last_read 
FROM crdb_internal.index_usage_statistics AS us 
JOIN crdb_internal.table_indexes ti ON us.index_id = ti.index_id AND us.table_id = ti.descriptor_id 
ORDER BY total_reads DESC LIMIT 10;

-- Sample Output
--

   table_name   | index_name | total_reads |           last_read
----------------+------------+-------------+--------------------------------
  scandirection | idx_fw     |      111213 | 2021-12-13 18:33:28.003372+00
  scandirection | idx_rev    |       94903 | 2021-12-14 17:38:38.310606+00
  scandirection | primary    |           9 | 2021-12-14 17:37:41.023539+00
```

## Lock Timeout new in v21.2

```sql
> set lock_timeout = '5s';
SET


Time: 0ms total (execution 0ms / network 0ms)

root@test-crdb.us-west-2.aws.ddnw.net:26257/tpcc> SELECT * FROM warehouse WHERE w_id = 0;
ERROR: canceling statement due to lock timeout on row (w_id)=(0) in warehouse@primary
SQLSTATE: 55P03
```

## NO FULL SCAN HINT

```sql
root@:26257/defaultdb> show create a;
  table_name |                create_statement
-------------+-------------------------------------------------
  a          | CREATE TABLE public.a (
             |     id INT8 NOT NULL DEFAULT unique_rowid(),
             |     name STRING NULL,
             |     CONSTRAINT "primary" PRIMARY KEY (id ASC),
             |     FAMILY "primary" (id, name)
             | )


root@:26257/defaultdb> select count(*) from a;
  count
---------
   2958


root@:26257/defaultdb> explain select count(*) from a;
                                        info
------------------------------------------------------------------------------------
  distribution: full
  vectorized: true

  • group (scalar)
  │ estimated row count: 1
  │
  └── • scan
        estimated row count: 2,958 (100% of the table; stats collected 2 days ago)
        table: a@primary
        spans: FULL SCAN
(10 rows)


Time: 4ms total (execution 0ms / network 4ms)

root@:26257/defaultdb> explain select count(*) from a@{NO_FULL_SCAN};
ERROR: could not produce a query plan conforming to the NO_FULL_SCAN hint
```


## Show Dirty Rows per Table... (yet to be GCed)

```sql
select
        crdb_internal.pb_to_json('cockroach.sql.sqlbase.Descriptor', d.descriptor)->'database'->>'name' as db_name,
        crdb_internal.pb_to_json('cockroach.sql.sqlbase.Descriptor', t.descriptor)->'table'->>'name' as table_name,
        ranges.table_id,
        ranges.range_id,
        crdb_internal.range_stats(ranges.start_key)->>'key_bytes' as key_bytes,
        crdb_internal.range_stats(ranges.start_key)->>'val_bytes' as val_bytes,
        crdb_internal.range_stats(ranges.start_key)->>'live_bytes' as live_bytes,
        (crdb_internal.range_stats(ranges.start_key)->>'key_bytes')::int
                + (crdb_internal.range_stats(ranges.start_key)->>'val_bytes')::int
                - (crdb_internal.range_stats(ranges.start_key)->>'live_bytes')::int as garbage_bytes,
        round (100 - (crdb_internal.range_stats(ranges.start_key)->>'live_bytes')::int * 100 / 
                ((crdb_internal.range_stats(ranges.start_key)->>'key_bytes')::int +
                (crdb_internal.range_stats(ranges.start_key)->>'val_bytes')::int), 2) as garbage_percentage
from
        crdb_internal.ranges_no_leases ranges
        join system.descriptor as t on table_id = t.id
        join system.descriptor as d on (crdb_internal.pb_to_json('cockroach.sql.sqlbase.Descriptor', t.descriptor)->'table'->>'parentId')::int = d.id
where
        ((crdb_internal.range_stats(start_key)->>'key_bytes')::int + (crdb_internal.range_stats(start_key)->>'val_bytes')::int) != 0
order by garbage_percentage desc;
```

```
   db_name  |           table_name            | table_id | range_id | key_bytes | val_bytes | live_bytes | garbage_bytes | garbage_percentage
------------+---------------------------------+----------+----------+-----------+-----------+------------+---------------+---------------------
  system    | sqlliveness                     |       39 |       40 | 3252211   | 5690454   | 505        |       8942160 |              99.99
  system    | reports_meta                    |       28 |       29 | 93399     | 123440    | 99         |        216740 |              99.95
  system    | lease                           |       11 |       12 | 29038080  | 3427235   | 22534      |      32442781 |              99.93
  system    | scheduled_jobs                  |       37 |       38 | 3766      | 5762      | 618        |          8910 |              93.51
  system    | replication_critical_localities |       26 |       27 | 5560      | 4188      | 838        |          8910 |              91.40
  defaultdb | usertable                       |      130 |     2096 | 8483169   | 35963068  | 18609650   |      25836587 |              58.13
  defaultdb | usertable                       |      130 |     1988 | 7207260   | 30547725  | 15812544   |      21942441 |              58.12
  defaultdb | usertable                       |      130 |     1942 | 36908861  | 156371017 | 81012380   |     112267498 |              58.09
  defaultdb | usertable                       |      130 |     1447 | 11233968  | 47600245  | 24656338   |      34177875 |              58.09
  defaultdb | usertable                       |      130 |     1971 | 30190046  | 127861713 | 66276154   |      91775605 |              58.07
  defaultdb | usertable                       |      130 |     2122 | 42309323  | 179151521 | 92898796   |     128562048 |              58.05
  defaultdb | usertable                       |      130 |     2136 | 28662201  | 121370939 | 62940037   |      87093103 |              58.05
  ```

## Show size of tables in a Database

```sql
SELECT t.relname as table_name, sum(range_size_mb)::DECIMAL(8,4) as size_MB
FROM [show ranges with tables, details] as r
JOIN pg_catalog.pg_class as t ON (r.table_id = t.oid)
GROUP BY 1
ORDER BY 2 DESC;
```

## Compaction increase for MVCC

Default is TOO low for compactions, just two vCPUs per node.

```bash
export COCKROACH_CONCURRENT_COMPACTIONS=$(printf "%.0f" $(echo "$(nproc) * 0.5" | bc))
```

## TTL to do onetime bulk delete

CockroachDB allows you to use [Row-Level TTL](https://www.cockroachlabs.com/docs/stable/row-level-ttl) to be able to delete old data on a schedule.  It also allows you to create an express using the [ttl_expiration_expression](https://www.cockroachlabs.com/docs/stable/row-level-ttl#using-ttl_expiration_expression) parameter to include other criteria other than the _date_.  This functionality has been used to do *onetime* deletion of incorrect data.  The following statement configures `mytable` to delete some erroneous data based on `user_id` and `type`.  

```sql
ALTER TABLE mytable SET (
    ttl_expiration_expression = '
        CASE
            WHEN (user_id = 0 AND type IN (
                ''AB'', 
                ''BC'', 
                ''CD'', 
                ''DE'', 
                ''EF'', 
                ''FG'', 
                ''GH'' 
            )) 
            THEN (now()-interval ''1y'') ELSE (now()+interval ''1y'')
         END
    ', 
    ttl_job_cron='45 17 7 3 FRI', ttl_delete_rate_limit=200
);
```

It is configured to run one time really to acomplish this task, but should be removed after using `ALTER TABLE mytable RESET (ttl)`.

## Optimizer Options

**V24.3 ->**
+ `SET optimizer_prefer_bounded_cardinality = true;` 
+ `SET optimizer_min_row_count = 1.0;`