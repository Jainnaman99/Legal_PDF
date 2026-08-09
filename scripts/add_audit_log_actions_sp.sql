USE legal_pdf;

DROP PROCEDURE IF EXISTS sp_get_audit_log_actions;

DELIMITER $$

CREATE PROCEDURE sp_get_audit_log_actions()
BEGIN
    SELECT DISTINCT action
    FROM audit_logs
    ORDER BY action ASC;
END$$

DELIMITER ;

SELECT 'sp_get_audit_log_actions created successfully.' AS Message;