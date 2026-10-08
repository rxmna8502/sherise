from .conftest import create_admin


def test_super_admin_can_revoke_another_admin_session(client):
    password = "Correct-Horse-Battery-Staple-123!"
    create_admin("operator@example.com", "operations_admin")
    create_admin("root@example.com", "super_admin")

    operator_token = client.post(
        "/api/admin/login",
        json={"email": "operator@example.com", "password": password},
    ).get_json()["data"]["accessToken"]
    operator_session = client.get(
        "/api/admin/sessions", headers={"Authorization": f"Bearer {operator_token}"}
    ).get_json()["data"][0]["id"]

    root_token = client.post(
        "/api/admin/login",
        json={"email": "root@example.com", "password": password},
    ).get_json()["data"]["accessToken"]
    revoke = client.post(
        f"/api/admin/sessions/{operator_session}/revoke",
        headers={"Authorization": f"Bearer {root_token}"},
        json={"reason": "Security review"},
    )
    assert revoke.status_code == 200

    assert client.get(
        "/api/admin/me", headers={"Authorization": f"Bearer {operator_token}"}
    ).status_code == 401
