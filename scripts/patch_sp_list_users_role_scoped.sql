-- Role-scoped user list procedures
--
-- sp_list_users            → super Admin: all roles except super Admin, no dept restriction
-- sp_list_users_admin      → admin: nodal Officer / approver / uploader within their dept(s)
-- sp_list_users_nodal      → nodal Officer: approver / uploader within their dept(s)
--
-- All three return the same column set so the same Python _map_row() can handle them.
-- Run once:  mysql -u <user> -p legal_pdf < scripts/patch_sp_list_users_role_scoped.sql

USE legal_pdf;

DELIMITER $$

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. SUPER ADMIN  — exclude super Admin role, no dept restriction
-- ─────────────────────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS sp_list_users $$

CREATE PROCEDURE sp_list_users(
    IN p_skip            INT,
    IN p_limit           INT,
    IN p_exclude_user_id INT,
    IN p_department_ids  VARCHAR(500),
    IN p_is_active       TINYINT
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin')
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_total,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin') AND u2.is_active = 1
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_active,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin') AND u2.is_active = 0
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_inactive,

        u.id, u.username, u.email, '' AS hashed_password, u.is_active,
        u.must_change_password, u.mobile_number, u.password_changed_at,
        u.first_name, u.last_name, u.role_id, u.department_id,
        u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description,
        (SELECT GROUP_CONCAT(d2.name ORDER BY CAST(TRIM(jt.did) AS UNSIGNED) SEPARATOR '|')
         FROM JSON_TABLE(CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')) jt
         JOIN departments d2 ON d2.id = CAST(TRIM(jt.did) AS UNSIGNED)
         WHERE TRIM(jt.did) != '') AS department_name,
        NULL AS department_description,
        (SELECT created_at FROM user_login_logs
         WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login

    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE (r.name IS NULL OR r.name != 'super Admin')
      AND (p_exclude_user_id IS NULL OR u.id != p_exclude_user_id)
      AND (p_is_active       IS NULL OR u.is_active = p_is_active)
      AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
          SELECT 1 FROM JSON_TABLE(
              CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
          ) udt WHERE TRIM(udt.did) != ''
                  AND FIND_IN_SET(TRIM(udt.did), p_department_ids) > 0
      ))
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. ADMIN  — nodal Officer / approver / uploader, filtered to their dept(s)
-- ─────────────────────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS sp_list_users_admin $$

CREATE PROCEDURE sp_list_users_admin(
    IN p_skip            INT,
    IN p_limit           INT,
    IN p_exclude_user_id INT,
    IN p_department_ids  VARCHAR(500),
    IN p_is_active       TINYINT
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('nodal Officer', 'approver', 'uploader')
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_total,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('nodal Officer', 'approver', 'uploader') AND u2.is_active = 1
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_active,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('nodal Officer', 'approver', 'uploader') AND u2.is_active = 0
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_inactive,

        u.id, u.username, u.email, '' AS hashed_password, u.is_active,
        u.must_change_password, u.mobile_number, u.password_changed_at,
        u.first_name, u.last_name, u.role_id, u.department_id,
        u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description,
        (SELECT GROUP_CONCAT(d2.name ORDER BY CAST(TRIM(jt.did) AS UNSIGNED) SEPARATOR '|')
         FROM JSON_TABLE(CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')) jt
         JOIN departments d2 ON d2.id = CAST(TRIM(jt.did) AS UNSIGNED)
         WHERE TRIM(jt.did) != '') AS department_name,
        NULL AS department_description,
        (SELECT created_at FROM user_login_logs
         WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login

    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE r.name IN ('nodal Officer', 'approver', 'uploader')
      AND (p_exclude_user_id IS NULL OR u.id != p_exclude_user_id)
      AND (p_is_active       IS NULL OR u.is_active = p_is_active)
      AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
          SELECT 1 FROM JSON_TABLE(
              CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
          ) udt WHERE TRIM(udt.did) != ''
                  AND FIND_IN_SET(TRIM(udt.did), p_department_ids) > 0
      ))
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. NODAL OFFICER  — approver / uploader only, filtered to their dept(s)
-- ─────────────────────────────────────────────────────────────────────────────
DROP PROCEDURE IF EXISTS sp_list_users_nodal $$

CREATE PROCEDURE sp_list_users_nodal(
    IN p_skip            INT,
    IN p_limit           INT,
    IN p_exclude_user_id INT,
    IN p_department_ids  VARCHAR(500),
    IN p_is_active       TINYINT
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('approver', 'uploader')
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_total,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('approver', 'uploader') AND u2.is_active = 1
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_active,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE r2.name IN ('approver', 'uploader') AND u2.is_active = 0
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != ''
                        AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_inactive,

        u.id, u.username, u.email, '' AS hashed_password, u.is_active,
        u.must_change_password, u.mobile_number, u.password_changed_at,
        u.first_name, u.last_name, u.role_id, u.department_id,
        u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description,
        (SELECT GROUP_CONCAT(d2.name ORDER BY CAST(TRIM(jt.did) AS UNSIGNED) SEPARATOR '|')
         FROM JSON_TABLE(CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')) jt
         JOIN departments d2 ON d2.id = CAST(TRIM(jt.did) AS UNSIGNED)
         WHERE TRIM(jt.did) != '') AS department_name,
        NULL AS department_description,
        (SELECT created_at FROM user_login_logs
         WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login

    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE r.name IN ('approver', 'uploader')
      AND (p_exclude_user_id IS NULL OR u.id != p_exclude_user_id)
      AND (p_is_active       IS NULL OR u.is_active = p_is_active)
      AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
          SELECT 1 FROM JSON_TABLE(
              CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
          ) udt WHERE TRIM(udt.did) != ''
                  AND FIND_IN_SET(TRIM(udt.did), p_department_ids) > 0
      ))
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_users (super admin), sp_list_users_admin, sp_list_users_nodal — all created.' AS status;
