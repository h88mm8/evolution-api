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
        printf '%s\n'             'CREATE TABLE IF NOT EXISTS "evolution_api"."RuntimeConfig" ("id" SERIAL NOT NULL, "key" VARCHAR(100) NOT NULL, "value" TEXT NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP NOT NULL, CONSTRAINT "RuntimeConfig_pkey" PRIMARY KEY ("id"));'             'CREATE UNIQUE INDEX IF NOT EXISTS "RuntimeConfig_key_key" ON "evolution_api"."RuntimeConfig"("key");'             | npx prisma db execute --stdin
        if [ $? -ne 0 ]; then
            echo "RuntimeConfig integrity check failed"
            exit 1
        else
            echo "RuntimeConfig integrity check succeeded"
        fi

        # The repair migration previously failed after partially finding an existing FK.
        # Remove only its failed bookkeeping row so Prisma can rerun the idempotent repair.
        printf '%s\n' 'DELETE FROM "evolution_api"."_prisma_migrations" WHERE migration_name = '\''20260820220000_repair_missing_application_schema'\'' AND finished_at IS NULL;' | npx prisma db execute --stdin
        if [ $? -ne 0 ]; then
            echo "Failed migration bookkeeping cleanup failed"
            exit 1
        else
            echo "Failed migration bookkeeping cleanup succeeded"
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
