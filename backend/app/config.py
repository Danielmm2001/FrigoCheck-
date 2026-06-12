from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "FrigoCheck API"
    OPENAI_API_KEY: str = ""
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    BARCODE_LOOKUP_API_KEY: str = ""
    ENVIRONMENT: str = "development"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
