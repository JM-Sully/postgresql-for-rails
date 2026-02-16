-- example users table
id  | name
----+-------
  1 | Dalma
  2 | Jess

-- example orders table
id  | user_id | total
----+---------+-------
  1 |       1 | 25.00
  2 |       1 | 40.00
  3 |       2 | 15.00
  4 |      99 | 30.00

-- new day from page 69
bin/rails g migration AddCityStateUniqueness

-- add index to city and state columns
-- db/migrate/20260216094818_add_city_state_uniqueness.rb

bin/rails db:migrate
-- Setting role for development
--    (68.4ms)  SET ROLE owner
--   ↳ lib/tasks/migration_hooks.rake:11:in `block (2 levels) in <top (required)>'
--    (0.3ms)  SELECT pg_try_advisory_lock(5537362570877065845)
--   ActiveRecord::SchemaMigration Load (2.3ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
--   ActiveRecord::InternalMetadata Load (3.6ms)  SELECT * FROM "ar_internal_metadata" WHERE "ar_internal_metadata"."key" = $1 ORDER BY "ar_internal_metadata"."key" ASC LIMIT 1  [[nil, "environment"]]
-- Migrating to AddCityStateUniqueness (20260216094818)
-- == 20260216094818 AddCityStateUniqueness: migrating ===========================
--    (2.1ms)  SHOW server_version_num
--    (0.3ms)  SET statement_timeout TO 3600000
--    (0.2ms)  SET lock_timeout TO 10000
-- -- add_index(:locations, [:city, :state], {:unique=>true, :algorithm=>:concurrently})
--    (9.2ms)  CREATE UNIQUE INDEX CONCURRENTLY "index_locations_on_city_and_state" ON "locations" ("city", "state")
--    -> 0.0123s
-- == 20260216094818 AddCityStateUniqueness: migrated (0.0172s) ==================

--   ActiveRecord::SchemaMigration Create (0.3ms)  INSERT INTO "schema_migrations" ("version") VALUES ('20260216094818') RETURNING "version"
--    (0.6ms)  SELECT pg_advisory_unlock(5537362570877065845)
--   ActiveRecord::SchemaMigration Load (0.1ms)  SELECT "schema_migrations"."version" FROM "schema_migrations" ORDER BY "schema_migrations"."version" ASC
-- Loading application environment...
-- Loading code in search of Active Record models...
-- Generating Entity-Relationship Diagram for 12 models...
-- Done! Saved diagram to ./erd.pdf


-- new day from page 71

DELETE FROM users
WHERE id NOT IN (
  SELECT MIN(id)
  FROM users
  GROUP BY first_name, email
);

-- example users table
id  | first_name | email                  | updated_at
----+------------+------------------------+---------------
  1 | Dalma      | dalma@example.com      | 2026-01-01
  2 | Jess       | jess@example.com       | 2026-01-01
  3 | Jess       | jess@example.com       | 2026-02-17
  4 | Jess       |                        | 2026-02-02

-- example users table with row number
id  | first_name | email                  | updated_at     | row_number
----+------------+------------------------+----------------+----------
  1 | Dalma      | dalma@example.com      | 2026-01-01     | 1
  2 | Jess       | jess@example.com       | 2026-01-01     | 3
  3 | Jess       | jess@example.com       | 2026-02-17     | 1
  4 | Jess       | jess@example.com       | 2026-02-02     | 2


WITH duplicates AS (
  SELECT id, ROW_NUMBER() OVER(
    PARTITION BY first_name, email
    ORDER BY updated_at DESC
  ) AS rownum
  FROM users
)
DELETE FROM users
USING duplicates
WHERE users.id = duplicates.id AND duplicates.rownum > 1;

psql -U postgres -d rideshare_development
\timing 
ALTER TABLE ONLY rideshare.trips
ADD CONSTRAINT fk_trips_trip_request
FOREIGN KEY (trip_request_id)
REFERENCES rideshare.trip_requests(id);
ERROR:  relation "trips" does not exist
-- I seem to have no records...
bin/rails db:migrate

-- generate 20,000 records
bin/rails data_generators:generate_all

-- populate 10,000,000 records in the users table
export DATABASE_URL='postgres://owner:@localhost:5432/rideshare_development'
sh db/scripts/bulk_load.sh

psql -U postgres -d rideshare_development
-- back on track!
-- actually, the issue is that I need to do rideshare.trips, not trips
ALTER TABLE ONLY rideshare.trips
ADD CONSTRAINT fk_trips_trip_request
FOREIGN KEY (trip_request_id)
REFERENCES rideshare.trip_requests(id);

-- do this so I don't have to type rideshare.trips every time
SET search_path TO rideshare;

-- create a new constraint on the trips table
ALTER TABLE ONLY trips
ADD CONSTRAINT fk_trips_trip_request_2
FOREIGN KEY (trip_request_id)
REFERENCES trip_requests(id);

-- check the constraints
\d rideshare.trips
\d rideshare.trip_requests

-- remove duplicates
ALTER TABLE trips DROP CONSTRAINT fk_trips_trip_request;
ALTER TABLE trips DROP CONSTRAINT fk_trips_trip_request_2;

-- new day from page 74
-- create a check constraint on the vehicle_reservations using migrations
bin/rails g migration AddCheckConstrainToVehicleReservations
bin/rails db:migrate

bin/rails g migration ValidateCheckConstrainOnVehicleReservations
bin/rails db:migrat

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\d rideshare.vehicle_reservations

-- create a check constraint on the vehicle_reservations using SQL in psql
ALTER TABLE vehicle_reservations
ADD CONSTRAINT vehicle_reservation_minimum_length
CHECK (ends_at >= (starts_at + INTERVAL '30 minutes'));

-- create a check constraint on the users using SQL in psql
ALTER TABLE users
ADD CONSTRAINT users_email_present
CHECK (email IS NOT NULL)
NOT VALID;

-- validate the check constraint
ALTER TABLE users
VALIDATE CONSTRAINT users_email_present;

-- add regular NOT NULL constraint
ALTER TABLE users
ALTER COLUMN email SET NOT NULL;

-- remove the check constraint
ALTER TABLE users
DROP CONSTRAINT users_email_present;

-- new day from page 77
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\d rideshare.users

-- create a deferred unique constraint on the user email using SQL in psql
ALTER TABLE users
ADD CONSTRAINT users_email_unique
UNIQUE (email)
DEFERRABLE INITIALLY DEFERRED;

-- example transaction using the deferred unique constraint
-- start transaction
BEGIN;

-- Insert the potentially duplicate email
INSERT INTO users (first_name, email)
VALUES ('Jess', 'jess@example.com');

-- If more than one row has that email,
-- modify the newest one (highest id) to use its id in the email
WITH duplicates AS (
  SELECT id, COUNT(*) OVER () AS cnt
  FROM users
  WHERE email = 'jess@example.com'
),
newest_duplicate AS (
  SELECT id, cnt FROM duplicates ORDER BY id DESC LIMIT 1
)
UPDATE users
SET email = 'jess+' || users.id::text || '@example.com'
FROM newest_duplicate
WHERE users.id = newest_duplicate.id AND newest_duplicate.cnt > 1;

-- commit transaction
COMMIT;
