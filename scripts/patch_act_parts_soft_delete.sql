-- Patch: soft-delete support for act_parts tables
-- Run: mysql -u root -p Legal_PDF < scripts/patch_act_parts_soft_delete.sql

-- ── 1. Add is_deleted column to all six tables ────────────────────────────────

ALTER TABLE act_part_chapters  ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;
ALTER TABLE act_part_sections  ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;
ALTER TABLE act_part_schedules ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;
ALTER TABLE act_part_annexures ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;
ALTER TABLE act_part_appendices ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;
ALTER TABLE act_part_forms     ADD COLUMN is_deleted TINYINT NOT NULL DEFAULT 0;

-- ── 2. Rewrite sp_save_act_part_sections — upsert by id, no hard deletes ─────

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
                UPDATE act_part_chapters SET
                    chapter_number = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                    chapter_title  = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                    display_order  = ch_idx,
                    is_deleted     = v_is_deleted
                WHERE id = v_ch_id AND pdf_document_id = p_pdf_document_id;
                SET v_chapter_id = v_ch_id;
            ELSE
                INSERT INTO act_part_chapters (pdf_document_id, chapter_number, chapter_title, display_order, created_by, is_deleted)
                VALUES (
                    p_pdf_document_id,
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                    ch_idx,
                    p_created_by,
                    0
                );
                SET v_chapter_id = LAST_INSERT_ID();
            END IF;

            -- Process sections for this chapter
            SET sec_count = JSON_LENGTH(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections')));
            SET sec_idx = 0;
            WHILE sec_idx < sec_count DO
                SET v_sec_id     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].id'))),         'null') AS SIGNED);
                SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].is_deleted')), 0) AS SIGNED);

                IF v_sec_id IS NOT NULL THEN
                    UPDATE act_part_sections SET
                        section_number    = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_number'))),
                        section_title     = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_title'))),
                        section_content   = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_content'))),
                        file_path         = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_path'))),
                        file_size         = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                        original_filename = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].original_filename'))),
                        display_order     = sec_idx,
                        is_deleted        = v_is_deleted
                    WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
                ELSE
                    INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by, is_deleted)
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
                        0
                    );
                END IF;
                SET sec_idx = sec_idx + 1;
            END WHILE;

            SET ch_idx = ch_idx + 1;
        END WHILE;

    ELSEIF p_has_chapters = 0 AND p_flat_json IS NOT NULL THEN
        SET sec_count = JSON_LENGTH(p_flat_json);
        SET sec_idx = 0;
        WHILE sec_idx < sec_count DO
            SET v_sec_id     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].id'))),         'null') AS SIGNED);
            SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].is_deleted')), 0) AS SIGNED);

            IF v_sec_id IS NOT NULL THEN
                UPDATE act_part_sections SET
                    section_number    = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_number'))),
                    section_title     = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_title'))),
                    section_content   = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].section_content'))),
                    file_path         = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_path'))),
                    file_size         = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                    original_filename = JSON_UNQUOTE(JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].original_filename'))),
                    display_order     = sec_idx,
                    is_deleted        = v_is_deleted
                WHERE id = v_sec_id AND pdf_document_id = p_pdf_document_id;
            ELSE
                INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by, is_deleted)
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
                    0
                );
            END IF;
            SET sec_idx = sec_idx + 1;
        END WHILE;
    END IF;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ── 3. Rewrite sp_save_act_part_entries — upsert by id, no hard deletes ──────

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

    -- Bind procedure params to user variables so EXECUTE USING can reference them
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
                SET @sql_upd = CONCAT(
                    'UPDATE ', tbl,
                    ' SET entry_number=?, title=?, description=?, file_path=?, file_size=?, original_filename=?, display_order=?, is_deleted=?',
                    ' WHERE id=? AND pdf_document_id=?'
                );
                PREPARE stmt_upd FROM @sql_upd;
                EXECUTE stmt_upd USING @v_enum, @v_title, @v_desc, @v_fpath, @v_fsize, @v_ofname, @v_order, @v_is_del, @v_entry_id, @v_pdf_doc_id;
                DEALLOCATE PREPARE stmt_upd;
            ELSE
                SET @sql_ins = CONCAT(
                    'INSERT INTO ', tbl,
                    ' (pdf_document_id, entry_number, title, description, file_path, file_size, original_filename, display_order, created_by, is_deleted)',
                    ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)'
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
