-- ============================================================
-- Updates pdf_documents schema to support per-document-type
-- metadata fields and adds a relationships table.
--
-- Run AFTER add_document_metadata.sql
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\update_pdf_document_schema.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Rename existing columns
-- ─────────────────────────────────────────────

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'act_name'
)
    EXEC sp_rename 'dbo.pdf_documents.act_name', 'document_name', 'COLUMN';
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'issuing_authority'
)
    EXEC sp_rename 'dbo.pdf_documents.issuing_authority', 'legal_authority', 'COLUMN';
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'enactment_date'
)
    EXEC sp_rename 'dbo.pdf_documents.enactment_date', 'issue_date', 'COLUMN';
GO

-- ─────────────────────────────────────────────
-- 2. Add new type-specific columns
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'reference_number')
    ALTER TABLE dbo.pdf_documents ADD reference_number NVARCHAR(100) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'short_title')
    ALTER TABLE dbo.pdf_documents ADD short_title NVARCHAR(255) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'effective_from')
    ALTER TABLE dbo.pdf_documents ADD effective_from DATE NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'valid_until')
    ALTER TABLE dbo.pdf_documents ADD valid_until DATE NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'sector_domain')
    ALTER TABLE dbo.pdf_documents ADD sector_domain NVARCHAR(255) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'implementing_agency')
    ALTER TABLE dbo.pdf_documents ADD implementing_agency NVARCHAR(255) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'next_review_date')
    ALTER TABLE dbo.pdf_documents ADD next_review_date DATE NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'rule_making_authority')
    ALTER TABLE dbo.pdf_documents ADD rule_making_authority NVARCHAR(255) NULL;
GO

-- ─────────────────────────────────────────────
-- 3. pdf_document_relationships table
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.pdf_document_relationships', 'U') IS NULL
CREATE TABLE dbo.pdf_document_relationships
(
    id                INT          IDENTITY(1,1) NOT NULL,
    source_pdf_id     INT          NOT NULL,
    target_pdf_id     INT          NOT NULL,
    relationship_type NVARCHAR(50) NOT NULL CONSTRAINT DF_rel_type DEFAULT 'related',
    created_at        DATETIME2    NOT NULL CONSTRAINT DF_rel_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_pdf_relationships  PRIMARY KEY (id),
    CONSTRAINT UQ_pdf_relationship   UNIQUE (source_pdf_id, target_pdf_id, relationship_type),
    CONSTRAINT CK_rel_no_self        CHECK  (source_pdf_id <> target_pdf_id),
    CONSTRAINT FK_rel_source         FOREIGN KEY (source_pdf_id)
        REFERENCES dbo.pdf_documents(id) ON DELETE CASCADE,
    CONSTRAINT FK_rel_target         FOREIGN KEY (target_pdf_id)
        REFERENCES dbo.pdf_documents(id) ON DELETE NO ACTION
);
GO

-- ─────────────────────────────────────────────
-- 4. Relationships SP
--    @relationships: JSON array
--    e.g. [{"pdf_id":5,"type":"parent_act"},{"pdf_id":7,"type":"related"}]
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_save_pdf_relationships
    @source_pdf_id INT,
    @relationships NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.pdf_document_relationships WHERE source_pdf_id = @source_pdf_id;
    INSERT INTO dbo.pdf_document_relationships (source_pdf_id, target_pdf_id, relationship_type)
    SELECT
        @source_pdf_id,
        j.pdf_id,
        ISNULL(j.[type], 'related')
    FROM OPENJSON(@relationships)
    WITH (
        pdf_id INT          '$.pdf_id',
        [type] NVARCHAR(50) '$.type'
    ) j
    WHERE j.pdf_id IS NOT NULL AND j.pdf_id <> @source_pdf_id;
END;
GO

-- ─────────────────────────────────────────────
-- 5. Updated PDF stored procedures
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_pdf_document
    @filename              NVARCHAR(255),
    @original_filename     NVARCHAR(255),
    @file_path             NVARCHAR(500),
    @file_size             BIGINT,
    @uploaded_by           INT,
    @document_name         NVARCHAR(500) = NULL,
    @reference_number      NVARCHAR(100) = NULL,
    @issue_date            DATE          = NULL,
    @effective_from        DATE          = NULL,
    @gazette_reference     NVARCHAR(500) = NULL,
    @legal_authority       NVARCHAR(255) = NULL,
    @short_title           NVARCHAR(255) = NULL,
    @valid_until           DATE          = NULL,
    @sector_domain         NVARCHAR(255) = NULL,
    @implementing_agency   NVARCHAR(255) = NULL,
    @next_review_date      DATE          = NULL,
    @rule_making_authority NVARCHAR(255) = NULL,
    @version_no            NVARCHAR(50)  = '1.0',
    @department_id         INT           = NULL,
    @document_type_id      INT           = NULL,
    @description           NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.pdf_documents (
        filename, original_filename, file_path, file_size, uploaded_by,
        document_name, reference_number, issue_date, effective_from,
        gazette_reference, legal_authority, short_title, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        version_no, department_id, document_type_id, description
    ) VALUES (
        @filename, @original_filename, @file_path, @file_size, @uploaded_by,
        @document_name, @reference_number, @issue_date, @effective_from,
        @gazette_reference, @legal_authority, @short_title, @valid_until,
        @sector_domain, @implementing_agency, @next_review_date, @rule_making_authority,
        @version_no, @department_id, @document_type_id, @description
    );

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        NULL AS tags,
        NULL AS relationships
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
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT r.target_pdf_id AS pdf_id,
                   pd.document_name,
                   r.relationship_type AS [type]
            FROM   dbo.pdf_document_relationships r
            JOIN   dbo.pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
            FOR JSON PATH
        ) AS relationships
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
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT r.target_pdf_id AS pdf_id,
                   pd.document_name,
                   r.relationship_type AS [type]
            FROM   dbo.pdf_document_relationships r
            JOIN   dbo.pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
            FOR JSON PATH
        ) AS relationships
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
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT r.target_pdf_id AS pdf_id,
                   pd.document_name,
                   r.relationship_type AS [type]
            FROM   dbo.pdf_document_relationships r
            JOIN   dbo.pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
            FOR JSON PATH
        ) AS relationships
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO
