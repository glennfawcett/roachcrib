# roachcrib
Crib Sheet for Cockroach Database commands.  This is a parking lot for various commands to navigate through the roach universe.  This is an ever evolving crib sheet that I initially created when developing a workshop.

Enjoy

## MISC
```
-- Change Database Focus
USE mytest;

-- Show DDL for a Table /w Indexes
SHOW CREATE TABLE rides;
SELECT create_statement FROM [SHOW CREATE TABLE rides];

-- Show Running Queries
SHOW QUERIES;

-- Show Running Jobs
SHOW JOBS;
SELECT * FROM [SHOW JOBS] WHERE status='running';

-- Show Vectorize
SHOW session vectorize;

-- Enable/Disable Vectorize
SET session vectorize='auto';
SET session vectorize='experimental_on';
SET session vectorize='off';

-- Restore Database into different database name
CREATE DATABASE testmovr1;
RESTORE movr1.* FROM 'gs://geolabs/backup1' WITH into_db ='testmovr1';

-- Show Cluster Settings
select variable,value from [show cluster setting all];
select variable,value from [show cluster setting all] where variable like '%range%';


-- Create Indexes that STORE values that are not part of the index or primary key
--   This is useful for WIDE tables.  It is a "consolidated view"  of a table fragment
--
CREATE INDEX idx_wide_storing ON big_measures(city, measure_id) storing (myval1, myval2, myval3);


--  TIME travel with Queries
--
SELECT id, fname, lname  
FROM customer AS OF SYSTEM TIME INTERVAL '-10m' 
WHERE id = 42;
```

## GEO PARTITIONING
```
-- Show Locality for your connection
SHOW LOCALITY;

-- Show Range Distribution
SELECT start_key, lease_holder_locality
FROM [SHOW EXPERIMENTAL_RANGES FROM TABLE rides]
WHERE 'start_key' IS NOT NULL
AND 'start_key' NOT LIKE '%Prefix%';

-- Show Lease Holder Distribution
SELECT lease_holder, count(*)
FROM [SHOW experimental_ranges FROM table bigwide] GROUP BY 1 ORDER BY 1;

-- Force Range re-distribution
ALTER TABLE bigwide scatter;
ALTER INDEX idx_bw_city scatter;

-- Sample Partitioning
ALTER TABLE bigwide2 PARTITION BY LIST (city) (
    PARTITION us_west VALUES IN ('san francisco', 'portland'),
    PARTITION us_east VALUES IN ('new york','boston'),
    PARTITION eu_west VALUES IN ('paris','rome')
);

-- Sample Geo Partitioned Replicas
ALTER PARTITION us_west OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=us-west1]';
ALTER PARTITION us_east OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=us-east4]';
ALTER PARTITION eu_west OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=europe-west2]';
        
-- Sample Geo Partitioned Lease Holders
ALTER PARTITION us_west1 OF INDEX bigwide2@*
CONFIGURE ZONE USING
    num_replicas = 3,
    constraints = '{"+region=us-west1":1}',
    lease_preferences = '[[+region=us-west1]]';    

ALTER PARTITION us_east3 OF INDEX bigwide2@*
CONFIGURE ZONE USING
    num_replicas = 3,
    constraints = '{"+region=us-east4":1}',
    lease_preferences = '[[+region=us-east4]]';  

ALTER PARTITION eu_west2 OF INDEX bigwide2@*
CONFIGURE ZONE USING
    num_replicas = 3,
    constraints = '{"+region=europe-west2":1}',
    lease_preferences = '[[+region=europe-west2]]';  

-- Duplicate Indexes per region
--
CREATE INDEX idx_central ON postal_codes (id)
    STORING (code);

CREATE INDEX idx_east ON postal_codes (id)
    STORING (code);

-- Enable Follower Reads
SHOW CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled;
SET CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled='true';
```

## EXPLAIN and ANALYZE
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
```



## JSON Tips
```
-- IMPORT table from CSV
--
IMPORT TABLE myjson_table (
id INT PRIMARY KEY,
name STRING,
state STRING,
myjsoncol JSONB
) CSV DATA ('gs://mybucket/subdir/jsonfile.tsv')
WITH
    delimiter = e'\t';

IMPORT INTO myjson_table (id, name, state, myjsoncol)
CSV DATA (
    'gs://mybucket/subdir/jsonfile2.tsv'
)
WITH
    delimiter = e'\t';

-- JSON function for pretty print
select jsonb_pretty(myjsoncol) from myjson_table where name = 'Rosie';

-- Extract values from JSON object
select myjsoncol::JSONB->>'customer_id' from myjson_table;

-- Filter based on JSON values
select * from myjson_table where myjsoncol::JSONB->>'customer_id' ='429908572';
SELECT * from myjson_table where myflat::JSONB @> '{"customer_id": "429908572"}';


-- Index JSON column to improve JSON queries
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