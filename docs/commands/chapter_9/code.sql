psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing


SELECT ctid, id FROM users WHERE id = 1;
ctid | id 
------+----
(0 rows)

Time: 1.282 ms

SELECT COUNT(*) FROM users;
  count   
----------
  10000900
(1 row)

Time: 412.722 ms

-- output ids from 5 users
SELECT id FROM users LIMIT 5;
  id  
------
  1864
  1871
  1877
  1894
  1920
(5 rows)

SELECT ctid, id FROM users WHERE id = 1864;
  ctid    |  id  
----------+------
  (32,15) | 1864
(1 row)

-- update the user with id 1864
UPDATE users SET first_name = 'Jess' WHERE id = 1864;
UPDATE 1

-- check the ctid of the user with id 1864
SELECT ctid, id FROM users WHERE id = 1864;
  ctid    |  id  
----------+------
  (32,57) | 1864
(1 row)

Time: 1.333 ms

-- new day from page 205
-- Tuning Autovacuum
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- show the autovacuum settings
SELECT name, setting, unit FROM pg_settings WHERE name LIKE 'autovacuum%' ORDER BY name;

                name                  |  setting  | unit 
---------------------------------------+-----------+------
autovacuum                            | on        | 
autovacuum_analyze_scale_factor       | 0.1       | 
autovacuum_analyze_threshold          | 50        | 
autovacuum_freeze_max_age             | 200000000 | 
autovacuum_max_workers                | 3         | 
autovacuum_multixact_freeze_max_age   | 400000000 | 
autovacuum_naptime                    | 60        | s
autovacuum_vacuum_cost_delay          | 2         | ms
autovacuum_vacuum_cost_limit          | -1        | 
autovacuum_vacuum_insert_scale_factor | 0.2       | 
autovacuum_vacuum_insert_threshold    | 1000      | 
autovacuum_vacuum_scale_factor        | 0.2       | 
autovacuum_vacuum_threshold           | 50        | 
autovacuum_work_mem                   | -1        | kB
(14 rows)

-- set the autovacuum analyze scale factor to 0.01, 1% of the table size
ALTER TABLE trips SET (autovacuum_analyze_scale_factor = 0.01);
ALTER TABLE

-- change the global value of autovacuum_vacuum_cost_limit
ALTER SYSTEM SET autovacuum_vacuum_cost_limit = 1000;
ALTER SYSTEM

-- reload the configuration
SELECT pg_reload_conf();

-- see if it's been changed
SELECT name, setting, unit FROM pg_settings WHERE name LIKE 'autovacuum%' ORDER BY name;
                name                  |  setting  | unit 
---------------------------------------+-----------+------
autovacuum                            | on        | 
autovacuum_analyze_scale_factor       | 0.1       | 
autovacuum_analyze_threshold          | 50        | 
autovacuum_freeze_max_age             | 200000000 | 
autovacuum_max_workers                | 3         | 
autovacuum_multixact_freeze_max_age   | 400000000 | 
autovacuum_naptime                    | 60        | s
autovacuum_vacuum_cost_delay          | 2         | ms
autovacuum_vacuum_cost_limit          | 1000      | 
autovacuum_vacuum_insert_scale_factor | 0.2       | 
autovacuum_vacuum_insert_threshold    | 1000      | 
autovacuum_vacuum_scale_factor        | 0.2       | 
autovacuum_vacuum_threshold           | 50        | 
autovacuum_work_mem                   | -1        | kB



VACUUM VERBOSE trips;
INFO:  vacuuming "rideshare_development.rideshare.trips"
INFO:  finished vacuuming "rideshare_development.rideshare.trips": index scans: 1
pages: 0 removed, 33 remain, 33 scanned (100.00% of total)
tuples: 4 removed, 1009 remain, 0 are dead but not yet removable
removable cutoff: 5725501, which was 0 XIDs old when operation ended
new relminmxid: 217057, which is 1215 MXIDs ahead of previous value
frozen: 1 pages from table (3.03% of total) had 4 tuples frozen
index scan needed: 1 pages from table (3.03% of total) had 3 dead item identifiers removed
index "trips_pkey": pages: 9 in total, 0 newly deleted, 0 currently deleted, 0 reusable
index "index_trips_on_driver_id": pages: 5 in total, 0 newly deleted, 0 currently deleted, 0 reusable
index "index_trips_on_rating": pages: 5 in total, 0 newly deleted, 0 currently deleted, 0 reusable
index "index_trips_on_trip_request_id": pages: 9 in total, 0 newly deleted, 0 currently deleted, 0 reusable
index "trips_data_path_ops": pages: 3 in total, 0 newly deleted, 1 currently deleted, 1 reusable
index "trips_btree_expr": pages: 2 in total, 0 newly deleted, 0 currently deleted, 0 reusable
index "trips_completed_at_index": pages: 5 in total, 0 newly deleted, 0 currently deleted, 0 reusable
avg read rate: 24.146 MB/s, avg write rate: 5.017 MB/s
buffer usage: 137 hits, 77 misses, 16 dirtied
WAL usage: 19 records, 11 full page images, 44230 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.02 s
INFO:  vacuuming "rideshare_development.pg_toast.pg_toast_5035003"
INFO:  finished vacuuming "rideshare_development.pg_toast.pg_toast_5035003": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total)
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 5725501, which was 0 XIDs old when operation ended
new relfrozenxid: 5725501, which is 26183 XIDs ahead of previous value
new relminmxid: 217057, which is 1215 MXIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 4.088 MB/s, avg write rate: 8.176 MB/s
buffer usage: 21 hits, 1 misses, 2 dirtied
WAL usage: 1 records, 1 full page images, 7897 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
Time: 30.865 ms


SELECT name, setting, unit FROM pg_settings WHERE name LIKE 'vacuum%' ORDER BY name;
              name                |  setting   | unit 
-----------------------------------+------------+------
vacuum_buffer_usage_limit         | 256        | kB
vacuum_cost_delay                 | 0          | ms
vacuum_cost_limit                 | 200        | 
vacuum_cost_page_dirty            | 20         | 
vacuum_cost_page_hit              | 1          | 
vacuum_cost_page_miss             | 2          | 
vacuum_failsafe_age               | 1600000000 | 
vacuum_freeze_min_age             | 50000000   | 
vacuum_freeze_table_age           | 150000000  | 
vacuum_multixact_failsafe_age     | 1600000000 | 
vacuum_multixact_freeze_min_age   | 5000000    | 
vacuum_multixact_freeze_table_age | 150000000  | 
(12 rows)

VACUUM VERBOSE trips;

-- new day from page 207, still on params
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- delete the trip with id 20
DELETE FROM trips WHERE id = 20;

-- update the trip with id 21 to have a rating of 5
UPDATE trips SET rating = 5 WHERE id = 21;

-- see the xmin, xmax, ctid, and id of the trip for ids 18-22
SELECT xmin, xmax, ctid, id
FROM trips
WHERE id BETWEEN 18 AND 22;
xmin    | xmax |  ctid   | id 
--------+------+---------+----
5699345 |    0 | (0,1)   | 18
5699345 |    0 | (0,2)   | 19
5725561 |    0 | (0,105) | 21
5699345 |    0 | (0,5)   | 22
(4 rows)
-- xmin (creating transaction) transaction that inserted (or last rewrote) this version
-- xmax (deleting/updating transaction, or 0 if still live)
-- ctid — physical location (page, slot)

-- output the relname, relfrozenxid, and xids_behind of the trips table
SELECT relname,
       relfrozenxid,
       age(relfrozenxid) AS xids_behind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'rideshare'
  AND relname = 'trips';

relname | relfrozenxid | xids_behind 
--------+--------------+-------------
trips   |      5699345 |       26224
(1 row)
-- relfrozenid: is the table-level oldest unfrozen XID still referenced by live row versions in that table.
-- xids_behind is how many transaction IDs (XIDs) have been issued since the table’s oldest unfrozen XID.


-- Compare to the thresholds
SELECT relname,
       age(relfrozenxid) AS xids_behind,
       current_setting('vacuum_freeze_table_age')::bigint AS table_age_limit,
       current_setting('vacuum_failsafe_age')::bigint AS failsafe_limit
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'rideshare'
  AND relname = 'trips';
relname | xids_behind | table_age_limit | failsafe_limit 
--------+-------------+-----------------+----------------
trips   |       26224 |       150000000 |     1600000000

-- table_age_limit isn't “freezing starts here” — it's “start scanning the entire table aggressively to freeze, because normal vacuum isn't visiting enough pages.” Individual rows become freeze-eligible much earlier, at vacuum_freeze_min_age (50M).

-- VACUUM (FREEZE) is a special form of VACUUM that freezes all rows in the table.
VACUUM (FREEZE);
frozen: 9 pages ... had 922 tuples frozen
new relfrozenxid: 5725569, which is 26224 XIDs ahead of previous value

-- new day from page 207
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- reindex a particular index concurrently
REINDEX (VERBOSE) INDEX CONCURRENTLY index_trips_on_driver_id;
INFO:  index "rideshare.index_trips_on_driver_id" was reindexed
DETAIL:  CPU: user: 0.00 s, system: 0.01 s, elapsed: 0.05 s.
REINDEX
Time: 59.291 ms

-- reindex a table concurrently
REINDEX (VERBOSE) TABLE CONCURRENTLY trips;
INFO:  index "rideshare.trips_pkey" was reindexed
INFO:  index "rideshare.index_trips_on_rating" was reindexed
INFO:  index "rideshare.index_trips_on_trip_request_id" was reindexed
INFO:  index "rideshare.trips_data_path_ops" was reindexed
INFO:  index "rideshare.trips_btree_expr" was reindexed
INFO:  index "rideshare.trips_completed_at_index" was reindexed
INFO:  index "rideshare.index_trips_on_driver_id" was reindexed
INFO:  index "pg_toast.pg_toast_5035003_index" was reindexed
INFO:  table "rideshare.trips" was reindexed
DETAIL:  CPU: user: 0.01 s, system: 0.01 s, elapsed: 0.07 s.
REINDEX
Time: 72.442 ms


-- new day from page 208
-- Running manual vacuums

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- vacuum a table and update the statistics by running ANALYZE
VACUUM (ANALYZE, VERBOSE) users;


rideshare_development=# VACUUM (ANALYZE, VERBOSE) users;
INFO:  vacuuming "rideshare_development.rideshare.users"
INFO:  launched 2 parallel vacuum workers for index cleanup (planned: 2)
INFO:  finished vacuuming "rideshare_development.rideshare.users": index scans: 0
pages: 0 removed, 147669 remain, 334 scanned (0.23% of total)
tuples: 0 removed, 10000900 remain, 0 are dead but not yet removable
removable cutoff: 5725590, which was 0 XIDs old when operation ended
new relfrozenxid: 5725590, which is 20 XIDs ahead of previous value
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
index scan bypassed: 334 pages from table (0.23% of total) have 19324 dead item identifiers
avg read rate: 82.546 MB/s, avg write rate: 0.210 MB/s
buffer usage: 135 hits, 394 misses, 1 dirtied
WAL usage: 1 records, 1 full page images, 7153 bytes
system usage: CPU: user: 0.00 s, system: 0.01 s, elapsed: 0.03 s
INFO:  vacuuming "rideshare_development.pg_toast.pg_toast_5035007"
INFO:  finished vacuuming "rideshare_development.pg_toast.pg_toast_5035007": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total)
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 5725590, which was 0 XIDs old when operation ended
new relfrozenxid: 5725590, which is 20 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 15.563 MB/s, avg write rate: 0.000 MB/s
buffer usage: 26 hits, 1 misses, 0 dirtied
WAL usage: 1 records, 0 full page images, 188 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
INFO:  analyzing "rideshare.users"
INFO:  "users": scanned 147669 of 147669 pages, containing 10000900 live rows and 19324 dead rows;
  3000000 rows in sample, 10000900 estimated total rows
VACUUM
Time: 9073.615 ms (00:09.074)

-- skip locked tables
VACUUM (SKIP_LOCKED) trip_requests, trips;
VACUUM
Time: 43.006 ms

-- show last_analyze and last_auto_analyze_at
SELECT
  schemaname,
  relname,
  last_autoanalyze,
  last_analyze
FROM pg_stat_all_tables
WHERE relname = 'vehicles';

 schemaname | relname  | last_autoanalyze | last_analyze 
------------+----------+------------------+--------------
 rideshare  | vehicles |                  | 
(1 row)

SELECT
  schemaname,
  relname,
  last_autoanalyze,
  last_analyze
FROM pg_stat_all_tables
WHERE relname = 'trips';

 schemaname | relname |       last_autoanalyze        | last_analyze
------------+---------+-------------------------------+--------------
 rideshare  | trips   | 2026-06-09 12:45:39.686271+01 |
(1 row)

SELECT
  schemaname,
  relname,
  last_autoanalyze,
  last_analyze
FROM pg_stat_all_tables
WHERE relname = 'users';
 schemaname | relname | last_autoanalyze |         last_analyze
------------+---------+------------------+-------------------------------
 rideshare  | users   |                  | 2026-07-07 13:04:52.628685+01
(1 row)

-- change parallel workers to 4, default is 2
SET MAX_PARALLEL_MAINTENANCE_WORKERS=4;
SET

VACUUM (PARALLEL 4, VERBOSE) users;
INFO:  vacuuming "rideshare_development.rideshare.users"
INFO:  launched 4 parallel vacuum workers for index cleanup (planned: 4)
INFO:  finished vacuuming "rideshare_development.rideshare.users": index scans: 0
pages: 0 removed, 147669 remain, 334 scanned (0.23% of total)
tuples: 0 removed, 10000900 remain, 0 are dead but not yet removable
removable cutoff: 5725591, which was 0 XIDs old when operation ended
new relfrozenxid: 5725591, which is 1 XIDs ahead of previous value
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
index scan bypassed: 334 pages from table (0.23% of total) have 19324 dead item identifiers
avg read rate: 50.110 MB/s, avg write rate: 0.151 MB/s
buffer usage: 112 hits, 332 misses, 1 dirtied
WAL usage: 1 records, 1 full page images, 7153 bytes
system usage: CPU: user: 0.00 s, system: 0.02 s, elapsed: 0.05 s
INFO:  vacuuming "rideshare_development.pg_toast.pg_toast_5035007"
INFO:  finished vacuuming "rideshare_development.pg_toast.pg_toast_5035007": index scans: 0
pages: 0 removed, 0 remain, 0 scanned (100.00% of total)
tuples: 0 removed, 0 remain, 0 are dead but not yet removable
removable cutoff: 5725591, which was 0 XIDs old when operation ended
new relfrozenxid: 5725591, which is 1 XIDs ahead of previous value
frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
avg read rate: 0.000 MB/s, avg write rate: 0.000 MB/s
buffer usage: 6 hits, 0 misses, 0 dirtied
WAL usage: 1 records, 0 full page images, 188 bytes
system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
VACUUM
Time: 57.539 ms

-- new day from page 209
-- Simulating bloat and understanding impact

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- top updated tables, including HOT updates
-- https://medium.com/nerd-for-tech/postgres-fillfactor-baf3117aca0a
SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relname::regclass)) AS full_size,
    pg_size_pretty(pg_relation_size(relname::regclass)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relname::regclass) - pg_relation_size(relname::regclass)) AS index_size,
    n_tup_upd,
    n_tup_hot_upd,
    ((nullif (n_tup_hot_upd::float, 0) / nullif (n_tup_upd::float, 0)) * 100) AS hot_upd_percent
FROM
    pg_stat_user_tables
ORDER BY
    n_tup_upd DESC
LIMIT 10;
ERROR:  relation "hints" does not exist

SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relname::regclass)) AS full_size,
    pg_size_pretty(pg_relation_size(relname::regclass)) AS table_size,
    pg_size_pretty(pg_total_relation_size(relname::regclass) - pg_relation_size(relname::regclass)) AS index_size,
    n_tup_upd,
    n_tup_hot_upd,
    ((nullif (n_tup_hot_upd::float, 0) / nullif (n_tup_upd::float, 0)) * 100) AS hot_upd_percent
FROM
    pg_stat_user_tables
WHERE
  schemaname = 'rideshare'
ORDER BY
    n_tup_upd DESC
LIMIT 10;

schemaname |       relname        | full_size | table_size | index_size | n_tup_upd | n_tup_hot_upd |  hot_upd_percent   
-----------+----------------------+-----------+------------+------------+-----------+---------------+--------------------
rideshare  | trips                | 504 kB    | 264 kB     | 240 kB     |      2020 |            14 | 0.6930693069306931
rideshare  | users                | 4598 MB   | 1154 MB    | 3444 MB    |        22 |             0 |                   
rideshare  | vehicles             | 24 kB     | 0 bytes    | 24 kB      |         0 |             0 |                   
rideshare  | trip_requests        | 208 kB    | 72 kB      | 136 kB     |         0 |             0 |                   
rideshare  | vehicle_reservations | 24 kB     | 0 bytes    | 24 kB      |         0 |             0 |                   
rideshare  | trip_positions       | 611 MB    | 385 MB     | 226 MB     |         0 |             0 |                   
rideshare  | schema_migrations    | 64 kB     | 8192 bytes | 56 kB      |         0 |             0 |                   
rideshare  | locations            | 96 kB     | 8192 bytes | 88 kB      |         0 |             0 |                   
rideshare  | ar_internal_metadata | 64 kB     | 8192 bytes | 56 kB      |         0 |             0 |                   
rideshare  | fast_search_results  | 64 kB     | 8192 bytes | 56 kB      |         0 |             0 |                   
(10 rows)

Time: 22.593 ms


-- open a psql session to simulate bloat
psql

-- check if I have a temp users table
SELECT COUNT(*) FROM temp.users;
  count
----------
  10000000

-- This is the script to estimate the bloat of a table
https://github.com/ioguix/pgsql-bloat-estimation/blob/master/table/table_bloat.sql
/* WARNING: executed with a non-superuser role, the query inspect only tables and materialized view (9.3+) you are granted to read.
* This query is compatible with PostgreSQL 9.0 and more
*/
SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size,
  (tblpages-est_tblpages)*bs AS extra_size,
  CASE WHEN tblpages > 0 AND tblpages - est_tblpages > 0
    THEN 100 * (tblpages - est_tblpages)/tblpages::float
    ELSE 0
  END AS extra_pct, fillfactor,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN (tblpages-est_tblpages_ff)*bs
    ELSE 0
  END AS bloat_size,
  CASE WHEN tblpages > 0 AND tblpages - est_tblpages_ff > 0
    THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
    ELSE 0
  END AS bloat_pct, is_na
  -- , tpl_hdr_size, tpl_data_size, (pst).free_percent + (pst).dead_tuple_percent AS real_frag -- (DEBUG INFO)
FROM (
  SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
    ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
    tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    -- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  FROM (
    SELECT
      ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
      ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
      toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      -- , tpl_hdr_size, tpl_data_size
    FROM (
      SELECT
        tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
        tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
        coalesce(toast.reltuples, 0) AS toasttuples,
        coalesce(substring(
          array_to_string(tbl.reloptions, ' ')
          FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
        current_setting('block_size')::numeric AS bs,
        CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
        24 AS page_hdr,
        23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
           + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
        sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
        bool_or(att.atttypid = 'pg_catalog.name'::regtype)
          OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
      FROM pg_attribute AS att
        JOIN pg_class AS tbl ON att.attrelid = tbl.oid
        JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
        LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
          AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
        LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
      WHERE NOT att.attisdropped
        AND tbl.relkind in ('r','m')
      GROUP BY 1,2,3,4,5,6,7,8,9,10
      ORDER BY 2,3
    ) AS s
  ) AS s2
) AS s3
-- WHERE NOT is_na
--   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
-- make this change to run the query for the temp users table
WHERE schemaname = 'temp' AND tblname = 'users'
ORDER BY schemaname, tblname;

  current_database | schemaname | tblname | real_size  | extra_size |     extra_pct      | fillfactor | bloat_size |bloat_pct           | is_na
------------------+------------+---------+------------+------------+--------------------+------------+------------+--------------------+-------
  scan             | temp       | users   | 1089470464 |    6291456 | 0.5774783445620789 |        100 |    6291456 | 0.5774783445620789 | f
(1 row)

bloat_pct — estimated bloat percentage (book expects low, e.g. under 5%, on a fresh table)
bloat_size — estimated wasted space in bytes
extra_pct — includes fillfactor + alignment padding + bloat
is_na — if true, the estimate isn’t reliable; ignore those rows

-- simulate bloat (I ran this 3 or 4 times, can't remember)
UPDATE temp.users
SET first_name =
CASE (seq % 2)
WHEN 0 THEN 'Bill' || FLOOR(RANDOM() * 10)
ELSE 'Jane' || FLOOR(RANDOM() * 10)
END
FROM GENERATE_SERIES(1, 1_000_000) seq
WHERE id = seq;

-- re-run the query to estimate the bloat
-- (see previous query)
 current_database | schemaname | tblname | real_size  | extra_size |     extra_pct      | fillfactor | bloat_size |     bloat_pct      | is_na 
------------------+------------+---------+------------+------------+--------------------+------------+------------+--------------------+-------
 scan             | temp       | users   | 1089470464 |    6291456 | 0.5774783445620789 |        100 |    6291456 | 0.5774783445620789 | f
(1 row)

-- see the number of dead tuples
SELECT n_live_tup, n_dead_tup, n_tup_upd, n_tup_hot_upd
FROM pg_stat_user_tables
WHERE schemaname = 'temp' AND relname = 'users';
  n_live_tup| n_dead_tup | n_tup_upd | n_tup_hot_upd 
------------+------------+-----------+---------------
    9999194 |    2999931 |   3000000 |          2508
(1 row)


CREATE EXTENSION IF NOT EXISTS pgstattuple;
SELECT * FROM pgstattuple('temp.users');
table_len  | tuple_count | tuple_len  | tuple_percent | dead_tuple_count | dead_tuple_len | dead_tuple_percent | free_space | free_percent 
-----------+-------------+------------+---------------+------------------+----------------+--------------------+------------+--------------
1391632384 |    10000000 | 1031756920 |         74.14 |          1001130 |       95863416 |               6.89 |  207255876 |        14.89