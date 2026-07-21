USE legal_pdf;

DELIMITER $$

-- ── Roles ──────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_role_by_id $$
CREATE PROCEDURE sp_get_role_by_id(IN p_role_id INT)
BEGIN
    SELECT id, name, description, created_at FROM roles WHERE id = p_role_id;
END $$

DROP PROCEDURE IF EXISTS sp_list_roles $$
CREATE PROCEDURE sp_list_roles(IN p_skip INT, IN p_limit INT)
BEGIN
    SELECT id, name, description, created_at FROM roles ORDER BY id LIMIT p_limit OFFSET p_skip;
END $$

-- ── Departments ────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_department_by_id $$
CREATE PROCEDURE sp_get_department_by_id(IN p_department_id INT)
BEGIN
    SELECT id, name, description, is_active, created_at FROM departments WHERE id = p_department_id;
END $$

DROP PROCEDURE IF EXISTS sp_create_department $$
CREATE PROCEDURE sp_create_department(IN p_name VARCHAR(100), IN p_description TEXT)
BEGIN
    INSERT INTO departments (name, description, is_active, created_at)
    VALUES (p_name, p_description, 1, UTC_TIMESTAMP(6));
    SELECT id, name, description, is_active, created_at FROM departments WHERE id = LAST_INSERT_ID();
END $$

DROP PROCEDURE IF EXISTS sp_list_departments $$
CREATE PROCEDURE sp_list_departments(IN p_skip INT, IN p_limit INT)
BEGIN
    SELECT id, name, description, is_active, created_at
    FROM departments
    ORDER BY name
    LIMIT p_limit OFFSET p_skip;
END $$

DROP PROCEDURE IF EXISTS sp_toggle_department_status $$
CREATE PROCEDURE sp_toggle_department_status(IN p_department_id INT)
BEGIN
    UPDATE departments
    SET is_active = IF(is_active = 1, 0, 1)
    WHERE id = p_department_id;
    SELECT id, name, description, is_active, created_at FROM departments WHERE id = p_department_id;
END $$

-- ── Document Types ─────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_list_document_types $$
CREATE PROCEDURE sp_list_document_types()
BEGIN
    SELECT id, name, description, is_active, created_at FROM document_types ORDER BY name;
END $$

DROP PROCEDURE IF EXISTS sp_get_document_type_by_id $$
CREATE PROCEDURE sp_get_document_type_by_id(IN p_type_id INT)
BEGIN
    SELECT id, name, description, is_active, created_at FROM document_types WHERE id = p_type_id;
END $$

DROP PROCEDURE IF EXISTS sp_create_document_type $$
CREATE PROCEDURE sp_create_document_type(IN p_name VARCHAR(100), IN p_description TEXT)
BEGIN
    INSERT INTO document_types (name, description, is_active, created_at)
    VALUES (p_name, p_description, 1, UTC_TIMESTAMP(6));
    SELECT id, name, description, is_active, created_at FROM document_types WHERE id = LAST_INSERT_ID();
END $$

DROP PROCEDURE IF EXISTS sp_toggle_document_type_status $$
CREATE PROCEDURE sp_toggle_document_type_status(IN p_type_id INT)
BEGIN
    UPDATE document_types SET is_active = IF(is_active = 1, 0, 1) WHERE id = p_type_id;
    SELECT id, name, description, is_active, created_at FROM document_types WHERE id = p_type_id;
END $$

-- ── Tags ───────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_list_tags $$
CREATE PROCEDURE sp_list_tags()
BEGIN
    SELECT t.id, t.name, t.parent_id, t.created_at, p.name AS parent_name
    FROM tags t
    LEFT JOIN tags p ON p.id = t.parent_id
    ORDER BY t.name;
END $$

DROP PROCEDURE IF EXISTS sp_get_tag_by_id $$
CREATE PROCEDURE sp_get_tag_by_id(IN p_tag_id INT)
BEGIN
    SELECT t.id, t.name, t.parent_id, t.created_at, p.name AS parent_name
    FROM tags t
    LEFT JOIN tags p ON p.id = t.parent_id
    WHERE t.id = p_tag_id;
END $$

DROP PROCEDURE IF EXISTS sp_create_tag $$
CREATE PROCEDURE sp_create_tag(IN p_name VARCHAR(100), IN p_parent_id INT)
BEGIN
    INSERT INTO tags (name, parent_id, created_at) VALUES (p_name, p_parent_id, UTC_TIMESTAMP(6));
    SELECT t.id, t.name, t.parent_id, t.created_at, p.name AS parent_name
    FROM tags t
    LEFT JOIN tags p ON p.id = t.parent_id
    WHERE t.id = LAST_INSERT_ID();
END $$

DROP PROCEDURE IF EXISTS sp_save_pdf_document_tags $$
CREATE PROCEDURE sp_save_pdf_document_tags(IN p_pdf_id INT, IN p_tag_ids VARCHAR(500))
BEGIN
    DELETE FROM pdf_document_tags WHERE pdf_id = p_pdf_id;
    IF p_tag_ids IS NOT NULL AND p_tag_ids != '' THEN
        INSERT INTO pdf_document_tags (pdf_id, tag_id)
        SELECT p_pdf_id, CAST(TRIM(jt.tag_id) AS UNSIGNED)
        FROM JSON_TABLE(
            CONCAT('["', REPLACE(p_tag_ids, ',', '","'), '"]'),
            '$[*]' COLUMNS (tag_id VARCHAR(10) PATH '$')
        ) jt
        WHERE TRIM(jt.tag_id) != '';
    END IF;
END $$

-- ── Users ──────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_user_by_id $$
CREATE PROCEDURE sp_get_user_by_id(IN p_user_id INT)
BEGIN
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.id = p_user_id;
END $$

DROP PROCEDURE IF EXISTS sp_get_user_by_username $$
CREATE PROCEDURE sp_get_user_by_username(IN p_username VARCHAR(100))
BEGIN
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.username = p_username;
END $$

DROP PROCEDURE IF EXISTS sp_get_user_by_email $$
CREATE PROCEDURE sp_get_user_by_email(IN p_email VARCHAR(255))
BEGIN
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.email = p_email;
END $$

DROP PROCEDURE IF EXISTS sp_get_user_by_mobile $$
CREATE PROCEDURE sp_get_user_by_mobile(IN p_mobile_number VARCHAR(20))
BEGIN
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE u.mobile_number = p_mobile_number;
END $$

DROP PROCEDURE IF EXISTS sp_create_user $$
CREATE PROCEDURE sp_create_user(
    IN p_username      VARCHAR(100),
    IN p_email         VARCHAR(255),
    IN p_hashed_password VARCHAR(255),
    IN p_first_name    VARCHAR(100),
    IN p_last_name     VARCHAR(100),
    IN p_role_id       INT,
    IN p_department_id VARCHAR(500),
    IN p_mobile_number VARCHAR(20)
)
BEGIN
    INSERT INTO users (username, email, hashed_password, first_name, last_name, role_id, department_id, mobile_number, is_active, must_change_password, created_at, updated_at)
    VALUES (p_username, p_email, p_hashed_password, p_first_name, p_last_name, p_role_id, p_department_id, p_mobile_number, 1, 1, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6));

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
END $$

DROP PROCEDURE IF EXISTS sp_update_user $$
CREATE PROCEDURE sp_update_user(
    IN p_user_id       INT,
    IN p_first_name    VARCHAR(100),
    IN p_last_name     VARCHAR(100),
    IN p_email         VARCHAR(255),
    IN p_is_active     TINYINT(1),
    IN p_role_id       INT,
    IN p_department_id VARCHAR(500)
)
BEGIN
    UPDATE users SET
        first_name    = IFNULL(p_first_name,    first_name),
        last_name     = IFNULL(p_last_name,     last_name),
        email         = IFNULL(p_email,         email),
        is_active     = IFNULL(p_is_active,     is_active),
        role_id       = IFNULL(p_role_id,       role_id),
        department_id = IFNULL(p_department_id, department_id)
    WHERE id = p_user_id;

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
    WHERE u.id = p_user_id;
END $$

DROP PROCEDURE IF EXISTS sp_list_users $$
CREATE PROCEDURE sp_list_users(
    IN p_skip           INT,
    IN p_limit          INT,
    IN p_exclude_user_id INT,
    IN p_department_ids  VARCHAR(500)
)
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
        (SELECT created_at FROM user_login_logs WHERE user_id = u.id ORDER BY created_at DESC LIMIT 1) AS last_login
    FROM users u
    LEFT JOIN roles r ON r.id = u.role_id
    WHERE (r.name IS NULL OR r.name != 'super Admin')
      AND (p_exclude_user_id IS NULL OR u.id != p_exclude_user_id)
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

DROP PROCEDURE IF EXISTS sp_change_password $$
CREATE PROCEDURE sp_change_password(IN p_user_id INT, IN p_hashed_password VARCHAR(255))
BEGIN
    UPDATE users
    SET hashed_password      = p_hashed_password,
        must_change_password = 0,
        password_changed_at  = UTC_TIMESTAMP(6)
    WHERE id = p_user_id;
END $$

-- ── Audit Log ──────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_create_audit_log $$
CREATE PROCEDURE sp_create_audit_log(
    IN p_user_id     INT,
    IN p_action      VARCHAR(100),
    IN p_entity_type VARCHAR(50),
    IN p_entity_id   INT,
    IN p_details     TEXT,
    IN p_ip_address  VARCHAR(45),
    IN p_status      VARCHAR(20)
)
BEGIN
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, ip_address, status, created_at)
    VALUES (p_user_id, p_action, p_entity_type, p_entity_id, p_details, p_ip_address, IFNULL(p_status,'success'), UTC_TIMESTAMP(6));
END $$

DROP PROCEDURE IF EXISTS sp_list_audit_logs $$
CREATE PROCEDURE sp_list_audit_logs(
    IN p_skip            INT,
    IN p_limit           INT,
    IN p_user_id         INT,
    IN p_action          VARCHAR(100),
    IN p_entity_type     VARCHAR(50),
    IN p_from_date       DATETIME,
    IN p_to_date         DATETIME,
    IN p_exclude_user_id INT,
    IN p_dept_ids        VARCHAR(500)
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total,
        al.id, al.user_id, al.action, al.entity_type, al.entity_id,
        al.details, al.ip_address, al.status, al.created_at,
        u.username   AS actor_username,
        u.first_name AS actor_first_name,
        u.last_name  AS actor_last_name
    FROM audit_logs al
    LEFT JOIN users u ON u.id = al.user_id
    WHERE (p_user_id     IS NULL OR al.user_id     = p_user_id)
      AND (p_action      IS NULL OR al.action      = p_action)
      AND (p_entity_type IS NULL OR al.entity_type = p_entity_type)
      AND (p_from_date   IS NULL OR al.created_at >= p_from_date)
      AND (p_to_date     IS NULL OR al.created_at <= p_to_date)
      AND (p_exclude_user_id IS NULL OR al.user_id != p_exclude_user_id)
      AND (p_dept_ids IS NULL OR p_dept_ids = '' OR EXISTS (
          SELECT 1 FROM JSON_TABLE(
              CONCAT('["', REPLACE(IFNULL(u.department_id,''), ',', '","'), '"]'),
              '$[*]' COLUMNS (did VARCHAR(10) PATH '$')
          ) udt
          WHERE TRIM(udt.did) != '' AND FIND_IN_SET(TRIM(udt.did), p_dept_ids) > 0
      ))
    ORDER BY al.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

-- ── Login Log ──────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_log_user_action $$
CREATE PROCEDURE sp_log_user_action(IN p_user_id INT, IN p_action VARCHAR(50), IN p_ip_address VARCHAR(45))
BEGIN
    INSERT INTO user_login_logs (user_id, action, ip_address, created_at)
    VALUES (p_user_id, p_action, p_ip_address, UTC_TIMESTAMP(6));
END $$

-- ── Password Reset OTP ─────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_create_reset_otp $$
CREATE PROCEDURE sp_create_reset_otp(
    IN p_user_id    INT,
    IN p_otp_hash   VARCHAR(255),
    IN p_channel    VARCHAR(20),
    IN p_expires_at DATETIME
)
BEGIN
    UPDATE password_reset_otps SET is_used = 1 WHERE user_id = p_user_id AND is_used = 0;
    INSERT INTO password_reset_otps (user_id, otp_hash, channel, expires_at, is_used, created_at)
    VALUES (p_user_id, p_otp_hash, p_channel, p_expires_at, 0, UTC_TIMESTAMP(6));
END $$

DROP PROCEDURE IF EXISTS sp_get_valid_reset_otp $$
CREATE PROCEDURE sp_get_valid_reset_otp(IN p_user_id INT)
BEGIN
    SELECT id, user_id, otp_hash, channel, expires_at, is_used, created_at
    FROM password_reset_otps
    WHERE user_id = p_user_id AND is_used = 0 AND expires_at > UTC_TIMESTAMP(6)
    ORDER BY created_at DESC
    LIMIT 1;
END $$

DROP PROCEDURE IF EXISTS sp_mark_otp_used $$
CREATE PROCEDURE sp_mark_otp_used(IN p_otp_id INT)
BEGIN
    UPDATE password_reset_otps SET is_used = 1 WHERE id = p_otp_id;
END $$

-- ── Admin Login OTP ────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_create_admin_login_otp $$
CREATE PROCEDURE sp_create_admin_login_otp(
    IN p_user_id    INT,
    IN p_otp_hash   VARCHAR(255),
    IN p_expires_at DATETIME
)
BEGIN
    UPDATE admin_login_otps SET is_used = 1 WHERE user_id = p_user_id AND is_used = 0;
    INSERT INTO admin_login_otps (user_id, otp_hash, expires_at, is_used, created_at)
    VALUES (p_user_id, p_otp_hash, p_expires_at, 0, UTC_TIMESTAMP(6));
END $$

DROP PROCEDURE IF EXISTS sp_get_valid_admin_login_otp $$
CREATE PROCEDURE sp_get_valid_admin_login_otp(IN p_user_id INT)
BEGIN
    SELECT id, user_id, otp_hash, expires_at, is_used, created_at
    FROM admin_login_otps
    WHERE user_id = p_user_id AND is_used = 0 AND expires_at > UTC_TIMESTAMP(6)
    ORDER BY created_at DESC
    LIMIT 1;
END $$

DROP PROCEDURE IF EXISTS sp_mark_admin_login_otp_used $$
CREATE PROCEDURE sp_mark_admin_login_otp_used(IN p_otp_id INT)
BEGIN
    UPDATE admin_login_otps SET is_used = 1 WHERE id = p_otp_id;
END $$

-- ── PDF Pages / FTS ────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_save_pdf_page $$
CREATE PROCEDURE sp_save_pdf_page(
    IN p_doc_id    INT,
    IN p_page_num  INT,
    IN p_page_text LONGTEXT
)
BEGIN
    INSERT INTO pdf_pages (pdf_document_id, page_number, page_text, created_at)
    VALUES (p_doc_id, p_page_num, p_page_text, UTC_TIMESTAMP(6));
END $$

DROP PROCEDURE IF EXISTS sp_search_pdf_pages $$
CREATE PROCEDURE sp_search_pdf_pages(IN p_term VARCHAR(500), IN p_skip INT, IN p_limit INT)
BEGIN
    SELECT
        pp.pdf_document_id AS pdf_id,
        p.original_filename,
        pp.page_number,
        MATCH(pp.page_text) AGAINST(p_term IN BOOLEAN MODE) AS relevance_score,
        pp.page_text
    FROM pdf_pages pp
    JOIN pdf_documents p ON p.id = pp.pdf_document_id
    WHERE MATCH(pp.page_text) AGAINST(p_term IN BOOLEAN MODE)
    ORDER BY relevance_score DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DROP PROCEDURE IF EXISTS sp_delete_pdf_pages_by_doc $$
CREATE PROCEDURE sp_delete_pdf_pages_by_doc(IN p_doc_id INT)
BEGIN
    DELETE FROM pdf_pages WHERE pdf_document_id = p_doc_id;
END $$

-- ── PDF Documents ──────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_create_pdf_document $$
CREATE PROCEDURE sp_create_pdf_document(
    IN p_filename             VARCHAR(255),
    IN p_original_filename    VARCHAR(255),
    IN p_file_path            VARCHAR(500),
    IN p_file_size            BIGINT,
    IN p_uploaded_by          INT,
    IN p_document_name        VARCHAR(500),
    IN p_reference_number     VARCHAR(100),
    IN p_issue_date           DATE,
    IN p_effective_from       DATE,
    IN p_gazette_reference    VARCHAR(500),
    IN p_legal_authority      VARCHAR(255),
    IN p_short_title          VARCHAR(255),
    IN p_valid_until          DATE,
    IN p_sector_domain        VARCHAR(255),
    IN p_implementing_agency  VARCHAR(255),
    IN p_next_review_date     DATE,
    IN p_rule_making_authority VARCHAR(255),
    IN p_version_no           VARCHAR(50),
    IN p_department_id        INT,
    IN p_document_type_id     INT,
    IN p_description          TEXT,
    IN p_summary              LONGTEXT,
    IN p_act_year             INT,
    IN p_long_title           TEXT,
    IN p_regional_title       TEXT,
    IN p_notification_no      VARCHAR(100),
    IN p_act_code             VARCHAR(100),
    IN p_so_reason            TEXT,
    IN p_no_of_rules          INT,
    IN p_no_of_notifications  INT,
    IN p_no_of_regulations    INT,
    IN p_no_of_circulars      INT,
    IN p_no_of_statutes       INT,
    IN p_no_of_ordinances     INT,
    IN p_no_of_orders         INT,
    IN p_keywords             TEXT,
    IN p_is_repealed          TINYINT(1)
)
BEGIN
    INSERT INTO pdf_documents (
        filename, original_filename, file_path, file_size, uploaded_by,
        document_name, reference_number, issue_date, effective_from,
        gazette_reference, legal_authority, short_title, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        version_no, department_id, document_type_id, description, summary,
        act_year, long_title, regional_title, notification_no, act_code, so_reason,
        no_of_rules, no_of_notifications, no_of_regulations, no_of_circulars,
        no_of_statutes, no_of_ordinances, no_of_orders, keywords, is_repealed,
        status, created_at
    ) VALUES (
        p_filename, p_original_filename, p_file_path, p_file_size, p_uploaded_by,
        p_document_name, p_reference_number, p_issue_date, p_effective_from,
        p_gazette_reference, p_legal_authority, p_short_title, p_valid_until,
        p_sector_domain, p_implementing_agency, p_next_review_date, p_rule_making_authority,
        p_version_no, p_department_id, p_document_type_id, p_description, p_summary,
        p_act_year, p_long_title, p_regional_title, p_notification_no, p_act_code, p_so_reason,
        p_no_of_rules, p_no_of_notifications, p_no_of_regulations, p_no_of_circulars,
        p_no_of_statutes, p_no_of_ordinances, p_no_of_orders, p_keywords, IFNULL(p_is_repealed,0),
        'pending', UTC_TIMESTAMP(6)
    );

    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.uploaded_by, p.created_at,
        dt.name AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        NULL AS tags,
        NULL AS relationships,
        NULL AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.id = LAST_INSERT_ID();
END $$

DROP PROCEDURE IF EXISTS sp_get_pdf_by_id $$
CREATE PROCEDURE sp_get_pdf_by_id(IN p_document_id INT)
BEGIN
    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id,':',t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id
         WHERE pdt.pdf_id = p.id) AS tags,
        (SELECT CAST(CONCAT('[', GROUP_CONCAT(
             JSON_OBJECT('pdf_id', r.target_pdf_id, 'document_name', rp.document_name, 'type', r.relationship_type)
             SEPARATOR ','), ']') AS CHAR)
         FROM pdf_document_relationships r
         LEFT JOIN pdf_documents rp ON rp.id = r.target_pdf_id
         WHERE r.source_pdf_id = p.id) AS relationships,
        (SELECT CAST(JSON_OBJECT(
             'action', a.action, 'comments', a.comments, 'annotations_json', a.annotations_json,
             'acted_at', a.acted_at, 'approver_username', au.username,
             'approver_first_name', au.first_name, 'approver_last_name', au.last_name
         ) AS CHAR)
         FROM pdf_document_approvals a JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id ORDER BY a.acted_at DESC LIMIT 1) AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.id = p_document_id;
END $$

DROP PROCEDURE IF EXISTS sp_list_pdfs_by_user $$
CREATE PROCEDURE sp_list_pdfs_by_user(IN p_user_id INT, IN p_skip INT, IN p_limit INT)
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
        (SELECT CAST(JSON_OBJECT('action', a.action, 'comments', a.comments, 'annotations_json', a.annotations_json,
             'acted_at', a.acted_at, 'approver_username', au.username,
             'approver_first_name', au.first_name, 'approver_last_name', au.last_name) AS CHAR)
         FROM pdf_document_approvals a JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id ORDER BY a.acted_at DESC LIMIT 1) AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.uploaded_by = p_user_id
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$
CREATE PROCEDURE sp_list_all_pdfs(IN p_skip INT, IN p_limit INT, IN p_status VARCHAR(20))
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
        (SELECT CAST(JSON_OBJECT('action', a.action, 'comments', a.comments, 'annotations_json', a.annotations_json,
             'acted_at', a.acted_at, 'approver_username', au.username,
             'approver_first_name', au.first_name, 'approver_last_name', au.last_name) AS CHAR)
         FROM pdf_document_approvals a JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id ORDER BY a.acted_at DESC LIMIT 1) AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE (p_status IS NULL OR p.status = p_status)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DROP PROCEDURE IF EXISTS sp_get_pending_pdfs $$
CREATE PROCEDURE sp_get_pending_pdfs(IN p_skip INT, IN p_limit INT)
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
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DROP PROCEDURE IF EXISTS sp_review_pdf_document $$
CREATE PROCEDURE sp_review_pdf_document(
    IN p_pdf_id          INT,
    IN p_approver_id     INT,
    IN p_action          VARCHAR(20),
    IN p_comments        TEXT,
    IN p_annotations_json LONGTEXT
)
BEGIN
    UPDATE pdf_documents SET status = p_action WHERE id = p_pdf_id;

    INSERT INTO pdf_document_approvals (pdf_id, approver_id, action, comments, annotations_json, acted_at)
    VALUES (p_pdf_id, p_approver_id, p_action, p_comments, p_annotations_json, UTC_TIMESTAMP(6));

    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.version_no,
        p.department_id, p.document_type_id, p.description, p.summary, p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        NULL AS tags,
        NULL AS relationships,
        (SELECT CAST(JSON_OBJECT('action', a.action, 'comments', a.comments, 'annotations_json', a.annotations_json,
             'acted_at', a.acted_at, 'approver_username', au.username,
             'approver_first_name', au.first_name, 'approver_last_name', au.last_name) AS CHAR)
         FROM pdf_document_approvals a JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id ORDER BY a.acted_at DESC LIMIT 1) AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.id = p_pdf_id;
END $$

DROP PROCEDURE IF EXISTS sp_search_documents_by_type $$
CREATE PROCEDURE sp_search_documents_by_type(
    IN p_document_type VARCHAR(100),
    IN p_q             VARCHAR(500),
    IN p_limit         INT
)
BEGIN
    SELECT p.id, p.document_name, p.reference_number, p.status, dt.name AS document_type_name
    FROM pdf_documents p
    JOIN document_types dt ON dt.id = p.document_type_id
    WHERE dt.name = p_document_type
      AND p.document_name LIKE CONCAT('%', p_q, '%')
      AND p.status = 'approved'
    ORDER BY p.document_name
    LIMIT p_limit;
END $$

DROP PROCEDURE IF EXISTS sp_check_duplicate_document $$
CREATE PROCEDURE sp_check_duplicate_document(
    IN p_document_name    VARCHAR(500),
    IN p_document_type_id INT,
    IN p_caller_dept_id   INT
)
BEGIN
    SELECT
        p.id, p.document_name, p.version_no, p.status, p.created_at,
        p.department_id,
        dep.name AS department_name,
        dt.name  AS document_type_name,
        u.username AS uploader_username,
        CASE WHEN p.department_id = p_caller_dept_id THEN 'own_dept' ELSE 'other_dept' END AS match_type
    FROM pdf_documents p
    JOIN document_types dt ON dt.id = p.document_type_id
    LEFT JOIN departments dep ON dep.id = p.department_id
    LEFT JOIN users u ON u.id = p.uploaded_by
    WHERE p.document_name = p_document_name
      AND p.document_type_id = p_document_type_id;
END $$

DROP PROCEDURE IF EXISTS sp_save_pdf_relationships $$
CREATE PROCEDURE sp_save_pdf_relationships(IN p_source_pdf_id INT, IN p_relationships JSON)
BEGIN
    DELETE FROM pdf_document_relationships WHERE source_pdf_id = p_source_pdf_id;
    INSERT INTO pdf_document_relationships (source_pdf_id, target_pdf_id, relationship_type, created_at)
    SELECT p_source_pdf_id, jt.pdf_id, jt.rel_type, UTC_TIMESTAMP(6)
    FROM JSON_TABLE(p_relationships, '$[*]' COLUMNS (
        pdf_id   INT          PATH '$.pdf_id',
        rel_type VARCHAR(50)  PATH '$.type'
    )) jt
    WHERE jt.pdf_id IS NOT NULL;
END $$

-- ── Department Links ───────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_link_document_to_department $$
CREATE PROCEDURE sp_link_document_to_department(
    IN p_pdf_id        INT,
    IN p_department_id INT,
    IN p_linked_by     INT
)
BEGIN
    INSERT INTO pdf_document_department_links (pdf_id, department_id, linked_by, status, created_at)
    VALUES (p_pdf_id, p_department_id, p_linked_by, 'pending', UTC_TIMESTAMP(6))
    ON DUPLICATE KEY UPDATE status = 'pending', linked_by = p_linked_by, created_at = UTC_TIMESTAMP(6);

    SELECT
        lnk.id AS link_id, lnk.pdf_id, lnk.status AS link_status,
        lnk.created_at AS requested_at, lnk.reviewed_at,
        lnk.review_comments, lnk.annotations_json,
        p.document_name, p.version_no, p.status AS document_status,
        dt.name AS document_type_name,
        od.name AS original_department_name,
        u.username   AS requested_by_username,
        u.first_name AS requested_by_first_name,
        u.last_name  AS requested_by_last_name,
        NULL AS reviewed_by_username,
        NULL AS reviewed_by_first_name,
        NULL AS reviewed_by_last_name
    FROM pdf_document_department_links lnk
    JOIN pdf_documents p      ON p.id   = lnk.pdf_id
    LEFT JOIN document_types dt ON dt.id = p.document_type_id
    LEFT JOIN departments od    ON od.id = p.department_id
    LEFT JOIN users u           ON u.id  = lnk.linked_by
    WHERE lnk.pdf_id = p_pdf_id AND lnk.department_id = p_department_id;
END $$

DROP PROCEDURE IF EXISTS sp_get_department_links $$
CREATE PROCEDURE sp_get_department_links(IN p_department_id INT, IN p_status VARCHAR(20))
BEGIN
    SELECT
        lnk.id AS link_id, lnk.pdf_id, lnk.status AS link_status,
        lnk.created_at AS requested_at, lnk.reviewed_at,
        lnk.review_comments, lnk.annotations_json,
        p.document_name, p.version_no, p.status AS document_status,
        dt.name AS document_type_name,
        od.name AS original_department_name,
        req.username   AS requested_by_username,
        req.first_name AS requested_by_first_name,
        req.last_name  AS requested_by_last_name,
        rev.username   AS reviewed_by_username,
        rev.first_name AS reviewed_by_first_name,
        rev.last_name  AS reviewed_by_last_name
    FROM pdf_document_department_links lnk
    JOIN pdf_documents p       ON p.id   = lnk.pdf_id
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments od     ON od.id  = p.department_id
    LEFT JOIN users req          ON req.id = lnk.linked_by
    LEFT JOIN users rev          ON rev.id = lnk.reviewed_by
    WHERE lnk.department_id = p_department_id
      AND (p_status IS NULL OR lnk.status = p_status)
    ORDER BY lnk.created_at DESC;
END $$

DROP PROCEDURE IF EXISTS sp_review_department_link $$
CREATE PROCEDURE sp_review_department_link(
    IN p_link_id          INT,
    IN p_action           VARCHAR(20),
    IN p_reviewed_by      INT,
    IN p_review_comments  TEXT,
    IN p_annotations_json LONGTEXT
)
BEGIN
    UPDATE pdf_document_department_links
    SET status           = p_action,
        reviewed_by      = p_reviewed_by,
        reviewed_at      = UTC_TIMESTAMP(6),
        review_comments  = p_review_comments,
        annotations_json = p_annotations_json
    WHERE id = p_link_id;
END $$

DROP PROCEDURE IF EXISTS sp_get_linked_documents_for_department $$
CREATE PROCEDURE sp_get_linked_documents_for_department(IN p_department_id INT, IN p_status VARCHAR(20))
BEGIN
    SELECT
        p.id, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.version_no, p.reference_number, p.issue_date,
        p.document_type_id, p.department_id, p.uploaded_by, p.created_at,
        dt.name AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        lnk.id AS link_id, lnk.status AS link_status,
        lnk.review_comments, lnk.reviewed_at,
        lnk.annotations_json AS link_annotations_json,
        rev.username   AS link_reviewed_by_username,
        rev.first_name AS link_reviewed_by_first_name,
        rev.last_name  AS link_reviewed_by_last_name
    FROM pdf_document_department_links lnk
    JOIN pdf_documents p       ON p.id   = lnk.pdf_id
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments dep    ON dep.id = p.department_id
    LEFT JOIN users u            ON u.id   = p.uploaded_by
    LEFT JOIN users rev          ON rev.id = lnk.reviewed_by
    WHERE lnk.department_id = p_department_id
      AND (p_status IS NULL OR lnk.status = p_status)
    ORDER BY lnk.created_at DESC;
END $$

DROP PROCEDURE IF EXISTS sp_get_all_department_links $$
CREATE PROCEDURE sp_get_all_department_links(IN p_status VARCHAR(20), IN p_department_id INT)
BEGIN
    SELECT
        lnk.id AS link_id, lnk.pdf_id, lnk.status AS link_status,
        lnk.created_at AS requested_at, lnk.reviewed_at,
        lnk.review_comments, lnk.annotations_json,
        p.document_name, p.version_no, p.status AS document_status,
        dt.name  AS document_type_name,
        od.name  AS original_department_name,
        ld.name  AS linked_department_name,
        req.username   AS requested_by_username,
        req.first_name AS requested_by_first_name,
        req.last_name  AS requested_by_last_name,
        rev.username   AS reviewed_by_username,
        rev.first_name AS reviewed_by_first_name,
        rev.last_name  AS reviewed_by_last_name
    FROM pdf_document_department_links lnk
    JOIN pdf_documents p       ON p.id   = lnk.pdf_id
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments od     ON od.id  = p.department_id
    LEFT JOIN departments ld     ON ld.id  = lnk.department_id
    LEFT JOIN users req          ON req.id = lnk.linked_by
    LEFT JOIN users rev          ON rev.id = lnk.reviewed_by
    WHERE (p_status IS NULL OR lnk.status = p_status)
      AND (p_department_id IS NULL OR lnk.department_id = p_department_id)
    ORDER BY lnk.created_at DESC;
END $$

DROP PROCEDURE IF EXISTS sp_get_documents_under_act $$
CREATE PROCEDURE sp_get_documents_under_act(IN p_act_id INT)
BEGIN
    SELECT
        p.id, p.document_name, p.reference_number, p.issue_date, p.status,
        p.version_no, p.effective_from, p.gazette_reference, p.legal_authority,
        p.short_title, p.act_year, p.long_title, p.regional_title,
        p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.valid_until, p.sector_domain, p.implementing_agency, p.next_review_date,
        p.rule_making_authority,
        p.description, p.summary,
        p.department_id, p.document_type_id,
        p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        r.relationship_type
    FROM pdf_document_relationships r
    JOIN pdf_documents p       ON p.id   = r.source_pdf_id
    JOIN document_types dt     ON dt.id  = p.document_type_id
    LEFT JOIN departments dep   ON dep.id = p.department_id
    LEFT JOIN users u           ON u.id   = p.uploaded_by
    WHERE r.target_pdf_id = p_act_id
      AND r.relationship_type = 'parent_act'
    ORDER BY dt.name, p.issue_date DESC;
END $$

DELIMITER ;