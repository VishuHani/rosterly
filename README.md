# Rosterly - SmartRoster

AI-powered workforce management system for hospitality businesses. Upload a roster screenshot, and let AI handle the rest.

## 🚀 Quick Start

This guide will help you set up Rosterly from scratch, even if you're not a developer.

---

## 📋 Prerequisites

Before you begin, you'll need accounts on these services (all have free tiers):

1. **Supabase** (Database & Auth): https://supabase.com
2. **OpenAI** (AI Features): https://platform.openai.com
3. **Vercel** (API Hosting): https://vercel.com
4. **Firebase** (Push Notifications): https://firebase.google.com
5. **GitHub** (Code Repository): https://github.com

---

## 🛠️ Step 1: Set Up Supabase (Database)

### 1.1 Create a Supabase Project

1. Go to https://supabase.com and sign up
2. Click "New Project"
3. Enter project details:
   - **Name**: Rosterly
   - **Database Password**: Create a strong password (save this!)
   - **Region**: Choose closest to you (e.g., Sydney for Australia)
4. Wait 2-3 minutes for the project to be ready

### 1.2 Run the Database Schema

1. In your Supabase dashboard, click "SQL Editor" in the left menu
2. Click "New Query"
3. Open the file `database/schema.sql` from this project
4. Copy the entire contents and paste into the SQL Editor
5. Click "Run" (or press Cmd/Ctrl + Enter)
6. You should see "Success. No rows returned" - that's perfect!
7. Go to "Table Editor" to verify all tables were created

### 1.3 Get Your Supabase Credentials

1. Go to Project Settings (gear icon) → API
2. Copy these two values (you'll need them later):
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon public key** (long string starting with `eyJ...`)

---

## 🤖 Step 2: Set Up OpenAI (AI Features)

### 2.1 Create an OpenAI Account

1. Go to https://platform.openai.com
2. Sign up or log in
3. Add billing information (required even for free tier)
4. Add $10-20 credit to start (you can add more later)

### 2.2 Create an API Key

1. Go to https://platform.openai.com/api-keys
2. Click "Create new secret key"
3. Name it "Rosterly"
4. Copy the key (starts with `sk-...`)
5. **IMPORTANT**: Save this key somewhere safe - you can't see it again!

---

## 🚀 Step 3: Deploy API to Vercel

### 3.1 Fork This Repository to GitHub

1. Go to https://github.com (create account if needed)
2. Click "+" in top right → "New repository"
3. Name it "rosterly-api"
4. Make it Private
5. Don't initialize with README
6. Click "Create repository"
7. On your computer, open Terminal (Mac) or Command Prompt (Windows)
8. Navigate to this project folder:
   ```bash
   cd /Users/officerdevil
   ```
9. Initialize git and push to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/rosterly-api.git
   git push -u origin main
   ```

### 3.2 Deploy to Vercel

1. Go to https://vercel.com and sign up with GitHub
2. Click "New Project"
3. Import your `rosterly-api` repository
4. Vercel will auto-detect the configuration
5. Click "Deploy"
6. Wait for deployment to finish (2-3 minutes)

### 3.3 Add Environment Variables to Vercel

1. In Vercel dashboard, go to your project
2. Click "Settings" → "Environment Variables"
3. Add these variables one by one:

   | Name | Value | Where to find |
   |------|-------|---------------|
   | `SUPABASE_URL` | Your Supabase URL | Supabase Dashboard → Settings → API |
   | `SUPABASE_SERVICE_KEY` | Your Supabase service key | Supabase Dashboard → Settings → API (service_role key) |
   | `OPENAI_API_KEY` | Your OpenAI API key | OpenAI Dashboard (starts with sk-...) |
   | `VECTOR_SIM_THRESHOLD` | `0.83` | Type this value |

4. Click "Save" after adding each variable
5. Go back to "Deployments" and click "Redeploy"

### 3.4 Get Your API URL

1. After redeployment, go to your project page
2. You'll see a URL like: `https://your-project.vercel.app`
3. Copy this URL - you'll need it for the Flutter app

---

## 📱 Step 4: Set Up Flutter App (Mobile)

### 4.1 Install Flutter (One-time setup)

**On Mac:**
1. Open Terminal
2. Install Homebrew (if not already):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install Flutter:
   ```bash
   brew install --cask flutter
   ```
4. Verify installation:
   ```bash
   flutter doctor
   ```

**On Windows:**
1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add to PATH
4. Run `flutter doctor` in Command Prompt

### 4.2 Configure the Flutter App

1. Navigate to the Flutter project folder:
   ```bash
   cd /Users/officerdevil/rosterly/app
   ```

2. Open `lib/config/app_config.dart` in a text editor

3. Replace the placeholder values:
   ```dart
   static const String supabaseUrl = 'YOUR-SUPABASE-URL';  // From Step 1.3
   static const String supabaseAnonKey = 'YOUR-SUPABASE-ANON-KEY';  // From Step 1.3
   static const String apiBaseUrl = 'https://your-project.vercel.app/api';  // From Step 3.4
   ```

4. Save the file

### 4.3 Install Dependencies

In Terminal/Command Prompt:
```bash
cd /Users/officerdevil/rosterly/app
flutter pub get
```

### 4.4 Run the App

**On iOS Simulator (Mac only):**
```bash
open -a Simulator
flutter run
```

**On Android Emulator:**
```bash
flutter emulators --launch <emulator-name>
flutter run
```

**On Physical Device:**
```bash
flutter devices  # List connected devices
flutter run -d <device-id>
```

---

## 🔥 Step 5: Set Up Firebase (Push Notifications)

### 5.1 Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project"
3. Name it "Rosterly"
4. Disable Google Analytics (not needed)
5. Click "Create project"

### 5.2 Add iOS App

1. In Firebase console, click iOS icon
2. Enter iOS Bundle ID: `com.rosterly.app` (or your custom bundle ID)
3. Download `GoogleService-Info.plist`
4. Move it to `rosterly/app/ios/Runner/GoogleService-Info.plist`

### 5.3 Add Android App

1. Click Android icon
2. Enter Android Package Name: `com.rosterly.app`
3. Download `google-services.json`
4. Move it to `rosterly/app/android/app/google-services.json`

### 5.4 Get FCM Server Key

1. In Firebase console, click gear icon → Project settings
2. Go to "Cloud Messaging" tab
3. Copy "Server key"
4. Add to Vercel environment variables:
   - Name: `FCM_SERVER_KEY`
   - Value: Your server key

---

## 🎨 Step 6: Add System Roles and Initial Data

### 6.1 Create Your First Account

1. In Supabase dashboard, go to "Table Editor"
2. Open the `accounts` table
3. Click "Insert" → "Insert row"
4. Fill in:
   - `name`: Your Business Name
   - `owner_email`: Your email
   - `subscription_tier`: free
5. Click "Save"
6. Copy the generated `id` (UUID)

### 6.2 Create a Venue

1. Open the `venues` table
2. Click "Insert row"
3. Fill in:
   - `account_id`: The account ID from above
   - `name`: Your venue name (e.g., "Main Restaurant")
   - `address`: Your address
   - `timezone`: `Australia/Sydney` (or your timezone)
   - `latitude`: Your venue latitude (find on Google Maps)
   - `longitude`: Your venue longitude
   - `radius_meters`: 100
4. Click "Save"
5. Copy the venue `id`

### 6.3 Create System Roles

1. Open the `roles` table
2. Insert these three rows (repeat for each):

   **Admin Role:**
   - `account_id`: Your account ID
   - `name`: Admin
   - `description`: Full system access
   - `is_system_role`: true

   **Manager Role:**
   - `account_id`: Your account ID
   - `name`: Manager
   - `description`: Venue management
   - `is_system_role`: true

   **Staff Role:**
   - `account_id`: Your account ID
   - `name`: Staff
   - `description`: Basic staff access
   - `is_system_role`: true

3. Copy each role's `id` after creating

### 6.4 Add Permissions

For each role, add permissions in the `permissions` table:

**Admin permissions:** (Add all these rows)
- Role: Admin, Resource: rosters, Action: read
- Role: Admin, Resource: rosters, Action: write
- Role: Admin, Resource: attendance, Action: read
- Role: Admin, Resource: attendance, Action: approve
- Role: Admin, Resource: announcements, Action: write
- Role: Admin, Resource: chat, Action: write
- Role: Admin, Resource: reports, Action: read

**Manager permissions:** (Similar subset)

**Staff permissions:** (Limited subset)

---

## 👤 Step 7: Create Your First User

### 7.1 Sign Up in the App

1. Open the Rosterly app
2. You'll see the sign-in screen
3. Since you don't have an account yet, use Supabase Auth UI:

### 7.2 Create User via Supabase Dashboard

1. In Supabase, go to "Authentication" → "Users"
2. Click "Add user"
3. Enter email and password
4. Click "Create user"
5. Copy the user's UUID

### 7.3 Link User to Venue

1. Go to `user_venue_roles` table
2. Insert row:
   - `user_id`: The user UUID
   - `venue_id`: Your venue ID
   - `role_id`: Choose Manager or Staff role ID
3. Click "Save"

### 7.4 Test Sign In

1. Open Rosterly app
2. Sign in with your email/password
3. You should see the home screen!

---

## 📊 Step 8: Test Roster Upload (Managers Only)

### 8.1 Prepare a Test Roster

Create a simple roster image with:
- Column headers: Employee, Mon, Tue, Wed, Thu, Fri, Sat, Sun
- Rows with: Names, times (e.g., "9am-5pm")

Or use a real roster screenshot/PDF.

### 8.2 Upload via App

1. In the app, go to Rosters → Upload
2. Take a photo or select your roster file
3. Wait for AI processing (30-60 seconds)
4. Review extracted shifts
5. Match any unrecognized names
6. Publish the roster

### 8.3 Verify in Database

1. Go to Supabase → Table Editor → `rosters`
2. You should see a new row with status "published"
3. Check `shifts` table - you should see extracted shifts
4. Check `shift_changes` table for notification records

---

## 🔧 Troubleshooting

### "Failed to initialize Supabase"
- Check `lib/config/app_config.dart` has correct URL and key
- Verify keys don't have extra spaces
- Restart the app

### "API endpoint not found"
- Check Vercel deployment status
- Verify API_BASE_URL in Flutter config
- Check Vercel logs for errors

### "No shifts extracted"
- Ensure roster image is clear and readable
- Check OpenAI API key is valid and has credits
- Look at Vercel function logs

### "Clock in failed - outside geofence"
- Verify venue latitude/longitude are correct
- Check device location permissions are granted
- Increase radius_meters in venues table

---

## 📁 Project Structure

```
rosterly/                    # 👈 Single parent folder
├── app/                     # Flutter mobile app (iOS, Android, Web)
│   ├── lib/
│   │   ├── config/         # App configuration
│   │   ├── core/           # Core utilities, theme, router
│   │   ├── features/       # Feature modules
│   │   └── main.dart       # App entry point
│   ├── android/            # Android platform code
│   ├── ios/                # iOS platform code
│   └── pubspec.yaml        # Flutter dependencies
│
├── api/                     # TypeScript serverless functions (Vercel)
│   ├── ingest-roster.ts    # AI roster extraction endpoint
│   ├── notification-worker.ts  # Notification processing
│   ├── package.json
│   └── tsconfig.json
│
├── database/                # Database schema & migrations
│   └── schema.sql          # Complete Postgres schema with RLS
│
├── .env.example            # Environment variables template
├── .gitignore              # Git ignore rules
├── vercel.json             # Vercel deployment configuration
│
└── Documentation:
    ├── README.md           # This file (main setup guide)
    ├── QUICK_START.md      # 30-minute quick start
    ├── PLATFORM_SETUP.md   # iOS/Android configuration
    └── PROJECT_SUMMARY.md  # Architecture overview
```

---

## 🔐 Security Notes

1. **Never commit secrets to git:**
   - Create `.gitignore` with:
     ```
     .env
     lib/config/app_config.dart
     **/GoogleService-Info.plist
     **/google-services.json
     ```

2. **Use environment variables:**
   - All API keys should be in Vercel environment variables
   - Never hardcode in source code

3. **Supabase RLS:**
   - Row Level Security is enabled on all tables
   - Users can only access their own data
   - Managers can access their venue's data

---

## 🚀 Next Steps

Now that your app is running, you can:

1. **Add more staff:**
   - Create users in Supabase Auth
   - Link them to venues with roles

2. **Upload real rosters:**
   - Take photos of your actual rosters
   - Let AI extract and match names

3. **Set up reminders:**
   - Staff can configure shift reminder preferences

4. **Enable location tracking:**
   - Configure geofencing for clock in/out
   - Optional: Enable background location pings

5. **Customize the app:**
   - Change colors in `lib/core/theme/app_theme.dart`
   - Update app name in `pubspec.yaml`
   - Add your logo in `assets/images/`

---

## 📞 Support

If you run into issues:

1. Check Vercel logs: https://vercel.com/dashboard → Your Project → Logs
2. Check Supabase logs: Supabase Dashboard → Logs
3. Check Flutter logs: Run `flutter logs` in terminal
4. Check OpenAI usage: https://platform.openai.com/usage

---

## 📄 License

Proprietary - All rights reserved

---

## 🎉 You're Done!

Your Rosterly system is now live! Start uploading rosters and managing your team.

**Important reminders:**
- Keep your API keys secure
- Monitor OpenAI usage (costs ~$0.50-1.00 per roster)
- Back up your Supabase database regularly
- Test thoroughly before using in production

Need help? Create an issue in this repository.
