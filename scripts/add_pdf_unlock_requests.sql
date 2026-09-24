-- Unlock-request workflow for approved documents.
--
-- Once a document is approved, the Approver can ask to unlock it — either to
-- let the uploader edit it, or to soft-delete it. The Nodal Officer of the
-- document's own department reviews the request:
--   - approved "edit"   request -> pdf_documents.status becomes 'returned'
--                                   (sent back to the uploader to edit)
--   - approved "delete" request -> pdf_documents.status becomes 'deleted'
--                                   (soft delete — hidden from the citizen portal)
--   - rejected request           -> pdf_documents is left untouched
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_pdf_unlock_requests.sql

USE legal_pdf;

CREATE TABLE IF NOT EXISTS pdf_unlock_requests (
  id            INT          NOT NULL AUTO_INCREMENT,
  pdf_id        INT          NOT NULL,
  department_id INT          NOT NULL,     -- snapshot of the document's department at request time, for routing
  request_type  VARCHAR(10)  NOT NULL,     -- 'edit' | 'delete'
  requested_by  INT          NOT NULL,     -- approver user.id
  reason        TEXT         NULL,
  status        VARCHAR(20)  NOT NULL DEFAULT 'pending',
  reviewed_by   INT          NULL,         -- nodal officer user.id
  reviewed_at   DATETIME     NULL,
  review_note   TEXT         NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT chk_unlock_req_type   CHECK (request_type IN ('edit', 'delete')),
  CONSTRAINT chk_unlock_req_status CHECK (status IN ('pending', 'approved', 'rejected')),
  KEY idx_unlock_req_pdf   (pdf_id),
  KEY idx_unlock_req_dept  (department_id),
  KEY idx_unlock_req_status (status)
);

SELECT 'pdf_unlock_requests created.' AS status;
