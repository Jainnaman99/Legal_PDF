-- Adds 'draft' as a valid value for pdf_documents.status.
--
-- The original CHECK constraint only permits ('pending','approved','rejected').
-- This script drops it and recreates it with 'draft' included so that the
-- uploader "Save as Draft" flow can insert rows with status = 'draft'.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_draft_status_constraint.sql

USE legal_pdf;

-- ── 1. Drop the old constraint ──────────────────────────────────────────────
ALTER TABLE pdf_documents
    DROP CHECK chk_pdf_status;

-- ── 2. Recreate it with 'draft' added ───────────────────────────────────────
ALTER TABLE pdf_documents
    ADD CONSTRAINT chk_pdf_status
        CHECK (status IN ('pending', 'approved', 'rejected', 'draft'));

-- ── 3. Verify ────────────────────────────────────────────────────────────────
-- Expected output: one row showing the updated constraint expression.
SELECT
    CONSTRAINT_NAME,
    CHECK_CLAUSE
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND CONSTRAINT_NAME = 'chk_pdf_status';
