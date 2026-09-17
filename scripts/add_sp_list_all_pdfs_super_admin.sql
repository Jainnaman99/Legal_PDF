-- New stored procedure for the Super Admin "All Uploads" screen. Unlike
-- sp_list_all_pdfs (used by the public, unauthenticated /pdf/all endpoint),
-- this adds server-side filtering so the Super Admin dashboard no longer has
-- to fetch up to 500 rows and filter them in the browser.
--
-- Filters (all optional — NULL means "no filter"):
--   p_department_id             — exact match against pdf_documents.department_id (the dropdown's value)
--   p_uploader_id               — exact match against pdf_documents.uploaded_by (the dropdown's value)
--   p_approver_id               — exact match against the latest approval's approver_id (the dropdown's value)
--   p_document_name_starts_with — prefix match against pdf_documents.document_name
--   p_status                    — exact match: pending | approved | rejected
--
-- The count_* columns respect every filter above except p_status, so the
-- stat cards update correctly per filter combination while every status tab
-- stays reachable.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_list_all_pdfs_super_admin.sql

USE legal_pdf;

DELIMITER $$

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
        p.last_updated_on, p.uploaded_by, p.created_at,
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

SELECT 'sp_list_all_pdfs_super_admin created.' AS status;
