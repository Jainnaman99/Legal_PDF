-- Clears annotations_json from the latest approval when a file is replaced.
-- The approval row itself (action, comments, approver, timestamp) is preserved for logs.
-- Highlights on the PDF viewer are cleared because the file is new and old positions
-- no longer correspond to content in the new file.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_replace_pdf_clear_annotations.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_replace_pdf_file $$

CREATE PROCEDURE sp_replace_pdf_file(
    IN p_pdf_id                INT,
    IN p_new_filename          VARCHAR(255),
    IN p_new_original_filename VARCHAR(255),
    IN p_new_file_path         VARCHAR(500),
    IN p_new_file_size         BIGINT,
    IN p_new_summary           TEXT,
    IN p_resubmit              TINYINT   -- 0 = replace only, 1 = replace + reset to pending
)
BEGIN
    DECLARE v_current_status VARCHAR(20);

    SELECT status INTO v_current_status
    FROM pdf_documents
    WHERE id = p_pdf_id;

    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Document not found.';
    END IF;

    IF v_current_status NOT IN ('pending', 'rejected') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'File replacement is only allowed for documents in pending or rejected state.';
    END IF;

    IF p_resubmit = 1 AND v_current_status != 'rejected' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resubmit is only allowed for rejected documents.';
    END IF;

    -- Update the document file fields
    UPDATE pdf_documents
    SET
        filename          = p_new_filename,
        original_filename = p_new_original_filename,
        file_path         = p_new_file_path,
        file_size         = p_new_file_size,
        summary           = IFNULL(p_new_summary, summary),
        status            = IF(p_resubmit = 1, 'pending', status)
    WHERE id = p_pdf_id;

    -- Clear annotations on the latest approval so highlights don't appear on the new file.
    -- The approval row (action, comments, approver, acted_at) is kept intact for audit logs.
    UPDATE pdf_document_approvals pda
    JOIN (
        SELECT id FROM pdf_document_approvals
        WHERE pdf_id = p_pdf_id
        ORDER BY acted_at DESC
        LIMIT 1
    ) latest ON pda.id = latest.id
    SET pda.annotations_json = NULL;

    -- Return updated document (same shape as sp_get_pdf_by_id)
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.summary, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        (
            SELECT GROUP_CONCAT(CONCAT(t.id, ':', t.name) SEPARATOR ',')
            FROM   pdf_document_tags pdt
            JOIN   tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'pdf_id', r.target_pdf_id,
                           'document_name', pd.document_name,
                           'type', r.relationship_type
                       )
                   )
            FROM   pdf_document_relationships r
            JOIN   pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
        ) AS relationships,
        (
            SELECT JSON_OBJECT(
                       'action',              a.action,
                       'comments',            a.comments,
                       'annotations_json',    a.annotations_json,
                       'acted_at',            a.acted_at,
                       'approver_username',   u.username,
                       'approver_first_name', u.first_name,
                       'approver_last_name',  u.last_name
                   )
            FROM   pdf_document_approvals a
            JOIN   users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            LIMIT  1
        ) AS latest_approval
    FROM  pdf_documents d
    LEFT  JOIN departments    dep ON dep.id = d.department_id
    LEFT  JOIN document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = p_pdf_id;
END $$

DELIMITER ;
