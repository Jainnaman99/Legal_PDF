-- Supersedes add_sp_get_approver_doc_stats.sql — adds an assigned_uploader_count
-- column so the Approver Dashboard can tell apart two very different empty
-- states that currently look identical:
--   1. "You have uploaders assigned, you've just reviewed everything" (a
--      genuine "all caught up" state).
--   2. "No uploader account has your user id as its approver_id at all" —
--      you were never assigned anyone to review, so there is nothing to
--      catch up on and never will be until an admin assigns you one.
--
-- assigned_uploader_count is simply how many user rows have
-- users.approver_id = p_approver_id (see scripts/patch_uploader_approver_mapping.sql
-- for that column) — independent of any document filter, so like the other
-- columns here it's safe to read regardless of which status tab is active.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_get_approver_doc_stats_uploader_count.sql

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
           AND (p_approver_id IS NULL OR u2.approver_id = p_approver_id))             AS count_deleted,
        (SELECT COUNT(*) FROM users u3
         WHERE p_approver_id IS NOT NULL AND u3.approver_id = p_approver_id)          AS assigned_uploader_count;
END $$

DELIMITER ;

SELECT 'sp_get_approver_doc_stats patched — assigned_uploader_count added.' AS status;
