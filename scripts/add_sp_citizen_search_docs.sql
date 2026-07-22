USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_citizen_search_docs $$
CREATE PROCEDURE sp_citizen_search_docs(
    IN p_document_type_id INT,
    IN p_name_prefix      VARCHAR(500),
    IN p_skip             INT,
    IN p_limit            INT
)
BEGIN
    SELECT
        COUNT(*) OVER() AS total_count,
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
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
        NULL AS latest_approval
    FROM pdf_documents p
    JOIN document_types dt   ON dt.id  = p.document_type_id
    LEFT JOIN departments dep ON dep.id = p.department_id
    LEFT JOIN users u         ON u.id   = p.uploaded_by
    WHERE p.status = 'approved'
      AND (p_document_type_id IS NULL OR p.document_type_id = p_document_type_id)
      AND (p_name_prefix IS NULL OR p_name_prefix = '' OR p.document_name LIKE CONCAT(p_name_prefix, '%'))
    ORDER BY p.document_name ASC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_citizen_search_docs created.' AS status;
