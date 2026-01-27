-- Chapter 3 commands

-- generate 20,000 records
bin/rails data_generators:generate_all
  https://github.com/JM-Sully/postgresql-for-rails/blob/0fc75230e519a2dd39596868e66bf2fce60b5731/lib/tasks/data_generators.rake#L5

-- populate 10,000,000 records in the users table
export DATABASE_URL='postgres://owner:@localhost:5432/rideshare_development'
sh db/scripts/bulk_load.sh
  -- started at 0900, finished at 0903

psql -U postgres -d rideshare_development

-- check the size of the users table
SELECT PG_SIZE_PRETTY(PG_TOTAL_RELATION_SIZE('rideshare.users'));
--  pg_size_pretty 
-- ----------------
--  2633 MB
-- (1 row)
SELECT COUNT(*) FROM rideshare.users;
--   count   
-- ----------
--  10020210
-- (1 row)

\d users
-- Did not find any relation named "users".

-- find my table
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename LIKE '%users%';
--  schemaname | tablename 
-- ------------+-----------
--  rideshare  | users

\d rideshare.users
--                                                    Table "rideshare.users"
--          Column         |              Type              | Collation | Nullable |                   Default                   
-- ------------------------+--------------------------------+-----------+----------+---------------------------------------------
--  id                     | bigint                         |           | not null | nextval('rideshare.users_id_seq'::regclass)
--  first_name             | character varying              |           | not null | 
--  last_name              | character varying              |           | not null | 
--  email                  | character varying              |           | not null | 
--  type                   | character varying              |           | not null | 
--  created_at             | timestamp(6) without time zone |           | not null | 
--  updated_at             | timestamp(6) without time zone |           | not null | 
--  password_digest        | character varying              |           |          | 
--  trips_count            | integer                        |           |          | 
--  drivers_license_number | character varying(100)         |           |          | 
-- Indexes:
--     "users_pkey" PRIMARY KEY, btree (id)
--     "index_users_on_email" UNIQUE, btree (email)
--     "index_users_on_last_name" btree (last_name)
-- Referenced by:
--     TABLE "rideshare.trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES rideshare.users(id)
-- FERENCES rideshare.users(id)

ALTER TABLE rideshare.users
ALTER COLUMN first_name SET STATISTICS 5_000;

ANALYZE rideshare.users;

SELECT
  attname,
  n_distinct,
  most_common_vals
FROM pg_stats
WHERE schemaname = 'rideshare'
AND tablename = 'users'
AND attname = 'first_name';
--   attname   | n_distinct |                                   most_common_vals                                   
-- ------------+------------+--------------------------------------------------------------------------------------
--  first_name | -0.9932877 | {Joan,John,Louie,Wesley,Chad,Chong,Kristopher,Marcelo,Marshall,Shaun,Stacy,Terrence}
-- (1 row)

-- reset the statistics
ALTER TABLE rideshare.users
ALTER COLUMN first_name SET STATISTICS 100;

COMMENT ON COLUMN rideshare.users.first_name IS 'sensitive_data=true';
-- COMMENT

SHOW search_path;
--    search_path   
-----------------
--  "$user", public
-- (1 row)

SET search_path TO rideshare, public;
-- SET
--     search_path    
-- -------------------
--  rideshare, public
-- (1 row)
-- shouldn't have to do rideshare.users! I must have missed this step earlier?!

\d+ users
--                                                                             Table "rideshare.users"
--         Column         |              Type              | Collation | Nullable |              Default              | Storage  | Compression | Stats target |     Description     
-- ------------------------+--------------------------------+-----------+----------+-----------------------------------+----------+-------------+--------------+---------------------
-- id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass) | plain    |             |              | 
-- first_name             | character varying              |           | not null |                                   | extended |             | 100          | sensitive_data=true
-- last_name              | character varying              |           | not null |                                   | extended |             |              | 
-- email                  | character varying              |           | not null |                                   | extended |             |              | 
-- type                   | character varying              |           | not null |                                   | extended |             |              | 
-- created_at             | timestamp(6) without time zone |           | not null |                                   | plain    |             |              | 
-- updated_at             | timestamp(6) without time zone |           | not null |                                   | plain    |             |              | 
-- password_digest        | character varying              |           |          |                                   | extended |             |              | 
-- trips_count            | integer                        |           |          |                                   | plain    |             |              | 
-- drivers_license_number | character varying(100)         |           |          |                                   | extended |             |              | 


\dx
-- confirm that plpgsql is installed, it is!
--                                             List of installed extensions
--         Name        | Version |   Schema   |                              Description
-- --------------------+---------+------------+------------------------------------------------------------------------
-- pg_stat_statements | 1.10    | rideshare  | track planning and execution statistics of all SQL statements executed
-- plpgsql            | 1.0     | pg_catalog | PL/pgSQL procedural language
-- (2 rows)

-- create (or replace) a function to scrub an email address
-- NOTE: I had to add the rideshare schema to the search path to make this work.
CREATE OR REPLACE FUNCTION rideshare.SCRUB_EMAIL(email_address varchar(255))
RETURNS varchar(255) AS $$
SELECT email_address;
$$ LANGUAGE SQL;

SELECT rideshare.SCRUB_EMAIL(email)
FROM rideshare.users
LIMIT 5;
--           scrub_email
-- ----------------------------------
-- Bradford-Hahn-driver-0@email.com
-- Edmund-Zemlak-driver-1@email.com
-- Marylin-Tromp-driver-2@email.com
-- Blake-Green-driver-3@email.com
-- Stan-Lockman-driver-4@email.com

SELECT SPLIT_PART('jess@email.com', '@', 1);
--  split_part
-- ------------
--  jess

SELECT LENGTH('jess');
--  length
-- --------
--       4

SELECT SETSEED(0.5);
--  setseed
-- ---------
--

SELECT rideshare.SCRUB_EMAIL('jess@email.com');
--    scrub_email
-- -----------------
--  2bffb@email.com

-- create a copy of the users table, no data, just the structure
CREATE TABLE rideshare.users_copy (LIKE rideshare.users INCLUDING ALL);
SELECT * FROM rideshare.users_copy;
--  id | first_name | last_name | email | type | created_at | updated_at | password_digest | trips_count | drivers_license_number
-- ----+------------+-----------+-------+------+------------+------------+-----------------+-------------+------------------------
-- (0 rows)

-- there are + 1 million records in the users table, so only doing 20,000 for now
rideshare_development=# INSERT INTO rideshare.users_copy(
  id,
  first_name,
  last_name,
  email,
  type,
  created_at,
  updated_at
)
SELECT
  id,
  first_name,
  last_name,
  rideshare.SCRUB_EMAIL(email),
  type,
  created_at,
  updated_at
FROM rideshare.users
LIMIT 20000;

SELECT COUNT(*) FROM rideshare.users_copy;
--  count
-- -------
--  20000
-- (1 row)

SELECT
  u1.email AS original_email,
  u2.email AS scrubbed_email
FROM rideshare.users u1
JOIN rideshare.users_copy u2 USING (id)
WHERE id = (SELECT MIN(id) FROM rideshare.users);
-- none are the same, makes sense
--  original_email | scrubbed_email
-- ----------------+----------------
-- (0 rows)

-- new day
psql -U postgres -d rideshare_development
DROP TABLE IF EXISTS rideshare.users_copy;
-- DROP TABLE

CREATE TABLE rideshare.users_copy (LIKE rideshare.users INCLUDING ALL EXCLUDING INDEXES);

\d rideshare.users_copy
--                                                  Table "rideshare.users_copy"
--          Column         |              Type              | Collation | Nullable |                   Default
-- ------------------------+--------------------------------+-----------+----------+---------------------------------------------
--  id                     | bigint                         |           | not null | nextval('rideshare.users_id_seq'::regclass)
--  first_name             | character varying              |           | not null |
--  last_name              | character varying              |           | not null |
--  email                  | character varying              |           | not null |
--  type                   | character varying              |           | not null |
--  created_at             | timestamp(6) without time zone |           | not null |
--  updated_at             | timestamp(6) without time zone |           | not null |
--  password_digest        | character varying              |           |          |
--  trips_count            | integer                        |           |          |
--  drivers_license_number | character varying(100)         |           |          |
\timing

sql/scrubbing_on_the_fly.sql
-- this didn't do anything and I've run out of time to investigate! (p56)

SELECT
  conrelid::regclass AS table_name,
  conname AS foreign_key,
  PG_GET_CONSTRAINTDEF(oid)
FROM pg_constraint
WHERE contype = 'f'
AND connamespace = 'rideshare'::regnamespace
ORDER BY conrelid::regclass::text, contype DESC;
--           table_name           |     foreign_key     |                         pg_get_constraintdef
-- --------------------------------+---------------------+----------------------------------------------------------------------
-- rideshare.trip_positions       | fk_rails_9688ac8706 | FOREIGN KEY (trip_id) REFERENCES rideshare.trips(id)
-- rideshare.trip_requests        | fk_rails_fa2679b626 | FOREIGN KEY (start_location_id) REFERENCES rideshare.locations(id)
-- rideshare.trip_requests        | fk_rails_c17a139554 | FOREIGN KEY (rider_id) REFERENCES rideshare.users(id)
-- rideshare.trip_requests        | fk_rails_3fdebbfaca | FOREIGN KEY (end_location_id) REFERENCES rideshare.locations(id)
-- rideshare.trips                | fk_rails_6d92acb430 | FOREIGN KEY (trip_request_id) REFERENCES rideshare.trip_requests(id)
-- rideshare.trips                | fk_rails_e7560abc33 | FOREIGN KEY (driver_id) REFERENCES rideshare.users(id)
-- rideshare.vehicle_reservations | fk_rails_7edc8e666a | FOREIGN KEY (vehicle_id) REFERENCES rideshare.vehicles(id)
-- rideshare.vehicle_reservations | fk_rails_59996232fc | FOREIGN KEY (trip_request_id) REFERENCES rideshare.trip_requests(id)

\d rideshare.trips
--                                               Table "rideshare.trips"
--     Column      |              Type              | Collation | Nullable |                   Default
-- -----------------+--------------------------------+-----------+----------+---------------------------------------------
-- id              | bigint                         |           | not null | nextval('rideshare.trips_id_seq'::regclass)
-- trip_request_id | bigint                         |           | not null |
-- driver_id       | integer                        |           | not null |
-- completed_at    | timestamp without time zone    |           |          |
-- rating          | integer                        |           |          |
-- created_at      | timestamp(6) without time zone |           | not null |
-- updated_at      | timestamp(6) without time zone |           | not null |
-- Indexes:
--   "trips_pkey" PRIMARY KEY, btree (id)
--   "index_trips_on_driver_id" btree (driver_id)
--   "index_trips_on_rating" btree (rating)
--   "index_trips_on_trip_request_id" btree (trip_request_id)
-- Check constraints:
--   "chk_rails_4743ddc2d2" CHECK (completed_at > created_at) NOT VALID
--   "rating_check" CHECK (rating >= 1 AND rating <= 5)
-- Foreign-key constraints:
--   "fk_rails_6d92acb430" FOREIGN KEY (trip_request_id) REFERENCES rideshare.trip_requests(id)
--   "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES rideshare.users(id)
-- Referenced by:
--   TABLE "rideshare.trip_positions" CONSTRAINT "fk_rails_9688ac8706" FOREIGN KEY (trip_id) REFERENCES rideshare.trips(id)

-- list out the constraint definitions as creation DDL statements
SELECT
  FORMAT(
    'ALTER TABLE %I.%I ADD CONSTRAINT %I %s;',
    connamespace::regnamespace,
    conrelid::regclass,
    conname,
    PG_GET_CONSTRAINTDEF(oid)
  )
FROM pg_constraint
WHERE conname IN ('fk_rails_e7560abc33');
--                                                                format
-- ------------------------------------------------------------------------------------------------------------------------------------
--  ALTER TABLE rideshare."rideshare.trips" ADD CONSTRAINT fk_rails_e7560abc33 FOREIGN KEY (driver_id) REFERENCES rideshare.users(id);
-- (1 row)

CREATE TABLE rideshare.trips_copy (
  LIKE rideshare.trips INCLUDING ALL EXCLUDING INDEXES
);
-- CREATE TABLE
-- Time: 9.004 ms

ALTER TABLE rideshare.trips_copy
ADD CONSTRAINT fk_rails_e7560abc33 FOREIGN KEY (driver_id)
REFERENCES rideshare.users(id);
-- ALTER TABLE
-- Time: 13.883 ms

-- List all sequences
SELECT
  s.relname AS seq,
  n.nspname AS sch,
  t.relname AS tab,
  a.attname AS col
FROM
  pg_class s
JOIN pg_depend d ON d.objid = s.oid
AND d.classid = 'pg_class'::regclass
AND d.refclassid = 'pg_class'::regclass
JOIN pg_class t ON t.oid = d.refobjid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid
AND a.attnum = d.refobjsubid
WHERE s.relkind = 'S'
AND d.deptype = 'a';
--              seq             |    sch    |         tab          | col
-- -----------------------------+-----------+----------------------+-----
--  users_id_seq                | rideshare | users                | id
--  locations_id_seq            | rideshare | locations            | id
--  trip_requests_id_seq        | rideshare | trip_requests        | id
--  trips_id_seq                | rideshare | trips                | id
--  vehicle_reservations_id_seq | rideshare | vehicle_reservations | id
--  vehicles_id_seq             | rideshare | vehicles             | id
--  trip_positions_id_seq       | rideshare | trip_positions       | id
-- (7 rows)

ALTER SEQUENCE rideshare.users_id_seq
OWNED BY rideshare.users.id;
-- ALTER SEQUENCE
-- Time: 4.953 ms

SELECT PG_GET_INDEXDEF(indexrelid) || ';' AS index
FROM pg_index
WHERE indrelid = 'rideshare.users'::regclass;
--                                        index
-- -----------------------------------------------------------------------------------
--  CREATE UNIQUE INDEX users_pkey ON rideshare.users USING btree (id);
--  CREATE UNIQUE INDEX index_users_on_email ON rideshare.users USING btree (email);
--  CREATE INDEX index_users_on_last_name ON rideshare.users USING btree (last_name);

CREATE UNIQUE INDEX index_users_on_email2
ON rideshare.users_copy USING btree (email);
-- CREATE INDEX
-- Time: 4.680 ms

-- Drop the source table and rename the destination table
BEGIN;
DROP TABLE rideshare.users CASCADE;
ALTER TABLE rideshare.users_copy RENAME TO users;
COMMIT;

-- BEGIN
-- Time: 2.289 ms
-- NOTICE:  drop cascades to 6 other objects
-- DETAIL:  drop cascades to default value for column id of table rideshare.users_copy
-- drop cascades to constraint fk_rails_c17a139554 on table rideshare.trip_requests
-- drop cascades to constraint fk_rails_e7560abc33 on table rideshare.trips
-- drop cascades to view rideshare.search_results
-- drop cascades to materialized view rideshare.fast_search_results
-- drop cascades to constraint fk_rails_e7560abc33 on table rideshare.trips_copy
-- DROP TABLE
-- Time: 19.819 ms
-- ALTER TABLE
-- Time: 2.606 ms
-- COMMIT
-- Time: 445.888 ms

-- Use Direct Updates for Text Replacement

UPDATE rideshare.users
SET email = rideshare.SCRUB_EMAIL(email);
-- UPDATE 0
-- Time: 17.385 ms
-- I have none....
-- Let's start fresh

rails db:drop
--   ActiveRecord::SchemaMigration Load (0.9ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
--   ActiveRecord::InternalMetadata Load (2.8ms)  SELECT * FROM "ar_internal_metadata" WHERE "ar_internal_metadata"."key" = $1 ORDER BY "ar_internal_metadata"."key" ASC LIMIT 1  [[nil, "environment"]]
--   ActiveRecord::SchemaMigration Load (0.4ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
--   ActiveRecord::InternalMetadata Load (0.2ms)  SELECT * FROM "ar_internal_metadata" WHERE "ar_internal_metadata"."key" = $1 ORDER BY "ar_internal_metadata"."key" ASC LIMIT 1  [[nil, "environment"]]
--   ActiveRecord::SchemaMigration Load (0.1ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
--   ActiveRecord::InternalMetadata Load (0.2ms)  SELECT * FROM "ar_internal_metadata" WHERE "ar_internal_metadata"."key" = $1 ORDER BY "ar_internal_metadata"."key" ASC LIMIT 1  [[nil, "environment"]]
--    (68.9ms)  DROP DATABASE IF EXISTS "rideshare_development"
-- Dropped database 'rideshare_development'
--    (25.8ms)  DROP DATABASE IF EXISTS "rideshare_test"
-- Dropped database 'rideshare_test'

rails db:create
--    (320.9ms)  CREATE DATABASE "rideshare_development" ENCODING = 'utf8'
-- Created database 'rideshare_development'
--    (188.1ms)  CREATE DATABASE "rideshare_test" ENCODING = 'utf8'
-- Created database 'rideshare_test'

psql -U postgres -d rideshare_development -c "GRANT ALL ON SCHEMA rideshare TO owner;"
-- CREATE SCHEMA

rails db:migrate
-- did it

rails data_generators:generate_all
-- did it

-- ok, should be ready to go from page 62 now!
-- new day
psql -U postgres -d rideshare_development

UPDATE rideshare.users
SET email = rideshare.SCRUB_EMAIL(email);
-- UPDATE 40210
-- perfect, back on track!

-- run the vacuum command to clean up dead rows
VACUUM (ANALYZE, VERBOSE) rideshare.users;
-- INFO:  vacuuming "rideshare_development.rideshare.users"
-- INFO:  launched 2 parallel vacuum workers for index cleanup (planned: 2)
-- INFO:  finished vacuuming "rideshare_development.rideshare.users": index scans: 0
-- pages: 0 removed, 1315 remain, 1 scanned (0.08% of total)
-- tuples: 0 removed, 40210 remain, 0 are dead but not yet removable
-- removable cutoff: 4253428, which was 0 XIDs old when operation ended
-- frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
-- index scan not needed: 0 pages from table (0.00% of total) had 0 dead item identifiers removed
-- index "index_users_on_email": pages: 735 in total, 0 newly deleted, 345 currently deleted, 345 reusable
-- avg read rate: 42.060 MB/s, avg write rate: 0.971 MB/s
-- buffer usage: 996 hits, 130 misses, 3 dirtied
-- WAL usage: 1 records, 0 full page images, 72 bytes
-- system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.02 s
-- INFO:  vacuuming "rideshare_development.pg_toast.pg_toast_4415210"
-- INFO:  finished vacuuming "rideshare_development.pg_toast.pg_toast_4415210": index scans: 0
-- pages: 0 removed, 0 remain, 0 scanned (100.00% of total)
-- tuples: 0 removed, 0 remain, 0 are dead but not yet removable
-- removable cutoff: 4253428, which was 0 XIDs old when operation ended
-- new relfrozenxid: 4253428, which is 41052 XIDs ahead of previous value
-- new relminmxid: 204050, which is 457 MXIDs ahead of previous value
-- frozen: 0 pages from table (100.00% of total) had 0 tuples frozen
-- index scan not needed: 0 pages from table (100.00% of total) had 0 dead item identifiers removed
-- avg read rate: 11.472 MB/s, avg write rate: 0.000 MB/s
-- buffer usage: 23 hits, 1 misses, 0 dirtied
-- WAL usage: 1 records, 0 full page images, 188 bytes
-- system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
-- INFO:  analyzing "rideshare.users"
-- INFO:  "users": scanned 1315 of 1315 pages, containing 40210 live rows and 0 dead rows; 30000 rows in sample, 40210 estimated total rows
-- VACUUM

-- there are a lot of 0s, doesn't look like there were any dead rows!

-- reindex the users table
REINDEX INDEX rideshare.index_users_on_email;
-- REINDEX

-- turn timing on
\timing

CREATE OR REPLACE PROCEDURE SCRUB_BATCHES()
LANGUAGE PLPGSQL
AS $$
DECLARE
  current_id INT := (SELECT MIN(id) FROM rideshare.users);
  max_id INT := (SELECT MAX(id) FROM rideshare.users);
  batch_size INT := 1000;
  rows_updated INT;
BEGIN
  WHILE current_id <= max_id LOOP
    UPDATE rideshare.users
    SET email = rideshare.SCRUB_EMAIL(email)
    WHERE id >= current_id
    AND id < current_id + batch_size;
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    COMMIT;
    RAISE NOTICE 'current_id: % - Number of rows updated: %', current_id, rows_updated;
    current_id := current_id + batch_size + 1;
  END LOOP;
END;
$$;
-- CREATE PROCEDURE
-- Time: 19.285 ms

CALL SCRUB_BATCHES();
-- NOTICE:  current_id: 1 - Number of rows updated: 1000
-- NOTICE:  current_id: 1002 - Number of rows updated: 1000
-- NOTICE:  current_id: 2003 - Number of rows updated: 1000
-- NOTICE:  current_id: 3004 - Number of rows updated: 1000
-- NOTICE:  current_id: 4005 - Number of rows updated: 1000
-- NOTICE:  current_id: 5006 - Number of rows updated: 1000
-- NOTICE:  current_id: 6007 - Number of rows updated: 1000
-- NOTICE:  current_id: 7008 - Number of rows updated: 1000
-- NOTICE:  current_id: 8009 - Number of rows updated: 1000
-- NOTICE:  current_id: 9010 - Number of rows updated: 1000
-- NOTICE:  current_id: 10011 - Number of rows updated: 1000
-- NOTICE:  current_id: 11012 - Number of rows updated: 1000
-- NOTICE:  current_id: 12013 - Number of rows updated: 1000
-- NOTICE:  current_id: 13014 - Number of rows updated: 1000
-- NOTICE:  current_id: 14015 - Number of rows updated: 1000
-- NOTICE:  current_id: 15016 - Number of rows updated: 1000
-- NOTICE:  current_id: 16017 - Number of rows updated: 1000
-- NOTICE:  current_id: 17018 - Number of rows updated: 1000
-- NOTICE:  current_id: 18019 - Number of rows updated: 1000
-- NOTICE:  current_id: 19020 - Number of rows updated: 1000
-- NOTICE:  current_id: 20021 - Number of rows updated: 1000
-- NOTICE:  current_id: 21022 - Number of rows updated: 1000
-- NOTICE:  current_id: 22023 - Number of rows updated: 1000
-- NOTICE:  current_id: 23024 - Number of rows updated: 1000
-- NOTICE:  current_id: 24025 - Number of rows updated: 1000
-- NOTICE:  current_id: 25026 - Number of rows updated: 1000
-- NOTICE:  current_id: 26027 - Number of rows updated: 1000
-- NOTICE:  current_id: 27028 - Number of rows updated: 1000
-- NOTICE:  current_id: 28029 - Number of rows updated: 1000
-- NOTICE:  current_id: 29030 - Number of rows updated: 1000
-- NOTICE:  current_id: 30031 - Number of rows updated: 1000
-- NOTICE:  current_id: 31032 - Number of rows updated: 1000
-- NOTICE:  current_id: 32033 - Number of rows updated: 1000
-- NOTICE:  current_id: 33034 - Number of rows updated: 1000
-- NOTICE:  current_id: 34035 - Number of rows updated: 1000
-- NOTICE:  current_id: 35036 - Number of rows updated: 1000
-- NOTICE:  current_id: 36037 - Number of rows updated: 1000
-- NOTICE:  current_id: 37038 - Number of rows updated: 1000
-- NOTICE:  current_id: 38039 - Number of rows updated: 1000
-- NOTICE:  current_id: 39040 - Number of rows updated: 1000
-- NOTICE:  current_id: 40041 - Number of rows updated: 170
-- CALL
-- Time: 387.473 ms
