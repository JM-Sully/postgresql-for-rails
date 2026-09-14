query="SELECT PG_SLEEP(30)"

for number in {1..4}; do
  echo "Running query=${query} Number=${run}"
  psql $DATABASE_URL \ -c "$query" & # separate processes
done
