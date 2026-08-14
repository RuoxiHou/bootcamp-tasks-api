#!/bin/sh
set -eu

ENCODED_MYSQL_PASSWORD="$(python -c 'import os, urllib.parse; print(urllib.parse.quote_plus(os.environ["MYSQL_PASSWORD"]))')"
export DATABASE_URL="mysql+pymysql://${MYSQL_USER}:${ENCODED_MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT:-3306}/${MYSQL_DATABASE}"

exec "$@"