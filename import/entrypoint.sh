#!/bin/bash
set -e

# Wait for Postgres
until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER"; do
  echo "Waiting for database..."
  sleep 2
done

echo "Database is ready."

# Check if OSM file exists
OSM_PATH="/data/$OSM_FILE"
if [ ! -f "$OSM_PATH" ]; then
    echo "No OSM file found at $OSM_PATH."
    echo "Available files in /data:"
    ls -1 /data
    echo "Please place your .osm or .pbf file in the data directory and update docker-compose.yml if necessary."
    exit 0
fi

export PGPASSWORD="$POSTGRES_PASSWORD"

# Check if data already imported
TABLE_EXISTS=$(psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT to_regclass('public.ways');")

if [ "$TABLE_EXISTS" != "public.ways" ]; then
    echo "Importing OSM data from $OSM_PATH..."

    # Enable extensions
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
    psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgrouting;"

    # Find mapconfig.xml
    CONFIG_PATH="/data/mapconfig.xml"
    if [ ! -f "$CONFIG_PATH" ]; then
        CONFIG_PATH="/usr/share/osm2pgrouting/mapconfig.xml"
        if [ ! -f "$CONFIG_PATH" ]; then
            CONFIG_PATH=$(find /usr/share -name mapconfig.xml | head -n 1)
        fi
    fi

    if [ -z "$CONFIG_PATH" ]; then
        echo "Error: mapconfig.xml not found."
        exit 1
    fi

    echo "Using config: $CONFIG_PATH"

    # osm2pgrouting handles .osm files. If it's .pbf, we might need to convert it first using osmconvert (from osmctools)
    if [[ "$OSM_PATH" == *.pbf ]]; then
        echo "Converting PBF to OSM..."
        osmconvert "$OSM_PATH" --out-osm > /tmp/temp.osm
        IMPORT_FILE="/tmp/temp.osm"
    else
        IMPORT_FILE="$OSM_PATH"
    fi

    osm2pgrouting \
      -f "$IMPORT_FILE" \
      -c "$CONFIG_PATH" \
      -d "$POSTGRES_DB" \
      -U "$POSTGRES_USER" \
      -h "$POSTGRES_HOST" \
      -p "$POSTGRES_PORT" \
      -W "$POSTGRES_PASSWORD" \
      --clean

    if [[ "$OSM_PATH" == *.pbf ]]; then
        rm /tmp/temp.osm
    fi

    echo "Import finished."

    # Run init.sql to create routing functions
    if [ -f "init.sql" ]; then
        echo "Running init.sql..."
        psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f init.sql
    fi

else
    echo "Table 'ways' already exists. Skipping import."
fi

