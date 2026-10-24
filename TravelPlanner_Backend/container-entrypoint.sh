#!/bin/sh
set -eu
: "${DB_HOST:=database}" "${DB_PORT:=3306}" "${DB_NAME:=test_planner_20261019_update}" "${DB_USERNAME:=planner}"
export SPRING_DATASOURCE_URL="jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true&characterEncoding=utf8"
export DB_URL="$SPRING_DATASOURCE_URL" SPRING_DATASOURCE_USERNAME="$DB_USERNAME"
export SPRING_DATASOURCE_PASSWORD="$(cat /run/secrets/db_password)"
export DB_PASSWORD="$SPRING_DATASOURCE_PASSWORD"
export SPRING_CONFIG_ADDITIONAL_LOCATION=file:/app/config/application-docker.properties
exec java -jar /app/app.jar "$@"
