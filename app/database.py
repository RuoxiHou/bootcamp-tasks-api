import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


_engine = None
SessionLocal = None

Base = declarative_base()


def get_engine():
    global _engine, SessionLocal

    if _engine is None:
        database_url = os.environ["DATABASE_URL"]

        if database_url.startswith("sqlite"):
            _engine = create_engine(
                database_url,
                connect_args={"check_same_thread": False},
                pool_pre_ping=True,
            )
        else:
            _engine = create_engine(
                database_url,
                connect_args={
                    "ssl": {
                        "ssl": True
                    }
                },
                pool_pre_ping=True,
            )

        SessionLocal = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=_engine,
        )

    return _engine


def get_db():
    get_engine()
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()