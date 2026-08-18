-- Creates the pdf_approval_drafts table for storing approver annotation drafts.
-- One row per (pdf_id, approver_id) — UPSERT keeps only the latest draft.
-- Row is auto-deleted via CASCADE when the parent document is deleted.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_pdf_approval_drafts_table.sql

USE legal_pdf;

CREATE TABLE IF NOT EXISTS pdf_approval_drafts (
    id               INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    pdf_id           INT          NOT NULL,
    approver_id      INT          NOT NULL,
    comments         TEXT,
    annotations_json LONGTEXT,
    saved_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_draft_per_doc_approver (pdf_id, approver_id),
    CONSTRAINT fk_apdraft_pdf
        FOREIGN KEY (pdf_id)      REFERENCES pdf_documents(id) ON DELETE CASCADE,
    CONSTRAINT fk_apdraft_approver
        FOREIGN KEY (approver_id) REFERENCES users(id)          ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
