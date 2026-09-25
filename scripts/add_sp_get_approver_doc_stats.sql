-- New procedure: sp_get_approver_doc_stats
--
-- Returns the 5 stat-card counts (total/pending/approved/rejected/deleted)
-- as their own always-1-row result set, decoupled from sp_list_all_pdfs'
-- paginated document list.
--
-- Why: sp_list_all_pdfs used to attach these counts as extra columns on
-- each row of the paginated list. That works fine when the list has at
-- least one row, but when a filter (e.g. status=rejected with zero actual
-- rejected documents) matches NO rows, the whole result set comes back
-- empty — so the counts, even though they don't depend on the filter,
-- never get returned either. The API then reports total/count_pending/
-- count_approved/count_rejected/count_deleted as all 0, which is wrong
-- whenever the *list* is empty but real data still exists elsewhere.
--
-- This procedure has no dependency on the row cardinality of any filtered
-- query — it's a flat SELECT of independent scalar subqueries, so it
-- always returns exactly one row.
--
-- Companion script add_sp_list_all_pdfs_count_deleted.sql (updated) removes
-- the now-redundant count_* subqueries from sp_list_all_pdfs and fixes its
-- total_count the same way. Run BOTH scripts.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_get_approver_doc_stats.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_get_approver_doc_stats $$

CREATE PROCEDURE sp_get_approver_doc_stats(
    IN p_approver_id INT   -- NULL = all documents; set to approver user id to scope
)
BEGIN
    SELECT
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
        (SELECT COUNT(*) FROM pdf_documents pd2 LEFT JOIN users u2 ON u2.id = pd2.uploaded_by
         WHERE pd2.status = 'deleted'
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_deleted;
END $$

DELIMITER ;

SELECT 'sp_get_approver_doc_stats created.' AS status;
