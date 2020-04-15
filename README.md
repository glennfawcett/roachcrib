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