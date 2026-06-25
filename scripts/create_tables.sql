-- ============================================================
-- Database setup script for Legal PDF API  (SQL Server T-SQL)
-- Run via sqlcmd:
--   sqlcmd -S localhost -U sa -P YourPass -i scripts\create_tables.sql
-- Or open in SSMS and execute.
--
-- Roles: super_admin | admin | approver | officer | auditor | uploader | citizen
-- ============================================================

--USE master;
--GO

--IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'legal_pdf_db')
--    CREATE DATABASE legal_pdf_db
--        COLLATE SQL_Latin1_General_CP1_CI_AS;
--GO

--USE legal_pdf_db;
--GO

-- ─────────────────────────────────────────────
-- TABLES
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.pdf_documents', 'U') IS NULL
CREATE TABLE dbo.pdf_documents
(
    id                INT           IDENTITY(1,1) NOT NULL,
    filename          NVARCHAR(255) NOT NULL,
    original_filename NVARCHAR(255) NOT NULL,
    file_path         NVARCHAR(500) NOT NULL,
    file_size         BIGINT        NOT NULL,
    description       NVARCHAR(MAX) NULL,
    uploaded_by       INT           NOT NULL,
    created_at        DATETIME2     NOT NULL CONSTRAINT DF_pdf_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_pdf_documents PRIMARY KEY (id)
);
GO

IF OBJECT_ID('dbo.roles', 'U') IS NULL
CREATE TABLE dbo.roles
(
    id          INT           IDENTITY(1,1) NOT NULL,
    name        NVARCHAR(50)  NOT NULL,
    description NVARCHAR(MAX) NULL,
    created_at  DATETIME2     NOT NULL CONSTRAINT DF_roles_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_roles     PRIMARY KEY (id),
    CONSTRAINT UQ_roles_name UNIQUE (name)
);
GO

IF OBJECT_ID('dbo.users', 'U') IS NULL
CREATE TABLE dbo.users
(
    id              INT           IDENTITY(1,1) NOT NULL,
    username        NVARCHAR(100) NOT NULL,
    email           NVARCHAR(255) NOT NULL,
    hashed_password NVARCHAR(255) NOT NULL,
    is_active       BIT           NOT NULL CONSTRAINT DF_users_is_active DEFAULT 1,
    role_id         INT           NULL,
    created_at      DATETIME2     NOT NULL CONSTRAINT DF_users_created_at DEFAULT GETDATE(),
    updated_at      DATETIME2     NOT NULL CONSTRAINT DF_users_updated_at DEFAULT GETDATE(),
    CONSTRAINT PK_users          PRIMARY KEY (id),
    CONSTRAINT UQ_users_username UNIQUE (username),
    CONSTRAINT UQ_users_email    UNIQUE (email),
    CONSTRAINT FK_users_role     FOREIGN KEY (role_id) REFERENCES dbo.roles(id) ON DELETE SET NULL
);
GO

-- Add FK from pdf_documents → users (created after users table)
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_pdf_user'
)
ALTER TABLE dbo.pdf_documents
    ADD CONSTRAINT FK_pdf_user
    FOREIGN KEY (uploaded_by) REFERENCES dbo.users(id) ON DELETE CASCADE;
GO

-- Trigger: keep updated_at current on every UPDATE
IF OBJECT_ID('dbo.trg_users_updated_at', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_users_updated_at;
GO

CREATE TRIGGER dbo.trg_users_updated_at
ON dbo.users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.users
    SET    updated_at = GETDATE()
    FROM   dbo.users u
    INNER JOIN inserted i ON u.id = i.id;
END;
GO

-- ─────────────────────────────────────────────
-- STORED PROCEDURES
-- ─────────────────────────────────────────────

-- ── User procedures ──────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.role_id, u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON u.role_id = r.id
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
        u.role_id, u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON u.role_id = r.id
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
        u.role_id, u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON u.role_id = r.id
    WHERE u.email = @email;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username        NVARCHAR(100),
    @email           NVARCHAR(255),
    @hashed_password NVARCHAR(255),
    @role_id         INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users (username, email, hashed_password, role_id)
    VALUES (@username, @email, @hashed_password, @role_id);

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.role_id, u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON u.role_id = r.id
    WHERE u.id = @new_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_users
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.role_id, u.created_at, u.updated_at,
        r.name        AS role_name,
        r.description AS role_description
    FROM dbo.users u
    LEFT JOIN dbo.roles r ON u.role_id = r.id
    ORDER BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

-- ── PDF procedures ───────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_pdf_document
    @filename          NVARCHAR(255),
    @original_filename NVARCHAR(255),
    @file_path         NVARCHAR(500),
    @file_size         BIGINT,
    @uploaded_by       INT,
    @description       NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.pdf_documents
        (filename, original_filename, file_path, file_size, uploaded_by, description)
    VALUES
        (@filename, @original_filename, @file_path, @file_size, @uploaded_by, @description);

    SET @new_id = SCOPE_IDENTITY();

    SELECT id, filename, original_filename, file_path, file_size,
           uploaded_by, description, created_at
    FROM dbo.pdf_documents
    WHERE id = @new_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_pdf_by_id
    @document_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, filename, original_filename, file_path, file_size,
           uploaded_by, description, created_at
    FROM dbo.pdf_documents
    WHERE id = @document_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_pdfs_by_user
    @user_id INT,
    @skip    INT = 0,
    @limit   INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, filename, original_filename, file_path, file_size,
           uploaded_by, description, created_at
    FROM dbo.pdf_documents
    WHERE uploaded_by = @user_id
    ORDER BY created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_all_pdfs
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, filename, original_filename, file_path, file_size,
           uploaded_by, description, created_at
    FROM dbo.pdf_documents
    ORDER BY created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO
