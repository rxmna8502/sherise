from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
try:
    from flask_migrate import Migrate
except ImportError:
    Migrate = None
import uuid
import os
import json
import secrets
import base64
import random
import time
import requests as http_requests
import xml.etree.ElementTree as ET
from datetime import datetime
import jwt
from functools import wraps
from datetime import timedelta
from groq import Groq
from dotenv import load_dotenv
import tempfile
from extensions import db

# Load environment variables from .env file
load_dotenv()

# Configure Groq
GROQ_API_KEY = os.environ.get('GROQ_API_KEY')
if GROQ_API_KEY:
    groq_client = Groq(api_key=GROQ_API_KEY)
else:
    groq_client = None

# ─── DigiLocker Configuration ───────────────────────────────────────────────
# Sandbox URLs (switch to production when approved)
DIGILOCKER_BASE       = os.environ.get('DIGILOCKER_BASE', 'https://sandbox.digilocker.gov.in')
DIGILOCKER_CLIENT_ID  = os.environ.get('DIGILOCKER_CLIENT_ID', 'YOUR_CLIENT_ID')
DIGILOCKER_SECRET     = os.environ.get('DIGILOCKER_SECRET', 'YOUR_CLIENT_SECRET')
DIGILOCKER_REDIRECT   = os.environ.get('DIGILOCKER_REDIRECT', 'http://localhost:5175/digilocker-callback')
# ─────────────────────────────────────────────────────────────────────────────

# ─── Email OTP Configuration (Gmail SMTP) ────────────────────────────────────
# To use Gmail SMTP, enable 2-Step Verification on your Google account, then
# create an App Password at: https://myaccount.google.com/apppasswords
# Use that 16-character app password below (NOT your regular Gmail password)
SMTP_EMAIL = os.environ.get('SMTP_EMAIL', '')        # e.g. yourname@gmail.com
SMTP_PASSWORD = os.environ.get('SMTP_PASSWORD', '')   # 16-char app password
SMTP_HOST = os.environ.get('SMTP_HOST', 'smtp.gmail.com')
SMTP_PORT = int(os.environ.get('SMTP_PORT', '587'))
# ─────────────────────────────────────────────────────────────────────────────

# ─── JWT Configuration ────────────────────────────────────────────────────────
# Preserve the existing user JWT signing secret and token format for backward
# compatibility. Admin JWTs additionally require an explicitly configured
# strong JWT_SECRET in admin/auth.py; no automatic rotation happens here.
JWT_SECRET = os.environ.get('JWT_SECRET', 'your-very-strong-random-secret-min-32-characters-long')
JWT_SECRET_CONFIGURED = bool(os.environ.get('JWT_SECRET'))
JWT_SECRET_PREVIOUS = os.environ.get('JWT_SECRET_PREVIOUS')
JWT_EXPIRY_DAYS = 30

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]

        user_id = None
        if token:
            try:
                data = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
                if data.get('token_type') == 'admin':
                    return jsonify({'success': False, 'message': 'User authentication required'}), 403
                user_id = data.get('user_id')
                if not user_id:
                    return jsonify({'success': False, 'message': 'Invalid token'}), 401
            except jwt.ExpiredSignatureError:
                return jsonify({'success': False, 'message': 'Token expired'}), 401
            except jwt.InvalidTokenError:
                return jsonify({'success': False, 'message': 'Invalid token'}), 401
        else:
            # Fallback for Web and Mobile React SPA (which transmits identity via query params / body / headers)
            user_id = (request.headers.get('X-User-Id') or
                       request.args.get('userId') or
                       request.args.get('user_id'))
            if not user_id and request.is_json:
                body = request.get_json(silent=True) or {}
                if isinstance(body, dict):
                    user_id = (body.get('userId') or 
                               body.get('user_id') or 
                               body.get('workerId') or 
                               body.get('creatorId') or 
                               body.get('creator_id') or 
                               body.get('senderId'))

            # Route-level contextual fallbacks if entity ID is provided in URL
            if not user_id:
                n_id = kwargs.get('n_id')
                if n_id:
                    notif_cls = globals().get('Notification')
                    if notif_cls:
                        notif = db.session.get(notif_cls, n_id)
                        if notif:
                            user_id = notif.user_id

            if not user_id:
                app_id = kwargs.get('app_id')
                if app_id:
                    app_cls = globals().get('JobApplication')
                    job_cls = globals().get('Job')
                    if app_cls:
                        application = db.session.get(app_cls, app_id)
                        if application:
                            # If cancel, authenticated as applicant worker; if accept/reject, as job poster
                            if request.path.endswith('/cancel'):
                                user_id = application.worker_id
                            elif job_cls:
                                job = db.session.get(job_cls, application.job_id)
                                if job:
                                    user_id = job.creator_id

            if not user_id:
                job_id = kwargs.get('job_id')
                if job_id:
                    job_cls = globals().get('Job')
                    if job_cls:
                        job = db.session.get(job_cls, job_id)
                        if job and (job.creator_id or job.worker_id):
                            user_id = job.creator_id or job.worker_id

        if not user_id:
            return jsonify({'success': False, 'message': 'Authentication token required'}), 401

        current_user = db.session.get(User, user_id)
        if not current_user:
            return jsonify({'success': False, 'message': 'User not found'}), 401

        if getattr(current_user, 'is_banned', False):
            return jsonify({
                'success': False,
                'message': f'Account suspended: {current_user.ban_reason or "Violation of platform policies. Contact support."}'
            }), 403

        return f(current_user, *args, **kwargs)
    return decorated
# ─────────────────────────────────────────────────────────────────────────────

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email_otp(to_email: str, otp_code: str) -> bool:
    """Send OTP via email using Gmail SMTP. Returns True if sent."""
    if not SMTP_EMAIL or not SMTP_PASSWORD:
        print(f"[OTP] SMTP not configured. Console-only mode.", flush=True)
        print(f"[OTP] OTP for {to_email}: {otp_code}", flush=True)
        return False

    try:
        msg = MIMEMultipart('alternative')
        msg['From'] = f'SheRise <{SMTP_EMAIL}>'
        msg['To'] = to_email
        msg['Subject'] = f'Your SheRise Verification Code: {otp_code}'

        html = f"""
        <div style="font-family: 'Plus Jakarta Sans', Arial, sans-serif; max-width: 480px; margin: 20px auto; padding: 40px; background: #ffffff; border-radius: 24px; border: 1px solid #eef2f6; box-shadow: 0 10px 25px rgba(0,0,0,0.02);">
            <div style="text-align: center; margin-bottom: 32px;">
                <h1 style="color: #0f172a; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.025em;">SheRise</h1>
                <p style="color: #64748b; font-size: 14px; margin-top: 4px; font-weight: 500;">Verification Required</p>
            </div>
            
            <p style="color: #334155; font-size: 16px; line-height: 1.6; margin-bottom: 24px; text-align: center;">
                Your one-time verification code is below.
            </p>
            
            <div style="background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 20px; padding: 32px; text-align: center; margin-bottom: 32px;">
                <span style="font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #0f172a; font-family: monospace;">{otp_code}</span>
            </div>
            
            <p style="color: #94a3b8; font-size: 13px; text-align: center; margin-bottom: 32px;">
                This code expires in 5 minutes.<br>Do not share it with anyone.
            </p>
            
            <div style="border-top: 1px solid #f1f5f9; padding-top: 24px; text-align: center;">
                <p style="color: #cbd5e1; font-size: 12px; font-weight: 600; text-transform: uppercase; tracking-wider: 0.1em; margin: 0;">
                    Feminine Shakthi
                </p>
                <p style="color: #94a3b8; font-size: 11px; margin-top: 4px;">Empowering Women, One Task at a Time</p>
            </div>
        </div>
        """

        msg.attach(MIMEText(html, 'html'))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_EMAIL, SMTP_PASSWORD)
            server.send_message(msg)

        print(f"[OTP] Email sent to {to_email}", flush=True)
        return True
    except Exception as e:
        print(f"[OTP] Email send failed: {e}", flush=True)
        print(f"[OTP] Fallback — OTP for {to_email}: {otp_code}", flush=True)
        return False

# ─── SMS OTP Configuration (Twilio SMS) ──────────────────────────────────────
TWILIO_ACCOUNT_SID  = os.environ.get('TWILIO_ACCOUNT_SID', '')
TWILIO_AUTH_TOKEN   = os.environ.get('TWILIO_AUTH_TOKEN', '')
TWILIO_PHONE_NUMBER = os.environ.get('TWILIO_PHONE_NUMBER', '')

def send_sms_otp(to_phone: str, otp_code: str) -> bool:
    """Send OTP via SMS using Twilio if configured. Returns True if sent."""
    if not (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_PHONE_NUMBER):
        print(f"[OTP-SMS] Twilio not configured. Console-only fallback.", flush=True)
        print(f"[OTP-SMS] OTP for {to_phone}: {otp_code}", flush=True)
        return False
    try:
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        formatted_phone = to_phone if to_phone.startswith('+') else f"+91{to_phone}"
        message = client.messages.create(
            body=f"Your SheRise verification code is: {otp_code}. Valid for 5 minutes. Do not share.",
            from_=TWILIO_PHONE_NUMBER,
            to=formatted_phone
        )
        print(f"[OTP-SMS] SMS dispatched to {formatted_phone}: {message.sid}")
        return True
    except Exception as e:
        print(f"[OTP-SMS] Twilio send failed: {e}")
        return False

def send_sos_sms_alert(phone: str, alert_message: str) -> bool:
    """Dispatch emergency SOS message via SMS if Twilio is configured."""
    print(f"[SOS-DISPATCH] [!] EMERGENCY ALERT for {phone}: {alert_message}".encode('ascii', errors='replace').decode('ascii'), flush=True)
    if not phone or phone == 'Not provided':
        return False
    if not (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_PHONE_NUMBER):
        return False
    try:
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        formatted_phone = phone if phone.startswith('+') else f"+91{phone}"
        client.messages.create(
            body=f"🚨 [SHERISE EMERGENCY SOS] {alert_message}",
            from_=TWILIO_PHONE_NUMBER,
            to=formatted_phone
        )
        return True
    except Exception as e:
        print(f"[SOS-DISPATCH] Twilio send failed: {e}", flush=True)
        return False

# Base directory for resolving paths
basedir = os.path.abspath(os.path.dirname(__file__))

# Point Flask at the built frontend
frontend_dir = os.path.join(basedir, 'frontend_dist')
app = Flask(__name__, static_folder=frontend_dir, static_url_path='')
allowed_origins = [
    origin.strip()
    for origin in os.environ.get('ADMIN_ALLOWED_ORIGINS', '').split(',')
    if origin.strip()
]
# Allow all localhost and 127.0.0.1 ports during local development
allowed_origins.extend([r"^http://localhost:\d+$", r"^http://127\.0\.0\.1:\d+$"])
CORS(app, origins=allowed_origins, supports_credentials=True)

# Clean console: Filter out repetitive static assets (.png, .css, .js) from terminal logs
import logging
class StaticAssetLogFilter(logging.Filter):
    def filter(self, record):
        msg = record.getMessage()
        return not any(ext in msg for ext in ['.png', '.jpg', '.jpeg', '.svg', '.css', '.js', '.ico', '/assets/'])
logging.getLogger('werkzeug').addFilter(StaticAssetLogFilter())

# Configure Database (PostgreSQL for Vercel/Cloud, fallback to SQLite)
database_url = os.environ.get('DATABASE_URL')
if database_url:
    # Handle SQLAlchemy 1.4+ requirement for postgresql://
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
else:
    db_path = os.path.join(basedir, 'instance', 'shakthi_v6.db')
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)
migrate = Migrate(app, db) if Migrate else None

# In-memory OTP store: { phone_or_email: { 'otp': '123456', 'expires': timestamp } }
otp_store = {}

# Models
class User(db.Model):
    __tablename__ = 'user'
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    phone = db.Column(db.String(20))
    address = db.Column(db.String(200))
    aadhaarLast4 = db.Column(db.String(4))
    aadhaar_verified = db.Column(db.Boolean, default=False)
    gender = db.Column(db.String(10))
    credits = db.Column(db.Integer, default=0)
    rating = db.Column(db.Float, default=0.0)
    reviewCount = db.Column(db.Integer, default=0)
    isVerified = db.Column(db.Boolean, default=True)
    availability = db.Column(db.String(100))
    skills_str = db.Column(db.String(500), default="[]")
    portfolio_str = db.Column(db.String(10000), default="[]")
    last_seen = db.Column(db.DateTime, nullable=True)
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    is_banned = db.Column(db.Boolean, default=False)
    ban_reason = db.Column(db.String(255), nullable=True)

    def to_dict(self):
        skills = []
        try:
            if self.skills_str:
                s = self.skills_str.replace("'", '"')
                if "[" in s:
                    skills = json.loads(s)
        except:
             skills = []

        # Check if online (active in last 2 minutes)
        is_online = False
        if self.last_seen:
            time_diff = (datetime.now() - self.last_seen).total_seconds()
            is_online = time_diff < 120  # 2 minutes

        # Populate dynamic workHistory from completed jobs
        work_history_list = []
        try:
            completed_jobs = Job.query.filter_by(worker_id=self.id, status='completed').all()
            for j in completed_jobs:
                work_history_list.append({
                    'id': j.id,
                    'title': j.title,
                    'description': j.description,
                    'status': j.status,
                    'date': j.postedAt,
                    'amount': j.max_amount,
                    'rating': j.rating,
                    'review': j.review,
                    'customerName': j.customerName
                })
        except Exception as e:
            print(f"Error fetching work history: {e}")

        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'phone': self.phone,
            'address': self.address,
            'aadhaarLast4': self.aadhaarLast4,
            'gender': self.gender,
            'credits': self.credits,
            'rating': round(self.rating, 1),
            'reviewCount': self.reviewCount,
            'isVerified': self.isVerified,
            'aadhaarVerified': self.aadhaar_verified or False,
            'availability': self.availability,
            'skills': skills,
            'portfolio': json.loads(self.portfolio_str) if self.portfolio_str else [],
            'workHistory': work_history_list,
            'radius': 5,
            'isOnline': is_online,
            'lastSeen': self.last_seen.isoformat() if self.last_seen else None,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'isBanned': bool(self.is_banned) if hasattr(self, 'is_banned') and self.is_banned is not None else False,
            'banReason': self.ban_reason if hasattr(self, 'ban_reason') else None
        }

class Job(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    title = db.Column(db.String(100))
    description = db.Column(db.String(500))
    category = db.Column(db.String(50))
    min_amount = db.Column(db.Integer)
    max_amount = db.Column(db.Integer)
    location = db.Column(db.String(100))
    deliveryType = db.Column(db.String(20))
    urgency = db.Column(db.String(20))
    customerName = db.Column(db.String(100))
    customerRating = db.Column(db.Float)
    postedAt = db.Column(db.String(50))
    status = db.Column(db.String(20), default='open') 
    paymentMode = db.Column(db.String(50), default='online') # online (escrow) or cod
    worker_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=True)
    creator_id = db.Column(db.String(36), nullable=True) 
    rating = db.Column(db.Float, nullable=True)
    review = db.Column(db.String(500), nullable=True)

    def to_dict(self):
        worker = User.query.get(self.worker_id) if self.worker_id else None
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'category': self.category,
            'amount': {'min': self.min_amount, 'max': self.max_amount},
            'location': self.location,
            'deliveryType': self.deliveryType,
            'urgency': self.urgency,
            'paymentMode': self.paymentMode,
            'customerName': self.customerName,
            'customerRating': self.customerRating,
            'postedAt': self.postedAt,
            'status': self.status,
            'creator_id': self.creator_id,
            'worker_id': self.worker_id,
            'workerName': worker.name if worker else None
        }

class JobApplication(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    job_id = db.Column(db.String(36), db.ForeignKey('job.id'), nullable=False)
    worker_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False)
    status = db.Column(db.String(20), default='pending') # pending, accepted, rejected
    timestamp = db.Column(db.String(50))

    worker = db.relationship('User', backref='applications')
    job = db.relationship('Job', backref='applications')

    def to_dict(self):
        return {
            'id': self.id,
            'jobId': self.job_id,
            'workerId': self.worker_id,
            'status': self.status,
            'timestamp': self.timestamp,
            'workerName': self.worker.name,
            'workerRating': self.worker.rating,
            'jobTitle': self.job.title
        }


class Message(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    job_id = db.Column(db.String(36), db.ForeignKey('job.id'), nullable=False)
    sender_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False)
    content = db.Column(db.String(1000), nullable=True)
    timestamp = db.Column(db.String(50))
    read = db.Column(db.Boolean, default=False)
    
    sender = db.relationship('User', backref='messages')

    def to_dict(self):
        return {
            'id': self.id,
            'jobId': self.job_id,
            'senderId': self.sender_id,
            'senderName': self.sender.name if self.sender else 'System',
            'content': self.content,
            'timestamp': self.timestamp,
            'read': self.read
        }

@app.before_request
def update_last_seen():
    """Update user's last_seen timestamp on every request"""
    try:
        # Never trust senderId/userId/workerId from a request to update another
        # user's presence. Only a valid normal-user JWT can update last_seen.
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return
        claims = jwt.decode(auth_header[7:].strip(), JWT_SECRET, algorithms=['HS256'])
        if claims.get('token_type') == 'admin':
            return
        user_id = claims.get('user_id')
        if user_id:
            user = User.query.get(user_id)
            if user:
                user.last_seen = datetime.now()
                db.session.commit()
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return
    except Exception:
        pass  # Presence updates must never block a request.

def log_activity(event_type: str, entity_type: str = None, entity_id: str = None, actor_user_id: str = None, metadata: dict = None):
    """Record an operational activity event for administrative audit and monitoring."""
    try:
        from admin.models import ActivityLog
        import hashlib
        ip = request.remote_addr or '127.0.0.1'
        ip_hash = hashlib.sha256(ip.encode('utf-8')).hexdigest()[:64]
        log_entry = ActivityLog(
            id=str(uuid.uuid4()),
            actor_user_id=actor_user_id,
            event_type=event_type,
            entity_type=entity_type,
            entity_id=entity_id,
            metadata_json=json.dumps(metadata) if metadata else None,
            created_at=datetime.utcnow(),
            ip_hash=ip_hash,
        )
        db.session.add(log_entry)
        db.session.commit()
    except Exception as e:
        print(f"[ActivityLog] Error logging activity {event_type}: {e}")
        try:
            db.session.rollback()
        except Exception:
            pass

@app.route('/api/messages/<job_id>', methods=['GET'])
@token_required
def get_messages(current_user, job_id):
    job = Job.query.get(job_id)
    if not job:
        return jsonify({'success': False, 'message': 'Job not found'}), 404
    is_applicant = JobApplication.query.filter_by(
        job_id=job_id, worker_id=current_user.id
    ).first() is not None
    if current_user.id not in {job.creator_id, job.worker_id} and not is_applicant:
        return jsonify({'success': False, 'message': 'You are not a participant in this job'}), 403
    messages = Message.query.filter_by(job_id=job_id).order_by(Message.timestamp.asc()).all()
    return jsonify([msg.to_dict() for msg in messages])

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok'})

@app.route('/api/messages', methods=['POST'])
@token_required
def send_message(current_user=None):
    data = request.json
    try:
        sender_id = current_user.id
        job_id = data.get('jobId')
        job = Job.query.get(job_id)
        if not job:
            return jsonify({'success': False, 'message': 'Job not found'}), 404
        is_applicant = JobApplication.query.filter_by(
            job_id=job_id, worker_id=current_user.id
        ).first() is not None
        if current_user.id not in {job.creator_id, job.worker_id} and not is_applicant:
            return jsonify({'success': False, 'message': 'You are not a participant in this job'}), 403
        sender = current_user

        new_msg = Message(
            id=str(uuid.uuid4()),
            job_id=job_id,
            sender_id=sender_id,
            content=data.get('content'),
            timestamp=datetime.now().strftime("%I:%M %p"),
            read=False
        )
        db.session.add(new_msg)
        db.session.commit()
        
        # Create notification for recipient
        # Determine recipient: if sender is job creator, notify worker; else notify creator
        if job:
            recipient_id = None
            if sender_id == job.creator_id:
                # Sender is job creator, notify worker
                recipient_id = job.worker_id
            else:
                # Sender is worker/applicant, notify job creator
                recipient_id = job.creator_id
            
            if recipient_id:
                sender_name = sender.name if sender else 'Someone'
                notification = Notification(
                    id=str(uuid.uuid4()),
                    user_id=recipient_id,
                    type='message',
                    message=f'New message from {sender_name}',
                    timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    related_id=job_id,
                    read=False
                )
                db.session.add(notification)
                db.session.commit()
        
        return jsonify({'success': True, 'message': new_msg.to_dict()})
    except Exception as e:
        app.logger.exception("Error sending message")
        return jsonify({'success': False, 'message': 'Unable to send message'}), 500

@app.route('/api/messages/<job_id>/mark-read', methods=['POST'])
@token_required
def mark_messages_read(current_user, job_id):
    """Mark all messages in a job as read for the current user"""
    try:
        user_id = current_user.id
        job = Job.query.get(job_id)
        is_applicant = JobApplication.query.filter_by(
            job_id=job_id, worker_id=user_id
        ).first() is not None
        if not job:
            return jsonify({'success': False, 'message': 'Job not found'}), 404
        if user_id not in {job.creator_id, job.worker_id} and not is_applicant:
            return jsonify({'success': False, 'message': 'You are not a participant in this job'}), 403
        
        # Mark all messages in this job that were sent TO this user as read
        messages = Message.query.filter_by(job_id=job_id).filter(Message.sender_id != user_id).all()
        for msg in messages:
            msg.read = True
        db.session.commit()
        
        return jsonify({'success': True})
    except Exception as e:
        app.logger.exception("Error marking messages read")
        return jsonify({'success': False, 'message': 'Unable to update messages'}), 500

@app.route('/api/users/me', methods=['GET'])
@token_required
def get_user_profile(current_user):
    """Get full profile info for the authenticated user"""
    user = current_user
    if not user:
        # Auto-heal ghost session
        if user_id and user_id != "undefined":
            user = User(
                id=user_id,
                name=f'Deleted User ({user_id[:4]})',
                email=f'recovered_{user_id[-8:]}@example.com',
                phone='',
                credits=0,
                rating=5.0,
                reviewCount=0,
                isVerified=True,
                skills_str="[]"
            )
            db.session.add(user)
            try:
                db.session.commit()
            except Exception as e:
                db.session.rollback()
                return jsonify({'success': False, 'message': 'User not found'}), 404
        else:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
    # Deep recovery: Restore actual signed-in name from surviving job artifacts if they have a ghost name
    if user.name.startswith(('Deleted User', 'Recovered User', 'Recovered Sender')):
        surviving_job = Job.query.filter_by(creator_id=user.id).first()
        if surviving_job and surviving_job.customerName:
            user.name = surviving_job.customerName
            db.session.commit()
            
    return jsonify({'success': True, 'user': user.to_dict()})

@app.route('/api/users/me/status', methods=['GET'])
@token_required
def get_user_status(current_user):
    """Get authenticated user's online status"""
    user = current_user
    if not user:
        return jsonify({'success': False}), 404
    return jsonify({'success': True, 'user': user.to_dict()})

@app.route('/api/notifications', methods=['GET'])
@token_required
def get_notifications(current_user):
    """Get notifications for the authenticated user"""
    user_id = current_user.id
    notifications = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc()).all()
    return jsonify([n.to_dict() for n in notifications])

@app.route('/api/notifications/count', methods=['GET'])
@token_required
def get_notification_count(current_user):
    user_id = current_user.id
    count = Notification.query.filter_by(user_id=user_id, read=False).count()
    return jsonify({'count': count})

class Notification(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False)
    type = db.Column(db.String(50)) # request, accept, reject, message, info
    message = db.Column(db.String(500))
    timestamp = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.now, nullable=False)
    related_id = db.Column(db.String(36), nullable=True) # e.g. job_id
    read = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            'id': self.id,
            'userId': self.user_id,
            'type': self.type,
            'message': self.message,
            'timestamp': self.timestamp or (self.created_at.strftime("%Y-%m-%d %I:%M %p") if self.created_at else ""),
            'relatedId': self.related_id,
            'read': self.read
        }

# Initialize Database
def init_db():
    with app.app_context():
        db.create_all()
        # Dummy data removed as per user request

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    phone = data.get('phone')
    name = data.get('name', '').strip()

    # Look up user by phone or email
    user = None
    if phone:
        user = User.query.filter_by(phone=phone).first()
    if not user and email:
        email = email.lower().strip()
        user = User.query.filter_by(email=email).first()

    if not user:
        return jsonify({'success': False, 'message': 'User not found. Please register first.'})

    if getattr(user, 'is_banned', False):
        return jsonify({'success': False, 'message': f'Account suspended: {user.ban_reason or "Violation of platform policies. Contact support."}'}), 403

    # Verify that the provided name matches the stored name
    if not name:
        return jsonify({'success': False, 'message': 'Please enter your full name.'})
    if name.lower() != user.name.lower():
        return jsonify({'success': False, 'message': 'Name does not match our records. Please enter the name you registered with.'})

    token = jwt.encode(
        {'user_id': user.id, 'exp': datetime.utcnow() + timedelta(days=JWT_EXPIRY_DAYS)},
        JWT_SECRET,
        algorithm='HS256'
    )
    
    log_activity('user_login', 'user', user.id, user.id, {'name': user.name, 'email': user.email})
    return jsonify({'success': True, 'token': token, 'user': user.to_dict()})

@app.route('/api/send-otp', methods=['POST'])
def send_otp():
    """Send OTP for login or registration."""
    try:
        data = request.json
        if not data:
            return jsonify({'success': False, 'message': 'No data provided.'}), 400
            
        email = data.get('email', '').lower().strip()
        phone = data.get('phone', '').strip()

        if not email and not phone:
            return jsonify({'success': False, 'message': 'Email or phone is required to send OTP.'}), 400

        # Generate a random 6-digit OTP
        generated_otp = str(random.randint(100000, 999999))

        otp_data = {
            'otp': generated_otp,
            'expires': time.time() + 300
        }
        if email:
            otp_store[email] = otp_data
        if phone:
            otp_store[phone] = otp_data

        # Send OTP via email and SMS if provided
        email_sent = send_email_otp(email, generated_otp) if email else False
        sms_sent = send_sms_otp(phone, generated_otp) if phone else False

        res = {
            'success': True,
            'message': 'OTP sent to your email and phone!' if (email_sent or sms_sent) else f'OTP generated: {generated_otp} (Check console)',
            'email_sent': email_sent,
            'sms_sent': sms_sent
        }
        if not email_sent:
            res['dev_otp'] = generated_otp
        return jsonify(res)
    except Exception as e:
        app.logger.exception("Error in send_otp")
        return jsonify({'success': False, 'message': 'Server error. Please try again later.'}), 500


@app.route('/api/send-otp-register', methods=['POST'])
def send_otp_register():
    """Send OTP for REGISTRATION."""
    data = request.json or {}
    email = data.get('email', '').lower().strip()
    phone = data.get('phone', '').strip()

    if not email and not phone:
        return jsonify({'success': False, 'message': 'Email or phone is required to send OTP.'}), 400

    # Generate a random 6-digit OTP
    generated_otp = str(random.randint(100000, 999999))

    otp_data = {
        'otp': generated_otp,
        'expires': time.time() + 300
    }
    if email:
        otp_store[email] = otp_data
    if phone:
        otp_store[phone] = otp_data

    # Send OTP via email and SMS if provided
    email_sent = send_email_otp(email, generated_otp) if email else False
    sms_sent = send_sms_otp(phone, generated_otp) if phone else False

    res = {
        'success': True,
        'message': 'OTP sent to your email and phone!' if (email_sent or sms_sent) else f'OTP generated: {generated_otp} (Check console)',
        'email_sent': email_sent,
        'sms_sent': sms_sent
    }
    if not email_sent:
        res['dev_otp'] = generated_otp
    return jsonify(res)

@app.route('/api/verify-otp', methods=['POST'])
def verify_otp():
    data = request.json or {}
    phone = data.get('phone', '').strip() if data.get('phone') else None
    email = data.get('email', '').lower().strip() if data.get('email') else None
    otp = str(data.get('otp', '')).strip()
    identifier = email or phone

    print(f"[OTP-VERIFY] Attempting verification for email={email}, phone={phone}, otp={otp}", flush=True)

    if not identifier or not otp:
        print("[OTP-VERIFY] Failed: Missing identifier or OTP", flush=True)
        return jsonify({'success': False, 'message': 'Phone/email and OTP are required.'}), 400

    # Look up OTP under identifier, email, phone, or phone digit variants
    stored = None
    keys_to_check = [identifier, email, phone]
    if phone:
        digits_only = ''.join(c for c in phone if c.isdigit())
        keys_to_check.extend([digits_only, f"+{digits_only}", f"+91{digits_only[-10:]}", digits_only[-10:]])
    for k in keys_to_check:
        if k and k in otp_store:
            stored = otp_store[k]
            break

    # Allow master test OTP in development mode
    is_dev = os.environ.get('APP_ENV', 'development').lower() == 'development'
    is_master_otp = is_dev and otp in {'123456', '000000'}

    if not stored and not is_master_otp:
        print(f"[OTP-VERIFY] Failed: No OTP found in store for {keys_to_check}", flush=True)
        return jsonify({'success': False, 'message': 'OTP not found. Please request a new one.'}), 400

    if stored and time.time() > stored['expires'] and not is_master_otp:
        print(f"[OTP-VERIFY] Failed: OTP expired for {identifier}", flush=True)
        return jsonify({'success': False, 'message': 'OTP has expired. Please request a new one.'}), 400

    if not is_master_otp and (not stored or str(stored['otp']).strip() != otp):
        expected_otp = stored.get('otp') if stored else None
        print(f"[OTP-VERIFY] Failed: Invalid OTP for {identifier}. Expected {expected_otp}, got {otp}", flush=True)
        return jsonify({'success': False, 'message': 'Invalid OTP. Please try again.'}), 400

    print(f"[OTP-VERIFY] SUCCESS for {identifier}!", flush=True)

    # Clear OTP after successful verification to prevent replay
    for k in keys_to_check:
        if k:
            otp_store.pop(k, None)

    user = User.query.filter_by(email=email).first() if email else None
    if not user and phone:
        user = User.query.filter_by(phone=phone).first()

    if user and getattr(user, 'is_banned', False):
        return jsonify({'success': False, 'message': f'Account suspended: {user.ban_reason or "Violation of platform policies. Contact support."}'}), 403

    if not user:
        # Automatically provision user on OTP verification for registration
        name = data.get('name') or (email.split('@')[0].replace('.', ' ').title() if email else 'SheRise Member')
        user = User(
            id=str(uuid.uuid4()),
            name=name,
            email=email if email else None,
            phone=phone if phone else None,
            address=data.get('address', ''),
            aadhaarLast4='',
            gender=data.get('gender', 'Female'),
            credits=100,
            rating=5.0,
            reviewCount=1,
            isVerified=True,
            availability='Flexible',
            skills_str="[]",
            latitude=None,
            longitude=None
        )
        db.session.add(user)
        db.session.commit()
        log_activity('user_registered', 'user', user.id, user.id, {'name': user.name, 'email': user.email})

    token = jwt.encode(
        {'user_id': user.id, 'exp': datetime.utcnow() + timedelta(days=JWT_EXPIRY_DAYS)},
        JWT_SECRET,
        algorithm='HS256'
    )
    
    return jsonify({
        'success': True,
        'message': 'OTP verified successfully.',
        'token': token,
        'user': user.to_dict()
    })

@app.route('/api/register', methods=['POST'])
def register():
    try:
        data = request.json
        phone = data.get('phone')

        if not phone:
            return jsonify({'success': False, 'message': 'Phone number is required.'}), 400

        if User.query.filter_by(email=data.get('email')).first():
            return jsonify({'success': False, 'message': 'Email already registered'})

        if User.query.filter_by(phone=phone).first():
            return jsonify({'success': False, 'message': 'Phone number already registered'})

        location = data.get('location') or {}
        new_user = User(
            id=str(uuid.uuid4()),
            name=data.get('name'),
            email=data.get('email').lower().strip() if data.get('email') else None,
            phone=phone,
            address=data.get('address'),
            aadhaarLast4=data.get('aadhaarLast4'),
            gender=data.get('gender'),
            credits=0,
            rating=0.0,
            reviewCount=0,
            isVerified=True,
            availability='Flexible',
            skills_str="[]",
            latitude=location.get('lat'),
            longitude=location.get('lng')
        )
        db.session.add(new_user)
        db.session.commit()
        log_activity('user_registered', 'user', new_user.id, new_user.id, {'name': new_user.name, 'email': new_user.email})
        
        return jsonify({'success': True, 'user': new_user.to_dict()})
    except Exception as e:
        app.logger.exception("Registration error")
        return jsonify({'success': False, 'message': 'Server error. Please try again later.'}), 500

@app.route('/api/users/me/location', methods=['POST'])
@token_required
def update_user_location(current_user):
    """Update a user's lat/lng and last_seen. Called by Near Me page."""
    try:
        data = request.json
        # Use authenticated user id
        user_id = current_user.id
        lat = data.get('latitude')
        lng = data.get('longitude')
        if not user_id:
            return jsonify({'success': False, 'message': 'userId required'}), 400
        user = User.query.get(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        if lat is not None and lng is not None:
            user.latitude = float(lat)
            user.longitude = float(lng)
        user.last_seen = datetime.now()
        db.session.commit()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/workers/nearby', methods=['GET'])
@token_required
def get_nearby_workers(current_user):
    """Return all users except the requesting user, with role info (giver/seeker)."""
    exclude_id = current_user.id
    users = User.query.all()
    result = []
    for u in users:
        if exclude_id and u.id == exclude_id:
            continue
        d = u.to_dict()
        jobs_posted = Job.query.filter_by(creator_id=u.id).count()
        jobs_applied = JobApplication.query.filter_by(worker_id=u.id).count()
        d['jobsPosted'] = jobs_posted
        d['jobsApplied'] = jobs_applied
        result.append(d)
    return jsonify({'success': True, 'workers': result})

@app.route('/api/jobs', methods=['GET'])
def get_jobs():
    # Fetch both open and on_hold jobs so users can see the status
    jobs = Job.query.filter(Job.status.in_(['open', 'on_hold'])).all()
    # Also check if current user has applied? (Frontend handles this by fetching applications)
    return jsonify([job.to_dict() for job in jobs])

# AI Matching Algorithm
def calculate_skill_match(user_skills, job_category):
    """
    Calculate skill match score between user skills and job category
    Returns a score from 0-100
    """
    if not user_skills or not job_category:
        return 0
    
    # Skill to category mapping
    skill_category_map = {
        'Stitching & Tailoring': ['Tailoring', 'Handicrafts'],
        'Handicrafts': ['Handicrafts', 'Creative Work'],
        'Tutoring & Education': ['Education', 'Office Work'],
        'Beauty Services': ['Beauty & Wellness'],
        'Elderly Care': ['Caregiving'],
        'Data Entry': ['Office Work', 'Digital Services'],
        'Content Writing': ['Creative Work', 'Digital Services', 'Office Work'],
        'Graphic Design': ['Creative Work', 'Digital Services'],
        'Social Media Management': ['Digital Services', 'Creative Work']
    }
    
    max_score = 0
    
    # Simple direct matching or partial string matching
    for skill in user_skills:
        skill_lower = skill.lower()
        cat_lower = job_category.lower()
        if skill_lower in cat_lower or cat_lower in skill_lower:
            max_score = max(max_score, 100)
        elif skill in skill_category_map:
            matching_categories = skill_category_map[skill]
            if job_category in matching_categories:
                max_score = max(max_score, 90)
            elif any(cat.lower() in cat_lower or cat_lower in cat.lower() for cat in matching_categories):
                max_score = max(max_score, 70)
                
    # If no direct match, still give a baseline score so Gemini/Groq can evaluate it
    if max_score == 0:
        max_score = 30
    
    return max_score

def calculate_location_match(user_location, job_location):
    """
    Simple location matching based on city names
    Returns True if locations match or are nearby
    """
    if not user_location or not job_location:
        return True  # If no location specified, don't filter
    
    user_loc = user_location.lower().strip()
    job_loc = job_location.lower().strip()
    
    # Exact match
    if user_loc == job_loc:
        return True
    
    # Check if one contains the other (e.g., "Hyderabad" in "Hyderabad, Telangana")
    if user_loc in job_loc or job_loc in user_loc:
        return True
    
    return False

@app.route('/api/jobs/recommended', methods=['GET'])
def get_recommended_jobs():
    """
    Get AI-recommended jobs based on user skills and location
    """
    user_id = request.args.get('userId')
    
    if not user_id:
        return jsonify({'success': False, 'message': 'User ID required'}), 400
    
    user = User.query.get(user_id)
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    # Get user skills
    user_skills = []
    try:
        if user.skills_str:
            # Handle both JSON array string and Python list string representation
            import ast
            try:
                # Try safe eval first for strings like "['cooking']"
                parsed = ast.literal_eval(user.skills_str)
                if isinstance(parsed, list):
                    user_skills = parsed
            except:
                # Fallback to JSON load
                s = user.skills_str.replace("'", '"')
                if "[" in s:
                    user_skills = json.loads(s)
    except Exception as e:
        print(f"Error parsing skills: {e}")
        user_skills = []
    
    # Get all open jobs
    all_jobs = Job.query.filter(Job.status.in_(['open', 'on_hold'])).all()
    
    # Filter and score jobs
    recommended_jobs = []
    for job in all_jobs:
        # Skip jobs created by the user
        if job.creator_id == user_id:
            continue
        
        # Calculate skill match
        skill_score = calculate_skill_match(user_skills, job.category)
        
        # Calculate location match
        location_match = calculate_location_match(user.address, job.location)
        
        # Only include jobs with skill match > 30% or if user has no skills set
        if skill_score >= 30 or len(user_skills) == 0:
            if location_match:
                job_dict = job.to_dict()
                job_dict['matchScore'] = skill_score
                recommended_jobs.append(job_dict)
    
    # Sort by match score (highest first)
    recommended_jobs.sort(key=lambda x: x['matchScore'], reverse=True)
    
    # AI Job Matcher Enhancement
    # If Groq is configured and we have recommended jobs, ask AI to pick the top 3 and explain why
    if groq_client and recommended_jobs and user_skills:
        try:
            # Prepare data snippet for AI
            jobs_data = []
            for j in recommended_jobs[:10]: # Check top 10
                jobs_data.append({
                    "id": j['id'],
                    "title": j['title'],
                    "category": j['category'],
                    "description": j['description'],
                    "deliveryType": j['deliveryType']
                })
                
            prompt = f"""
            You are an AI assistant matching homemakers in India to flexible work opportunities.
            The user has these skills: {', '.join(user_skills)}.
            Here are some available jobs:
            {json.dumps(jobs_data)}
            
            Select the top 3 best matching jobs for her. For each selected job, provide an encouraging 1-sentence explanation of why it's a great fit for her specific skills.
            If she has relevant skills for 'onlineWork' or 'deliveryHome', prioritize those as they help women who cannot leave home easily.
            
            Return ONLY a valid JSON array of objects with 'id' and 'ai_explanation' keys.
            Example: [{{"id": "job123", "ai_explanation": "Since you know tailoring, stitching this blouse from home is a perfect fit!"}}]
            """
            
            chat_completion = groq_client.chat.completions.create(
                messages=[
                    {
                        "role": "user",
                        "content": prompt,
                    }
                ],
                model="llama-3.3-70b-versatile",
            )
            
            text = chat_completion.choices[0].message.content.strip()
            if text.startswith('```json'): text = text[7:-3].strip()
            elif text.startswith('```'): text = text[3:-3].strip()
            
            ai_matches = json.loads(text)
            ai_match_dict = {item['id']: item.get('ai_explanation', '') for item in ai_matches if 'id' in item}
            
            # Reorder recommended_jobs to put AI top 3 first, and add the explanation
            ai_top_jobs = []
            other_jobs = []
            
            for j in recommended_jobs:
                if j['id'] in ai_match_dict:
                    j['aiRecommendation'] = ai_match_dict[j['id']]
                    # Boost AI picked jobs to top
                    j['matchScore'] = max(j['matchScore'], 95) 
                    ai_top_jobs.append(j)
                else:
                    other_jobs.append(j)
            
            recommended_jobs = ai_top_jobs + other_jobs
            
        except Exception as e:
            print(f"AI Matcher Error: {e}")
            # Silently fallback to standard matching

    return jsonify(recommended_jobs)


@app.route('/api/refresh-token', methods=['POST'])
def refresh_token():
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'success': False, 'message': 'Token required'}), 401
    try:
        old_token = auth_header.split(' ')[1]
        data = jwt.decode(old_token, JWT_SECRET, algorithms=['HS256'], options={'verify_exp': False})
        user = User.query.get(data['user_id'])
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 401
        new_token = jwt.encode(
            {'user_id': user.id, 'exp': datetime.utcnow() + timedelta(days=JWT_EXPIRY_DAYS)},
            JWT_SECRET,
            algorithm='HS256'
        )
        return jsonify({'success': True, 'token': new_token})
    except Exception as e:
        return jsonify({'success': False, 'message': 'Invalid token'}), 401


@app.route('/api/skills/trending', methods=['GET'])
def get_trending_skills():
    """Fetch unique skills/categories from job postings that are NOT in the preset list.
    This discovers new skills organically from what people are posting."""
    try:
        preset_skills = {
            'stitching', 'tailoring', 'cooking', 'pickles', 'snacks', 'kidcare',
            'storytelling', 'tuition', 'dataentry', 'contentwriting', 'graphicdesign',
            'handicrafts', 'cleaning'
        }
        preset_categories = {
            'stitching & tailoring', 'cooking & catering', 'pickles & snacks',
            'baby & kid care', 'storytelling & education', 'data entry & online',
            'handicrafts & arts', 'cleaning & housekeeping'
        }

        # Get all unique categories from jobs
        jobs = Job.query.with_entities(Job.category).distinct().all()
        job_categories = set()
        for (cat,) in jobs:
            if cat:
                job_categories.add(cat.strip())

        # Get all unique custom skills from users
        users = User.query.with_entities(User.skills_str).all()
        user_skills = set()
        for (skills_str,) in users:
            if skills_str:
                try:
                    parsed = json.loads(skills_str.replace("'", '"'))
                    if isinstance(parsed, list):
                        for s in parsed:
                            user_skills.add(str(s).strip().lower())
                except:
                    pass

        # Find new skills not in presets
        new_skills = set()
        for cat in job_categories:
            cat_lower = cat.lower().strip()
            if cat_lower not in preset_categories and cat_lower not in preset_skills:
                # Convert category to a skill-like ID
                skill_id = cat_lower.replace(' & ', '_').replace(' ', '_').replace('&', '_')
                new_skills.add(skill_id)

        for skill in user_skills:
            if skill not in preset_skills:
                new_skills.add(skill)

        return jsonify({
            'success': True,
            'skills': sorted(list(new_skills))
        })

    except Exception as e:
        print(f"Trending skills error: {e}")
        return jsonify({'success': True, 'skills': []})


@app.route('/api/users/extract-skills', methods=['POST'])
def extract_skills():
    data = request.json
    description = data.get('description', '')
    
    if not description:
        return jsonify({'success': False, 'message': 'Description is required'}), 400
        
    try:
        # If API key is not configured, return a mocked smart response
        if not groq_client:
            print("No GROQ_API_KEY found, returning mocked skills")
            # Mock logic based on keywords for demo purposes when no API key is provided
            mock_skills = []
            desc_lower = description.lower()
            if 'stitch' in desc_lower or 'tailor' in desc_lower or 'clothes' in desc_lower or 'blouse' in desc_lower:
                mock_skills.extend(['stitching', 'tailoring'])
            if 'cook' in desc_lower or 'food' in desc_lower or 'pickle' in desc_lower or 'meal' in desc_lower:
                mock_skills.extend(['cooking', 'pickles'])
            if 'baby' in desc_lower or 'child' in desc_lower or 'kids' in desc_lower:
                mock_skills.extend(['kidcare'])
            if 'clean' in desc_lower or 'house' in desc_lower:
                mock_skills.extend(['cleaning'])
            if 'teach' in desc_lower or 'tutor' in desc_lower or 'math' in desc_lower:
                mock_skills.extend(['tuition'])
            if 'write' in desc_lower or 'type' in desc_lower or 'data' in desc_lower:
                mock_skills.extend(['dataentry'])
                
            if not mock_skills:
                mock_skills = ['handicrafts'] # Default safe fallback
                
            return jsonify({
                'success': True, 
                'skills': list(set(mock_skills)),
                'message': 'Skills extracted successfully (Mocked)'
            })

        # Use Groq to extract skills
        prompt = f"""
        Extract professional skills from the following description provided by a homemaker looking for flexible work.
        Map her description to these predefined skill IDs if possible: 
        [stitching, tailoring, cooking, pickles, snacks, kidcare, storytelling, dataentry, handicrafts, cleaning, tuition, contentwriting, graphicdesign, resume]
        
        If she mentions something else that isn't on the list, create a new concise 1-word skill tag for it (e.g., 'embroidery', 'baking', 'knitting').
        
        Return ONLY a valid JSON array of string tags, nothing else. Do not include markdown formatting. Example: ["cooking", "pickles", "baking"]
        
        Description: "{description}"
        """
        
        chat_completion = groq_client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
            model="llama-3.3-70b-versatile",
        )
        
        text = chat_completion.choices[0].message.content.strip()
        
        # Clean up the markdown code blocks if present
        if text.startswith('```json'):
            text = text[7:-3].strip()
        elif text.startswith('```'):
            text = text[3:-3].strip()
            
        try:
            skills_list = json.loads(text)
            # Format the list to be safe lowercased strings
            skills_list = [str(s).lower().replace(' ', '') for s in skills_list]
        except json.JSONDecodeError:
            # Fallback if AI didn't return proper JSON
            print(f"Failed to parse AI response as JSON: {text}")
            skills_list = ['handicrafts']
        
        return jsonify({
            'success': True,
            'skills': skills_list,
            'message': 'Skills extracted successfully via AI'
        })
        
    except Exception as e:
        print(f"Error extracting skills: {e}")
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/jobs/<job_id>/apply', methods=['POST'])
@token_required
def apply_job(current_user, job_id):
    data = request.json
    # The authenticated identity is authoritative; workerId in the request is
    # ignored so one user cannot apply as another user.
    worker_id = current_user.id
    
    if not worker_id:
        return jsonify({'success': False, 'message': 'Worker ID required'}), 400
    
    try:
        job = Job.query.get(job_id)
        if not job:
            return jsonify({'success': False, 'message': 'Job not found'}), 404
            
        if job.status != 'open':
            return jsonify({'success': False, 'message': 'Job no longer open'}), 400

        # Check existence
        existing = JobApplication.query.filter_by(job_id=job_id, worker_id=worker_id).first()
        if existing:
            return jsonify({'success': False, 'message': 'Already applied'}), 400

        # The authenticated user must already exist; do not create users from
        # client-supplied identifiers.
        worker = User.query.get(worker_id)
        if not worker:
            return jsonify({'success': False, 'message': 'Authenticated user not found'}), 401

        job_application = JobApplication(
            id=str(uuid.uuid4()),
            job_id=job_id,
            worker_id=worker_id,
            status='pending',
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M")
        )
        db.session.add(job_application)
        db.session.flush()
        
        # Notify Customer via Chat
        worker = User.query.get(worker_id)
        worker_name = worker.name if worker else "A Worker"
        msg = Message(
            id=str(uuid.uuid4()),
            job_id=job_id,
            sender_id=worker_id,
            content=f"EXT_SYSTEM: {worker_name} has requested to work on the task: {job.title}",
            timestamp=datetime.now().strftime("%I:%M %p"),
            read=False
        )
        db.session.add(msg)
        
        # Send Notification to Creator
        if job.creator_id:
            notif = Notification(
                id=str(uuid.uuid4()),
                user_id=job.creator_id,
                type='request',
                message=f"{worker_name} requested to work on '{job.title}'",
                timestamp=datetime.now().strftime("%Y-%m-%d %I:%M %p"),
                related_id=job_id,
                read=False
            )
            db.session.add(notif)
        
        # User Request: "if one worker request... make it hold"
        job.status = 'on_hold'
        db.session.commit()
        log_activity('job_applied', 'application', job_application.id, current_user.id, {'job_id': job_id, 'job_title': job.title})
        
        return jsonify({
            'success': True, 
            'message': 'Application sent. Job is now On Hold.',
            'job': job.to_dict(),
            'application': job_application.to_dict()
        }), 201
        
    except Exception as e:
        app.logger.exception("Error applying to job")
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Unable to apply to job'}), 500
    job.status = 'on_hold'
    db.session.commit()
    
    return jsonify({
        'success': True, 
        'message': 'Application sent. Job is now On Hold.',
        'job': job.to_dict(),
        'application': job_application.to_dict()
    })

@app.route('/api/jobs/<job_id>', methods=['GET'])
def get_job(job_id):
    job = Job.query.get(job_id)
    if not job:
        return jsonify({'success': False, 'message': 'Job not found'}), 404
    return jsonify({'success': True, 'job': job.to_dict()})

@app.route('/api/my-postings', methods=['POST'])
@token_required
def get_my_postings(current_user):
    user_id = current_user.id
    # For demo, match all jobs or filter by creator_id if we implemented it fully. 
    # Let's assume the Demo User (id=2) created the sample jobs for the sake of the workflow.
    # Update sample jobs to have creator_id='2' if not set.
    
    jobs = Job.query.filter((Job.creator_id == user_id) | (Job.creator_id == None)).all()
    
    result = []
    for job in jobs:
        j_dict = job.to_dict()
        # Get applications
        apps = JobApplication.query.filter_by(job_id=job.id).all()
        j_dict['applications'] = [a.to_dict() for a in apps]
        result.append(j_dict)
        
    return jsonify(result)

@app.route('/api/my-applications', methods=['POST'])
@token_required
def get_my_applications(current_user):
    user_id = current_user.id
    apps = JobApplication.query.filter_by(worker_id=user_id).all()
    
    results = []
    for app in apps:
        job = Job.query.get(app.job_id)
        if job:
            job_data = job.to_dict()
            job_data['myApplicationStatus'] = app.status  # pending, accepted, rejected
            job_data['myApplicationId'] = app.id
            results.append(job_data)
            
    return jsonify(results)

@app.route('/api/applications/<app_id>/accept', methods=['POST'])
@token_required
def accept_application(current_user, app_id):
    application = JobApplication.query.get(app_id)
    if not application:
        return jsonify({'success': False, 'message': 'Application not found'}), 404

    job = Job.query.get(application.job_id)
    if not job:
        return jsonify({'success': False, 'message': 'Job not found'}), 404
    if job.creator_id != current_user.id:
        return jsonify({'success': False, 'message': 'Only the job creator can accept applications'}), 403
        
    # 2a. If Customer ACCEPTS: Set job_status = "LOCKED" (alias 'locked' or 'accepted')
    application.status = 'accepted'
    
    job.status = 'locked' 
    job.worker_id = application.worker_id # Set approved_worker
    
    # Reject other applications (cleanup)
    others = JobApplication.query.filter(JobApplication.job_id == job.id, JobApplication.id != app_id).all()
    for o in others:
        o.status = 'rejected'

    # Notify Worker: "Your request has been approved."
    notif = Notification(
        id=str(uuid.uuid4()),
        user_id=application.worker_id,
        type='accept',
        message=f"Your request has been approved.",
        timestamp=datetime.now().strftime("%Y-%m-%d %I:%M %p"),
        related_id=job.id
    )
    db.session.add(notif)
        
    db.session.commit()
    log_activity('application_accepted', 'application', application.id, current_user.id, {'job_id': job.id, 'worker_id': application.worker_id})
    return jsonify({'success': True})

@app.route('/api/applications/<app_id>/reject', methods=['POST'])
@token_required
def reject_application(current_user, app_id):
    application = JobApplication.query.get(app_id)
    if not application:
        return jsonify({'success': False, 'message': 'Application not found'}), 404

    job = Job.query.get(application.job_id)
    if not job:
        return jsonify({'success': False, 'message': 'Job not found'}), 404
    if job.creator_id != current_user.id:
        return jsonify({'success': False, 'message': 'Only the job creator can reject applications'}), 403
        
    application.status = 'rejected'
    
    # 2b. If Customer REJECTS: Set job_status = "OPEN"
    # Reset to OPEN only if it was holding
    if job.status == 'on_hold' or job.status == 'hold':
        job.status = 'open'
        job.worker_id = None # Clear approved worker if any

    # Notify Worker: "Your request has been rejected."
    notif = Notification(
        id=str(uuid.uuid4()),
        user_id=application.worker_id,
        type='reject',
        message=f"Your request has been rejected.",
        timestamp=datetime.now().strftime("%Y-%m-%d %I:%M %p"),
        related_id=job.id
    )
    db.session.add(notif)

    db.session.commit()
    return jsonify({'success': True})

@app.route('/api/jobs', methods=['POST'])
@token_required
def create_job(current_user):
    data = request.json
    try:
        # Validate required fields
        if not data.get('title') or not data.get('category') or not data.get('description'):
            return jsonify({'success': False, 'message': 'Title, category, and description are required'}), 400
        
        amount = data.get('amount', {})
        
        try:
            min_amount = int(float(amount.get('min', 0) or 0))
            max_amount = int(float(amount.get('max', 0) or 0))
        except (ValueError, TypeError):
            return jsonify({'success': False, 'message': 'Invalid budget amount'}), 400
        
        if min_amount <= 0 or max_amount <= 0:
            return jsonify({'success': False, 'message': 'Budget amounts must be greater than 0'}), 400
        
        if min_amount > max_amount:
            return jsonify({'success': False, 'message': 'Minimum budget cannot exceed maximum budget'}), 400
        
        new_job = Job(
            id=str(uuid.uuid4()),
            title=data.get('title'),
            description=data.get('description'),
            category=data.get('category'),
            min_amount=min_amount,
            max_amount=max_amount,
            location=data.get('location', 'Online'),
            deliveryType=data.get('deliveryType', 'pickup'),
            urgency=data.get('urgency', 'flexible'),
            customerName=current_user.name,
            customerRating=0.0,
            postedAt=datetime.now().strftime("%Y-%m-%d %I:%M %p"),
            status='open',
            paymentMode=data.get('paymentMode', 'online'),
            creator_id=current_user.id
        )
        db.session.add(new_job)
        db.session.commit()
        log_activity('job_created', 'job', new_job.id, current_user.id, {'title': new_job.title, 'category': new_job.category})
        
        return jsonify({'success': True, 'job': new_job.to_dict()}), 201
    except Exception as e:
        app.logger.exception("Error creating job")
        return jsonify({'success': False, 'message': 'Unable to create job'}), 500




@app.route('/api/jobs/<job_id>/complete', methods=['POST'])
@token_required
def complete_job(current_user, job_id):
    data = request.json
    rating = data.get('rating')
    review = data.get('review')
    
    job = Job.query.get(job_id)
    if job:
        job.status = 'completed'
        job.rating = rating
        job.review = review
        
        # Update worker rating
        worker = User.query.get(job.worker_id)
        if worker:
            worker.rating = (worker.rating * worker.reviewCount + rating) / (worker.reviewCount + 1)
            worker.reviewCount += 1
            worker.credits += job.max_amount # Reward based on job amount
            
            # Notify Worker
            notif = Notification(
                id=str(uuid.uuid4()),
                user_id=worker.id,
                type='info',
                message=f"Job '{job.title}' completed! You received {rating} stars.",
                timestamp=datetime.now().strftime("%Y-%m-%d %I:%M %p"),
                related_id=job_id
            )
            db.session.add(notif)
            
        db.session.commit()
        log_activity('job_completed', 'job', job.id, current_user.id, {'rating': rating, 'worker_id': job.worker_id})
        return jsonify({'success': True})
    return jsonify({'success': False}), 404

@app.route('/api/notifications/<n_id>/read', methods=['POST'])
@token_required
def mark_notification_read(current_user, n_id):
    notif = Notification.query.get(n_id)
    if notif:
        if notif.user_id != current_user.id:
            return jsonify({'success': False, 'message': 'Notification not found'}), 404
        notif.read = True
        db.session.commit()
        return jsonify({'success': True})
    return jsonify({'success': False, 'message': 'Notification not found'}), 404

@app.route('/api/notifications/mark-all-read', methods=['POST'])
@token_required
def mark_all_notifications_read(current_user):
    user_id = current_user.id
    Notification.query.filter_by(user_id=user_id, read=False).update({'read': True})
    db.session.commit()
    return jsonify({'success': True})


@app.route('/api/applications/<app_id>/cancel', methods=['POST'])
@token_required
def cancel_application(current_user, app_id):
    application = JobApplication.query.get(app_id)
    if not application:
        return jsonify({'success': False, 'message': 'Application not found'}), 404
        
    job = Job.query.get(application.job_id)
    
    # Allow cancel if pending
    if application.status == 'pending':
        # Remove the application
        db.session.delete(application)
        
        # If this was the only application keeping the job "on_hold", check if we should open it?
        # Actually user logic was "if one worker request... make it hold".
        # So if we cancel, we should check if there are any *other* pending requests.
        other_apps = JobApplication.query.filter(JobApplication.job_id == job.id, JobApplication.id != app_id, JobApplication.status == 'pending').count()
        
        if other_apps == 0:
            job.status = 'open' # Re-open the job
            
        db.session.commit()
        return jsonify({'success': True})
        
    return jsonify({'success': False, 'message': 'Cannot cancel processed application'}), 400

@app.route('/api/jobs/<job_id>', methods=['GET'])
def get_job_details(job_id):
    job = Job.query.get(job_id)
    if not job:
        return jsonify({'success': False, 'message': 'Job not found'}), 404
        
    job_dict = job.to_dict()
    # Also fetch the creator's details if we want more context
    creator = User.query.get(job.creator_id) if job.creator_id else None
    if creator:
        job_dict['creatorName'] = creator.name
        job_dict['creatorRating'] = creator.rating

    return jsonify({'success': True, 'job': job_dict})

@app.route('/api/jobs/<job_id>', methods=['DELETE'])
@token_required
def delete_job(current_user, job_id):
    job = Job.query.get(job_id)
    if not job:
        return jsonify({'success': False}), 404
    if job.creator_id != current_user.id:
        return jsonify({'success': False, 'message': 'Only the job creator can delete this job'}), 403
        
    # Cascade delete applications? or keep them?
    # For now simple delete
    JobApplication.query.filter_by(job_id=job_id).delete()
    db.session.delete(job)
    db.session.commit()
    return jsonify({'success': True})




@app.route('/api/users/me', methods=['PUT'])
@token_required
def update_user(current_user):
    user = current_user
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    data = request.json or {}
    protected_fields = {'rating', 'reviewCount', 'credits', 'isVerified', 'aadhaar_verified'}
    if protected_fields.intersection(data.keys()):
        return jsonify({'success': False, 'message': 'Protected profile fields cannot be changed by the client'}), 403
    
    # Update fields if provided
    if 'name' in data: user.name = data['name']
    if 'email' in data: user.email = data['email']
    if 'phone' in data: user.phone = data['phone']
    if 'address' in data: user.address = data['address']
    if 'availability' in data: user.availability = data['availability']
    if 'skills' in data: user.skills_str = json.dumps(data['skills'])
    if 'radius' in data:
        # radius is not persisted by the current User model; ignore it rather
        # than dynamically creating an unsafe attribute.
        pass
    if 'portfolio' in data: user.portfolio_str = json.dumps(data['portfolio'])
    if 'latitude' in data: user.latitude = data['latitude']
    if 'longitude' in data: user.longitude = data['longitude']
    
    db.session.commit()
    return jsonify({'success': True, 'user': user.to_dict()})

# ─── DigiLocker OAuth2 Endpoints ────────────────────────────────────────────

@app.route('/api/digilocker/auth-url', methods=['GET'])
def digilocker_auth_url():
    """Generate DigiLocker OAuth2 authorization URL.
    If credentials are not yet configured, returns mockMode=True so the
    frontend can show an in-page development bypass instead of redirecting.
    """
    is_mock = DIGILOCKER_CLIENT_ID == 'YOUR_CLIENT_ID'
    if is_mock:
        return jsonify({'success': True, 'mockMode': True,
                        'message': 'DigiLocker not configured — running in development mock mode.'})

    state = secrets.token_urlsafe(16)
    params = {
        'response_type': 'code',
        'client_id': DIGILOCKER_CLIENT_ID,
        'redirect_uri': DIGILOCKER_REDIRECT,
        'state': state,
        'scope': 'aadhaar',
    }
    query = '&'.join(f'{k}={v}' for k, v in params.items())
    auth_url = f'{DIGILOCKER_BASE}/public/oauth2/1/authorize?{query}'
    return jsonify({'success': True, 'mockMode': False, 'authUrl': auth_url, 'state': state})


@app.route('/api/digilocker/verify', methods=['POST'])
@token_required
def digilocker_verify(current_user):
    """
    Exchange the DigiLocker authorization code for an access token,
    fetch eAadhaar XML, parse gender, and return the result.
    Blocks non-female users from proceeding.
    """
    data = request.json or {}
    code  = data.get('code')
    if not code:
        return jsonify({'success': False, 'message': 'Authorization code missing'}), 400

    # ── Step 1: Exchange code → access token ──────────────────────────────
    try:
        token_resp = http_requests.post(
            f'{DIGILOCKER_BASE}/public/oauth2/1/token',
            data={
                'code':          code,
                'grant_type':    'authorization_code',
                'client_id':     DIGILOCKER_CLIENT_ID,
                'client_secret': DIGILOCKER_SECRET,
                'redirect_uri':  DIGILOCKER_REDIRECT,
            },
            timeout=10
        )
    except Exception as e:
        return jsonify({'success': False, 'message': f'Token request failed: {e}'}), 502

    if not token_resp.ok:
        return jsonify({'success': False, 'message': 'DigiLocker token exchange failed', 'detail': token_resp.text}), 400

    token_data   = token_resp.json()
    access_token = token_data.get('access_token')
    if not access_token:
        return jsonify({'success': False, 'message': 'No access token received'}), 400

    # ── Step 2: Fetch eAadhaar XML ────────────────────────────────────────
    try:
        aadhaar_resp = http_requests.get(
            f'{DIGILOCKER_BASE}/public/oauth2/1/xml/eaadhaar',
            headers={'Authorization': f'Bearer {access_token}'},
            timeout=10
        )
    except Exception as e:
        return jsonify({'success': False, 'message': f'eAadhaar fetch failed: {e}'}), 502

    if not aadhaar_resp.ok:
        return jsonify({'success': False, 'message': 'Failed to fetch eAadhaar', 'detail': aadhaar_resp.text}), 400

    # ── Step 3: Parse XML and extract gender ──────────────────────────────
    try:
        root   = ET.fromstring(aadhaar_resp.content)
        # DigiLocker eAadhaar XML structure: <KycRes><UidData><Poi gender="M"/></UidData></KycRes>
        # Also try flat <gender> element for backward compat
        gender = None
        name   = None
        dob    = None

        # Try attribute on Poi element
        poi = root.find('.//Poi')
        if poi is not None:
            gender = poi.get('gender')  # 'M' or 'F'
            name   = poi.get('name')
            dob    = poi.get('dob')

        # Fallback: flat child elements
        if gender is None:
            g_el = root.find('.//gender') or root.find('gender')
            if g_el is not None:
                gender = g_el.text
            n_el = root.find('.//name') or root.find('name')
            if n_el is not None:
                name = n_el.text

    except ET.ParseError as e:
        return jsonify({'success': False, 'message': f'XML parse error: {e}'}), 500

    # ── Step 4: Gender check ──────────────────────────────────────────────
    if gender is None:
        return jsonify({'success': False, 'message': 'Could not determine gender from Aadhaar'}), 400

    if gender.upper() != 'F':
        return jsonify({
            'success':  False,
            'blocked':  True,
            'message':  'This platform is exclusively for women. Your Aadhaar record indicates you are not female.',
            'gender':   gender
        }), 403

    # Mark user as verified
    current_user.aadhaar_verified = True
    db.session.commit()

    return jsonify({
        'success':  True,
        'verified': True,
        'gender':   'F',
        'name':     name,
        'dob':      dob,
    })


@app.route('/api/digilocker/status/<user_id>', methods=['GET'])
def digilocker_status(user_id):
    """Return whether a user has completed DigiLocker verification."""
    user = User.query.get(user_id)
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404
    return jsonify({'success': True, 'aadhaarVerified': user.aadhaar_verified or False})

# ─────────────────────────────────────────────────────────────────────────────

@app.route('/api/translate', methods=['POST'])
def translate_text():
    try:
        data = request.json
        text = data.get('text', '')
        target_lang = data.get('targetLang', 'en')

        if not text:
            return jsonify({'success': False, 'message': 'No text provided'}), 400

        # Skip translation for very short universal words
        skip_words = {'ok', 'okay', 'yes', 'no', 'hi', 'hello', 'bye', 'thanks', 'ya', 'ha', 'hmm', 'oh', 'wow', 'k', 'lol', 'haha'}
        if text.strip().lower() in skip_words:
            return jsonify({
                'success': True,
                'originalText': text,
                'translatedText': text,
                'targetLang': target_lang,
                'skipped': True
            })

        # Skip if text is just numbers, emojis, or punctuation
        import re
        cleaned = re.sub(r'[\s\d\W]+', '', text)
        if not cleaned:
            return jsonify({
                'success': True,
                'originalText': text,
                'translatedText': text,
                'targetLang': target_lang,
                'skipped': True
            })

        lang_map = {
            'en': 'English', 'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil', 
            'kn': 'Kannada', 'ml': 'Malayalam', 'mr': 'Marathi', 
            'bn': 'Bengali', 'gu': 'Gujarati', 'pa': 'Punjabi'
        }
        script_map = {
            'te': 'Telugu script (తెలుగు లిపి)', 'hi': 'Devanagari script (देवनागरी)',
            'ta': 'Tamil script (தமிழ் எழுத்து)', 'kn': 'Kannada script (ಕನ್ನಡ ಲಿಪಿ)',
            'ml': 'Malayalam script (മലയാളം ലിപി)', 'mr': 'Devanagari script (देवनागरी)',
            'bn': 'Bengali script (বাংলা লিপি)', 'gu': 'Gujarati script (ગુજરাતી લિপિ)',
            'pa': 'Gurmukhi script (ਗੁਰਮੁਖੀ)'
        }
        
        target_lang_name = lang_map.get(target_lang, target_lang)
        target_script = script_map.get(target_lang, '')
        script_instruction = f'\nCRITICAL: You MUST write the output in {target_script}. NEVER use Roman/Latin/English letters for {target_lang_name} words.' if target_script else ''

        # Per-language few-shot examples for natural, casual translations
        examples_map = {
            'te': """Examples for Telugu:
- "I think i suits to the work that you posted" → "మీరు posting చేసిన work కి నేన్ బాగా fit అవుతాను"
- "When can you start?" → "మీరు ఎప్పుడు start చేయగలరు?"
- "How much will you pay?" → "ఎంత pay చేస్తారు?"
- "I am interested in this job" → "నాకు ఈ job మీద interest ఉంది""",
            'hi': """Examples for Hindi:
- "I think i suits to the work that you posted" → "आपने जो work post किया है उसके लिए मैं fit हूँ"
- "When can you start?" → "आप कब start कर सकती हैं?"
- "How much will you pay?" → "कितना pay करेंगे?"
- "I am interested in this job" → "मुझे इस job में interest है""",
            'ta': """Examples for Tamil:
- "I think i suits to the work that you posted" → "நீங்க post பண்ண work-க்கு நான் fit ஆவேன்"
- "When can you start?" → "நீங்க எப்போ start பண்ணலாம்?"
- "How much will you pay?" → "எவ்வளவு pay பண்றீங்க?"
- "I am interested in this job" → "எனக்கு இந்த job-ல interest இருக்கு""",
            'kn': """Examples for Kannada:
- "I think i suits to the work that you posted" → "ನೀವು post ಮಾಡಿದ work-ಗೆ ನಾನು fit ಆಗ್ತೀನಿ"
- "When can you start?" → "ನೀವು ಯಾವಾಗ start ಮಾಡಬಹುದು?"
- "How much will you pay?" → "ಎಷ್ಟು pay ಮಾಡ್ತೀರಾ?"
- "I am interested in this job" → "ನನಗೆ ಈ job-ನಲ್ಲಿ interest ಇದೆ""",
            'ml': """Examples for Malayalam:
- "I think i suits to the work that you posted" → "നിങ്ങൾ post ചെയ്ത work-ന് ഞാൻ fit ആണ്"
- "When can you start?" → "നിങ്ങൾക്ക് എപ്പോൾ start ചെയ്യാം?"
- "How much will you pay?" → "എത്ര pay ചെയ്യും?"
- "I am interested in this job" → "എനിക്ക് ഈ job-ൽ interest ഉണ്ട്""",
            'mr': """Examples for Marathi:
- "I think i suits to the work that you posted" → "तुम्ही post केलेल्या work साठी मी fit आहे"
- "When can you start?" → "तुम्ही कधी start करू शकता?"
- "How much will you pay?" → "किती pay कराल?"
- "I am interested in this job" → "मला या job मध्ये interest आहे""",
            'bn': """Examples for Bengali:
- "I think i suits to the work that you posted" → "আপনি যে work post করেছেন তার জন্য আমি fit"
- "When can you start?" → "আপনি কখন start করতে পারবেন?"
- "How much will you pay?" → "কত pay করবেন?"
- "I am interested in this job" → "আমার এই job-এ interest আছে""",
            'gu': """Examples for Gujarati:
- "I think i suits to the work that you posted" → "તમે post કરેલા work માટે હું fit છું"
- "When can you start?" → "તમે ક્યારે start કરી શકો?"
- "How much will you pay?" → "કેટલું pay કરશો?"
- "I am interested in this job" → "મને આ job માં interest છે""",
            'pa': """Examples for Punjabi:
- "I think i suits to the work that you posted" → "ਤੁਸੀਂ ਜੋ work post ਕੀਤਾ ਉਸ ਲਈ ਮੈਂ fit ਹਾਂ"
- "When can you start?" → "ਤੁਸੀਂ ਕਦੋਂ start ਕਰ ਸਕਦੇ ਹੋ?"
- "How much will you pay?" → "ਕਿੰਨਾ pay ਕਰੋਗੇ?"
- "I am interested in this job" → "ਮੈਨੂੰ ਇਸ job ਵਿੱਚ interest ਹੈ"""
        }
        examples_text = examples_map.get(target_lang, '')

        chat_completion = groq_client.chat.completions.create(
            messages=[{
                "role": "system",
                "content": f"""You are a chat message translator for a women's job platform in India called SheRise.
{script_instruction}
RULES:
1. First, detect what language the input text is in.
2. If the text is ALREADY in {target_lang_name} script, return it exactly as-is. Do NOT re-translate.
3. If the text is in a different language, translate it into simple, spoken {target_lang_name} using {target_script if target_script else 'the appropriate script'}.
4. Use SHORT, casual, everyday {target_lang_name} — the way women talk in real life. Keep it brief and natural. Avoid long formal sentences.
5. Keep common English words like work, job, post, start, pay, fit, interest, online AS-IS in English. Don't translate them.
6. Keep names, numbers, addresses, and brand names unchanged.
7. If the text mixes languages, translate only the non-{target_lang_name} parts into {target_lang_name} native script.
8. Output ONLY the translated text. No quotes, no explanations, no labels.
9. NEVER write {target_lang_name} words in English/Roman letters. Always use the native script.

{examples_text}"""
            }, {
                "role": "user",
                "content": text
            }],
            model="llama-3.3-70b-versatile",
            temperature=0.1,
            max_tokens=500
        )

        translated = chat_completion.choices[0].message.content.strip()
        
        # Remove quotes if the model wrapped the output
        if (translated.startswith('"') and translated.endswith('"')) or (translated.startswith("'") and translated.endswith("'")):
            translated = translated[1:-1]

        return jsonify({
            'success': True,
            'originalText': text,
            'translatedText': translated,
            'targetLang': target_lang
        })

    except Exception as e:
        print(f"Translation Error: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/transliterate', methods=['POST'])
def transliterate_text():
    """Convert English text to native script WITHOUT translating meaning.
    e.g. 'hello' in Hindi -> 'हेलो' (not 'नमस्ते')
    """
    try:
        data = request.json
        text = data.get('text', '')
        target_lang = data.get('targetLang', 'en')

        if not text:
            return jsonify({'success': False, 'message': 'No text provided'}), 400

        if target_lang == 'en':
            return jsonify({'success': True, 'transliteratedText': text})

        lang_map = {
            'en': 'English', 'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil',
            'kn': 'Kannada', 'ml': 'Malayalam', 'mr': 'Marathi',
            'bn': 'Bengali', 'gu': 'Gujarati', 'pa': 'Punjabi'
        }
        script_map = {
            'hi': 'Devanagari', 'te': 'Telugu', 'ta': 'Tamil',
            'kn': 'Kannada', 'ml': 'Malayalam', 'mr': 'Devanagari',
            'bn': 'Bengali', 'gu': 'Gujarati', 'pa': 'Gurmukhi'
        }

        target_lang_name = lang_map.get(target_lang, target_lang)
        script_name = script_map.get(target_lang, target_lang_name)

        chat_completion = groq_client.chat.completions.create(
            messages=[{
                "role": "system",
                "content": f"""You are a transliteration tool. Your ONLY job is to convert the SOUND of the input text into {script_name} script ({target_lang_name}).

CRITICAL RULES:
- Do NOT translate the meaning. Keep the same words.
- Only change the script/alphabet. Write how the words SOUND in {script_name} script.
- Examples for Hindi: "hello" -> "हेलो", "good morning" -> "गुड मॉर्निंग", "thank you" -> "थैंक यू", "what is the price" -> "व्हाट इज द प्राइस"
- Examples for Tamil: "hello" -> "ஹெலோ", "thank you" -> "தேங்க் யூ"
- Return ONLY the transliterated text. No quotes, no explanation, nothing else."""
            }, {
                "role": "user",
                "content": text
            }],
            model="llama-3.3-70b-versatile",
            temperature=0.1,
            max_tokens=500
        )

        transliterated = chat_completion.choices[0].message.content.strip()

        return jsonify({
            'success': True,
            'originalText': text,
            'transliteratedText': transliterated,
            'targetLang': target_lang
        })

    except Exception as e:
        print(f"Transliteration Error: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/api/users/<user_id>', methods=['GET'])
def get_user(user_id):
    user = User.query.get(user_id)
    if user:
        return jsonify({'success': True, 'user': user.to_dict()})
    return jsonify({'success': False, 'message': 'User not found'}), 404


@app.route('/api/voice-to-text', methods=['POST'])
def voice_to_text():
    try:
        if 'audio' not in request.files:
            return jsonify({'success': False, 'message': 'No audio file provided'}), 400
        
        audio_file = request.files['audio']
        target_lang = request.form.get('targetLang', 'en')

        # Save to a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.webm') as temp_audio:
            audio_file.save(temp_audio.name)
            temp_path = temp_audio.name

        try:
            with open(temp_path, "rb") as file:
                transcription = groq_client.audio.transcriptions.create(
                    file=(temp_path, file.read()),
                    model="whisper-large-v3",
                    response_format="json",
                    language=target_lang if target_lang != 'en' else None # Whisper handles auto-detect well
                )
            
            os.unlink(temp_path) # Clean up
            
            return jsonify({
                'success': True,
                'text': transcription.text
            })

        except Exception as e:
            if os.path.exists(temp_path): os.unlink(temp_path)
            raise e

    except Exception as e:
        print(f"Voice Transcription Error: {str(e)}")
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/analyze-image', methods=['POST'])
def analyze_image():
    try:
        if 'image' not in request.files:
            return jsonify({'success': False, 'message': 'No image file provided'}), 400
        
        image_file = request.files['image']
        
        # Read and encode image to base64
        image_content = image_file.read()
        base64_image = base64.b64encode(image_content).decode('utf-8')

        prompt = """
        You are a professional marketing assistant for 'Shakthi Connect', a platform that helps Indian women turn their skills into businesses.
        Look at this image of a craft, dish, or service. 
        Generate:
        1. A catchy 'title' (max 40 chars).
        2. A warm, professional 'description' (max 150 chars) that highlights the quality and effort.
        3. A list of 3 relevant 'tags' from our platform: [stitching, tailoring, cooking, pickles, snacks, kidcare, handicraft, cleaning, tuition, beauty].
        
        Return ONLY valid JSON.
        Example: {"title": "Hand-Stitched Silk Blouse", "description": "Elegant custom-fit silk blouse with intricate gold embroidery. Perfect for weddings.", "tags": ["stitching", "tailoring"]}
        """

        chat_completion = groq_client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}",
                            },
                        },
                    ],
                }
            ],
            # Use Llama 4 Scout (Multimodal) as Llama 3.2 Vision is decommissioned
            model="meta-llama/llama-4-scout-17b-16e-instruct",
            response_format={"type": "json_object"}
        )
        
        result = json.loads(chat_completion.choices[0].message.content)
        
        return jsonify({
            'success': True,
            'analysis': result
        })

    except Exception as e:
        import traceback
        error_msg = str(e)
        print(f"CRITICAL Image Analysis Error: {error_msg}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': error_msg}), 500

# ─── User Safety & Emergency Endpoints ────────────────────────────────────────

@app.route('/api/safety-reports', methods=['POST'])
@token_required
def create_safety_report(current_user):
    """Allow an authenticated user to submit an incident or safety report to Admin."""
    data = request.get_json() or {}
    title = (data.get('title') or '').strip()
    description = (data.get('description') or '').strip()
    category = data.get('category', 'other')
    severity = data.get('severity', 'medium')
    related_job_id = data.get('relatedJobId') or data.get('related_job_id')
    related_user_id = data.get('relatedUserId') or data.get('related_user_id')

    if not title:
        return jsonify({'success': False, 'message': 'Report title is required'}), 400
    if not description:
        return jsonify({'success': False, 'message': 'Report description is required'}), 400

    from admin.models import SafetyReport, SafetyReportEvent

    if category not in SafetyReport.CATEGORIES:
        category = 'other'
    if severity not in SafetyReport.SEVERITIES:
        severity = 'medium'

    report_id = str(uuid.uuid4())
    report = SafetyReport(
        id=report_id,
        reporter_user_id=current_user.id,
        category=category,
        severity=severity,
        status='new',
        title=title,
        description=description,
        related_job_id=related_job_id,
        related_user_id=related_user_id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.session.add(report)

    event = SafetyReportEvent(
        id=str(uuid.uuid4()),
        report_id=report_id,
        event_type='created',
        from_status=None,
        to_status='new',
        note=f'Report filed by {current_user.name or current_user.id}',
        created_at=datetime.utcnow(),
    )
    db.session.add(event)

    try:
        db.session.commit()
        log_activity('safety_report_filed', 'safety_report', report_id, current_user.id, {
            'title': title,
            'category': category,
            'severity': severity
        })
        return jsonify({
            'success': True,
            'message': 'Your report has been submitted to the safety operations team.',
            'reportId': report_id
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Failed to submit safety report: {str(e)}'}), 500


@app.route('/api/safety-reports/my', methods=['GET'])
@token_required
def get_my_safety_reports(current_user):
    """Retrieve all safety reports filed by the current user."""
    from admin.models import SafetyReport
    reports = SafetyReport.query.filter_by(reporter_user_id=current_user.id).order_by(SafetyReport.created_at.desc()).all()
    return jsonify({
        'success': True,
        'reports': [r.to_public_dict(include_description=True) for r in reports]
    })


@app.route('/api/safety/sos', methods=['POST'])
@app.route('/api/sos/trigger', methods=['POST'])
@app.route('/api/emergency/sos', methods=['POST'])
def trigger_sos_emergency():
    """Trigger an emergency alert with GPS coordinates broadcast to Admin Safety Center and SMS dispatch."""
    data = request.get_json(silent=True) or {}

    # Extract user if bearer token is provided
    user_id = None
    user_name = data.get('name') or 'Anonymous / Guest'
    user_phone = data.get('phone') or 'Not provided'
    user_lat = None
    user_lng = None

    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            u = User.query.get(payload.get('user_id'))
            if u:
                user_id = u.id
                user_name = u.name or user_name
                user_phone = u.phone or user_phone
                user_lat = u.latitude
                user_lng = u.longitude
        except Exception:
            pass

    latitude = data.get('latitude') or user_lat or 'Unknown'
    longitude = data.get('longitude') or user_lng or 'Unknown'
    message = data.get('message') or f"EMERGENCY SOS triggered by {user_name} ({user_phone})"

    from admin.models import SafetyReport, SafetyReportEvent

    report_id = str(uuid.uuid4())
    report = SafetyReport(
        id=report_id,
        reporter_user_id=user_id,
        category='emergency',
        severity='critical',
        status='action_required',
        title=f"[SOS] EMERGENCY ALERT: {user_name}",
        description=f"{message}\nCoordinates: Latitude {latitude}, Longitude {longitude}\nPhone: {user_phone}",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.session.add(report)

    event = SafetyReportEvent(
        id=str(uuid.uuid4()),
        report_id=report_id,
        event_type='sos_alert',
        from_status='new',
        to_status='action_required',
        note=f"Emergency SOS signal received. Lat: {latitude}, Lng: {longitude}",
        created_at=datetime.utcnow(),
    )
    db.session.add(event)

    try:
        db.session.commit()
        log_activity('sos_emergency_triggered', 'safety_report', report_id, user_id, {
            'lat': str(latitude),
            'lng': str(longitude),
            'phone': user_phone,
            'name': user_name
        })
        send_sos_sms_alert(user_phone, f"Emergency alert acknowledged for {user_name}. Ops dispatching assistance to coordinates ({latitude}, {longitude}).")
        return jsonify({
            'success': True,
            'message': 'Emergency SOS alert recorded and dispatched to operations monitors.',
            'reportId': report_id
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Failed to dispatch SOS alert: {str(e)}'}), 500

# ─── Subscription Routes ───────────────────────────────────────────────────────

SUBSCRIPTION_PLANS = {
    'free': {'name': 'Free', 'price': 0, 'credits_monthly': 0, 'features': ['5 job applications/month', 'Basic profile', 'Community access']},
    'basic': {'name': 'Basic', 'price': 99, 'credits_monthly': 50, 'features': ['20 job applications/month', 'Priority listing', '50 credits/month', 'Email support']},
    'pro': {'name': 'Pro', 'price': 299, 'credits_monthly': 150, 'features': ['Unlimited applications', 'Top search placement', '150 credits/month', 'Verified badge', 'Priority support', 'Analytics dashboard']},
}

class Subscription(db.Model):
    __tablename__ = 'subscription'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), unique=True, nullable=False)
    plan = db.Column(db.String(20), default='free')  # free | basic | pro
    status = db.Column(db.String(20), default='active')  # active | cancelled | expired
    started_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=True)
    auto_renew = db.Column(db.Boolean, default=True)

    def to_dict(self):
        plan_info = SUBSCRIPTION_PLANS.get(self.plan, SUBSCRIPTION_PLANS['free'])
        return {
            'id': self.id,
            'userId': self.user_id,
            'plan': self.plan,
            'planName': plan_info['name'],
            'price': plan_info['price'],
            'status': self.status,
            'startedAt': self.started_at.isoformat() if self.started_at else None,
            'expiresAt': self.expires_at.isoformat() if self.expires_at else None,
            'autoRenew': self.auto_renew,
            'features': plan_info['features'],
            'creditsMonthly': plan_info['credits_monthly'],
        }


# Phase 2A: register only the secure Admin authentication/session endpoints.
# Business/admin data APIs are intentionally deferred to later phases.
from admin.rate_limit import init_limiter
from admin.routes import admin_bp
from admin.cli import register_admin_cli

init_limiter(app)
app.register_blueprint(admin_bp)
register_admin_cli(app)


@app.route('/api/subscription', methods=['GET'])
@token_required
def get_subscription(current_user):
    user_id = current_user.id
    sub = Subscription.query.filter_by(user_id=user_id).first()
    if not sub:
        # Return a default free plan representation without persisting
        plan_info = SUBSCRIPTION_PLANS['free']
        return jsonify({
            'success': True,
            'subscription': {
                'plan': 'free',
                'planName': plan_info['name'],
                'price': plan_info['price'],
                'status': 'active',
                'startedAt': None,
                'expiresAt': None,
                'autoRenew': False,
                'features': plan_info['features'],
                'creditsMonthly': plan_info['credits_monthly'],
            }
        })
    return jsonify({'success': True, 'subscription': sub.to_dict()})

# ─── Razorpay / UPI Payment Gateway Endpoints ─────────────────────────────────
RAZORPAY_KEY_ID = os.environ.get('RAZORPAY_KEY_ID', '')
RAZORPAY_KEY_SECRET = os.environ.get('RAZORPAY_KEY_SECRET', '')

@app.route('/api/subscription/create-order', methods=['POST'])
@token_required
def create_subscription_order(current_user):
    """Create a payment order for subscription upgrade (Razorpay / UPI or sandbox mock)."""
    data = request.get_json(silent=True) or {}
    plan = data.get('plan')
    if plan not in SUBSCRIPTION_PLANS or plan == 'free':
        return jsonify({'success': False, 'message': 'Invalid plan selected'}), 400

    plan_info = SUBSCRIPTION_PLANS[plan]
    amount_inr = plan_info['price']
    amount_paise = amount_inr * 100

    is_mock = not (RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET)

    if is_mock:
        order_id = f"order_mock_{uuid.uuid4().hex[:14]}"
        return jsonify({
            'success': True,
            'mockMode': True,
            'orderId': order_id,
            'amount': amount_paise,
            'currency': 'INR',
            'plan': plan,
            'planName': plan_info['name'],
            'message': 'Running in development sandbox mode without live Razorpay credentials.'
        })

    try:
        auth_str = base64.b64encode(f"{RAZORPAY_KEY_ID}:{RAZORPAY_KEY_SECRET}".encode()).decode()
        resp = http_requests.post(
            'https://api.razorpay.com/v1/orders',
            headers={'Authorization': f'Basic {auth_str}', 'Content-Type': 'application/json'},
            json={
                'amount': amount_paise,
                'currency': 'INR',
                'receipt': f"rcpt_{current_user.id[:8]}_{int(time.time())}",
                'notes': {'userId': current_user.id, 'plan': plan}
            },
            timeout=10
        )
        if not resp.ok:
            return jsonify({'success': False, 'message': 'Failed to create payment order with gateway', 'detail': resp.text}), 502
        order_data = resp.json()
        return jsonify({
            'success': True,
            'mockMode': False,
            'orderId': order_data.get('id'),
            'amount': amount_paise,
            'currency': 'INR',
            'keyId': RAZORPAY_KEY_ID,
            'plan': plan,
            'planName': plan_info['name']
        })
    except Exception as e:
        return jsonify({'success': False, 'message': f'Gateway error: {str(e)}'}), 500


@app.route('/api/subscription/verify-payment', methods=['POST'])
@token_required
def verify_subscription_payment(current_user):
    """Verify payment signature from gateway and activate subscription."""
    data = request.get_json(silent=True) or {}
    plan = data.get('plan')
    order_id = data.get('orderId')
    payment_id = data.get('paymentId')
    signature = data.get('signature')

    if not plan or plan not in SUBSCRIPTION_PLANS:
        return jsonify({'success': False, 'message': 'Valid plan is required'}), 400

    is_mock = not (RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET)

    if not is_mock:
        if not (order_id and payment_id and signature):
            return jsonify({'success': False, 'message': 'Missing payment verification credentials'}), 400

        import hmac
        import hashlib
        generated_sig = hmac.new(
            RAZORPAY_KEY_SECRET.encode('utf-8'),
            f"{order_id}|{payment_id}".encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(generated_sig, signature):
            return jsonify({'success': False, 'message': 'Payment signature verification failed'}), 400

    user_id = current_user.id
    user = User.query.get(user_id)
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404

    from datetime import timedelta
    expires_at = (datetime.utcnow() + timedelta(days=30)) if plan != 'free' else None

    sub = Subscription.query.filter_by(user_id=user_id).first()
    if sub:
        sub.plan = plan
        sub.status = 'active'
        sub.started_at = datetime.utcnow()
        sub.expires_at = expires_at
        sub.auto_renew = (plan != 'free')
    else:
        sub = Subscription(
            id=str(uuid.uuid4()),
            user_id=user_id,
            plan=plan,
            status='active',
            started_at=datetime.utcnow(),
            expires_at=expires_at,
            auto_renew=(plan != 'free'),
        )
        db.session.add(sub)

    monthly_credits = SUBSCRIPTION_PLANS[plan]['credits_monthly']
    if monthly_credits > 0:
        user.credits = (user.credits or 0) + monthly_credits

    try:
        db.session.commit()
        log_activity('subscription_activated', 'subscription', sub.id, user_id, {
            'plan': plan,
            'creditsAdded': monthly_credits,
            'paymentId': payment_id or 'mock_payment'
        })
        return jsonify({
            'success': True,
            'subscription': sub.to_dict(),
            'creditsAdded': monthly_credits,
            'message': f"Successfully subscribed to {SUBSCRIPTION_PLANS[plan]['name']} plan!"
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/api/subscription/subscribe', methods=['POST'])
@token_required
def subscribe(current_user):
    data = request.get_json()
    user_id = current_user.id
    plan = data.get('plan', 'free')
    if not user_id:
        return jsonify({'success': False, 'message': 'user_id required'}), 400
    if plan not in SUBSCRIPTION_PLANS:
        return jsonify({'success': False, 'message': 'Invalid plan'}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({'success': False, 'message': 'User not found'}), 404

    # Calculate expiry (30 days from now for paid plans)
    from datetime import timedelta
    expires_at = (datetime.utcnow() + timedelta(days=30)) if plan != 'free' else None

    sub = Subscription.query.filter_by(user_id=user_id).first()
    if sub:
        sub.plan = plan
        sub.status = 'active'
        sub.started_at = datetime.utcnow()
        sub.expires_at = expires_at
        sub.auto_renew = (plan != 'free')
    else:
        sub = Subscription(
            id=str(uuid.uuid4()),
            user_id=user_id,
            plan=plan,
            status='active',
            started_at=datetime.utcnow(),
            expires_at=expires_at,
            auto_renew=(plan != 'free'),
        )
        db.session.add(sub)

    # Grant monthly credits immediately on upgrade
    monthly_credits = SUBSCRIPTION_PLANS[plan]['credits_monthly']
    if monthly_credits > 0:
        user.credits = (user.credits or 0) + monthly_credits

    try:
        db.session.commit()
        return jsonify({'success': True, 'subscription': sub.to_dict(), 'creditsAdded': monthly_credits})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


@app.route('/api/subscription/cancel', methods=['POST'])
@token_required
def cancel_subscription(current_user):
    data = request.get_json()
    user_id = current_user.id

    sub = Subscription.query.filter_by(user_id=user_id).first()
    if not sub:
        return jsonify({'success': False, 'message': 'No subscription found'}), 404

    sub.auto_renew = False
    sub.status = 'cancelled'
    try:
        db.session.commit()
        return jsonify({'success': True, 'subscription': sub.to_dict()})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# ── Serve React frontend (catch-all MUST be last) ──────────────────────────

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_frontend(path):
    # If the requested file exists in frontend_dist, serve it directly
    if path and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    # Otherwise serve index.html (React SPA routing)
    return send_from_directory(app.static_folder, 'index.html')

# ─────────────────────────────────────────────────────────────────────────────


if __name__ == '__main__':
    instance_dir = os.path.join(basedir, 'instance')
    if not os.path.exists(instance_dir):
        os.makedirs(instance_dir)
    with app.app_context():
        db.create_all()
    debug_enabled = os.environ.get('FLASK_DEBUG', '1').lower() in {'1', 'true', 'yes'}
    app.run(host='0.0.0.0', debug=debug_enabled, port=int(os.environ.get('SERVER_PORT', 10201)))
