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
        node - <<'NODE'
const { Client } = require('pg');

const client = new Client({ connectionString: process.env.DATABASE_CONNECTION_URI });

(async () => {
  try {
    await client.connect();
    const result = await client.query(`
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_type = 'BASE TABLE'
        AND table_name IN ('Instance', 'Message', 'Contact', 'RuntimeConfig', '_prisma_migrations')
      ORDER BY table_schema, table_name
    `);
    console.log('Schema diagnostic:', JSON.stringify(result.rows));
  } catch (error) {
    console.error('Schema diagnostic failed:', error.message);
  } finally {
    await client.end().catch(() => undefined);
  }
})();
NODE

        printf '%s\n'             'CREATE TABLE IF NOT EXISTS "public"."RuntimeConfig" ("id" SERIAL NOT NULL, "key" VARCHAR(100) NOT NULL, "value" TEXT NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP NOT NULL, CONSTRAINT "RuntimeConfig_pkey" PRIMARY KEY ("id"));'             'CREATE UNIQUE INDEX IF NOT EXISTS "RuntimeConfig_key_key" ON "public"."RuntimeConfig"("key");'             | npx prisma db execute --stdin
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
