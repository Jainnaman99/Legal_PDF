-- Adds "draft" status support to the document upload flow.
-- Recreates sp_create_pdf_document with an optional p_status parameter
-- (defaults to 'pending' so all existing callers are unaffected).
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_draft_status_support.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_create_pdf_document $$
CREATE PROCEDURE sp_create_pdf_document(
    IN p_filename             VARCHAR(255),
    IN p_original_filename    VARCHAR(255),
    IN p_file_path            VARCHAR(500),
    IN p_file_size            BIGINT,
    IN p_uploaded_by          INT,
    IN p_document_name        VARCHAR(500),
    IN p_reference_number     VARCHAR(100),
    IN p_issue_date           DATE,
    IN p_effective_from       DATE,
    IN p_gazette_reference    VARCHAR(500),
    IN p_legal_authority      VARCHAR(255),
    IN p_short_title          VARCHAR(255),
    IN p_valid_until          DATE,
    IN p_sector_domain        VARCHAR(255),
    IN p_implementing_agency  VARCHAR(255),
    IN p_next_review_date     DATE,
    IN p_rule_making_authority VARCHAR(255),
    IN p_version_no           VARCHAR(50),
    IN p_department_id        INT,
    IN p_document_type_id     INT,
    IN p_description          TEXT,
    IN p_summary              LONGTEXT,
    IN p_act_year             INT,
    IN p_long_title           TEXT,
    IN p_regional_title       TEXT,
    IN p_notification_no      VARCHAR(100),
    IN p_act_code             VARCHAR(100),
    IN p_so_reason            TEXT,
    IN p_no_of_rules          INT,
    IN p_no_of_notifications  INT,
    IN p_no_of_regulations    INT,
    IN p_no_of_circulars      INT,
    IN p_no_of_statutes       INT,
    IN p_no_of_ordinances     INT,
    IN p_no_of_orders         INT,
    IN p_keywords             TEXT,
    IN p_is_repealed          TINYINT(1),
    IN p_last_updated_on      DATE,
    IN p_status               VARCHAR(20)
)
BEGIN
    INSERT INTO pdf_documents (
        filename, original_filename, file_path, file_size, uploaded_by,
        document_name, reference_number, issue_date, effective_from,
        gazette_reference, legal_authority, short_title, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        version_no, department_id, document_type_id, description, summary,
        act_year, long_title, regional_title, notification_no, act_code, so_reason,
        no_of_rules, no_of_notifications, no_of_regulations, no_of_circulars,
        no_of_statutes, no_of_ordinances, no_of_orders, keywords, is_repealed,
        last_updated_on, status, created_at
    ) VALUES (
        p_filename, p_original_filename, p_file_path, p_file_size, p_uploaded_by,
        p_document_name, p_reference_number, p_issue_date, p_effective_from,
        p_gazette_reference, p_legal_authority, p_short_title, p_valid_until,
        p_sector_domain, p_implementing_agency, p_next_review_date, p_rule_making_authority,
        p_version_no, p_department_id, p_document_type_id, p_description, p_summary,
        p_act_year, p_long_title, p_regional_title, p_notification_no, p_act_code, p_so_reason,
        p_no_of_rules, p_no_of_notifications, p_no_of_regulations, p_no_of_circulars,
        p_no_of_statutes, p_no_of_ordinances, p_no_of_orders, p_keywords, IFNULL(p_is_repealed, 0),
        p_last_updated_on, IFNULL(p_status, 'pending'), UTC_TIMESTAMP(6)
    );

    SELECT
        p.id, p.filename, p.original_filename, p.file_path, p.file_size, p.status,
        p.document_name, p.reference_number, p.issue_date, p.effective_from,
        p.gazette_reference, p.legal_authority, p.short_title, p.valid_until,
        p.sector_domain, p.implementing_agency, p.next_review_date, p.rule_making_authority,
        p.version_no, p.department_id, p.document_type_id, p.description, p.summary,
        p.act_year, p.long_title, p.regional_title, p.notification_no, p.act_code, p.so_reason,
        p.no_of_rules, p.no_of_notifications, p.no_of_regulations, p.no_of_circulars,
        p.no_of_statutes, p.no_of_ordinances, p.no_of_orders, p.keywords, p.is_repealed,
        p.last_updated_on, p.uploaded_by, p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        NULL AS tags,
        NULL AS relationships,
        NULL AS latest_approval
    FROM pdf_documents p
    LEFT JOIN document_types dt  ON dt.id  = p.document_type_id
    LEFT JOIN departments    dep ON dep.id  = p.department_id
    LEFT JOIN users          u   ON u.id   = p.uploaded_by
    WHERE p.id = LAST_INSERT_ID();
END $$

DELIMITER ;
