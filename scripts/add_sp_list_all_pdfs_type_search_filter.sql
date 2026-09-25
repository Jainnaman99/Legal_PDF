-- Extends sp_list_all_pdfs (used by GET /pdf/approver/documents and the
-- legacy public GET /pdf/all) with two new optional filters so the Approver
-- Dashboard can do real server-side pagination (skip/limit tied to the
-- actual page shown) without breaking its Type filter or title search —
-- both of which used to run client-side over whatever batch was fetched.
--
-- New parameters (both NULL/'' = no filter, so existing callers that don't
-- pass them — e.g. the /pdf/all route — are unaffected):
--   p_document_type_name — exact match against document_types.name
--   p_search             — substring match against document_name OR original_filename
--
-- Existing parameters (p_skip, p_limit, p_status, p_approver_id) and their
-- order are unchanged; the two new ones are appended at the end, so this is
-- a backward-compatible signature change (adds params, doesn't reorder any).
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_list_all_pdfs_type_search_filter.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_all_pdfs $$

CREATE PROCEDURE sp_list_all_pdfs(
    IN p_skip                INT,
    IN p_limit               INT,
    IN p_status               VARCHAR(20),
    IN p_approver_id          INT,
    IN p_document_type_name   VARCHAR(100),
    IN p_search               VARCHAR(500)
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
      AND (p_status              IS NULL OR p.status = p_status)
      AND (p_approver_id         IS NULL OR u.approver_id = p_approver_id)
      AND (p_document_type_name  IS NULL OR p_document_type_name = '' OR dt.name = p_document_type_name)
      AND (p_search               IS NULL OR p_search = '' OR p.document_name LIKE CONCAT('%', p_search, '%') OR p.original_filename LIKE CONCAT('%', p_search, '%'))
    ORDER BY p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_all_pdfs patched — document_type_name + search filters added.' AS status;
