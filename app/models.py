from sqlalchemy import Boolean, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class TaskDB(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    done: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    priority: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )