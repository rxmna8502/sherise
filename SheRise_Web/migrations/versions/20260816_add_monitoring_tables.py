"""Additive Phase 2B monitoring and safety tables."""

from alembic import op
import sqlalchemy as sa

revision = "20260816_monitoring"
down_revision = "20260816_admin_auth"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "activity_log",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("actor_user_id", sa.String(36), nullable=True),
        sa.Column("event_type", sa.String(80), nullable=False),
        sa.Column("entity_type", sa.String(40), nullable=True),
        sa.Column("entity_id", sa.String(36), nullable=True),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("ip_hash", sa.String(128), nullable=True),
    )
    op.create_index("ix_activity_log_actor_user_id", "activity_log", ["actor_user_id"])
    op.create_index("ix_activity_log_event_type", "activity_log", ["event_type"])
    op.create_index("ix_activity_log_created_at", "activity_log", ["created_at"])

    op.create_table(
        "safety_report",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("reporter_user_id", sa.String(36), nullable=True),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("severity", sa.String(20), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="new"),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("related_job_id", sa.String(36), nullable=True),
        sa.Column("related_user_id", sa.String(36), nullable=True),
        sa.Column("assigned_admin_id", sa.String(36), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
    )
    for name, col in (("category", "category"), ("severity", "severity"), ("status", "status"), ("created_at", "created_at")):
        op.create_index(f"ix_safety_report_{name}", "safety_report", [col])

    op.create_table(
        "safety_report_event",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("report_id", sa.String(36), nullable=False),
        sa.Column("admin_user_id", sa.String(36), nullable=True),
        sa.Column("event_type", sa.String(50), nullable=False),
        sa.Column("from_status", sa.String(20), nullable=True),
        sa.Column("to_status", sa.String(20), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["report_id"], ["safety_report.id"]),
    )
    op.create_index("ix_safety_report_event_report_id", "safety_report_event", ["report_id"])
    op.create_index("ix_safety_report_event_created_at", "safety_report_event", ["created_at"])


def downgrade():
    raise RuntimeError("Destructive monitoring migrations are not supported")
