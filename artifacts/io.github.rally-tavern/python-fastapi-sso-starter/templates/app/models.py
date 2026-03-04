"""SQLAlchemy models."""

from datetime import datetime, timezone

from sqlalchemy import Column, Integer, String, DateTime, Boolean

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)  # Null for SSO-only users
    full_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)

    # SSO provider fields
    google_id = Column(String(255), unique=True, nullable=True, index=True)
    facebook_id = Column(String(255), unique=True, nullable=True, index=True)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
