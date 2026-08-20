-- Repair production databases where the upstream migration is marked applied
-- but RuntimeConfig was removed or never created.
CREATE TABLE IF NOT EXISTS "RuntimeConfig" (
    "id" SERIAL NOT NULL,
    "key" VARCHAR(100) NOT NULL,
    "value" TEXT NOT NULL,
    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP NOT NULL,
    CONSTRAINT "RuntimeConfig_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "RuntimeConfig_key_key"
    ON "RuntimeConfig"("key");
