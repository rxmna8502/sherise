"""Database models for secure administrator authentication."""

from datetime import datetime
import json

from extensions import db


class AdminUser(db.Model):
    __tablename__ = "admin_user"

    id = db.Column(db.String(36), primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(40), nullable=False, index=True)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    failed_login_count = db.Column(db.Integer, nullable=False, default=0)
    locked_until = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    last_login_at = db.Column(db.DateTime, nullable=True)

    sessions = db.relationship(
        "AdminSession", backref="admin_user", lazy=True, cascade="all, delete-orphan"
    )

    def to_public_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "role": self.role,
            "isActive": self.is_active,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "lastLoginAt": self.last_login_at.isoformat() if self.last_login_at else None,
        }


class AdminSession(db.Model):
    __tablename__ = "admin_session"

    id = db.Column(db.String(36), primary_key=True)
    admin_user_id = db.Column(
        db.String(36), db.ForeignKey("admin_user.id"), nullable=False, index=True
    )
    refresh_token_hash = db.Column(db.String(64), nullable=False, unique=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False, index=True)
    last_seen_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    revoked_at = db.Column(db.DateTime, nullable=True, index=True)
    ip_hash = db.Column(db.String(128), nullable=True)
    user_agent_summary = db.Column(db.String(255), nullable=True)

    def is_active(self, now=None):
        now = now or datetime.utcnow()
        return self.revoked_at is None and self.expires_at > now

    def to_public_dict(self, current=False):
        return {
            "id": self.id,
            "adminUserId": self.admin_user_id,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "expiresAt": self.expires_at.isoformat() if self.expires_at else None,
            "lastSeenAt": self.last_seen_at.isoformat() if self.last_seen_at else None,
            "revokedAt": self.revoked_at.isoformat() if self.revoked_at else None,
            "userAgent": self.user_agent_summary,
            "current": current,
            "active": self.is_active(),
        }


class AdminAuditLog(db.Model):
    __tablename__ = "admin_audit_log"

    id = db.Column(db.String(36), primary_key=True)
    # Nullable so failed attempts for unknown email addresses can be recorded
    # without fabricating an administrator identity.
    admin_user_id = db.Column(
        db.String(36), db.ForeignKey("admin_user.id"), nullable=True, index=True
    )
    action = db.Column(db.String(60), nullable=False, index=True)
    target_type = db.Column(db.String(40), nullable=True)
    target_id = db.Column(db.String(36), nullable=True)
    reason = db.Column(db.Text, nullable=True)
    metadata_json = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    ip_hash = db.Column(db.String(128), nullable=True)


class ActivityLog(db.Model):
    __tablename__ = "activity_log"

    id = db.Column(db.String(36), primary_key=True)
    actor_user_id = db.Column(db.String(36), nullable=True, index=True)
    event_type = db.Column(db.String(80), nullable=False, index=True)
    entity_type = db.Column(db.String(40), nullable=True, index=True)
    entity_id = db.Column(db.String(36), nullable=True, index=True)
    metadata_json = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    ip_hash = db.Column(db.String(128), nullable=True)

    def to_public_dict(self):
        try:
            metadata = json.loads(self.metadata_json) if self.metadata_json else {}
        except (TypeError, ValueError):
            metadata = {}
        return {
            "id": self.id,
            "actorUserId": self.actor_user_id,
            "eventType": self.event_type,
            "entityType": self.entity_type,
            "entityId": self.entity_id,
            "metadata": metadata,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
        }


class SafetyReport(db.Model):
    __tablename__ = "safety_report"

    CATEGORIES = {"suspicious_job", "harassment", "fraud", "payment_issue", "unsafe_location", "inappropriate_behavior", "emergency", "other"}
    SEVERITIES = {"low", "medium", "high", "critical"}
    STATUSES = {"new", "under_review", "action_required", "resolved"}

    id = db.Column(db.String(36), primary_key=True)
    reporter_user_id = db.Column(db.String(36), nullable=True, index=True)
    category = db.Column(db.String(40), nullable=False, index=True)
    severity = db.Column(db.String(20), nullable=False, index=True)
    status = db.Column(db.String(20), nullable=False, default="new", index=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=False)
    related_job_id = db.Column(db.String(36), nullable=True, index=True)
    related_user_id = db.Column(db.String(36), nullable=True, index=True)
    assigned_admin_id = db.Column(db.String(36), nullable=True, index=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
    resolved_at = db.Column(db.DateTime, nullable=True)

    def to_public_dict(self, include_description=True):
        value = {
            "id": self.id,
            "reporterUserId": self.reporter_user_id,
            "category": self.category,
            "severity": self.severity,
            "status": self.status,
            "title": self.title,
            "relatedJobId": self.related_job_id,
            "relatedUserId": self.related_user_id,
            "assignedAdminId": self.assigned_admin_id,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
            "updatedAt": self.updated_at.isoformat() if self.updated_at else None,
            "resolvedAt": self.resolved_at.isoformat() if self.resolved_at else None,
        }
        if include_description:
            value["description"] = self.description
        return value


class SafetyReportEvent(db.Model):
    __tablename__ = "safety_report_event"

    id = db.Column(db.String(36), primary_key=True)
    report_id = db.Column(db.String(36), db.ForeignKey("safety_report.id"), nullable=False, index=True)
    admin_user_id = db.Column(db.String(36), nullable=True, index=True)
    event_type = db.Column(db.String(50), nullable=False)
    from_status = db.Column(db.String(20), nullable=True)
    to_status = db.Column(db.String(20), nullable=True)
    note = db.Column(db.Text, nullable=True)
    metadata_json = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, index=True)

    report = db.relationship("SafetyReport", backref=db.backref("events", lazy=True, cascade="all, delete-orphan"))

    def to_public_dict(self):
        return {
            "id": self.id,
            "reportId": self.report_id,
            "adminUserId": self.admin_user_id,
            "eventType": self.event_type,
            "fromStatus": self.from_status,
            "toStatus": self.to_status,
            "note": self.note,
            "createdAt": self.created_at.isoformat() if self.created_at else None,
        }
