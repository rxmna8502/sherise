"""Rate limiting for administrative authentication."""

import os

from flask import request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


def _storage_uri():
    # Memory storage is suitable only for local development. Production should
    # set a shared Redis/database storage URI so limits work across workers.
    return os.environ.get("ADMIN_LOGIN_RATE_LIMIT_STORAGE_URI", "memory://")


limiter = Limiter(key_func=get_remote_address, storage_uri=_storage_uri())


def email_key():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    return f"admin-email:{email or 'missing'}"


def init_limiter(app):
    limiter.init_app(app)
