-- requested_cap now means "amount to add to the current cap" (can be negative
-- to request a decrease) instead of an absolute new cap, so the old
-- "must be >= 0" constraint no longer applies.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_cap_change_requests_allow_negative.sql

USE legal_pdf;

ALTER TABLE cap_change_requests DROP CHECK chk_cap_req_cap;

SELECT 'cap_change_requests.requested_cap now allows negative values.' AS status;
