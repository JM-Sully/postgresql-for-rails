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

-- new day from page 78
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- Remove existing constraint in Rideshare, we'll
-- add it back to practice (need double quotes)
ALTER TABLE vehicle_reservations
DROP CONSTRAINT IF EXISTS "non_overlapping_vehicle_reservation";

-- enable the extension
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- create the exclusion constraint
-- using a GIST index
ALTER TABLE vehicle_reservations
ADD CONSTRAINT non_overlapping_vehicle_reservation
EXCLUDE USING GIST (
  vehicle_id WITH =,
  TSTZRANGE(starts_at, ends_at) WITH &&
)
WHERE (not canceled);

-- list exclusion constraints
SELECT conname from pg_constraint where contype = 'x';

-- existing reservation
vehicle_id = 7
starts_at = 10:00
ends_at = 11:00

-- non-conflicting reservation
vehicle_id = 7
starts_at = 11:00
ends_at = 12:00

-- conflicting reservation
vehicle_id = 7
starts_at = 10:30
ends_at = 11:30

-- new day from page 83
psql -U postgres -d rideshare_development

-- add the citext extension
-- it provides a case-insensitive character type we'll use as a column type
CREATE EXTENSION IF NOT EXISTS citext;

-- show the extensions
\dx

-- create a new schema for testing out the citext extension
CREATE SCHEMA IF NOT EXISTS temp;

-- Create a new table in the temp schema, with a case-insensitive email column
CREATE TABLE IF NOT EXISTS temp.users (email CITEXT);

-- Insert a new row into the users table
INSERT INTO temp.users (email) VALUES ('jess@example.com');

-- Query my new row with different case variations
SELECT * FROM temp.users WHERE email = 'Jess@example.com';

-- Add a unique constraint on the email column
ALTER TABLE temp.users
ADD CONSTRAINT users_email_unique
UNIQUE (email);

-- Try to insert a new row with the same email
INSERT INTO temp.users (email) VALUES ('JESS@example.com');
-- ERROR:  duplicate key value violates unique constraint "users_email_unique"
-- DETAIL:  Key (email)=(JESS@example.com) already exists.

-- How you would do this in rails with a migration
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    enable_extension "citext"

    create_table :users do |t|
      t.citext :email, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

-- new day from page 85

psql -U postgres -d rideshare_development

-- find my temp table
SELECT schemaname, tablename
FROM pg_tables
WHERE tablename LIKE '%users%';

-- see the existing users table
\d temp.users

-- Add a virtual column to store the downcased email
ALTER TABLE temp.users
ADD COLUMN email_downcased TEXT GENERATED ALWAYS AS (LOWER(email)) STORED;

create_table :users do |t|
  t.string :email, null: false
  t.virtual :email_downcased,
    type: :string,
    as: "LOWER(email)",
    stored: true
  end
end

-- uses
user = User.create!(email: "Jess@example.com")
user.email_downcased
-- => "jess@example.com"

user.email_downcased = "something"
-- This will raise an error at the DB level

-- new day from page 88
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

SELECT
  n.nspname AS enum_schema,
  t.typname AS enum_name,
  e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace;
--  enum_schema |   enum_name    | enum_value
-- -------------+----------------+------------
--  rideshare   | vehicle_status | published
--  rideshare   | vehicle_status | draft
-- (2 rows)

-- new day from page 89
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- create a domain for the vehicle status
CREATE DOMAIN vehicle_status AS TEXT
CONSTRAINT vehicle_status_check CHECK (
  VALUE IN ('draft', 'published')
);
-- ERROR:  type "vehicle_status" already exists

-- create a domain for the vehicle status, with a different name
CREATE DOMAIN vehicle_status_2 AS TEXT
CONSTRAINT vehicle_status_check CHECK (
  VALUE IN ('draft', 'published')
);

-- check the domains
\dD
                                                          -- List of domains
--   Schema   |       Name       | Type | Collation | Nullable | Default |                             Check
-- -----------+------------------+------+-----------+----------+---------+---------------------------------------------------------------
--  rideshare | vehicle_status_2 | text |           |          |         | CHECK (VALUE = ANY (ARRAY['draft'::text, 'published'::text]))
-- (1 row)

-- see what the vehicle table looks like
\d vehicles
-- no change

-- drop the column so we can reconfigure it
ALTER TABLE vehicles DROP COLUMN status;

-- add the column back with the domain called vehicle_status_2
ALTER TABLE vehicles
ADD COLUMN status vehicle_status_2
NOT NULL
DEFAULT 'draft';

-- new day from page 90

-- run the active record doctor gem
bin/rails active_record_doctor
-- trip_requests.end_location_id is a foreign key of type integer and references locations.id of type bigint - foreign keys should be of the same type as the referenced column
-- trip_requests.rider_id is a foreign key of type integer and references users.id of type bigint - foreign keys should be of the same type as the referenced column
-- trip_requests.start_location_id is a foreign key of type integer and references locations.id of type bigint - foreign keys should be of the same type as the referenced column
-- trips.driver_id is a foreign key of type integer and references users.id of type bigint - foreign keys should be of the same type as the referenced column
-- vehicle_reservations.trip_request_id is a foreign key of type integer and references trip_requests.id of type bigint - foreign keys should be of the same type as the referenced column
-- vehicle_reservations.vehicle_id is a foreign key of type integer and references vehicles.id of type bigint - foreign keys should be of the same type as the referenced column
-- use `dependent: :delete_all` or similar on Vehicle.vehicle_reservations - associated model VehicleReservation has no callbacks and can be deleted in bulk
-- add an index on trip_positions(trip_id) - foreign keys are often used in database lookups and should be indexed for performance reasons
-- add an index on vehicle_reservations(trip_request_id) - foreign keys are often used in database lookups and should be indexed for performance reasons
-- the schema limits locations.state to 2 characters but there's no length validator on Location.state - remove the database limit or add the validator
-- add a unique index on users(drivers_license_number) - validating uniqueness in Driver without an index can lead to duplicates
-- add a unique index on trips(trip_request_id) - using `has_one` in TripRequest without an index can lead to duplicates
-- add a `presence` validator to VehicleReservation.canceled - it's NOT NULL but lacks a validator

-- run the database consistency gem
bundle exec database_consistency
-- No configurations were provided
-- UniqueIndexChecker fail Location index_locations_on_city_and_state index is unique in the database but do not have uniqueness validator
-- UniqueIndexChecker fail FastSearchResult index_fast_search_results_on_driver_id index is unique in the database but do not have uniqueness validator
-- ForeignKeyTypeChecker fail VehicleReservation vehicle
-- ForeignKeyTypeChecker fail VehicleReservation trip_request
-- ForeignKeyTypeChecker fail Vehicle vehicle_reservations
-- ForeignKeyTypeChecker fail TripRequest rider
-- ForeignKeyTypeChecker fail TripRequest start_location
-- ForeignKeyTypeChecker fail TripRequest end_location
-- MissingIndexChecker fail TripRequest trip associated model should have proper unique index in the database
-- MissingIndexChecker fail TripRequest vehicle_reservations associated model should have proper index in the database
-- ForeignKeyTypeChecker fail TripRequest vehicle_reservations
-- ForeignKeyTypeChecker fail Trip driver
-- MissingIndexChecker fail Trip trip_positions associated model should have proper index in the database
-- ForeignKeyTypeChecker fail Rider trip_requests
-- ForeignKeyTypeChecker fail Driver trips
-- EnumTypeChecker fail Vehicle status enum has String types but column has text type