#!/bin/sh
# Runs only on the first start of an empty volume. Creates the disposable database used by pytest.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "CREATE DATABASE agritwin_test OWNER \"$POSTGRES_USER\";"
