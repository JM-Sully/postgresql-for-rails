-- new day from page 154
-- set the below in postgresql.conf
log_min_duration_statement = 1000	

-- I needed to restart the postgresql service to apply the changes
brew services restart postgresql@16

psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log

-- run the query in psql
SELECT pg_sleep(2);


-- new session
-- needed to refresh the global command 
curl -O https://raw.githubusercontent.com/andyatkinson/pg_scripts/main/administration/tail_log.sh
chmod +x tail_log.sh
export DATABASE_URL=postgres://postgres@localhost/rideshare_development
./tail_log.sh

-- new session from page 154
--  changes in posgresql.conf
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = 0

-- restart the postgresql service to apply the changes
brew services restart postgresql@16

-- start a new psql session
psql -U postgres -d rideshare_development

-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log


--  changes in posgresql.conf
compute_query_id = on
log_line_prefix = '%m [%p] qid=%Q '

-- restart the postgresql service to apply the changes
brew services restart postgresql@16

-- start a new psql session
psql -U postgres -d rideshare_development
SET search_path TO rideshare;


-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log
-- 2026-04-22 15:42:00.547 BST [56476] qid=-3416356442043621232 LOG:  duration: 2000.646 ms  plan:
--         Query Text: SELECT pg_sleep(2);
--         Result  (cost=0.00..0.01 rows=1 width=4)
-- 2026-04-22 15:42:00.547 BST [56476] qid=-3416356442043621232 LOG:  duration: 2010.138 ms  statement: SELECT pg_sleep(2);

-- reset the statistics
SELECT rideshare.pg_stat_statements_reset();
-- output to a file (wasn't rendering in the terminal well)
\o file.text

-- get some slow data
SELECT pg_sleep(2);
SELECT pg_sleep(2);

-- get the top 10 slowest queries
SELECT
  mean_exec_time,
  calls,
  query,
  queryid
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- see the same queryid as from the log
--    mean_exec_time   | calls |                    query                    |       queryid        
-- --------------------+-------+---------------------------------------------+----------------------
--         2001.211604 |     2 | SELECT pg_sleep($1)                         | -3416356442043621232
--  0.7665839999999999 |     1 | SELECT                                     +|  -688589285304235266
--                     |       |   mean_exec_time,                          +| 
--                     |       |   calls,                                   +| 
--                     |       |   query,                                   +| 
--                     |       |   queryid                                  +| 
--                     |       | FROM pg_stat_statements                    +| 
--                     |       | ORDER BY mean_exec_time DESC               +| 
--                     |       | LIMIT $1                                    | 
--            0.314791 |     1 | SELECT rideshare.pg_stat_statements_reset() |  5423182380465503768
--            0.128625 |     1 | SET search_path TO rideshare                |  6618742273586964954
-- (4 rows)


SELECT * FROM users WHERE first_name = 'Jess';

SELECT * FROM users WHERE type = 'Driver' LIMIT(2);

-- new day from page 157
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\d users
--                                               Table "rideshare.users"
--          Column         |              Type              | Collation | Nullable |              Default              
-- ------------------------+--------------------------------+-----------+----------+-----------------------------------
--  id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
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
--     TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
--     TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)


-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log

SELECT * FROM users WHERE last_name = 'Sipes';
-- in the logs from the above query, and there is an index on this field
2026-04-27 14:51:31.490 BST [28038] qid=-4512862274133231448 LOG:  duration: 6.078 ms  plan:
        Query Text: SELECT * FROM users WHERE last_name = 'Sipes';
        Bitmap Heap Scan on users  (cost=4.60..118.47 rows=40 width=159)
          Recheck Cond: ((last_name)::text = 'Sipes'::text)
          ->  Bitmap Index Scan on index_users_on_last_name  (cost=0.00..4.59 rows=40 width=0)
                Index Cond: ((last_name)::text = 'Sipes'::text)

SELECT * FROM users WHERE first_name = 'Jess';
-- In the logs, but there is no index on first name
2026-04-27 14:53:16.306 BST [28038] qid=-4712150826851824628 LOG:  duration: 20.694 ms  plan:
        Query Text: SELECT * FROM users WHERE first_name = 'Jess';
        Seq Scan on users  (cost=0.00..584.90 rows=4 width=159)
          Filter: ((first_name)::text = 'Jess'::text)


SELECT * FROM users WHERE type = 'Driver';
2026-04-27 15:33:16.542 BST [28038] qid=2689086765974547644 LOG:  duration: 20.988 ms  plan:
        Query Text: SELECT * FROM users WHERE type = 'Driver';
        Seq Scan on users  (cost=0.00..583.50 rows=10103 width=159)
          Filter: ((type)::text = 'Driver'::text)


-- add an index on the type column on users
CREATE INDEX index_users_on_type ON users USING btree (type);
-- CREATE INDEX

-- check the users table to make sure it is there
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
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_last_name" btree (last_name)
    "index_users_on_type" btree (type)
Referenced by:
    TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
    TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)

-- DROP INDEX IF EXISTS index_users_on_type;



-- new day from page 157 (yup, still on this section...)
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log

SELECT * FROM users WHERE type = 'Driver';
2026-04-29 08:39:49.695 BST [9698] qid=2689086765974547644 LOG:  duration: 57.921 ms  plan:
        Query Text: SELECT * FROM users WHERE type = 'Driver';
        Index Scan using index_users_on_type on users  (cost=0.29..387.81 rows=10103 width=159)
          Index Cond: ((type)::text = 'Driver'::text)



-- new day from page 157 (yup, still on this section...)
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log

VACUUM ANALYZE users;
VACUUM

SELECT * FROM users WHERE first_name = 'Jess';


SELECT * FROM users WHERE last_name = 'Sipes';


SELECT last_name FROM users WHERE last_name = 'Sipes';
2026-04-30 07:53:18.870 BST [19808] qid=2308745996181189102 LOG:  duration: 0.215 ms  plan:
        Query Text: SELECT last_name FROM users WHERE last_name = 'Sipes';
        Index Only Scan using index_users_on_last_name on users  (cost=0.29..4.99 rows=40 width=7)
          Index Cond: (last_name = 'Sipes'::text)

SELECT last_name, email FROM users WHERE last_name = 'Sipes';
2026-04-30 07:55:41.677 BST [19808] qid=8762733795932077561 LOG:  duration: 0.225 ms  plan:
        Query Text: SELECT last_name, email FROM users WHERE last_name = 'Sipes';
        Bitmap Heap Scan on users  (cost=4.60..118.47 rows=40 width=42)
          Recheck Cond: ((last_name)::text = 'Sipes'::text)
          ->  Bitmap Index Scan on index_users_on_last_name  (cost=0.00..4.59 rows=40 width=0)
                Index Cond: ((last_name)::text = 'Sipes'::text)

SELECT email, last_name FROM users WHERE last_name = 'Sipes';
2026-04-30 07:56:26.586 BST [19808] qid=4791931548373742125 LOG:  duration: 0.188 ms  plan:
        Query Text: SELECT email, last_name FROM users WHERE last_name = 'Sipes';
        Bitmap Heap Scan on users  (cost=4.60..118.47 rows=40 width=42)
          Recheck Cond: ((last_name)::text = 'Sipes'::text)
          ->  Bitmap Index Scan on index_users_on_last_name  (cost=0.00..4.59 rows=40 width=0)
                Index Cond: ((last_name)::text = 'Sipes'::text)

-- create an index on the email and last_name columns
CREATE INDEX index_users_on_email_and_last_name ON users USING btree (email, last_name);
-- CREATE INDEX

-- check the users table to make sure it is there
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
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_email_and_last_name" btree (email, last_name)
    "index_users_on_last_name" btree (last_name)
    "index_users_on_type" btree (type)
Referenced by:
    TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
    TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)

-- drop the index
DROP INDEX IF EXISTS index_users_on_email_and_last_name;
-- DROP INDEX

SELECT email, last_name FROM users WHERE last_name = 'Sipes';
2026-04-30 08:04:26.656 BST [19808] qid=4791931548373742125 LOG:  duration: 0.283 ms  plan:
        Query Text: SELECT email, last_name FROM users WHERE last_name = 'Sipes';
        Bitmap Heap Scan on users  (cost=4.60..118.47 rows=40 width=42)
          Recheck Cond: ((last_name)::text = 'Sipes'::text)
          ->  Bitmap Index Scan on index_users_on_last_name  (cost=0.00..4.59 rows=40 width=0)
                Index Cond: ((last_name)::text = 'Sipes'::text)

DROP INDEX IF EXISTS index_users_on_email_and_last_name;
-- DROP INDEX

-- create an index on the email and last_name columns
CREATE INDEX index_users_on_last_name_and_email ON users USING btree (last_name, email);
-- CREATE INDEX

-- check the users table to make sure it is there
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
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_last_name" btree (last_name)
    "index_users_on_last_name_and_email" btree (last_name, email)
    "index_users_on_type" btree (type)
Referenced by:
REFERENCES users(id)
CES users(id)


-- drop the index
DROP INDEX IF EXISTS index_users_on_last_name_and_email;
-- DROP INDEX

SELECT email, last_name FROM users WHERE last_name = 'Sipes';
2026-04-30 08:16:20.737 BST [19808] qid=4791931548373742125 LOG:  duration: 1.436 ms  plan:
        Query Text: SELECT email, last_name FROM users WHERE last_name = 'Sipes';
        Index Only Scan using index_users_on_last_name_and_email on users  (cost=0.41..5.11 rows=40 width=42)
          Index Cond: (last_name = 'Sipes'::text)


DROP INDEX IF EXISTS index_users_on_last_name;
-- DROP INDEX

SELECT * FROM users WHERE last_name = 'Sipes';
2026-04-30 08:24:02.300 BST [19808] qid=-4512862274133231448 LOG:  duration: 1.289 ms  plan:
        Query Text: SELECT * FROM users WHERE last_name = 'Sipes';
        Bitmap Heap Scan on users  (cost=4.72..118.60 rows=40 width=159)
          Recheck Cond: ((last_name)::text = 'Sipes'::text)
          ->  Bitmap Index Scan on index_users_on_last_name_and_email  (cost=0.00..4.71 rows=40 width=0)
                Index Cond: ((last_name)::text = 'Sipes'::text)
