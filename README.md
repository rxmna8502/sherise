# SheRise — Women Empowerment Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![Flask](https://img.shields.io/badge/Flask-2.x-000000?logo=flask)](https://flask.palletsprojects.com/)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react)](https://react.dev)

> **Connecting skilled women with micro-work opportunities, powered by AI matching, verified identities, and a dedicated native mobile experience.**

---

## 🏛️ Project Architecture

This repository contains the complete end-to-end SheRise platform:

```
sherise/
├── SheRise_Mobile/        # 100% Pure Native Flutter Mobile Application
│   ├── lib/               # Clean architecture (Riverpod, GoRouter, Dio)
│   ├── assets/            # App assets, branding, and images
│   └── android/           # Native Android configuration
├── SheRise_Web/           # Backend REST API & Web Platform
│   ├── app.py             # Flask application & API endpoints
│   ├── frontend_dist/     # Pre-built Web Frontend distribution
│   ├── requirements.txt   # Python dependencies
│   └── .env.example       # Environment template
├── SheRise_AdminPanel/    # Admin Console (React + Vite + TailwindCSS)
│   ├── src/               # Admin pages, tables, moderation controls
│   └── package.json       # Admin dependencies
├── start.bat              # Universal interactive platform launcher
├── start_all.ps1          # PowerShell launcher for all microservices
└── start_mobile.bat       # Mobile backend + Flutter app launcher
```

---

## 📱 SheRise Mobile App (Native Flutter)

The mobile app in [`SheRise_Mobile/`](SheRise_Mobile/) is built with pure Flutter widgets with zero WebView dependencies:

- **1:1 Visual Parity:** Clones the web mobile aesthetic with warm blush backgrounds (`#FAF7F7`), serif brand titles, card borders (`#F3E8EC`), and dark slate (`#0F172A`) buttons.
- **5 Core Navigation Tabs:**
  1. 💼 **Take Work (`jobs_screen.dart`):** Micro-job listings, AI-recommended opportunities, search with voice assistant, category chips, and application submission.
  2. 📝 **Give Work (`post_job_screen.dart`):** Structured job posting with escrow online payment, cash on delivery, and budget limits.
  3. 📍 **Near Me (`near_me_screen.dart`):** Geolocation-based directory of verified women artisans, tailors, cooks, and tutors with direct contact actions.
  4. 🛡️ **Safety Center (`safety_screen.dart`):** One-touch SOS emergency dispatcher, 24/7 national helpline dialing (`1091`, `112`, `181`), and confidential reporting.
  5. 👤 **Profile (`profile_screen.dart`):** DigiLocker verification badge, work history, and empowerment subscription tiers (`Free`, `Starter Shakti`, `Pro Empower`).
- **Universal Mobile Header:** Circular brand logo, Indic language switcher (English, Hindi, Tamil, Telugu, Kannada, Bengali), and real-time notification badge.

---

## 💻 SheRise Web & Backend API

The backend in [`SheRise_Web/`](SheRise_Web/) provides:
- **Authentication:** Email & SMS OTP verification with JWT authentication.
- **AI Matching:** Groq API-powered recommendation engine matching user skills to local opportunities.
- **Verification:** Sandbox integration with DigiLocker for Aadhaar/identity verification.
- **Real-Time Notifications:** Dynamic polling and status updates for work applications and messages.

---

## 🚀 Quick Start & Launching

### Option 1: Universal Launcher (Windows)
Double-click [`start.bat`](start.bat) or run from terminal:

```cmd
.\start.bat
```
Choose from the interactive menu:
- `[1]` Web App + Admin Panel (Port 10201 & Port 5173)
- `[2]` Dedicated Mobile Backend (Port 10202)
- `[3]` Mobile App on Connected Device
- `[4]` Launch Everything

### Option 2: Running the Flutter App Manually
```bash
cd SheRise_Mobile
flutter pub get
flutter run --dart-define=SHE_RISE_URL=http://127.0.0.1:10202
```

### Option 3: Running the Web App Manually
```bash
cd SheRise_Web
python -m venv .venv
# Activate virtual environment
.venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

---

## 🛡️ License

This project is licensed under the MIT License.
