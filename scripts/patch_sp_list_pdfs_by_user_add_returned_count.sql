-- Adds a count_returned column to sp_list_pdfs_by_user so the Uploader
-- dashboard can show a "Returned for Edit" stat card/filter — documents an
-- Approver unlocked (via a Nodal-Officer-approved unlock request) and sent
-- back to the uploader to edit.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_list_pdfs_by_user_add_returned_count.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_pdfs_by_user $$

CREATE PROCEDURE sp_list_pdfs_by_user(
    IN p_user_id INT,
    IN p_skip    INT,
    IN p_limit   INT,
    IN p_status  VARCHAR(20)   -- NULL = no status filter
)
BEGIN
    SELECT
        -- Pagination count: rows that match the optional status filter
        COUNT(*) OVER()                                                                           AS total_count,

        -- Status counts: always computed across ALL statuses for this user
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id)                        AS count_total,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'pending') AS count_pending,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'approved')AS count_approved,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'rejected')AS count_rejected,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'draft')   AS count_draft,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'returned')AS count_returned,

        -- Document columns (unchanged from previous version)
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
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.uploaded_by = p_user_id
      AND (p_status IS NULL OR p.status = p_status)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_pdfs_by_user patched — count_returned added.' AS status;
