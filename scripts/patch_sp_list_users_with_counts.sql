-- Adds count_total/active/inactive stat columns and p_is_active status filter
-- to sp_list_users, enabling:
--   - Correct stat card totals regardless of pagination limit
--   - Server-side status filtering so pagination totals are accurate
--
-- New columns returned on every row:
--   total_count    — rows matching current filters (use for pagination)
--   count_total    — all non-super-Admin users in scope (stat card: Total)
--   count_active   — active non-super-Admin users in scope (stat card: Active)
--   count_inactive — inactive non-super-Admin users in scope (stat card: Inactive)
--
-- New parameter:
--   p_is_active TINYINT  — NULL=all, 1=active only, 0=inactive only
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_list_users_with_counts.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_users $$

CREATE PROCEDURE sp_list_users(
    IN p_skip            INT,
    IN p_limit           INT,
    IN p_exclude_user_id INT,           -- NULL = no exclusion; typically the calling user's id
    IN p_department_ids  VARCHAR(500),  -- NULL or '' = no dept filter; CSV e.g. '1,2,3'
    IN p_is_active       TINYINT        -- NULL=all, 1=active only, 0=inactive only
)
BEGIN
    SELECT
        -- Pagination count (respects p_is_active filter)
        COUNT(*) OVER() AS total_count,

        -- Global stat counts — always unfiltered by p_is_active (for stat cards)
        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin')
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != '' AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_total,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin') AND u2.is_active = 1
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != '' AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_active,

        (SELECT COUNT(*) FROM users u2 LEFT JOIN roles r2 ON r2.id = u2.role_id
         WHERE (r2.name IS NULL OR r2.name != 'super Admin') AND u2.is_active = 0
           AND (p_exclude_user_id IS NULL OR u2.id != p_exclude_user_id)
           AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
               SELECT 1 FROM JSON_TABLE(
                   CONCAT('["', REPLACE(IFNULL(u2.department_id,''), ',', '","'), '"]'),
                   '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
               ) udt2 WHERE TRIM(udt2.did) != '' AND FIND_IN_SET(TRIM(udt2.did), p_department_ids) > 0
           ))
        ) AS count_inactive,

        -- User columns (unchanged from base schema)
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login

    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE (r.name IS NULL OR r.name != 'super Admin')
      AND (p_exclude_user_id IS NULL OR u.id != p_exclude_user_id)
      AND (p_is_active       IS NULL OR u.is_active = p_is_active)
      AND (p_department_ids IS NULL OR p_department_ids = '' OR EXISTS (
          SELECT 1 FROM JSON_TABLE(
              CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
          ) udt
          WHERE TRIM(udt.did) != '' AND FIND_IN_SET(TRIM(udt.did), p_department_ids) > 0
      ))
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_users patched — p_is_active filter + count columns added.' AS status;
