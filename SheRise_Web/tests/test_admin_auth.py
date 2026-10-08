from .conftest import create_admin


PASSWORD = "Correct-Horse-Battery-Staple-123!"


def test_admin_login_me_refresh_logout(client):
    create_admin()
    login = client.post(
        "/api/admin/login",
        json={"email": "admin@example.com", "password": PASSWORD},
    )
    assert login.status_code == 200
    body = login.get_json()
    assert body["data"]["admin"]["role"] == "super_admin"
    assert body["data"]["expiresIn"] == 900
    assert "password" not in str(body)
    assert "password_hash" not in str(body)

    access = body["data"]["accessToken"]
    me = client.get("/api/admin/me", headers={"Authorization": f"Bearer {access}"})
    assert me.status_code == 200

    refreshed = client.post("/api/admin/refresh")
    assert refreshed.status_code == 200
    refreshed_token = refreshed.get_json()["data"]["accessToken"]
    assert refreshed_token

    logout = client.post(
        "/api/admin/logout",
        headers={"Authorization": f"Bearer {refreshed_token}"},
    )
    assert logout.status_code == 200
    assert client.post("/api/admin/refresh").status_code == 401


def test_wrong_admin_credentials_are_generic(client):
    create_admin()
    response = client.post(
        "/api/admin/login",
        json={"email": "admin@example.com", "password": "wrong"},
    )
    assert response.status_code == 401
    assert response.get_json()["message"] == "Invalid administrator credentials"


def test_admin_password_reset_uses_otp_and_updates_password(client, monkeypatch):
    create_admin()
    sent = {}
    from admin.password_reset import issue as real_issue
    monkeypatch.setattr("admin.routes.issue", lambda email: real_issue(email))
    monkeypatch.setattr("admin.routes.send_reset_otp", lambda email, code: sent.update({"code": code}))
    requested = client.post("/api/admin/forgot-password", json={"email": "admin@example.com"})
    assert requested.status_code == 200
    reset = client.post("/api/admin/reset-password", json={
        "email": "admin@example.com", "otp": sent["code"], "password": "New-Password-123!",
    })
    assert reset.status_code == 200
    login = client.post("/api/admin/login", json={"email": "admin@example.com", "password": "New-Password-123!"})
    assert login.status_code == 200
