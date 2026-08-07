-- Uploader → Approver mapping
-- Run once against the production database.

-- 1. Add approver_id column to users
ALTER TABLE users
    ADD COLUMN approver_id INT NULL,
    ADD CONSTRAINT fk_users_approver
        FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL;

-- 2. SP: fetch active approvers for a given department (used by the admin "Add User" form)
DROP PROCEDURE IF EXISTS sp_get_approvers_by_department;
DELIMITER $$
CREATE PROCEDURE sp_get_approvers_by_department(IN p_department_id INT)
BEGIN
    SELECT
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
        NULL AS last_login
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.is_active = 1
      AND r.name = 'approver'
      AND FIND_IN_SET(p_department_id, IFNULL(u.department_id, '')) > 0
    ORDER BY u.first_name, u.last_name;
END$$
DELIMITER ;

-- 3. Recreate sp_create_user with new p_approver_id parameter
DROP PROCEDURE IF EXISTS sp_create_user;
DELIMITER $$
CREATE PROCEDURE sp_create_user(
    IN p_username        VARCHAR(100),
    IN p_email           VARCHAR(255),
    IN p_hashed_password VARCHAR(255),
    IN p_first_name      VARCHAR(100),
    IN p_last_name       VARCHAR(100),
    IN p_role_id         INT,
    IN p_department_id   VARCHAR(500),
    IN p_mobile_number   VARCHAR(20),
    IN p_approver_id     INT
)
BEGIN
    INSERT INTO users (
        username, email, hashed_password, first_name, last_name,
        role_id, department_id, mobile_number, approver_id,
        is_active, must_change_password, created_at, updated_at
    ) VALUES (
        p_username, p_email, p_hashed_password, p_first_name, p_last_name,
        p_role_id, p_department_id, p_mobile_number, p_approver_id,
        1, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6)
    );

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
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
        NULL AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.id = LAST_INSERT_ID();
END$$
DELIMITER ;

-- 4. Recreate sp_get_pending_pdfs with p_approver_id filter
--    NULL  → return all pending (admin / super Admin view)
--    <id>  → return only docs uploaded by uploaders mapped to this approver
DROP PROCEDURE IF EXISTS sp_get_pending_pdfs;
DELIMITER $$
CREATE PROCEDURE sp_get_pending_pdfs(IN p_skip INT, IN p_limit INT, IN p_approver_id INT)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.version_no,
        p.department_id, p.document_type_id, p.description, p.summary, p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id,':',t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id WHERE pdt.pdf_id = p.id) AS tags,
        NULL AS relationships,
        NULL AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.status = 'pending'
      AND (p_approver_id IS NULL OR u.approver_id = p_approver_id)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END$$
DELIMITER ;
