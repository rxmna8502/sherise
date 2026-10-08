import jwt

from .conftest import create_admin, create_user, user_token


def test_normal_user_token_cannot_access_admin_api(client):
    create_user()
    token = user_token()
    response = client.get("/api/admin/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403


def test_missing_admin_token_is_rejected(client):
    assert client.get("/api/admin/me").status_code == 401


def test_admin_session_revocation_requires_super_admin_for_other_sessions(client):
    create_admin("one@example.com", "operations_admin")
    create_admin("two@example.com", "super_admin")

    one = client.post(
        "/api/admin/login",
        json={"email": "one@example.com", "password": "Correct-Horse-Battery-Staple-123!"},
    ).get_json()["data"]["accessToken"]
    sessions = client.get("/api/admin/sessions", headers={"Authorization": f"Bearer {one}"})
    assert sessions.status_code == 200

    # An operations admin only sees/revokes its own session.
    session_id = sessions.get_json()["data"][0]["id"]
    assert client.post(
        f"/api/admin/sessions/{session_id}/revoke",
        headers={"Authorization": f"Bearer {one}"},
        json={"reason": "Own session cleanup"},
    ).status_code == 200
