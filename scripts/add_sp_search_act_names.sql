-- Search document_name within Act documents (case-insensitive LIKE)
-- Used by the relationship / autocomplete input on the frontend

CREATE OR ALTER PROCEDURE sp_search_act_names
    @q     NVARCHAR(255),
    @limit INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@limit)
        p.id,
        p.document_name,
        p.reference_number,
        p.status
    FROM pdf_documents p
    INNER JOIN document_types dt ON p.document_type_id = dt.id
    WHERE dt.name = 'Act'
      AND p.document_name LIKE N'%' + @q + N'%'
    ORDER BY p.document_name ASC;
END;
GO
