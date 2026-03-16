-- new day from page 106

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- psql1, start a transaction
BEGIN;
LOCK trips IN ACCESS EXCLUSIVE MODE;

-- psql2, set a transaction level lock_timeout
BEGIN;
SET LOCAL lock_timeout = '5s';
-- should hang for 5 seconds
ALTER TABLE trips ADD COLUMN city_id INTEGER DEFAULT 1;
-- ERROR:  canceling statement due to lock timeout
-- Time: 5075.823 ms (00:05.076)

-- rollback both the transactions
ROLLBACK;

-- new day from page 110
-- backfill the users_intermediate table with the users table
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

CREATE SCHEMA IF NOT EXISTS temp;

CREATE UNLOGGED TABLE temp.users_intermediate (
  user_id BIGINT,
  city_id INTEGER
);

ALTER TABLE trip_requests_intermediate
SET (autovacuum_enabled = false);

INSERT INTO temp.users_intermediate (user_id, city_id)
SELECT GENERATE_SERIES(1, 10, 1), GENERATE_SERIES(1, 10, 1);

\d temp.users_intermediate
--       Unlogged table "temp.users_intermediate"
--  Column  |  Type   | Collation | Nullable | Default 
-- ---------+---------+-----------+----------+---------
--  user_id | bigint  |           |          | 
--  city_id | integer |           |          | 

SELECT * FROM temp.users_intermediate LIMIT 10;
--  user_id | city_id 
-- ---------+---------
--        1 |       1
--        2 |       2
--        3 |       3
--        4 |       4
--        5 |       5
--        6 |       6
--        7 |       7
--        8 |       8
--        9 |       9
--       10 |      10
-- (10 rows)

-- Time: 1.396 ms

CREATE INDEX temp_users_user_id_city_id
ON temp.users_intermediate (user_id, city_id);

ALTER TABLE users ADD COLUMN IF NOT EXISTS city_id INTEGER;

EXPLAIN 
UPDATE users
SET 
  city_id = temp.users_intermediate.city_id
FROM temp.users_intermediate
WHERE users.id = temp.users_intermediate.user_id
AND users.id > 0
AND users.id < 10000;
--                                          QUERY PLAN                                          
-- ---------------------------------------------------------------------------------------------
--  Update on users  (cost=0.43..85.68 rows=0 width=0)
--    ->  Nested Loop  (cost=0.43..85.68 rows=1 width=16)
--          ->  Seq Scan on users_intermediate  (cost=0.00..1.10 rows=10 width=18)
--          ->  Index Scan using users_pkey on users  (cost=0.43..8.46 rows=1 width=14)
--                Index Cond: ((id = users_intermediate.user_id) AND (id > 0) AND (id < 10000))
-- (5 rows)

SET enable_seqscan = off;

EXPLAIN 
UPDATE users
SET 
  city_id = temp.users_intermediate.city_id
FROM temp.users_intermediate
WHERE users.id = temp.users_intermediate.user_id
AND users.id > 0
AND users.id < 5000;
--                                                        QUERY PLAN                                                       
-- ------------------------------------------------------------------------------------------------------------------------
--  Update on users  (cost=0.76..446.19 rows=0 width=0)
--    ->  Merge Join  (cost=0.76..446.19 rows=5 width=16)
--          Merge Cond: (users.id = users_intermediate.user_id)
--          ->  Index Scan using users_pkey on users  (cost=0.43..241.66 rows=5111 width=14)
--                Index Cond: ((id > 0) AND (id < 5000))
--          ->  Index Scan using temp_users_user_id_city_id on users_intermediate  (cost=0.29..420.19 rows=10010 width=18)
-- (6 rows)

-- count the number of rows in the temp.users_intermediate table
SELECT COUNT(*) FROM temp.users_intermediate;

-- add 10000 rows to the temp.users_intermediate table
INSERT INTO temp.users_intermediate (user_id, city_id)
SELECT GENERATE_SERIES(10001, 20000, 1), GENERATE_SERIES(1, 10, 1);

-- count the number of rows in the temp.users_intermediate table
SELECT COUNT(*) FROM temp.users_intermediate;

UPDATE users
SET 
  city_id = temp.users_intermediate.city_id
FROM temp.users_intermediate
WHERE users.id = temp.users_intermediate.user_id
AND users.id > 0
AND users.id < 5000;
-- UPDATE 10
-- Time: 16.286 ms


UPDATE users
SET 
  city_id = temp.users_intermediate.city_id
FROM temp.users_intermediate
WHERE users.id = temp.users_intermediate.user_id
AND users.id > 0
AND users.id < 30000;
-- UPDATE 10010
-- Time: 245.390 ms

-- select the first 10 rows from the users table
-- and see that the the city_id has been updated!

SELECT * FROM users
WHERE id BETWEEN 1 AND 10;
--  id | first_name |  last_name   |                 email                  |  type  |        created_at         |        updated_at         | password_digest | trips_count | drivers_license_number | city_id 
-- ----+------------+--------------+----------------------------------------+--------+---------------------------+---------------------------+-----------------+-------------+------------------------+---------
--   1 | Zona       | Ferry        | 58d6d44372e5a7d52c0@email.com          | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | Z800000471510          |       1
--   2 | Dominica   | Prosacco     | 350223a7fd35061debc6b5b636@email.com   | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | D800000815191          |       2
--   3 | Sonny      | Hessel       | 1d6d0a0fd96bbc5c56171@email.com        | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | S800000653442          |       3
--   4 | Alysa      | Robel        | 6f62630d365f677ad434@email.com         | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | A800000628773          |       4
--   5 | Rolf       | Greenfelder  | 87fdbec96651b48aa9a8b35b4@email.com    | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | R800000496804          |       5
--   6 | Ignacia    | McGlynn      | f98358dd99bad8f7ad223478@email.com     | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | I800000467065          |       6
--   7 | Eddie      | Hills        | 9adb3ce13cca36f6bf6b@email.com         | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | E800000711946          |       7
--   8 | Leonel     | Christiansen | 7896303a079313f0483a48325012@email.com | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | L800000148827          |       8
--   9 | Helga      | Watsica      | a71a5c8545c69d570a2bee@email.com       | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | H800000228638          |       9
--  10 | Luciano    | Hilll        | 813f1a8ea1bc8d91c7839b@email.com       | Driver | 2026-01-29 17:14:05.02089 | 2026-01-29 17:14:05.02089 |                 |             | L800000625259          |      10
-- (10 rows)

-- delete the temp.users_intermediate table
DROP TABLE IF EXISTS temp.users_intermediate;

-- confirm it's gone
\d temp.users_intermediate
-- Did not find any relation named "temp.users_intermediate".
