# CockroachDB Cribsheet
Roachcrib is a "Crib Sheet" for Cockroach database commands.  This is a parking lot for various commands to navigate through the roach universe.  This is an ever evolving crib sheet that I initially created when developing a workshop.

Enjoy!!!

## Geo Partitioning

There are two main patterns for geo-partitioing.
+ *Geo Partitioned Replicas* pin ALL partioned replicas to a specific region.  This is typically done for GDPR reasons to ensure data from certian countries stay within their borders.
+ *Geo Partitioned Leaseholders* Place lease-holders across regions so as to survive a full region failure.
Below are commands that show how partition, monitor and tune geo-partitioning.

### Geo Partitioned Replicas and Leaseholders

```
-- Sample Partitioning
--
ALTER TABLE bigwide2 PARTITION BY LIST (city) (
    PARTITION us_west VALUES IN ('san francisco', 'portland'),
    PARTITION us_east VALUES IN ('new york','boston'),
    PARTITION eu_west VALUES IN ('paris','rome')
);

-- Sample Geo Partitioned Replicas
--
ALTER PARTITION us_west OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=us-west1]';
ALTER PARTITION us_east OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=us-east4]';
ALTER PARTITION eu_west OF INDEX bigwide2@*
    CONFIGURE ZONE USING constraints='[+region=europe-west2]';
        
-- Sample Geo Partitioned Lease Holders
--
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
```

### Monitor Geo Parititiong
```
-- Show Locality for your connection
--
SHOW LOCALITY;

-- Show Range Distribution
--
SELECT start_key, lease_holder_locality
FROM [SHOW EXPERIMENTAL_RANGES FROM TABLE rides]
WHERE 'start_key' IS NOT NULL
AND 'start_key' NOT LIKE '%Prefix%';

-- Show Lease Holder Distribution
--
SELECT lease_holder, count(*)
FROM [SHOW experimental_ranges FROM table bigwide] GROUP BY 1 ORDER BY 1;

-- Force Range re-distribution
--
ALTER TABLE bigwide scatter;
ALTER INDEX idx_bw_city scatter;
```

### Tune Geo Partitioning
You can create Duplicate indexes and Pin them to specific regions.  The optimizer will recgonize this and choose the nearest index for the best response time.  Additionally, you can use follower reads to read data from the nearest replica slightly in the past.

```
-- Duplicate Indexes per region
--
CREATE INDEX idx_central ON postal_codes (id)
    STORING (code);

ALTER INDEX postal_codes@idx_central
    CONFIGURE ZONE USING
      num_replicas = 3,
      constraints = '{"+region=us-central":1}',
      lease_preferences = '[[+region=us-central]]';

CREATE INDEX idx_east ON postal_codes (id)
    STORING (code);

ALTER INDEX postal_codes@idx_east
    CONFIGURE ZONE USING
      num_replicas = 3,
      constraints = '{"+region=us-east":1}',
      lease_preferences = '[[+region=us-east]]';

-- Follower Reads  (SHOW and Enable)
--
SHOW CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled;
SET CLUSTER SETTING kv.closed_timestamp.follower_reads_enabled='true';

-- Query with Follower Reads
--
SELECT ... FROM ... AS OF SYSTEM TIME experimental_follower_read_timestamp();

-- Read Only Transaction with Follower Reads
--
BEGIN;
  SET TRANSACTION AS OF SYSTEM TIME experimental_follower_read_timestamp();
  SAVEPOINT cockroach_restart;
  SELECT ...
  SELECT ...
COMMIT;
```
