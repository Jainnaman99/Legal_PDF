-- ============================================================
-- Act Parts Tables: Manual entry of sections, schedules,
-- annexures, appendices, and forms linked to an Act document.
--
-- These tables are independent of the AI-extraction tables
-- (act_structures, act_chapters, act_sections, act_schedules)
-- which remain untouched.
--
-- Run via mysql:
--   mysql -u <user> -p Legal_PDF < scripts/add_act_parts_tables.sql
-- ============================================================

USE Legal_PDF;

-- ─────────────────────────────────────────────
-- 1. act_part_chapters
--    Optional grouping layer under an Act. When an Act is
--    structured with chapters each section belongs to a chapter.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_chapters` (
    `id`              INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id` INT UNSIGNED     NOT NULL COMMENT 'FK → pdf_documents.id',
    `chapter_number`  VARCHAR(50)      NULL     COMMENT 'e.g. I, II, 1, 2',
    `chapter_title`   VARCHAR(500)     NULL,
    `display_order`   INT              NOT NULL DEFAULT 0,
    `created_by`      INT UNSIGNED     NOT NULL,
    `created_at`      DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_chapters_doc`  (`pdf_document_id`),
    KEY `idx_act_part_chapters_order`(`pdf_document_id`, `display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- 2. act_part_sections
--    Sections optionally nested under a chapter.
--    chapter_id is NULL for Acts that have no chapters.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_sections` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NOT NULL COMMENT 'FK → pdf_documents.id',
    `chapter_id`        INT UNSIGNED     NULL     COMMENT 'FK → act_part_chapters.id, NULL = no chapter',
    `section_number`    VARCHAR(50)      NULL     COMMENT 'e.g. 1, 3A, 123',
    `section_title`     VARCHAR(1000)    NULL,
    `section_content`   LONGTEXT         NULL,
    `file_path`         VARCHAR(500)     NULL,
    `file_size`         BIGINT           NULL,
    `original_filename` VARCHAR(255)     NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_by`        INT UNSIGNED     NOT NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_sections_doc`     (`pdf_document_id`),
    KEY `idx_act_part_sections_chapter` (`chapter_id`),
    KEY `idx_act_part_sections_order`   (`pdf_document_id`, `display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- 3. act_part_schedules
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_schedules` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NOT NULL COMMENT 'FK → pdf_documents.id',
    `entry_number`      VARCHAR(50)      NULL     COMMENT 'e.g. 1, I, A',
    `title`             VARCHAR(500)     NULL,
    `description`       LONGTEXT         NULL,
    `file_path`         VARCHAR(500)     NULL,
    `file_size`         BIGINT           NULL,
    `original_filename` VARCHAR(255)     NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_by`        INT UNSIGNED     NOT NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_schedules_doc`  (`pdf_document_id`),
    KEY `idx_act_part_schedules_order`(`pdf_document_id`, `display_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- 4. act_part_annexures
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_annexures` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NOT NULL,
    `entry_number`      VARCHAR(50)      NULL,
    `title`             VARCHAR(500)     NULL,
    `description`       LONGTEXT         NULL,
    `file_path`         VARCHAR(500)     NULL,
    `file_size`         BIGINT           NULL,
    `original_filename` VARCHAR(255)     NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_by`        INT UNSIGNED     NOT NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_annexures_doc`(`pdf_document_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- 5. act_part_appendices
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_appendices` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NOT NULL,
    `entry_number`      VARCHAR(50)      NULL,
    `title`             VARCHAR(500)     NULL,
    `description`       LONGTEXT         NULL,
    `file_path`         VARCHAR(500)     NULL,
    `file_size`         BIGINT           NULL,
    `original_filename` VARCHAR(255)     NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_by`        INT UNSIGNED     NOT NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_appendices_doc`(`pdf_document_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- 6. act_part_forms
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `act_part_forms` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NOT NULL,
    `entry_number`      VARCHAR(50)      NULL,
    `title`             VARCHAR(500)     NULL,
    `description`       LONGTEXT         NULL,
    `file_path`         VARCHAR(500)     NULL,
    `file_size`         BIGINT           NULL,
    `original_filename` VARCHAR(255)     NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_by`        INT UNSIGNED     NOT NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_part_forms_doc`(`pdf_document_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────
-- Stored Procedures
-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS `sp_save_act_part_sections`;
DELIMITER ;;
CREATE PROCEDURE `sp_save_act_part_sections`(
    IN p_pdf_document_id INT UNSIGNED,
    IN p_created_by      INT UNSIGNED,
    IN p_has_chapters    TINYINT,
    IN p_chapters_json   JSON,      -- [{chapter_number, chapter_title, sections:[{section_number,section_title,section_content,file_path,file_size,original_filename}]}]
    IN p_flat_json       JSON       -- [{section_number,section_title,section_content,file_path,file_size,original_filename}]  (used when p_has_chapters=0)
)
BEGIN
    DECLARE ch_idx      INT DEFAULT 0;
    DECLARE ch_count    INT DEFAULT 0;
    DECLARE sec_idx     INT DEFAULT 0;
    DECLARE sec_count   INT DEFAULT 0;
    DECLARE chapter_id  INT UNSIGNED DEFAULT NULL;
    DECLARE disp_order  INT DEFAULT 0;

    -- Remove existing data for this act (full replace semantics)
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
                    JSON_EXTRACT(p_chapters_json, CONCAT('$[', ch_idx, '].sections[', sec_idx, '].file_size')),
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
                JSON_EXTRACT(p_flat_json, CONCAT('$[', sec_idx, '].file_size')),
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

DROP PROCEDURE IF EXISTS `sp_get_act_part_sections`;
DELIMITER ;;
CREATE PROCEDURE `sp_get_act_part_sections`(IN p_pdf_document_id INT UNSIGNED)
BEGIN
    SELECT
        c.id             AS chapter_id,
        c.chapter_number,
        c.chapter_title,
        c.display_order  AS chapter_order,
        s.id             AS section_id,
        s.section_number,
        s.section_title,
        s.section_content,
        s.file_path,
        s.file_size,
        s.original_filename,
        s.display_order  AS section_order
    FROM act_part_chapters c
    LEFT JOIN act_part_sections s ON s.chapter_id = c.id
    WHERE c.pdf_document_id = p_pdf_document_id
    ORDER BY c.display_order, s.display_order;

    -- Also return flat (no-chapter) sections
    SELECT
        s.id             AS section_id,
        s.section_number,
        s.section_title,
        s.section_content,
        s.file_path,
        s.file_size,
        s.original_filename,
        s.display_order
    FROM act_part_sections s
    WHERE s.pdf_document_id = p_pdf_document_id
      AND s.chapter_id IS NULL
    ORDER BY s.display_order;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS `sp_save_act_part_entries`;
DELIMITER ;;
CREATE PROCEDURE `sp_save_act_part_entries`(
    IN p_part_type       VARCHAR(20),  -- 'schedule'|'annexure'|'appendix'|'form'
    IN p_pdf_document_id INT UNSIGNED,
    IN p_created_by      INT UNSIGNED,
    IN p_entries_json    JSON          -- [{entry_number, title, description, file_path, file_size, original_filename}]
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

    -- Full-replace: delete existing entries for this act+type
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
                IFNULL(JSON_EXTRACT(p_entries_json, CONCAT('$[', entry_idx, '].file_size')), 'NULL'), ', ',
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

-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS `sp_get_act_part_entries`;
DELIMITER ;;
CREATE PROCEDURE `sp_get_act_part_entries`(
    IN p_part_type       VARCHAR(20),
    IN p_pdf_document_id INT UNSIGNED
)
BEGIN
    DECLARE tbl VARCHAR(50);
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

    SET @sql_sel = CONCAT(
        'SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order, created_at ',
        'FROM ', tbl, ' WHERE pdf_document_id = ', p_pdf_document_id, ' ORDER BY display_order'
    );
    PREPARE stmt_sel FROM @sql_sel;
    EXECUTE stmt_sel;
    DEALLOCATE PREPARE stmt_sel;
END ;;
DELIMITER ;

-- ─────────────────────────────────────────────

DROP PROCEDURE IF EXISTS `sp_get_all_act_parts`;
DELIMITER ;;
CREATE PROCEDURE `sp_get_all_act_parts`(IN p_pdf_document_id INT UNSIGNED)
BEGIN
    -- Result 1: chapters (may be empty)
    SELECT id, chapter_number, chapter_title, display_order
    FROM act_part_chapters
    WHERE pdf_document_id = p_pdf_document_id
    ORDER BY display_order;

    -- Result 2: sections (chapter_id NULL = flat)
    SELECT id, chapter_id, section_number, section_title, section_content,
           file_path, file_size, original_filename, display_order
    FROM act_part_sections
    WHERE pdf_document_id = p_pdf_document_id
    ORDER BY display_order;

    -- Result 3: schedules
    SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order
    FROM act_part_schedules WHERE pdf_document_id = p_pdf_document_id ORDER BY display_order;

    -- Result 4: annexures
    SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order
    FROM act_part_annexures WHERE pdf_document_id = p_pdf_document_id ORDER BY display_order;

    -- Result 5: appendices
    SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order
    FROM act_part_appendices WHERE pdf_document_id = p_pdf_document_id ORDER BY display_order;

    -- Result 6: forms
    SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order
    FROM act_part_forms WHERE pdf_document_id = p_pdf_document_id ORDER BY display_order;
END ;;
DELIMITER ;
