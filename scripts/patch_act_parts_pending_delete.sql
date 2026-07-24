-- Patch: approval-gated deletion for chapters, sections, and flat entries
-- When an uploader marks an existing item for deletion, instead of immediately
-- setting is_deleted=1, we set status='pending_delete' and keep is_deleted=0.
-- The approver then either confirms (is_deleted=1) or cancels (status restored).
--
-- Run: mysql -u root -p Legal_PDF < scripts/patch_act_parts_pending_delete.sql

-- ── 1. Extend status ENUM on all 6 item tables ────────────────────────────────

ALTER TABLE act_part_chapters   MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';
ALTER TABLE act_part_sections   MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';
ALTER TABLE act_part_schedules  MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';
ALTER TABLE act_part_annexures  MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';
ALTER TABLE act_part_appendices MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';
ALTER TABLE act_part_forms      MODIFY COLUMN status ENUM('draft','pending','approved','rejected','pending_delete') NOT NULL DEFAULT 'draft';

-- ── 2. Rewrite sp_save_act_part_sections ──────────────────────────────────────
-- Deletion of an existing chapter/section → pending_delete + keep is_deleted=0.
-- Cascade: deleting a chapter also marks its active sections as pending_delete.

DROP PROCEDURE IF EXISTS `sp_save_act_part_sections`;
DELIMITER ;;
CREATE PROCEDURE `sp_save_act_part_sections`(
    IN p_pdf_document_id INT UNSIGNED,
    IN p_created_by      INT UNSIGNED,
    IN p_has_chapters    TINYINT,
    IN p_chapters_json   JSON,
    IN p_flat_json       JSON
)
BEGIN
    DECLARE ch_idx       INT DEFAULT 0;
    DECLARE ch_count     INT DEFAULT 0;
    DECLARE sec_idx      INT DEFAULT 0;
    DECLARE sec_count    INT DEFAULT 0;
    DECLARE v_chapter_id INT UNSIGNED DEFAULT NULL;
    DECLARE v_ch_id      INT DEFAULT NULL;
    DECLARE v_sec_id     INT DEFAULT NULL;
    DECLARE v_is_deleted TINYINT DEFAULT 0;

    IF p_has_chapters = 1 AND p_chapters_json IS NOT NULL THEN
        SET ch_count = JSON_LENGTH(p_chapters_json);
        WHILE ch_idx < ch_count DO
            SET v_ch_id      = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].id'))),         'null') AS SIGNED);
            SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].is_deleted')), 0) AS SIGNED);

            IF v_ch_id IS NOT NULL THEN
                IF v_is_deleted = 1 THEN
                    -- Queue chapter deletion for approval
                    UPDATE act_part_chapters SET status = 'pending_delete', is_deleted = 0
                        WHERE id = v_ch_id AND pdf_document_id = p_pdf_document_id;
                    -- Cascade: also queue all active sections for deletion
                    UPDATE act_part_sections SET status = 'pending_delete', is_deleted = 0
                        WHERE chapter_id = v_ch_id AND pdf_document_id = p_pdf_document_id AND is_deleted = 0;
                ELSE
                    UPDATE act_part_chapters SET
                        chapter_number = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                        chapter_title  = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                        display_order  = ch_idx,
                        is_deleted     = 0
                    WHERE id = v_ch_id AND pdf_document_id = p_pdf_document_id;
                END IF;
                SET v_chapter_id = v_ch_id;
            ELSE
                INSERT INTO act_part_chapters (pdf_document_id, chapter_number, chapter_title, display_order, created_by, is_deleted, status)
                VALUES (
                    p_pdf_document_id,
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                    ch_idx,
                    p_created_by,
                    0,
                    'draft'
                );
                SET v_chapter_id = LAST_INSERT_ID();
            END IF;

            -- Process sections only for chapters not queued for deletion
            IF v_is_deleted = 0 THEN
                SET sec_count = JSON_LENGTH(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections')));
                SET sec_idx = 0;
                WHILE sec_idx < sec_count DO
                    SET v_sec_id     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].id'))),         'null') AS SIGNED);
                    SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].is_deleted')), 0) AS SIGNED);

                    IF v_sec_id IS NOT NULL THEN
                        IF v_is_deleted = 1 THEN
                            -- Queue section deletion for approval
                            UPDATE act_part_sections SET status = 'pending_delete', is_deleted = 0
                                WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
                        ELSE
                            UPDATE act_part_sections SET
                                section_number    = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_number'))),
                                section_title     = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_title'))),
                                section_content   = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_content'))),
                                file_path         = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_path'))),
                                file_size         = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                                original_filename = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].original_filename'))),
                                display_order     = sec_idx,
                                is_deleted        = 0
                            WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
                        END IF;
                    ELSE
                        INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by, is_deleted, status)
                        VALUES (
                            p_pdf_document_id,
                            v_chapter_id,
                            JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_number'))),
                            JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_title'))),
                            JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_content'))),
                            JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_path'))),
                            CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                            JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].original_filename'))),
                            sec_idx,
                            p_created_by,
                            0,
                            'draft'
                        );
                    END IF;
                    SET sec_idx = sec_idx + 1;
                END WHILE;
            END IF;

            SET ch_idx = ch_idx + 1;
        END WHILE;

    ELSEIF p_has_chapters = 0 AND p_flat_json IS NOT NULL THEN
        SET sec_count = JSON_LENGTH(p_flat_json);
        SET sec_idx = 0;
        WHILE sec_idx < sec_count DO
            SET v_sec_id     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].id'))),         'null') AS SIGNED);
            SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].is_deleted')), 0) AS SIGNED);

            IF v_sec_id IS NOT NULL THEN
                IF v_is_deleted = 1 THEN
                    UPDATE act_part_sections SET status = 'pending_delete', is_deleted = 0
                        WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
                ELSE
                    UPDATE act_part_sections SET
                        section_number    = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_number'))),
                        section_title     = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_title'))),
                        section_content   = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_content'))),
                        file_path         = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_path'))),
                        file_size         = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                        original_filename = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].original_filename'))),
                        display_order     = sec_idx,
                        is_deleted        = 0
                    WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
                END IF;
            ELSE
                INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by, is_deleted, status)
                VALUES (
                    p_pdf_document_id,
                    NULL,
                    JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_number'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_title'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_content'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_path'))),
                    CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                    JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].original_filename'))),
                    sec_idx,
                    p_created_by,
                    0,
                    'draft'
                );
            END IF;
            SET sec_idx = sec_idx + 1;
        END WHILE;
    END IF;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ── 3. Rewrite sp_save_act_part_entries ───────────────────────────────────────
-- Deletion of an existing entry → pending_delete + keep is_deleted=0.

DROP PROCEDURE IF EXISTS `sp_save_act_part_entries`;
DELIMITER ;;
CREATE PROCEDURE `sp_save_act_part_entries`(
    IN p_part_type       VARCHAR(20),
    IN p_pdf_document_id INT UNSIGNED,
    IN p_created_by      INT UNSIGNED,
    IN p_entries_json    JSON
)
BEGIN
    DECLARE entry_idx   INT DEFAULT 0;
    DECLARE entry_count INT DEFAULT 0;
    DECLARE tbl         VARCHAR(50);

    SET tbl = CASE p_part_type
        WHEN 'schedule'  THEN 'act_part_schedules'
        WHEN 'annexure'  THEN 'act_part_annexures'
        WHEN 'appendix'  THEN 'act_part_appendices'
        WHEN 'form'      THEN 'act_part_forms'
        ELSE NULL
    END;

    IF tbl IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown part_type';
    END IF;

    SET @v_pdf_doc_id = p_pdf_document_id;
    SET @v_cb         = p_created_by;

    IF p_entries_json IS NOT NULL THEN
        SET entry_count = JSON_LENGTH(p_entries_json);
        WHILE entry_idx < entry_count DO
            SET @v_entry_id = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].id'))),         'null') AS SIGNED);
            SET @v_is_del   = CAST(IFNULL(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].is_deleted')), 0) AS SIGNED);
            SET @v_enum     = JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].entry_number')));
            SET @v_title    = JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].title')));
            SET @v_desc     = JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].description')));
            SET @v_fpath    = JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].file_path')));
            SET @v_fsize    = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].file_size'))), 'null') AS SIGNED);
            SET @v_ofname   = JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].original_filename')));
            SET @v_order    = entry_idx;

            IF @v_entry_id IS NOT NULL THEN
                IF @v_is_del = 1 THEN
                    -- Queue deletion for approval instead of immediately soft-deleting
                    SET @sql_del = CONCAT(
                        'UPDATE ', tbl,
                        " SET status='pending_delete', is_deleted=0",
                        ' WHERE id=? AND pdf_document_id=?'
                    );
                    PREPARE stmt_del FROM @sql_del;
                    EXECUTE stmt_del USING @v_entry_id, @v_pdf_doc_id;
                    DEALLOCATE PREPARE stmt_del;
                ELSE
                    SET @sql_upd = CONCAT(
                        'UPDATE ', tbl,
                        ' SET entry_number=?, title=?, description=?, file_path=?, file_size=?, original_filename=?, display_order=?, is_deleted=0',
                        ' WHERE id=? AND pdf_document_id=?'
                    );
                    PREPARE stmt_upd FROM @sql_upd;
                    EXECUTE stmt_upd USING @v_enum, @v_title, @v_desc, @v_fpath, @v_fsize, @v_ofname, @v_order, @v_entry_id, @v_pdf_doc_id;
                    DEALLOCATE PREPARE stmt_upd;
                END IF;
            ELSE
                SET @sql_ins = CONCAT(
                    'INSERT INTO ', tbl,
                    ' (pdf_document_id, entry_number, title, description, file_path, file_size, original_filename, display_order, created_by, is_deleted, status)',
                    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'draft')"
                );
                PREPARE stmt_ins FROM @sql_ins;
                EXECUTE stmt_ins USING @v_pdf_doc_id, @v_enum, @v_title, @v_desc, @v_fpath, @v_fsize, @v_ofname, @v_order, @v_cb;
                DEALLOCATE PREPARE stmt_ins;
            END IF;

            SET entry_idx = entry_idx + 1;
        END WHILE;
    END IF;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ── 4. Rewrite sp_review_act_parts ────────────────────────────────────────────
-- Approve:  pending_delete items → is_deleted=1 (deletion confirmed).
-- Reject:   pending_delete items → status='approved', is_deleted=0 (deletion cancelled).
-- Regular items (pending/draft) continue to get the approve/reject decision as before.

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

    -- Transition regular items (pending/draft) to the approver's decision.
    -- For pending_delete items: approve confirms the deletion (is_deleted=1);
    -- reject cancels the deletion (status restored to 'approved').
    IF p_part_type = 'sections' THEN
        UPDATE act_part_chapters SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        UPDATE act_part_sections SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        IF p_action = 'approved' THEN
            UPDATE act_part_chapters SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
            UPDATE act_part_sections SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        ELSE
            UPDATE act_part_chapters SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
            UPDATE act_part_sections SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        END IF;
    ELSEIF p_part_type = 'schedule' THEN
        UPDATE act_part_schedules SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        IF p_action = 'approved' THEN
            UPDATE act_part_schedules SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        ELSE
            UPDATE act_part_schedules SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        END IF;
    ELSEIF p_part_type = 'annexure' THEN
        UPDATE act_part_annexures SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        IF p_action = 'approved' THEN
            UPDATE act_part_annexures SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        ELSE
            UPDATE act_part_annexures SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        END IF;
    ELSEIF p_part_type = 'appendix' THEN
        UPDATE act_part_appendices SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        IF p_action = 'approved' THEN
            UPDATE act_part_appendices SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        ELSE
            UPDATE act_part_appendices SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        END IF;
    ELSEIF p_part_type = 'forms' THEN
        UPDATE act_part_forms SET status = p_action
            WHERE pdf_document_id = p_pdf_document_id
              AND status IN ('pending', 'draft') AND is_deleted = 0;
        IF p_action = 'approved' THEN
            UPDATE act_part_forms SET status = 'approved', is_deleted = 1
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        ELSE
            UPDATE act_part_forms SET status = 'approved'
                WHERE pdf_document_id = p_pdf_document_id AND status = 'pending_delete';
        END IF;
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
