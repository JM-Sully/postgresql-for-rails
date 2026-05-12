-- new day from page 159
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- Ensure stats are updated
ANALYZE users;
-- ANALYZE

-- use reltuples for estimate
SELECT reltuples::NUMERIC FROM pg_class WHERE relname = 'users';
reltuples 
-----------
    20200
(1 row)

-- start a rails console
bin/rails console

-- regular count of users
User.count
  User Count (12.3ms)  SELECT COUNT(*) FROM "users"
=> 20200

-- fast count of users
User.fast_count
  (56.7ms)  SELECT fast_count('users', 100000)
=> 20200

-- add 10 millions user records
DATABASE_URL='postgres://postgres:@localhost:5432/rideshare_development' sh db/scripts/bulk_load.sh

-- regular count of users
User.count
  User Count (577.7ms)  SELECT COUNT(*) FROM "users"
=> 10020200

-- fast count of users
User.fast_count
  (27.9ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (6.5ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (2.5ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (3.5ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (2.6ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (1.8ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (3.1ms)  SELECT fast_count('users', 100000)
=> 10021207
User.fast_count
  (2.5ms)  SELECT fast_count('users', 100000)
=> 10021207


User.where("last_name ILIKE 'lname123%'").count
[sql.active_record] 3.593973 SELECT COUNT(*) FROM "users" WHERE (last_name ILIKE 'lname123%')
  User Count (3594.7ms)  SELECT COUNT(*) FROM "users" WHERE (last_name ILIKE 'lname123%')
=> 11111

User.where("last_name ILIKE 'lname123%'").estimated_count
  (2.7ms)  EXPLAIN SELECT "users".* FROM "users" WHERE (last_name ILIKE 'lname123%')
=> 1002

ALTER TABLE users ALTER COLUMN last_name SET STATISTICS 10000;
-- ALTER TABLE
ANALYZE users;
-- ANALYZE

User.where("last_name ILIKE 'lname123%'").count
[sql.active_record] 1.354832 SELECT COUNT(*) FROM "users" WHERE (last_name ILIKE 'lname123%')
  User Count (1355.1ms)  SELECT COUNT(*) FROM "users" WHERE (last_name ILIKE 'lname123%')
=> 11111

User.where("last_name ILIKE 'lname123%'").estimated_count
  (4.3ms)  EXPLAIN SELECT "users".* FROM "users" WHERE (last_name ILIKE 'lname123%')
=> 12001

User.distinct.count(:last_name)
[sql.active_record] 1.987772 SELECT COUNT(DISTINCT "users"."last_name") FROM "users"
  User Count (1988.0ms)  SELECT COUNT(DISTINCT "users"."last_name") FROM "users"
=> 10000472


User.fast_distinct_count(column: :last_name)
[sql.active_record] 29.893178 WITH RECURSIVE t AS (
  (SELECT "last_name" FROM "users" ORDER BY "last_name" LIMIT 1)
  UNION
  SELECT (SELECT "last_name" FROM "users" WHERE "last_name" > t."last_name" ORDER BY "last_name" LIMIT 1)
  FROM t
  WHERE t."last_name" IS NOT NULL
),

distinct_values AS (
  SELECT "last_name" FROM t WHERE "last_name" IS NOT NULL
  UNION
  SELECT NULL WHERE EXISTS (SELECT 1 FROM "users" WHERE "last_name" IS NULL)
)

SELECT COUNT(*) FROM distinct_values

   (29893.4ms)  WITH RECURSIVE t AS (
  (SELECT "last_name" FROM "users" ORDER BY "last_name" LIMIT 1)
  UNION
  SELECT (SELECT "last_name" FROM "users" WHERE "last_name" > t."last_name" ORDER BY "last_name" LIMIT 1)
  FROM t
  WHERE t."last_name" IS NOT NULL
),

distinct_values AS (
  SELECT "last_name" FROM t WHERE "last_name" IS NOT NULL
  UNION
  SELECT NULL WHERE EXISTS (SELECT 1 FROM "users" WHERE "last_name" IS NULL)
)

SELECT COUNT(*) FROM distinct_values

User.fast_distinct_count(column: :last_name)
[sql.active_record] 31.234858 WITH RECURSIVE t AS (
  (SELECT "last_name" FROM "users" ORDER BY "last_name" LIMIT 1)
  UNION
  SELECT (SELECT "last_name" FROM "users" WHERE "last_name" > t."last_name" ORDER BY "last_name" LIMIT 1)
  FROM t
  WHERE t."last_name" IS NOT NULL
),
distinct_values AS (
  SELECT "last_name" FROM t WHERE "last_name" IS NOT NULL
  UNION
  SELECT NULL WHERE EXISTS (SELECT 1 FROM "users" WHERE "last_name" IS NULL)
)
SELECT COUNT(*) FROM distinct_values
  (31235.4ms)  WITH RECURSIVE t AS (
  (SELECT "last_name" FROM "users" ORDER BY "last_name" LIMIT 1)
  UNION
  SELECT (SELECT "last_name" FROM "users" WHERE "last_name" > t."last_name" ORDER BY "last_name" LIMIT 1)
  FROM t
  WHERE t."last_name" IS NOT NULL
),
distinct_values AS (
  SELECT "last_name" FROM t WHERE "last_name" IS NOT NULL
  UNION
  SELECT NULL WHERE EXISTS (SELECT 1 FROM "users" WHERE "last_name" IS NULL)
)
SELECT COUNT(*) FROM distinct_values
=> 10000472

-- back in psql
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE type = 'Rider') AS rider_count,
  COUNT(*) FILTER (WHERE type = 'Driver') AS driver_count
FROM users;

  total    | rider_count | driver_count 
----------+-------------+--------------
  10020200 |     5010100 |      5010100
(1 row)

-- new day from page 163
-- install pg_hint_plan (page 405 in paper book for instructions)
-- https://github.com/ossc-db/pg_hint_plan
git clone git@github.com:ossc-db/pg_hint_plan.git
cd pg_hint_plan
make && make install
-- got errors because a PostgreSQL version mismatch

-- try a different approach, suggested by cursor agent
brew install pgxnclient
export PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
pgxn install pg_hint_plan16

-- connect to the rideshare development database as a super user
psql -U postgres -d rideshare_development
-- create the extension
CREATE EXTENSION pg_hint_plan;
-- CREATE EXTENSION

SET search_path TO rideshare;

-- start a rails console
bin/rails console
User.where("id <= 10").explain(:analyze)

=> 
EXPLAIN (ANALYZE) SELECT "users".* FROM "users" WHERE (id <= 10)
                                                      QUERY PLAN
----------------------------------------------------------------------------------------------------------------------
Index Scan using users_pkey on users  (cost=0.43..8.61 rows=10 width=158) (actual time=0.005..0.007 rows=10 loops=1)
  Index Cond: (id <= 10)
Planning Time: 0.081 ms
Execution Time: 0.044 ms
(4 rows)

-- tell the query to use a SeqScan instead of an Index Scan
User.optimizer_hints('SeqScan(users)').where("id <= 10").to_sql
=> "SELECT /*+ SeqScan(users) */ \"users\".* FROM \"users\" WHERE (id <= 10)"

-- make sure pg_hint_plan is enabled
ActiveRecord::Base.connection.execute("SET pg_hint_plan.enable_hint = ON")
  (2.2ms)  SET pg_hint_plan.enable_hint = ON
=> #<PG::Result:0x00000001100b7f50 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>


-- add pg_hint_plan to the shared_preload_libraries in postgresql.conf
vim /opt/homebrew/var/postgresql@16/postgresql.conf
shared_preload_libraries = 'pg_stat_statements,auto_explain,pg_hint_plan'

-- restart the postgresql service to apply the changes
brew services restart postgresql@16


User.optimizer_hints("SeqScan(users)").where("id <= 10").explain(:analyze)

[sql.active_record] 3.506588 SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
  User Load (3506.8ms)  SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
[sql.active_record] 3.134178 EXPLAIN (ANALYZE) SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
=> 
EXPLAIN (ANALYZE) SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
Gather  (cost=1000.00..200857.54 rows=10 width=158) (actual time=0.552..3133.536 rows=10 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  ->  Parallel Seq Scan on users  (cost=0.00..199856.54 rows=4 width=158) (actual time=2086.098..3129.783 rows=3 loops=3)
        Filter: (id <= 10)
        Rows Removed by Filter: 3340063
Planning Time: 0.058 ms
Execution Time: 3133.658 ms
(8 rows)

-- make sure pg_hint_plan is turned off
ActiveRecord::Base.connection.execute("SET pg_hint_plan.enable_hint = OFF")
  (29.3ms)  SET pg_hint_plan.enable_hint = OFF
=> #<PG::Result:0x000000010dd528f8 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>


User.optimizer_hints("SeqScan(users)").where("id <= 10").explain(:analyze)
  User Load (9.5ms)  SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
=> 
EXPLAIN (ANALYZE) SELECT /*+ SeqScan(users) */ "users".* FROM "users" WHERE (id <= 10)
                                                      QUERY PLAN
----------------------------------------------------------------------------------------------------------------------
Index Scan using users_pkey on users  (cost=0.43..8.61 rows=10 width=158) (actual time=0.005..0.009 rows=10 loops=1)
  Index Cond: (id <= 10)
Planning Time: 0.137 ms
Execution Time: 1.369 ms
(4 rows)


-- new day from page 164
bin/rails runner 'RailsPgExtras.table_cache_hit(args: { schema: "rideshare" })'
   (88.9ms)  /* Calculates your cache hit rate for reading tables */
SELECT
  relname AS name,
  heap_blks_hit AS buffer_hits,
  heap_blks_read AS block_reads,
  heap_blks_hit + heap_blks_read AS total_read,
  CASE (heap_blks_hit + heap_blks_read)::float
    WHEN 0 THEN 'Insufficient data'
    ELSE (heap_blks_hit / (heap_blks_hit + heap_blks_read)::float)::text
  END ratio
FROM
  pg_statio_user_tables
WHERE
  schemaname = 'rideshare'
ORDER BY
  heap_blks_hit / (heap_blks_hit + heap_blks_read + 1)::float DESC;

+----------------------------------------------------------------------------------------+
|                   Calculates your cache hit rate for reading tables                    |
+----------------------+-------------+-------------+------------+------------------------+
| name                 | buffer_hits | block_reads | total_read | ratio                  |
+----------------------+-------------+-------------+------------+------------------------+
| users                | 100         | 295242      | 295342     | 0.00033859051540248257 |
| fast_search_results  | 0           | 0           | 0          | Insufficient data      |
| trip_positions       | 0           | 0           | 0          | Insufficient data      |
| vehicle_reservations | 0           | 0           | 0          | Insufficient data      |
| schema_migrations    | 0           | 0           | 0          | Insufficient data      |
| trips                | 0           | 0           | 0          | Insufficient data      |
| vehicles             | 0           | 0           | 0          | Insufficient data      |
| locations            | 0           | 0           | 0          | Insufficient data      |
| ar_internal_metadata | 0           | 0           | 0          | Insufficient data      |
| trip_requests        | 0           | 0           | 0          | Insufficient data      |
+----------------------+-------------+-------------+------------+------------------------+


-- generate a report using pgBadger
-- install pgBadger
brew install pgbadger      

-- create a directory for the reports
mkdir -p ~/pg_reports

-- generate the report, for the week of May 1-6
pgbadger -b "2026-05-01 00:00:00" -e "2026-05-06 23:59:59" \
  -o ~/pg_reports/rideshare_week.html \
  /opt/homebrew/var/log/postgresql@16.log

-- open the report
open ~/pg_reports/rideshare_week.html

