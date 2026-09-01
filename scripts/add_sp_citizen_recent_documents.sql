-- ============================================================
-- Returns the top N most recently approved documents for the
-- public citizen portal (no authentication required).
--
-- Ordered by the approval acted_at timestamp DESC so that the
-- latest approver action determines the ranking.
--
-- Run via:
--   mysql -u root -p legal_pdf < scripts/add_sp_citizen_recent_documents.sql
--
-- Call:
--   CALL sp_citizen_recent_documents(5);
-- ============================================================

USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_citizen_recent_documents;

DELIMITER $$

CREATE PROCEDURE sp_citizen_recent_documents(
    IN p_limit INT
)
BEGIN
    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date,
        p.rule_making_authority, p.version_no,
        p.act_year, p.long_title, p.regional_title, p.notification_no,
        p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.description, p.summary,
        p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (
            SELECT GROUP_CONCAT(CONCAT(t.id, ':', t.name) ORDER BY t.id SEPARATOR ',')
            FROM   pdf_document_tags pdt
            JOIN   tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = p.id
        ) AS tags,
        NULL AS relationships,
        (
            SELECT CAST(JSON_OBJECT(
                'action',              a.action,
                'comments',            a.comments,
                'annotations_json',    a.annotations_json,
                'acted_at',            a.acted_at,
                'approver_username',   au.username,
                'approver_first_name', au.first_name,
                'approver_last_name',  au.last_name
            ) AS CHAR)
            FROM   pdf_document_approvals a
            JOIN   users au ON au.id = a.approver_id
            WHERE  a.pdf_id = p.id
            ORDER  BY a.acted_at DESC
            LIMIT  1
        ) AS latest_approval,
        latest_appr.acted_at AS approved_at
    FROM  pdf_documents p
    JOIN  document_types dt    ON dt.id  = p.document_type_id
    LEFT  JOIN departments dep  ON dep.id = p.department_id
    LEFT  JOIN users u          ON u.id   = p.uploaded_by
    JOIN  (
        SELECT pdf_id, MAX(acted_at) AS acted_at
        FROM   pdf_document_approvals
        WHERE  action = 'approved'
        GROUP  BY pdf_id
    ) latest_appr ON latest_appr.pdf_id = p.id
    WHERE p.status = 'approved'
    ORDER BY latest_appr.acted_at DESC
    LIMIT p_limit;
END $$

DELIMITER ;

SELECT 'sp_citizen_recent_documents created successfully.' AS status;
