from typing import Optional

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.interfaces.user_repository import IUserRepository
from app.models.role import Role
from app.models.user import User


class UserRepository(IUserRepository):

    def __init__(self, db: Session):
        self._db = db

    def get_by_id(self, user_id: int) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_id @user_id = :user_id"),
            {"user_id": user_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def get_by_username(self, username: str) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_username @username = :username"),
            {"username": username},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def get_by_email(self, email: str) -> Optional[User]:
        result = self._db.execute(
            text("EXEC sp_get_user_by_email @email = :email"),
            {"email": email},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def create(
        self,
        username: str,
        email: str,
        hashed_password: str,
        role_id: Optional[int] = None,
    ) -> User:
        try:
            result = self._db.execute(
                text(
                    "EXEC sp_create_user "
                    "@username = :username, @email = :email, "
                    "@hashed_password = :hashed_password, @role_id = :role_id"
                ),
                {
                    "username": username,
                    "email": email,
                    "hashed_password": hashed_password,
                    "role_id": role_id,
                },
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row)
        except IntegrityError as e:
            self._db.rollback()
            err = str(e.orig).lower()
            if "uq_users_username" in err:
                raise ValueError("Username is already taken")
            if "uq_users_email" in err:
                raise ValueError("Email is already registered")
            raise ValueError("A user with this username or email already exists")

    def list_all(self, skip: int = 0, limit: int = 100) -> list[User]:
        result = self._db.execute(
            text("EXEC sp_list_users @skip = :skip, @limit = :limit"),
            {"skip": skip, "limit": limit},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    @staticmethod
    def _map_row(row) -> User:
        user = User(
            id=row["id"],
            username=row["username"],
            email=row["email"],
            hashed_password=row["hashed_password"],
            is_active=bool(row["is_active"]),
            role_id=row["role_id"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )
        if row["role_id"]:
            user.role = Role(
                id=row["role_id"],
                name=row["role_name"],
                description=row["role_description"],
            )
        return user
