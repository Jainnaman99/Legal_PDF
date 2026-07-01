-- ============================================================
-- Adds mobile_number to users and creates password_reset_otps
-- table for OTP-based password reset (email + SMS).
--
-- Prerequisites: add_must_change_password.sql must have been run.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_mobile_and_reset_tokens.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Add mobile_number to users
-- ─────────────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'mobile_number'
)
BEGIN
    ALTER TABLE dbo.users ADD mobile_number NVARCHAR(20) NULL;
    PRINT 'Column mobile_number added to users.';
END
ELSE
    PRINT 'Column mobile_number already exists — skipping.';
GO

-- ─────────────────────────────────────────────────────────────
-- 2. password_reset_otps table
-- ─────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.password_reset_otps', 'U') IS NULL
CREATE TABLE dbo.password_reset_otps
(
    id         INT           IDENTITY(1,1) NOT NULL,
    user_id    INT           NOT NULL,
    otp_hash   NVARCHAR(64)  NOT NULL,          -- SHA-256 hex of the 6-digit OTP
    channel    NVARCHAR(10)  NOT NULL,           -- 'email' | 'sms'
    expires_at DATETIME2     NOT NULL,
    used       BIT           NOT NULL CONSTRAINT DF_otp_used DEFAULT 0,
    created_at DATETIME2     NOT NULL CONSTRAINT DF_otp_created_at DEFAULT GETUTCDATE(),
    CONSTRAINT PK_password_reset_otps PRIMARY KEY (id),
    CONSTRAINT FK_otp_user             FOREIGN KEY (user_id) REFERENCES dbo.users(id) ON DELETE CASCADE,
    CONSTRAINT CK_otp_channel          CHECK (channel IN ('email', 'sms'))
);
GO

-- ─────────────────────────────────────────────────────────────
-- 3. sp_get_user_by_id  — add mobile_number
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
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
-- 4. sp_get_user_by_username  — add mobile_number
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_username
    @username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
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
-- 5. sp_get_user_by_email  — add mobile_number
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_email
    @email NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
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
-- 6. sp_get_user_by_mobile  — NEW
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_mobile
    @mobile_number NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
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
    WHERE u.mobile_number = @mobile_number;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 7. sp_create_user  — add mobile_number
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
        (username, email, hashed_password, first_name, last_name, role_id, department_id, mobile_number)
        -- must_change_password uses column DEFAULT (1) — new accounts must change on first login
    VALUES
        (@username, @email, @hashed_password, @first_name, @last_name, @role_id, @department_id, @mobile_number);

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
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
-- 8. sp_update_user  — add mobile_number, include must_change_password in SELECT
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
        u.mobile_number, u.must_change_password,
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
-- 9. sp_list_users  — add mobile_number
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
        u.mobile_number, u.must_change_password,
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
-- 10. sp_create_reset_otp  — NEW
--     Deletes previous unused OTPs for the user, then inserts.
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_reset_otp
    @user_id    INT,
    @otp_hash   NVARCHAR(64),
    @channel    NVARCHAR(10),
    @expires_at DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    -- Remove any existing unused OTPs for this user to prevent spamming
    DELETE FROM dbo.password_reset_otps
    WHERE  user_id = @user_id AND used = 0;

    INSERT INTO dbo.password_reset_otps (user_id, otp_hash, channel, expires_at)
    VALUES (@user_id, @otp_hash, @channel, @expires_at);
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 11. sp_get_valid_reset_otp  — NEW
--     Returns the latest valid (unused, not expired) OTP for a user.
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_valid_reset_otp
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1
        id, user_id, otp_hash, channel, expires_at, used
    FROM  dbo.password_reset_otps
    WHERE user_id   = @user_id
      AND used      = 0
      AND expires_at > GETUTCDATE()
    ORDER BY created_at DESC;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 12. sp_mark_otp_used  — NEW
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_mark_otp_used
    @otp_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.password_reset_otps
    SET    used = 1
    WHERE  id   = @otp_id;
END;
GO

PRINT 'Migration add_mobile_and_reset_tokens completed successfully.';
GO
