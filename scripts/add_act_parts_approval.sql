-- Act Parts Approval Workflow
-- Approval is tracked per (pdf_document_id, part_type) pair.
-- part_type values match frontend tab keys: 'sections','schedule','annexure','appendix','forms'
--
-- Run: mysql -u root -p Legal_PDF < scripts/add_act_parts_approval.sql

-- ── 1. Table ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS act_part_approvals (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    pdf_document_id   INT         NOT NULL,
    part_type         VARCHAR(20) NOT NULL,   -- 'sections'|'schedule'|'annexure'|'appendix'|'forms'
    status            VARCHAR(20) NOT NULL DEFAULT 'pending',
    submitted_by      INT         NOT NULL,
    submitted_at      DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_by       INT         NULL,
    reviewed_at       DATETIME    NULL,
    comments          TEXT        NULL,
    UNIQUE KEY uq_apa (pdf_document_id, part_type),
    CONSTRAINT fk_apa_doc      FOREIGN KEY (pdf_document_id) REFERENCES pdf_documents(id) ON DELETE CASCADE,
    CONSTRAINT fk_apa_sub      FOREIGN KEY (submitted_by)    REFERENCES users(id),
    CONSTRAINT fk_apa_rev      FOREIGN KEY (reviewed_by)     REFERENCES users(id),
    CONSTRAINT chk_apa_status  CHECK (status IN ('pending','approved','rejected')),
    CONSTRAINT chk_apa_type    CHECK (part_type IN ('sections','schedule','annexure','appendix','forms'))
);

-- ── 2. Submit (or re-submit after rejection) ──────────────────────────────────

DROP PROCEDURE IF EXISTS sp_submit_act_parts;
DELIMITER ;;
CREATE PROCEDURE sp_submit_act_parts(
    IN p_pdf_document_id INT,
    IN p_part_type       VARCHAR(20),
    IN p_submitted_by    INT
)
BEGIN
    INSERT INTO act_part_approvals
        (pdf_document_id, part_type, status, submitted_by, submitted_at)
    VALUES
        (p_pdf_document_id, p_part_type, 'pending', p_submitted_by, NOW())
    ON DUPLICATE KEY UPDATE
        status       = 'pending',
        submitted_by = p_submitted_by,
        submitted_at = NOW(),
        reviewed_by  = NULL,
        reviewed_at  = NULL,
        comments     = NULL;

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
        u.last_name  AS submitter_last_name
    FROM act_part_approvals a
    JOIN users u ON u.id = a.submitted_by
    WHERE a.pdf_document_id = p_pdf_document_id AND a.part_type = p_part_type;
END ;;
DELIMITER ;

-- ── 3. Review (approve / reject) ──────────────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_review_act_parts;
DELIMITER ;;
CREATE PROCEDURE sp_review_act_parts(
    IN p_pdf_document_id INT,
    IN p_part_type       VARCHAR(20),
    IN p_reviewed_by     INT,
    IN p_action          VARCHAR(20),   -- 'approved' | 'rejected'
    IN p_comments        TEXT
)
BEGIN
    UPDATE act_part_approvals SET
        status      = p_action,
        reviewed_by = p_reviewed_by,
        reviewed_at = NOW(),
        comments    = p_comments
    WHERE pdf_document_id = p_pdf_document_id AND part_type = p_part_type;

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

-- ── 4. Get all approvals for one document ─────────────────────────────────────

DROP PROCEDURE IF EXISTS sp_get_act_part_approvals;
DELIMITER ;;
CREATE PROCEDURE sp_get_act_part_approvals(
    IN p_pdf_document_id INT
)
BEGIN
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
    WHERE a.pdf_document_id = p_pdf_document_id
    ORDER BY FIELD(a.part_type,'sections','schedule','annexure','appendix','forms');
END ;;
DELIMITER ;

-- ── 5. List pending submissions (for approver dashboard) ─────────────────────

DROP PROCEDURE IF EXISTS sp_list_pending_act_parts;
DELIMITER ;;
CREATE PROCEDURE sp_list_pending_act_parts()
BEGIN
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
        u.username          AS submitter_username,
        u.first_name        AS submitter_first_name,
        u.last_name         AS submitter_last_name,
        d.document_name     AS act_name,
        d.document_type     AS act_type
    FROM act_part_approvals a
    JOIN users u          ON u.id = a.submitted_by
    JOIN pdf_documents d  ON d.id = a.pdf_document_id
    WHERE a.status = 'pending'
    ORDER BY a.submitted_at ASC;
END ;;
DELIMITER ;

-- ── 6. List all submissions by uploader (my-submissions) ─────────────────────

DROP PROCEDURE IF EXISTS sp_list_my_act_part_submissions;
DELIMITER ;;
CREATE PROCEDURE sp_list_my_act_part_submissions(
    IN p_submitted_by INT
)
BEGIN
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
        r.username   AS reviewer_username,
        r.first_name AS reviewer_first_name,
        r.last_name  AS reviewer_last_name,
        d.document_name AS act_name,
        d.document_type AS act_type
    FROM act_part_approvals a
    LEFT JOIN users r      ON r.id = a.reviewed_by
    JOIN pdf_documents d   ON d.id = a.pdf_document_id
    WHERE a.submitted_by = p_submitted_by
    ORDER BY a.submitted_at DESC;
END ;;
DELIMITER ;
