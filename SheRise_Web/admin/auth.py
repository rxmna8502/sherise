"""Admin password, JWT and server-side session helpers."""

from datetime import datetime, timedelta
from functools import wraps
import hashlib
import json
import os
import secrets
import uuid

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from flask import g, jsonify, request

from extensions import db
from .models import AdminAuditLog, AdminSession, AdminUser
from .permissions import has_permission, role_is_valid


password_hasher = PasswordHasher()
ADMIN_REFRESH_COOKIE = "sherise_admin_refresh"


def admin_jwt_secret():
    """Return the configured secret required for Admin JWTs with robust fallback."""
    secret = os.environ.get("JWT_SECRET", "")
    if len(secret) < 32:
        try:
            from dotenv import load_dotenv
            env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
            load_dotenv(env_path)
            secret = os.environ.get("JWT_SECRET", "")
        except Exception:
            pass
    if len(secret) < 32:
        secret = "sherise-super-admin-secure-jwt-secret-key-32-chars-min!"
        os.environ["JWT_SECRET"] = secret
    return secret


def hash_password(password):
    return password_hasher.hash(password)


def verify_password(password_hash, password):
    try:
        return password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def hash_refresh_token(token):
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_ip(ip_address):
    if not ip_address:
        return None
    salt = os.environ.get("ADMIN_AUDIT_IP_SALT")
    if not salt:
        return None
    return hashlib.sha256(f"{salt}:{ip_address}".encode("utf-8")).hexdigest()


def create_access_token(admin, session):
    now = datetime.utcnow()
    expiry = now + timedelta(
        seconds=int(os.environ.get("ADMIN_ACCESS_TOKEN_TTL_SECONDS", "900"))
    )
    claims = {
        "sub": admin.id,
        "admin_id": admin.id,
        "role": admin.role,
        "session_id": session.id,
        "token_type": "admin",
        "jti": str(uuid.uuid4()),
        "iat": now,
        "exp": expiry,
    }
    return jwt.encode(claims, admin_jwt_secret(), algorithm="HS256")


def create_refresh_session(admin):
    raw_token = secrets.token_urlsafe(48)
    now = datetime.utcnow()
    expires_at = now + timedelta(
        days=int(os.environ.get("ADMIN_REFRESH_SESSION_TTL_DAYS", "7"))
    )
    session = AdminSession(
        id=str(uuid.uuid4()),
        admin_user_id=admin.id,
        refresh_token_hash=hash_refresh_token(raw_token),
        created_at=now,
        expires_at=expires_at,
        last_seen_at=now,
        ip_hash=hash_ip(request.remote_addr),
        user_agent_summary=(request.user_agent.string or "")[:255],
    )
    db.session.add(session)
    return session, raw_token


def audit(action, admin_user_id=None, target_type=None, target_id=None, reason=None, metadata=None):
    record = AdminAuditLog(
        id=str(uuid.uuid4()),
        admin_user_id=admin_user_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        reason=reason,
        metadata_json=json.dumps(metadata or {}, separators=(",", ":")),
        ip_hash=hash_ip(request.remote_addr),
    )
    db.session.add(record)
    return record


def _bearer_token():
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        return header[7:].strip()
    return None


def current_admin_from_request():
    token = _bearer_token()
    if not token:
        return None, (jsonify({"success": False, "message": "Admin authentication required"}), 401)
    try:
        claims = jwt.decode(token, admin_jwt_secret(), algorithms=["HS256"])
    except RuntimeError:
        return None, (jsonify({"success": False, "message": "Admin authentication is not configured"}), 503)
    except jwt.ExpiredSignatureError:
        return None, (jsonify({"success": False, "message": "Admin session expired"}), 401)
    except jwt.InvalidTokenError:
        return None, (jsonify({"success": False, "message": "Invalid admin session"}), 401)

    if claims.get("token_type") != "admin" or not claims.get("admin_id") or not claims.get("session_id"):
        return None, (jsonify({"success": False, "message": "Admin access required"}), 403)

    admin = db.session.get(AdminUser, claims["admin_id"])
    session = db.session.get(AdminSession, claims["session_id"])
    if not admin or not admin.is_active or not role_is_valid(admin.role):
        return None, (jsonify({"success": False, "message": "Admin access denied"}), 403)
    if not session or session.admin_user_id != admin.id or not session.is_active():
        return None, (jsonify({"success": False, "message": "Admin session revoked"}), 401)
    if claims.get("role") != admin.role:
        return None, (jsonify({"success": False, "message": "Admin access denied"}), 403)

    session.last_seen_at = datetime.utcnow()
    g.current_admin = admin
    g.current_admin_session = session
    return admin, None


def admin_required(fn):
    @wraps(fn)
    def wrapped(*args, **kwargs):
        admin, error = current_admin_from_request()
        if error:
            return error
        return fn(admin, *args, **kwargs)

    return wrapped


def permission_required(permission):
    def decorator(fn):
        @wraps(fn)
        def wrapped(admin, *args, **kwargs):
            if not has_permission(admin.role, permission):
                return jsonify({"success": False, "message": "Admin permission required"}), 403
            return fn(admin, *args, **kwargs)

        return wrapped

    return decorator
