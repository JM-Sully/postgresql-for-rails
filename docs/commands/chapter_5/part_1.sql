-- new day from page 97

psql -U postgres -d rideshare_development

-- reset my temp schema
DROP SCHEMA IF EXISTS temp CASCADE;
-- NOTICE:  drop cascades to table temp.users
-- DROP SCHEMA
CREATE SCHEMA temp;
-- CREATE SCHEMA

-- create a users table with an id and name column
CREATE TABLE temp.users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL
);
-- CREATE TABLE

-- look at the table
\d temp.users
--                                        Table "temp.users"
--  Column |          Type          | Collation | Nullable |                Default                 
-- --------+------------------------+-----------+----------+----------------------------------------
--  id     | integer                |           | not null | nextval('temp.users_id_seq'::regclass)
--  name   | character varying(255) |           | not null | 
-- Indexes:
--     "users_pkey" PRIMARY KEY, btree (id)

-- turn on the timer
\timing
-- Timing is on.

-- add ten million rows to the users table with fake names using the Faker gem
INSERT INTO temp.users (name)
SELECT 'user_' || seq
FROM GENERATE_SERIES(1, 10_000_000) seq;
-- INSERT 0 10000000
-- Time: 29347.367 ms (00:29.347)

-- query the table with a limit of 10
SELECT * FROM temp.users LIMIT 10;
--  id |  name   
-- ----+---------
--   1 | user_1
--   2 | user_2
--   3 | user_3
--   4 | user_4
--   5 | user_5
--   6 | user_6
--   7 | user_7
--   8 | user_8
--   9 | user_9
--  10 | user_10
-- (10 rows)

-- add city_id to users table with a default value of 1, NON-VOLATILE
ALTER TABLE temp.users
ADD COLUMN city_id INTEGER DEFAULT 1;
-- ALTER TABLE
-- Time: 5.205 ms

-- look at the table
\d temp.users
--                                         Table "temp.users"
--  Column  |          Type          | Collation | Nullable |                Default                 
-- ---------+------------------------+-----------+----------+----------------------------------------
--  id      | integer                |           | not null | nextval('temp.users_id_seq'::regclass)
--  name    | character varying(255) |           | not null | 
--  city_id | integer                |           |          | 1
-- Indexes:
--     "users_pkey" PRIMARY KEY, btree (id)

-- drop the column I just added to prepare to add it a second time...
ALTER TABLE temp.users
DROP COLUMN city_id;
-- ALTER TABLE
-- Time: 4.756 ms

-- start a second psql session
psql -U postgres -d rideshare_development

-- run a VOLATILE transaction
-- this query locked the table with exclusive access
ALTER TABLE temp.users ADD COLUMN city_id INTEGER 
  DEFAULT 1 + FLOOR(RANDOM() * 25);
-- ALTER TABLE
-- Time: 21982.739 ms (00:21.983)


-- while the above is running in one session, run a query in the other session
-- takes pretty much the same amount of time to run as the query above
-- since it needs to wait for the exclusive access to be released
SELECT * FROM temp.users LIMIT 1;
--  id |  name  | city_id 
-- ----+--------+---------
--   1 | user_1 |       7
-- (1 row)

-- Time: 21350.583 ms (00:21.351)

-- new day from page 104, Locking, Blocking, and Concurrency Refresher
-- open two sessions
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- in the first session
BEGIN;
LOCK trips IN ACCESS EXCLUSIVE MODE;
-- BEGIN
-- Time: 0.408 ms
-- LOCK TABLE
-- Time: 0.101 ms
-- in the second session

-- in the second session
SELECT
  mode,
  pg_class.relname,
  locktype,
  relation
FROM pg_locks
JOIN pg_class
ON pg_locks.relation = pg_class.oid
AND pg_locks.mode = 'AccessExclusiveLock';
--         mode         | relname | locktype | relation 
-- ---------------------+---------+----------+----------
--  AccessExclusiveLock | trips   | relation |  4415242
-- (1 row)

-- Time: 0.699 ms

-- first session
SHOW lock_timeout;
--  lock_timeout 
-- --------------
--  0
-- (1 row)

-- Time: 0.143 ms

-- second session
ALTER TABLE trips ADD COLUMN city_id INTEGER DEFAULT 1;
-- this hangs, because the first session has the exclusive lock on the table

-- session 1, see the waiting query
SELECT
  wait_event_type,
  wait_event, query
FROM pg_stat_activity
WHERE wait_event = 'relation'
AND query LIKE '%ALTER TABLE%';
--  wait_event_type | wait_event |                          query                          
-- -----------------+------------+---------------------------------------------------------
--  Lock            | relation   | ALTER TABLE trips ADD COLUMN city_id INTEGER DEFAULT 1;
-- (1 row)

-- still session 1
-- rollback the transaction
ROLLBACK;
-- ROLLBACK
-- Time: 0.585 ms

-- session 2, see the query finish
-- INTEGER DEFAULT 1;
-- ALTER TABLE
-- Time: 79450.292 ms (01:19.450)