#!/bin/bash
# Initialize a new Toolhub deployment.
# This is meant to run as a one time job in a new deployment when enabled with
# the jobs.init_db setting in a values.yaml for the deployment.
set -Eeuxo pipefail

expected_env() {
    if [ -z "$DB_HOST" ]; then
        echo "DB_HOST not set, exiting." 1>&2
        exit 1
    fi
    if [ -z "$DB_USER" ]; then
        echo "DB_USER not set, exiting." 1>&2
        exit 1
    fi
    if [ -z "$DB_PASSWORD" ]; then
        echo "DB_PASSWORD not set, exiting." 1>&2
        exit 1
    fi
    if [ -z "$DB_NAME" ]; then
        echo "DB_NAME not set, exiting." 1>&2
        exit 1
    fi
    if [ -z "$DB_PORT" ]; then
        echo "DB_PORT not set, exiting." 1>&2
        exit 1
    fi
}

wait_for_db() {
    local max_attempts=24
    local db_check=$(cat <<-END
		import MySQLdb
		db = MySQLdb.connect(
		    host='$DB_HOST',
		    user='$DB_USER',
		    password='$DB_PASSWORD',
		    db='$DB_NAME',
		    port=int($DB_PORT)
		)
		print(db)
	END
    )
    echo "$(date): Waiting for DB to become available"
    for ((attempt=0; attempt<$max_attempts; attempt++)); do
        if poetry run python3 -c "${db_check}"; then
            echo "$(date): DB is available"
            return
        else
            echo "$(date): DB connection failed, taking a nap."
            sleep 5
        fi
    done
    # If we get here we did not successfully connect
    echo "$(date): DB not available after ${max_attempts} tries."
    exit 1
}

init_database() {
    # Create/update the database schema
    poetry run python3 manage.py migrate
    # Initialize revisions table contents
    poetry run python3 manage.py createinitialrevisions
    # Load demo server sample data
    poetry run python3 manage.py loaddata toolhub/fixtures/demo.yaml
    # Crawl toolinfo URLs
    poetry run python3 manage.py crawl
}

expected_env
wait_for_db
init_database
