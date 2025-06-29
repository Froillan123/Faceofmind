from pydantic import BaseSettings
from typing import Optional
from dotenv import load_dotenv
import os

# Load environment variables from .env file
env_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=env_path)


class Settings(BaseSettings):
    # Database configuration
    database_url: str = os.getenv("DATABASE_URL")
    # JWT configuration
    jwt_secret_token: str = os.getenv("JWT_SECRET_TOKEN")
    jwt_access_token: str = os.getenv("JWT_ACCESS_TOKEN")
    jwt_refresh_token: str = os.getenv("JWT_REFRESH_TOKEN")
    jwt_access_token_expire_minutes: int = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", 30))
    # SMTP configuration
    smtp_host: str = os.getenv("SMTP_HOST")
    smtp_port: int = int(os.getenv("SMTP_PORT", 587))
    smtp_email: str = os.getenv("SMTP_EMAIL")
    smtp_password: str = os.getenv("SMTP_PASSWORD")
    # Redis configuration
    redis_url: str = os.getenv("REDIS_URL")
    # OpenRouter API (hardcoded)
    openrouter_api_key: str = os.getenv("OPENROUTER_API_KEY")
    openrouter_api_url: str = os.getenv("OPENROUTER_API_URL")

    # Gemini API (hardcoded)
    gemini_api_key: str = os.getenv("GEMINI_API_KEY")
    gemini_api_url: str = os.getenv("GEMINI_API_URL")

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()