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
