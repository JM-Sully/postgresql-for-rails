-- create a script to lookup postgres logs
-- download the tail_log.sh script
curl -O https://raw.githubusercontent.com/andyatkinson/pg_scripts/main/administration/tail_log.sh
--   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
--                                  Dload  Upload   Total   Spent    Left  Speed
-- 100   305  100   305    0     0   1492      0 --:--:-- --:--:-- --:--:--  1495

-- make the script executable
chmod +x tail_log.sh

-- test that it exists and is executable
./tail_log.sh
-- SHOW data_directory: /opt/homebrew/var/postgresql@16
-- SELECT pg_current_logfile(): 
-- tail: /opt/homebrew/var/postgresql@16/: Is a directory
-- tail: /opt/homebrew/var/postgresql@16/: Is a directory

-- If your goal is to make it available from anywhere, the next commands would be
sudo mv tail_log.sh /usr/local/bin/tail_log
sudo chmod +x /usr/local/bin/tail_log

-- Run it anywhere with 
tail_log

-- new day from page 120
rails console

-- query to show N+1 queries
Vehicle.all.each do |vehicle|
  vehicle.vehicle_reservations.count
end; nil

--   Vehicle Load (76.8ms)  SELECT "vehicles".* FROM "vehicles" /*application='Rideshare'*/
--   VehicleReservation Count (2.5ms)  SELECT COUNT(*) FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" = 5 /*application='Rideshare'*/
--   VehicleReservation Count (0.3ms)  SELECT COUNT(*) FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" = 6 /*application='Rideshare'*/
--   VehicleReservation Count (0.1ms)  SELECT COUNT(*) FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" = 7 /*application='Rideshare'*/
--   VehicleReservation Count (0.1ms)  SELECT COUNT(*) FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" = 8 /*application='Rideshare'*/
-- => nil

-- using Prosopite
Prosopite.rails_logger = true

Prosopite.scan do
  Vehicle.all.each do |vehicle|
    vehicle.vehicle_reservations.count
  end
end

-- new day from page 122
rails console

Vehicle.preload(:vehicle_reservations).each do |vehicle|
  vehicle.vehicle_reservations.size
end; nil
--   Vehicle Load (110.7ms)  SELECT "vehicles".* FROM "vehicles" /*application='Rideshare'*/
--   VehicleReservation Load (2.6ms)  SELECT "vehicle_reservations".* FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" IN (5, 6, 7, 8) /*application='Rideshare'*/
-- => nil

Vehicle.includes(:vehicle_reservations).each do |vehicle|
  vehicle.vehicle_reservations.size
end; nil
--   Vehicle Load (36.3ms)  SELECT "vehicles".* FROM "vehicles" /*application='Rideshare'*/
--   VehicleReservation Load (2.8ms)  SELECT "vehicle_reservations".* FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" IN (5, 6, 7, 8) /*application='Rideshare'*/
-- => nil

Vehicle.includes(:vehicle_reservations).where(vehicle_reservations: { canceled: false }).size
--   Vehicle Count (11.6ms)  SELECT COUNT(*) FROM (SELECT DISTINCT "vehicles"."id" FROM "vehicles" LEFT OUTER JOIN "vehicle_reservations" ON "vehicle_reservations"."vehicle_id" = "vehicles"."id" WHERE "vehicle_reservations"."canceled" = FALSE) subquery_for_count /*application='Rideshare'*/
-- => 1

Vehicle.includes(:vehicle_reservations).limit(2)
  -- Vehicle Load (3.1ms)  SELECT "vehicles".* FROM "vehicles" /* loading for pp */ LIMIT 2 /*application='Rideshare'*/
  -- VehicleReservation Load (2.4ms)  SELECT "vehicle_reservations".* FROM "vehicle_reservations" WHERE "vehicle_reservations"."vehicle_id" IN (5, 6) /*application='Rideshare'*/

-- new day from page 124
rails console
vehicles = Vehicle.strict_loading.all

vehicles.each do |vehicle|
  vehicle.vehicle_reservations.first.starts_at
end; nil
-- (rideshare):8:in `block in <top (required)>': `Vehicle` is marked for strict_loading. The VehicleReservation association named `:vehicle_reservations` cannot be lazily loaded. (ActiveRecord::StrictLoadingViolationError)
--         from (rideshare):7:in `<top (required)>'

-- eager loading vehicle reservations
vehicles.includes(:vehicle_reservations).each do |vehicle|
  vehicle.vehicle_reservations.first&.starts_at
end; nil

-- start a new console so we're not strict loading
rails console
Vehicle.includes(:vehicle_reservations).pluck('vehicles.name', 'vehicle_reservations.starts_at', 'vehicle_reservations.canceled')
--   Vehicle Pluck (7.3ms)  SELECT "vehicles"."name", "vehicle_reservations"."starts_at", "vehicle_reservations"."canceled" FROM "vehicles" LEFT OUTER JOIN "vehicle_reservations" ON "vehicle_reservations"."vehicle_id" = "vehicles"."id" /*application='Rideshare'*/
-- => 
-- [["Limo", Fri, 20 Mar 2026 14:37:46.642886000 CDT -05:00, false],
--  ["Limo", Fri, 20 Mar 2026 15:37:46.642886000 CDT -05:00, true],
--  ["Limo", Fri, 20 Mar 2026 15:37:46.642886000 CDT -05:00, false],
--  ["Party Bus", nil, nil],
--  ["Food Truck", nil, nil],
--  ["Ice Cream Truck", nil, nil]]

-- do the same query using select
Vehicle.includes(:vehicle_reservations)
  .references(:vehicle_reservations)
  .select(
    "vehicles.name",
    "vehicle_reservations.starts_at",
    "vehicle_reservations.canceled"
  )

Vehicle.eager_load(:vehicle_reservations).select(
  "vehicles.name",
  "vehicle_reservations.starts_at",
  "vehicle_reservations.canceled"
)

-- new day from page 127
psql -U postgres -d rideshare_development

CREATE SEQUENCE temp_users_id_seq INCREMENT 1 START 1;
-- CREATE SEQUENCE
ALTER TABLE temp.users ALTER COLUMN id
SET DEFAULT nextval('temp_users_id_seq');
-- ALTER TABLE

INSERT INTO temp.users (name) VALUES ('Jess') RETURNING id, name;
-- ERROR:  duplicate key value violates unique constraint "users_pkey"
-- DETAIL:  Key (id)=(1) already exists.

SELECT MAX(id) FROM temp.users;
--    max    
-- ----------
--  10000000
-- (1 row)

SELECT setval(
  'public.temp_users_id_seq'::regclass,
  (SELECT MAX(id) FROM temp.users)
);
--   setval  
-- ----------
--  10000000
-- (1 row)


INSERT INTO temp.users (name) VALUES ('Jess') RETURNING id, name;
--     id    | name 
-- ----------+------
--  10000001 | Jess
-- (1 row)

-- INSERT 0 1

INSERT INTO temp.users (name) VALUES ('Jessica') RETURNING id, name;
--     id    |  name   
-- ----------+---------
--  10000002 | Jessica
-- (1 row)

-- INSERT 0 1

INSERT INTO temp.users (name) VALUES ('Judy') RETURNING id;
--     id    
-- ----------
--  10000003
-- (1 row)

-- INSERT 0 1

rails console
driver = Driver.insert_all(
  [
    {
      first_name: 'Jess',
      last_name: 'Sully',
      email: 'jess.sully@example.com',
      password_digest: SecureRandom.hex
    }
  ],
  returning: [:id]
).first

  Driver Insert (8.2ms)  INSERT INTO "users" ("type","first_name","last_name","email","password_digest","created_at","updated_at") VALUES ('Driver', 'Jess', 'Sully', 'jess.sully@example.com', '9e18a0287aad2be5d1ffaaf6c2cb4886', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT  DO NOTHING RETURNING "id" /*application='Rideshare'*/
=> {"id"=>10060421}


-- new day from page 129

-- Find the average number of trips provided by drivers
SELECT ROUND(AVG(trips_count))
FROM rideshare.users
WHERE type = 'Driver';
--  round 
-- -------
--     10
-- (1 row)

-- Find the average number of trips provided by drivers
-- Find drivers who have completed more trips that the average
-- From that filtered list, order drivers by their trip output
SET search_path TO rideshare;

SELECT
  users.id AS driver_id,
  trips_count
FROM users
WHERE type = 'Driver'
AND trips_count > (SELECT ROUND(AVG(trips_count)) FROM users WHERE type = 'Driver')
ORDER BY trips_count
DESC LIMIT 5;

--  driver_id | trips_count 
-- -----------+-------------
--      60266 |          20
--      40096 |          19
--      60230 |          19
--      60271 |          18
--      60213 |          16
-- (5 rows)

rails console
Driver.where('trips_count > (:avg)',
              avg: Driver.select('ROUND(AVG(trips_count))'))
      .order(trips_count: :desc)
      .limit(5)

-- Driver Load (5574.4ms)  SELECT "users".* FROM "users" WHERE "users"."type" = 'Driver' 
-- AND (trips_count > (SELECT ROUND(AVG(trips_count)) 
-- FROM "users" 
-- WHERE "users"."type" = 'Driver'))
-- ORDER BY "users"."trips_count" 
-- DESC LIMIT 5 /*application='Rideshare'*/

avg_trips = Driver.select("ROUND(AVG(trips_count))");nil

Driver.where("trips_count > (?)", avg_trips)
      .order(trips_count: :desc)
      .limit(5)

