-- Patches sp_department_report so the cumulative "total_*" columns are read
-- directly off pdf_documents.status (the document's current status) instead
-- of being derived from pdf_document_approvals.acted_at history.
--
-- Why: the original query joined pdf_documents AND pdf_document_approvals
-- flat alongside users in one FROM clause. A document that went through
-- multiple approval actions (e.g. rejected then later approved) produces
-- multiple joined rows per document, and the total_* columns were computed
-- from that same fan-out. Reading total_* as plain correlated subqueries
-- against pdf_documents avoids that fan-out entirely and just reflects
-- "how many documents in this department currently have this status".
--
-- Unchanged: the per-role user headcounts, and the *_on_date columns
-- (uploaded_on_date / pending_on_date / approved_on_date / rejected_on_date),
-- which still need the approvals table for approved/rejected-on-a-given-date.
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/patch_sp_department_report_status_counts.sql

USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_department_report;

DELIMITER $$

CREATE PROCEDURE sp_department_report(IN p_date DATE)
BEGIN
    SELECT
        ROW_NUMBER() OVER (ORDER BY d.name)  AS sr_no,
        d.name                                AS department,

        -- ── Active users by role ────────────────────────────
        SUM(CASE WHEN r.name = 'uploader'                AND u.is_active = 1 THEN 1 ELSE 0 END) AS uploaders,
        SUM(CASE WHEN r.name = 'approver'                AND u.is_active = 1 THEN 1 ELSE 0 END) AS approvers,
        SUM(CASE WHEN r.name = 'nodal Officer'           AND u.is_active = 1 THEN 1 ELSE 0 END) AS nodal_officers,
        SUM(CASE WHEN r.name IN ('admin','super Admin')  AND u.is_active = 1 THEN 1 ELSE 0 END) AS admins,
        SUM(CASE WHEN u.is_active = 1                    THEN 1 ELSE 0 END)                     AS total_active_users,

        -- ── On the given date ───────────────────────────────

        -- Total uploaded on that date
        COUNT(DISTINCT CASE WHEN DATE(p.created_at) = p_date
                            THEN p.id END)                                                       AS uploaded_on_date,

        -- Uploaded on that date — still pending
        COUNT(DISTINCT CASE WHEN DATE(p.created_at) = p_date AND p.status = 'pending'
                            THEN p.id END)                                                       AS pending_on_date,

        -- Approved on that date (approval action recorded on that date)
        COUNT(DISTINCT CASE WHEN DATE(a.acted_at) = p_date AND a.action = 'approved'
                            THEN p.id END)                                                       AS approved_on_date,

        -- Rejected on that date (rejection action recorded on that date)
        COUNT(DISTINCT CASE WHEN DATE(a.acted_at) = p_date AND a.action = 'rejected'
                            THEN p.id END)                                                       AS rejected_on_date,

        -- ── Cumulative, read directly off pdf_documents.status ──────────
        (SELECT COUNT(*) FROM pdf_documents pd2
         WHERE pd2.department_id = d.id AND pd2.status != 'draft')                                AS total_uploaded,
        (SELECT COUNT(*) FROM pdf_documents pd2
         WHERE pd2.department_id = d.id AND pd2.status = 'pending')                                AS total_pending,
        (SELECT COUNT(*) FROM pdf_documents pd2
         WHERE pd2.department_id = d.id AND pd2.status = 'approved')                               AS total_approved,
        (SELECT COUNT(*) FROM pdf_documents pd2
         WHERE pd2.department_id = d.id AND pd2.status = 'rejected')                                AS total_rejected

    FROM departments d

    LEFT JOIN users u
        ON FIND_IN_SET(d.id, u.department_id) > 0
    LEFT JOIN roles r
        ON r.id = u.role_id

    LEFT JOIN pdf_documents p
        ON p.department_id = d.id
    LEFT JOIN pdf_document_approvals a
        ON a.pdf_id = p.id

    WHERE d.is_active = 1

    GROUP BY d.id, d.name
    ORDER BY d.name;
END $$

DELIMITER ;

SELECT 'sp_department_report patched — total_* columns now read from pdf_documents.status.' AS status;
