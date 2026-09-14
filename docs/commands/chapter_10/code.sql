-- Beginning of chapter 10

psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

SELECT * FROM pg_stat_activity;
  datid  |        datname        |  pid  | leader_pid | usesysid | usename  | application_name  | client_addr | client_hostname | client_port |         backend_start         |          xact_start  |          query_start          |         state_change         | wait_event_type |     wait_event      | state  | backend_xid | backend_xmin |       query_id       |              query              |      backend_type         
---------+-----------------------+-------+------------+----------+----------+-------------------+-------------+-----------------+-------------+-------------------------------+-------------------------------+-------------------------------+------------------------------+-----------------+---------------------+--------+-------------+--------------+----------------------+---------------------------------+------------------------------
         |                       |  1405 |            |          |          |                   |             |                 |             | 2026-08-06 15:54:12.29586+01  |  |                               |                              | Activity        | AutoVacuumMain      |        |             |              |                      |                                 | autovacuum launcher
         |                       |  1408 |            |       10 | scan     |                   |             |                 |             | 2026-08-06 15:54:12.322105+01 |  |                               |                              | Activity        | LogicalLauncherMain |        |             |              |                      |                                 | logical replication launcher
 5034986 | rideshare_development |  1407 |            |       10 | scan     | pg_cron scheduler |             |                 |             | 2026-08-06 15:54:12.322759+01 |  |                               |                              | Extension       | Extension           |        |             |              | -5996402778861906297 |                                 | pg_cron launcher
 5034986 | rideshare_development | 52996 |            |  4340503 | postgres | psql              |             |                 |          -1 | 2026-08-06 16:46:41.412095+01 | 2026-08-06 16:47:16.840478+01 | 2026-08-06 16:47:16.840478+01 | 2026-08-06 16:47:16.84048+01 |                 |                     | active |             |      6100179 | -6114308060117779060 | SELECT * FROM pg_stat_activity; | client backend
         |                       |  1384 |            |          |          |                   |             |                 |             | 2026-08-06 15:54:12.040042+01 |  |                               |                              | Activity        | BgWriterHibernate   |        |             |              |                      |                                 | background writer
         |                       |  1383 |            |          |          |                   |             |                 |             | 2026-08-06 15:54:12.038646+01 |  |                               |                              | Activity        | CheckpointerMain    |        |             |              |                      |                                 | checkpointer
         |                       |  1403 |            |          |          |                   |             |                 |             | 2026-08-06 15:54:12.283733+01 |  |                               |                              | Activity        | WalWriterMain       |        |             |              |                      |                                 | walwriter
(7 rows)


-- in a new terminal, start a rails server
rails s

-- in a new terminal, simulate app activity
bin/rails simulate:app_activity

-- Use \watch to continually monitor results 
SELECT pid, datname, usename, application_name, client_hostname, client_port, backend_start, query_start, query, state 
FROM pg_stat_activity
WHERE pid != PG_BACKEND_PID() -- exclude this query
AND datname = 'rideshare_development' -- specify app DB
AND state IS NOT NULL\watch

                                                                                                                 Thu Aug  6 16:56:16 2026 (every 2s)

  pid  |        datname        | usename | application_name | client_hostname | client_port |         backend_start         |          query_start          |                          query                                              | state 
-------+-----------------------+---------+------------------+-----------------+-------------+-------------------------------+-------------------------------+------------------------------------------------------------------------------------------------+-------
 57721 | rideshare_development | scan    | bin/rails        |                 |          -1 | 2026-08-06 16:56:07.347197+01 | 2026-08-06 16:56:07.401081+01 | SELECT "users".* FROM "users" WHERE "users"."type" = 'Rider' ORDER BY "users"."id" ASC LIMIT 1 | idle
 55935 | rideshare_development | scan    | bin/rails        |                 |          -1 | 2026-08-06 16:53:14.96219+01  | 2026-08-06 16:53:15.050063+01 | SELECT "users".* FROM "users" WHERE "users"."type" = 'Driver'                                  | idle
(2 rows)

Time: 11.889 ms
                                                                                                                 Thu Aug  6 16:56:18 2026 (every 2s)

  pid  |        datname        | usename | application_name | client_hostname | client_port |         backend_start         |          query_start          |                          query                                              | state 
-------+-----------------------+---------+------------------+-----------------+-------------+-------------------------------+-------------------------------+------------------------------------------------------------------------------------------------+-------
 57721 | rideshare_development | scan    | bin/rails        |                 |          -1 | 2026-08-06 16:56:07.347197+01 | 2026-08-06 16:56:07.401081+01 | SELECT "users".* FROM "users" WHERE "users"."type" = 'Rider' ORDER BY "users"."id" ASC LIMIT 1 | idle
 55935 | rideshare_development | scan    | bin/rails        |                 |          -1 | 2026-08-06 16:53:14.96219+01  | 2026-08-06 16:53:15.050063+01 | SELECT "users".* FROM "users" WHERE "users"."type" = 'Driver'                                  | idle
(2 rows)

Time: 2.162 ms


-- query for finding slow queries (running longer than 5 minutes)
SELECT pid, NOW() - pg_stat_activity.query_start AS duration, query, state FROM pg_stat_activity WHERE (

NOW() - pg_stat_activity.query_start ) > INTERVAL '5 minutes' AND state != 'idle';
 pid | duration | query | state 
-----+----------+-------+-------
(0 rows)

Time: 16.303 ms
-- none found, which is good!

-- new day from p228 Running Out of Connections
-- start a psql session
psql -U postgres -d rideshare_development
SET search_path TO rideshare;
\timing

SHOW max_connections;
 max_connections 
-----------------
 100
(1 row)

-- edit posgresql.conf and set max_connections lower
max_connections = 3			# (change requires restart)
superuser_reserved_connections = 2	# (change requires restart)


-- start a psql session
psql -U postgres -d rideshare_development
SET search_path TO rideshare;

-- create rideshare/docs/commands/chapter_10/exhaust_database_connections.sh

-- in the terminal
-- give execute permissions to my script file
chmod +x docs/commands/chapter_10/exhaust_database_connections.sh

-- run the script
docs/commands/chapter_10/exhaust_database_connections.sh

Running query=SELECT PG_SLEEP(30) Number=
Running query=SELECT PG_SLEEP(30) Number=
Running query=SELECT PG_SLEEP(30) Number=
Running query=SELECT PG_SLEEP(30) Number=
psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  role "SELECT PG_SLEEP(30)" does not exist
psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  role "SELECT PG_SLEEP(30)" does not exist
psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  role "SELECT PG_SLEEP(30)" does not exist
psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  role "SELECT PG_SLEEP(30)" does not exist
-- I think the lack of internet might possibly be the reason this isn't working?


-- See idle queries
SELECT COUNT(*), state FROM pg_stat_activity GROUP BY 2;
 count | state  
-------+--------
     6 | 
     1 | active

SELECT * FROM pg_stat_activity WHERE (state = 'idle in transaction');
 datid | datname | pid | leader_pid | usesysid | usename | application_name | client_addr | client_hostname | client_port | backend_start | xact_start | query_start | state_change | wait_event_type | wait_event | state | backend_xid | backend_xmin | query_id | query | backend_type 
-------+---------+-----+------------+----------+---------+------------------+-------------+-----------------+-------------+---------------+------------+-------------+--------------+-----------------+------------+-------+-------------+--------------+----------+-------+--------------
(0 rows)

-- download pgbouncer
brew install pgbouncer

-- check the version
pgbouncer --version

brew services info pgbouncer
pgbouncer (homebrew.mxcl.pgbouncer)
Running: ✘
Loaded: ✘
Schedulable: ✘

brew services restart pgbouncer
==> Successfully started `pgbouncer` (label: homebrew.mxcl.pgbouncer)

brew services info pgbouncer
pgbouncer (homebrew.mxcl.pgbouncer)
Running: ✔
Loaded: ✔
Schedulable: ✘
User: scan
PID: 26095

-- find the path for the ini file
brew info pgbouncer
==> pgbouncer ✔: stable 1.25.2 (bottled), HEAD
Lightweight connection pooler for PostgreSQL
https://www.pgbouncer.org/
Installed (on request)
From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/p/pgbouncer.rb
License: ISC
==> Installed Versions
pgbouncer ✔ 1.25.2 (22 files, 807.0KB) [Linked]
==> Dependencies
Required (2): libevent ↑, openssl@3 ↑
Recursive Runtime (3): all installed ✔
==> Options
--HEAD
        Install HEAD version
==> Caveats
The config file: /opt/homebrew/etc/pgbouncer.ini is in the "ini" format and you
will need to edit it for your particular setup. See:
https://pgbouncer.github.io/config.html

The auth_file option should point to the /opt/homebrew/etc/userlist.txt file which
can be populated by the /opt/homebrew/Cellar/pgbouncer/1.25.2/bin/mkauth.py script.

-- To restart pgbouncer after an upgrade:
--   brew services restart pgbouncer
-- Or, if you don't want/need a background service you can just run:
--   /opt/homebrew/opt/pgbouncer/bin/pgbouncer -q /opt/homebrew/etc/pgbouncer.ini
-- ==> Downloading https://formulae.brew.sh/api/formula/pgbouncer.json
-- ==> Analytics
-- install: 89 (30 days), 259 (90 days), 1,041 (365 days)
-- install-on-request: 89 (30 days), 259 (90 days), 1,041 (365 days)
-- build-error: 0 (30 days)


-- update this file to look like postgresql/pgbouncer.sample.ini
open /opt/homebrew/etc/pgbouncer.ini
-- add the following lines to the file
admin_users = owner

[databases]
rideshare_development = host=127.0.0.1 port=5432 dbname=rideshare_development

[pgbouncer]
listen_port = 6432
listen_addr = localhost
auth_type = md5
auth_file = /opt/homebrew/etc/userlist.txt
logfile = pgbouncer.log
pidfile = pgbouncer.pid
admin_users = owner

-- restart pgbouncer
brew services restart pgbouncer

psql -U owner -d rideshare_development -p 6432
psql: error: connection to server on socket "/tmp/.s.PGSQL.6432" failed: FATAL:  password authentication failed

echo '"owner" "e479e5f6c26e211403c73e68"' >> /opt/homebrew/etc/userlist.txt

brew services restart pgbouncer
psql -U owner -d rideshare_development -p 6432

-- connect to pgbouncer databse
psql -p 6432 -U owner pgbouncer

-- explore all the commands
SHOW HELP;
NOTICE:  Console usage
DETAIL:  
        SHOW HELP|CONFIG|DATABASES|POOLS|CLIENTS|SERVERS|USERS|VERSION
        SHOW PEERS|PEER_POOLS
        SHOW FDS|SOCKETS|ACTIVE_SOCKETS|LISTS|MEM|STATE
        SHOW DNS_HOSTS|DNS_ZONES
        SHOW STATS|STATS_TOTALS|STATS_AVERAGES|TOTALS
        SET key = arg
        RELOAD
        PAUSE [<db>]
        RESUME [<db>]
        DISABLE <db>
        ENABLE <db>
        RECONNECT [<db>]
        KILL [<db>]
        KILL_CLIENT <client_id>
        SUSPEND
        SHUTDOWN
        SHUTDOWN WAIT_FOR_SERVERS|WAIT_FOR_CLIENTS
        WAIT_CLOSE [<db>]
SHOW

-- try some commands
SHOW DATABASES;

         name          |   host    | port |       database        | force_user | pool_size | min_pool_size | reserve_pool_size | server_lifetime| pool_mode | load_balance_hosts | max_connections | current_connections | max_client_connections | current_client_connections | paused | disabled 
-----------------------+-----------+------+-----------------------+------------+-----------+---------------+-------------------+-----------------+-----------+--------------------+-----------------+---------------------+------------------------+----------------------------+--------+----------
 pgbouncer             |           | 6432 | pgbouncer             | pgbouncer  |         2 |             0 |                 0 |            3600| statement |                    |               0 |                   0 |                      0 |                          1 |      0 |0
 rideshare_development | 127.0.0.1 | 5432 | rideshare_development |            |        20 |             0 |                 0 |            3600|           |                    |               0 |                   1 |                      0 |                          0 |      0 |0
(2 rows)

SHOW CLIENTS;
 type | user  | database  | replication | state | addr | port | local_addr | local_port |      connect_time       |      request_time       | wait | wait_us | close_needed |     ptr     | link | remote_pid | tls | application_name | prepared_statements | id 
------+-------+-----------+-------------+-------+------+------+------------+------------+-------------------------+-------------------------+------+---------+--------------+-------------+------+------------+-----+------------------+---------------------+----
 C    | owner | pgbouncer | none        | idle  | unix | 6432 | unix       |       6432 | 2026-08-21 10:05:13 IST | 2026-08-21 10:07:38 IST |  138 |    2691 |            0 | 0xac344c010 |      |          0 |     | psql             |                   0 |  5
(1 row)

-- Update pgbouncer.ini config with 
pool_mode=transaction
max_prepared_statements = 200
rideshare_development = host=127.0.0.1 port=5432 dbname=rideshare_development pool_mode=transaction
-- Ensure query_log_tags_enabled = false in config/application.rb (incompatible with prepared statements)

-- Restart PgBouncer
brew services restart pgbouncer

-- Start up the Rails server and run the app activity simulation script from earlier
chmod +x /Users/scan/projects/rideshare/db/pgbouncer_prepared_statements_check.sh
/Users/scan/projects/rideshare/db/pgbouncer_prepared_statements_check.sh
List Prepared Statements results (empty to start):
   (81.4ms)  SELECT * FROM pg_prepared_statements
Run a query to populate prepared statements:
  Trip Load (10.4ms)  SELECT "trips".* FROM "trips" ORDER BY "trips"."id" ASC LIMIT 1
List Prepared Statements results again:
