-- =============================================================================
-- Migration: Add changed_by_user_id to all audit tables
-- Adds the column and recreates all triggers to capture @app_user_id,
-- which is set by the FastAPI application before every write.
--
-- Run AFTER create_audit_tables_and_triggers.sql has already been applied.
-- Run: mysql -u root -p legal_pdf < scripts/add_audit_changed_by.sql
-- =============================================================================

-- Step 1: Add changed_by_user_id column to all 19 audit tables
ALTER TABLE users_audit                   ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE roles_audit                   ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE departments_audit             ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE document_types_audit          ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE tags_audit                    ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE pdf_documents_audit           ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE pdf_document_approvals_audit  ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE pdf_document_relationships_audit ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_structures_audit          ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_chapters_audit            ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_sections_audit            ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_schedules_audit           ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_chapters_audit       ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_sections_audit       ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_schedules_audit      ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_annexures_audit      ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_appendices_audit     ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE act_part_forms_audit          ADD COLUMN changed_by_user_id INT NULL;
ALTER TABLE password_reset_otps_audit     ADD COLUMN changed_by_user_id INT NULL;


-- Step 2: Recreate all 57 triggers to capture @app_user_id
-- @app_user_id is set by the FastAPI app via the before_cursor_execute
-- SQLAlchemy engine event in app/db/session.py before every write.
-- If NULL, the change was made outside the application.

DELIMITER $$

-- =============================================================================
-- 1. users
-- =============================================================================
DROP TRIGGER IF EXISTS tr_users_after_insert $$
CREATE TRIGGER tr_users_after_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (
        id, username, email, hashed_password, is_active, must_change_password,
        mobile_number, password_changed_at, first_name, last_name,
        role_id, department_id, approver_id, mobile_verified, email_verified,
        created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.username, NEW.email, NEW.hashed_password, NEW.is_active,
        NEW.must_change_password, NEW.mobile_number, NEW.password_changed_at,
        NEW.first_name, NEW.last_name, NEW.role_id, NEW.department_id,
        NEW.approver_id, NEW.mobile_verified, NEW.email_verified,
        NEW.created_at, NEW.updated_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_users_after_update $$
CREATE TRIGGER tr_users_after_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (
        id, username, email, hashed_password, is_active, must_change_password,
        mobile_number, password_changed_at, first_name, last_name,
        role_id, department_id, approver_id, mobile_verified, email_verified,
        created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.username, OLD.email, OLD.hashed_password, OLD.is_active,
        OLD.must_change_password, OLD.mobile_number, OLD.password_changed_at,
        OLD.first_name, OLD.last_name, OLD.role_id, OLD.department_id,
        OLD.approver_id, OLD.mobile_verified, OLD.email_verified,
        OLD.created_at, OLD.updated_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_users_after_delete $$
CREATE TRIGGER tr_users_after_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO users_audit (
        id, username, email, hashed_password, is_active, must_change_password,
        mobile_number, password_changed_at, first_name, last_name,
        role_id, department_id, approver_id, mobile_verified, email_verified,
        created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.username, OLD.email, OLD.hashed_password, OLD.is_active,
        OLD.must_change_password, OLD.mobile_number, OLD.password_changed_at,
        OLD.first_name, OLD.last_name, OLD.role_id, OLD.department_id,
        OLD.approver_id, OLD.mobile_verified, OLD.email_verified,
        OLD.created_at, OLD.updated_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 2. roles
-- =============================================================================
DROP TRIGGER IF EXISTS tr_roles_after_insert $$
CREATE TRIGGER tr_roles_after_insert
AFTER INSERT ON roles
FOR EACH ROW
BEGIN
    INSERT INTO roles_audit (id, name, description, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.name, NEW.description, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_roles_after_update $$
CREATE TRIGGER tr_roles_after_update
AFTER UPDATE ON roles
FOR EACH ROW
BEGIN
    INSERT INTO roles_audit (id, name, description, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_roles_after_delete $$
CREATE TRIGGER tr_roles_after_delete
AFTER DELETE ON roles
FOR EACH ROW
BEGIN
    INSERT INTO roles_audit (id, name, description, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.created_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 3. departments
-- =============================================================================
DROP TRIGGER IF EXISTS tr_departments_after_insert $$
CREATE TRIGGER tr_departments_after_insert
AFTER INSERT ON departments
FOR EACH ROW
BEGIN
    INSERT INTO departments_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.name, NEW.description, NEW.is_active, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_departments_after_update $$
CREATE TRIGGER tr_departments_after_update
AFTER UPDATE ON departments
FOR EACH ROW
BEGIN
    INSERT INTO departments_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.is_active, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_departments_after_delete $$
CREATE TRIGGER tr_departments_after_delete
AFTER DELETE ON departments
FOR EACH ROW
BEGIN
    INSERT INTO departments_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.is_active, OLD.created_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 4. document_types
-- =============================================================================
DROP TRIGGER IF EXISTS tr_document_types_after_insert $$
CREATE TRIGGER tr_document_types_after_insert
AFTER INSERT ON document_types
FOR EACH ROW
BEGIN
    INSERT INTO document_types_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.name, NEW.description, NEW.is_active, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_document_types_after_update $$
CREATE TRIGGER tr_document_types_after_update
AFTER UPDATE ON document_types
FOR EACH ROW
BEGIN
    INSERT INTO document_types_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.is_active, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_document_types_after_delete $$
CREATE TRIGGER tr_document_types_after_delete
AFTER DELETE ON document_types
FOR EACH ROW
BEGIN
    INSERT INTO document_types_audit (id, name, description, is_active, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.description, OLD.is_active, OLD.created_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 5. tags
-- =============================================================================
DROP TRIGGER IF EXISTS tr_tags_after_insert $$
CREATE TRIGGER tr_tags_after_insert
AFTER INSERT ON tags
FOR EACH ROW
BEGIN
    INSERT INTO tags_audit (id, name, parent_id, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.name, NEW.parent_id, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_tags_after_update $$
CREATE TRIGGER tr_tags_after_update
AFTER UPDATE ON tags
FOR EACH ROW
BEGIN
    INSERT INTO tags_audit (id, name, parent_id, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.parent_id, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_tags_after_delete $$
CREATE TRIGGER tr_tags_after_delete
AFTER DELETE ON tags
FOR EACH ROW
BEGIN
    INSERT INTO tags_audit (id, name, parent_id, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.name, OLD.parent_id, OLD.created_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 6. pdf_documents
-- =============================================================================
DROP TRIGGER IF EXISTS tr_pdf_documents_after_insert $$
CREATE TRIGGER tr_pdf_documents_after_insert
AFTER INSERT ON pdf_documents
FOR EACH ROW
BEGIN
    INSERT INTO pdf_documents_audit (
        id, filename, original_filename, file_path, file_size,
        document_name, issue_date, version_no, department_id, document_type_id,
        description, summary, reference_number, effective_from, gazette_reference,
        legal_authority, short_title, act_year, long_title, regional_title,
        notification_no, act_code, so_reason, no_of_rules, no_of_notifications,
        no_of_regulations, no_of_circulars, no_of_statutes, no_of_ordinances,
        no_of_orders, keywords, is_repealed, last_updated_on, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        status, uploaded_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.filename, NEW.original_filename, NEW.file_path, NEW.file_size,
        NEW.document_name, NEW.issue_date, NEW.version_no, NEW.department_id, NEW.document_type_id,
        NEW.description, NEW.summary, NEW.reference_number, NEW.effective_from, NEW.gazette_reference,
        NEW.legal_authority, NEW.short_title, NEW.act_year, NEW.long_title, NEW.regional_title,
        NEW.notification_no, NEW.act_code, NEW.so_reason, NEW.no_of_rules, NEW.no_of_notifications,
        NEW.no_of_regulations, NEW.no_of_circulars, NEW.no_of_statutes, NEW.no_of_ordinances,
        NEW.no_of_orders, NEW.keywords, NEW.is_repealed, NEW.last_updated_on, NEW.valid_until,
        NEW.sector_domain, NEW.implementing_agency, NEW.next_review_date, NEW.rule_making_authority,
        NEW.status, NEW.uploaded_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_pdf_documents_after_update $$
CREATE TRIGGER tr_pdf_documents_after_update
AFTER UPDATE ON pdf_documents
FOR EACH ROW
BEGIN
    INSERT INTO pdf_documents_audit (
        id, filename, original_filename, file_path, file_size,
        document_name, issue_date, version_no, department_id, document_type_id,
        description, summary, reference_number, effective_from, gazette_reference,
        legal_authority, short_title, act_year, long_title, regional_title,
        notification_no, act_code, so_reason, no_of_rules, no_of_notifications,
        no_of_regulations, no_of_circulars, no_of_statutes, no_of_ordinances,
        no_of_orders, keywords, is_repealed, last_updated_on, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        status, uploaded_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.filename, OLD.original_filename, OLD.file_path, OLD.file_size,
        OLD.document_name, OLD.issue_date, OLD.version_no, OLD.department_id, OLD.document_type_id,
        OLD.description, OLD.summary, OLD.reference_number, OLD.effective_from, OLD.gazette_reference,
        OLD.legal_authority, OLD.short_title, OLD.act_year, OLD.long_title, OLD.regional_title,
        OLD.notification_no, OLD.act_code, OLD.so_reason, OLD.no_of_rules, OLD.no_of_notifications,
        OLD.no_of_regulations, OLD.no_of_circulars, OLD.no_of_statutes, OLD.no_of_ordinances,
        OLD.no_of_orders, OLD.keywords, OLD.is_repealed, OLD.last_updated_on, OLD.valid_until,
        OLD.sector_domain, OLD.implementing_agency, OLD.next_review_date, OLD.rule_making_authority,
        OLD.status, OLD.uploaded_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_pdf_documents_after_delete $$
CREATE TRIGGER tr_pdf_documents_after_delete
AFTER DELETE ON pdf_documents
FOR EACH ROW
BEGIN
    INSERT INTO pdf_documents_audit (
        id, filename, original_filename, file_path, file_size,
        document_name, issue_date, version_no, department_id, document_type_id,
        description, summary, reference_number, effective_from, gazette_reference,
        legal_authority, short_title, act_year, long_title, regional_title,
        notification_no, act_code, so_reason, no_of_rules, no_of_notifications,
        no_of_regulations, no_of_circulars, no_of_statutes, no_of_ordinances,
        no_of_orders, keywords, is_repealed, last_updated_on, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        status, uploaded_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.filename, OLD.original_filename, OLD.file_path, OLD.file_size,
        OLD.document_name, OLD.issue_date, OLD.version_no, OLD.department_id, OLD.document_type_id,
        OLD.description, OLD.summary, OLD.reference_number, OLD.effective_from, OLD.gazette_reference,
        OLD.legal_authority, OLD.short_title, OLD.act_year, OLD.long_title, OLD.regional_title,
        OLD.notification_no, OLD.act_code, OLD.so_reason, OLD.no_of_rules, OLD.no_of_notifications,
        OLD.no_of_regulations, OLD.no_of_circulars, OLD.no_of_statutes, OLD.no_of_ordinances,
        OLD.no_of_orders, OLD.keywords, OLD.is_repealed, OLD.last_updated_on, OLD.valid_until,
        OLD.sector_domain, OLD.implementing_agency, OLD.next_review_date, OLD.rule_making_authority,
        OLD.status, OLD.uploaded_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 7. pdf_document_approvals
-- =============================================================================
DROP TRIGGER IF EXISTS tr_pdf_document_approvals_after_insert $$
CREATE TRIGGER tr_pdf_document_approvals_after_insert
AFTER INSERT ON pdf_document_approvals
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_approvals_audit (id, pdf_id, approver_id, action, comments, acted_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.pdf_id, NEW.approver_id, NEW.action, NEW.comments, NEW.acted_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_pdf_document_approvals_after_update $$
CREATE TRIGGER tr_pdf_document_approvals_after_update
AFTER UPDATE ON pdf_document_approvals
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_approvals_audit (id, pdf_id, approver_id, action, comments, acted_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.pdf_id, OLD.approver_id, OLD.action, OLD.comments, OLD.acted_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_pdf_document_approvals_after_delete $$
CREATE TRIGGER tr_pdf_document_approvals_after_delete
AFTER DELETE ON pdf_document_approvals
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_approvals_audit (id, pdf_id, approver_id, action, comments, acted_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.pdf_id, OLD.approver_id, OLD.action, OLD.comments, OLD.acted_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 8. pdf_document_relationships
-- =============================================================================
DROP TRIGGER IF EXISTS tr_pdf_document_relationships_after_insert $$
CREATE TRIGGER tr_pdf_document_relationships_after_insert
AFTER INSERT ON pdf_document_relationships
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_relationships_audit (id, source_pdf_id, target_pdf_id, relationship_type, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.source_pdf_id, NEW.target_pdf_id, NEW.relationship_type, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_pdf_document_relationships_after_update $$
CREATE TRIGGER tr_pdf_document_relationships_after_update
AFTER UPDATE ON pdf_document_relationships
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_relationships_audit (id, source_pdf_id, target_pdf_id, relationship_type, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.source_pdf_id, OLD.target_pdf_id, OLD.relationship_type, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_pdf_document_relationships_after_delete $$
CREATE TRIGGER tr_pdf_document_relationships_after_delete
AFTER DELETE ON pdf_document_relationships
FOR EACH ROW
BEGIN
    INSERT INTO pdf_document_relationships_audit (id, source_pdf_id, target_pdf_id, relationship_type, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.source_pdf_id, OLD.target_pdf_id, OLD.relationship_type, OLD.created_at, 'DELETE', @app_user_id);
END $$


-- =============================================================================
-- 9. act_structures
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_structures_after_insert $$
CREATE TRIGGER tr_act_structures_after_insert
AFTER INSERT ON act_structures
FOR EACH ROW
BEGIN
    INSERT INTO act_structures_audit (
        id, pdf_document_id, act_title, act_number, act_year,
        total_chapters, total_sections, total_schedules,
        extraction_status, error_message, created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.act_title, NEW.act_number, NEW.act_year,
        NEW.total_chapters, NEW.total_sections, NEW.total_schedules,
        NEW.extraction_status, NEW.error_message, NEW.created_at, NEW.updated_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_structures_after_update $$
CREATE TRIGGER tr_act_structures_after_update
AFTER UPDATE ON act_structures
FOR EACH ROW
BEGIN
    INSERT INTO act_structures_audit (
        id, pdf_document_id, act_title, act_number, act_year,
        total_chapters, total_sections, total_schedules,
        extraction_status, error_message, created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.act_title, OLD.act_number, OLD.act_year,
        OLD.total_chapters, OLD.total_sections, OLD.total_schedules,
        OLD.extraction_status, OLD.error_message, OLD.created_at, OLD.updated_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_structures_after_delete $$
CREATE TRIGGER tr_act_structures_after_delete
AFTER DELETE ON act_structures
FOR EACH ROW
BEGIN
    INSERT INTO act_structures_audit (
        id, pdf_document_id, act_title, act_number, act_year,
        total_chapters, total_sections, total_schedules,
        extraction_status, error_message, created_at, updated_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.act_title, OLD.act_number, OLD.act_year,
        OLD.total_chapters, OLD.total_sections, OLD.total_schedules,
        OLD.extraction_status, OLD.error_message, OLD.created_at, OLD.updated_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 10. act_chapters
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_chapters_after_insert $$
CREATE TRIGGER tr_act_chapters_after_insert
AFTER INSERT ON act_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_chapters_audit (
        id, act_structure_id, chapter_number, chapter_title,
        chapter_description, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.act_structure_id, NEW.chapter_number, NEW.chapter_title,
        NEW.chapter_description, NEW.display_order, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_chapters_after_update $$
CREATE TRIGGER tr_act_chapters_after_update
AFTER UPDATE ON act_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_chapters_audit (
        id, act_structure_id, chapter_number, chapter_title,
        chapter_description, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.chapter_number, OLD.chapter_title,
        OLD.chapter_description, OLD.display_order, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_chapters_after_delete $$
CREATE TRIGGER tr_act_chapters_after_delete
AFTER DELETE ON act_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_chapters_audit (
        id, act_structure_id, chapter_number, chapter_title,
        chapter_description, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.chapter_number, OLD.chapter_title,
        OLD.chapter_description, OLD.display_order, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 11. act_sections
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_sections_after_insert $$
CREATE TRIGGER tr_act_sections_after_insert
AFTER INSERT ON act_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_sections_audit (
        id, act_structure_id, act_chapter_id, section_number,
        section_title, section_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.act_structure_id, NEW.act_chapter_id, NEW.section_number,
        NEW.section_title, NEW.section_content, NEW.display_order, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_sections_after_update $$
CREATE TRIGGER tr_act_sections_after_update
AFTER UPDATE ON act_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_sections_audit (
        id, act_structure_id, act_chapter_id, section_number,
        section_title, section_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.act_chapter_id, OLD.section_number,
        OLD.section_title, OLD.section_content, OLD.display_order, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_sections_after_delete $$
CREATE TRIGGER tr_act_sections_after_delete
AFTER DELETE ON act_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_sections_audit (
        id, act_structure_id, act_chapter_id, section_number,
        section_title, section_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.act_chapter_id, OLD.section_number,
        OLD.section_title, OLD.section_content, OLD.display_order, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 12. act_schedules
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_schedules_after_insert $$
CREATE TRIGGER tr_act_schedules_after_insert
AFTER INSERT ON act_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_schedules_audit (
        id, act_structure_id, schedule_number, schedule_title,
        schedule_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.act_structure_id, NEW.schedule_number, NEW.schedule_title,
        NEW.schedule_content, NEW.display_order, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_schedules_after_update $$
CREATE TRIGGER tr_act_schedules_after_update
AFTER UPDATE ON act_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_schedules_audit (
        id, act_structure_id, schedule_number, schedule_title,
        schedule_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.schedule_number, OLD.schedule_title,
        OLD.schedule_content, OLD.display_order, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_schedules_after_delete $$
CREATE TRIGGER tr_act_schedules_after_delete
AFTER DELETE ON act_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_schedules_audit (
        id, act_structure_id, schedule_number, schedule_title,
        schedule_content, display_order, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.act_structure_id, OLD.schedule_number, OLD.schedule_title,
        OLD.schedule_content, OLD.display_order, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 13. act_part_chapters
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_chapters_after_insert $$
CREATE TRIGGER tr_act_part_chapters_after_insert
AFTER INSERT ON act_part_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_part_chapters_audit (
        id, pdf_document_id, chapter_number, chapter_title,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.chapter_number, NEW.chapter_title,
        NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_chapters_after_update $$
CREATE TRIGGER tr_act_part_chapters_after_update
AFTER UPDATE ON act_part_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_part_chapters_audit (
        id, pdf_document_id, chapter_number, chapter_title,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.chapter_number, OLD.chapter_title,
        OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_chapters_after_delete $$
CREATE TRIGGER tr_act_part_chapters_after_delete
AFTER DELETE ON act_part_chapters
FOR EACH ROW
BEGIN
    INSERT INTO act_part_chapters_audit (
        id, pdf_document_id, chapter_number, chapter_title,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.chapter_number, OLD.chapter_title,
        OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 14. act_part_sections
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_sections_after_insert $$
CREATE TRIGGER tr_act_part_sections_after_insert
AFTER INSERT ON act_part_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_part_sections_audit (
        id, pdf_document_id, chapter_id, section_number, section_title,
        section_content, file_path, file_size, original_filename,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.chapter_id, NEW.section_number, NEW.section_title,
        NEW.section_content, NEW.file_path, NEW.file_size, NEW.original_filename,
        NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_sections_after_update $$
CREATE TRIGGER tr_act_part_sections_after_update
AFTER UPDATE ON act_part_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_part_sections_audit (
        id, pdf_document_id, chapter_id, section_number, section_title,
        section_content, file_path, file_size, original_filename,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.chapter_id, OLD.section_number, OLD.section_title,
        OLD.section_content, OLD.file_path, OLD.file_size, OLD.original_filename,
        OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_sections_after_delete $$
CREATE TRIGGER tr_act_part_sections_after_delete
AFTER DELETE ON act_part_sections
FOR EACH ROW
BEGIN
    INSERT INTO act_part_sections_audit (
        id, pdf_document_id, chapter_id, section_number, section_title,
        section_content, file_path, file_size, original_filename,
        display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.chapter_id, OLD.section_number, OLD.section_title,
        OLD.section_content, OLD.file_path, OLD.file_size, OLD.original_filename,
        OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 15. act_part_schedules
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_schedules_after_insert $$
CREATE TRIGGER tr_act_part_schedules_after_insert
AFTER INSERT ON act_part_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_part_schedules_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.entry_number, NEW.title, NEW.description,
        NEW.file_path, NEW.file_size, NEW.original_filename, NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_schedules_after_update $$
CREATE TRIGGER tr_act_part_schedules_after_update
AFTER UPDATE ON act_part_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_part_schedules_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_schedules_after_delete $$
CREATE TRIGGER tr_act_part_schedules_after_delete
AFTER DELETE ON act_part_schedules
FOR EACH ROW
BEGIN
    INSERT INTO act_part_schedules_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 16. act_part_annexures
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_annexures_after_insert $$
CREATE TRIGGER tr_act_part_annexures_after_insert
AFTER INSERT ON act_part_annexures
FOR EACH ROW
BEGIN
    INSERT INTO act_part_annexures_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.entry_number, NEW.title, NEW.description,
        NEW.file_path, NEW.file_size, NEW.original_filename, NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_annexures_after_update $$
CREATE TRIGGER tr_act_part_annexures_after_update
AFTER UPDATE ON act_part_annexures
FOR EACH ROW
BEGIN
    INSERT INTO act_part_annexures_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_annexures_after_delete $$
CREATE TRIGGER tr_act_part_annexures_after_delete
AFTER DELETE ON act_part_annexures
FOR EACH ROW
BEGIN
    INSERT INTO act_part_annexures_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 17. act_part_appendices
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_appendices_after_insert $$
CREATE TRIGGER tr_act_part_appendices_after_insert
AFTER INSERT ON act_part_appendices
FOR EACH ROW
BEGIN
    INSERT INTO act_part_appendices_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.entry_number, NEW.title, NEW.description,
        NEW.file_path, NEW.file_size, NEW.original_filename, NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_appendices_after_update $$
CREATE TRIGGER tr_act_part_appendices_after_update
AFTER UPDATE ON act_part_appendices
FOR EACH ROW
BEGIN
    INSERT INTO act_part_appendices_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_appendices_after_delete $$
CREATE TRIGGER tr_act_part_appendices_after_delete
AFTER DELETE ON act_part_appendices
FOR EACH ROW
BEGIN
    INSERT INTO act_part_appendices_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 18. act_part_forms
-- =============================================================================
DROP TRIGGER IF EXISTS tr_act_part_forms_after_insert $$
CREATE TRIGGER tr_act_part_forms_after_insert
AFTER INSERT ON act_part_forms
FOR EACH ROW
BEGIN
    INSERT INTO act_part_forms_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        NEW.id, NEW.pdf_document_id, NEW.entry_number, NEW.title, NEW.description,
        NEW.file_path, NEW.file_size, NEW.original_filename, NEW.display_order, NEW.created_by, NEW.created_at, 'INSERT', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_forms_after_update $$
CREATE TRIGGER tr_act_part_forms_after_update
AFTER UPDATE ON act_part_forms
FOR EACH ROW
BEGIN
    INSERT INTO act_part_forms_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'UPDATE', @app_user_id
    );
END $$

DROP TRIGGER IF EXISTS tr_act_part_forms_after_delete $$
CREATE TRIGGER tr_act_part_forms_after_delete
AFTER DELETE ON act_part_forms
FOR EACH ROW
BEGIN
    INSERT INTO act_part_forms_audit (
        id, pdf_document_id, entry_number, title, description,
        file_path, file_size, original_filename, display_order, created_by, created_at, audit_action, changed_by_user_id
    ) VALUES (
        OLD.id, OLD.pdf_document_id, OLD.entry_number, OLD.title, OLD.description,
        OLD.file_path, OLD.file_size, OLD.original_filename, OLD.display_order, OLD.created_by, OLD.created_at, 'DELETE', @app_user_id
    );
END $$


-- =============================================================================
-- 19. password_reset_otps
-- =============================================================================
DROP TRIGGER IF EXISTS tr_password_reset_otps_after_insert $$
CREATE TRIGGER tr_password_reset_otps_after_insert
AFTER INSERT ON password_reset_otps
FOR EACH ROW
BEGIN
    INSERT INTO password_reset_otps_audit (id, user_id, otp_hash, channel, expires_at, created_at, audit_action, changed_by_user_id)
    VALUES (NEW.id, NEW.user_id, NEW.otp_hash, NEW.channel, NEW.expires_at, NEW.created_at, 'INSERT', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_password_reset_otps_after_update $$
CREATE TRIGGER tr_password_reset_otps_after_update
AFTER UPDATE ON password_reset_otps
FOR EACH ROW
BEGIN
    INSERT INTO password_reset_otps_audit (id, user_id, otp_hash, channel, expires_at, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.user_id, OLD.otp_hash, OLD.channel, OLD.expires_at, OLD.created_at, 'UPDATE', @app_user_id);
END $$

DROP TRIGGER IF EXISTS tr_password_reset_otps_after_delete $$
CREATE TRIGGER tr_password_reset_otps_after_delete
AFTER DELETE ON password_reset_otps
FOR EACH ROW
BEGIN
    INSERT INTO password_reset_otps_audit (id, user_id, otp_hash, channel, expires_at, created_at, audit_action, changed_by_user_id)
    VALUES (OLD.id, OLD.user_id, OLD.otp_hash, OLD.channel, OLD.expires_at, OLD.created_at, 'DELETE', @app_user_id);
END $$


DELIMITER ;

-- =============================================================================
-- Verification
-- =============================================================================
-- SELECT audit_id, id, email, audit_action, changed_by_user_id, audit_timestamp
-- FROM users_audit ORDER BY audit_id DESC LIMIT 10;
--
-- A NULL changed_by_user_id means the change was made outside the application
-- (e.g. direct DB script or migration).
