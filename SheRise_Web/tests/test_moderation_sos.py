import uuid
import pytest
from tests.conftest import create_admin, create_user, user_token
from admin.models import SafetyReport, ActivityLog
from app import db, User


def admin_token(client, email):
    response = client.post("/api/admin/login", json={"email": email, "password": "Correct-Horse-Battery-Staple-123!"})
    data = response.get_json()
    assert response.status_code == 200, f"Login failed: {data}"
    return data["data"]["accessToken"]


def test_user_ban_and_unban_moderation(client):
    email = f"mod-{uuid.uuid4().hex[:6]}@example.com"
    create_admin(email=email)
    headers = {"Authorization": f"Bearer {admin_token(client, email)}"}
    user = create_user("victim-1")

    # 1. Ban user
    res = client.post(f"/api/admin/users/{user.id}/ban", json={"reason": "Spam behavior"}, headers=headers)
    assert res.status_code == 200
    assert res.json["data"]["isBanned"] is True
    assert res.json["data"]["banReason"] == "Spam behavior"

    # 2. Block login for banned user
    login_res = client.post("/api/login", json={"email": user.email, "name": user.name})
    assert login_res.status_code == 403
    assert "suspended" in login_res.json["message"]

    # 3. Block authenticated requests using token
    token = user_token(user.id)
    profile_res = client.get("/api/users/me", headers={"Authorization": f"Bearer {token}"})
    assert profile_res.status_code == 403

    # 4. Unban user
    unban_res = client.post(f"/api/admin/users/{user.id}/unban", json={}, headers=headers)
    assert unban_res.status_code == 200
    assert unban_res.json["data"]["isBanned"] is False

    # 5. User can access again
    profile_res2 = client.get("/api/users/me", headers={"Authorization": f"Bearer {token}"})
    assert profile_res2.status_code == 200


def test_sos_emergency_trigger_and_safety_report(client):
    email = f"sos-{uuid.uuid4().hex[:6]}@example.com"
    create_admin(email=email)
    headers = {"Authorization": f"Bearer {admin_token(client, email)}"}

    # Trigger SOS without login (e.g. emergency quick tap)
    sos_res = client.post("/api/sos/trigger", json={
        "name": "Sunita Devi",
        "phone": "+919876543210",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "message": "Immediate help needed near Central Park"
    })
    assert sos_res.status_code == 200
    report_id = sos_res.json["reportId"]

    # Verify report is listed in Safety Center
    reports_res = client.get("/api/admin/safety-reports", headers=headers)
    assert reports_res.status_code == 200
    items = reports_res.json["data"]["items"]
    found = [r for r in items if r["id"] == report_id]
    assert len(found) == 1
    assert found[0]["severity"] == "critical"
    assert found[0]["status"] == "action_required"

    # Verify activity was logged
    act_res = client.get("/api/admin/activity?eventType=sos_emergency_triggered", headers=headers)
    assert act_res.status_code == 200
    assert len(act_res.json["data"]["items"]) >= 1
