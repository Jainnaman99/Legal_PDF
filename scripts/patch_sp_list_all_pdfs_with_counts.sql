-- Adds per-status count columns to sp_list_all_pdfs so the approver dashboard
-- stat cards show correct totals regardless of pagination limit.
--
-- New columns returned on every row (read from rows[0] in the backend):
--   count_total    — total non-draft documents visible to this approver
--   count_pending  — pending  documents visible to this approver
--   count_approved — approved documents visible to this approver
--   count_rejected — rejected documents visible to this approver
--   total_count    — rows matching the p_status filter (used for pagination)
--
-- The count_* subqueries respect p_approver_id: when set they only count
-- documents whose uploader is assigned to that approver, matching the main
-- WHERE clause behaviour.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_list_all_pdfs_with_counts.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$

CREATE PROCEDURE sp_list_all_pdfs(
    IN p_skip        INT,
    IN p_limit       INT,
    IN p_status      VARCHAR(20),
    IN p_approver_id INT          -- NULL = all documents; set to approver user id to filter
)
BEGIN
    SELECT
        -- Pagination count: rows matching the optional status filter
        COUNT(*) OVER() AS total_count,

        -- Status counts: always computed across ALL non-draft docs for this approver scope
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
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.status != 'draft'
      AND (p_status      IS NULL OR p.status      = p_status)
      AND (p_approver_id IS NULL OR u.approver_id = p_approver_id)
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_all_pdfs patched — status counts added.' AS status;
