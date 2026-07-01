-- ============================================================
-- Adds password_changed_at to users for 6-month password expiry.
-- When this column is older than 180 days the backend sets
-- must_change_password = true in the JWT on next login.
--
-- Prerequisites: add_mobile_and_reset_tokens.sql must have been run.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_password_expiry.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Add password_changed_at column
--    Existing users get the current timestamp so they won't be
--    forced to change immediately — they get a fresh 6-month window.
-- ─────────────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'password_changed_at'
)
BEGIN
    ALTER TABLE dbo.users ADD password_changed_at DATETIME2 NULL;
    UPDATE dbo.users SET password_changed_at = GETUTCDATE();
    PRINT 'Column password_changed_at added. Existing users given a fresh 6-month window.';
END
ELSE
    PRINT 'Column password_changed_at already exists — skipping.';
GO

-- ─────────────────────────────────────────────────────────────
-- 2. sp_change_password — also stamp password_changed_at
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_change_password
    @user_id         INT,
    @hashed_password NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.users
    SET    hashed_password      = @hashed_password,
           must_change_password = 0,
           password_changed_at  = GETUTCDATE(),
           updated_at           = GETUTCDATE()
    WHERE  id = @user_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 3. sp_create_user — stamp password_changed_at on creation
--    (new users must change on first login anyway, but the
--     timestamp starts the clock for subsequent 6-month checks)
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username        NVARCHAR(100),
    @email           NVARCHAR(255),
    @hashed_password NVARCHAR(255),
    @first_name      NVARCHAR(100) = NULL,
    @last_name       NVARCHAR(100) = NULL,
    @role_id         INT           = NULL,
    @department_id   INT           = NULL,
    @mobile_number   NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users
        (username, email, hashed_password, first_name, last_name,
         role_id, department_id, mobile_number, password_changed_at)
    VALUES
        (@username, @email, @hashed_password, @first_name, @last_name,
         @role_id, @department_id, @mobile_number, GETUTCDATE());

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        NULL AS last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.id = @new_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 4-7. Update GET procedures to return password_changed_at
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_username
    @username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.username = @username;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_email
    @email NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.email = @email;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_mobile
    @mobile_number NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.mobile_number = @mobile_number;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 8. sp_list_users — add password_changed_at
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_users
    @skip            INT = 0,
    @limit           INT = 100,
    @exclude_user_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.roles r2
        WHERE  r2.id = u.role_id AND r2.name = 'super_admin'
    )
    AND (@exclude_user_id IS NULL OR u.id <> @exclude_user_id)
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 9. sp_update_user — add password_changed_at to SELECT
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_update_user
    @user_id       INT,
    @first_name    NVARCHAR(100) = NULL,
    @last_name     NVARCHAR(100) = NULL,
    @email         NVARCHAR(255) = NULL,
    @is_active     BIT           = NULL,
    @role_id       INT           = NULL,
    @department_id INT           = NULL,
    @mobile_number NVARCHAR(20)  = NULL
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
        mobile_number = COALESCE(@mobile_number, mobile_number),
        updated_at    = GETDATE()
    WHERE id = @user_id;

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

PRINT 'Migration add_password_expiry completed successfully.';
GO
