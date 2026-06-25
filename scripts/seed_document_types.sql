-- ============================================================
-- Seed data for document_types table.
-- Safe to re-run — skips existing entries by name.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\seed_document_types.sql
-- ============================================================

USE Legal_PDF;
GO

INSERT INTO dbo.document_types (name)
SELECT name FROM (VALUES
    ('Act'),
    ('Amendment'),
    ('Notification'),
    ('Circular'),
    ('Policy'),
    ('Rules & Regulations'),
    ('Order / Gazette')
) AS src(name)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.document_types dt WHERE dt.name = src.name
);
GO
