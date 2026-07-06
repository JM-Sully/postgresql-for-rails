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
