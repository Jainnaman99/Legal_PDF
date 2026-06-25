-- ============================================================
-- Adds document metadata fields to pdf_documents, creates
-- document_types and tags (hierarchical) tables, and updates
-- all PDF stored procedures to include the new columns.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_document_metadata.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. document_types table
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.document_types', 'U') IS NULL
CREATE TABLE dbo.document_types
(
    id          INT           IDENTITY(1,1) NOT NULL,
    name        NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NULL,
    created_at  DATETIME2     NOT NULL CONSTRAINT DF_doc_types_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_document_types      PRIMARY KEY (id),
    CONSTRAINT UQ_document_types_name UNIQUE (name)
);
GO

-- ─────────────────────────────────────────────
-- 2. tags table  (hierarchical via parent_id)
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.tags', 'U') IS NULL
CREATE TABLE dbo.tags
(
    id         INT           IDENTITY(1,1) NOT NULL,
    name       NVARCHAR(100) NOT NULL,
    parent_id  INT           NULL,
    created_at DATETIME2     NOT NULL CONSTRAINT DF_tags_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_tags        PRIMARY KEY (id),
    CONSTRAINT UQ_tags_name   UNIQUE (name),
    CONSTRAINT FK_tags_parent FOREIGN KEY (parent_id)
        REFERENCES dbo.tags(id) ON DELETE NO ACTION
);
GO

-- ─────────────────────────────────────────────
-- 3. pdf_document_tags  (junction)
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.pdf_document_tags', 'U') IS NULL
CREATE TABLE dbo.pdf_document_tags
(
    pdf_id INT NOT NULL,
    tag_id INT NOT NULL,
    CONSTRAINT PK_pdf_document_tags PRIMARY KEY (pdf_id, tag_id),
    CONSTRAINT FK_pdt_pdf FOREIGN KEY (pdf_id)
        REFERENCES dbo.pdf_documents(id) ON DELETE CASCADE,
    CONSTRAINT FK_pdt_tag FOREIGN KEY (tag_id)
        REFERENCES dbo.tags(id) ON DELETE CASCADE
);
GO

-- ─────────────────────────────────────────────
-- 4. New metadata columns on pdf_documents
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'act_name')
    ALTER TABLE dbo.pdf_documents ADD act_name NVARCHAR(500) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'gazette_reference')
    ALTER TABLE dbo.pdf_documents ADD gazette_reference NVARCHAR(500) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'issuing_authority')
    ALTER TABLE dbo.pdf_documents ADD issuing_authority NVARCHAR(255) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'enactment_date')
    ALTER TABLE dbo.pdf_documents ADD enactment_date DATE NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'version_no')
    ALTER TABLE dbo.pdf_documents ADD version_no NVARCHAR(50) NULL CONSTRAINT DF_pdf_version_no DEFAULT '1.0';
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'department_id')
    ALTER TABLE dbo.pdf_documents ADD department_id INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_pdf_department')
    ALTER TABLE dbo.pdf_documents
        ADD CONSTRAINT FK_pdf_department FOREIGN KEY (department_id)
        REFERENCES dbo.departments(id) ON DELETE SET NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'document_type_id')
    ALTER TABLE dbo.pdf_documents ADD document_type_id INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_pdf_document_type')
    ALTER TABLE dbo.pdf_documents
        ADD CONSTRAINT FK_pdf_document_type FOREIGN KEY (document_type_id)
        REFERENCES dbo.document_types(id) ON DELETE SET NULL;
GO

-- ─────────────────────────────────────────────
-- 5. Document-type SPs
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_document_types
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.document_types
    ORDER  BY name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_document_type_by_id
    @type_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, description, created_at
    FROM   dbo.document_types
    WHERE  id = @type_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_document_type
    @name        NVARCHAR(100),
    @description NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;
    INSERT INTO dbo.document_types (name, description) VALUES (@name, @description);
    SET @new_id = SCOPE_IDENTITY();
    SELECT id, name, description, created_at FROM dbo.document_types WHERE id = @new_id;
END;
GO

-- ─────────────────────────────────────────────
-- 6. Tag SPs
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_tags
AS
BEGIN
    SET NOCOUNT ON;
    SELECT t.id, t.name, t.parent_id, p.name AS parent_name, t.created_at
    FROM   dbo.tags t
    LEFT   JOIN dbo.tags p ON p.id = t.parent_id
    ORDER  BY t.parent_id, t.name;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_tag_by_id
    @tag_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT t.id, t.name, t.parent_id, p.name AS parent_name, t.created_at
    FROM   dbo.tags t
    LEFT   JOIN dbo.tags p ON p.id = t.parent_id
    WHERE  t.id = @tag_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_tag
    @name      NVARCHAR(100),
    @parent_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;
    INSERT INTO dbo.tags (name, parent_id) VALUES (@name, @parent_id);
    SET @new_id = SCOPE_IDENTITY();
    SELECT t.id, t.name, t.parent_id, p.name AS parent_name, t.created_at
    FROM   dbo.tags t
    LEFT   JOIN dbo.tags p ON p.id = t.parent_id
    WHERE  t.id = @new_id;
END;
GO

-- Save tags for a document (replaces existing; accepts comma-separated IDs)
CREATE OR ALTER PROCEDURE dbo.sp_save_pdf_document_tags
    @pdf_id  INT,
    @tag_ids NVARCHAR(MAX)   -- e.g. '1,3,5'
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.pdf_document_tags WHERE pdf_id = @pdf_id;
    INSERT INTO dbo.pdf_document_tags (pdf_id, tag_id)
    SELECT @pdf_id, TRY_CAST(value AS INT)
    FROM   STRING_SPLIT(@tag_ids, ',')
    WHERE  TRY_CAST(value AS INT) IS NOT NULL;
END;
GO

-- ─────────────────────────────────────────────
-- 7. Shared tag subquery as a helper comment:
--    (used inline in each PDF SP below)
--    STRING_AGG requires SQL Server 2017+
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
-- 8. Updated PDF document SPs
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_pdf_document
    @filename          NVARCHAR(255),
    @original_filename NVARCHAR(255),
    @file_path         NVARCHAR(500),
    @file_size         BIGINT,
    @uploaded_by       INT,
    @act_name          NVARCHAR(500) = NULL,
    @gazette_reference NVARCHAR(500) = NULL,
    @issuing_authority NVARCHAR(255) = NULL,
    @enactment_date    DATE          = NULL,
    @version_no        NVARCHAR(50)  = '1.0',
    @department_id     INT           = NULL,
    @document_type_id  INT           = NULL,
    @description       NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.pdf_documents (
        filename, original_filename, file_path, file_size, uploaded_by,
        act_name, gazette_reference, issuing_authority, enactment_date, version_no,
        department_id, document_type_id, description
    ) VALUES (
        @filename, @original_filename, @file_path, @file_size, @uploaded_by,
        @act_name, @gazette_reference, @issuing_authority, @enactment_date, @version_no,
        @department_id, @document_type_id, @description
    );

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.act_name, d.gazette_reference, d.issuing_authority, d.enactment_date, d.version_no,
        d.uploaded_by, d.description, d.created_at,
        d.department_id,   dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        NULL AS tags
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = @new_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_pdf_by_id
    @document_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.act_name, d.gazette_reference, d.issuing_authority, d.enactment_date, d.version_no,
        d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = @document_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_pdfs_by_user
    @user_id INT,
    @skip    INT = 0,
    @limit   INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.act_name, d.gazette_reference, d.issuing_authority, d.enactment_date, d.version_no,
        d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.uploaded_by = @user_id
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_all_pdfs
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.act_name, d.gazette_reference, d.issuing_authority, d.enactment_date, d.version_no,
        d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO
