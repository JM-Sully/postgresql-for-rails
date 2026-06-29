-- start of chapter 8 from page 169
-- start a new psql session
psql

CREATE SCHEMA IF NOT EXISTS temp;
-- CREATE SCHEMA

DROP TABLE IF EXISTS temp.users;
-- NOTICE:  table "users" does not exist, skipping
-- DROP TABLE

BEGIN;
-- BEGIN

SET LOCAL statement_timeout = '120s';
-- SET

CREATE TABLE IF NOT EXISTS temp.users
WITH (autovacuum_enabled = false) AS
SELECT
  seq AS id,
  'fname' || seq AS first_name,
  'lname' || seq AS last_name,
  'user_' || seq || '@' || (
    CASE (RANDOM() * 2)::INT
      WHEN 0 THEN 'gmail'
      WHEN 1 THEN 'hotmail'
      WHEN 2 THEN 'yahoo'
    END
  ) || '.com' AS email,
  CASE (seq % 2)
    WHEN 0 THEN 'Driver'
    ELSE 'Rider'
  END AS type,
  NOW() AS created_at,
  NOW() AS updated_at
FROM GENERATE_SERIES(1, 10_000_000) seq;
-- SELECT 10000000

COMMIT;
-- COMMIT

VACUUM ANALYZE temp.users;
-- VACUUM

-- turn on the timer
\timing
-- Timing is on.

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM temp.users
WHERE last_name IN ('lname1000', 'lname10000', 'lname100000');

                                                      QUERY PLAN                                                       
------------------------------------------------------------------------------------------------------------------------
Gather  (cost=1000.00..191279.35 rows=3 width=73) (actual time=2.859..592.158 rows=3 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=2080 read=130912
  ->  Parallel Seq Scan on users  (cost=0.00..190279.05 rows=1 width=73) (actual time=197.193..576.595 rows=1 loops=3)
        Filter: (last_name = ANY ('{lname1000,lname10000,lname100000}'::text[]))
        Rows Removed by Filter: 3333332
        Buffers: shared hit=2080 read=130912
Planning:
  Buffers: shared hit=33 read=4
Planning Time: 2.648 ms
Execution Time: 592.499 ms
(12 rows)

Time: 598.704 ms

-- it did a parallel sequential scan which is the first time I've seen this!

-- create an index on the last_name column (don't need to use CUNCURRENTLY because this is a temp table)
CREATE INDEX users_last_name_idx ON temp.users (last_name);
-- CREATE INDEX
-- Time: 7235.985 ms (00:07.236)
-- That took some time!!

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM temp.users
WHERE last_name IN ('lname1000', 'lname10000', 'lname100000');

                                                        QUERY PLAN                                                          
-----------------------------------------------------------------------------------------------------------------------------
Index Scan using users_last_name_idx on users  (cost=0.43..20.01 rows=3 width=73) (actual time=0.430..0.621 rows=3 loops=1)
  Index Cond: (last_name = ANY ('{lname1000,lname10000,lname100000}'::text[]))
  Buffers: shared hit=9 read=6
Planning:
  Buffers: shared hit=15 read=1
Planning Time: 2.006 ms
Execution Time: 1.143 ms
(7 rows)

Time: 3.871 ms

-- using an index scan, which makes sense, and it's significantly faster
-- the row estimates are accurate now too (they weren't in the sequential scan)

-- run the same query again
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM temp.users
WHERE last_name IN ('lname1000', 'lname10000', 'lname100000');

                                                        QUERY PLAN                                                          
-----------------------------------------------------------------------------------------------------------------------------
Index Scan using users_last_name_idx on users  (cost=0.43..20.01 rows=3 width=73) (actual time=0.078..0.097 rows=3 loops=1)
  Index Cond: (last_name = ANY ('{lname1000,lname10000,lname100000}'::text[]))
  Buffers: shared hit=12
Planning Time: 0.160 ms
Execution Time: 0.309 ms
(5 rows)

-- even faster since everything is in memory now


SHOW shared_buffers;
--  shared_buffers 
-- ----------------
--  128MB
-- (1 row)

-- Time: 0.295 ms

-- Note that this index already exists in the rideshare database
db/migrate/20220716020213_add_index_users_last_name.rb


-- unrelated, but adding so it exists
-- quick way to veiw a sequence ( *<table name>*)
\ds *specialist*

-- new day from page 178
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

ALTER TABLE users ADD COLUMN deleted_at timestamptz;
-- ALTER TABLE

-- index supporting queries for 'soft deleted' users
CREATE INDEX IF NOT EXISTS index_users_deleted_email_partial
ON users
USING BTREE (email)
WHERE deleted_at IS NULL;
-- CREATE INDEX

\timing

-- soft delete some users
UPDATE users
SET deleted_at = NOW()
WHERE id <= 20;
-- UPDATE 20
-- Time: 40.986 ms

-- update date stats following delete
ANALYZE (VERBOSE) users;
-- INFO:  analyzing "rideshare.users"
-- INFO:  "users": scanned 147669 of 147669 pages, containing 10020200 live rows and 20 dead rows; 3000000 rows in sample, 10020200 estimated total rows
-- ANALYZE
-- Time: 8891.162 ms (00:08.891)

SELECT email
FROM users
WHERE deleted_at IS NOT NULL;
-- 20 records returned

EXPLAIN (ANALYZE, BUFFERS)
SELECT email
FROM users
WHERE deleted_at IS NOT NULL;
                                                      QUERY PLAN                                                       
------------------------------------------------------------------------------------------------------------------------
Gather  (cost=1000.00..190421.83 rows=20 width=23) (actual time=330.531..336.145 rows=20 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=226 read=147443
  ->  Parallel Seq Scan on users  (cost=0.00..189419.83 rows=8 width=23) (actual time=317.612..317.615 rows=7 loops=3)
        Filter: (deleted_at IS NOT NULL)
        Rows Removed by Filter: 3340060
        Buffers: shared hit=226 read=147443
Planning Time: 1.702 ms
Execution Time: 336.902 ms
(10 rows)

Time: 341.215 ms

-- the above is using a sequential scan, but the expectation from the book was that this would use the index_users_deleted_email_partial index
-- but that's because I created the index for IS NULL, not IS NOT NULL

-- drop the index
DROP INDEX IF EXISTS index_users_deleted_email_partial;
-- DROP INDEX

-- create a new index for IS NOT NULL
CREATE INDEX IF NOT EXISTS index_users_deleted_email_partial
ON users
USING BTREE (email)
WHERE deleted_at IS NOT NULL;
-- CREATE INDEX

-- re analyze the table
ANALYZE (VERBOSE) users;

EXPLAIN (ANALYZE, BUFFERS)
SELECT email
FROM users
WHERE deleted_at IS NOT NULL;

                                                                  QUERY PLAN                                                                    
--------------------------------------------------------------------------------------------------------------------------------------------------
Index Only Scan using index_users_deleted_email_partial on users  (cost=0.14..12.59 rows=30 width=23) (actual time=0.035..0.047 rows=20 loops=1)
  Heap Fetches: 20
  Buffers: shared hit=12 read=1
Planning:
  Buffers: shared hit=16 read=1
Planning Time: 2.502 ms
Execution Time: 0.216 ms
(7 rows)

Time: 3.507 ms
-- partial index is used, and it's much faster!

CREATE INDEX IF NOT EXISTS index_users_deleted_email_multi
ON users USING BTREE (deleted_at, email);
-- CREATE INDEX
-- Time: 12277.966 ms (00:12.278)
-- quite a long time but it's a big table!

\d users;
                                              Table "rideshare.users"
        Column         |              Type              | Collation | Nullable |              Default              
------------------------+--------------------------------+-----------+----------+-----------------------------------
id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
first_name             | character varying              |           | not null | 
last_name              | character varying              |           | not null | 
email                  | character varying              |           | not null | 
type                   | character varying              |           | not null | 
created_at             | timestamp(6) without time zone |           | not null | 
updated_at             | timestamp(6) without time zone |           | not null | 
password_digest        | character varying              |           |          | 
trips_count            | integer                        |           |          | 
drivers_license_number | character varying(100)         |           |          | 
deleted_at             | timestamp with time zone       |           |          | 
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_deleted_email_multi" btree (deleted_at, email)
    "index_users_deleted_email_partial" btree (email) WHERE deleted_at IS NOT NULL
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_last_name_and_email" btree (last_name, email)
    "index_users_on_type" btree (type)
Referenced by:
    TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
    TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)

-- we've got both our indexes

-- drop the partial index
DROP INDEX IF EXISTS index_users_deleted_email_partial;
-- DROP INDEX
-- Time: 2.976 ms


EXPLAIN (ANALYZE, BUFFERS)
SELECT email
FROM users
WHERE deleted_at IS NOT NULL;
                                                                  QUERY PLAN                                                                   
-----------------------------------------------------------------------------------------------------------------------------------------------
Index Only Scan using index_users_deleted_email_multi on users  (cost=0.56..9.09 rows=30 width=23) (actual time=1.024..1.040 rows=20 loops=1)
  Index Cond: (deleted_at IS NOT NULL)
  Heap Fetches: 20
  Buffers: shared hit=12 read=4
Planning:
  Buffers: shared hit=11 read=1
Planning Time: 2.444 ms
Execution Time: 1.286 ms
(8 rows)

Time: 4.598 ms
-- slower than the previous on, but I suppose could be used if you wanted to return users?
-- still an index only scan which is super fast

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM users
WHERE deleted_at IS NOT NULL;

                                                                QUERY PLAN                                                                 
--------------------------------------------------------------------------------------------------------------------------------------------
Index Scan using index_users_deleted_email_multi on users  (cost=0.56..59.84 rows=30 width=166) (actual time=0.015..0.024 rows=20 loops=1)
  Index Cond: (deleted_at IS NOT NULL)
  Buffers: shared hit=15
Planning:
  Buffers: shared hit=42 dirtied=4
Planning Time: 0.532 ms
Execution Time: 0.601 ms
(7 rows)

Time: 2.813 ms
-- Getting the users that are deleted uses the multi-column index, index scan, which is good!

SELECT
PG_SIZE_PRETTY(
  PG_TOTAL_RELATION_SIZE('index_users_deleted_email_multi')
);
--  pg_size_pretty 
-- ----------------
--  515 MB
-- (1 row)

-- Time: 3.571 ms

-- recreate the partial index
CREATE INDEX IF NOT EXISTS index_users_deleted_email_partial
ON users USING BTREE (email)
WHERE deleted_at IS NOT NULL;

SELECT
PG_SIZE_PRETTY(
  PG_TOTAL_RELATION_SIZE('index_users_deleted_email_partial')
);
--  pg_size_pretty 
-- ----------------
--  16 kB
-- (1 row)

-- Time: 2.171 ms

-- the partial index is significantly smaller!

-- new day from page 181
-- start a new psql session
psql

-- turn on timing
\timing


-- create an expression index on the email column
CREATE UNIQUE INDEX IF NOT EXISTS index_temp_users_lower_email_unique
ON temp.users (LOWER(email));
-- CREATE INDEX
-- Time: 11525.171 ms (00:11.525)


-- this shouldn't work because the email is not unique once it's converted to lowercase
INSERT INTO temp.users (
  first_name, last_name, email, type, created_at, updated_at
)
VALUES
  ('Jess', 'Example', 'Jess@example.com', 'Driver', NOW(), NOW()),
  ('jess', 'example2', 'jess@example.com', 'Driver', NOW(), NOW());
-- ERROR:  duplicate key value violates unique constraint "index_temp_users_lower_email_unique"
-- DETAIL:  Key (lower(email))=(jess@example.com) already exists.
-- Time: 6.868 ms

-- I wonder if this is the best way to do this? Could have a check constraint on the email column to ensure it's unique

-- new day from page 182
-- Using GIN indexes with JSON (Generalized Inverted Index types)
-- need to efficiently query for data within a JSON structure. 
-- jsonb supports indexes, json does not

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- assign data to json_string
SELECT
$$'{
  "ride_details": {
    "bags_in_trunk": 1,
    "music_on": true,
    "water_offered": true
  }
}' $$ AS json_string \gset
-- Time: 11.427 ms

-- see the json_string, and also check that it's valid, using JSONB_PRETTY
SELECT JSONB_PRETTY(:json_string);
          jsonb_pretty          
  -------------------------------
  {                            +
      "ride_details": {        +
          "music_on": true,    +
          "bags_in_trunk": 1,  +
          "water_offered": true+
      }                        +
  }
(1 row)

Time: 12.687 ms

SELECT
$$'{
  "ride_details": {
    "bags_in_trunk": 1,
    "music_on": true,
    "water_offered": false
  }
}' $$ AS json_string1 \gset

SELECT
$$'{
  "ride_details": {
    "bags_in_trunk": 2,
    "music_on": true,
    "water_offered": true
  }
}' $$ AS json_string2 \gset

SELECT
$$'{
  "ride_details": {
    "bags_in_trunk": 3,
    "music_on": false,
    "water_offered": true
  }
}' $$ AS json_string3 \gset


-- vertical presentation
\x
-- Expanded display is on.

-- Make sure three rows appear
SELECT :json_string1, :json_string2, :json_string3;
-[ RECORD 1 ]------------------------
  ?column? | {                         +
          |   "ride_details": {       +
          |     "bags_in_trunk": 1,   +
          |     "music_on": true,     +
          |     "water_offered": false+
          |   }                       +
          | }
  ?column? | {                         +
          |   "ride_details": {       +
          |     "bags_in_trunk": 2,   +
          |     "music_on": true,     +
          |     "water_offered": true +
          |   }                       +
          | }
  ?column? | {                         +
          |   "ride_details": {       +
          |     "bags_in_trunk": 3,   +
          |     "music_on": false,    +
          |     "water_offered": true +
          |   }                       +
          | }

Time: 2.768 ms

-- Add the `data` column to the trips table
ALTER TABLE trips ADD COLUMN data jsonb;
-- ALTER TABLE
-- Time: 46.115 ms

-- check that the new column is there
\d trips;
--                                            Table "rideshare.trips"
--      Column      |              Type              | Collation | Nullable |              Default              
-- -----------------+--------------------------------+-----------+----------+-----------------------------------
--  id              | bigint                         |           | not null | nextval('trips_id_seq'::regclass)
--  trip_request_id | bigint                         |           | not null | 
--  driver_id       | integer                        |           | not null | 
--  completed_at    | timestamp without time zone    |           |          | 
--  rating          | integer                        |           |          | 
--  created_at      | timestamp(6) without time zone |           | not null | 
--  updated_at      | timestamp(6) without time zone |           | not null | 
--  data            | jsonb                          |           |          | 


UPDATE trips AS t 
SET data = c.json_string
from (VALUES 
  (:json_string1, 1),
  (:json_string2, 2),
  (:json_string3, 3)
) AS c(json_string, trip_id) 
WHERE c.trip_id = t.id;
-- the above didn't work...


-- struggle was real without the internet
-- ended up adding data for all records, then editing in postico to give variety
UPDATE trips
SET data = '{"ride_details": {"bags_in_trunk": 1,"music_on": true,"water_offered": false}}';

-- check that the first three records have data
SELECT id, data FROM trips WHERE id IN (1,2,3);
-- -[ RECORD 1 ]--------------------------------------------------------------------------
-- id   | 1
-- data | {"ride_details": {"music_on": true, "bags_in_trunk": 1, "water_offered": false}}
-- -[ RECORD 2 ]--------------------------------------------------------------------------
-- id   | 2
-- data | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
-- -[ RECORD 3 ]--------------------------------------------------------------------------
-- id   | 3
-- data | {"ride_details": {"music_on": false, "bags_in_trunk": 3, "water_offered": true}}

EXPLAIN SELECT * FROM trips WHERE data ? 'ride_details';
-[ RECORD 1 ]---------------------------------------------------------
QUERY PLAN | Seq Scan on trips  (cost=0.00..45.61 rows=1009 width=145)
-[ RECORD 2 ]---------------------------------------------------------
QUERY PLAN |   Filter: (data ? 'ride_details'::text)
-- no idex on this column yet, so makes sense that it's a sequential scan

-- turn off the toggle
\x

-- run explain again, because it's much easier to read!
EXPLAIN SELECT * FROM trips WHERE data ? 'ride_details';
                        QUERY PLAN                         
-----------------------------------------------------------
  Seq Scan on trips  (cost=0.00..45.61 rows=1009 width=145)
    Filter: (data ? 'ride_details'::text)
(2 rows)
Time: 1.336 ms

-- Create a GIN index with a specific name
CREATE INDEX trips_data_gin_idx ON trips USING GIN(data);
CREATE INDEX
Time: 14.772 ms

-- run the query again, to see if the new GIN index is used
EXPLAIN SELECT * FROM trips WHERE data ? 'ride_details';
--                         QUERY PLAN                         
-- -----------------------------------------------------------
--  Seq Scan on trips  (cost=0.00..45.61 rows=1009 width=145)
--    Filter: (data ? 'ride_details'::text)
-- (2 rows)

-- Time: 2.479 ms
-- Seems it's still using Seq Scan, possibily because it's a small table?


-- make sure the index is on the table
\d trips;
                                           Table "rideshare.trips"
     Column      |              Type              | Collation | Nullable |              Default              
-----------------+--------------------------------+-----------+----------+-----------------------------------
 id              | bigint                         |           | not null | nextval('trips_id_seq'::regclass)
 trip_request_id | bigint                         |           | not null | 
 driver_id       | integer                        |           | not null | 
 completed_at    | timestamp without time zone    |           |          | 
 rating          | integer                        |           |          | 
 created_at      | timestamp(6) without time zone |           | not null | 
 updated_at      | timestamp(6) without time zone |           | not null | 
 data            | jsonb                          |           |          | 
Indexes:
    "trips_pkey" PRIMARY KEY, btree (id)
    "index_trips_on_driver_id" btree (driver_id)
    "index_trips_on_rating" btree (rating)
    "index_trips_on_trip_request_id" btree (trip_request_id)
    "trips_data_gin_idx" gin (data)
Check constraints:
    "chk_rails_4743ddc2d2" CHECK (completed_at > created_at) NOT VALID
    "rating_check" CHECK (rating >= 1 AND rating <= 5)
Foreign-key constraints:
    "fk_rails_6d92acb430" FOREIGN KEY (trip_request_id) REFERENCES trip_requests(id)
    "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)
Referenced by:
    TABLE "trip_positions" CONSTRAINT "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)

-- yup, the gin (data) index is defintiely there...

-- see if the index will be used with a more complex query?
EXPLAIN SELECT AVG((data->'ride_details'->'bags_in_trunk')::INTEGER) FROM trips WHERE data ? 'ride_details';
                            QUERY PLAN                           
  ----------------------------------------------------------------
  Aggregate  (cost=55.70..55.71 rows=1 width=32)
    ->  Seq Scan on trips  (cost=0.00..45.61 rows=1009 width=97)
          Filter: (data ? 'ride_details'::text)
(3 rows)

Time: 2.189 ms

-- nope, still not used
-- TODO: investigate why my GIN index isn't used when I have internet
-- carry on from the top of page 187

-- new day from page 187, but actually backtracking to see why the GIN index isn't used
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- turn off sequential scans
SET enable_seqscan = off;
-- SET
-- Time: 1.435 ms

-- try running a query and see if the index is used
EXPLAIN SELECT * FROM trips WHERE data ? 'ride_details';
                                      QUERY PLAN                                      
  -------------------------------------------------------------------------------------
  Bitmap Heap Scan on trips  (cost=13.82..59.43 rows=1009 width=145)
    Recheck Cond: (data ? 'ride_details'::text)
    ->  Bitmap Index Scan on trips_data_gin_idx  (cost=0.00..13.57 rows=1009 width=0)
          Index Cond: (data ? 'ride_details'::text)
  (4 rows)

Time: 5.701 ms
-- ok cool. So the table was small, so PostgreSQL decided that it didn't need to use the index. Checks out
-- I also added data to all the records, so it would need to check every single row anyways...

-- update the data column to NULL for all records that are not between 1 and 10
UPDATE trips
SET data = NULL
WHERE id NOT BETWEEN 1 AND 10;

-- turn on sequential scans
SET enable_seqscan = on;

-- try running the query again and see if the index is used
                                    QUERY PLAN                                    
  ---------------------------------------------------------------------------------
  Bitmap Heap Scan on trips  (cost=8.56..28.85 rows=8 width=145)
    Recheck Cond: (data ? 'ride_details'::text)
    ->  Bitmap Index Scan on trips_data_gin_idx  (cost=0.00..8.56 rows=8 width=0)
          Index Cond: (data ? 'ride_details'::text)
  (4 rows)

Time: 2.777 ms
-- And it did! Mystery solved.

-- carry on from the top of page 187

-- containment query example
-- create a GIN index using the JSONB_PATH_OPS operator
CREATE INDEX trips_data_path_ops
ON trips USING GIN(data JSONB_PATH_OPS);
-- CREATE INDEX
-- Time: 22.547 ms

-- checkout my new index
\d trips;
                                            Table "rideshare.trips"
      Column      |              Type              | Collation | Nullable |              Default              
  -----------------+--------------------------------+-----------+----------+-----------------------------------
  id              | bigint                         |           | not null | nextval('trips_id_seq'::regclass)
  trip_request_id | bigint                         |           | not null | 
  driver_id       | integer                        |           | not null | 
  completed_at    | timestamp without time zone    |           |          | 
  rating          | integer                        |           |          | 
  created_at      | timestamp(6) without time zone |           | not null | 
  updated_at      | timestamp(6) without time zone |           | not null | 
  data            | jsonb                          |           |          | 
Indexes:
    "trips_pkey" PRIMARY KEY, btree (id)
    "index_trips_on_driver_id" btree (driver_id)
    "index_trips_on_rating" btree (rating)
    "index_trips_on_trip_request_id" btree (trip_request_id)
    "trips_data_gin_idx" gin (data)
    "trips_data_path_ops" gin (data jsonb_path_ops) -- this is the new index
Check constraints:
    "chk_rails_4743ddc2d2" CHECK (completed_at > created_at) NOT VALID
    "rating_check" CHECK (rating >= 1 AND rating <= 5)
Foreign-key constraints:
    "fk_rails_6d92acb430" FOREIGN KEY (trip_request_id) REFERENCES trip_requests(id)
    "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)
Referenced by:
    TABLE "trip_positions" CONSTRAINT "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)

-- example of a containment queries: 
-- Which drivers offered water to riders?
SELECT * FROM  trips
WHERE data @> '{"ride_details": {"water_offered": true}}';

 id | trip_request_id | driver_id |        completed_at        | rating |         created_at         |         updated_at         |                                       data 
----+-----------------+-----------+----------------------------+--------+----------------------------+----------------------------+----------------------------------------------------------------------------------
  2 |               2 |     20001 | 2026-03-31 07:50:44.510439 |        | 2026-03-31 07:49:44.510736 | 2026-03-31 07:49:44.510736 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  3 |               3 |     20027 | 2026-03-31 07:50:44.518593 |        | 2026-03-31 07:49:44.519354 | 2026-03-31 07:49:44.519354 | {"ride_details": {"music_on": false, "bags_in_trunk": 3, "water_offered": true}}
  4 |               4 |     20029 | 2026-03-31 07:50:44.52769  |        | 2026-03-31 07:49:44.528107 | 2026-03-31 07:49:44.528107 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  5 |               5 |     20017 | 2026-03-31 07:50:44.53457  |      3 | 2026-03-31 07:49:44.53502  | 2026-03-31 07:49:44.53502  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  6 |               6 |     20025 | 2026-03-31 07:50:44.541379 |        | 2026-03-31 07:49:44.54177  | 2026-03-31 07:49:44.54177  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  7 |               7 |     20066 | 2026-03-31 07:50:44.547186 |        | 2026-03-31 07:49:44.547447 | 2026-03-31 07:49:44.547447 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  8 |               8 |     20075 | 2026-03-31 07:50:44.553277 |        | 2026-03-31 07:49:44.553646 | 2026-03-31 07:49:44.553646 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  9 |               9 |     20050 | 2026-03-31 07:50:44.56689  |      3 | 2026-03-31 07:49:44.567281 | 2026-03-31 07:49:44.567281 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
 10 |              10 |     20011 | 2026-03-31 07:50:44.575295 |        | 2026-03-31 07:49:44.575635 | 2026-03-31 07:49:44.575635 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
(9 rows)

-- Which trips had two bags in the trunk?
SELECT * FROM  trips
WHERE data @> '{"ride_details": {"bags_in_trunk": 2}}';

 id | trip_request_id | driver_id |        completed_at        | rating |         created_at         |         updated_at         |                                      data                                       
----+-----------------+-----------+----------------------------+--------+----------------------------+----------------------------+---------------------------------------------------------------------------------
  2 |               2 |     20001 | 2026-03-31 07:50:44.510439 |        | 2026-03-31 07:49:44.510736 | 2026-03-31 07:49:44.510736 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  4 |               4 |     20029 | 2026-03-31 07:50:44.52769  |        | 2026-03-31 07:49:44.528107 | 2026-03-31 07:49:44.528107 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  5 |               5 |     20017 | 2026-03-31 07:50:44.53457  |      3 | 2026-03-31 07:49:44.53502  | 2026-03-31 07:49:44.53502  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  6 |               6 |     20025 | 2026-03-31 07:50:44.541379 |        | 2026-03-31 07:49:44.54177  | 2026-03-31 07:49:44.54177  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
 10 |              10 |     20011 | 2026-03-31 07:50:44.575295 |        | 2026-03-31 07:49:44.575635 | 2026-03-31 07:49:44.575635 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
(5 rows)

-- see if the index is used
EXPLAIN SELECT * FROM  trips
WHERE data @> '{"ride_details": {"bags_in_trunk": 2}}';
--                                     QUERY PLAN                                     
-- -----------------------------------------------------------------------------------
--  Bitmap Heap Scan on trips  (cost=12.81..33.10 rows=8 width=145)
--    Recheck Cond: (data @> '{"ride_details": {"bags_in_trunk": 2}}'::jsonb)
--    ->  Bitmap Index Scan on trips_data_path_ops  (cost=0.00..12.81 rows=8 width=0)
--          Index Cond: (data @> '{"ride_details": {"bags_in_trunk": 2}}'::jsonb)
-- (4 rows)

-- Time: 2.415 ms

-- Which trips had two OR MORE bags in the trunk?
SELECT * FROM trips
WHERE (data->'ride_details'->>'bags_in_trunk')::integer >= 2;
 id | trip_request_id | driver_id |        completed_at        | rating |         created_at         |         updated_at         |                                       data                                       
----+-----------------+-----------+----------------------------+--------+----------------------------+----------------------------+----------------------------------------------------------------------------------
  3 |               3 |     20027 | 2026-03-31 07:50:44.518593 |        | 2026-03-31 07:49:44.519354 | 2026-03-31 07:49:44.519354 | {"ride_details": {"music_on": false, "bags_in_trunk": 3, "water_offered": true}}
  7 |               7 |     20066 | 2026-03-31 07:50:44.547186 |        | 2026-03-31 07:49:44.547447 | 2026-03-31 07:49:44.547447 | {"ride_details": {"music_on": false, "bags_in_trunk": 4, "water_offered": true}}
  2 |               2 |     20001 | 2026-03-31 07:50:44.510439 |        | 2026-03-31 07:49:44.510736 | 2026-03-31 07:49:44.510736 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  4 |               4 |     20029 | 2026-03-31 07:50:44.52769  |        | 2026-03-31 07:49:44.528107 | 2026-03-31 07:49:44.528107 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  5 |               5 |     20017 | 2026-03-31 07:50:44.53457  |      3 | 2026-03-31 07:49:44.53502  | 2026-03-31 07:49:44.53502  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  6 |               6 |     20025 | 2026-03-31 07:50:44.541379 |        | 2026-03-31 07:49:44.54177  | 2026-03-31 07:49:44.54177  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
 10 |              10 |     20011 | 2026-03-31 07:50:44.575295 |        | 2026-03-31 07:49:44.575635 | 2026-03-31 07:49:44.575635 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
(7 rows)

EXPLAIN SELECT * FROM trips
WHERE (data->'ride_details'->>'bags_in_trunk')::integer >= 2;
--                                        QUERY PLAN                                       
-- ----------------------------------------------------------------------------------------
--  Seq Scan on trips  (cost=0.00..55.70 rows=336 width=145)
--    Filter: ((((data -> 'ride_details'::text) ->> 'bags_in_trunk'::text))::integer >= 2)
-- (2 rows)

-- Time: 2.506 ms
-- Interesting that it's still using a Seq Scan, even though we have the index.

EXPLAIN SELECT * FROM trips
WHERE jsonb_path_exists(
  data,
  '$.ride_details.bags_in_trunk ? (@ >= 2)'
);
--                                                   QUERY PLAN                                                  
-- --------------------------------------------------------------------------------------------------------------
--  Seq Scan on trips  (cost=0.00..45.61 rows=336 width=145)
--    Filter: jsonb_path_exists(data, '$."ride_details"."bags_in_trunk"?(@ >= 2)'::jsonpath, '{}'::jsonb, false)
-- (2 rows)

-- Time: 4.077 ms
-- Also using a Seq Scan, and takes a bit longer than the previous query.

-- Indexes only help specific operators
-- Think of an index like a lookup optimized for one kind of question.

-- Your indexes:

-- trips_data_gin_idx — default GIN (jsonb_ops)
-- trips_data_path_ops — GIN with jsonb_path_ops
-- Those are built for containment / key-existence style checks, for example:

-- WHERE data @> '{"ride_details": {"bags_in_trunk": 2}}'
-- WHERE data ? 'ride_details'


-- create a B-Tree expression index
CREATE INDEX trips_btree_expr ON trips USING BTREE (data)
WHERE (data->'ride_details'->'bags_in_trunk')::INT4 >= 2;

-- drop the older GIN index to make sure the new one is used
DROP INDEX trips_data_gin_idx;

-- check that the new index is there
                                           Table "rideshare.trips"
     Column      |              Type              | Collation | Nullable |              Default              
-----------------+--------------------------------+-----------+----------+-----------------------------------
 id              | bigint                         |           | not null | nextval('trips_id_seq'::regclass)
 trip_request_id | bigint                         |           | not null | 
 driver_id       | integer                        |           | not null | 
 completed_at    | timestamp without time zone    |           |          | 
 rating          | integer                        |           |          | 
 created_at      | timestamp(6) without time zone |           | not null | 
 updated_at      | timestamp(6) without time zone |           | not null | 
 data            | jsonb                          |           |          | 
Indexes:
    "trips_pkey" PRIMARY KEY, btree (id)
    "index_trips_on_driver_id" btree (driver_id)
    "index_trips_on_rating" btree (rating)
    "index_trips_on_trip_request_id" btree (trip_request_id)
    "trips_btree_expr" btree (data) WHERE ((data -> 'ride_details'::text) -> 'bags_in_trunk'::text)::integer >= 2 -- here she is, and she's long!
    "trips_data_path_ops" gin (data jsonb_path_ops)
Check constraints:
    "chk_rails_4743ddc2d2" CHECK (completed_at > created_at) NOT VALID
    "rating_check" CHECK (rating >= 1 AND rating <= 5)
Foreign-key constraints:
    "fk_rails_6d92acb430" FOREIGN KEY (trip_request_id) REFERENCES trip_requests(id)
    "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)
Referenced by:
    TABLE "trip_positions" CONSTRAINT "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)


-- see if the new btree expression index is used, and it is!
EXPLAIN SELECT * FROM trips
WHERE (data->'ride_details'->'bags_in_trunk')::INT4 >= 2;
                                    QUERY PLAN                                     
-----------------------------------------------------------------------------------
 Index Scan using trips_btree_expr on trips  (cost=0.13..28.37 rows=336 width=145)
(1 row)

Time: 14.691 ms

-- query to get all the trips with two or more bags in the trunk
SELECT * FROM trips
WHERE (data->'ride_details'->'bags_in_trunk')::INT4 >= 2;
 id | trip_request_id | driver_id |        completed_at        | rating |         created_at         |         updated_at         |                                       data                                       
----+-----------------+-----------+----------------------------+--------+----------------------------+----------------------------+----------------------------------------------------------------------------------
  3 |               3 |     20027 | 2026-03-31 07:50:44.518593 |        | 2026-03-31 07:49:44.519354 | 2026-03-31 07:49:44.519354 | {"ride_details": {"music_on": false, "bags_in_trunk": 3, "water_offered": true}}
  7 |               7 |     20066 | 2026-03-31 07:50:44.547186 |        | 2026-03-31 07:49:44.547447 | 2026-03-31 07:49:44.547447 | {"ride_details": {"music_on": false, "bags_in_trunk": 4, "water_offered": true}}
  2 |               2 |     20001 | 2026-03-31 07:50:44.510439 |        | 2026-03-31 07:49:44.510736 | 2026-03-31 07:49:44.510736 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  4 |               4 |     20029 | 2026-03-31 07:50:44.52769  |        | 2026-03-31 07:49:44.528107 | 2026-03-31 07:49:44.528107 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  5 |               5 |     20017 | 2026-03-31 07:50:44.53457  |      3 | 2026-03-31 07:49:44.53502  | 2026-03-31 07:49:44.53502  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
  6 |               6 |     20025 | 2026-03-31 07:50:44.541379 |        | 2026-03-31 07:49:44.54177  | 2026-03-31 07:49:44.54177  | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
 10 |              10 |     20011 | 2026-03-31 07:50:44.575295 |        | 2026-03-31 07:49:44.575635 | 2026-03-31 07:49:44.575635 | {"ride_details": {"music_on": true, "bags_in_trunk": 2, "water_offered": true}}
(7 rows)

-- this is a VERY specific query, which was a very specific index. And I can see that, if this was a really large table, this would be a lot faster than the previous queries.

-- there is a Rails equivalent, using store_accessor from Active Record Store, but it only has one level of depth for querying
-- in this example I would have access to ride_details, but not the nested details within it
-- for multiple levels of depth, in rails, I would need to use jsonb directly with Active Record.

-- new day from page 188
-- Maintaining Unstructured JSON Data

-- INSTRUCTIONS/CODE FOR THIS SECTION: https://github.com/andyatkinson/development_guides/blob/main/postgres_json_schema.md

-- install postgres-json-schema extension
git clone git@github.com:gavinwahl/postgres-json-schema.git
cd postgres-json-schema
make install
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

CREATE EXTENSION "postgres-json-schema"
WITH SCHEMA rideshare;
-- WITH SCHEMA rideshare;
-- CREATE EXTENSION

ALTER TABLE trips ADD CONSTRAINT data_is_valid CHECK (validate_json_schema(
'{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "ride_details": {
      "type": "object",
      "properties": {
        "music_on": {
          "type": "boolean"
        },
        "bags_in_trunk": {
          "type": "integer",
          "minimum": 0
        },
        "water_offered": {
          "type": "boolean"
        }
      },
      "required": ["music_on", "bags_in_trunk", "water_offered"]
    }
  },
  "required": ["ride_details"]
}', data));
-- ALTER TABLE

-- check that the new constraint is working
SELECT $$'{"ride_details":
{"bags_in_trunk": 1, "music_on": true,"water_offered": false}
}'::jsonb$$
AS json_string4 \gset

UPDATE trips AS t
SET data = c.json_string
from (VALUES
  (:json_string4, 1)
) AS c(json_string, trip_id)
WHERE c.trip_id = t.id;
-- UPDATE 1

-- test that this doesn't work
SELECT $$'{"ride_details_BREAK":
{"bags_in_trunk": 1, "music_on": true,"water_offered": false}
}'::jsonb$$
AS json_string5 \gset
-- ERROR:  new row for relation "trips" violates check constraint "data_is_valid"
-- DETAIL:  Failing row contains (1, 1, 20005, 2026-03-31 07:50:44.483752, 5, 2026-03-31 07:49:44.497974, 2026-03-31 07:49:44.497974, {"ride_details_BREAK": {"music_on": true, "bags_in_trunk": 1, "w...).
-- fails, which is expected

\d trips;
                                           Table "rideshare.trips"
     Column      |              Type              | Collation | Nullable |              Default              
-----------------+--------------------------------+-----------+----------+-----------------------------------
 id              | bigint                         |           | not null | nextval('trips_id_seq'::regclass)
 trip_request_id | bigint                         |           | not null | 
 driver_id       | integer                        |           | not null | 
 completed_at    | timestamp without time zone    |           |          | 
 rating          | integer                        |           |          | 
 created_at      | timestamp(6) without time zone |           | not null | 
 updated_at      | timestamp(6) without time zone |           | not null | 
 data            | jsonb                          |           |          | 
Indexes:
    "trips_pkey" PRIMARY KEY, btree (id)
    "index_trips_on_driver_id" btree (driver_id)
    "index_trips_on_rating" btree (rating)
    "index_trips_on_trip_request_id" btree (trip_request_id)
    "trips_btree_expr" btree (data) WHERE ((data -> 'ride_details'::text) -> 'bags_in_trunk'::text)::integer >= 2
    "trips_data_path_ops" gin (data jsonb_path_ops)
Check constraints:
    "chk_rails_4743ddc2d2" CHECK (completed_at > created_at) NOT VALID
    -- new check constraint
    "data_is_valid" CHECK (validate_json_schema('{"type": "object", "$schema": "http://json-schema.org/draft-07/schema#", "required":["ride_details"], "properties": {"ride_details": {"type": "object", "required": ["music_on", "bags_in_trunk", "water_offered"], "properties": {"music_on": {"type": "boolean"}, "bags_in_trunk": {"type": "integer", "minimum": 0}, "water_offered": {"type": "boolean"}}}}}'::jsonb, data))
    "rating_check" CHECK (rating >= 1 AND rating <= 5)
Foreign-key constraints:
    "fk_rails_6d92acb430" FOREIGN KEY (trip_request_id) REFERENCES trip_requests(id)
    "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)
Referenced by:
    TABLE "trip_positions" CONSTRAINT "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)


-- new day from page 190
-- Using BRIN Indexes (Block Range INdexes)
-- A block range index entry points to a page and stores two values:
--  - The minimum value of the data in the page
--  - The maximum value of the data in the page
-- BRIN indexes can be a good fit for time ranges, where the phhysical layout of the data in block ranges matches how the data is queried.


psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

\d trip_positions;
                                        Table "rideshare.trip_positions"
    Column   |              Type              | Collation | Nullable |                  Default                   
  ------------+--------------------------------+-----------+----------+--------------------------------------------
  id         | bigint                         |           | not null | nextval('trip_positions_id_seq'::regclass)
  position   | point                          |           | not null | 
  trip_id    | bigint                         |           | not null | 
  created_at | timestamp(6) without time zone |           | not null | 
  updated_at | timestamp(6) without time zone |           | not null | 
Indexes:
    "trip_positions_pkey" PRIMARY KEY, btree (id)
Foreign-key constraints:
    "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)

SELECT * FROM trip_positions;
--  id | position | trip_id | created_at | updated_at 
-- ----+----------+---------+------------+------------
-- (0 rows)
-- she empty!

SELECT SETSEED(0.5);

BEGIN;

SET LOCAL statement_timeout = '60s';

INSERT INTO trip_positions (
  position, trip_id, created_at, updated_at)
  SELECT POINT('(37.769233' ||
    FLOOR(RANDOM() * 10 +1)::TEXT ||
    ',-122.3890705)'),
  (SELECT MIN(id) FROM trips),
  seq,
  seq
  FROM GENERATE_SERIES(
    '2026-08-01 00:00:00'::TIMESTAMP,
    '2026-10-01 00:00:00'::TIMESTAMP,
    '1 second'::INTERVAL)
  AS t(seq);

COMMIT;

-- BEGIN
-- Time: 0.263 ms
-- SET
-- Time: 0.133 ms
-- INSERT 0 5270401
-- Time: 31280.874 ms (00:31.281)
-- COMMIT
-- Time: 0.213 ms

-- get the count of the trip_positions table
SELECT COUNT(*) FROM trip_positions;
--   count  
-- ---------
--  5,270,401
-- (1 row)

-- Time: 133.553 ms

-- query to count records by day
SELECT
  DATE_PART('day', created_at) AS day,
  COUNT(*)
FROM trip_positions
WHERE created_at >= '2026-08-01' AND created_at < '2026-08-06'
GROUP BY 1
ORDER BY 1;
--  day | count 
-- -----+-------
--    1 | 86400
--    2 | 86400
--    3 | 86400
--    4 | 86400
--    5 | 86400
-- (5 rows)

-- Time: 205.002 ms

EXPLAIN ANALYZE SELECT
  DATE_PART('day', created_at) AS day,
  COUNT(*)
FROM trip_positions
WHERE created_at >= '2026-08-01' AND created_at < '2026-08-06'
GROUP BY 1
ORDER BY 1;

                                                                                  QUERY PLAN                                                                                  
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Finalize GroupAggregate  (cost=101068.18..151439.84 rows=415651 width=16) (actual time=187.343..191.237 rows=5 loops=1)
    Group Key: (date_part('day'::text, created_at))
    ->  Gather Merge  (cost=101068.18..144512.32 rows=346376 width=16) (actual time=185.906..191.232 rows=15 loops=1)
          Workers Planned: 2
          Workers Launched: 2
          ->  Partial GroupAggregate  (cost=100068.15..103531.91 rows=173188 width=16) (actual time=170.995..176.457 rows=5 loops=3)
                Group Key: (date_part('day'::text, created_at))
                ->  Sort  (cost=100068.15..100501.12 rows=173188 width=8) (actual time=169.601..172.623 rows=144000 loops=3)
                      Sort Key: (date_part('day'::text, created_at))
                      Sort Method: quicksort  Memory: 4096kB
                      Worker 0:  Sort Method: quicksort  Memory: 4096kB
                      Worker 1:  Sort Method: quicksort  Memory: 3073kB
                      ->  Parallel Seq Scan on trip_positions  (cost=0.00..82629.58 rows=173188 width=8) (actual time=0.100..163.689 rows=144000 loops=3)
                            Filter: ((created_at >= '2026-08-01 00:00:00'::timestamp without time zone) AND (created_at < '2026-08-06 00:00:00'::timestamp without time zone))
                            Rows Removed by Filter: 1612800
  Planning Time: 0.131 ms
  Execution Time: 191.518 ms
(17 rows)
Time: 192.610 ms

-- Parallel Seq Scan on trip_positions is used here

-- create a BRIN index on the created_at column
CREATE INDEX trip_positions_created_at_brin
ON trip_positions USING BRIN (created_at);
-- CREATE INDEX
-- Time: 443.404 ms

-- create a B-Tree index on the created_at column
CREATE INDEX trip_positions_created_at_btree
ON trip_positions USING BTREE (created_at);
-- CREATE INDEX
-- Time: 2939.683 ms (00:02.940)
-- this took a lot longer to build!

-- check that the new indexes are there
\d trip_positions;

                                        Table "rideshare.trip_positions"
    Column   |              Type              | Collation | Nullable |                  Default                   
  ------------+--------------------------------+-----------+----------+--------------------------------------------
  id         | bigint                         |           | not null | nextval('trip_positions_id_seq'::regclass)
  position   | point                          |           | not null | 
  trip_id    | bigint                         |           | not null | 
  created_at | timestamp(6) without time zone |           | not null | 
  updated_at | timestamp(6) without time zone |           | not null | 
Indexes:
    "trip_positions_pkey" PRIMARY KEY, btree (id)
    "trip_positions_created_at_brin" brin (created_at)
    "trip_positions_created_at_btree" btree (created_at)
Foreign-key constraints:
    "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES trips(id)

-- Run the query again with the new indexes
EXPLAIN ANALYZE SELECT
  DATE_PART('day', created_at) AS day,
  COUNT(*)
FROM trip_positions
WHERE created_at >= '2026-08-01' AND created_at < '2026-08-06'
GROUP BY 1
ORDER BY 1;

                                                                                    QUERY PLAN                                                                                   
  --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  GroupAggregate  (cost=58467.70..66791.36 rows=416183 width=16) (actual time=117.984..139.607 rows=5 loops=1)
    Group Key: (date_part('day'::text, created_at))
    ->  Sort  (cost=58467.70..59508.15 rows=416183 width=8) (actual time=112.366..126.766 rows=432000 loops=1)
          Sort Key: (date_part('day'::text, created_at))
          Sort Method: external merge  Disk: 5088kB
          ->  Index Only Scan using trip_positions_created_at_btree on trip_positions  (cost=0.43..13932.55 rows=416183 width=8) (actual time=0.040..78.379 rows=432000 loops=1)
                Index Cond: ((created_at >= '2026-08-01 00:00:00'::timestamp without time zone) AND (created_at < '2026-08-06 00:00:00'::timestamp without time zone))
                Heap Fetches: 0
  Planning Time: 4.329 ms
  Execution Time: 141.044 ms
(10 rows)

Time: 152.844 ms

-- Uses an Index Only Scan on the B-Tree index

-- drop the B-Tree index
DROP INDEX trip_positions_created_at_btree;
-- DROP INDEX

-- Run the query again with the BRIN index
EXPLAIN ANALYZE SELECT
  DATE_PART('day', created_at) AS day,
  COUNT(*)
FROM trip_positions
WHERE created_at >= '2026-08-01' AND created_at < '2026-08-06'
GROUP BY 1
ORDER BY 1;
                                                                                  QUERY PLAN                                                                                 
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  GroupAggregate  (cost=101257.76..109570.88 rows=415656 width=16) (actual time=144.716..166.418 rows=5 loops=1)
    Group Key: (date_part('day'::text, created_at))
    ->  Sort  (cost=101257.76..102296.90 rows=415656 width=8) (actual time=139.106..153.637 rows=432000 loops=1)
          Sort Key: (date_part('day'::text, created_at))
          Sort Method: external merge  Disk: 5088kB
          ->  Bitmap Heap Scan on trip_positions  (cost=120.91..56782.60 rows=415656 width=8) (actual time=1.683..111.281 rows=432000 loops=1)
                Recheck Cond: ((created_at >= '2026-08-01 00:00:00'::timestamp without time zone) AND (created_at < '2026-08-06 00:00:00'::timestamp without time zone))
                Rows Removed by Index Recheck: 6272
                Heap Blocks: lossy=4096
                ->  Bitmap Index Scan on trip_positions_created_at_brin  (cost=0.00..16.99 rows=424370 width=0) (actual time=1.424..1.424 rows=40960 loops=1)
                      Index Cond: ((created_at >= '2026-08-01 00:00:00'::timestamp without time zone) AND (created_at < '2026-08-06 00:00:00'::timestamp without time zone))
  Planning Time: 2.379 ms
  Execution Time: 168.105 ms
(13 rows)

Time: 172.682 ms
-- Now were using the BRIN index, speed was ever so slightly slower compare to the B-Tree index, but still very fast.

-- add the btree index back
CREATE INDEX trip_positions_created_at_btree
ON trip_positions USING BTREE (created_at);


-- check out how much space the indexes are taking up
SELECT pg_size_pretty(pg_total_relation_size('trip_positions_created_at_brin'));
-- pg_size_pretty 
-- ----------------
--  56 kB
(1 row)

SELECT pg_size_pretty(pg_total_relation_size('trip_positions_created_at_btree'));
-- pg_size_pretty 
-- ----------------
--  113 MB
-- (1 row)

-- That's a big difference! The BRIN index is about 99.97% smaller than the B-Tree index.

-- new day from page 194
-- Hash Indexes over B-tree
-- Hash indexes support only equality comparisons (which are also supported by B-tree indexes)

-- the basics of creating a hash index type for the name column in the vehiccles table looks like this:
CREATE INDEX idx_name_hash ON vehicles USING HASH (name);


-- As a rule of thumb, use B-tree indexes, not hash indexes.

-- new day from page 195
Using Indexes for Sorting
-- B-tree indexes are sorted in ascending order by default 1,2,3,4

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- order trips by completion time
EXPLAIN SELECT * FROM trips
WHERE completed_at IS null
ORDER BY completed_at;

                          QUERY PLAN                          
--------------------------------------------------------------
  Sort  (cost=43.23..43.26 rows=9 width=145)
    Sort Key: completed_at
    ->  Seq Scan on trips  (cost=0.00..43.09 rows=9 width=145)
          Filter: (completed_at IS NULL)
(4 rows)

Time: 44.600 ms

-- get a count of trips
SELECT COUNT(*) FROM trips;
  count
-------
  1009
(1 row)

Time: 11.776 ms

-- null values are ordered in the front by default
-- to put them in the back, use NULLS LAST in SQL, or in Arel below
Trip.where(completed_at: nil)
    .order(Trip.arel_table[:completed_at].desc.nulls_last)
    .to_sql
-- => "SELECT \"trips\".* FROM \"trips\" WHERE \"trips\".\"completed_at\" IS NULL ORDER BY \"trips\".\"completed_at\" DESC NULLS LAST"

-- I'll not sure what I'm supposed to do with that query, possibly a migration, but will come back to it.

-- add an index to completed_at
CREATE INDEX trips_completed_at_index
ON trips(completed_at DESC NULLS LAST);
-- CREATE INDEX
-- Time: 31.015 ms

-- re-run query to see the index being used
EXPLAIN SELECT * FROM trips
WHERE completed_at IS null
ORDER BY completed_at;

                                          QUERY PLAN                                           
-----------------------------------------------------------------------------------------------
  Sort  (cost=17.09..17.12 rows=9 width=145)
    Sort Key: completed_at
    ->  Index Scan using trips_completed_at_index on trips  (cost=0.28..16.95 rows=9 width=145)
          Index Cond: (completed_at IS NULL)
(4 rows)

Time: 5.382 ms

-- We're now using index scan, rather than seq scan
-- We're also sorting with "Sort Key: completed_at". Which we were doing before as well
-- WAY faster


-- Using Covering Indexes, p197
-- Covering indexes refer to the definition of the index, 
-- where the index entries provide all needed data for a query

-- In INCLUDE keyword specifies columns that only supply data, called 'payload' columns
-- They can't be used for filtering, but supply data for columns listed in the SELECT clause

-- create a mult-column index
CREATE INDEX users_fname_lname_multi_idx
ON users (first_name, last_name);
-- CREATE INDEX
-- Time: 14532.353 ms (00:14.532) (not fast, lots to do)

SELECT COUNT(*) FROM users;
--   count   
-- ----------
--  10020200
-- (1 row)

-- confirm the multi-column index will be used
EXPLAIN (ANALYZE) SELECT first_name, last_name
FROM users WHERE first_name = 'Elroy';
                                                              QUERY PLAN                                                                
-----------------------------------------------------------------------------------------------------------------------------------------
Index Only Scan using users_fname_lname_multi_idx on users  (cost=0.56..8.58 rows=1 width=24) (actual time=1.167..1.273 rows=9 loops=1)
  Index Cond: (first_name = 'Elroy'::text)
  Heap Fetches: 0
Planning Time: 0.635 ms
Execution Time: 1.417 ms
(5 rows)

Time: 6.881 ms
-- Index only scan, using our new index

-- drop the index, so it doesn't interfere with the new one.
-- Actually, I'm going to wait to do this....
DROP INDEX users_fname_lname_multi_idx;

-- Create index on first_name, but INCLUDE last_name
CREATE INDEX users_fname_include_lname_incl
ON users (first_name)
INCLUDE (last_name);
-- CREATE INDEX
-- Time: 13330.382 ms (00:13.330) (slightly faster than the previous one)

-- see the indexes on the users table
                                              Table "rideshare.users"
         Column         |              Type              | Collation | Nullable |              Default              
------------------------+--------------------------------+-----------+----------+-----------------------------------
 id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
 first_name             | character varying              |           | not null | 
 last_name              | character varying              |           | not null | 
 email                  | character varying              |           | not null | 
 type                   | character varying              |           | not null | 
 created_at             | timestamp(6) without time zone |           | not null | 
 updated_at             | timestamp(6) without time zone |           | not null | 
 password_digest        | character varying              |           |          | 
 trips_count            | integer                        |           |          | 
 drivers_license_number | character varying(100)         |           |          | 
 deleted_at             | timestamp with time zone       |           |          | 
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_deleted_email_multi" btree (deleted_at, email)
    "index_users_deleted_email_partial" btree (email) WHERE deleted_at IS NOT NULL
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_last_name_and_email" btree (last_name, email)
    "index_users_on_type" btree (type)
    "users_fname_include_lname_incl" btree (first_name) INCLUDE (last_name)  -- INCLUDE
    "users_fname_lname_multi_idx" btree (first_name, last_name)  -- multi-column
Referenced by:
    TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
    TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)

-- re-run the query and see which index it decides to use
EXPLAIN (ANALYZE) SELECT first_name, last_name
FROM users WHERE first_name = 'Elroy';

                                                                QUERY PLAN                                                                 
--------------------------------------------------------------------------------------------------------------------------------------------
Index Only Scan using users_fname_include_lname_incl on users  (cost=0.56..8.58 rows=1 width=24) (actual time=2.899..2.904 rows=9 loops=1)
  Index Cond: (first_name = 'Elroy'::text)
  Heap Fetches: 0
Planning Time: 6.022 ms
Execution Time: 3.490 ms
(5 rows)

Time: 10.505 ms
-- It's using INCLUDE index, but is also quite a bit slower
-- Previous was Time: 6.881 ms

-- Drop index, replacing it with UNIQUE
DROP INDEX users_fname_include_lname_incl;

-- Remove constraints for example, allows deletes 
ALTER TABLE trips DROP CONSTRAINT fk_rails_e7560abc33;
ALTER TABLE trip_requests DROP CONSTRAINT fk_rails_c17a139554;

-- CTE to find duplicate first names, then
-- delete users with that first_name 
WITH dupe_first_names AS ( SELECT first_name, COUNT(*) FROM users GROUP BY first_name HAVING COUNT(*) > 1 ) DELETE FROM users WHERE first_name IN ( SELECT DISTINCT first_name FROM dupe_first_names );

-- Create index again, adding UNIQUE
CREATE UNIQUE INDEX users_fname_include_lname_incl ON users (first_name) INCLUDE (last_name);

-- re-run the query with the new UNIQUE index
EXPLAIN (ANALYZE) SELECT first_name, last_name
FROM users WHERE first_name = 'Elroy';
                                                                  QUERY PLAN                                                                 
  --------------------------------------------------------------------------------------------------------------------------------------------
  Index Only Scan using users_fname_include_lname_incl on users  (cost=0.56..8.58 rows=1 width=24) (actual time=0.498..0.499 rows=0 loops=1)
    Index Cond: (first_name = 'Elroy'::text)
    Heap Fetches: 0
  Planning Time: 3.133 ms
  Execution Time: 0.842 ms
(5 rows)

Time: 5.334 ms
-- Still using the INCLUDe index, much faster now, but we did remove all the duplicates from the table

-- Try inserting a duplicate
INSERT INTO users ( first_name, last_name, email, type, created_at, updated_at ) VALUES (
  'Adela', -- the duplicate
  'Lastname', 'email@example.com', 'Driver', NOW(), NOW()
);
-- First time it worked.
-- Second time it didn't
ERROR:  duplicate key value violates unique constraint "index_users_on_email"
DETAIL:  Key (email)=(email@example.com) already exists.
Time: 1.845 ms