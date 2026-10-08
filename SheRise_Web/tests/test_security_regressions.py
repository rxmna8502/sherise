from .conftest import create_user, user_token


def test_critical_mutations_require_authentication(client):
    assert client.post("/api/jobs", json={}).status_code == 401
    assert client.get("/api/messages/job-1").status_code == 401
    assert client.post("/api/notifications/n-1/read").status_code == 401
    assert client.get("/api/subscription").status_code == 401
    assert client.post("/api/subscription/subscribe", json={"plan": "free"}).status_code == 401


def test_authenticated_user_cannot_change_protected_profile_fields(client):
    create_user()
    token = user_token()
    response = client.put(
        "/api/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"credits": 999999},
    )
    assert response.status_code == 403
