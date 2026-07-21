USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_docs_by_dept_and_type $$
CREATE PROCEDURE sp_list_docs_by_dept_and_type(
    IN p_dept_ids       VARCHAR(500),   -- CSV e.g. "1" or "1,2"
    IN p_doc_type_id    INT,            -- document_types.id
    IN p_skip           INT,
    IN p_limit          INT,
    IN p_status         VARCHAR(20)     -- NULL = all; 'pending' | 'approved' | 'rejected'
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.version_no,
        p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.short_title, p.regional_title,
        p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        (SELECT GROUP_CONCAT(CONCAT(t.id,':',t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id
         WHERE pdt.pdf_id = p.id) AS tags,
        NULL AS relationships,
        (SELECT CAST(JSON_OBJECT(
             'action', a.action, 'comments', a.comments, 'annotations_json', a.annotations_json,
             'acted_at', a.acted_at, 'approver_username', au.username,
             'approver_first_name', au.first_name, 'approver_last_name', au.last_name
         ) AS CHAR)
         FROM pdf_document_approvals a JOIN users au ON au.id = a.approver_id
         WHERE a.pdf_id = p.id ORDER BY a.acted_at DESC LIMIT 1) AS latest_approval
    FROM pdf_documents p
    JOIN document_types dt   ON dt.id  = p.document_type_id
    LEFT JOIN departments dep ON dep.id = p.department_id
    LEFT JOIN users u         ON u.id   = p.uploaded_by
    WHERE p.document_type_id = p_doc_type_id
      AND FIND_IN_SET(p.department_id, p_dept_ids) > 0
      AND (p_status IS NULL OR p.status = p_status)
    ORDER BY p.issue_date DESC, p.created_at DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_list_docs_by_dept_and_type created.' AS status;
