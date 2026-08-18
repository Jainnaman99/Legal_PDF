-- ============================================================
-- Department Summary Report Stored Procedure
-- Returns per-department user counts by role and document stats
-- (pending / approved / rejected) for a given date.
--
-- Run via:
--   mysql -u root -p legal_pdf < scripts/sp_department_report.sql
--
-- Then call:
--   CALL sp_department_report('2026-08-18');
--   CALL sp_department_report(CURDATE());
-- ============================================================

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

        -- ── Cumulative up to and including the given date ───

        -- Total uploaded up to that date
        COUNT(DISTINCT CASE WHEN DATE(p.created_at) <= p_date
                            THEN p.id END)                                                       AS total_uploaded,

        -- Currently pending (uploaded on or before date, still awaiting approval)
        COUNT(DISTINCT CASE WHEN DATE(p.created_at) <= p_date AND p.status = 'pending'
                            THEN p.id END)                                                       AS total_pending,

        -- Approved up to that date
        COUNT(DISTINCT CASE WHEN DATE(a.acted_at) <= p_date AND a.action = 'approved'
                            THEN p.id END)                                                       AS total_approved,

        -- Rejected up to that date
        COUNT(DISTINCT CASE WHEN DATE(a.acted_at) <= p_date AND a.action = 'rejected'
                            THEN p.id END)                                                       AS total_rejected

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

SELECT 'sp_department_report created successfully.' AS status;
