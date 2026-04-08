-- new day from page 131
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

-- Drivers created in the last 30 days
SELECT *
FROM users
WHERE type = 'Driver'
AND created_at >= (
  NOW() - INTERVAL '30 days'
);

--     id    | first_name | last_name |         email          |  type  |         created_at         |         updated_at         |         password_digest          | trips_count | drivers_license_number | city_id 
-- ----------+------------+-----------+------------------------+--------+----------------------------+----------------------------+----------------------------------+-------------+------------------------+---------
--  10060421 | Jess       | Sully     | jess.sully@example.com | Driver | 2026-03-25 09:00:41.748969 | 2026-03-25 09:00:41.748969 | 9e18a0287aad2be5d1ffaaf6c2cb4886 |             |                        |        
-- (1 row)

-- Time: 2970.578 ms (00:02.971)

-- decided to start with a refresed db so I'd have more data to work with
bin/rails db:reset
bin/rails data_generators:drivers_and_riders
bin/rails data_generators:trips_and_requests



WITH new_drivers AS (
  SELECT *
  FROM users
  WHERE type = 'Driver'
  AND created_at >= (
    NOW() - INTERVAL '30 days'
  )
),
rated_trips AS (
  SELECT *
  FROM trips
  WHERE rating IS NOT NULL
)

-- display their name and average rating
SELECT
  trips.driver_id,
  CONCAT(users.first_name, ' ', users.last_name) AS driver_name,
  ROUND(AVG(trips.rating), 2) AS avg_rating
FROM trips
JOIN users ON trips.driver_id = users.id
JOIN new_drivers ON trips.driver_id = new_drivers.id
JOIN rated_trips ON trips.id = rated_trips.id
GROUP by 1, 2
ORDER BY 3 DESC
LIMIT 10;

--  driver_id |  driver_name  | avg_rating 
-- -----------+---------------+------------
--      20092 | Eddie Hilll   |       5.00
--      20070 | Eric Kovacek  |       5.00
--      20074 | Brendon Brown |       5.00
--      20091 | Raven Kozey   |       5.00
--      20065 | Leslee Hintz  |       5.00
--      20014 | Marshall Fay  |       5.00
--      20061 | Isreal Ryan   |       5.00
--      20059 | Donovan Toy   |       5.00
--      20052 | Magen Kessler |       5.00
--      20063 | Lorna Ortiz   |       4.67
-- (10 rows)

-- Time: 8.297 ms

-- and now in rails
-- but this isn't the same as the query above...
rails console
Trip
  .with(recently_rated: Trip.where.not(rating: nil).where(created_at: 30.days.ago..))
  .from('recently_rated')
  .count

-- This would be the same as the query above...
Trip
  .where.not(rating: nil)
  .joins(:driver)
  .merge(User.where(type: 'Driver', created_at: 30.days.ago..))
  .group('trips.driver_id', 'users.first_name', 'users.last_name')
  .select(
    'trips.driver_id',
    Arel.sql("CONCAT(users.first_name, ' ', users.last_name) AS driver_name"),
    Arel.sql('ROUND(AVG(trips.rating)::numeric, 2) AS avg_rating')
  )
  .order(Arel.sql('avg_rating DESC'))
  .limit(10)

-- Trip Load (5.1ms)  SELECT "trips"."driver_id", CONCAT(users.first_name, ' ', users.last_name) AS driver_name, ROUND(AVG(trips.rating)::numeric, 2) AS avg_rating FROM "trips" INNER JOIN "users" ON "users"."id" = "trips"."driver_id" WHERE "trips"."rating" IS NOT NULL AND "users"."type" = 'Driver' AND "users"."created_at" >= '2026-03-01 07:57:13.792067' GROUP BY "trips"."driver_id", "users"."first_name", "users"."last_name" /* loading for pp */ ORDER BY avg_rating DESC LIMIT 10 /*application='Rideshare'*/
-- => 
-- [#<Trip:0x0000000118d7ca80 driver_id: 20065, driver_name: "Leslee Hintz", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d16190 driver_id: 20070, driver_name: "Eric Kovacek", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d16050 driver_id: 20059, driver_name: "Donovan Toy", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15f10 driver_id: 20052, driver_name: "Magen Kessler", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15dd0 driver_id: 20091, driver_name: "Raven Kozey", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15c90 driver_id: 20061, driver_name: "Isreal Ryan", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15b50 driver_id: 20014, driver_name: "Marshall Fay", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15a10 driver_id: 20092, driver_name: "Eddie Hilll", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d158d0 driver_id: 20074, driver_name: "Brendon Brown", avg_rating: 0.5e1, id: nil>,
--  #<Trip:0x0000000118d15790 driver_id: 20063, driver_name: "Lorna Ortiz", avg_rating: 0.467e1, id: nil>]

-- Or this one, which might be nicer to start from the Driver model
Driver
  .where(created_at: 30.days.ago..)
  .joins(:trips)
  .where.not(trips: { rating: nil })
  .group('users.id', 'users.first_name', 'users.last_name')
  .select(
    'users.id AS driver_id',
    Arel.sql("CONCAT(users.first_name, ' ', users.last_name) AS driver_name"),
    Arel.sql('ROUND(AVG(trips.rating)::numeric, 2) AS avg_rating')
  )
  .order(Arel.sql('avg_rating DESC'))
  .limit(10)

-- SELECT users.id AS driver_id, CONCAT(users.first_name, ' ', users.last_name) AS driver_name, ROUND(AVG(trips.rating)::numeric, 2) AS avg_rating FROM "users" INNER JOIN "trips" ON "trips"."driver_id" = "users"."id" WHERE "users"."type" = 'Driver' AND "users"."created_at" >= '2026-03-01 07:58:03.356130' AND "trips"."rating" IS NOT NULL GROUP BY "users"."id", "users"."first_name", "users"."last_name" /* loading for pp */ ORDER BY avg_rating DESC LIMIT 10 /*application='Rideshare'*/
-- => 
-- [#<Driver:0x00000001192d5658 driver_id: 20059, driver_name: "Donovan Toy", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929f288 driver_id: 20070, driver_name: "Eric Kovacek", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929f148 driver_id: 20091, driver_name: "Raven Kozey", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929f008 driver_id: 20092, driver_name: "Eddie Hilll", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929eec8 driver_id: 20061, driver_name: "Isreal Ryan", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929ed88 driver_id: 20052, driver_name: "Magen Kessler", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929ec48 driver_id: 20065, driver_name: "Leslee Hintz", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929eb08 driver_id: 20074, driver_name: "Brendon Brown", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929e9c8 driver_id: 20014, driver_name: "Marshall Fay", avg_rating: 0.5e1, id: nil>,
--  #<Driver:0x000000011929e888 driver_id: 20063, driver_name: "Lorna Ortiz", avg_rating: 0.467e1, id: nil>]

-- back in psql
DROP VIEW IF EXISTS new_drivers;

CREATE VIEW new_drivers AS
  SELECT * FROM users
  WHERE type = 'Driver'
  AND created_at >= (NOW() - INTERVAL '30 days');

-- NOTICE:  view "new_drivers" does not exist, skipping
-- DROP VIEW
-- Time: 2.962 ms
-- CREATE VIEW
-- Time: 5.375 ms

-- see the views
-- new drivers is the one I just created
\dv
              List of relations
  Schema   |      Name      | Type |  Owner   
-----------+----------------+------+----------
 rideshare | new_drivers    | view | postgres
 rideshare | search_results | view | scan
(2 rows)

-- back in rails console
-- query the search results view
SearchResult.first
--   SearchResult Load (6.7ms)  SELECT "search_results".* FROM "search_results" LIMIT 1 /*application='Rideshare'*/
-- => #<SearchResult:0x0000000118dd79f8 driver_name: "Annalisa Hartmann", avg_rating: 0.3e1, trip_count: 7>

-- new day from page 136
FastSearchResult.first
--   FastSearchResult Load (4.5ms)  SELECT "fast_search_results".* FROM "fast_search_results" LIMIT 1 /*application='Rideshare'*/
-- (rideshare):2:in `<top (required)>': PG::ObjectNotInPrerequisiteState: ERROR:  materialized view "fast_search_results" has not been populated (ActiveRecord::StatementInvalid)
-- HINT:  Use the REFRESH MATERIALIZED VIEW command.

-- /Users/scan/.rbenv/versions/3.2.2/lib/ruby/gems/3.2.0/gems/activerecord-7.2.3/lib/active_record/connection_adapters/postgresql_adapter.rb:899:in `exec_params': ERROR:  materialized view "fast_search_results" has not been populated (PG::ObjectNotInPrerequisiteState)
-- HINT:  Use the REFRESH MATERIALIZED VIEW command.


psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing
SELECT * FROM pg_matviews;
--  schemaname |     matviewname     | matviewowner | tablespace | hasindexes | ispopulated |                         definition                         
-- ------------+---------------------+--------------+------------+------------+-------------+------------------------------------------------------------
--  rideshare  | fast_search_results | scan         |            | t          | f           |  SELECT t.driver_id,                                      +
--             |                     |              |            |            |             |     concat(d.first_name, ' ', d.last_name) AS driver_name,+
--             |                     |              |            |            |             |     avg(t.rating) AS avg_rating,                          +
--             |                     |              |            |            |             |     count(t.rating) AS trip_count                         +
--             |                     |              |            |            |             |    FROM (trips t                                          +
--             |                     |              |            |            |             |      JOIN users d ON ((t.driver_id = d.id)))              +
--             |                     |              |            |            |             |   GROUP BY t.driver_id, d.first_name, d.last_name         +
--             |                     |              |            |            |             |   ORDER BY (count(t.rating)) DESC;
-- (1 row)

-- rails
FastSearchResult.refresh
--    (30.9ms)  REFRESH MATERIALIZED VIEW "fast_search_results"; /*application='Rideshare'*/
-- => #<PG::Result:0x0000000107c94fc0 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>

SearchResult.first
--   SearchResult Load (3.2ms)  SELECT "search_results".* FROM "search_results" LIMIT 1 /*application='Rideshare'*/
-- => #<SearchResult:0x00000001079d6900 driver_name: "Annalisa Hartmann", avg_rating: 0.3e1, trip_count: 7>

-- The fast is, faster...
FastSearchResult.first
--   FastSearchResult Load (2.3ms)  SELECT "fast_search_results".* FROM "fast_search_results" LIMIT 1 /*application='Rideshare'*/
-- => #<FastSearchResult:0x00000001080797f8 driver_id: 20021, driver_name: "Annalisa Hartmann", avg_rating: 0.3e1, trip_count: 7>

FastSearchResult.refresh(concurrently: true)
--    (2.0ms)  SELECT relispopulated FROM pg_class WHERE relname = 'fast_search_results' /*application='Rideshare'*/
--    (35.2ms)  REFRESH MATERIALIZED VIEW CONCURRENTLY "fast_search_results"; /*application='Rideshare'*/
-- => #<PG::Result:0x00000001083902e8 status=PGRES_COMMAND_OK ntuples=0 nfields=0 cmd_tuples=0>


-- from psql
ROM pg_prepared_statements;
--  name | statement | prepare_time | parameter_types | result_types | from_sql | generic_plans | custom_plans 
-- ------+-----------+--------------+-----------------+--------------+----------+---------------+--------------
-- (0 rows)

-- Time: 6.248 ms

-- set to false
config.active_record.query_log_tags_enabled = false
-- restart rails console
-- run some queries
User.first
Trip.first

-- I feel like this should be populated...
-- Might come back to this later
ActiveRecord::Base.connection.execute(
  'SELECT * FROM pg_prepared_statements'
).values
--    (3.4ms)  SELECT * FROM pg_prepared_statements
-- => []

-- new day from page 141
rails console
-- just saying that this is a bit of an odd way to get a driver,
-- but it does ensure that there are trips associated with the driver
driver = Trip.first.driver
driver.trips.count

-- manually reset the counter cache
Driver.reset_counters(driver.id, :trips)
  -- Driver Load (165.9ms)  SELECT "users".* FROM "users" WHERE "users"."type" = 'Driver' AND "users"."id" = 20005 LIMIT 1
  -- Trip Count (4.0ms)  SELECT COUNT(*) FROM "trips" WHERE "trips"."driver_id" = 20005
driver.trips.size
  -- Trip Count (268.1ms)  SELECT COUNT(*) FROM "trips" WHERE "trips"."driver_id" = 20005

TripRequest.find_by_sql("SELECT * FROM trip_requests LIMIT 1")
-- [sql.active_record] 1.136686 SELECT * FROM trip_requests LIMIT 1
--   TripRequest Load (1136.8ms)  SELECT * FROM trip_requests LIMIT 1
-- => [#<TripRequest:0x00000001285f26d8 id: 1, rider_id: 20177, start_location_id: 1, end_location_id: 2, created_at: "2026-03-31 01:49:44.479231000 -0500", updated_at: "2026-03-31 01:49:44.479231000 -0500">]

ActiveRecord::Base.connection.execute("SELECT * FROM trip_requests LIMIT 1")
--    (80.9ms)  SELECT * FROM trip_requests LIMIT 1
-- => #<PG::Result:0x000000010d994608 status=PGRES_TUPLES_OK ntuples=1 nfields=6 cmd_tuples=1>

bin/rails benchmarks:active_record
-- Calculating -------------------------------------
--    (451.9ms)  SELECT * FROM users ORDER BY id LIMIT 1
--   ↳ lib/tasks/benchmarks.rake:9:in `block (4 levels) in <top (required)>'
-- .select_all() single User
--                        613.498k memsize (   116.792k retained)
--                          6.534k objects (   975.000  retained)
--                         50.000  strings (    50.000  retained)
--   User Load (12.9ms)  SELECT "users".* FROM "users" ORDER BY "users"."id" ASC LIMIT 1
--   ↳ lib/tasks/benchmarks.rake:12:in `block (4 levels) in <top (required)>'
--           User.first     1.351M memsize (   253.322k retained)
--                         10.866k objects (     1.640k retained)
--                         50.000  strings (    50.000  retained)

-- Comparison:
-- .select_all() single User:     613498 allocated
--           User.first:    1350989 allocated - 2.20x more


