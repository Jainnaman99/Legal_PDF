import json
from datetime import date
from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_repository import IPDFRepository
from app.models.pdf_document import PDFDocument
from app.schemas.pdf import ApprovalInfo, RelationshipRef
from app.schemas.tag import TagRef


class PDFRepository(IPDFRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(
        self,
        filename: str,
        original_filename: str,
        file_path: str,
        file_size: int,
        uploaded_by: int,
        document_name: Optional[str] = None,
        reference_number: Optional[str] = None,
        issue_date: Optional[date] = None,
        effective_from: Optional[date] = None,
        gazette_reference: Optional[str] = None,
        legal_authority: Optional[str] = None,
        short_title: Optional[str] = None,
        valid_until: Optional[date] = None,
        sector_domain: Optional[str] = None,
        implementing_agency: Optional[str] = None,
        next_review_date: Optional[date] = None,
        rule_making_authority: Optional[str] = None,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        description: Optional[str] = None,
        summary: Optional[str] = None,
        act_year: Optional[int] = None,
        long_title: Optional[str] = None,
        regional_title: Optional[str] = None,
        notification_no: Optional[str] = None,
        act_code: Optional[str] = None,
        so_reason: Optional[str] = None,
        no_of_rules: Optional[int] = None,
        no_of_notifications: Optional[int] = None,
        no_of_regulations: Optional[int] = None,
        no_of_circulars: Optional[int] = None,
        no_of_statutes: Optional[int] = None,
        no_of_ordinances: Optional[int] = None,
        no_of_orders: Optional[int] = None,
        keywords: Optional[str] = None,
        is_repealed: bool = False,
        last_updated_on: Optional[date] = None,
        status: str = "pending",
    ) -> PDFDocument:
        result = self._db.execute(
            text(
                "CALL sp_create_pdf_document("
                ":filename, :original_filename, :file_path, :file_size, :uploaded_by, "
                ":document_name, :reference_number, :issue_date, :effective_from, "
                ":gazette_reference, :legal_authority, :short_title, :valid_until, "
                ":sector_domain, :implementing_agency, :next_review_date, :rule_making_authority, "
                ":version_no, :department_id, :document_type_id, :description, :summary, "
                ":act_year, :long_title, :regional_title, :notification_no, :act_code, :so_reason, "
                ":no_of_rules, :no_of_notifications, :no_of_regulations, :no_of_circulars, "
                ":no_of_statutes, :no_of_ordinances, :no_of_orders, :keywords, :is_repealed, "
                ":last_updated_on, :status"
                ")"
            ),
            {
                "filename": filename,
                "original_filename": original_filename,
                "file_path": file_path,
                "file_size": file_size,
                "uploaded_by": uploaded_by,
                "document_name": document_name,
                "reference_number": reference_number,
                "issue_date": issue_date,
                "effective_from": effective_from,
                "gazette_reference": gazette_reference,
                "legal_authority": legal_authority,
                "short_title": short_title,
                "valid_until": valid_until,
                "sector_domain": sector_domain,
                "implementing_agency": implementing_agency,
                "next_review_date": next_review_date,
                "rule_making_authority": rule_making_authority,
                "version_no": version_no,
                "department_id": department_id,
                "document_type_id": document_type_id,
                "description": description,
                "summary": summary,
                "act_year": act_year,
                "long_title": long_title,
                "regional_title": regional_title,
                "notification_no": notification_no,
                "act_code": act_code,
                "so_reason": so_reason,
                "no_of_rules": no_of_rules,
                "no_of_notifications": no_of_notifications,
                "no_of_regulations": no_of_regulations,
                "no_of_circulars": no_of_circulars,
                "no_of_statutes": no_of_statutes,
                "no_of_ordinances": no_of_ordinances,
                "no_of_orders": no_of_orders,
                "keywords": keywords,
                "is_repealed": is_repealed,
                "last_updated_on": last_updated_on,
                "status": status,
            },
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row)

    def update(
        self,
        document_id: int,
        document_name: Optional[str] = None,
        reference_number: Optional[str] = None,
        issue_date: Optional[date] = None,
        effective_from: Optional[date] = None,
        gazette_reference: Optional[str] = None,
        legal_authority: Optional[str] = None,
        short_title: Optional[str] = None,
        valid_until: Optional[date] = None,
        sector_domain: Optional[str] = None,
        implementing_agency: Optional[str] = None,
        next_review_date: Optional[date] = None,
        rule_making_authority: Optional[str] = None,
        version_no: Optional[str] = None,
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        description: Optional[str] = None,
        act_year: Optional[int] = None,
        long_title: Optional[str] = None,
        regional_title: Optional[str] = None,
        notification_no: Optional[str] = None,
        act_code: Optional[str] = None,
        so_reason: Optional[str] = None,
        no_of_rules: Optional[int] = None,
        no_of_notifications: Optional[int] = None,
        no_of_regulations: Optional[int] = None,
        no_of_circulars: Optional[int] = None,
        no_of_statutes: Optional[int] = None,
        no_of_ordinances: Optional[int] = None,
        no_of_orders: Optional[int] = None,
        keywords: Optional[str] = None,
        is_repealed: Optional[bool] = None,
        last_updated_on: Optional[date] = None,
    ) -> Optional[PDFDocument]:
        result = self._db.execute(
            text(
                "CALL sp_update_pdf_document("
                ":document_id, :document_name, :reference_number, :issue_date, :effective_from, "
                ":gazette_reference, :legal_authority, :short_title, :valid_until, "
                ":sector_domain, :implementing_agency, :next_review_date, :rule_making_authority, "
                ":version_no, :department_id, :document_type_id, :description, "
                ":act_year, :long_title, :regional_title, :notification_no, :act_code, :so_reason, "
                ":no_of_rules, :no_of_notifications, :no_of_regulations, :no_of_circulars, "
                ":no_of_statutes, :no_of_ordinances, :no_of_orders, :keywords, :is_repealed, "
                ":last_updated_on"
                ")"
            ),
            {
                "document_id": document_id,
                "document_name": document_name,
                "reference_number": reference_number,
                "issue_date": issue_date,
                "effective_from": effective_from,
                "gazette_reference": gazette_reference,
                "legal_authority": legal_authority,
                "short_title": short_title,
                "valid_until": valid_until,
                "sector_domain": sector_domain,
                "implementing_agency": implementing_agency,
                "next_review_date": next_review_date,
                "rule_making_authority": rule_making_authority,
                "version_no": version_no,
                "department_id": department_id,
                "document_type_id": document_type_id,
                "description": description,
                "act_year": act_year,
                "long_title": long_title,
                "regional_title": regional_title,
                "notification_no": notification_no,
                "act_code": act_code,
                "so_reason": so_reason,
                "no_of_rules": no_of_rules,
                "no_of_notifications": no_of_notifications,
                "no_of_regulations": no_of_regulations,
                "no_of_circulars": no_of_circulars,
                "no_of_statutes": no_of_statutes,
                "no_of_ordinances": no_of_ordinances,
                "no_of_orders": no_of_orders,
                "keywords": keywords,
                "is_repealed": is_repealed,
                "last_updated_on": last_updated_on,
            },
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row) if row else None

    def resubmit_document(self, document_id: int) -> None:
        self._db.execute(
            text("UPDATE pdf_documents SET status='pending' WHERE id=:id AND status IN ('rejected','draft')"),
            {"id": document_id},
        )
        self._db.execute(
            text("""
                UPDATE pdf_document_approvals pda
                JOIN (
                    SELECT id FROM pdf_document_approvals
                    WHERE pdf_id = :id
                    ORDER BY acted_at DESC
                    LIMIT 1
                ) latest ON pda.id = latest.id
                SET pda.annotations_json = NULL
            """),
            {"id": document_id},
        )
        self._db.commit()

    def get_by_id(self, document_id: int) -> Optional[PDFDocument]:
        result = self._db.execute(
            text("CALL sp_get_pdf_by_id(:document_id)"),
            {"document_id": document_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def list_by_user(self, user_id: int, skip: int = 0, limit: int = 100) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_list_pdfs_by_user(:user_id, :skip, :limit)"),
            {"user_id": user_id, "skip": skip, "limit": limit},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def list_all(self, skip: int = 0, limit: int = 100, status: Optional[str] = None, approver_id: Optional[int] = None) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_list_all_pdfs(:skip, :limit, :status, :approver_id)"),
            {"skip": skip, "limit": limit, "status": status, "approver_id": approver_id},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def get_pending(self, skip: int = 0, limit: int = 100, approver_id=None) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_get_pending_pdfs(:skip, :limit, :approver_id)"),
            {"skip": skip, "limit": limit, "approver_id": approver_id},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def search_documents_by_type(self, document_type: str, q: str, limit: int = 20) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_search_documents_by_type(:document_type, :q, :limit)"),
            {"document_type": document_type, "q": q, "limit": limit},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def check_duplicate(self, document_name: str, document_type_id: int, caller_dept_id: int) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_check_duplicate_document(:document_name, :document_type_id, :caller_dept_id)"),
            {"document_name": document_name, "document_type_id": document_type_id, "caller_dept_id": caller_dept_id},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def link_to_department(self, pdf_id: int, department_id: int, user_id: int) -> dict:
        result = self._db.execute(
            text("CALL sp_link_document_to_department(:pdf_id, :department_id, :linked_by)"),
            {"pdf_id": pdf_id, "department_id": department_id, "linked_by": user_id},
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return dict(row) if row else {}

    def get_links_for_department(self, department_id: int, status: str | None = "pending") -> list[dict]:
        result = self._db.execute(
            text("CALL sp_get_department_links(:department_id, :status)"),
            {"department_id": department_id, "status": status},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def review_department_link(self, link_id: int, action: str, reviewed_by: int, comments: str | None = None, annotations_json: str | None = None) -> None:
        self._db.execute(
            text("CALL sp_review_department_link(:link_id, :action, :reviewed_by, :comments, :annotations_json)"),
            {"link_id": link_id, "action": action, "reviewed_by": reviewed_by, "comments": comments, "annotations_json": annotations_json},
        )
        self._db.commit()

    def get_linked_documents_for_department(self, department_id: int, status: str | None = None) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_get_linked_documents_for_department(:department_id, :status)"),
            {"department_id": department_id, "status": status},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def get_all_department_links(self, status: str | None = None, department_id: int | None = None) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_get_all_department_links(:status, :department_id)"),
            {"status": status, "department_id": department_id},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def citizen_search(self, document_type_id: Optional[int] = None, name_prefix: Optional[str] = None, skip: int = 0, limit: int = 20) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_citizen_search_docs(:document_type_id, :name_prefix, :skip, :limit)"),
            {"document_type_id": document_type_id, "name_prefix": name_prefix, "skip": skip, "limit": limit},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def list_docs_by_dept_and_type(self, dept_ids: str, doc_type_id: int, skip: int = 0, limit: int = 100, status: Optional[str] = None) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_list_docs_by_dept_and_type(:dept_ids, :doc_type_id, :skip, :limit, :status)"),
            {"dept_ids": dept_ids, "doc_type_id": doc_type_id, "skip": skip, "limit": limit, "status": status},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def list_acts_by_department(self, dept_ids: str, skip: int = 0, limit: int = 100, status: Optional[str] = None) -> tuple[int, list[PDFDocument]]:
        result = self._db.execute(
            text("CALL sp_list_acts_by_department(:dept_ids, :skip, :limit, :status)"),
            {"dept_ids": dept_ids, "skip": skip, "limit": limit, "status": status},
        )
        rows = result.mappings().fetchall()
        total = rows[0]["total_count"] if rows else 0
        return total, [self._map_row(row) for row in rows]

    def get_documents_under_act(self, act_id: int) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_get_documents_under_act(:act_id)"),
            {"act_id": act_id},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def get_act_full_related_docs(self, act_id: int) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_get_act_full_related_docs(:act_id)"),
            {"act_id": act_id},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def replace_file(
        self,
        pdf_id: int,
        new_filename: str,
        new_original_filename: str,
        new_file_path: str,
        new_file_size: int,
        new_summary: Optional[str] = None,
        resubmit: bool = False,
    ) -> Optional[PDFDocument]:
        result = self._db.execute(
            text(
                "CALL sp_replace_pdf_file("
                ":pdf_id, :new_filename, :new_original_filename, :new_file_path, "
                ":new_file_size, :new_summary, :resubmit"
                ")"
            ),
            {
                "pdf_id": pdf_id,
                "new_filename": new_filename,
                "new_original_filename": new_original_filename,
                "new_file_path": new_file_path,
                "new_file_size": new_file_size,
                "new_summary": new_summary,
                "resubmit": 1 if resubmit else 0,
            },
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row) if row else None

    def save_relationships(self, pdf_id: int, relationships: list[dict]) -> None:
        if not relationships:
            return
        self._db.execute(
            text("CALL sp_save_pdf_relationships(:pdf_id, :rels)"),
            {"pdf_id": pdf_id, "rels": json.dumps(relationships)},
        )
        self._db.commit()

    @staticmethod
    def _parse_tags(tags_str: Optional[str]) -> list[TagRef]:
        if not tags_str:
            return []
        result = []
        for part in tags_str.split(","):
            part = part.strip()
            if ":" in part:
                tag_id_str, tag_name = part.split(":", 1)
                try:
                    result.append(TagRef(id=int(tag_id_str), name=tag_name))
                except ValueError:
                    pass
        return result

    @staticmethod
    def _parse_approval(approval_json: Optional[str]) -> Optional[ApprovalInfo]:
        if not approval_json:
            return None
        try:
            d = json.loads(approval_json)
            return ApprovalInfo(
                action=d["action"],
                comments=d.get("comments"),
                annotations_json=d.get("annotations_json"),
                acted_at=d["acted_at"],
                approver_username=d["approver_username"],
                approver_first_name=d.get("approver_first_name"),
                approver_last_name=d.get("approver_last_name"),
            )
        except (json.JSONDecodeError, KeyError):
            return None

    @staticmethod
    def _parse_relationships(rels_json: Optional[str]) -> list[RelationshipRef]:
        if not rels_json:
            return []
        try:
            items = json.loads(rels_json)
            return [
                RelationshipRef(
                    pdf_id=item["pdf_id"],
                    document_name=item.get("document_name"),
                    type=item.get("type", "related"),
                )
                for item in items
            ]
        except (json.JSONDecodeError, KeyError):
            return []

    @staticmethod
    def _map_row(row) -> PDFDocument:
        d = dict(row)
        doc = PDFDocument(
            id=d["id"],
            filename=d["filename"],
            original_filename=d["original_filename"],
            file_path=d["file_path"],
            file_size=d["file_size"],
            status=d.get("status", "pending"),
            document_name=d.get("document_name"),
            reference_number=d.get("reference_number"),
            issue_date=d.get("issue_date"),
            effective_from=d.get("effective_from"),
            gazette_reference=d.get("gazette_reference"),
            legal_authority=d.get("legal_authority"),
            short_title=d.get("short_title"),
            valid_until=d.get("valid_until"),
            sector_domain=d.get("sector_domain"),
            implementing_agency=d.get("implementing_agency"),
            next_review_date=d.get("next_review_date"),
            rule_making_authority=d.get("rule_making_authority"),
            version_no=d.get("version_no"),
            department_id=d.get("department_id"),
            document_type_id=d.get("document_type_id"),
            description=d.get("description"),
            summary=d.get("summary"),
            act_year=d.get("act_year"),
            long_title=d.get("long_title"),
            regional_title=d.get("regional_title"),
            notification_no=d.get("notification_no"),
            act_code=d.get("act_code"),
            so_reason=d.get("so_reason"),
            no_of_rules=d.get("no_of_rules"),
            no_of_notifications=d.get("no_of_notifications"),
            no_of_regulations=d.get("no_of_regulations"),
            no_of_circulars=d.get("no_of_circulars"),
            no_of_statutes=d.get("no_of_statutes"),
            no_of_ordinances=d.get("no_of_ordinances"),
            no_of_orders=d.get("no_of_orders"),
            keywords=d.get("keywords"),
            is_repealed=bool(d.get("is_repealed", False)),
            last_updated_on=d.get("last_updated_on"),
            uploaded_by=d["uploaded_by"],
            created_at=d["created_at"],
        )
        doc.department_name = d.get("department_name")
        doc.document_type_name = d.get("document_type_name")
        doc.tags = PDFRepository._parse_tags(d.get("tags"))
        doc.relationships = PDFRepository._parse_relationships(d.get("relationships"))
        doc.latest_approval = PDFRepository._parse_approval(d.get("latest_approval"))
        doc.uploader_username = d.get("uploader_username")
        doc.uploader_first_name = d.get("uploader_first_name")
        doc.uploader_last_name = d.get("uploader_last_name")
        return doc
