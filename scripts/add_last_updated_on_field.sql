-- Adds last_updated_on DATE NULL column to pdf_documents and updates all
-- stored procedures that read or write this table.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_last_updated_on_field.sql

USE legal_pdf;

DELIMITER $$

-- 1. Add the column (idempotent — skip if already exists)
ALTER TABLE pdf_documents
  ADD COLUMN last_updated_on DATE NULL AFTER is_repealed $$

-- 2. sp_create_pdf_document — add p_last_updated_on parameter
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
    IN p_is_repealed          TINYINT(1),
    IN p_last_updated_on      DATE
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
        last_updated_on, status, created_at
    ) VALUES (
        p_filename, p_original_filename, p_file_path, p_file_size, p_uploaded_by,
        p_document_name, p_reference_number, p_issue_date, p_effective_from,
        p_gazette_reference, p_legal_authority, p_short_title, p_valid_until,
        p_sector_domain, p_implementing_agency, p_next_review_date, p_rule_making_authority,
        p_version_no, p_department_id, p_document_type_id, p_description, p_summary,
        p_act_year, p_long_title, p_regional_title, p_notification_no, p_act_code, p_so_reason,
        p_no_of_rules, p_no_of_notifications, p_no_of_regulations, p_no_of_circulars,
        p_no_of_statutes, p_no_of_ordinances, p_no_of_orders, p_keywords, IFNULL(p_is_repealed,0),
        p_last_updated_on, 'pending', UTC_TIMESTAMP(6)
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
        p.last_updated_on, p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
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

-- 3. sp_update_pdf_document — add p_last_updated_on parameter
DROP PROCEDURE IF EXISTS sp_update_pdf_document $$
CREATE PROCEDURE sp_update_pdf_document(
    IN p_document_id          INT,
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
    IN p_is_repealed          TINYINT(1),
    IN p_last_updated_on      DATE
)
BEGIN
    UPDATE pdf_documents SET
        document_name         = IFNULL(p_document_name,         document_name),
        reference_number      = IFNULL(p_reference_number,      reference_number),
        issue_date            = IFNULL(p_issue_date,            issue_date),
        effective_from        = IFNULL(p_effective_from,        effective_from),
        gazette_reference     = IFNULL(p_gazette_reference,     gazette_reference),
        legal_authority       = IFNULL(p_legal_authority,       legal_authority),
        short_title           = IFNULL(p_short_title,           short_title),
        valid_until           = IFNULL(p_valid_until,           valid_until),
        sector_domain         = IFNULL(p_sector_domain,         sector_domain),
        implementing_agency   = IFNULL(p_implementing_agency,   implementing_agency),
        next_review_date      = IFNULL(p_next_review_date,      next_review_date),
        rule_making_authority = IFNULL(p_rule_making_authority, rule_making_authority),
        version_no            = IFNULL(p_version_no,            version_no),
        department_id         = IFNULL(p_department_id,         department_id),
        document_type_id      = IFNULL(p_document_type_id,      document_type_id),
        description           = IFNULL(p_description,           description),
        act_year              = IFNULL(p_act_year,              act_year),
        long_title            = IFNULL(p_long_title,            long_title),
        regional_title        = IFNULL(p_regional_title,        regional_title),
        notification_no       = IFNULL(p_notification_no,       notification_no),
        act_code              = IFNULL(p_act_code,              act_code),
        so_reason             = IFNULL(p_so_reason,             so_reason),
        no_of_rules           = IFNULL(p_no_of_rules,           no_of_rules),
        no_of_notifications   = IFNULL(p_no_of_notifications,   no_of_notifications),
        no_of_regulations     = IFNULL(p_no_of_regulations,     no_of_regulations),
        no_of_circulars       = IFNULL(p_no_of_circulars,       no_of_circulars),
        no_of_statutes        = IFNULL(p_no_of_statutes,        no_of_statutes),
        no_of_ordinances      = IFNULL(p_no_of_ordinances,      no_of_ordinances),
        no_of_orders          = IFNULL(p_no_of_orders,          no_of_orders),
        keywords              = IFNULL(p_keywords,              keywords),
        is_repealed           = IFNULL(p_is_repealed,           is_repealed),
        last_updated_on       = p_last_updated_on
    WHERE id = p_document_id;

    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at,
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

-- 4. sp_get_pdf_by_id — add last_updated_on to SELECT
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
        p.last_updated_on, p.uploaded_by, p.created_at,
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

-- 5. sp_list_pdfs_by_user — add last_updated_on to SELECT
DROP PROCEDURE IF EXISTS sp_list_pdfs_by_user $$
CREATE PROCEDURE sp_list_pdfs_by_user(IN p_user_id INT, IN p_skip INT, IN p_limit INT)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id, ':', t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt
         JOIN tags t ON t.id = pdt.tag_id
         WHERE pdt.pdf_id = p.id) AS tags,
        NULL AS relationships,
        (SELECT CAST(JSON_OBJECT(
                 'action',              a.action,
                 'comments',           a.comments,
                 'annotations_json',   a.annotations_json,
                 'acted_at',           a.acted_at,
                 'approver_username',  au.username,
                 'approver_first_name', au.first_name,
                 'approver_last_name',  au.last_name
             ) AS CHAR)
         FROM pdf_document_approvals a
         JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id
         ORDER BY a.acted_at DESC
         LIMIT 1) AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.uploaded_by = p_user_id
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

-- 6. sp_list_all_pdfs — add last_updated_on to SELECT (keeps p_approver_id filter)
DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$
CREATE PROCEDURE sp_list_all_pdfs(
    IN p_skip        INT,
    IN p_limit       INT,
    IN p_status      VARCHAR(20),
    IN p_approver_id INT
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.version_no,
        p.department_id, p.document_type_id, p.description, p.summary,
        p.last_updated_on, p.uploaded_by, p.created_at,
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
    WHERE (p_status      IS NULL OR p.status      = p_status)
      AND (p_approver_id IS NULL OR u.approver_id = p_approver_id)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'add_last_updated_on_field migration complete.' AS status;
