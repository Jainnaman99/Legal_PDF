-- Patch: fix NULL file_size handling in act_parts stored procedures
-- Run: mysql -u root -p Legal_PDF < scripts/patch_act_parts_file_size_null.sql

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
    DECLARE ch_idx      INT DEFAULT 0;
    DECLARE ch_count    INT DEFAULT 0;
    DECLARE sec_idx     INT DEFAULT 0;
    DECLARE sec_count   INT DEFAULT 0;
    DECLARE chapter_id  INT UNSIGNED DEFAULT NULL;
    DECLARE disp_order  INT DEFAULT 0;

    DELETE FROM act_part_sections WHERE pdf_document_id = p_pdf_document_id;
    DELETE FROM act_part_chapters WHERE pdf_document_id = p_pdf_document_id;

    IF p_has_chapters = 1 AND p_chapters_json IS NOT NULL THEN
        SET ch_count = JSON_LENGTH(p_chapters_json);
        SET ch_idx = 0;
        WHILE ch_idx < ch_count DO
            INSERT INTO act_part_chapters (pdf_document_id, chapter_number, chapter_title, display_order, created_by)
            VALUES (
                p_pdf_document_id,
                JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                ch_idx,
                p_created_by
            );
            SET chapter_id = LAST_INSERT_ID();

            SET sec_count = JSON_LENGTH(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections')));
            SET sec_idx = 0;
            WHILE sec_idx < sec_count DO
                INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by)
                VALUES (
                    p_pdf_document_id,
                    chapter_id,
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_number'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_title'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].section_content'))),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_path'))),
                    CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_size'))), 'null') AS SIGNED),
                    JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].original_filename'))),
                    sec_idx,
                    p_created_by
                );
                SET sec_idx = sec_idx + 1;
            END WHILE;

            SET ch_idx = ch_idx + 1;
        END WHILE;
    ELSEIF p_has_chapters = 0 AND p_flat_json IS NOT NULL THEN
        SET sec_count = JSON_LENGTH(p_flat_json);
        SET sec_idx = 0;
        WHILE sec_idx < sec_count DO
            INSERT INTO act_part_sections (pdf_document_id, chapter_id, section_number, section_title, section_content, file_path, file_size, original_filename, display_order, created_by)
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
                p_created_by
            );
            SET sec_idx = sec_idx + 1;
        END WHILE;
    END IF;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────

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

    SET @sql_del = CONCAT('DELETE FROM ', tbl, ' WHERE pdf_document_id = ', p_pdf_document_id);
    PREPARE stmt_del FROM @sql_del;
    EXECUTE stmt_del;
    DEALLOCATE PREPARE stmt_del;

    IF p_entries_json IS NOT NULL THEN
        SET entry_count = JSON_LENGTH(p_entries_json);
        WHILE entry_idx < entry_count DO
            SET @sql_ins = CONCAT(
                'INSERT INTO ', tbl,
                ' (pdf_document_id, entry_number, title, description, file_path, file_size, original_filename, display_order, created_by) VALUES (',
                p_pdf_document_id, ', ',
                QUOTE(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].entry_number')))), ', ',
                QUOTE(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].title')))), ', ',
                QUOTE(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].description')))), ', ',
                QUOTE(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].file_path')))), ', ',
                IFNULL(CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].file_size'))), 'null') AS SIGNED), 'NULL'), ', ',
                QUOTE(JSON_UNQUOTE(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].original_filename')))), ', ',
                entry_idx, ', ',
                p_created_by, ')'
            );
            PREPARE stmt_ins FROM @sql_ins;
            EXECUTE stmt_ins;
            DEALLOCATE PREPARE stmt_ins;
            SET entry_idx = entry_idx + 1;
        END WHILE;
    END IF;

    SELECT 'ok' AS result;
END ;;
DELIMITER ;
