"""
Seed initial roles and a super admin user.
Usage:
    venv\Scripts\python scripts\seed_data.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text

from app.core.security import hash_password
from app.db.session import SessionLocal

ROLES = [
    ("super_admin", "Full system access — manages all users, roles, and settings"),
    ("admin",       "Manages users and documents within their organization"),
    ("approver",    "Reviews and approves uploaded documents"),
    ("officer",     "Processes and manages legal documents"),
    ("auditor",     "Read-only access for compliance and audit purposes"),
    ("uploader",    "Can upload documents with limited management access"),
    ("citizen",     "Basic access to submit and track their own documents"),
]


def seed() -> None:
    db = SessionLocal()
    try:
        for name, description in ROLES:
            db.execute(
                text("""
                    IF NOT EXISTS (SELECT 1 FROM roles WHERE name = :name)
                        INSERT INTO roles (name, description) VALUES (:name, :description)
                """),
                {"name": name, "description": description},
            )
        db.commit()
        print(f"Seeded {len(ROLES)} roles: {', '.join(r[0] for r in ROLES)}")

        result = db.execute(text("SELECT id FROM roles WHERE name = 'super_admin'"))
        super_admin_role_id = result.fetchone()[0]

        db.execute(
            text("""
                IF NOT EXISTS (SELECT 1 FROM users WHERE username = 'superadmin')
                    INSERT INTO users (username, email, hashed_password, role_id)
                    VALUES (:username, :email, :pwd, :role_id)
            """),
            {
                "username": "superadmin",
                "email": "superadmin@legalpdf.com",
                "pwd": hash_password("Admin@123"),
                "role_id": super_admin_role_id,
            },
        )
        db.commit()
        print("Seeded super admin user -> username: superadmin  password: Admin@123")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
