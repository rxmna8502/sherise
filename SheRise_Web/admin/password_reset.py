"""Short-lived, rate-limited Admin password reset OTPs.

Reset challenges are intentionally kept in process memory for this local/V1
implementation. OTPs are never stored in plaintext and expire quickly.
"""

from datetime import datetime, timedelta
import hashlib
import secrets
import smtplib
from email.mime.text import MIMEText
import os


RESET_TTL_MINUTES = 10
MAX_ATTEMPTS = 5
_challenges = {}


def _key(email):
    return email.strip().lower()


def issue(email):
    email = _key(email)
    code = f"{secrets.randbelow(1_000_000):06d}"
    _challenges[email] = {
        "digest": hashlib.sha256(code.encode()).hexdigest(),
        "expires_at": datetime.utcnow() + timedelta(minutes=RESET_TTL_MINUTES),
        "attempts": 0,
    }
    return code


def verify(email, code):
    challenge = _challenges.get(_key(email))
    if not challenge or datetime.utcnow() >= challenge["expires_at"]:
        _challenges.pop(_key(email), None)
        return False
    challenge["attempts"] += 1
    valid = secrets.compare_digest(challenge["digest"], hashlib.sha256(str(code).strip().encode()).hexdigest())
    if valid:
        _challenges.pop(_key(email), None)
    elif challenge["attempts"] >= MAX_ATTEMPTS:
        _challenges.pop(_key(email), None)
    return valid


def send_reset_otp(email, code):
    smtp_email = os.environ.get("SMTP_EMAIL", "")
    smtp_password = os.environ.get("SMTP_PASSWORD", "")
    if not smtp_email or not smtp_password:
        raise RuntimeError("SMTP_EMAIL and SMTP_PASSWORD must be configured to send reset OTPs")
    host = os.environ.get("SMTP_HOST", "smtp.gmail.com")
    port = int(os.environ.get("SMTP_PORT", "587"))
    message = MIMEText(
        f"Your SheRise Admin password reset OTP is {code}. It expires in {RESET_TTL_MINUTES} minutes.\n\nIf you did not request this, ignore this email.",
        "plain",
    )
    message["Subject"] = "SheRise Admin password reset OTP"
    message["From"] = smtp_email
    message["To"] = email
    with smtplib.SMTP(host, port, timeout=20) as server:
        server.starttls()
        server.login(smtp_email, smtp_password)
        server.send_message(message)
