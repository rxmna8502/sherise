# SheRise Web

This folder is the complete SheRise web application:

- `app.py` — Flask API, authentication, jobs, applications, messaging,
  notifications, DigiLocker, translation, voice/image AI, and subscriptions.
- `frontend_dist/` — the complete built web UI and static assets.
- `requirements.txt` — Python runtime dependencies.
- `instance/` — runtime SQLite database directory; it is created/populated on
  first run and should not be committed with secrets or production data.

## Run locally

```bash
python -m venv .venv
.venv\\Scripts\\activate       # Windows
pip install -r requirements.txt
python app.py
```

The app runs at `http://127.0.0.1:10201` by default. Configure secrets with
environment variables (or a local `.env` file): `GROQ_API_KEY`, SMTP settings,
`JWT_SECRET`, and optional DigiLocker credentials.

The frontend and API are same-origin, so the browser loads the exact existing
SheRise design and all currently implemented web features.

## Phase 2A Admin authentication foundation

Phase 2A adds server-side Admin authentication only. The Admin UI and Admin
business-data APIs are intentionally deferred.

Set an explicit strong `JWT_SECRET` before using Admin authentication. The
existing user JWT secret is not rotated automatically. Create an Admin account
interactively after applying the migration:

```bash
flask --app app db upgrade
flask --app app admin-create
```

The command prompts for the email, role and password; no plaintext password is
stored in the project. Admin access tokens last 15 minutes and refresh sessions
last 7 days. Admin refresh tokens are stored server-side only as hashes.

Admin endpoints currently available:

```text
POST /api/admin/login
POST /api/admin/refresh
POST /api/admin/logout
GET  /api/admin/me
GET  /api/admin/sessions
POST /api/admin/sessions/<session_id>/revoke
```
