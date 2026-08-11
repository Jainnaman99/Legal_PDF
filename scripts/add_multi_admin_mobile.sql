-- Migration: support multiple admin users sharing the same mobile number.
-- Adds two stored procedures used by the new department-selection OTP login flow.
--
-- Run: mysql -u root -p Legal_PDF < scripts/add_multi_admin_mobile.sql

DELIMITER $$

-- 1. sp_get_admin_users_by_mobile
--    Returns ALL active admin/super Admin users for a given mobile number,
--    along with their department names (pipe-separated, ordered by id).
DROP PROCEDURE IF EXISTS sp_get_admin_users_by_mobile $$
CREATE PROCEDURE sp_get_admin_users_by_mobile(IN p_mobile_number VARCHAR(20))
BEGIN
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.must_change_password, u.mobile_number, u.password_changed_at,
        u.first_name, u.last_name, u.role_id, u.department_id,
        u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description,
        (SELECT GROUP_CONCAT(d2.name ORDER BY CAST(TRIM(jt.did) AS UNSIGNED) SEPARATOR '|')
         FROM JSON_TABLE(
                CONCAT('["', REPLACE(IFNULL(u.department_id, ''), ',', '","'), '"]'),
                '$[*]' COLUMNS (did VARCHAR(10) PATH '$')) jt
         JOIN departments d2 ON d2.id = CAST(TRIM(jt.did) AS UNSIGNED)
         WHERE TRIM(jt.did) != ''
        ) AS department_name,
        NULL AS department_description,
        NULL AS last_login
    FROM  users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.mobile_number = p_mobile_number
      AND u.is_active     = 1
      AND r.name IN ('admin', 'super Admin');
END $$

-- 2. sp_get_admin_user_by_mobile_and_dept
--    Returns the single active admin/super Admin user whose mobile number matches
--    AND whose department_id CSV contains p_dept_id.
DROP PROCEDURE IF EXISTS sp_get_admin_user_by_mobile_and_dept $$
CREATE PROCEDURE sp_get_admin_user_by_mobile_and_dept(
    IN p_mobile_number VARCHAR(20),
    IN p_dept_id       INT
)
BEGIN
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.must_change_password, u.mobile_number, u.password_changed_at,
        u.first_name, u.last_name, u.role_id, u.department_id,
        u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description,
        (SELECT GROUP_CONCAT(d2.name ORDER BY CAST(TRIM(jt.did) AS UNSIGNED) SEPARATOR '|')
         FROM JSON_TABLE(
                CONCAT('["', REPLACE(IFNULL(u.department_id, ''), ',', '","'), '"]'),
                '$[*]' COLUMNS (did VARCHAR(10) PATH '$')) jt
         JOIN departments d2 ON d2.id = CAST(TRIM(jt.did) AS UNSIGNED)
         WHERE TRIM(jt.did) != ''
        ) AS department_name,
        NULL AS department_description,
        (SELECT created_at FROM user_login_logs
         WHERE  user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM  users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.mobile_number = p_mobile_number
      AND u.is_active     = 1
      AND r.name IN ('admin', 'super Admin')
      AND FIND_IN_SET(CAST(p_dept_id AS CHAR), IFNULL(u.department_id, '')) > 0
    LIMIT 1;
END $$

DELIMITER ;

SELECT 'sp_get_admin_users_by_mobile and sp_get_admin_user_by_mobile_and_dept created.' AS status;
