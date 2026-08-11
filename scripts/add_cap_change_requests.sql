-- Cap-change request table.
-- Admins submit requests to increase/decrease role-user caps for their department.
-- Super Admin reviews and approves or rejects each request.
-- On approval the cap is automatically applied to dept_role_limits.
--
-- Run via mysql client:
--   mysql -u <user> -p <database> < scripts/add_cap_change_requests.sql

USE legal_pdf;

CREATE TABLE IF NOT EXISTS cap_change_requests (
  id               INT          NOT NULL AUTO_INCREMENT,
  department_id    INT          NOT NULL,
  role_id          INT          NOT NULL,
  requested_by     INT          NOT NULL,          -- admin user.id
  current_cap      INT          NULL,              -- NULL means the system default was in effect
  requested_cap    INT          NOT NULL,
  reason           TEXT         NULL,
  status           VARCHAR(20)  NOT NULL DEFAULT 'pending',
  super_admin_note TEXT         NULL,
  resolved_by      INT          NULL,
  resolved_at      DATETIME     NULL,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT chk_cap_req_status CHECK (status IN ('pending', 'approved', 'rejected')),
  CONSTRAINT chk_cap_req_cap    CHECK (requested_cap >= 0)
);
