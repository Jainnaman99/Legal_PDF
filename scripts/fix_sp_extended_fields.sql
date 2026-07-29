-- ============================================================
-- Patch: Add extended PDF fields to list/pending/review SPs
-- Run: mysql -u root -p Legal_PDF < scripts/fix_sp_extended_fields.sql
-- ============================================================

DELIMITER $$

-- ── 1. sp_list_pdfs_by_user (my-documents) ───────────────────────────────────

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
        p.uploaded_by, p.created_at,
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

-- ── 2. sp_list_all_pdfs (all) ────────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$
CREATE PROCEDURE sp_list_all_pdfs(IN p_skip INT, IN p_limit INT, IN p_status VARCHAR(20))
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
        p.uploaded_by, p.created_at,
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

-- ── 3. sp_get_pending_pdfs (approver/documents) ──────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_pending_pdfs $$
CREATE PROCEDURE sp_get_pending_pdfs(IN p_skip INT, IN p_limit INT)
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
        p.uploaded_by, p.created_at,
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

-- ── 4. sp_review_pdf_document (inline SELECT after approval) ─────────────────

DROP PROCEDURE IF EXISTS sp_review_pdf_document $$
CREATE PROCEDURE sp_review_pdf_document(
    IN p_pdf_id           INT,
    IN p_approver_id      INT,
    IN p_action           VARCHAR(20),
    IN p_comments         TEXT,
    IN p_annotations_json LONGTEXT
)
BEGIN
    UPDATE pdf_documents SET status = p_action WHERE id = p_pdf_id;

    INSERT INTO pdf_document_approvals (pdf_id, approver_id, action, comments, annotations_json, acted_at)
    VALUES (p_pdf_id, p_approver_id, p_action, p_comments, p_annotations_json, UTC_TIMESTAMP(6));

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

DELIMITER ;

SELECT 'Extended fields added to sp_list_pdfs_by_user, sp_list_all_pdfs, sp_get_pending_pdfs, sp_review_pdf_document.' AS status;
