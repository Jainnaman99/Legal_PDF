USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_get_audit_log_actions;

DELIMITER $$

CREATE PROCEDURE sp_get_audit_log_actions(
    IN p_dept_id         INT,   -- NULL = all departments (admin); non-NULL = one department (nodal)
    IN p_exclude_user_id INT    -- exclude the calling user's own actions (mirrors sp_list_audit_logs)
)
BEGIN
    -- Mirror the same exclusions as sp_list_audit_logs so every action in the
    -- dropdown is guaranteed to return at least one row when filtered:
    --   user_id IS NOT NULL   → skip anonymous / deleted-user entries
    --   entity_type <> 'auth' → skip login / OTP / session noise
    --   user_id <> p_exclude_user_id → skip the viewer's own actions
    IF p_dept_id IS NULL THEN
        SELECT DISTINCT action
        FROM audit_logs
        WHERE user_id IS NOT NULL
          -- AND entity_type <> 'auth'
          AND (p_exclude_user_id IS NULL OR user_id <> p_exclude_user_id)
        ORDER BY action ASC;
    ELSE
        SELECT DISTINCT al.action
        FROM audit_logs al
        INNER JOIN users u ON al.user_id = u.id
        WHERE u.department_id = p_dept_id
          -- AND al.entity_type <> 'auth'
          AND (p_exclude_user_id IS NULL OR al.user_id <> p_exclude_user_id)
        ORDER BY al.action ASC;
    END IF;
END$$

DELIMITER ;

SELECT 'sp_get_audit_log_actions created successfully.' AS Message;
