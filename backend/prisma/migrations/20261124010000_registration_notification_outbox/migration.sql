CREATE TABLE "NotificationOutbox" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "registrationId" UUID NOT NULL,
    "type" "NotificationType" NOT NULL,
    "dedupeKey" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "availableAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leaseId" UUID,
    "lockedUntil" TIMESTAMPTZ(3),
    "processedAt" TIMESTAMPTZ(3),
    "lastError" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "NotificationOutbox_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "outbox_attempts_nonnegative" CHECK ("attempts" >= 0),
    CONSTRAINT "outbox_lease_pair" CHECK (("leaseId" IS NULL) = ("lockedUntil" IS NULL))
);
CREATE UNIQUE INDEX "NotificationOutbox_userId_dedupeKey_key" ON "NotificationOutbox"("userId", "dedupeKey");
CREATE INDEX "NotificationOutbox_processedAt_availableAt_lockedUntil_idx" ON "NotificationOutbox"("processedAt", "availableAt", "lockedUntil");
CREATE INDEX "NotificationOutbox_registrationId_idx" ON "NotificationOutbox"("registrationId");
CREATE INDEX "NotificationOutbox_eventId_idx" ON "NotificationOutbox"("eventId");
ALTER TABLE "NotificationOutbox" ADD CONSTRAINT "NotificationOutbox_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "NotificationOutbox" ADD CONSTRAINT "NotificationOutbox_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "NotificationOutbox" ADD CONSTRAINT "NotificationOutbox_registrationId_fkey" FOREIGN KEY ("registrationId") REFERENCES "Registration"("id") ON DELETE CASCADE ON UPDATE CASCADE;
