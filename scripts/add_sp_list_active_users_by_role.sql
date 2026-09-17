-- Lightweight lookup used to populate the Uploader/Approver filter dropdowns
-- on the Super Admin "All Uploads" screen: active users of a given role,
-- optionally restricted to one department.
--
--   p_role_name     — 'uploader' | 'approver'
--   p_department_id — NULL = every department; otherwise only users whose
--                     (comma-separated) department_id includes this id
--
-- Run via mysql client:
--   mysql -u <user> -p legal_pdf < scripts/add_sp_list_active_users_by_role.sql

USE legal_pdf;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_list_active_users_by_role $$

CREATE PROCEDURE sp_list_active_users_by_role(
    IN p_role_name     VARCHAR(50),
    IN p_department_id INT
)
BEGIN
    SELECT u.id, u.username, u.first_name, u.last_name
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.is_active = 1
      AND r.name = p_role_name
      AND (p_department_id IS NULL OR FIND_IN_SET(p_department_id, IFNULL(u.department_id, '')) > 0)
    ORDER BY u.first_name, u.last_name, u.username;
END $$

DELIMITER ;

SELECT 'sp_list_active_users_by_role created.' AS status;
