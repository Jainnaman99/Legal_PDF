-- ============================================================
-- Act Structure Tables: Store parsed structure of Legal Acts
-- Run this script ONCE in your MySQL database
-- ============================================================

CREATE TABLE IF NOT EXISTS `act_structures` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `pdf_document_id`   INT UNSIGNED     NULL     COMMENT 'Optional link to pdf_documents table',
    `act_title`         VARCHAR(500)     NOT NULL,
    `act_number`        VARCHAR(100)     NULL     COMMENT 'e.g. No. 18 of 2013',
    `act_year`          INT              NULL,
    `total_chapters`    INT              NOT NULL DEFAULT 0,
    `total_sections`    INT              NOT NULL DEFAULT 0,
    `total_schedules`   INT              NOT NULL DEFAULT 0,
    `extraction_status` ENUM('pending','processing','completed','failed') NOT NULL DEFAULT 'pending',
    `error_message`     TEXT             NULL,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `updated_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_structures_pdf_doc` (`pdf_document_id`),
    KEY `idx_act_structures_status`  (`extraction_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `act_chapters` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `act_structure_id`  INT UNSIGNED     NOT NULL,
    `chapter_number`    VARCHAR(50)      NULL     COMMENT 'e.g. I, II, XXIX',
    `chapter_title`     VARCHAR(500)     NULL     COMMENT 'e.g. PRELIMINARY',
    `chapter_description` TEXT           NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_chapters_structure` (`act_structure_id`),
    CONSTRAINT `fk_act_chapters_structure_id`
        FOREIGN KEY (`act_structure_id`) REFERENCES `act_structures`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `act_sections` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `act_structure_id`  INT UNSIGNED     NOT NULL,
    `act_chapter_id`    INT UNSIGNED     NULL,
    `section_number`    VARCHAR(50)      NULL     COMMENT 'e.g. 1, 3A, 123',
    `section_title`     VARCHAR(1000)    NULL,
    `section_content`   LONGTEXT         NULL     COMMENT 'Full section text (optional)',
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_sections_structure` (`act_structure_id`),
    KEY `idx_act_sections_chapter`   (`act_chapter_id`),
    CONSTRAINT `fk_act_sections_structure_id`
        FOREIGN KEY (`act_structure_id`) REFERENCES `act_structures`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_act_sections_chapter_id`
        FOREIGN KEY (`act_chapter_id`)   REFERENCES `act_chapters`(`id`)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `act_schedules` (
    `id`                INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `act_structure_id`  INT UNSIGNED     NOT NULL,
    `schedule_number`   VARCHAR(50)      NULL     COMMENT 'e.g. I, II, VII',
    `schedule_title`    VARCHAR(500)     NULL,
    `schedule_content`  LONGTEXT         NULL,
    `display_order`     INT              NOT NULL DEFAULT 0,
    `created_at`        DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`id`),
    KEY `idx_act_schedules_structure` (`act_structure_id`),
    CONSTRAINT `fk_act_schedules_structure_id`
        FOREIGN KEY (`act_structure_id`) REFERENCES `act_structures`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
