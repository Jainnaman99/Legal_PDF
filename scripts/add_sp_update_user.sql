-- ============================================================
-- Adds sp_update_user stored procedure.
-- Only the fields that are explicitly passed (non-NULL) are
-- updated; omitted fields keep their current values.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_sp_update_user.sql
-- ============================================================

USE Legal_PDF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_update_user
    @user_id       INT,
    @first_name    NVARCHAR(100) = NULL,
    @last_name     NVARCHAR(100) = NULL,
    @email         NVARCHAR(255) = NULL,
    @is_active     BIT           = NULL,
    @role_id       INT           = NULL,
    @department_id INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.users
    SET
        first_name    = COALESCE(@first_name,    first_name),
        last_name     = COALESCE(@last_name,     last_name),
        email         = COALESCE(@email,         email),
        is_active     = COALESCE(@is_active,     is_active),
        role_id       = COALESCE(@role_id,       role_id),
        department_id = COALESCE(@department_id, department_id),
        updated_at    = GETDATE()
    WHERE id = @user_id;

    -- Return the updated user row (same shape as sp_get_user_by_id)
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs
        WHERE  action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO
