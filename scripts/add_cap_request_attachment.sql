-- Adds a mandatory supporting-document attachment to cap_change_requests.
-- Admin must attach a file when raising a max-user-cap request; Super Admin
-- can then view/download it while reviewing the request.
--
-- Existing rows (submitted before this migration) will have NULL attachment
-- columns — the NOT NULL requirement is enforced at the API layer (the
-- upload field is mandatory on POST /cap-requests going forward), not via a
-- DB constraint, since old rows can't be retroactively backfilled with a file.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_cap_request_attachment.sql

USE legal_pdf;

ALTER TABLE cap_change_requests
    ADD COLUMN attachment_filename          VARCHAR(255) NULL AFTER reason,
    ADD COLUMN attachment_original_filename VARCHAR(255) NULL AFTER attachment_filename,
    ADD COLUMN attachment_file_path         VARCHAR(500) NULL AFTER attachment_original_filename,
    ADD COLUMN attachment_file_size         INT          NULL AFTER attachment_file_path;

SELECT 'cap_change_requests attachment columns added.' AS status;
