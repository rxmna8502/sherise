"""Additive Phase 2A Admin authentication tables.

Revision ID: 20260816_admin_auth
Revises:
"""

from alembic import op
import sqlalchemy as sa


revision = "20260816_admin_auth"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "admin_user",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("role", sa.String(length=40), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("failed_login_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("last_login_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("email", name="uq_admin_user_email"),
    )
    op.create_index("ix_admin_user_email", "admin_user", ["email"], unique=True)
    op.create_index("ix_admin_user_role", "admin_user", ["role"])

    op.create_table(
        "admin_session",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("admin_user_id", sa.String(length=36), nullable=False),
        sa.Column("refresh_token_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("ip_hash", sa.String(length=128), nullable=True),
        sa.Column("user_agent_summary", sa.String(length=255), nullable=True),
        sa.ForeignKeyConstraint(["admin_user_id"], ["admin_user.id"]),
        sa.UniqueConstraint("refresh_token_hash", name="uq_admin_session_refresh_hash"),
    )
    op.create_index("ix_admin_session_admin_user_id", "admin_session", ["admin_user_id"])
    op.create_index("ix_admin_session_expires_at", "admin_session", ["expires_at"])
    op.create_index("ix_admin_session_revoked_at", "admin_session", ["revoked_at"])

    op.create_table(
        "admin_audit_log",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("admin_user_id", sa.String(length=36), nullable=True),
        sa.Column("action", sa.String(length=60), nullable=False),
        sa.Column("target_type", sa.String(length=40), nullable=True),
        sa.Column("target_id", sa.String(length=36), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("ip_hash", sa.String(length=128), nullable=True),
        sa.ForeignKeyConstraint(["admin_user_id"], ["admin_user.id"]),
    )
    op.create_index("ix_admin_audit_log_admin_user_id", "admin_audit_log", ["admin_user_id"])
    op.create_index("ix_admin_audit_log_action", "admin_audit_log", ["action"])
    op.create_index("ix_admin_audit_log_created_at", "admin_audit_log", ["created_at"])


def downgrade():
    # Do not drop Admin tables automatically; preserve audit/security data.
    raise RuntimeError("Destructive Admin migrations are not supported")
