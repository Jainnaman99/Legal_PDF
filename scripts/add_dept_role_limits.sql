-- Creates the dept_role_limits table for dynamic per-department role-user caps.
-- Admin manages these from the Admin Dashboard → Role Caps page.
-- If no row exists for a (department, role) pair the system falls back to the
-- hardcoded default of 2 users per role per department.
--
-- Run via mysql client:
--   mysql -u <user> -p <database> < scripts/add_dept_role_limits.sql

USE legal_pdf;

CREATE TABLE IF NOT EXISTS dept_role_limits (
  id            INT          NOT NULL AUTO_INCREMENT,
  department_id INT          NOT NULL,
  role_id       INT          NOT NULL,
  max_users     INT          NOT NULL DEFAULT 5,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_dept_role (department_id, role_id),
  CONSTRAINT chk_max_users CHECK (max_users >= 0)
);
