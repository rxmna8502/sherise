from datetime import datetime
from app import db, Notification
from .conftest import create_user


def test_frontend_notifications_polling_with_userid_query_param(client):
    user = create_user("test-user-1")

    # Seed a notification for the user
    notif = Notification(
        id="notif-1",
        user_id="test-user-1",
        type="info",
        message="Welcome to SheRise!",
        timestamp="Just now",
        created_at=datetime.now(),
        read=False,
    )
    db.session.add(notif)
    db.session.commit()

    # 1. Frontend polls with query param ?userId=... without Authorization header
    response = client.get(f"/api/notifications?userId={user.id}")
    assert response.status_code == 200
    data = response.get_json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["id"] == "notif-1"
    assert data[0]["read"] is False

    # 2. Frontend marks notification as read with POST /api/notifications/<id>/read
    read_resp = client.post("/api/notifications/notif-1/read")
    assert read_resp.status_code == 200
    assert read_resp.get_json()["success"] is True

    # Verify notification is marked read
    updated_notif = db.session.get(Notification, "notif-1")
    assert updated_notif.read is True

    # 3. Frontend marks all read with POST /api/notifications/mark-all-read and JSON { userId: ... }
    mark_all_resp = client.post("/api/notifications/mark-all-read", json={"userId": user.id})
    assert mark_all_resp.status_code == 200
    assert mark_all_resp.get_json()["success"] is True

    # 4. Unauthenticated request without token and without userId returns 401
    unauth_resp = client.get("/api/notifications")
    assert unauth_resp.status_code == 401

    # 5. Non-existent notification read request returns 401
    missing_notif_resp = client.post("/api/notifications/non-existent-999/read")
    assert missing_notif_resp.status_code == 401


def test_frontend_postings_and_applications_interop(client):
    user = create_user("worker-1")

    # Frontend calls /api/my-applications with { userId: ... }
    app_resp = client.post("/api/my-applications", json={"userId": user.id})
    assert app_resp.status_code == 200
    assert isinstance(app_resp.get_json(), list)

    # Frontend calls /api/my-postings with { userId: ... }
    post_resp = client.post("/api/my-postings", json={"userId": user.id})
    assert post_resp.status_code == 200
    assert isinstance(post_resp.get_json(), list)


def test_banned_user_blocked_even_with_userid_query_param(client):
    user = create_user("banned-user-1")
    user.is_banned = True
    user.ban_reason = "Spamming complaints"
    db.session.commit()

    # Even if userId is sent, banned user must be rejected with 403
    response = client.get(f"/api/notifications?userId={user.id}")
    assert response.status_code == 403
    assert "Account suspended" in response.get_json()["message"]
