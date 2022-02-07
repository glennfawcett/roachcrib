# Scratchpad for CockroachDB

```sql

-- Multiple Primary Key Values
--
CREATE TABLE mpk(
    id INT, 
    ts TIMESTAMPTZ DEFAULT now(), 
    current_value INT,
    PRIMARY KEY (id ASC, ts DESC)
);

alter table myid split at select generate_series(1000,300000,1000);

INSERT INTO mpk (id, current_value)
SELECT i, (random()*1000)::int 
FROM generate_series(1,1000) as i;

ALTER TABLE mpk SPLIT AT VALUES (200), (400), (600), (800);

INSERT INTO mpk (id, current_value)
SELECT 201, (random()*1000)::int 
FROM generate_series(1,10000) as i;

SELECT sum(i1+i2), b.id 
FROM myid as m
JOIN bigfast as b ON (m.bid = b.id)
WHERE m.id BETWEEN 0 and 10000
GROUP BY 2
ORDER BY 2 DESC
LIMIT 10;

SELECT sum(i1+i2), b.id 
FROM myid as m
INNER HASH JOIN bigfast as b ON (b.id = m.bid)
WHERE m.id BETWEEN 0 and 10000
GROUP BY 2
ORDER BY 2 DESC
LIMIT 10;

SELECT sum(i1+i2), b.id 
FROM bigfast as b
INNER MERGE JOIN myid as m ON (b.id = m.bid)
WHERE m.id BETWEEN 0 and 10000
GROUP BY 2
ORDER BY 2 DESC
LIMIT 10;


SELECT sum(i1+i2), b.id 
FROM myid as m
JOIN bigfast as b ON (m.bid = b.id)
WHERE m.id BETWEEN 10000 AND 20000
GROUP BY 2
ORDER BY 2 DESC
LIMIT 10;

-----------
---

CREATE TABLE bigdelete (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    create_ts TIMESTAMPTZ DEFAULT now(),
    s1 STRING DEFAULT 'aaaaaaaaaaaaaaaaaaaaaa',
    s2 STRING DEFAULT 'bbbbbbbbbbbbbbbbbbbbbb',
    order_status STRING DEFAULT (CASE WHEN (random() < 0.95) THEN 'PROCESSED' ELSE 'PENDING' END)
);

INSERT INTO bigdelete(s1)
SELECT 's1';

CREATE INDEX idx_status_ts on bigdelete(order_status, create_ts);

explain select * from bigdelete where order_status='PENDING' and create_ts < '2021-10-22 17:22:14.306456+00';

root@:26257/defaultdb> explain select * from bigdelete where order_status='PROCESSED' and create_ts < '2021-10-22 17:22:14.306456+00';
                                             info
-----------------------------------------------------------------------------------------------
  distribution: full
  vectorized: true

  • filter
  │ estimated row count: 2,097
  │ filter: (order_status = 'PROCESSED') AND (create_ts < '2021-10-22 17:22:14.306456+00:00')
  │
  └── • scan
        estimated row count: 2,198 (100% of the table; stats collected 43 seconds ago)
        table: bigdelete@primary
        spans: FULL SCAN
(11 rows)



-----------
----------------------------------------------------------------
```

```sql
        └── • scan
              columns: (sales_order_id uuid, customer_order_no varchar, status varchar, create_ts timestamp, retry_count int, modify_ts timestamp)
              nodes: n5
              regions: us-east
              actual row count: 43,877
              vectorized batch count: 43
              KV rows read: 43,877
              KV bytes read: 544 MiB
              estimated row count: 10,017,881 (100% of the table; stats collected 2 days ago)
              table: order_update@primary
              spans: FULL 


WITH sbatch as (
    SELECT sales_order_id FROM order_update
    WHERE create_ts < '2021-09-21' AND status = 'PROCESSED' 
    LIMIT 1000
)
DELETE FROM order_update where sales_order_id in (select * from sbatch);

INSERT INTO _testruns(description, tablename, numthreads, batchsize)
VALUES ('abc', 'test', 10, 5)
RETURNING (id);

select lease_holder_locality, sum(range_size_mb) from [show ranges from table r.user_note] group by 1;

SET experimental_enable_hash_sharded_indexes=true;

CREATE TABLE badfact (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    big_id INT, 
    created_at TIMESTAMPTZ DEFAULT now(),
    c1 text,
    c2 text,
    c3 text,
    INDEX (created_at, big_id) USING HASH WITH BUCKET_COUNT = 8
);

INSERT INTO badfact(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(1, 100000) as i;

select id, c1 from badfact where big_id=42 and created_at=(select max(created_at) from badfact where big_id=42);

select id, c1, created_at from badfact where big_id=42 order by created_at;

CREATE TABLE scandirection (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    big_id INT,
    c1 text,
    c2 text,
    c3 text,
    INDEX idx_fw (big_id ASC),
    INDEX idx_rev (big_id DESC) 
);

INSERT INTO scandirection(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(1, 100000) as i;

INSERT INTO scandirection(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(100001, 200000) as i;

INSERT INTO scandirection(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(200001, 300000) as i;

INSERT INTO scandirection(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(300001, 400000) as i;

INSERT INTO scandirection(big_id, c1, c2, c3)
SELECT i, 'cccc1111', 'cccc2222', 'cccc3333'
FROM generate_series(400001, 500000) as i;

ALTER TABLE scandirection SPLIT AT select gen_random_uuid() from generate_series(1,9);

ALTER INDEX idx_fw SPLIT AT SELECT  generate_series(100000,400000,100000);
ALTER INDEX idx_rev SPLIT AT SELECT  generate_series(100000,400000,100000);


-- TEST QUERIES
--
SELECT big_id, c1 FROM scandirection@idx_fw WHERE big_id BETWEEN 99990 and 100010 ORDER BY big_id ASC
SELECT big_id, c1 FROM scandirection@idx_rev WHERE big_id BETWEEN 99990 and 100010 ORDER BY big_id ASC









WITH top100 AS (
    SELECT big_id, c1
    FROM scandirection@idx_rev
    WHERE big_id BETWEEN 99990 and 100010
    ORDER BY big_id ASC
)
SELECT big_id, c1
FROM top100
ORDER BY 1
LIMIT 10;

WITH top100 AS (
SELECT big_id, c1
FROM scandirection@idx_fw
WHERE big_id BETWEEN 99990 and 100010
ORDER BY big_id ASC
)
SELECT big_id, c1
FROM top100
ORDER BY 1
LIMIT 10;


SELECT big_id, c1
FROM scandirection@idx_fw
WHERE big_id BETWEEN 99990 and 100010
ORDER BY big_id ASC;


select app_name,plan->'Name',plan->'Table',plan 
from public.statement_statistics 
where app_name not like '%internal%' and plan @> '{"Name": "index join"}'  and app_name='scandir' 
limit 10;

select app_name,plan->'Name',plan->'Table',plan->'Children'
from public.statement_statistics 
where app_name not like '%internal%' and plan @> '{"Name": "index join"}'  and app_name='scandir' 
limit 10;

with idxj as (
    select app_name,plan->'Name', jsonb_pretty(plan) as pplan
    from public.statement_statistics 
    where app_name not like '%internal%' and plan @> '{"Name": "index join"}'  and app_name='scandir' 
)
select *
from idxj;

with idxj as (
    select app_name,plan->'Name', jsonb_pretty(plan->'Children')
    --jsonb_pretty(plan) as pplan
    from public.statement_statistics 
    where app_name not like '%internal%' and plan @> '{"Name": "index join"}'   
)
select *
from idxj
where app_name='scandir';

with idxj as (
    select app_name,plan->'Name' as idxjoin
    from public.statement_statistics 
    where app_name not like '%internal%' 
    and plan @> '{"Name": "index join"}'   
)
select (select count(*) from public.statement_statistics) as cnt_allstmt, count(*) as cnt_index_join
from idxj;

with idxjpp as (
    select app_name,
           plan->'Name' as idxJoin, 
           plan->'Table' as idxJoinTable,
           jsonb_pretty(plan) as pplan
    from crdb_internal.statement_statistics 
    where app_name not like '%internal%' 
    and plan @> '{"Name": "index join"}'   
)
select app_name, idxJoin, idxJoinTable
from idxjpp;

-- where app_name='scandir';

select count(*), 
       sampled_plan->'Name' as planAction 
    --    jsonb_pretty(sampled_plan)
from crdb_internal.statement_statistics
where app_name not like '%internal%'
and  not (sampled_plan @> '{"Name": ""}')   
group by 2
order by 1 desc;

select count(*), 
       metadata->'Query' as query 
    --    jsonb_pretty(sampled_plan)
from crdb_internal.statement_statistics
where app_name not like '%internal%'
and  not (sampled_plan @> '{"Name": ""}')   
group by 2
order by 1 desc;

select metadata->'query', 
       count(*) 
from crdb_internal.statement_statistics 
group by 1 
order by 2 desc
limit 10;

select metadata->'query', 
    --    sampled_plan->'Name',
       sampled_plan,
       count(*) 
from crdb_internal.statement_statistics 
group by 1, 2
order by 3 desc
limit 2;

select
jsonb_extract_path(sampled_plan, 'Name')
from crdb_internal.statement_statistics 
limit 10;


-- ON UPDATE!!!
--
root@:26257/defaultdb> create table u(id int primary key, name string, u boolean default false on update true);
CREATE TABLE


Time: 344ms total (execution 344ms / network 0ms)

root@:26257/defaultdb> insert into u(id, name) select i, 'zzz' from generate_series(1,1000) as i;
INSERT 1000


Time: 258ms total (execution 258ms / network 0ms)

root@:26257/defaultdb> select * from u limit 10;
  id | name |   u
-----+------+--------
   1 | zzz  | false
   2 | zzz  | false
   3 | zzz  | false
   4 | zzz  | false
   5 | zzz  | false
   6 | zzz  | false
   7 | zzz  | false
   8 | zzz  | false
   9 | zzz  | false
  10 | zzz  | false
(10 rows)


Time: 2ms total (execution 2ms / network 0ms)

root@:26257/defaultdb> update u set name='aaa' where id = 5;
UPDATE 1


Time: 67ms total (execution 67ms / network 0ms)

root@:26257/defaultdb> select * from u limit 10;
  id | name |   u
-----+------+--------
   1 | zzz  | false
   2 | zzz  | false
   3 | zzz  | false
   4 | zzz  | false
   5 | aaa  | true
   6 | zzz  | false
   7 | zzz  | false
   8 | zzz  | false
   9 | zzz  | false
  10 | zzz  | false
(10 rows)


select jsonb_pretty(sampled_plan->'Children'), 
       statistics->'execution_statistics'->'cnt' 
from crdb_internal.statement_statistics where app_name='G1';

select jsonb_pretty(sampled_plan), 
       statistics->'execution_statistics'->'cnt' 
from crdb_internal.statement_statistics where app_name='G1';

select jsonb_pretty(statistics) from crdb_internal.statement_statistics limit 1;
select jsonb_pretty(statistics->'statistics') from crdb_internal.statement_statistics limit 1;



--
--

select 
jsonb_pretty(sampled_plan), 
    --    jsonb_pretty(statistics)
        statistics->'execution_statistics'->'cnt',
        statistics->'statistics'->'cnt',
        CAST(statistics->'statistics'->'rowsRead'->'mean' as INT)
from crdb_internal.statement_statistics where app_name='G4';


with idxj as (
    select app_name, 
           jsonb_pretty(sampled_plan),
           sampled_plan->'Name', 
           sampled_plan->'Children'->'Name',
           sampled_plan->'Children'->'Name'->'Name',
           sampled_plan->'Children'->'Name'->'Name'->'Name'
    --jsonb_pretty(plan) as pplan
    from crdb_internal.statement_statistics
    where app_name not like '%internal%' 
    -- and sampled_plan @> '{"Name": "index join"}'
)
select *
from idxj
where app_name='G4';


select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)) from crdb_internal.statement_statistics;

select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT 
from crdb_internal.statement_statistics;
    sum
------------
  11135725
(1 row)

select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT 
from crdb_internal.statement_statistics 
where sampled_plan @> '{"Name": "index join"}' ;

select jsonb_pretty(sampled_plan) 
from crdb_internal.statement_statistics 
where app_name='G4';
where sampled_plan @> '{"Name": "index join"}' ;



select jsonb_pretty(sampled_plan) 
from crdb_internal.statement_statistics 
where app_name='G4';

select sampled_plan->'Name',
       sampled_plan->'Children'->1->'Name'
from crdb_internal.statement_statistics 
where app_name='G4';


select sampled_plan->'Name',
       sampled_plan->'Children'->0->'Name',
       sampled_plan->'Children'->1->'Name',
       sampled_plan->'Children'->2->'Name',
       sampled_plan->'Children'->3->'Name', 
       sampled_plan->'Children'->4->'Name'
from crdb_internal.statement_statistics;

select 
       statistics->'statistics'->'rowsRead'->>'mean',
       sampled_plan->'Name',
       sampled_plan->'Children'->0->'Name',
       sampled_plan->'Children'->1->'Name',
       sampled_plan->'Children'->2->'Name',
       sampled_plan->'Children'->3->'Name', 
       sampled_plan->'Children'->4->'Name'
from crdb_internal.statement_statistics
where sampled_plan @> '{"Name": "index join"}' OR
sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->4 @> '{"Name": "index join"}' ;


select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT,
       sum(CAST(statistics->'statistics'->'cnt' as INT))::INT
from crdb_internal.statement_statistics;

select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT
from crdb_internal.statement_statistics
where sampled_plan @> '{"Name": "index join"}' OR
sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->4 @> '{"Name": "index join"}' ;


-- Logical IO / rowsRead
--
select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT,
       sum(CAST(statistics->'statistics'->'cnt' as INT))::INT
from crdb_internal.statement_statistics;

-- Index Join
--
select 
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT,
sum(CAST(statistics->'statistics'->'cnt' as INT)),
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT
from crdb_internal.statement_statistics
where sampled_plan @> '{"Name": "index join"}' OR
sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
sampled_plan->'Children'->4 @> '{"Name": "index join"}' ;

-- scan Logical IO
--
select 
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT,
sum(CAST(statistics->'statistics'->'cnt' as INT)),
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT
from crdb_internal.statement_statistics
where sampled_plan @> '{"Name": "scan"}' OR
sampled_plan->'Children'->0 @>  '{"Name": "scan"}' OR
sampled_plan->'Children'->1 @> '{"Name": "scan"}' OR
sampled_plan->'Children'->2 @> '{"Name": "scan"}' OR
sampled_plan->'Children'->3 @> '{"Name": "scan"}' OR
sampled_plan->'Children'->4 @> '{"Name": "scan"}' ;

-- fullScan Logical IO
--
select 
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT))::INT,
sum(CAST(statistics->'statistics'->'cnt' as INT)),
sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT
from crdb_internal.statement_statistics
where 
metadata @> '{"fullScan": true}';


-- ijoin factor
--
WITH l as (
    select sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT as lio
from crdb_internal.statement_statistics
where aggregated_ts > now() - INTERVAL '1w'
),
ij as (
    select 
    sum(CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT))::INT 
      as ijoin
    from crdb_internal.statement_statistics
    where 
    aggregated_ts > now() - INTERVAL '1w' AND (
    sampled_plan @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
    sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->4 @> '{"Name": "index join"}'
    ) 
)
select lio, ijoin, (ijoin/lio)*100 as ijfactor
from l, ij;


CREATE MATERIALIZED VIEW IF NOT EXISTS 
stmt_sample (
    aggregated_ts,
    fingerprint_id,
    transaction_fingerprint_id,
    plan_hash,
    app_name,
    metadata,
    statistics,
    sampled_plan,
    aggregation_interval
)
AS
SELECT aggregated_ts,
    fingerprint_id,
    transaction_fingerprint_id,
    plan_hash,
    app_name,
    metadata,
    statistics,
    sampled_plan,
    aggregation_interval 
FROM crdb_internal.statement_statistics
WHERE aggregated_ts > NOW() - INTERVAL '1w';
WHERE aggregrated_ts > '2022-01-19 00:06:55.320073+00';



              table_name             |                 create_statement
-------------------------------------+----------------------------------------------------
  crdb_internal.statement_statistics | CREATE TABLE crdb_internal.statement_statistics (
                                     |     aggregated_ts TIMESTAMPTZ NOT NULL,
                                     |     fingerprint_id BYTES NOT NULL,
                                     |     transaction_fingerprint_id BYTES NOT NULL,
                                     |     plan_hash BYTES NOT NULL,
                                     |     app_name STRING NOT NULL,
                                     |     metadata JSONB NOT NULL,
                                     |     statistics JSONB NOT NULL,
                                     |     sampled_plan JSONB NOT NULL,
                                     |     aggregation_interval INTERVAL NOT NULL
                                     | )



SELECT b1.name, b2.name, sd.c1, sd.c2
FROM b1
JOIN scandirection as sd ON (sd.big_id=b1.id)
JOIN b2 ON (b2.big_id=b1.id)
WHERE b2.big_id > 101900
UNION ALL
(SELECT 'uuu', 'uuu', c1, c2
FROM scandirection
LIMIT 100000);

select jsonb_pretty(sampled_plan)
from crdb_internal.statement_statistics 
where app_name='ZZ';

SELECT 
sampled_plan->'Name',
sampled_plan->'Children'->0->'Name',
sampled_plan->'Children'->1->'Name',
sampled_plan->'Children'->2->'Name',
sampled_plan->'Children'->3->'Name',
sampled_plan->'Children'->4->'Name',
-- sampled_plan->'Children'->1->'Children'->0->'Name',
-- sampled_plan->'Children'->1->'Children'->1->'Name',
-- sampled_plan->'Children'->1->'Children'->2->'Name',
-- sampled_plan->'Children'->2->'Children'->0->'Name',
-- sampled_plan->'Children'->2->'Children'->1->'Name',
-- sampled_plan->'Children'->2->'Children'->2->'Name',
CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT,
CAST(statistics->'statistics'->'cnt' as INT),
CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT)::INT
-- jsonb_pretty(sampled_plan)
from crdb_internal.statement_statistics
where app_name='ZZ';


metadata->'query'


SELECT 
aggregated_ts,
CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT*CAST(statistics->'statistics'->'cnt' as INT),
jsonb_pretty(metadata)
from crdb_internal.statement_statistics
where 
aggregated_ts > now() - INTERVAL '1h' AND (
    sampled_plan @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
    sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->4 @> '{"Name": "index join"}'
);


SELECT
aggregated_ts,
metadata->'fullScan' as fullScan,
metadata->'distsql' as distsql,
metadata->'implicitTxn' as implicitTxn,
-- statistics->'statistics'->'numRows' as numRows,
CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
CAST(statistics->'statistics'->'cnt' as INT) as cnt,
CASE 
  WHEN (sampled_plan @> '{"Name": "scan"}') THEN 1
  WHEN (sampled_plan->'Children'->0 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->1 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->2 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->3 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->4 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->5 @>  '{"Name": "index join"}') THEN 1
  ELSE 0
END as iJoinRows
-- jsonb_pretty(metadata)
FROM crdb_internal.statement_statistics;

-- FULL SCAN Ratio
--
WITH rawStmtStats as (
    SELECT
        aggregated_ts,
        metadata->'fullScan' as fullScan,
        metadata->'distsql' as distsql,
        metadata->'implicitTxn' as implicitTxn,
        -- statistics->'statistics'->'numRows' as numRows,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
        CAST(statistics->'statistics'->'cnt' as INT) as cnt,
        metadata
    FROM crdb_internal.statement_statistics
)
SELECT fullScan, count(*) 
FROM rawStmtStats 
GROUP BY 1;


-- FULL SCAN TOP queries
--
WITH rawStmtStats as (
    SELECT
        aggregated_ts,
        metadata->'fullScan' as fullScan,
        metadata->'distsql' as distsql,
        metadata->'implicitTxn' as implicitTxn,
        -- statistics->'statistics'->'numRows' as numRows,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
        CAST(statistics->'statistics'->'cnt' as INT) as cnt,
        metadata
    FROM crdb_internal.statement_statistics
)
SELECT metadata->'query', count(*)
FROM rawStmtStats 
WHERE fullScan = 'true'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;


SELECT
aggregated_ts,
jsonb_pretty(metadata)
where
aggregated_ts > now() - INTERVAL '1h' AND (
    sampled_plan @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->0 @>  '{"Name": "index join"}' OR
    sampled_plan->'Children'->1 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->2 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->3 @> '{"Name": "index join"}' OR
    sampled_plan->'Children'->4 @> '{"Name": "index join"}'
);


--
--
-- Query For Golang stmt bundle
--
--
SELECT
aggregated_ts,
metadata->'fullScan' as fullScan,
metadata->'distsql' as distsql,
metadata->'implicitTxn' as implicitTxn,
-- statistics->'statistics'->'numRows' as numRows,
CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
CAST(statistics->'statistics'->'cnt' as INT) as cnt,
CASE 
  WHEN (sampled_plan @> '{"Name": "scan"}') THEN 1
  WHEN (sampled_plan->'Children'->0 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->1 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->2 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->3 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->4 @>  '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->5 @>  '{"Name": "index join"}') THEN 1
  ELSE 0
END as iJoinRows
-- jsonb_pretty(metadata)
FROM crdb_internal.statement_statistics;


-- Statement's Profile by Hour  (V21.2.x)+
--
WITH stmtpull as (
SELECT    
aggregated_ts,
IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
IF (metadata->'distsql' = 'true', 1, 0) as distsql,
IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
CAST(statistics->'statistics'->'cnt' as INT) as cnt,
CASE 
  WHEN (sampled_plan @> '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->0->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->1->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->2->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->3->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->4->>'Name' = 'index join') THEN 1
  ELSE 0
END as iJoinStmt,
jsonb_pretty(metadata)
FROM crdb_internal.statement_statistics
)
SELECT 
    aggregated_ts,
    sum(fullScan*cnt*numRows)/sum(cnt*numRows) as fullScanPct,
    -- sum(distsql*cnt*numRows)/sum(cnt*numRows) as distSqlPct,
    -- sum(implicitTxn*cnt*numRows)/sum(cnt*numRows) as implicitTxnPct,
    sum(iJoinStmt*cnt*numRows)/sum(cnt*numRows) as iJoinRowsPct,
    sum(numRows)/count(*) as rowsPerStmt,
    sum(numRows*cnt) as rowsPerAggIntvl
FROM stmtpull
GROUP BY aggregated_ts
ORDER BY aggregated_ts ASC;


--
--
WITH stmtpull as (
SELECT    
aggregated_ts,
IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
IF (metadata->'distsql' = 'true', 1, 0) as distsql,
IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
CAST(statistics->'statistics'->'cnt' as INT) as cnt,
CASE 
  WHEN (sampled_plan @> '{"Name": "index join"}') THEN 1
  WHEN (sampled_plan->'Children'->0->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->1->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->2->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->3->>'Name' = 'index join') THEN 1
  WHEN (sampled_plan->'Children'->4->>'Name' = 'index join') THEN 1
  ELSE 0
END as iJoinStmt,
jsonb_pretty(metadata)
FROM crdb_internal.statement_statistics
)
SELECT 
    aggregated_ts,
    IF (sum(numRows*fullScan)/count(*) > 100, sum(fullScan*cnt*numRows)/sum(cnt*numRows), 0) as fullScanPct,
    -- sum(fullScan*cnt*numRows)/sum(cnt*numRows) as fullScanPct,
    sum(distsql*cnt*numRows)/sum(cnt*numRows) as distSqlPct,
    -- sum(implicitTxn*cnt*numRows)/sum(cnt*numRows) as implicitTxnPct,
    sum(iJoinStmt*cnt*numRows)/sum(cnt*numRows) as indexJoinRowsPct,
    sum(numRows)/count(*) as rowsPerStmt,
    sum(numRows*cnt) as rowsPerAggIntvl
FROM stmtpull
GROUP BY aggregated_ts
ORDER BY aggregated_ts ASC;


-- Logical Io
--
WITH lio as (
    SELECT 
        aggregated_ts,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as rowsMean, 
        CAST(statistics->'statistics'->'cnt' as INT) as sumcnt
    FROM crdb_internal.statement_statistics
)
SELECT 
    aggregated_ts,
    sum(rowsMean*sumcnt) as lio
FROM lio
GROUP BY aggregated_ts
ORDER BY aggregated_ts ASC;

