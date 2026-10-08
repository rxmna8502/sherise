# SheRise Mobile (100% Pure Native Flutter)

This is the pure native Flutter Android mobile application for the SheRise platform. It contains pure Flutter widgets, clean architecture (Riverpod + GoRouter + Dio), and native screens without any WebView dependency.

## Native Screens Included

1. **Authentication Flow (`features/auth/`):**
   - Native Phone & Email Login (`login_screen.dart`)
   - Native 6-digit Pinput OTP Verification (`otp_screen.dart`)
   - Native User Registration (`register_screen.dart`)
2. **Main Navigation Shell (`features/navigation/`):**
   - Material 3 `NavigationBar` with 5 primary tabs.
3. **Jobs & Marketplace (`features/jobs/`):**
   - Browse, search, filter micro-jobs (`jobs_screen.dart`)
   - Post new work opportunities (`post_job_screen.dart`)
   - Job detail & 1-tap apply (`job_detail_screen.dart`)
   - Track applications and manage postings (`my_work_screen.dart`)
4. **Real-Time 1-on-1 Chat (`features/chat/`):**
   - Active conversations list (`chat_list_screen.dart`)
   - Native chat bubbles with live polling and send bar (`chat_screen.dart`)
5. **Safety & Emergency Center (`features/safety/`):**
   - Large Red One-Touch SOS broadcast with GPS coordinates (`safety_screen.dart`)
   - Direct dialers to Women Helpline (1091), National Emergency (112), and Police (100)
   - Incident safety report submission modal
6. **Notifications Center (`features/notifications/`):**
   - Activity notifications feed with mark-as-read (`notifications_screen.dart`)
7. **User Profile & Settings (`features/profile/`):**
   - User card, Aadhaar verified badge, rating, credits, registered skills, and logout (`profile_screen.dart`)

## Visual Design & Aesthetics (Web Parity)
- **Brand Palette:** Rose-600 (`#E11D48`), Pink-500 (`#EC4899`), Purple-600 (`#7C3AED`), Deep Violet (`#5B21B6`), Emerald-600 (`#059669`), and Amber-600 (`#D97706`).
- **Gradients & Cards:** Linear hero gradients, glowing selection pills, frosted top & bottom bars, and glassmorphic rounded cards with subtle drop shadows.

## Web App Features Integrated into Mobile
1. **Multilingual Translation & Transliteration:**
   - Instant language switching modal supporting 10 Indian languages: English, हिन्दी, తెలుగు, தமிழ், ಕನ್ನಡ, മലയാളം, मराठी, বাংলা, ગુજરાતી, ਪੰਜਾਬੀ.
   - On-demand translation of job descriptions via `/api/translate`.
2. **AI Voice Assistant:**
   - Interactive voice input modal with animated mic calling Groq Whisper v3 (`/api/voice-to-text`) to dictate work requirements.
3. **Smart Photo Assistant (Groq Llama Scout):**
   - Direct image attachment/upload via `image_picker` that calls `/api/analyze-image` to auto-extract catchy titles, descriptions, and categories.
4. **Nearby Skilled Women Discovery:**
   - Segmented toggle in the Work feed between "Available Work" and "Nearby Women" (`/api/workers/nearby`) showing skills, ratings, and direct contact options.
5. **Full 12 Indian Micro-Job Categories:**
   - Stitching & Tailoring, Cooking & Catering, Pickles & Snacks, Baby & Kid Care, Tuition & Teaching, Handicrafts & Arts, Cleaning & Housekeeping, Beauty & Mehendi, Data Entry & Digital, Storytelling & Care, Baking & Sweets, Packaging & Assembly.
6. **SheRise Membership Plans & Coins:**
   - Coin balance badge in top bar and profile (`/api/subscription`).
   - Subscription upgrade modal with Free, Starter Shakti (₹99/mo), and Pro Empower (₹299/mo) plans.
7. **Work Completion & 5-Star Reviews:**
   - Interactive rating dialog with star selector and feedback notes on accepted jobs (`/api/jobs/<id>/complete`).

## How to Run

From this folder:

```bash
flutter pub get
flutter run --dart-define=SHE_RISE_URL=http://localhost:10202
```

Or from the project root using the universal launcher:
```cmd
.\start.bat
```
Choose `[3]` for Mobile App on phone, or `[4]` to launch everything.

