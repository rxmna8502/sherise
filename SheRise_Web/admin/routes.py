"""Phase 2A Admin authentication and session endpoints."""

from datetime import datetime
import os
import json
import uuid
import sys
from sqlalchemy import or_

from flask import Blueprint, g, jsonify, make_response, request

from extensions import db
from .auth import (
    ADMIN_REFRESH_COOKIE,
    admin_jwt_secret,
    admin_required,
    audit,
    create_access_token,
    create_refresh_session,
    hash_refresh_token,
    verify_password,
)
from .models import AdminAuditLog, AdminSession, AdminUser, ActivityLog, SafetyReport, SafetyReportEvent
from .permissions import ROLE_PERMISSIONS, has_permission, role_is_valid
from .rate_limit import email_key, limiter
from .password_reset import issue, send_reset_otp, verify


admin_bp = Blueprint("admin_auth", __name__, url_prefix="/api/admin")


def _cookie_settings():
    production = os.environ.get("APP_ENV", "development").lower() == "production"
    return {
        "httponly": True,
        "secure": production,
        "samesite": "Lax",
        "path": "/api/admin",
    }


def _set_refresh_cookie(response, token):
    max_age = int(os.environ.get("ADMIN_REFRESH_SESSION_TTL_DAYS", "7")) * 86400
    response.set_cookie(ADMIN_REFRESH_COOKIE, token, max_age=max_age, **_cookie_settings())


def _clear_refresh_cookie(response):
    response.delete_cookie(ADMIN_REFRESH_COOKIE, path="/api/admin")


def _safe_login_error():
    return jsonify({"success": False, "message": "Invalid administrator credentials"}), 401


@admin_bp.post("/forgot-password")
@limiter.limit("3 per hour", key_func=email_key)
def admin_forgot_password():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    generic = {"success": True, "message": "If that Admin account exists, a reset OTP has been sent."}
    admin = AdminUser.query.filter_by(email=email).first()
    if not admin or not admin.is_active:
        return jsonify(generic)
    try:
        code = issue(email)
        send_reset_otp(email, code)
        audit("ADMIN_PASSWORD_RESET_REQUESTED", admin.id)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify({"success": False, "message": "Password reset email is not configured"}), 503
    return jsonify(generic)


@admin_bp.post("/reset-password")
@limiter.limit("5 per hour", key_func=email_key)
def admin_reset_password():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    otp = str(data.get("otp", "")).strip()
    password = data.get("password")
    if not email or len(otp) != 6 or not isinstance(password, str) or len(password) < 12:
        return jsonify({"success": False, "message": "Email, six-digit OTP, and a password of at least 12 characters are required"}), 400
    admin = AdminUser.query.filter_by(email=email).first()
    if not admin or not verify(email, otp):
        return jsonify({"success": False, "message": "Invalid or expired reset OTP"}), 400
    admin.password_hash = __import__("admin.auth", fromlist=["hash_password"]).hash_password(password)
    admin.failed_login_count = 0
    admin.locked_until = None
    for session in admin.sessions:
        if session.is_active():
            session.revoked_at = datetime.utcnow()
    audit("ADMIN_PASSWORD_RESET_COMPLETED", admin.id)
    db.session.commit()
    return jsonify({"success": True, "message": "Admin password updated. Please sign in again."})


@admin_bp.post("/login")
@limiter.limit("20 per 15 minutes")
@limiter.limit("5 per 15 minutes", key_func=email_key)
def admin_login():
    try:
        admin_jwt_secret()
    except RuntimeError:
        return jsonify({"success": False, "message": "Admin authentication is not configured"}), 503

    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    password = data.get("password")
    if not email or not isinstance(password, str) or not password:
        return jsonify({"success": False, "message": "Email and password are required"}), 400

    admin = AdminUser.query.filter_by(email=email).first()
    now = datetime.utcnow()
    if admin and admin.locked_until and admin.locked_until > now:
        audit("ADMIN_ACCOUNT_LOCKED", admin.id, reason="Login attempted while account was locked")
        db.session.commit()
        return jsonify({"success": False, "message": "Invalid administrator credentials"}), 401

    if not admin or not admin.is_active or not role_is_valid(admin.role) or not verify_password(admin.password_hash, password):
        if admin:
            admin.failed_login_count += 1
            if admin.failed_login_count >= 5:
                from datetime import timedelta

                admin.locked_until = now + timedelta(minutes=15)
                audit("ADMIN_ACCOUNT_LOCKED", admin.id, reason="Repeated failed login attempts")
            audit("ADMIN_LOGIN_FAILED", admin.id)
        else:
            audit("ADMIN_LOGIN_FAILED")
        db.session.commit()
        return _safe_login_error()

    admin.failed_login_count = 0
    admin.locked_until = None
    admin.last_login_at = now
    session, refresh_token = create_refresh_session(admin)
    access_token = create_access_token(admin, session)
    audit("ADMIN_LOGIN_SUCCESS", admin.id, target_type="admin_session", target_id=session.id)
    db.session.commit()

    response = make_response(
        jsonify(
            {
                "success": True,
                "data": {
                    "admin": admin.to_public_dict(),
                    "accessToken": access_token,
                    "expiresIn": int(os.environ.get("ADMIN_ACCESS_TOKEN_TTL_SECONDS", "900")),
                },
            }
        )
    )
    _set_refresh_cookie(response, refresh_token)
    return response


@admin_bp.post("/refresh")
def admin_refresh():
    try:
        admin_jwt_secret()
    except RuntimeError:
        return jsonify({"success": False, "message": "Admin authentication is not configured"}), 503

    raw_token = request.cookies.get(ADMIN_REFRESH_COOKIE)
    session = AdminSession.query.filter_by(refresh_token_hash=hash_refresh_token(raw_token or "")).first()
    if not session or not session.is_active():
        return jsonify({"success": False, "message": "Invalid admin session"}), 401
    admin = db.session.get(AdminUser, session.admin_user_id)
    if not admin or not admin.is_active or not role_is_valid(admin.role):
        return jsonify({"success": False, "message": "Admin access denied"}), 403

    session.last_seen_at = datetime.utcnow()
    audit("ADMIN_TOKEN_REFRESHED", admin.id, target_type="admin_session", target_id=session.id)
    access_token = create_access_token(admin, session)
    db.session.commit()
    return jsonify(
        {
            "success": True,
            "data": {
                "admin": admin.to_public_dict(),
                "accessToken": access_token,
                "expiresIn": int(os.environ.get("ADMIN_ACCESS_TOKEN_TTL_SECONDS", "900")),
            },
        }
    )


@admin_bp.post("/logout")
@admin_required
def admin_logout(admin):
    session = g.current_admin_session
    session.revoked_at = datetime.utcnow()
    audit("ADMIN_LOGOUT", admin.id, target_type="admin_session", target_id=session.id)
    db.session.commit()
    response = make_response(jsonify({"success": True}))
    _clear_refresh_cookie(response)
    return response


@admin_bp.get("/me")
@admin_required
def admin_me(admin):
    return jsonify(
        {
            "success": True,
            "data": {
                **admin.to_public_dict(),
                "permissions": sorted(ROLE_PERMISSIONS.get(admin.role, set())),
            },
        }
    )


@admin_bp.get("/sessions")
@admin_required
def admin_sessions(admin):
    query = AdminSession.query.filter_by(admin_user_id=admin.id)
    if has_permission(admin.role, "admin_sessions_all"):
        query = AdminSession.query
    sessions = query.order_by(AdminSession.created_at.desc()).limit(100).all()
    current_id = g.current_admin_session.id
    return jsonify({"success": True, "data": [s.to_public_dict(s.id == current_id) for s in sessions]})


@admin_bp.post("/sessions/<session_id>/revoke")
@admin_required
def revoke_admin_session(admin, session_id):
    session = db.session.get(AdminSession, session_id)
    if not session:
        return jsonify({"success": False, "message": "Admin session not found"}), 404
    if session.admin_user_id != admin.id and not has_permission(admin.role, "admin_sessions_all"):
        return jsonify({"success": False, "message": "Admin permission required"}), 403
    data = request.get_json(silent=True) or {}
    reason = str(data.get("reason", "")).strip()
    if not reason:
        return jsonify({"success": False, "message": "A revocation reason is required"}), 400
    session.revoked_at = datetime.utcnow()
    audit("ADMIN_SESSION_REVOKED", admin.id, "admin_session", session.id, reason=reason)
    db.session.commit()
    return jsonify({"success": True})


def _permission_or_403(admin, permission):
    if not has_permission(admin.role, permission):
        return jsonify({"success": False, "message": "Admin permission required"}), 403
    return None


def _page(query):
    try:
        page = max(1, int(request.args.get("page", 1)))
        per_page = min(100, max(1, int(request.args.get("perPage", request.args.get("per_page", 25)))))
    except (TypeError, ValueError):
        return None, (jsonify({"success": False, "message": "Invalid pagination"}), 400)
    result = query.paginate(page=page, per_page=per_page, error_out=False)
    return {"items": result.items, "pagination": {"page": page, "perPage": per_page, "total": result.total, "pages": result.pages}}, None


def _user_public(user):
    return {"id": user.id, "name": user.name, "email": user.email, "gender": user.gender,
            "rating": user.rating, "reviewCount": user.reviewCount, "isVerified": bool(user.isVerified),
            "isBanned": bool(getattr(user, "is_banned", False)), "banReason": getattr(user, "ban_reason", None),
            "availability": user.availability, "lastSeen": user.last_seen.isoformat() if user.last_seen else None}


def _job_public(job):
    return {"id": job.id, "title": job.title, "description": job.description, "category": job.category,
            "minAmount": job.min_amount, "maxAmount": job.max_amount, "location": job.location,
            "deliveryType": job.deliveryType, "urgency": job.urgency, "paymentMode": job.paymentMode,
            "customerName": job.customerName, "status": job.status, "postedAt": job.postedAt,
            "creatorId": job.creator_id, "workerId": job.worker_id}


def _admin_monitor_required(admin, permission="monitor_read"):
    return _permission_or_403(admin, permission)


def _core_models():
    """Return the already-loaded core models without importing app.py twice.

    When Flask runs app.py directly, it is loaded as __main__. Importing app
    from an Admin request would execute the module a second time and make
    SQLAlchemy register duplicate tables.
    """
    module = sys.modules.get("__main__")
    if not module or not hasattr(module, "User"):
        module = sys.modules.get("app")
    if not module or not hasattr(module, "User"):
        import importlib
        module = importlib.import_module("app")
    return module


@admin_bp.get("/stats")
@admin_required
def admin_stats(admin):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    core = _core_models()
    User, Job, JobApplication = core.User, core.Job, core.JobApplication
    return jsonify({"success": True, "data": {"users": User.query.count(), "jobs": Job.query.count(),
        "applications": JobApplication.query.count(), "activity": ActivityLog.query.count(),
        "safetyReports": SafetyReport.query.count(), "openSafetyReports": SafetyReport.query.filter(SafetyReport.status != "resolved").count()}})


@admin_bp.get("/users")
@admin_required
def admin_users(admin):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    User = _core_models().User
    query = User.query.order_by(User.id.desc())
    if request.args.get("verified") in {"true", "false"}: query = query.filter_by(isVerified=request.args.get("verified") == "true")
    if request.args.get("banned") in {"true", "false"}: query = query.filter_by(is_banned=request.args.get("banned") == "true")
    term = request.args.get("search", "").strip()
    if term: query = query.filter(or_(User.name.ilike(f"%{term}%"), User.email.ilike(f"%{term}%")))
    result, error = _page(query)
    if error: return error
    return jsonify({"success": True, "data": {"items": [_user_public(x) for x in result["items"]], "pagination": result["pagination"]}})


@admin_bp.get("/users/<user_id>")
@admin_required
def admin_user_detail(admin, user_id):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    User = _core_models().User
    user = db.session.get(User, user_id)
    if not user: return jsonify({"success": False, "message": "User not found"}), 404
    return jsonify({"success": True, "data": _user_public(user)})


@admin_bp.post("/users/<user_id>/verify")
@admin_required
def admin_toggle_verify_user(admin, user_id):
    denied = _permission_or_403(admin, "user_moderate")
    if denied: return denied
    User = _core_models().User
    user = db.session.get(User, user_id)
    if not user: return jsonify({"success": False, "message": "User not found"}), 404
    data = request.get_json(silent=True) or {}
    new_status = data.get("isVerified") if "isVerified" in data else not bool(user.isVerified)
    user.isVerified = new_status
    audit("USER_VERIFY_TOGGLE", admin.id, "user", user_id, reason=f"Set isVerified={new_status}")
    db.session.commit()
    return jsonify({"success": True, "data": _user_public(user)})


@admin_bp.post("/users/<user_id>/ban")
@admin_required
def admin_ban_user(admin, user_id):
    denied = _permission_or_403(admin, "user_moderate")
    if denied: return denied
    User = _core_models().User
    user = db.session.get(User, user_id)
    if not user: return jsonify({"success": False, "message": "User not found"}), 404
    data = request.get_json(silent=True) or {}
    reason = str(data.get("reason", "Violated platform safety guidelines")).strip() or "Violated platform safety guidelines"
    user.is_banned = True
    user.ban_reason = reason
    audit("USER_BANNED", admin.id, "user", user_id, reason=reason)
    activity = ActivityLog(
        id=str(uuid.uuid4()),
        event_type="user_banned",
        entity_type="user",
        entity_id=user_id,
        actor_user_id=None,
        metadata_json=json.dumps({"reason": reason, "admin_id": admin.id}),
        created_at=datetime.utcnow()
    )
    db.session.add(activity)
    db.session.commit()
    return jsonify({"success": True, "message": f"User {user.name or user.id} has been suspended.", "data": _user_public(user)})


@admin_bp.post("/users/<user_id>/unban")
@admin_required
def admin_unban_user(admin, user_id):
    denied = _permission_or_403(admin, "user_moderate")
    if denied: return denied
    User = _core_models().User
    user = db.session.get(User, user_id)
    if not user: return jsonify({"success": False, "message": "User not found"}), 404
    user.is_banned = False
    user.ban_reason = None
    audit("USER_UNBANNED", admin.id, "user", user_id, reason="Account unbanned by administrator")
    activity = ActivityLog(
        id=str(uuid.uuid4()),
        event_type="user_unbanned",
        entity_type="user",
        entity_id=user_id,
        actor_user_id=None,
        metadata_json=json.dumps({"admin_id": admin.id}),
        created_at=datetime.utcnow()
    )
    db.session.add(activity)
    db.session.commit()
    return jsonify({"success": True, "message": f"User {user.name or user.id} has been reinstated.", "data": _user_public(user)})


@admin_bp.get("/jobs")
@admin_required
def admin_jobs(admin):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    Job = _core_models().Job
    query = Job.query.order_by(Job.id.desc())
    if request.args.get("status"): query = query.filter_by(status=request.args["status"])
    term = request.args.get("search", "").strip()
    if term: query = query.filter(or_(Job.title.ilike(f"%{term}%"), Job.category.ilike(f"%{term}%")))
    result, error = _page(query)
    if error: return error
    return jsonify({"success": True, "data": {"items": [_job_public(x) for x in result["items"]], "pagination": result["pagination"]}})


@admin_bp.get("/jobs/<job_id>")
@admin_required
def admin_job_detail(admin, job_id):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    Job = _core_models().Job
    job = db.session.get(Job, job_id)
    if not job: return jsonify({"success": False, "message": "Job not found"}), 404
    return jsonify({"success": True, "data": _job_public(job)})


@admin_bp.delete("/jobs/<job_id>")
@admin_required
def admin_delete_job(admin, job_id):
    denied = _permission_or_403(admin, "job_moderate")
    if denied: return denied
    Job = _core_models().Job
    job = db.session.get(Job, job_id)
    if not job: return jsonify({"success": False, "message": "Job not found"}), 404
    data = request.get_json(silent=True) or {}
    reason = data.get("reason", "Admin removed job listing")
    audit("JOB_DELETED", admin.id, "job", job_id, reason=reason)
    db.session.delete(job)
    db.session.commit()
    return jsonify({"success": True, "message": "Job removed successfully"})


@admin_bp.post("/jobs/<job_id>/status")
@admin_required
def admin_set_job_status(admin, job_id):
    denied = _permission_or_403(admin, "job_moderate")
    if denied: return denied
    Job = _core_models().Job
    job = db.session.get(Job, job_id)
    if not job: return jsonify({"success": False, "message": "Job not found"}), 404
    data = request.get_json(silent=True) or {}
    new_status = data.get("status")
    if not new_status: return jsonify({"success": False, "message": "status is required"}), 400
    old_status = job.status
    job.status = new_status
    audit("JOB_STATUS_CHANGE", admin.id, "job", job_id, reason=f"Changed status from {old_status} to {new_status}")
    db.session.commit()
    return jsonify({"success": True, "data": _job_public(job)})


@admin_bp.get("/applications")
@admin_required
def admin_applications(admin):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    JobApplication = _core_models().JobApplication
    query = JobApplication.query.order_by(JobApplication.id.desc())
    if request.args.get("status"): query = query.filter_by(status=request.args["status"])
    result, error = _page(query)
    if error: return error
    items = [{"id": x.id, "jobId": x.job_id, "workerId": x.worker_id, "status": x.status, "timestamp": x.timestamp,
              "workerName": x.worker.name if x.worker else None, "jobTitle": x.job.title if x.job else None} for x in result["items"]]
    return jsonify({"success": True, "data": {"items": items, "pagination": result["pagination"]}})


@admin_bp.get("/activity")
@admin_required
def admin_activity(admin):
    denied = _admin_monitor_required(admin)
    if denied: return denied
    query = ActivityLog.query.order_by(ActivityLog.created_at.desc())
    if request.args.get("eventType"): query = query.filter_by(event_type=request.args["eventType"])
    result, error = _page(query)
    if error: return error
    return jsonify({"success": True, "data": {"items": [x.to_public_dict() for x in result["items"]], "pagination": result["pagination"]}})


@admin_bp.get("/safety-reports")
@admin_required
def admin_safety_reports(admin):
    denied = _permission_or_403(admin, "safety_read")
    if denied: return denied
    query = SafetyReport.query.order_by(SafetyReport.created_at.desc())
    allowed = {"category": SafetyReport.CATEGORIES, "severity": SafetyReport.SEVERITIES, "status": SafetyReport.STATUSES}
    for field, values in allowed.items():
        if request.args.get(field) in values: query = query.filter(getattr(SafetyReport, field) == request.args[field])
    result, error = _page(query)
    if error: return error
    return jsonify({"success": True, "data": {"items": [x.to_public_dict(False) for x in result["items"]], "pagination": result["pagination"]}})


@admin_bp.get("/safety-reports/<report_id>")
@admin_required
def admin_safety_report_detail(admin, report_id):
    denied = _permission_or_403(admin, "safety_read")
    if denied: return denied
    report = db.session.get(SafetyReport, report_id)
    if not report: return jsonify({"success": False, "message": "Safety report not found"}), 404
    return jsonify({"success": True, "data": {**report.to_public_dict(), "events": [x.to_public_dict() for x in sorted(report.events, key=lambda e: e.created_at)]}})


@admin_bp.patch("/safety-reports/<report_id>")
@admin_required
def admin_safety_report_update(admin, report_id):
    denied = _permission_or_403(admin, "safety_write")
    if denied: return denied
    report = db.session.get(SafetyReport, report_id)
    if not report: return jsonify({"success": False, "message": "Safety report not found"}), 404
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    severity = data.get("severity")
    if status is not None and status not in SafetyReport.STATUSES: return jsonify({"success": False, "message": "Invalid status"}), 400
    if severity is not None and severity not in SafetyReport.SEVERITIES: return jsonify({"success": False, "message": "Invalid severity"}), 400
    old_status = report.status
    if status is not None: report.status = status
    if severity is not None: report.severity = severity
    if status == "resolved": report.resolved_at = datetime.utcnow()
    elif status is not None: report.resolved_at = None
    event = SafetyReportEvent(id=str(uuid.uuid4()), report_id=report.id, admin_user_id=admin.id, event_type="updated",
        from_status=old_status, to_status=report.status, note=str(data.get("note", "")).strip() or None,
        metadata_json=json.dumps({"severity": report.severity}))
    db.session.add(event)
    audit("SAFETY_REPORT_UPDATED", admin.id, "safety_report", report.id, reason=event.note)
    db.session.commit()
    return jsonify({"success": True, "data": report.to_public_dict()})


@admin_bp.get("/audit")
@admin_required
def admin_audit(admin):
    denied = _permission_or_403(admin, "audit_read")
    if denied: return denied
    query = AdminAuditLog.query.order_by(AdminAuditLog.created_at.desc())
    if request.args.get("action"): query = query.filter_by(action=request.args["action"])
    result, error = _page(query)
    if error: return error
    items = [{"id": x.id, "adminUserId": x.admin_user_id, "action": x.action, "targetType": x.target_type,
              "targetId": x.target_id, "reason": x.reason, "createdAt": x.created_at.isoformat() if x.created_at else None} for x in result["items"]]
    return jsonify({"success": True, "data": {"items": items, "pagination": result["pagination"]}})
