"""Configuration Module."""

from pydantic import MongoDsn, PostgresDsn, computed_field
from pydantic_core import MultiHostUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration class."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_ignore_empty=True,
        extra="ignore",
    )

    # DataBase
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str | None = None
    POSTGRES_DB: str = "supermercado"

    @computed_field
    @property
    def SQLALCHEMY_DATABASE_URI(self) -> PostgresDsn:
        password = (
            None
            if self.POSTGRES_PASSWORD in (None, "", "trust")
            else self.POSTGRES_PASSWORD
        )

        return MultiHostUrl.build(
            scheme="postgresql+psycopg",
            username=self.POSTGRES_USER,
            password=password,
            host=self.POSTGRES_SERVER,
            port=self.POSTGRES_PORT,
            path=self.POSTGRES_DB,
        )

    # MongoDB
    MONGO_SERVER: str = "localhost"
    MONGO_PORT: int = 27017
    MONGO_USER: str | None = None
    MONGO_PASSWORD: str | None = None
    MONGO_DB: str = "product_catalog"

    @computed_field
    @property
    def MONGO_DATABASE_URI(self) -> MongoDsn:
        # Sin usuario no se envían credenciales (instancia local sin auth)
        username = self.MONGO_USER or None
        password = self.MONGO_PASSWORD if username else None

        return MultiHostUrl.build(
            scheme="mongodb",
            username=username,
            password=password,
            host=self.MONGO_SERVER,
            port=self.MONGO_PORT,
        )


settings = Settings()
