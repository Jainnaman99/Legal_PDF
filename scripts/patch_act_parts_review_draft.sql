-- Patch: include draft items in review transitions
-- When an approver approves/rejects a tab, ALL non-deleted items in that tab
-- (both 'pending' AND 'draft') receive the new status. This covers the case where
-- an uploader saves new content between a submission and the approval decision.
--
-- Run: mysql -u root -p Legal_PDF < scripts/patch_act_parts_review_draft.sql

-- ── 1. One-time data fix ──────────────────────────────────────────────────────
-- Promote any 'draft' items that belong to an already-approved tab.
-- (These are items that were saved after the last submission but the approver
-- approved the tab without the uploader re-submitting first.)

UPDATE act_part_chapters c
JOIN act_part_approvals a
    ON a.pdf_document_id = c.pdf_document_id AND a.part_type = 'sections'
SET c.status = 'approved'
WHERE c.status = 'draft' AND c.is_deleted = 0 AND a.status = 'approved';

UPDATE act_part_sections s
JOIN act_part_approvals a
    ON a.pdf_document_id = s.pdf_document_id AND a.part_type = 'sections'
SET s.status = 'approved'
WHERE s.status = 'draft' AND s.is_deleted = 0 AND a.status = 'approved';

UPDATE act_part_schedules t
JOIN act_part_approvals a
    ON a.pdf_document_id = t.pdf_document_id AND a.part_type = 'schedule'
SET t.status = 'approved'
WHERE t.status = 'draft' AND t.is_deleted = 0 AND a.status = 'approved';

UPDATE act_part_annexures t
JOIN act_part_approvals a
    ON a.pdf_document_id = t.pdf_document_id AND a.part_type = 'annexure'
SET t.status = 'approved'
WHERE t.status = 'draft' AND t.is_deleted = 0 AND a.status = 'approved';

UPDATE act_part_appendices t
JOIN act_part_approvals a
    ON a.pdf_document_id = t.pdf_document_id AND a.part_type = 'appendix'
SET t.status = 'approved'
WHERE t.status = 'draft' AND t.is_deleted = 0 AND a.status = 'approved';

UPDATE act_part_forms t
JOIN act_part_approvals a
    ON a.pdf_document_id = t.pdf_document_id AND a.part_type = 'forms'
SET t.status = 'approved'
WHERE t.status = 'draft' AND t.is_deleted = 0 AND a.status = 'approved';

-- ── 2. Rewrite sp_review_act_parts ───────────────────────────────────────────
-- Transition both 'pending' AND 'draft' items when a tab is approved/rejected.

DROP PROCEDURE IF EXISTS sp_review_act_parts;
DELIMITER ;;
CREATE PROCEDURE sp_review_act_parts(
    IN p_pdf_document_id INT,
    IN p_part_type       VARCHAR(20),
    IN p_reviewed_by     INT,
    IN p_action          VARCHAR(20),
    IN p_comments        TEXT
)
BEGIN
    -- Update tab-level approval record
    UPDATE act_part_approvals SET
        status      = p_action,
        reviewed_by = p_reviewed_by,
        reviewed_at = NOW(),
        comments    = p_comments
    WHERE pdf_document_id = p_pdf_document_id AND part_type = p_part_type;

    -- Transition ALL non-deleted items (pending + draft) to the decision.
    -- Draft items are included because the approver saw them in the detail view
    -- and the decision covers everything visible at review time.
    IF p_part_type = 'sections' THEN
        UPDATE act_part_chapters SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        UPDATE act_part_sections SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
    ELSEIF p_part_type = 'schedule' THEN
        UPDATE act_part_schedules SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
    ELSEIF p_part_type = 'annexure' THEN
        UPDATE act_part_annexures SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
    ELSEIF p_part_type = 'appendix' THEN
        UPDATE act_part_appendices SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
    ELSEIF p_part_type = 'forms' THEN
        UPDATE act_part_forms SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
    END IF;

    SELECT
        a.id,
        a.pdf_document_id,
        a.part_type,
        a.status,
        a.submitted_by,
        a.submitted_at,
        a.reviewed_by,
        a.reviewed_at,
        a.comments,
        u.username   AS submitter_username,
        u.first_name AS submitter_first_name,
        u.last_name  AS submitter_last_name,
        r.username   AS reviewer_username,
        r.first_name AS reviewer_first_name,
        r.last_name  AS reviewer_last_name
    FROM act_part_approvals a
    JOIN users u ON u.id = a.submitted_by
    LEFT JOIN users r ON r.id = a.reviewed_by
    WHERE a.pdf_document_id = p_pdf_document_id AND a.part_type = p_part_type;
END ;;
DELIMITER ;
