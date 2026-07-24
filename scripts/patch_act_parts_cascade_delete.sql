-- Patch: cascade chapter soft-delete to sections
-- When a chapter is soft-deleted, its sections must also be soft-deleted so they
-- are not left as orphaned rows (is_deleted=0 but chapter_id pointing to a deleted chapter).
--
-- Also fixes any existing orphaned sections in the DB.
--
-- Run: mysql -u root -p Legal_PDF < scripts/patch_act_parts_cascade_delete.sql

-- ── 1. Fix existing orphaned sections ─────────────────────────────────────────
-- Sections whose parent chapter is soft-deleted but they themselves are not

UPDATE act_part_sections s
JOIN act_part_chapters c ON c.id = s.chapter_id
SET s.is_deleted = 1
WHERE c.is_deleted = 1 AND s.is_deleted = 0;

-- ── 2. Rewrite sp_save_act_part_sections with cascading chapter soft-delete ───

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
                -- UPDATE: preserve status (not in SET clause)
                UPDATE act_part_chapters SET
                    chapter_number = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_number'))),
                    chapter_title  = JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].chapter_title'))),
                    display_order  = ch_idx,
                    is_deleted     = v_is_deleted
                WHERE id = v_ch_id AND pdf_document_id = p_pdf_document_id;
                SET v_chapter_id = v_ch_id;

                -- Cascade soft-delete to sections when chapter is deleted
                IF v_is_deleted = 1 THEN
                    UPDATE act_part_sections SET is_deleted = 1
                    WHERE chapter_id = v_ch_id AND pdf_document_id = p_pdf_document_id;
                END IF;
            ELSE
                -- INSERT: new chapter starts as draft
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

            -- Process sections for this chapter (skipped for deleted chapters since they're already cascaded)
            IF v_is_deleted = 0 THEN
                SET sec_count = JSON_LENGTH(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections')));
                SET sec_idx = 0;
                WHILE sec_idx < sec_count DO
                    SET v_sec_id     = CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].id'))),         'null') AS SIGNED);
                    SET v_is_deleted = CAST(IFNULL(JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].is_deleted')), 0) AS SIGNED);

                    IF v_sec_id IS NOT NULL THEN
                        -- UPDATE: preserve status
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
                        -- INSERT: new section starts as draft
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
