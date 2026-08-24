-- ============================================================
-- Public citizen document listing stored procedure.
-- Returns approved documents only — no authentication required.
--
-- Both p_department_id and p_document_type_id are optional.
-- Pass NULL (or omit) to show all departments / all types.
--
-- Run via:
--   mysql -u root -p legal_pdf < scripts/add_sp_citizen_list_documents.sql
--
-- Call:
--   CALL sp_citizen_list_documents(NULL, NULL, 0, 20);   -- all docs
--   CALL sp_citizen_list_documents(5,    NULL, 0, 20);   -- dept 5, all types
--   CALL sp_citizen_list_documents(NULL, 2,    0, 20);   -- all depts, type 2
--   CALL sp_citizen_list_documents(5,    2,    0, 20);   -- dept 5, type 2
-- ============================================================

USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_citizen_list_documents;

DELIMITER $$

CREATE PROCEDURE sp_citizen_list_documents(
    IN p_department_id    INT,     -- NULL = all departments
    IN p_document_type_id INT,     -- NULL = all document types
    IN p_skip             INT,
    IN p_limit            INT
)
BEGIN
    SELECT
        COUNT(*) OVER()  AS total_count,
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
        ) AS latest_approval
    FROM  pdf_documents p
    JOIN  document_types dt    ON dt.id  = p.document_type_id
    LEFT  JOIN departments dep  ON dep.id = p.department_id
    LEFT  JOIN users u          ON u.id   = p.uploaded_by
    WHERE p.status = 'approved'
      AND (p_department_id    IS NULL OR p.department_id    = p_department_id)
      AND (p_document_type_id IS NULL OR p.document_type_id = p_document_type_id)
    ORDER BY p.issue_date DESC, p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_citizen_list_documents created successfully.' AS status;
