#!/bin/bash

source ./Docker/scripts/env_functions.sh

if [ "$DOCKER_ENV" != "true" ]; then
    export_env_vars
fi

if [[ "$DATABASE_PROVIDER" == "postgresql" || "$DATABASE_PROVIDER" == "mysql" || "$DATABASE_PROVIDER" == "psql_bouncer" ]]; then
    export DATABASE_URL
    echo "Deploying migrations for $DATABASE_PROVIDER"
    echo "Database URL: $DATABASE_URL"

    if [[ "$DATABASE_PROVIDER" == "postgresql" ]]; then
        printf '%s\n' \
            'CREATE TABLE IF NOT EXISTS "RuntimeConfig" ("id" SERIAL NOT NULL, "key" VARCHAR(100) NOT NULL, "value" TEXT NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP NOT NULL, CONSTRAINT "RuntimeConfig_pkey" PRIMARY KEY ("id"));' \
            'CREATE UNIQUE INDEX IF NOT EXISTS "RuntimeConfig_key_key" ON "RuntimeConfig"("key");' \
            | npx prisma db execute --stdin
        if [ $? -ne 0 ]; then
            echo "RuntimeConfig integrity check failed"
            exit 1
        else
            echo "RuntimeConfig integrity check succeeded"
        fi
    fi

    npm run db:deploy
    if [ $? -ne 0 ]; then
        echo "Migration failed"
        exit 1
    else
        echo "Migration succeeded"
    fi
    npm run db:generate
    if [ $? -ne 0 ]; then
        echo "Prisma generate failed"
        exit 1
    else
        echo "Prisma generate succeeded"
    fi
else
    echo "Error: Database provider $DATABASE_PROVIDER invalid."
    exit 1
fi
