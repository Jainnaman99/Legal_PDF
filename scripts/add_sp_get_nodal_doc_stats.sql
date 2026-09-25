-- New procedure: sp_get_nodal_doc_stats
--
-- Same fix as sp_get_approver_doc_stats / sp_get_uploader_doc_stats applied
-- to the Nodal Officer Dashboard's "All Uploads" listing: returns the 5
-- stat-card counts (total/pending/approved/rejected/deleted) as their own
-- always-1-row result set, decoupled from sp_list_pdfs_by_department's
-- paginated document list, scoped by the officer's department(s).
--
-- Why: sp_list_pdfs_by_department used to attach these counts as extra
-- columns on each row of the paginated list. When a filter (status/
-- uploader/approver/search) matched zero rows, the whole result set came
-- back empty, so the counts — even though they don't depend on the filter —
-- were lost too.
--
-- Companion script add_sp_list_pdfs_by_department_filters.sql rewrites
-- sp_list_pdfs_by_department to remove the now-redundant count_* columns
-- and fix its total_count the same way, plus adds uploader/approver/search
-- filters. Run BOTH scripts.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_get_nodal_doc_stats.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_get_nodal_doc_stats $$

CREATE PROCEDURE sp_get_nodal_doc_stats(
    IN p_dept_ids VARCHAR(500)  -- CSV department ids from the caller's token
)
BEGIN
    SELECT
        (SELECT COUNT(*) FROM pdf_documents
         WHERE status != 'draft' AND FIND_IN_SET(department_id, p_dept_ids) > 0)  AS count_total,
        (SELECT COUNT(*) FROM pdf_documents
         WHERE status = 'pending' AND FIND_IN_SET(department_id, p_dept_ids) > 0) AS count_pending,
        (SELECT COUNT(*) FROM pdf_documents
         WHERE status = 'approved' AND FIND_IN_SET(department_id, p_dept_ids) > 0) AS count_approved,
        (SELECT COUNT(*) FROM pdf_documents
         WHERE status = 'rejected' AND FIND_IN_SET(department_id, p_dept_ids) > 0) AS count_rejected,
        (SELECT COUNT(*) FROM pdf_documents
         WHERE status = 'deleted' AND FIND_IN_SET(department_id, p_dept_ids) > 0) AS count_deleted;
END $$

DELIMITER ;

SELECT 'sp_get_nodal_doc_stats created.' AS status;
