#!/bin/sh
clear
echo "_________________________________________________________________________"
echo "__PLEASE READ!___________________________________________________________"
echo "This script will clone one PostgreSQL schema from 'source' to 'target' "
echo "database."
echo "You must have 'pg_dump' and 'psql' installed and accessible from the "
echo "terminal."
echo "As this is potentially dangerous operation, you must enter connection "
echo "parameters manually."
echo "If 'after.sql' file is found in the working directory, it will be "
echo "executed on 'target' database after cloning is finished."

echo ""
echo "_________________________________________________________________________"
echo "__Source database________________________________________________________"
read -p "Enter 'source' database host:" SOURCE_HOST
read -p "Enter 'source' database port:" SOURCE_PORT
read -p "Enter 'source' database name:" SOURCE_NAME
read -p "Enter 'source' database schema:" SOURCE_SCHEMA
read -p "Enter 'source' database user:" SOURCE_USER
read -p "Enter 'source' database password:" SOURCE_PASSWORD

echo ""
echo "_________________________________________________________________________"
echo "__Target database________________________________________________________"
read -p "Enter 'target' database host:" TARGET_HOST
read -p "Enter 'target' database port:" TARGET_PORT
read -p "Enter 'target' database name:" TARGET_NAME
read -p "Enter 'target' database user:" TARGET_USER
read -p "Enter 'target' database password:" TARGET_PASSWORD
clear

DATE=$(date +"%Y%m%dT%H%M%S")
SOURCE_FILE="source_schema_backup_$DATE.sql"
TARGET_FILE="target_schema_backup_$DATE.sql"
AFTER_SQL_FILE="after.sql"

echo "Downloading 'source' database '$SOURCE_SCHEMA' schema..."
PGPASSWORD=$SOURCE_PASSWORD pg_dump -h $SOURCE_HOST -U $SOURCE_USER -p $SOURCE_PORT -n $SOURCE_SCHEMA $SOURCE_NAME > $SOURCE_FILE

echo "Downloading 'target' database '$SOURCE_SCHEMA' schema..."
PGPASSWORD=$TARGET_PASSWORD pg_dump -h $TARGET_HOST -U $TARGET_USER -p $TARGET_PORT -n $SOURCE_SCHEMA $TARGET_NAME > $TARGET_FILE

echo "Revoking CONNECT grant on 'target' database..."
PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER -p $TARGET_PORT $TARGET_NAME << EOF
  REVOKE CONNECT ON DATABASE $TARGET_NAME FROM $SOURCE_SCHEMA;
EOF

echo "Stoping all connections on 'target' database..."
PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER -p $TARGET_PORT $TARGET_NAME << EOF
  SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname='$TARGET_NAME';
EOF

echo "Dropping old '$SOURCE_SCHEMA' schema on 'target' database..."
PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER postgres << EOF
  DROP SCHEMA IF EXISTS $SOURCE_SCHEMA CASCADE;
EOF

echo "Creating new '$SOURCE_SCHEMA' schema on 'target' database..."
PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER postgres << EOF
  CREATE SCHEMA $SOURCE_SCHEMA;
EOF

echo "Restoring $SOURCE_SCHEMA schema to 'target' database..."
PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER -p $TARGET_PORT $TARGET_NAME < $SOURCE_FILE

if [ -f "$AFTER_SQL_FILE" ]; then
    echo "Executing $AFTER_SQL_FILE ..."
    PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER -p $TARGET_PORT $TARGET_NAME < $AFTER_SQL_FILE
fi

echo "Done."
