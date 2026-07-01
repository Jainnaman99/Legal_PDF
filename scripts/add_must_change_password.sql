-- ============================================================
-- Adds must_change_password flag to users table.
-- Forces new users to change their password on first login.
-- Existing users are NOT affected (set to 0).
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_must_change_password.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Add column (safe — skips if already present)
-- ─────────────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'must_change_password'
)
BEGIN
    ALTER TABLE dbo.users
        ADD must_change_password BIT NOT NULL CONSTRAINT DF_users_must_change_password DEFAULT 1;

    -- Existing users already have passwords they chose — don't force a change
    UPDATE dbo.users SET must_change_password = 0;

    PRINT 'Column must_change_password added. Existing users set to 0.';
END
ELSE
    PRINT 'Column must_change_password already exists — skipping ALTER TABLE.';
GO

-- ─────────────────────────────────────────────────────────────
-- 2. sp_get_user_by_id  — include must_change_password
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.must_change_password,
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

-- ─────────────────────────────────────────────────────────────
-- 3. sp_get_user_by_username  — include must_change_password
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_username
    @username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.must_change_password,
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
    WHERE u.username = @username;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 4. sp_get_user_by_email  — include must_change_password
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_email
    @email NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.must_change_password,
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
    WHERE u.email = @email;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 5. sp_create_user  — new users default to must_change_password = 1
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username        NVARCHAR(100),
    @email           NVARCHAR(255),
    @hashed_password NVARCHAR(255),
    @first_name      NVARCHAR(100) = NULL,
    @last_name       NVARCHAR(100) = NULL,
    @role_id         INT           = NULL,
    @department_id   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users
        (username, email, hashed_password, first_name, last_name, role_id, department_id)
        -- must_change_password uses column DEFAULT (1) — new accounts must change on first login
    VALUES
        (@username, @email, @hashed_password, @first_name, @last_name, @role_id, @department_id);

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.must_change_password,
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
-- 6. sp_list_users  — include must_change_password
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
        u.must_change_password,
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
-- 7. sp_change_password  — NEW
--    Updates hashed_password and clears must_change_password flag
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
           updated_at           = GETUTCDATE()
    WHERE  id = @user_id;
END;
GO

PRINT 'Migration add_must_change_password completed successfully.';
GO
