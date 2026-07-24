-- Fix: soft-delete duplicate act_part_chapters rows created by the pre-fix bug
-- where chapters with no sections were not returned in GET /sections, causing
-- subsequent saves to re-insert the same chapter_number.
--
-- Strategy: keep the row with the LOWEST id (original insert) per
-- (pdf_document_id, chapter_number) and soft-delete all later duplicates.
--
-- Run: mysql -u root -p Legal_PDF < scripts/fix_duplicate_chapters.sql

UPDATE act_part_chapters a
JOIN (
    SELECT pdf_document_id, chapter_number, MIN(id) AS keep_id
    FROM act_part_chapters
    WHERE is_deleted = 0
    GROUP BY pdf_document_id, chapter_number
    HAVING COUNT(*) > 1
) d
    ON  a.pdf_document_id = d.pdf_document_id
    AND a.chapter_number   = d.chapter_number
    AND a.id              != d.keep_id
SET a.is_deleted = 1;

-- Also soft-delete any sections that belonged to the duplicate chapters
UPDATE act_part_sections s
JOIN act_part_chapters c ON s.chapter_id = c.id
SET s.is_deleted = 1
WHERE c.is_deleted = 1;

SELECT
    pdf_document_id,
    chapter_number,
    COUNT(*) AS total,
    SUM(is_deleted = 0) AS active,
    SUM(is_deleted = 1) AS deleted
FROM act_part_chapters
GROUP BY pdf_document_id, chapter_number
HAVING total > 1
ORDER BY pdf_document_id, chapter_number;
