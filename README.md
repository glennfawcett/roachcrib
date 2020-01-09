# roachcrib
Crib Sheet for Cockroach Database commands.  This is a parking lot for various commands to navigate through the roach universe.  This is an ever evolving crib sheet that I initially created when developing a workshop.

Enjoy

## 
```
-- Change Database Focus
  use movr20;

-- Show DDL for a Table /w Indexes
  show create table rides;
  select create_statement from [show create table rides];

-- Show Locality for your connection
  show locality;

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

-- Show Running Queries
  show queries;

-- Show Running Jobs
  show jobs;
  select * from [show jobs] where status='running';

-- Show Vectorize
  show session vectorize;

-- Enable/Disable Vectorize
  set session vectorize='auto';
  set session vectorize='experimental_on';
  set session vectorize='off';

-- Enable Follower Reads
  show CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled;
  set CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled='true';

-- Explain Plan
  EXPLAIN SELECT city, count(*) FROM rides;

-- Explain Analyze
  EXPLAIN ANALYZE SELECT city, count(*) FROM rides;

-- Restore Database into different database name
    create database testmovr1;
    restore movr1.* from 'gs://geolabs/backup1' with into_db ='testmovr1';

```
