-- ============================================================
-- Role lookup stored procedures  (SQL Server T-SQL)
-- Run AFTER create_tables.sql has been executed.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_roles_procedures.sql
-- ============================================================

USE Legal_PDF;
GO

-- List all roles with optional pagination
CREATE OR ALTER PROCEDURE dbo.sp_list_roles
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.roles
    ORDER  BY id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

-- Get a single role by ID
CREATE OR ALTER PROCEDURE dbo.sp_get_role_by_id
    @role_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.roles
    WHERE  id = @role_id;
END;
GO
