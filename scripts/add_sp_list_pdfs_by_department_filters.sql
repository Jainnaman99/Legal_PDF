-- Rewrites sp_list_pdfs_by_department to support true server-side pagination
-- for the Nodal Officer Dashboard's "All Uploads" screen — mirrors the same
-- fix already applied to sp_list_all_pdfs (approver) via
-- add_sp_list_all_pdfs_count_deleted.sql.
--
-- Changes from the previous version (add_sp_list_pdfs_by_department.sql):
--   1. Adds p_uploader_id, p_approver_id, p_search filters (previously only
--      done client-side in the browser over a one-time 500-row fetch).
--   2. total_count is now computed by its own always-1-row subquery (tc),
--      LEFT JOINed against the paginated list — so it stays correct even
--      when the current filter combination matches zero rows (previously,
--      an empty page meant the whole result set came back empty and
--      total_count silently read as 0).
--   3. The 5 stat-card counts (count_total/pending/approved/rejected/
--      deleted) have been moved out of this procedure entirely — see the
--      companion sp_get_nodal_doc_stats procedure
--      (add_sp_get_nodal_doc_stats.sql), which returns them as their own
--      row, for the same reason.
--   4. Approver filtering needs each document's latest approval's
--      approver_id, joined the same way sp_list_all_pdfs_super_admin does.
--
-- Run via mysql client (run add_sp_get_nodal_doc_stats.sql first):
--   mysql -u <user> -p legal_pdf < scripts/add_sp_list_pdfs_by_department_filters.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_pdfs_by_department $$

CREATE PROCEDURE sp_list_pdfs_by_department(
    IN p_dept_ids    VARCHAR(500),  -- CSV department ids from the caller's token
    IN p_skip        INT,
    IN p_limit       INT,
    IN p_status      VARCHAR(20),
    IN p_uploader_id INT,
    IN p_approver_id INT,
    IN p_search      VARCHAR(500)
)
BEGIN
    SELECT
        tc.total_count,

        list.id, list.filename, list.original_filename, list.file_path, list.file_size, list.status,
        list.document_name, list.reference_number, list.issue_date, list.effective_from,
        list.gazette_reference, list.legal_authority, list.short_title, list.valid_until,
        list.sector_domain, list.implementing_agency, list.next_review_date, list.rule_making_authority,
        list.version_no, list.department_id, list.document_type_id, list.description, list.summary,
        list.act_year, list.long_title, list.regional_title, list.notification_no, list.act_code, list.so_reason,
        list.no_of_rules, list.no_of_notifications, list.no_of_regulations, list.no_of_circulars,
        list.no_of_statutes, list.no_of_ordinances, list.no_of_orders, list.keywords, list.is_repealed,
        list.last_updated_on, list.uploaded_by, list.created_at, list.modified_on,
        list.document_type_name, list.department_name,
        list.uploader_username, list.uploader_first_name, list.uploader_last_name,
        list.tags, list.relationships, list.latest_approval

    FROM (
        SELECT COUNT(*) AS total_count
        FROM pdf_documents p2
        LEFT JOIN (
            SELECT a1.pdf_id, a1.approver_id
            FROM pdf_document_approvals a1
            WHERE a1.id = (SELECT a3.id FROM pdf_document_approvals a3 WHERE a3.pdf_id = a1.pdf_id ORDER BY a3.acted_at DESC LIMIT 1)
        ) la2 ON la2.pdf_id = p2.id
        WHERE p2.status != 'draft'
          AND FIND_IN_SET(p2.department_id, p_dept_ids) > 0
          AND (p_status      IS NULL OR p_status = '' OR p2.status = p_status)
          AND (p_uploader_id IS NULL OR p2.uploaded_by = p_uploader_id)
          AND (p_approver_id IS NULL OR la2.approver_id = p_approver_id)
          AND (p_search      IS NULL OR p_search = '' OR p2.document_name LIKE CONCAT('%', p_search, '%') OR p2.original_filename LIKE CONCAT('%', p_search, '%'))
    ) tc

    LEFT JOIN (
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
          AND FIND_IN_SET(p.department_id, p_dept_ids) > 0
          AND (p_status      IS NULL OR p_status = '' OR p.status = p_status)
          AND (p_uploader_id IS NULL OR p.uploaded_by = p_uploader_id)
          AND (p_approver_id IS NULL OR latest_appr.approver_id = p_approver_id)
          AND (p_search      IS NULL OR p_search = '' OR p.document_name LIKE CONCAT('%', p_search, '%') OR p.original_filename LIKE CONCAT('%', p_search, '%'))
        ORDER BY p.created_at DESC
        LIMIT p_limit OFFSET p_skip
    ) list ON 1=1

    ORDER BY list.created_at DESC;
END $$

DELIMITER ;

SELECT 'sp_list_pdfs_by_department patched — uploader/approver/search filters added, total_count decoupled, stat counts moved to sp_get_nodal_doc_stats.' AS status;
