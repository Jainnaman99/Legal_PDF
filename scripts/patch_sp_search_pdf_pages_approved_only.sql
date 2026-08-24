-- Restricts full-text search (sp_search_pdf_pages) to approved documents only.
--
-- Before this patch the procedure had no status filter, so searching from the
-- citizen portal could surface text from pending or rejected documents.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_search_pdf_pages_approved_only.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_search_pdf_pages $$

CREATE PROCEDURE sp_search_pdf_pages(IN p_term VARCHAR(500), IN p_skip INT, IN p_limit INT)
BEGIN
    SELECT
        pp.pdf_document_id AS pdf_id,
        p.original_filename,
        pp.page_number,
        MATCH(pp.page_text) AGAINST(p_term IN BOOLEAN MODE) AS relevance_score,
        pp.page_text
    FROM pdf_pages pp
    JOIN pdf_documents p ON p.id = pp.pdf_document_id
    WHERE MATCH(pp.page_text) AGAINST(p_term IN BOOLEAN MODE)
      AND p.status = 'approved'
    ORDER BY relevance_score DESC
    LIMIT p_limit OFFSET p_skip;
END $$

DELIMITER ;

SELECT 'sp_search_pdf_pages patched — results restricted to approved documents.' AS status;
