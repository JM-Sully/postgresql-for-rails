-- run the code in lib/tasks/fake_data_generator.rake
bin/rails data_generators:drivers

-- from the second half of the operation
--   ↳ lib/tasks/fake_data_generator.rake:28:in `block (4 levels) in <top (required)>'
-- Created 10000 drivers.
-- VACUUM (ANALYZE) users
-- [sql.active_record] 10.010581 VACUUM (ANALYZE) users
--    (10011.3ms)  VACUUM (ANALYZE) users
--   ↳ lib/tasks/fake_data_generator.rake:33:in `block (2 levels) in <top (required)>'
--   3.157699   0.103123   3.260822 (  3.945598)

-- new day from Handling Update Violations in Active Record, p263

rails c
attributes = {
  name: 'Surf bus'
}

-- upsert a new vehicle, specifying the unique_by constraint, and what will be returned
Vehicle.upsert(
  attributes,
  returning: [:id],
  unique_by: [:name]
)

Vehicle Insert (2.1ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") 
  VALUES ('Surf bus', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) 
  ON CONFLICT ("name") DO NOTHING RETURNING "id"
=> 
#<ActiveRecord::Result:0x000000010d75fab8
 @column_indexes=nil,
 @column_types=
  {0=>
    #<ActiveModel::Type::Integer:0x000000010d6974a0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>,
   "id"=>
    #<ActiveModel::Type::Integer:0x000000010d6974a0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>},
 @columns=["id"],
 @hash_rows=nil,
 @rows=[[1]]>

-- it works, which makes sense, since this is my first surfbus

-- try adding it again, shouldn't work, but not sure what the DO NOTHING will do 
Vehicle.upsert(
  attributes,
  returning: [:id],
  unique_by: [:name]
)
  Vehicle Insert (1.9ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") VALUES ('Surf bus', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT ("name") DO NOTHING RETURNING "id"
=> 
#<ActiveRecord::Result:0x000000010da71d28
 @column_indexes=nil,
 @column_types=
  {0=>
    #<ActiveModel::Type::Integer:0x000000010d6974a0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>,
   "id"=>
    #<ActiveModel::Type::Integer:0x000000010d6974a0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>},
 @columns=["id"],
 @hash_rows=nil,
 @rows=[]>

-- empty array, which makes sense, since the DO NOTHING will not insert the record

-- trying using .on_duplicate
Vehicle.upsert(
  attributes,
  returning: [:id],
  unique_by: [:name],
  on_duplicate: Arel.sql("name = 'New Surf bus'")
)
-- that worked! Actually, that updated the OG record, but I thought it would create a new one!! TIL
  Vehicle Upsert (5.3ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") VALUES ('Surf bus', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT ("name") DO UPDATE SET name = 'New Surf bus' RETURNING "id"
=> 
#<ActiveRecord::Result:0x000000010acd5338
 @column_indexes=nil,
 @column_types=
  {0=>
    #<ActiveModel::Type::Integer:0x000000010e05f5f0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>,
   "id"=>
    #<ActiveModel::Type::Integer:0x000000010e05f5f0
     @limit=8,
     @precision=nil,
     @range=-9223372036854775808...9223372036854775808,
     @scale=nil>},
 @columns=["id"],
 @hash_rows=nil,
 @rows=[[1]]>

og_surf_bus = Vehicle.find_by name: 'Surf bus'
  Vehicle Load (5.0ms)  SELECT "vehicles".* FROM "vehicles" WHERE "vehicles"."name" = 'Surf bus' LIMIT 1
=> nil

surf_bus = Vehicle.find_by name: 'New Surf bus'
  Vehicle Load (4.0ms)  SELECT "vehicles".* FROM "vehicles" WHERE "vehicles"."name" = 'New Surf bus' LIMIT 1
=> 
#<Vehicle:0x000000010e013560

surf_bus.updated_at
-- that is a very weird timezone for me... but fine.
Tue, 06 Oct 2026 01:43:39.474062000 CDT -05:00

-- option for upsert_all: https://api.rubyonrails.org/v7.0/classes/ActiveRecord/Persistence/ClassMethods.html#method-i-upsert



-- trying using .update_only
-- set values for name (there will be conflict on name) and status
attributes = {
  name: 'New Surf bus',
  status: 'published'
}

-- vehicle currently has status: 'draft'
Vehicle.last
  Vehicle Load (16.6ms)  SELECT "vehicles".* FROM "vehicles" ORDER BY "vehicles"."id" DESC LIMIT 1
=> #<Vehicle:0x000000010c387220 id: 1, name: "New Surf bus", created_at: "2026-10-06 01:43:39.474062000 -0500", updated_at: "2026-10-06 01:43:39.474062000 -0500", status: "draft">

-- upsert the vehicle, updating only the status
Vehicle.upsert(
  attributes,
  returning: [:id],
  unique_by: [:name],
  update_only: [:status]
)
  Vehicle Upsert (7.2ms)  INSERT INTO "vehicles" ("name","status","created_at","updated_at") VALUES ('New Surf bus', 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT ("name") DO UPDATE SET updated_at=(CASE WHEN ("vehicles"."status" IS NOT DISTINCT FROM excluded."status") THEN "vehicles".updated_at ELSE CURRENT_TIMESTAMP END),"status"=excluded."status" RETURNING "id"
=> 
#<ActiveRecord::Result:0x000000010b9cd040
 @column_indexes=nil,
 @column_types=
  {0=>#<ActiveModel::Type::Integer:0x000000010c9807d0 @limit=8, @precision=nil, @range=-9223372036854775808...9223372036854775808, @scale=nil>,
   "id"=>#<ActiveModel::Type::Integer:0x000000010c9807d0 @limit=8, @precision=nil, @range=-9223372036854775808...9223372036854775808, @scale=nil>},
 @columns=["id"],
 @hash_rows=nil,
 @rows=[[1]]>


-- vehicle now has status: 'published'
Vehicle.last
  Vehicle Load (0.4ms)  SELECT "vehicles".* FROM "vehicles" ORDER BY "vehicles"."id" DESC LIMIT 1
=> #<Vehicle:0x000000010bd218e0 id: 1, name: "New Surf bus", created_at: "2026-10-06 01:43:39.474062000 -0500", updated_at: "2026-10-07 01:30:09.214540000 -0500", status: "published">

-- Handling Conflicts with ON CONFLICT
psql
CREATE SCHEMA IF NOT EXISTS temp;
NOTICE:  schema "temp" already exists, skipping
CREATE SCHEMA

CREATE TABLE temp.people (id BIGINT PRIMARY KEY, name TEXT);
CREATE TABLE
INSERT INTO temp.people (id, name) VALUES (1, 'Jess');
INSERT 0 1
INSERT INTO temp.people (id, name) VALUES (2, 'Dalma');
INSERT 0 1

-- this will fail, since the id is already taken
INSERT INTO temp.people (id, name) VALUES (1, 'Esti');
ERROR:  duplicate key value violates unique constraint "people_pkey"
DETAIL:  Key (id)=(1) already exists.

-- do nothing if there is a conflict
INSERT INTO temp.people (id, name)
VALUES (2, 'Nuria')
ON CONFLICT (id) DO NOTHING;
-- no rows were modified, since the id is already taken
INSERT 0 0

-- use the EXCLUDED.name to update the name
INSERT INTO temp.people (id, name)
VALUES (2, 'Nuria')
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name;
-- Normally the second value is the number of rows inserted, in this case, it is the number of rows updated
INSERT 0 1

-- new with activerecord-import gem, p267
rails c

-- import from hashes
vehicles = [
  {name: 'Timmy', status: 'draft'},
  {name: 'Ambassador', status: 'draft'},
]
-- => [{:name=>"Timmy", :status=>"draft"}, {:name=>"Ambassador", :status=>"draft"}]

Vehicle.import(vehicles, validate: false)
  Vehicle Create Many (56.5ms)  INSERT INTO "vehicles" ("name","status","created_at","updated_at") VALUES ('Timmy','draft','2026-10-12 07:54:34.169698','2026-10-12 07:54:34.169698'),('Ambassador','draft','2026-10-12 07:54:34.169698','2026-10-12 07:54:34.169698') RETURNING "id"
=> #<struct ActiveRecord::Import::Result failed_instances=[], num_inserts=1, ids=[5, 6], results=[]>

-- import from object instances
vehicles = [
  Vehicle.new(name: 'Copper Rocket', status: 'draft'),
  Vehicle.new(name: 'Amber', status: 'draft'),
]
-- [#<Vehicle:0x000000010b5e8c68 id: nil, name: "Copper Rocket", created_at: nil, updated_at: nil, status: "draft">,
--  #<Vehicle:0x000000010b926f60 id: nil, name: "Amber", created_at: nil, updated_at: nil, status: "draft">]

Vehicle.import(vehicles, validate: true)
  Vehicle Create Many (2.5ms)  INSERT INTO "vehicles" ("id","name","created_at","updated_at","status") VALUES (nextval('rideshare.vehicles_id_seq'),'Copper Rocket','2026-10-12 07:57:03.668842','2026-10-12 07:57:03.668842','draft'),(nextval('rideshare.vehicles_id_seq'),'Amber','2026-10-12 07:57:03.668842','2026-10-12 07:57:03.668842','draft') RETURNING "id"
=> #<struct ActiveRecord::Import::Result failed_instances=[], num_inserts=1, ids=[7, 8], results=[]>

-- activerecord callbacks are not called with this approach!

-- create a bunch of vehicles
vehicles = [
  Vehicle.new(name: 'Super Skoda', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Top Transporter', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Moody Motorcycle', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Dashing Dune Buggy', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Fast Ferret', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Rapid Rover', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Swift Safari', status: VehicleStatus::DRAFT),
  Vehicle.new(name: 'Clever Canoe', status: VehicleStatus::DRAFT)
]
-- [#<Vehicle:0x000000010bf0fa08 id: nil, name: "Super Skoda", created_at: nil, updated_at: nil, status: "draft">,
-- ...

columns = [:name]
-- [:name]

-- batch size of 3, which should generate 3 SQL statements
Vehicle.import(columns, vehicles, validate: false, batch_size: 3)

  Vehicle Create Many (3.1ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") VALUES ('Super Skoda','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769'),('Top Transporter','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769'),('Moody Motorcycle','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769') RETURNING "id"
  Vehicle Create Many (0.5ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") VALUES ('Dashing Dune Buggy','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769'),('Fast Ferret','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769'),('Rapid Rover','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769') RETURNING "id"
  Vehicle Create Many (0.5ms)  INSERT INTO "vehicles" ("name","created_at","updated_at") VALUES ('Swift Safari','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769'),('Clever Canoe','2026-10-12 08:02:36.813769','2026-10-12 08:02:36.813769') RETURNING "id"
=> #<struct ActiveRecord::Import::Result failed_instances=[], num_inserts=3, ids=[9, 10, 11, 12, 13, 14, 15, 16], results=[]>
rideshare(dev)> 

-- another tradeoff is that the counter cache columns aren't updated, so you need to update them manually

-- new day from p268, Performing SQL Multirow Operations
bin/rails dbconsole

CREATE SCHEMA IF NOT EXISTS temp;
-- CREATE SCHEMA

create table temp.list_items (
  id SERIAL PRIMARY KEY,
  list_id INTEGER,
  position INTEGER,
  CONSTRAINT unique_pos UNIQUE (position)
);
-- CREATE TABLE

\d temp.list_items
                                 Table "temp.list_items"
  Column  |  Type   | Collation | Nullable |                   Default                   
----------+---------+-----------+----------+---------------------------------------------
 id       | integer |           | not null | nextval('temp.list_items_id_seq'::regclass)
 list_id  | integer |           |          | 
 position | integer |           |          | 
Indexes:
    "list_items_pkey" PRIMARY KEY, btree (id)
    "unique_pos" UNIQUE CONSTRAINT, btree ("position")

-- add data
-- GENERATE_SERIES(1, 10, 1) builds the integers from 1 through 10, stepping by 1. 
INSERT INTO temp.list_items (list_id, position)
SELECT 1, GENERATE_SERIES(1, 10, 1);
-- INSERT 0 10

SELECT * FROM temp.list_items;
 id | list_id | position 
----+---------+----------
  1 |       1 |        1
  2 |       1 |        2
  3 |       1 |        3
  4 |       1 |        4
  5 |       1 |        5
  6 |       1 |        6
  7 |       1 |        7
  8 |       1 |        8
  9 |       1 |        9
 10 |       1 |       10
(10 rows)

-- if I try to run the same generate again, it should fail because of the unique constraint on position
INSERT INTO temp.list_items (list_id, position)
SELECT 1, GENERATE_SERIES(1, 10, 1);
-- ERROR:  duplicate key value violates unique constraint "unique_pos"
-- DETAIL:  Key ("position")=(1) already exists.

-- cool, as expected.

-- do three moves to swap the positions between records 1 and 2
BEGIN;
UPDATE temp.list_items SET position = -1 WHERE id = 1;
UPDATE temp.list_items SET position = 1 WHERE id = 2;
UPDATE temp.list_items SET position = 2 WHERE id = 1;
END;

-- I wonder if they are default sorted by updated_at?
-- But the positions have successfully swapped
SELECT * FROM temp.list_items;
 id | list_id | position 
----+---------+----------
  3 |       1 |        3
  4 |       1 |        4
  5 |       1 |        5
  6 |       1 |        6
  7 |       1 |        7
  8 |       1 |        8
  9 |       1 |        9
 10 |       1 |       10
  2 |       1 |        1
  1 |       1 |        2
(10 rows)

-- unique constraints support deferred enforcement.
BEGIN;
SET CONSTRAINTS temp.unique_pos DEFERRED;
-- ERROR:  constraint "unique_pos" is not deferrable
ROLLBACK;

-- drop the constraint, the create it again with deferrable
ALTER TABLE temp.list_items
DROP CONSTRAINT unique_pos;
-- ALTER TABLE

ALTER TABLE temp.list_items
ADD CONSTRAINT unique_pos
UNIQUE (position) DEFERRABLE;
-- ALTER TABLE

\d temp.list_items
                                 Table "temp.list_items"
  Column  |  Type   | Collation | Nullable |                   Default                   
----------+---------+-----------+----------+---------------------------------------------
 id       | integer |           | not null | nextval('temp.list_items_id_seq'::regclass)
 list_id  | integer |           |          | 
 position | integer |           |          | 
Indexes:
    "list_items_pkey" PRIMARY KEY, btree (id)
    "unique_pos" UNIQUE CONSTRAINT, btree ("position") DEFERRABLE
-- it's now showing as deferrable

-- set it back to OG
BEGIN;
UPDATE temp.list_items SET position = -1 WHERE id = 2;
UPDATE temp.list_items SET position = 1 WHERE id = 1;
UPDATE temp.list_items SET position = 2 WHERE id = 2;
END;

SELECT * FROM temp.list_items;
 id | list_id | position 
----+---------+----------
  3 |       1 |        3
  4 |       1 |        4
  5 |       1 |        5
  6 |       1 |        6
  7 |       1 |        7
  8 |       1 |        8
  9 |       1 |        9
 10 |       1 |       10
  1 |       1 |        1
  2 |       1 |        2
(10 rows)

-- try to do a swap in one transaction, using deferred
BEGIN;
SET CONSTRAINTS temp.unique_pos DEFERRED;
UPDATE temp.list_items AS li
SET 
  position = li2.position
FROM (VALUES
  (2, 1),
  (1, 2)
) AS li2(id, position)
WHERE li2.id = li.id;
COMMIT;
-- BEGIN
-- SET CONSTRAINTS
-- UPDATE 2
-- COMMIT

-- works! Though more confusing that the three moves approach
-- but more efficient, since it's a single transaction.
-- SELECT * FROM temp.list_items;
 id | list_id | position 
----+---------+----------
  3 |       1 |        3
  4 |       1 |        4
  5 |       1 |        5
  6 |       1 |        6
  7 |       1 |        7
  8 |       1 |        8
  9 |       1 |        9
 10 |       1 |       10
  1 |       1 |        2
  2 |       1 |        1
(10 rows)

-- new day from page 271, Upserts with SQL MERGE
psql
SELECT * FROM temp.people;
 id | name  
----+-------
  1 | Jess
  2 | Nuria
(2 rows)

MERGE INTO temp.people p
-- VALUES data is aliased as poeple_data
  USING ( VALUES(2, 'Jade') ) people_data
  ON people_data.column1 = p.id
WHEN NOT MATCHED THEN
  INSERT VALUES(people_data.column1, people_data.column2)
WHEN MATCHED THEN
  UPDATE SET name = people_data.column2;

-- there is a record with id 2, so it will be updated
MERGE 1
SELECT * FROM temp.people;
 id | name 
----+------
  1 | Jess
  2 | Jade
(2 rows)

-- use an id that doesn't exist
MERGE INTO temp.people p
-- VALUES data is aliased as poeple_data
  USING ( VALUES(3, 'Stephanie') ) people_data
  ON people_data.column1 = p.id
WHEN NOT MATCHED THEN
  INSERT VALUES(people_data.column1, people_data.column2)
WHEN MATCHED THEN
  UPDATE SET name = people_data.column2;

-- there is no record with id 3, so it will be inserted
MERGE 1
SELECT * FROM temp.people;
 id | name  
----+-------
  1 | Jess
  2 | Jade
  3 | Stephanie
(3 rows)

-- working with pg_dump and pg_restore
-- run the below in the terminal
pg_dump \
  --username postgres \
  --format=c \
  --host localhost \
  --table rideshare.users \
  rideshare_development > users_table.dump

-- fun fact, if you omit the '\' on the first line it will output the command to the terminal,
-- and won't add anything to the dump file (this took about 3 mins)


-- restore the row data from the file
bin/rails dbconsole
CREATE DATABASE temp_restore;
-- CREATE DATABASE
\c temp_restore
-- You are now connected to database "temp_restore" as user "scan".
CREATE SCHEMA rideshare;
-- CREATE SCHEMA

-- back in the terminal
pg_restore \
  --username postgres \
  --dbname temp_restore \
  users_table.dump

-- connext to the new database
psql --dbname temp_restore

SELECT COUNT(*) FROM rideshare.users;
  count   
----------
 10004875
(1 row)

-- shows tables in my temp_restore search_path
\dt *.*
                          List of relations
       Schema       |           Name           |    Type     | Owner 
--------------------+--------------------------+-------------+-------
 rideshare          | users                    | table       | scan

--  there were a lot of pg_ ones, but not as important to me right now


-- shows tables in my rideshare_development=# search_path
\dt *.*
                           List of relations
       Schema       |           Name           |    Type     |  Owner   
--------------------+--------------------------+-------------+----------
 cron               | job                      | table       | postgres
 cron               | job_run_details          | table       | postgres
 hint_plan          | hints                    | table       | postgres
 rideshare          | ar_internal_metadata     | table       | scan
 rideshare          | locations                | table       | scan
 rideshare          | schema_migrations        | table       | scan
 rideshare          | trip_positions           | table       | scan
 rideshare          | trip_requests            | table       | scan
 rideshare          | trips                    | table       | scan
 rideshare          | users                    | table       | scan
 rideshare          | vehicle_reservations     | table       | scan
 rideshare          | vehicles                 | table       | scan
 temp               | list_items               | table       | scan
