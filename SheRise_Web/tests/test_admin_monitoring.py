from datetime import datetime
import uuid

from app import Job, JobApplication, User, db
from admin.models import ActivityLog, SafetyReport
from .conftest import create_admin


def admin_token(client, email="admin@example.com"):
    response = client.post("/api/admin/login", json={"email": email, "password": "Correct-Horse-Battery-Staple-123!"})
    return response.get_json()["data"]["accessToken"]


def test_monitoring_endpoints_serialize_and_paginate(client):
    create_admin()
    user = User(id="u1", name="Asha", email="asha@example.com", gender="female", isVerified=True)
    job = Job(id="j1", title="Tutoring", description="Teach maths", category="education", status="open")
    application = JobApplication(id="a1", job_id="j1", worker_id="u1", status="pending", timestamp="now")
    db.session.add_all([user, job, application, ActivityLog(id=str(uuid.uuid4()), event_type="job_created", entity_type="job", entity_id="j1", created_at=datetime.utcnow())])
    db.session.commit()
    headers = {"Authorization": f"Bearer {admin_token(client)}"}
    assert client.get("/api/admin/stats", headers=headers).status_code == 200
    users = client.get("/api/admin/users?page=1&perPage=1", headers=headers).get_json()["data"]
    assert users["pagination"]["total"] == 1 and users["items"][0]["email"] == "asha@example.com"
    assert client.get("/api/admin/jobs", headers=headers).get_json()["data"]["items"][0]["title"] == "Tutoring"
    assert client.get("/api/admin/applications", headers=headers).status_code == 200
    assert client.get("/api/admin/activity", headers=headers).status_code == 200


def test_safety_case_update_creates_event_and_audit(client):
    create_admin()
    report = SafetyReport(id="r1", category="harassment", severity="high", status="new", title="Concern", description="Details")
    db.session.add(report)
    db.session.commit()
    headers = {"Authorization": f"Bearer {admin_token(client)}"}
    response = client.patch("/api/admin/safety-reports/r1", headers=headers, json={"status": "under_review", "note": "Assigned"})
    assert response.status_code == 200
    detail = client.get("/api/admin/safety-reports/r1", headers=headers).get_json()["data"]
    assert detail["status"] == "under_review" and len(detail["events"]) == 1
    audit = client.get("/api/admin/audit", headers=headers).get_json()["data"]["items"]
    assert any(item["action"] == "SAFETY_REPORT_UPDATED" for item in audit)


def test_safety_write_is_denied_to_support_readonly(client):
    create_admin("support@example.com", "support_readonly")
    db.session.add(SafetyReport(id="r1", category="other", severity="low", status="new", title="Concern", description="Details"))
    db.session.commit()
    token = admin_token(client, "support@example.com")
    response = client.patch("/api/admin/safety-reports/r1", headers={"Authorization": f"Bearer {token}"}, json={"status": "resolved"})
    assert response.status_code == 403
