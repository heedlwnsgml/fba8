#!/bin/sh
set -eu
password="$(cat /run/secrets/db_password)"
# Password files produced by prepare-private.py use alphanumeric hex only.
case "$password" in ''|*[!0-9a-f]*) echo "Unexpected password format" >&2; exit 1;; esac
export MYSQL_PWD="$(cat /run/secrets/db_root_password)"
mariadb --protocol=socket -uroot <<SQL
CREATE USER IF NOT EXISTS 'planner'@'%' IDENTIFIED BY '${password}';
GRANT SELECT,INSERT,UPDATE,DELETE ON test_planner_20261019_update.* TO 'planner'@'%';
GRANT ALL PRIVILEGES ON test_planner_app_metadata.* TO 'planner'@'%';
GRANT SELECT ON test_planner_collected_passes_20261012.* TO 'planner'@'%';
FLUSH PRIVILEGES;
SQL
