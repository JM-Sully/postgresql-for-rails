-- misc Chapter 2 commands

psql $DATABASE_URL
psql -U postgres

\o file.text

SELECT * FROM pg_stat_activity
WHERE pid = (SELECT PG_BACKEND_PID());

SELECT * FROM pg_locks;

\c experiments -- my test db

CREATE TABLE tbl (col SMALLINT);
INSERT INTO tbl (col) SELECT GENERATE_SERIES(1, 10);

SELECT * FROM tbl;

psql -U postgres -d experiments

\timing 
CREATE INDEX test_index ON public.tbl (col);

-- find my table
SELECT schemaname, tablename 
FROM pg_tables 
WHERE tablename LIKE '%tbl%';

-- be able to output my table
SELECT * FROM public.tbl;

-- find my index
\d public.tbl

CREATE INDEX test_index ON public.tbl (col);
DROP INDEX test_index;

BEGIN;
INSERT INTO tbl (col_2) SELECT GENERATE_SERIES(1, 10);
CREATE INDEX test_index ON public.tbl (col_2);
COMMIT;

BEGIN;
CREATE INDEX test_index ON public.tbl (col);
ROLLBACK;
