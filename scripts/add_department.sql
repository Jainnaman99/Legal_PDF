-- ============================================================
-- Department feature  (SQL Server T-SQL)
-- Run AFTER create_tables.sql has been executed.
--
-- This script:
--   1. Creates dbo.departments table
--   2. Adds department_id column to dbo.users
--   3. Adds new department stored procedures
--   4. Updates all user-returning stored procedures
--      to include department info in their result sets
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_department.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- TABLE: departments
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.departments', 'U') IS NULL
CREATE TABLE dbo.departments
(
    id          INT           IDENTITY(1,1) NOT NULL,
    name        NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NULL,
    created_at  DATETIME2     NOT NULL CONSTRAINT DF_dept_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_departments      PRIMARY KEY (id),
    CONSTRAINT UQ_departments_name UNIQUE (name)
);
GO

-- ─────────────────────────────────────────────
-- ALTER users: add department_id column
-- ─────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'department_id'
)
    ALTER TABLE dbo.users
        ADD department_id INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_users_department')
    ALTER TABLE dbo.users
        ADD CONSTRAINT FK_users_department
            FOREIGN KEY (department_id) REFERENCES dbo.departments(id) ON DELETE SET NULL;
GO

-- ─────────────────────────────────────────────
-- DEPARTMENT STORED PROCEDURES
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_department_by_id
    @department_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.departments
    WHERE  id = @department_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_departments
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.departments
    ORDER  BY name
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_department
    @name        NVARCHAR(100),
    @description NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.departments (name, description)
    VALUES (@name, @description);

    SET @new_id = SCOPE_IDENTITY();

    SELECT id, name, description, created_at
    FROM   dbo.departments
    WHERE  id = @new_id;
END;
GO

-- ─────────────────────────────────────────────
-- UPDATED USER STORED PROCEDURES
-- (now include role + department in every result)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at
    FROM  dbo.users       u
    LEFT JOIN dbo.roles       r ON r.id = u.role_id
    LEFT JOIN dbo.departments d ON d.id = u.department_id
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
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at
    FROM  dbo.users       u
    LEFT JOIN dbo.roles       r ON r.id = u.role_id
    LEFT JOIN dbo.departments d ON d.id = u.department_id
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
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at
    FROM  dbo.users       u
    LEFT JOIN dbo.roles       r ON r.id = u.role_id
    LEFT JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.email = @email;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username        NVARCHAR(100),
    @email           NVARCHAR(255),
    @hashed_password NVARCHAR(255),
    @role_id         INT = NULL,
    @department_id   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users (username, email, hashed_password, role_id, department_id)
    VALUES (@username, @email, @hashed_password, @role_id, @department_id);

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at
    FROM  dbo.users       u
    LEFT JOIN dbo.roles       r ON r.id = u.role_id
    LEFT JOIN dbo.departments d ON d.id = u.department_id
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
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at
    FROM  dbo.users       u
    LEFT JOIN dbo.roles       r ON r.id = u.role_id
    LEFT JOIN dbo.departments d ON d.id = u.department_id
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO
