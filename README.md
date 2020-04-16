# CockroachDB Cribsheet
Roachcrib is a "Crib Sheet" for Cockroach database commands.  This is a parking lot for various commands to navigate through the roach universe.  This is an ever evolving crib sheet that I initially created when developing a workshop.

Enjoy!!!

## Geo Partitioning

I seperated out the CribSheet commands specific to Geo Partitioning as it a pretty detailed topic.

* [Geo CribSheet](Geo.md)

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