-- New SP: sp_get_act_full_related_docs
-- Returns ALL documents linked to a given ACT regardless of relationship_type.
-- Used by GET /api/v1/pdf/{act_id}/full to populate related_documents.
-- The existing sp_get_documents_under_act (parent_act filter only) is NOT modified.
-- Run: mysql -u root -p Legal_PDF < scripts/add_sp_get_act_full_related_docs.sql

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_get_act_full_related_docs $$

CREATE PROCEDURE sp_get_act_full_related_docs(IN p_act_id INT)
BEGIN
    SELECT
        p.id, p.document_name, p.reference_number, p.issue_date, p.status,
        p.version_no, p.effective_from, p.gazette_reference, p.legal_authority,
        p.short_title, p.act_year, p.long_title, p.regional_title,
        p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.valid_until, p.sector_domain, p.implementing_agency, p.next_review_date,
        p.rule_making_authority,
        p.description, p.summary,
        p.department_id, p.document_type_id,
        p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        r.relationship_type,
        (SELECT GROUP_CONCAT(CONCAT(t.id, ':', t.name) ORDER BY t.id SEPARATOR ',')
         FROM pdf_document_tags pdt JOIN tags t ON t.id = pdt.tag_id
         WHERE pdt.pdf_id = p.id) AS tags
    FROM pdf_document_relationships r
    JOIN pdf_documents  p   ON p.id   = r.source_pdf_id
    JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments dep ON dep.id = p.department_id
    LEFT JOIN users u         ON u.id   = p.uploaded_by
    WHERE r.target_pdf_id = p_act_id
    ORDER BY dt.name, p.issue_date DESC;
END $$

DELIMITER ;

SELECT 'sp_get_act_full_related_docs created successfully.' AS status;
