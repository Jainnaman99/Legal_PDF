-- Widens pdf_documents.status to support the unlock-request workflow:
--   'returned' — sent back to the uploader for edits after an approver's
--                "unlock for edit" request is approved by the Nodal Officer
--   'deleted'  — soft-deleted after an approver's "unlock for delete" request
--                is approved by the Nodal Officer (hidden from the citizen
--                portal — every citizen-facing query filters on status = 'approved'
--                exactly, so 'deleted' is excluded automatically)
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_pdf_status_add_returned_deleted.sql

USE legal_pdf;

ALTER TABLE pdf_documents
    DROP CHECK chk_pdf_status;

ALTER TABLE pdf_documents
    ADD CONSTRAINT chk_pdf_status
        CHECK (status IN ('pending', 'approved', 'rejected', 'draft', 'returned', 'deleted'));

SELECT 'pdf_documents.status now allows returned and deleted.' AS status;
