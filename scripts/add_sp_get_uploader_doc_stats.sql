-- New procedure: sp_get_uploader_doc_stats
--
-- Same fix as sp_get_approver_doc_stats / sp_get_nodal_doc_stats applied to
-- the Uploader Dashboard's "My Uploads" listing: returns the 7 stat-card
-- counts (total/pending/approved/rejected/draft/returned/deleted) as their
-- own always-1-row result set, decoupled from sp_list_pdfs_by_user's
-- paginated document list.
--
-- Why: sp_list_pdfs_by_user attaches these counts as extra columns on each
-- row of the paginated list. When a filter (status/type/search) matches
-- zero rows, the whole result set comes back empty, so the counts — even
-- though they don't depend on the filter — are lost too.
--
-- Companion script add_sp_list_pdfs_by_user_type_search_filter.sql rewrites
-- sp_list_pdfs_by_user to remove the now-redundant count_* columns and fix
-- its total_count the same way, plus adds type/search filters. Run BOTH
-- scripts.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_get_uploader_doc_stats.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_get_uploader_doc_stats $$

CREATE PROCEDURE sp_get_uploader_doc_stats(
    IN p_user_id INT
)
BEGIN
    SELECT
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id)                         AS count_total,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'pending')  AS count_pending,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'approved') AS count_approved,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'rejected') AS count_rejected,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'draft')    AS count_draft,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'returned') AS count_returned,
        (SELECT COUNT(*) FROM pdf_documents WHERE uploaded_by = p_user_id AND status = 'deleted')  AS count_deleted;
END $$

DELIMITER ;

SELECT 'sp_get_uploader_doc_stats created.' AS status;
