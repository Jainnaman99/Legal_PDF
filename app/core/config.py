from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "Legal PDF API"
    SECRET_KEY: str = "dev-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    DB_DRIVER: str = "ODBC Driver 18 for SQL Server"
    DB_SERVER: str = "localhost"
    DB_PORT: int = 1433
    DB_NAME: str = "legal_pdf_db"
    DB_USER: str = "sa"
    DB_PASSWORD: str = "YourStrong@Passw0rd"
    DB_TRUST_CERT: str = "yes"
    DB_ENCRYPT: str = "yes"

    UPLOAD_DIR: str = "uploads"

    model_config = {"env_file": ".env"}


settings = Settings()
