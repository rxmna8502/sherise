import os

os.environ.setdefault("JWT_SECRET", "phase2a-test-secret-that-is-at-least-32-chars")
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("ADMIN_LOGIN_RATE_LIMIT_STORAGE_URI", "memory://")
os.environ["ADMIN_ACCESS_TOKEN_TTL_SECONDS"] = "900"

import pytest
import jwt
from datetime import datetime, timedelta

from app import app, db, User
from admin.auth import hash_password
from admin.models import AdminUser


@pytest.fixture()
def client():
    app.config.update(TESTING=True, WTF_CSRF_ENABLED=False)
    with app.app_context():
        db.drop_all()
        db.create_all()
        yield app.test_client()
        db.session.remove()
        db.drop_all()


def create_admin(email="admin@example.com", role="super_admin"):
    admin = AdminUser(
        id=f"admin-{email}",
        email=email,
        password_hash=hash_password("Correct-Horse-Battery-Staple-123!"),
        role=role,
    )
    db.session.add(admin)
    db.session.commit()
    return admin


def create_user(user_id="user-1"):
    user = User(
        id=user_id,
        name="Test User",
        email=f"{user_id}@example.com",
        phone="9999999999",
        skills_str="[]",
    )
    db.session.add(user)
    db.session.commit()
    return user


def user_token(user_id="user-1"):
    return jwt.encode(
        {
            "user_id": user_id,
            "exp": datetime.utcnow() + timedelta(days=1),
        },
        os.environ["JWT_SECRET"],
        algorithm="HS256",
    )
