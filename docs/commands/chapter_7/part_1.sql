-- new day from page 145

bin/rails console
-- trigger the slow query subscriber
ActiveRecord::Base.connection.execute("SELECT PG_SLEEP(2)")
-- [sql.active_record] 2.055199 SELECT PG_SLEEP(2)
--    (2055.4ms)  SELECT PG_SLEEP(2)
-- => #<PG::Result:0x0000000118331850 status=PGRES_TUPLES_OK ntuples=1 nfields=1 cmd_tuples=1>

-- new terminal
-- connect to the rideshare development database as a super user
psql -U postgres -d rideshare_development

-- Create the extenstion within the rideshare schema
CREATE EXTENSION IF NOT EXISTS pg_stat_statements
WITH SCHEMA rideshare;
-- CREATE EXTENSION

-- new day from page 146
bin/rails server

-- new terminal
-- simulate application activity
bin/rails simulate:app_activity
-- Running script 1 times...
--   Rider Load (5.9ms)  SELECT "users".* FROM "users" WHERE "users"."type" = 'Rider' ORDER BY "users"."id" ASC LIMIT 1
--   ↳ lib/tasks/simulate_app_activity.rake:27:in `block (3 levels) in <top (required)>'
-- [trip_request] creating trip request...
-- [trip_request] got trip_request_id: 1001
-- [trip_request] checking for trip_id...
-- [trip_request] show_resp: {:trip_request_id=>1001, :trip_id=>1001}
-- [trip] Got a trip_id: 1001

-- new terminal
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

SELECT
  mean_exec_time,
  calls,
  query,
  queryid
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
-- this shows queries from all console activities, not just rideshare! (which I had been curious about seeing)

-- reset the statistics
SELECT rideshare.pg_stat_statements_reset();

-- check the statistics 
SELECT
  mean_exec_time,
  calls,
  query,
  queryid
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
--  mean_exec_time | calls |                    query                    |       queryid       
-- ----------------+-------+---------------------------------------------+---------------------
--        2.694751 |     1 | SELECT rideshare.pg_stat_statements_reset() | 5423182380465503768
-- (1 row)

-- output to a file (wasn't rendering in the terminal well)
\o file.text
-- get the top 10 slowest queries
SELECT
  mean_exec_time,
  calls,
  query,
  queryid
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;


--    mean_exec_time    | calls |                                                                                                                            query                                                                                                                            |       queryid        
-- ---------------------+-------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------
--   22.638666999999998 |     3 | SELECT "users".* FROM "users" WHERE "users"."type" = $1                                                                                                                                                                                                     |  2689086765974547644
--   3.8353193333333335 |     3 | SELECT "users".* FROM "users" WHERE "users"."type" = $1 ORDER BY "users"."id" ASC LIMIT $2                                                                                                                                                                  |   195433840722503843
--             2.694751 |     1 | SELECT rideshare.pg_stat_statements_reset()                                                                                                                                                                                                                 |  5423182380465503768
--    2.541805666666667 |     3 | SELECT a.attname, format_type(a.atttypid, a.atttypmod),                                                                                                                                                                                                    +| -2737493898749264857
--                      |       |        pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,                                                                                                                                                                             +| 
--                      |       |        c.collname, col_description(a.attrelid, a.attnum) AS comment,                                                                                                                                                                                       +| 
--                      |       |        attidentity AS identity,                                                                                                                                                                                                                            +| 
--                      |       |        attgenerated as attgenerated                                                                                                                                                                                                                        +| 
--                      |       |   FROM pg_attribute a                                                                                                                                                                                                                                      +| 
--                      |       |   LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum                                                                                                                                                                                  +| 
--                      |       |   LEFT JOIN pg_type t ON a.atttypid = t.oid                                                                                                                                                                                                                +| 
--                      |       |   LEFT JOIN pg_collation c ON a.attcollation = c.oid AND a.attcollation <> t.typcollation                                                                                                                                                                  +| 
--                      |       |  WHERE a.attrelid = $1::regclass                                                                                                                                                                                                                           +| 
--                      |       |    AND a.attnum > $2 AND NOT a.attisdropped                                                                                                                                                                                                                +| 
--                      |       |  ORDER BY a.attnum                                                                                                                                                                                                                                          | 
--   1.4954306666666668 |     3 | SELECT a.attname                                                                                                                                                                                                                                           +|  8949129557926170169
--                      |       |   FROM (                                                                                                                                                                                                                                                   +| 
--                      |       |          SELECT indrelid, indkey, generate_subscripts(indkey, $1) idx                                                                                                                                                                                      +| 
--                      |       |            FROM pg_index                                                                                                                                                                                                                                   +| 
--                      |       |           WHERE indrelid = $2::regclass                                                                                                                                                                                                                    +| 
--                      |       |             AND indisprimary                                                                                                                                                                                                                               +| 
--                      |       |        ) i                                                                                                                                                                                                                                                 +| 
--                      |       |   JOIN pg_attribute a                                                                                                                                                                                                                                      +| 
--                      |       |     ON a.attrelid = i.indrelid                                                                                                                                                                                                                             +| 
--                      |       |    AND a.attnum = i.indkey[i.idx]                                                                                                                                                                                                                          +| 
--                      |       |  ORDER BY i.idx                                                                                                                                                                                                                                             | 
--             1.337104 |     4 | SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype                                                                                                                                                         +| -2714464377604898367
--                      |       | FROM pg_type as t                                                                                                                                                                                                                                          +| 
--                      |       | LEFT JOIN pg_range as r ON oid = rngtypid                                                                                                                                                                                                                  +| 
--                      |       | WHERE                                                                                                                                                                                                                                                      +| 
--                      |       |   t.typname IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $40)                                              | 
--   0.9362363333333334 |     3 | INSERT INTO "trip_requests" ("rider_id", "start_location_id", "end_location_id", "created_at", "updated_at") VALUES ($1, $2, $3, $4, $5) RETURNING "id"                                                                                                     | -6037706505548990453
--   0.9062356666666667 |     3 | UPDATE "users" SET "trips_count" = COALESCE("trips_count", $1) + $2 WHERE "users"."type" = $3 AND "users"."id" = $4                                                                                                                                         |  6762093345777710064
--   0.5740006666666666 |     3 | INSERT INTO "trips" ("trip_request_id", "driver_id", "completed_at", "rating", "created_at", "updated_at") VALUES ($1, $2, $3, $4, $5, $6) RETURNING "id"                                                                                                   | -6232673237571866516
--  0.38527100000000003 |     4 | SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype                                                                                                                                                         +|  6083259529884519889
--                      |       | FROM pg_type as t                                                                                                                                                                                                                                          +| 
--                      |       | LEFT JOIN pg_range as r ON oid = rngtypid                                                                                                                                                                                                                  +| 
--                      |       | WHERE                                                                                                                                                                                                                                                      +| 
--                      |       |   t.typelem IN ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49) | 
-- (10 rows)

-- new day from page 150
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

EXPLAIN SELECT 1;
--                 QUERY PLAN                
-- ------------------------------------------
--  Result  (cost=0.00..0.01 rows=1 width=4)
-- (1 row)

EXPLAIN SELECT 1 FROM users;
--                                            QUERY PLAN                                            
-- -------------------------------------------------------------------------------------------------
--  Index Only Scan using index_users_on_last_name on users  (cost=0.29..408.97 rows=20312 width=4)
-- (1 row)

EXPLAIN (ANALYZE) SELECT 1 FROM users;
--                                                                   QUERY PLAN                                                                   
-- -----------------------------------------------------------------------------------------------------------------------------------------------
--  Index Only Scan using index_users_on_last_name on users  (cost=0.29..408.97 rows=20312 width=4) (actual time=1.344..7.261 rows=20200 loops=1)
--    Heap Fetches: 656
--  Planning Time: 0.170 ms
--  Execution Time: 8.130 ms
-- (4 rows)

EXPLAIN (ANALYZE, BUFFERS) SELECT 1 FROM users;
--                                                                   QUERY PLAN                                                                   
-- -----------------------------------------------------------------------------------------------------------------------------------------------
--  Index Only Scan using index_users_on_last_name on users  (cost=0.29..408.97 rows=20312 width=4) (actual time=0.065..3.122 rows=20200 loops=1)
--    Heap Fetches: 652
--    Buffers: shared hit=612
--  Planning Time: 0.119 ms
--  Execution Time: 6.946 ms
-- (5 rows)

EXPLAIN (FORMAT JSON) SELECT 1 FROM users;
--                    QUERY PLAN                    
-- -------------------------------------------------
--  [                                              +
--    {                                            +
--      "Plan": {                                  +
--        "Node Type": "Index Only Scan",          +
--        "Parallel Aware": false,                 +
--        "Async Capable": false,                  +
--        "Scan Direction": "Forward",             +
--        "Index Name": "index_users_on_last_name",+
--        "Relation Name": "users",                +
--        "Alias": "users",                        +
--        "Startup Cost": 0.29,                    +
--        "Total Cost": 408.97,                    +
--        "Plan Rows": 20312,                      +
--        "Plan Width": 4                          +
--      }                                          +
--    }                                            +
--  ]
-- (1 row)

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) SELECT 1 FROM users;
--                    QUERY PLAN                    
-- -------------------------------------------------
--  [                                              +
--    {                                            +
--      "Plan": {                                  +
--        "Node Type": "Index Only Scan",          +
--        "Parallel Aware": false,                 +
--        "Async Capable": false,                  +
--        "Scan Direction": "Forward",             +
--        "Index Name": "index_users_on_last_name",+
--        "Relation Name": "users",                +
--        "Alias": "users",                        +
--        "Startup Cost": 0.29,                    +
--        "Total Cost": 408.97,                    +
--        "Plan Rows": 20312,                      +
--        "Plan Width": 4,                         +
--        "Actual Startup Time": 0.047,            +
--        "Actual Total Time": 3.175,              +
--        "Actual Rows": 20200,                    +
--        "Actual Loops": 1,                       +
--        "Heap Fetches": 652,                     +
--        "Shared Hit Blocks": 612,                +
--        "Shared Read Blocks": 0,                 +
--        "Shared Dirtied Blocks": 0,              +
--        "Shared Written Blocks": 0,              +
--        "Local Hit Blocks": 0,                   +
--        "Local Read Blocks": 0,                  +
--        "Local Dirtied Blocks": 0,               +
--        "Local Written Blocks": 0,               +
--        "Temp Read Blocks": 0,                   +
--        "Temp Written Blocks": 0                 +
--      },                                         +
-- :

ANALYZE VERBOSE trips;
-- INFO:  analyzing "rideshare.trips"
-- INFO:  "trips": scanned 10 of 10 pages, containing 1009 live rows and 0 dead rows; 1009 rows in sample, 1009 estimated total rows
-- ANALYZE

-- new day from page 153
bundle exec rails_best_practices .
-- Source Code: |==============================================================================================================================================================================================================|
-- /Users/scan/projects/rideshare/app/models/fast_search_result.rb:6 - remove unused methods (FastSearchResult#readonly?)
-- /Users/scan/projects/rideshare/app/models/fast_search_result.rb:10 - remove unused methods (FastSearchResult#refresh)
-- /Users/scan/projects/rideshare/app/models/search_result.rb:6 - remove unused methods (SearchResult#readonly?)

-- Please go to https://rails-bestpractices.com to see more useful Rails Best Practices.

-- Found 3 warnings.


-- new day from page 154
-- set the below in postgresql.conf
log_min_duration_statement = 1000	

-- I needed to restart the postgresql service to apply the changes
brew services restart postgresql@16

psql -U postgres -d rideshare_development
-- SET search_path TO rideshare

-- tail the postgresql.log file in a new terminal
tail -f /opt/homebrew/var/log/postgresql@16.log

-- run the query in psql
SELECT pg_sleep(2);


-- new session
-- needed to Or refresh the global command 
curl -O https://raw.githubusercontent.com/andyatkinson/pg_scripts/main/administration/tail_log.sh
chmod +x tail_log.sh
export DATABASE_URL=postgres://postgres@localhost/rideshare_development
./tail_log.sh


