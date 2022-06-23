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
-- Query For Golang stmt bundle sampling
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
    WHERE metadata @> '{"distsql": false}'
)
SELECT 
    aggregated_ts,
    sum(rowsMean*sumcnt) as lio
FROM lio
GROUP BY aggregated_ts
ORDER BY aggregated_ts ASC;

WITH lio as (
    SELECT 
        aggregated_ts,
        metadata->>'query' as queryTxt,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as rowsMean, 
        CAST(statistics->'statistics'->'cnt' as INT) as sumcnt
    FROM crdb_internal.statement_statistics
    WHERE metadata @> '{"distsql": false}' 
    -- AND 
    --       aggregated_ts > now() - INTERVAL '2hr'
)
SELECT 
    aggregated_ts,
    substring(queryTxt for 30),
    sum(rowsMean*sumcnt) OVER (PARTITION BY aggregated_ts, queryTxt)
FROM lio
-- GROUP BY aggregated_ts, queryTxt
ORDER BY lio DESC
LIMIT 100;

--
-- index usage
--
root@:26257/defaultdb> SELECT ti.descriptor_name AS table_name, ti.index_name, total_reads, last_read
FROM crdb_internal.index_usage_statistics AS us
JOIN crdb_internal.table_indexes ti ON us.index_id = ti.index_id AND us.table_id = ti.descriptor_id
ORDER BY total_reads ASC;
   table_name   | index_name | total_reads |           last_read
----------------+------------+-------------+--------------------------------
  scandirection | primary    |           0 | NULL
  b2            | idx_big_id |           0 | NULL
  scandirection | idx_fw     |           0 | NULL
  contend       | primary    |           0 | NULL
  u             | primary    |           0 | NULL
  b1            | primary    |           0 | NULL
  b2            | primary    |           0 | NULL
  o             | primary    |           0 | NULL
  order         | primary    |           0 | NULL
  a             | primary    |           0 | NULL
  scandirection | idx_rev    |        2001 | 2022-02-07 17:01:01.901473+00

root@:26257/defaultdb> explain SELECT c1,c2,c3
    FROM scandirection
    WHERE big_id BETWEEN 10 and 20;
                                         info
--------------------------------------------------------------------------------------
  distribution: local
  vectorized: true

  • index join
  │ estimated row count: 0
  │ table: scandirection@primary
  │
  └── • scan
        estimated row count: 0 (<0.01% of the table; stats collected 23 minutes ago)
        table: scandirection@idx_rev
        spans: [/20 - /10]

--
-- Find Hot Statements
--
WITH stmtpull as (
SELECT    
    aggregated_ts,
    metadata,
    -- sampled_plan
    md5(jsonb_pretty(sampled_plan)) as myhash,
    -- IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
    -- IF (metadata->'distsql' = 'true', 1, 0) as distsql,
    -- IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
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
    END as iJoinStmt
FROM crdb_internal.statement_statistics
-- WHERE aggregated_ts > now() - INTERVAL '1hr'
)
SELECT 
    aggregated_ts,
    -- myhash,
    -- sampled_plan,
    metadata->>'query',
    -- jsonb_pretty(sampled_plan),
    -- IF (sum(numRows*fullScan)/count(*) > 100, sum(fullScan*cnt*numRows)/sum(cnt*numRows), 0) as fullScanPct,
    -- sum(fullScan*cnt*numRows)/sum(cnt*numRows) as fullScanPct,
    -- sum(distsql*cnt*numRows)/sum(cnt*numRows) as distSqlPct,
    -- sum(implicitTxn*cnt*numRows)/sum(cnt*numRows) as implicitTxnPct,
    sum(iJoinStmt*cnt*numRows) as indexJoinRows,
    sum(iJoinStmt*cnt*numRows)/(select sum(cnt*numRows) from stmtpull) as iJoinPct
    -- sum(numRows)/count(*) as rowsPerStmt,
    -- sum(numRows*cnt) as rowsPerAggIntvl
FROM stmtpull
WHERE cnt > 0 and numRows > 0 
GROUP BY 1,2
HAVING sum(iJoinStmt*cnt*numRows) > 1000
ORDER BY indexJoinRows DESC
LIMIT 5;


WITH stmt_hr_calc AS (
    SELECT 
        aggregated_ts,
        metadata->>'query' as queryTxt,
        IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
        IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as rowsMean, 
        CAST(statistics->'statistics'->'cnt' as INT) as sumcnt,
        app_name,
        CASE 
            WHEN (sampled_plan @> '{"Name": "index join"}') THEN 1
            WHEN (sampled_plan->'Children'->0->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->1->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->2->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->3->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->4->>'Name' = 'index join') THEN 1
            ELSE 0
        END as iJoinStmt
    FROM crdb_internal.statement_statistics
    -- WHERE metadata @> '{"distsql": false}' 
    -- AND 
    --       aggregated_ts > now() - INTERVAL '2hr'
), stmt_hr_stats AS (
    SELECT 
        aggregated_ts,
        substring(queryTxt for 30) as queryTxt,
        app_name,
        fullScan,
        iJoinStmt,
        implicitTxn,
        sumcnt,
        sum(rowsMean*sumcnt) OVER (PARTITION BY aggregated_ts, queryTxt) as lioPerStmt
    FROM stmt_hr_calc
    ORDER BY lioPerStmt DESC
), stmt_hr_pct AS (
    SELECT 
        aggregated_ts,
        queryTxt,
        app_name,
        fullScan,
        iJoinStmt,
        implicitTxn,
        lioPerStmt,
        sumcnt,
        lioPerStmt/(sum(lioPerStmt) OVER (PARTITION BY aggregated_ts)) as lioPct
    FROM stmt_hr_stats
)
SELECT 
    aggregated_ts, 
    queryTxt, 
    app_name,
    iJoinStmt, 
    lioPerStmt/sumcnt as readsPerExec,
    lioPct, 
    implicitTxn
FROM stmt_hr_pct
WHERE implicitTxn = 0 and 
      lioPct > 0.001 and 
      app_name not like '%internal-%' 
      --(lioPerStmt/sumcnt) > 1000
ORDER BY lioPct DESC
LIMIT 10;


WITH stmt_hr_calc AS (
        SELECT
            aggregated_ts,
            app_name,
            fingerprint_id,
            metadata->>'query' as queryTxt,
            plan,
            IF (metadata->'implicitTxn' = 'false', 1, 0) as explicitTxn,
            IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
            CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as rowsMean,
            CAST(statistics->'statistics'->'cnt' as INT) as execCnt,
            CASE
                WHEN (plan @> '{"Name": "index join"}') THEN 1
                WHEN (plan->'Children'->0->>'Name' = 'index join') THEN 1
                WHEN (plan->'Children'->1->>'Name' = 'index join') THEN 1
                WHEN (plan->'Children'->2->>'Name' = 'index join') THEN 1
                WHEN (plan->'Children'->3->>'Name' = 'index join') THEN 1
                WHEN (plan->'Children'->4->>'Name' = 'index join') THEN 1
                ELSE 0
                END as iJoinStmt
        FROM system.statement_statistics
        WHERE 1=1 
--             aggregated_ts = '2022-02-15 18:00:00+00' 
            AND aggregated_ts > now() - INTERVAL '2hr'
    ), sql_distinct_cnt as (
        SELECT DISTINCT aggregated_ts,
        -- app_name,
        -- fingerprint_id,
        substring(queryTxt for 30)                                                as queryTxt,
        -- sampled_plan,
        sum(fullScan) OVER (PARTITION BY aggregated_ts, fingerprint_id)           as fullCnt,
        sum(iJoinStmt) OVER (PARTITION BY aggregated_ts, fingerprint_id)          as iJoinCnt,
        sum(explicitTxn) OVER (PARTITION BY aggregated_ts, fingerprint_id)        as explicitCnt,
        sum(IF((fullScan = 0) and (iJoinStmt = 0) and (explicitTxn = 0), 1, 0))
            OVER (PARTITION BY  aggregated_ts, fingerprint_id) as healthyCnt,
        sum(execCnt) OVER (PARTITION BY aggregated_ts)                            as execTotal,
        sum(rowsMean * execCnt) OVER (PARTITION BY aggregated_ts)                 as lioTotal,
        sum(rowsMean * execCnt) OVER (PARTITION BY aggregated_ts, fingerprint_id) as lioPerStmt
        FROM stmt_hr_calc
        ORDER BY lioPerStmt
    ), lio_normalization as (
    SELECT aggregated_ts,
           lioTotal,
           sum(lioPerStmt * (IF(fullCnt > 0, 1, 0)))     as fullLio,
           sum(lioPerStmt * (IF(iJoinCnt > 0, 1, 0)))    as iJoinLio,
           sum(lioPerStmt * (IF(explicitCnt > 0, 1, 0))) as explicitLio,
           sum(lioPerStmt * (IF(healthyCnt > 0, 1, 0)))  as healtyLio
    FROM sql_distinct_cnt
    GROUP BY 1, 2
    )
    SELECT
           aggregated_ts, 
           LioTotal,
           fullLio/lioTotal as fullPct,
           iJoinLio/lioTotal as iJoinPCT,
           explicitLio/lioTotal as explicitPCT,
           healtyLio/lioTotal as healtyPCT
    FROM lio_normalization
;


with v as (
    select 1 as o, 56 as id
    union all
    select 2 as o, 7 as id
    union all
    select 3 as o, 21 as id
)
select * from a
join v on (v.id=a.id)
order by v.o;

select 
    t.database_name as Database , 
    t.name as Table, 
    i.index_id,
    n.index_name as Index,
    n.descriptor_id,
    n.descriptor_name,
    i.total_reads, i.last_read 
from crdb_internal.index_usage_statistics as i
inner join crdb_internal.tables as t
on (i.table_id=t.table_id)
inner join crdb_internal.table_indexes as n
on (i.index_id=n.index_id and i.table_id=t.table_id)
order by i.total_reads asc;


                                        info
-------------------------------------------------------------------------------------
  distribution: local
  vectorized: true

  • index join
  │ estimated row count: 2
  │ table: customer@primary
  │
  └── • scan
        estimated row count: 2 (<0.01% of the table; stats collected 9 minutes ago)
        table: customer@customer_idx
        spans: [/0/1/'BARBARBAR' - /0/1/'BARBARBAR']

EXPLAIN SELECT * FROM customer 
        WHERE c_w_id=0 AND c_d_id=1 AND c_last='BARBARBAR';

WITH stmt_hr_calc AS (
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        metadata->>'query' as queryTxt,
        sampled_plan,
        IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
        IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
        CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT as rowsRead,
        CASE
            WHEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT > CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
                THEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT
            ELSE CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
            END as rowsMean,
        CAST(statistics->'statistics'->'cnt' as INT) as execCnt,
        CASE
            WHEN (sampled_plan @> '{"Name": "index join"}') THEN 1
            WHEN (sampled_plan->'Children'->0->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->1->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->2->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->3->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->4->>'Name' = 'index join') THEN 1
            ELSE 0
            END as iJoinStmt
    FROM crdb_internal.statement_statistics
    WHERE 1=1
      --AND app_name not like '$ internal-%'
)
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        queryTxt,
        sampled_plan,
        fullScan,
        iJoinStmt,
        implicitTxn,
        execCnt,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts) as lioAggTotal,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts, fingerprint_id) as lioPerStmt
    FROM stmt_hr_calc
    WHERE iJoinStmt > 0
    ORDER BY lioPerStmt DESC;

WITH lim1000 as (
    SELECT i2
    FROM bigfast
    WHERE i1 = 42
    LIMIT 1000
)
SELECT SUM(i2)
FROM lim1000
AS OF SYSTEM TIME follower_read_timestamp();


WITH r as (
    select floor(random()*10000) as i1
),
lim1000 as (
    SELECT i2
    FROM bigfast
    JOIN r ON (r.i1 = bigfast.i1)
    LIMIT 1000
)
SELECT SUM(i2)
FROM lim1000;

cockroach workload run ycsb --workload F  postgresql://root@192.168.0.100:26257/ycsb?sslmode=disable --drop --concurrency 1024 --duration 1800s --help

>>> time.strftime("%Y-%m-%d %H:%M:%S",time.gmtime(0))
'1970-01-01 00:00:00'

sql_efficiency_check  -h
Usage of /sql_efficiency_check:
  -conn string
    	database connect string (default "postgresql://root@localhost:26257/defaultdb?sslmode=disable")
  -http string
    	a bind string for the metrics server (default ":8181")
  -lastHr
    	Using "now() - INTERVAL '1hr'"
  -maxStmt int
    	the maximum number of SQL Statements to display for each issue (default 5)
  -metricServer
    	Run Metric Server instead of Report... (default false)
  -showFull
    	Print the FULL statement
  -showPlans
    	Print the FULL Query Plan (default false)

CockroachDB CCL v21.2.7 (x86_64-unknown-linux-gnu, built 2022/03/14 16:37:26, go1.16.6)
ClusterID: 34454c6c-0d95-4625-b8b5-1816bde0e223

=================================================
=== Top Index Join Times by PCT% of Rows Read ===
=================================================
2022-03-17 05:00:00+0000 100.00% Rows :: 2440 RowsPerExec
	 SELECT * FROM connections1000 WHERE local_addr = $1::INET
2022-03-17 04:00:00+0000  99.95% Rows :: 2440 RowsPerExec
	 SELECT * FROM connections1000 WHERE local_addr = $1::INET


======================================================
=== Top EXPLICIT Transactions by PCT of Logical IO ===
======================================================
2022-03-16 23:00:00+0000  38.97% Rows :: 825022630 RowsPerExec
	 SELECT count(*) FROM (SELECT o_w_id, o_d_id, o_id FROM "order" WHERE o
2022-03-17 03:00:00+0000   8.21% Rows :: 399 RowsPerExec
	 SELECT count(*) FROM (SELECT DISTINCT s_i_id FROM order_line JOIN stoc


===========================================
=== Top FULL SCANs by PCT of Logical IO ===
===========================================
2022-03-16 23:00:00+0000  38.97% Rows :: 825022630 RowsPerExec
	 SELECT count(*) FROM (SELECT o_w_id, o_d_id, o_id FROM "order" WHERE o
2022-03-16 23:00:00+0000  35.43% Rows :: 750022630 RowsPerExec
	 SELECT count(*) FROM order_line AS OF SYSTEM TIME '_' GROUP BY ol_w_id


======================================================
=== Top Big SQL statements ===========================
======================================================
2022-03-16 23:00:00+0000  38.97% Rows :: 825022630 RowsPerExec
	 SELECT count(*) FROM (SELECT o_w_id, o_d_id, o_id FROM "order" WHERE o
2022-03-16 23:00:00+0000  35.43% Rows :: 750022630 RowsPerExec
	 SELECT count(*) FROM order_line AS OF SYSTEM TIME '_' GROUP BY ol_w_id


SELECT t.fingerprint_id as tid, s.fingerprint_id as sid, t.statistics->'execution_statistics'->'contentionTime'
FROM crdb_internal.transaction_statistics as t
JOIN crdb_internal.statement_statistics as s
ON (s.transaction_fingerprint_id=t.fingerprint_id AND s.aggregated_ts=t.aggregated_ts)
LIMIT 5;

SELECT t.fingerprint_id as tid, s.fingerprint_id as sid, t.statistics->'execution_statistics'->'contentionTime', s.metadata->'query'
FROM crdb_internal.transaction_statistics as t
JOIN crdb_internal.statement_statistics as s
ON (s.transaction_fingerprint_id=t.fingerprint_id AND s.aggregated_ts=t.aggregated_ts)
WHERE t.statistics->'execution_statistics'->'contentionTime'->'mean' != '0'
LIMIT 5;

WITH stmt_hr_calc AS (
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        metadata->>'query' as queryTxt,
        metadata,
        sampled_plan,
        IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
        IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
        CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT as rowsRead,
        CASE
            WHEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT > CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
                THEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT
            ELSE CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
            END as rowsMean,
        CAST(statistics->'statistics'->'cnt' as INT) as execCnt,
        CASE
            WHEN (sampled_plan @> '{"Name": "index join"}') THEN 1
            WHEN (sampled_plan->'Children'->0->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->1->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->2->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->3->>'Name' = 'index join') THEN 1
            WHEN (sampled_plan->'Children'->4->>'Name' = 'index join') THEN 1
            ELSE 0
            END as iJoinStmt
    FROM crdb_internal.statement_statistics
    WHERE 1=1
      AND app_name not like '$ internal-%' and app_name = 'hashtest'
      AND sampled_plan::TEXT like '%index join%'
) 
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        --queryTxt,
        -- sampled_plan->'Name',
        -- sampled_plan->'Children'->0,
        -- sampled_plan->'Children'->1->>'Name',
        -- sampled_plan->'Children'->2->>'Name',
        -- sampled_plan->'Children'->3->>'Name',
        -- sampled_plan->'Children'->4->>'Name',
        -- sampled_plan->'Children'->5->>'Name',
        -- metadata,
        fullScan,
        iJoinStmt,
        implicitTxn,
        execCnt,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts) as lioAggTotal,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts, fingerprint_id) as lioPerStmt
    FROM stmt_hr_calc
    WHERE aggregated_ts > now() - INTERVAL '2hr';

    WITH stmt_hr_calc AS (
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        metadata->>'query' as queryTxt,
        metadata,
        sampled_plan,
        IF (metadata->'implicitTxn' = 'true', 1, 0) as implicitTxn,
        IF (metadata->'fullScan' = 'true', 1, 0) as fullScan,
        CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT as numRows,
        CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT as rowsRead,
        CASE
            WHEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT > CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
                THEN CAST(statistics->'statistics'->'numRows'->>'mean' as FLOAT)::INT
            ELSE CAST(statistics->'statistics'->'rowsRead'->>'mean' as FLOAT)::INT
            END as rowsMean,
        CAST(statistics->'statistics'->'cnt' as INT) as execCnt,
        IF (sampled_plan::STRING like '%index join%', 1, 0) as ijoinStmt
    FROM crdb_internal.statement_statistics
    WHERE 1=1
      AND app_name not like '$ internal-%' and app_name = 'hashtest'
      AND sampled_plan::TEXT like '%index join%'
) 
    SELECT
        aggregated_ts,
        app_name,
        fingerprint_id,
        queryTxt,
        fullScan,
        iJoinStmt,
        implicitTxn,
        execCnt,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts) as lioAggTotal,
        sum(rowsMean*execCnt) OVER (PARTITION BY aggregated_ts, fingerprint_id) as lioPerStmt
    FROM stmt_hr_calc
    WHERE aggregated_ts > now() - INTERVAL '2hr';


SELECT created_at, mvalue 
FROM events 
WHERE 1=1 AND
    created_at > now() - INTERVAL '1m' AND
    device_id = {};

SELECT m100, count(*), sum(v100), min(ts), max(ts)
FROM events@idx_ts
WHERE ts BETWEEN '{}' and '{}'
GROUP BY m100
ORDER BY 3 DESC
LIMIT 10;

SELECT ts, m100, v100
FROM events@primary
WHERE 
    m100 = {}  AND ts > '{}'
LIMIT 10;

CREATE INDEX idx_m100hash_storing 
ON measure (m100 ASC, ts ASC) USING HASH WITH BUCKET_COUNT = 9 STORING (v100, txtblob);

WITH top100 as (
    SELECT m100, v100
    FROM  {}
    WHERE m100 = {}  AND ts > '{}'
    LIMIT 100
)
SELECT avg(v100) as AVG_VALUE
FROM top100;

WITH top100 as (
    SELECT m100, v100
    FROM measure@primary
    WHERE m100 = 42  AND ts > '2002-01-01'
    LIMIT 100
)
SELECT avg(v100) as AVG_VALUE
FROM top100;

SELECT m100, count(*), sum(v100), min(ts), max(ts)
FROM measure@idx_m100_ts
JOIN (select i from generate_series(1,101) as i) as g
ON (g.i = measure.m100)
WHERE ts BETWEEN '2001-07-01 00:00:00' and '2001-07-01 00:10:00'
GROUP BY m100
ORDER BY 3 desc
LIMIT 10;

create index idx_tshash4_storing on measure(ts) using hash with bucket_count=4 storing (m100, v100);

git clone git@github.com:cockroachdb/cockroach.git
cd cockroach/pkg/workload/
go mod vendor
GOOS=linux GOARCH=amd64 go build  -o bin/workload-amd64-linux workload.go

CREATE TABLE IF NOT EXISTS item_stress (
    uuid1 UUID NOT NULL,
    uuid2 UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    j JSONB NOT NULL,
    id1 INT8 NULL AS ((j->>'k1':::STRING)::INT8) VIRTUAL,
    id2 INT8 NULL AS ((j->>'k2':::STRING)::INT8) VIRTUAL,
    id3 INT8 NULL AS ((j->>'k3':::STRING)::INT8) VIRTUAL,
    id4 INT8 NULL AS ((j->>'k4':::STRING)::INT8) VIRTUAL,
    INDEX idx_created_at (created_at) USING HASH WITH BUCKET_COUNT = 16,
    INDEX idx_updated_at (created_at) USING HASH WITH BUCKET_COUNT = 16,
    INDEX idx_id1 (id1),
    INDEX idx_id2 (id2),
    INDEX idx_id3 (id3),
    INDEX idx_id4 (id4),
    PRIMARY KEY (uuid1, uuid2)
);

CREATE TABLE events_new (
      id UUID NOT NULL,
      thread INT8 NULL,
      ts TIMESTAMPTZ NULL DEFAULT now():::TIMESTAMPTZ,
      id2 INT8 NULL,
      id3 INT8 NULL,
      mvalue INT8 NULL,
      description STRING NULL,
      crdb_internal_expiration TIMESTAMPTZ NOT VISIBLE NOT NULL DEFAULT current_timestamp():::TIMESTAMPTZ + '00:01:00':::INTERVAL ON UPDATE current_timestamp():::TIMESTAMPTZ + '00:01:00':::INTERVAL,
      CONSTRAINT "primary" PRIMARY KEY (id ASC),
      INDEX ts_idx (ts ASC)
  ) WITH (ttl = 'on', ttl_automatic_column = 'on', ttl_expire_after = '00:01:00':::INTERVAL);


docker run -d --name=roach1 --hostname=roach1 --net=roachnet -p 26257:26257 -p 8080:8080  -v "${PWD}/cockroach-data/roach1:/cockroach/cockroach-data"  cockroachdb/cockroach:v21.2.9 start-single-node --insecure

https://github.com/cockroachdb/cockroach/issues/new?assignees=&labels=C-enhancement&template=feature_request.md&title=

```


**Is your feature request related to a problem? Please describe.**
Setting `application_name` by role doesn't actually set the session parameter.

```sql
ALTER ROLE foo SET application_name=bar;
```

**Describe the solution you'd like**
Currently when I run the following and it completes without error but is a noop:

```sql
> ALTER ROLE foo SET application_name=bar;
> SET ROLE foo;
> show session application_name;
  application_name
--------------------
  $ cockroach sql
```

Would like to have the role setting actually set the session paramater like so...

```sql
> set application_name=bar;
SET

> show session application_name;
  application_name
--------------------
  bar
```

**Describe alternatives you've considered**
Setting at the session level, but this doesn't allow control at the provisioning level.


```sql
root@192.168.0.100:26257/defaultdb> show create crdb_internal.tables;
       table_name      |               create_statement
-----------------------+-----------------------------------------------
  crdb_internal.tables | CREATE TABLE crdb_internal.tables (
                       |     table_id INT8 NOT NULL,
                       |     parent_id INT8 NOT NULL,
                       |     name STRING NOT NULL,
                       |     database_name STRING NULL,
                       |     version INT8 NOT NULL,
                       |     mod_time TIMESTAMP NOT NULL,
                       |     mod_time_logical DECIMAL NOT NULL,
                       |     format_version STRING NOT NULL,
                       |     state STRING NOT NULL,
                       |     sc_lease_node_id INT8 NULL,
                       |     sc_lease_expiration_time TIMESTAMP NULL,
                       |     drop_time TIMESTAMP NULL,
                       |     audit_mode STRING NOT NULL,
                       |     schema_name STRING NOT NULL,
                       |     parent_schema_id INT8 NOT NULL,
                       |     locality STRING NULL
                       | )
(1 row)


Time: 16ms total (execution 9ms / network 7ms)

root@192.168.0.100:26257/defaultdb> show create crdb_internal.index_usage_statistics;
               table_name              |                  create_statement
---------------------------------------+------------------------------------------------------
  crdb_internal.index_usage_statistics | CREATE TABLE crdb_internal.index_usage_statistics (
                                       |     table_id INT8 NOT NULL,
                                       |     index_id INT8 NOT NULL,
                                       |     total_reads INT8 NOT NULL,
                                       |     last_read TIMESTAMPTZ NULL
                                       | )

root@192.168.0.100:26257/defaultdb> show create crdb_internal.table_indexes;
          table_name          |              create_statement
------------------------------+---------------------------------------------
  crdb_internal.table_indexes | CREATE TABLE crdb_internal.table_indexes (
                              |     descriptor_id INT8 NULL,
                              |     descriptor_name STRING NOT NULL,
                              |     index_id INT8 NOT NULL,
                              |     index_name STRING NOT NULL,
                              |     index_type STRING NOT NULL,
                              |     is_unique BOOL NOT NULL,
                              |     is_inverted BOOL NOT NULL,
                              |     is_sharded BOOL NOT NULL,
                              |     shard_bucket_count INT8 NULL,
                              |     created_at TIMESTAMP NULL
                              | )

select  total_reads, t.name as table, ti.index_name as index
from crdb_internal.index_usage_statistics as u
join crdb_internal.table_indexes as ti
  on (u.table_id = ti.descriptor_id and u.index_id = ti.index_id)
join crdb_internal.tables as t
  on (t.table_id = u.table_id)
order by 2,3;





root@192.168.0.100:26257/defaultdb> select * from crdb_internal.cluster_contended_keys order by num_contention_events desc limit 5;
  database_name | schema_name | table_name |     index_name     |                               key                                | num_contention_events
----------------+-------------+------------+--------------------+------------------------------------------------------------------+------------------------
  system        | public      | settings   | primary            | /6/1/"version"/0                                                 |                    55
  system        | public      | jobs       | ts_idx             | /15/2/"running"/2022-04-19T22:57:20.495904Z/754773657176965122/0 |                    16
  system        | public      | jobs       | ts_idx             | /15/2/"running"/2022-04-19T22:57:20.23999Z/754773656338333697/0  |                    12
  system        | public      | jobs       | ts_idx             | /15/2/"running"/2022-04-19T22:57:20.230977Z/754773656308842498/0 |                    12
  system        | public      | settings   | ingest_stress_pkey | /6/1/"version"/0

select CAST(statistics->'execution_statistics'->'contentionTime'->>'mean' as FLOAT), statistics->>'statement'
from crdb_internal.statement_statistics
order by 1 DESC limit 2;

select CAST(statistics->'execution_statistics'->'contentionTime'->>'mean' as FLOAT), metadata->>'query'
from crdb_internal.statement_statistics
order by 1 DESC limit 2;
       float8       |                                                         ?column?
--------------------+---------------------------------------------------------------------------------------------------------------------------
  81.05864390983332 | UPDATE warehouse SET w_ytd = w_ytd + $1 WHERE w_id = $2 RETURNING w_name, w_street_1, w_street_2, w_city, w_state, w_zip
  48.58731318348625 | UPDATE warehouse SET w_ytd = w_ytd + $1 WHERE w_id = $2 RETURNING w_name, w_street_1, w_street_2, w_city, w_state, w_zip
(2 rows)


select aggregated_ts, CAST(statistics->'execution_statistics'->'contentionTime'->>'mean' as FLOAT) as contentionTime, metadata->>'query'
from crdb_internal.statement_statistics
order by 2 DESC limit 5;


select aggregated_ts, CAST(statistics->'execution_statistics'->'contentionTime'->>'mean' as FLOAT) as contentionTime, metadata
from crdb_internal.transaction_statistics
order by 2 DESC limit 5;

WITH s1 as (
	select id1, id2, id3, id4
	from ingest_stress
    where id1 between 1 and 1000000
	limit 50000000
)
select id2, sum(id2+id3+id4), count(*)
from s1
group by 1
order by 2
limit 10;

sql.disk.distsql.spilled.bytes.written
sql.distsql.temp_storage.workmem


root@localhost:26257/defaultdb> explain analyze WITH s1 as (
        select id1, id2, id3, id4
        from ingest_stress
    where id1 between 1 and 1000000
        limit 50000000
)
select id2, sum(id2+id3+id4), count(*)
from s1
group by 1
order by 2
limit 10;
                                                    info
------------------------------------------------------------------------------------------------------------
  planning time: 957µs
  execution time: 1m42s
  distribution: full
  vectorized: true
  rows read from KV: 2,328,619 (316 MiB)
  cumulative time spent in KV: 1m21s
  maximum memory usage: 71 MiB
  network usage: 480 B (3 messages)
  max sql temp disk usage: 18 MiB
  regions: us-east1

  • top-k
  │ nodes: n9
  │ regions: us-east1
  │ actual row count: 10
  │ estimated max memory allocated: 10 KiB
  │ estimated max sql temp disk usage: 0 B
  │ estimated row count: 10
  │ order: +sum
  │ k: 10
  │
  └── • group (hash)
      │ nodes: n9
      │ regions: us-east1
      │ actual row count: 902,589
      │ estimated max memory allocated: 54 MiB
      │ estimated max sql temp disk usage: 18 MiB
      │ estimated row count: 23,657,550
      │ group by: id2
      │
      └── • render
          │ nodes: n9
          │ regions: us-east1
          │ actual row count: 2,328,619
          │ estimated row count: 25,850,310
          │
          └── • render
              │ estimated row count: 25,850,310
              │
              └── • index join
                  │ estimated row count: 25,850,310
                  │ table: ingest_stress@ingest_stress_pkey
                  │
                  └── • scan
                        nodes: n9
                        regions: us-east1
                        actual row count: 2,328,619
                        KV time: 1m21s
                        KV contention time: 0µs
                        KV rows read: 2,328,619
                        KV bytes read: 316 MiB
                        estimated max memory allocated: 43 MiB
                        estimated max sql temp disk usage: 0 B
                        estimated row count: 9,900,000 (4.3% of the table; stats collected 17 minutes ago)
                        table: ingest_stress@idx_id1
                        spans: [/1 - /1000000]
                        limit: 50000000
(57 rows)


Time: 102.488s total (execution 102.487s / network 0.001s)


show cluster setting sql.distsql.temp_storage.workmem
  sql.distsql.temp_storage.workmem
------------------------------------
  64 MiB

set cluster setting sql.distsql.temp_storage.workmem='1024MiB';


set cluster setting sql.distsql.max_running_flows=4096;

WITH s1 as (
	select id1, id2, id3, id4
	from ingest_stress@primary
	limit 1000000
)
select id2, sum(id2+id3+id4), count(*)
from s1
group by 1
order by 2
limit 10;

ALTER TABLE ingest_stress
SET (ttl_expire_after = '6h');


spanconfig.kvaccessor.batch_size

create table testagg (
	c1 int,
	c2 int,
	c3 int,
	id uuid default gen_random_uuid(),
	primary key (id),
	index idx_call (c1, c2, c3)
);

select c3,c2,c1,count(*)
from testagg as of system time follower_read_timestamp()
group by 1,2,3
order by c3 desc, c2 asc, c1 desc;

spanconfig.kvaccessor.batch_size


grafana-cli admin reset-admin-password --homepath "/usr/share/gra


cockroach sql --url 'postgres://glenn:glenn@crdb.roach.sonic.tmachine.io:26257?sslmode=disable'


DROP DATABASE seq_unordered CASCADE;
CREATE DATABASE seq_unordered;

USE seq_unordered;

CREATE SEQUENCE s1 INCREMENT BY 1;
CREATE SEQUENCE s100 CACHE 100 INCREMENT BY 1;


create table log_seq1 (
    id INT DEFAULT nextval('s1') PRIMARY KEY,
    ts TIMESTAMPTZ NULL DEFAULT now():::TIMESTAMPTZ,
    eventname STRING NULL
);

create table log_seq100 (
    id INT DEFAULT nextval('s100') PRIMARY KEY,
    ts TIMESTAMPTZ NULL DEFAULT now():::TIMESTAMPTZ,
    eventname STRING NULL
);

create table log_unordered (
    id INT DEFAULT unordered_unique_rowid() PRIMARY KEY,
    ts TIMESTAMPTZ NULL DEFAULT now():::TIMESTAMPTZ,
    eventname STRING NULL
);
```

## Max Nodeid

```sql
select max(node_id) = crdb_internal.node_id() from crdb_internal.gossip_nodes;
```

## Set SQL Prompt

```sql
\set prompt1 >
```

## Unordered Unique Rowid

```sql
alter table test alter column id set default unordered_unique_rowid();
```


## pprof

```bash
go tool pprof -http localhost:8001 heap_n1_20220617_2031.pprof
```