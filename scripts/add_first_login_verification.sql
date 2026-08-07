-- ============================================================
-- Adds email_verified and mobile_verified columns to users table.
-- These track whether a user has verified their contact details.
-- mobile_verified is required before a first-time password reset.
--
-- Run via mysql client:
--   mysql -u <user> -p <database> < scripts/add_first_login_verification.sql
-- ============================================================

USE legal_pdf;

ALTER TABLE users
  ADD COLUMN mobile_verified TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN email_verified  TINYINT(1) NOT NULL DEFAULT 0;
