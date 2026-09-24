-- Adds pdf_documents.modified_on — a real "last modified" timestamp, auto-set
-- by a DB trigger on every UPDATE to the row, regardless of which stored
-- procedure (or raw UPDATE, e.g. PDFRepository.set_status/resubmit_document)
-- made the change. This mirrors the existing trg_users_updated_at pattern.
--
-- Also patches the stored procedures that read/return a full document row so
-- the new column actually reaches the API response: create, update, get-by-id,
-- the uploader's own list, replace-file, and the Admin/Super-Admin "All
-- Uploads" listings. Citizen-facing and department-scoped listing procedures
-- are intentionally left untouched for now (out of scope — read-only /
-- unrelated to editing).
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_pdf_documents_modified_on.sql

USE legal_pdf;

-- 1. Add the column. UTC_TIMESTAMP() (unlike the bare CURRENT_TIMESTAMP
--    keyword) needs the DEFAULT (expr) form — MySQL 8.0.13+.
ALTER TABLE pdf_documents
    ADD COLUMN modified_on DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)) AFTER created_at;

-- 2. Backfill existing rows to their creation time — ADD COLUMN ... DEFAULT
--    UTC_TIMESTAMP(6) stamps every existing row with "now" (the ALTER's own
--    execution time), which would make every pre-existing document look
--    freshly modified. Run this BEFORE the trigger exists, so it doesn't
--    immediately overwrite the backfill.
UPDATE pdf_documents SET modified_on = created_at;

-- 3. Trigger — keeps modified_on current on every UPDATE, from any caller.
DELIMITER $$

DROP TRIGGER IF EXISTS trg_pdf_documents_modified_on $$
CREATE TRIGGER trg_pdf_documents_modified_on
BEFORE UPDATE ON pdf_documents
FOR EACH ROW
BEGIN
    SET NEW.modified_on = UTC_TIMESTAMP(6);
END $$

-- 4. sp_create_pdf_document — add modified_on to the returned row.
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
    IN p_last_updated_on      DATE,
    IN p_status               VARCHAR(20)
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
        p_last_updated_on, IFNULL(p_status, 'pending'), UTC_TIMESTAMP(6)
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
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
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

-- 5. sp_update_pdf_document — add modified_on to the returned row (the
--    trigger already stamps the value; this just exposes it in the response).
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
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
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

-- 6. sp_get_pdf_by_id — add modified_on to the SELECT.
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
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
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

-- 7. sp_list_pdfs_by_user — add modified_on to the SELECT.
DROP PROCEDURE IF EXISTS sp_list_pdfs_by_user $$
CREATE PROCEDURE sp_list_pdfs_by_user(
    IN p_user_id INT,
    IN p_skip    INT,
    IN p_limit   INT,
    IN p_status  VARCHAR(20)   -- NULL = no status filter
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id)                        AS count_total,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'pending') AS count_pending,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'approved')AS count_approved,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'rejected')AS count_rejected,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'draft')   AS count_draft,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'returned')AS count_returned,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
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
      AND (p_status IS NULL OR p.status = p_status)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

-- 8. sp_replace_pdf_file — add modified_on to the returned row.
DROP PROCEDURE IF EXISTS sp_replace_pdf_file $$
CREATE PROCEDURE sp_replace_pdf_file(
    IN p_pdf_id                INT,
    IN p_new_filename          VARCHAR(255),
    IN p_new_original_filename VARCHAR(255),
    IN p_new_file_path         VARCHAR(500),
    IN p_new_file_size         BIGINT,
    IN p_new_summary           TEXT,
    IN p_resubmit              TINYINT   -- 0 = replace only, 1 = replace + reset to pending
)
BEGIN
    DECLARE v_current_status VARCHAR(20);

    SELECT status INTO v_current_status
    FROM pdf_documents
    WHERE id = p_pdf_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Document not found.';
    END IF;

    IF v_current_status NOT IN ('pending', 'rejected', 'returned') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'File replacement is only allowed for documents in pending, rejected, or returned state.';
    END IF;

    IF p_resubmit = 1 AND v_current_status NOT IN ('rejected', 'returned') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resubmit is only allowed for rejected or returned documents.';
    END IF;

    -- Update the document file fields
    UPDATE pdf_documents
    SET
        filename          = p_new_filename,
        original_filename = p_new_original_filename,
        file_path         = p_new_file_path,
        file_size         = p_new_file_size,
        summary           = IFNULL(p_new_summary, summary),
        status            = IF(p_resubmit = 1, 'pending', status)
    WHERE id = p_pdf_id;

    -- Clear annotations on the latest approval so highlights don't appear on the new file.
    -- The approval row (action, comments, approver, acted_at) is kept intact for audit logs.
    UPDATE pdf_document_approvals pda
    JOIN (
        SELECT id FROM pdf_document_approvals
        WHERE pdf_id = p_pdf_id
        ORDER BY acted_at DESC
        LIMIT 1
    ) latest ON pda.id = latest.id
    SET pda.annotations_json = NULL;

    -- Return updated document (same shape as sp_get_pdf_by_id)
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.summary, d.created_at, d.modified_on,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        (
            SELECT GROUP_CONCAT(CONCAT(t.id, ':', t.name) SEPARATOR ',')
            FROM   pdf_document_tags pdt
            JOIN   tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'pdf_id', r.target_pdf_id,
                           'document_name', pd.document_name,
                           'type', r.relationship_type
                       )
                   )
            FROM   pdf_document_relationships r
            JOIN   pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
        ) AS relationships,
        (
            SELECT JSON_OBJECT(
                       'action',              a.action,
                       'comments',            a.comments,
                       'annotations_json',    a.annotations_json,
                       'acted_at',            a.acted_at,
                       'approver_username',   u.username,
                       'approver_first_name', u.first_name,
                       'approver_last_name',  u.last_name
                   )
            FROM   pdf_document_approvals a
            JOIN   users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            LIMIT  1
        ) AS latest_approval
    FROM  pdf_documents d
    LEFT  JOIN departments    dep ON dep.id = d.department_id
    LEFT  JOIN document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = p_pdf_id;
END $$

-- 9. sp_list_all_pdfs — add modified_on to the SELECT (Admin "All Uploads").
DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$
CREATE PROCEDURE sp_list_all_pdfs(
    IN p_skip        INT,
    IN p_limit       INT,
    IN p_status      VARCHAR(20),
    IN p_approver_id INT          -- NULL = all documents; set to approver user id to filter
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,

        (SELECT COUNT(*) FROM pdf_documents pd2 LEFT JOIN users u2 ON u2.id = pd2.uploaded_by
         WHERE pd2.status != 'draft'
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_total,
        (SELECT COUNT(*) FROM pdf_documents pd2 LEFT JOIN users u2 ON u2.id = pd2.uploaded_by
         WHERE pd2.status = 'pending'
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_pending,
        (SELECT COUNT(*) FROM pdf_documents pd2 LEFT JOIN users u2 ON u2.id = pd2.uploaded_by
         WHERE pd2.status = 'approved'
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_approved,
        (SELECT COUNT(*) FROM pdf_documents pd2 LEFT JOIN users u2 ON u2.id = pd2.uploaded_by
         WHERE pd2.status = 'rejected'
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_rejected,

        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id,':',t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id WHERE pdt.pdf_id = p.id) AS tags,
        NULL AS relationships,
        (SELECT CAST(JSON_OBJECT(
                 'action',               a.action,
                 'comments',             a.comments,
                 'annotations_json',     a.annotations_json,
                 'acted_at',             a.acted_at,
                 'approver_username',    au.username,
                 'approver_first_name',  au.first_name,
                 'approver_last_name',   au.last_name
             ) AS CHAR)
         FROM pdf_document_approvals a
         JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id
         ORDER BY a.acted_at DESC
         LIMIT 1) AS latest_approval

    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.status != 'draft'
      AND (p_status      IS NULL OR p.status      = p_status)
      AND (p_approver_id IS NULL OR u.approver_id = p_approver_id)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

-- 10. sp_list_all_pdfs_super_admin — add modified_on to the SELECT.
DROP PROCEDURE IF EXISTS sp_list_all_pdfs_super_admin $$
CREATE PROCEDURE sp_list_all_pdfs_super_admin(
    IN p_skip                      INT,
    IN p_limit                     INT,
    IN p_status                    VARCHAR(20),
    IN p_department_id             INT,
    IN p_uploader_id               INT,
    IN p_approver_id               INT,
    IN p_document_name_starts_with VARCHAR(500)
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,

        (SELECT COUNT(*)
         FROM pdf_documents pd2
         LEFT JOIN (
             SELECT a1.pdf_id, a1.approver_id
             FROM pdf_document_approvals a1
             WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
         ) la2 ON la2.pdf_id = pd2.id
         WHERE pd2.status != 'draft'
           AND (p_department_id             IS NULL OR pd2.department_id = p_department_id)
           AND (p_uploader_id               IS NULL OR pd2.uploaded_by   = p_uploader_id)
           AND (p_approver_id               IS NULL OR la2.approver_id   = p_approver_id)
           AND (p_document_name_starts_with IS NULL OR p_document_name_starts_with = '' OR pd2.document_name LIKE CONCAT(p_document_name_starts_with, '%'))
        ) AS count_total,

        (SELECT COUNT(*)
         FROM pdf_documents pd2
         LEFT JOIN (
             SELECT a1.pdf_id, a1.approver_id
             FROM pdf_document_approvals a1
             WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
         ) la2 ON la2.pdf_id = pd2.id
         WHERE pd2.status = 'pending'
           AND (p_department_id             IS NULL OR pd2.department_id = p_department_id)
           AND (p_uploader_id               IS NULL OR pd2.uploaded_by   = p_uploader_id)
           AND (p_approver_id               IS NULL OR la2.approver_id   = p_approver_id)
           AND (p_document_name_starts_with IS NULL OR p_document_name_starts_with = '' OR pd2.document_name LIKE CONCAT(p_document_name_starts_with, '%'))
        ) AS count_pending,

        (SELECT COUNT(*)
         FROM pdf_documents pd2
         LEFT JOIN (
             SELECT a1.pdf_id, a1.approver_id
             FROM pdf_document_approvals a1
             WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
         ) la2 ON la2.pdf_id = pd2.id
         WHERE pd2.status = 'approved'
           AND (p_department_id             IS NULL OR pd2.department_id = p_department_id)
           AND (p_uploader_id               IS NULL OR pd2.uploaded_by   = p_uploader_id)
           AND (p_approver_id               IS NULL OR la2.approver_id   = p_approver_id)
           AND (p_document_name_starts_with IS NULL OR p_document_name_starts_with = '' OR pd2.document_name LIKE CONCAT(p_document_name_starts_with, '%'))
        ) AS count_approved,

        (SELECT COUNT(*)
         FROM pdf_documents pd2
         LEFT JOIN (
             SELECT a1.pdf_id, a1.approver_id
             FROM pdf_document_approvals a1
             WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
         ) la2 ON la2.pdf_id = pd2.id
         WHERE pd2.status = 'rejected'
           AND (p_department_id             IS NULL OR pd2.department_id = p_department_id)
           AND (p_uploader_id               IS NULL OR pd2.uploaded_by   = p_uploader_id)
           AND (p_approver_id               IS NULL OR la2.approver_id   = p_approver_id)
           AND (p_document_name_starts_with IS NULL OR p_document_name_starts_with = '' OR pd2.document_name LIKE CONCAT(p_document_name_starts_with, '%'))
        ) AS count_rejected,

        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at, p.modified_on,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id,':',t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id WHERE pdt.pdf_id = p.id) AS tags,
        NULL AS relationships,
        (SELECT CAST(JSON_OBJECT(
                 'action',               a.action,
                 'comments',             a.comments,
                 'annotations_json',     a.annotations_json,
                 'acted_at',             a.acted_at,
                 'approver_username',    au.username,
                 'approver_first_name',  au.first_name,
                 'approver_last_name',   au.last_name
             ) AS CHAR)
         FROM pdf_document_approvals a
         JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id
         ORDER BY a.acted_at DESC
         LIMIT 1) AS latest_approval

    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    LEFT JOIN (
        SELECT a1.pdf_id, a1.approver_id
        FROM pdf_document_approvals a1
        WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
    ) latest_appr ON latest_appr.pdf_id = p.id
    WHERE p.status != 'draft'
      AND (p_status                    IS NULL OR p.status        = p_status)
      AND (p_department_id             IS NULL OR p.department_id = p_department_id)
      AND (p_uploader_id               IS NULL OR p.uploaded_by   = p_uploader_id)
      AND (p_approver_id               IS NULL OR latest_appr.approver_id = p_approver_id)
      AND (p_document_name_starts_with IS NULL OR p_document_name_starts_with = '' OR p.document_name LIKE CONCAT(p_document_name_starts_with, '%'))
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'pdf_documents.modified_on added — trigger + procedures patched.' AS status;
