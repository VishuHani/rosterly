# Rosterly - Next Steps Implementation Guide

**Created:** 2025-11-01
**Current Status:** 60% Complete - Foundation Ready, Services Setup Required
**Estimated Time to MVP:** 36-52 hours

---

## Overview

This document tracks the critical path from current state (foundation complete) to a working MVP. Each step is documented with detailed instructions, expected outcomes, and checkpoints.

---

## Step 1: Set Up Services (30-45 minutes)

**Priority:** CRITICAL - Required before any feature work
**Estimated Time:** 30-45 minutes
**Status:** ⏳ Not Started

### 1.1 Set Up Supabase Project (15 minutes)

**What:** Create Supabase project and initialize database with schema

**Steps:**
1. Go to https://supabase.com and sign up/sign in
2. Click "New Project"
   - Organization: Create new or use existing
   - Name: `rosterly` or `smartroster`
   - Database Password: Generate strong password (SAVE THIS!)
   - Region: Choose closest to your users
   - Plan: Free tier is fine for development
3. Wait for project to provision (~2 minutes)

4. **Run Database Schema:**
   - Go to SQL Editor (left sidebar)
   - Click "New Query"
   - Open `/Users/officerdevil/rosterly/database/schema.sql` locally
   - Copy entire contents
   - Paste into Supabase SQL Editor
   - Click "Run" (bottom right)
   - Verify: Should see "Success. No rows returned" (965 lines executed)

5. **Enable Realtime:**
   - Go to Database → Replication (left sidebar)
   - Enable replication for these tables:
     - `chat_messages`
     - `announcements`
     - `notifications`
     - `shift_assignments`
     - `attendance`

6. **Get API Credentials:**
   - Go to Settings → API
   - Copy these values (you'll need them):
     - `Project URL` (e.g., https://xxxxx.supabase.co)
     - `anon public` key
     - `service_role` key (click "Reveal" button)

**Checkpoint:**
- [ ] Database schema successfully executed
- [ ] Realtime enabled on 5 tables
- [ ] API credentials saved securely

**Expected Outcome:**
- Supabase project with 21 tables
- All RLS policies active
- pgvector extension enabled
- Realtime subscriptions ready

---

### 1.2 Set Up Vercel Project (10 minutes)

**What:** Deploy API endpoints to Vercel serverless platform

**Steps:**
1. Go to https://vercel.com and sign up/sign in
2. Click "Add New..." → "Project"
3. **Option A: Import from Git (Recommended)**
   - Connect GitHub account
   - Push rosterly repo to GitHub first:
     ```bash
     cd /Users/officerdevil/rosterly
     # Create GitHub repo, then:
     git remote add origin https://github.com/yourusername/rosterly.git
     git push -u origin main
     ```
   - Import the repository in Vercel
   - Root Directory: Leave as `.` (root)
   - Framework Preset: Other
   - Build Command: Leave empty
   - Output Directory: Leave empty

4. **Option B: Deploy via CLI**
   ```bash
   cd /Users/officerdevil/rosterly
   npm install -g vercel
   vercel login
   vercel
   # Follow prompts
   ```

5. **Add Environment Variables:**
   - Go to Project Settings → Environment Variables
   - Add these variables (all environments: Production, Preview, Development):
     - `SUPABASE_URL` = Your Project URL from step 1.1
     - `SUPABASE_SERVICE_KEY` = Your service_role key from step 1.1
     - `OPENAI_API_KEY` = Your OpenAI API key (get from step 1.3)

6. **Redeploy:**
   - Go to Deployments tab
   - Click "..." on latest deployment → "Redeploy"
   - Or push a commit to trigger auto-deploy

**Checkpoint:**
- [ ] Vercel project created
- [ ] Environment variables added
- [ ] Deployment successful (green checkmark)
- [ ] API endpoints accessible

**Expected Outcome:**
- `/api/ingest-roster` endpoint live
- `/api/notification-worker` cron job running every 10 minutes
- Environment variables configured

**Verify:**
```bash
# Test endpoint (replace with your Vercel URL)
curl https://your-project.vercel.app/api/ingest-roster
# Should return 405 Method Not Allowed (because we didn't POST)
```

---

### 1.3 Set Up OpenAI API (5 minutes)

**What:** Get API key for AI-powered roster extraction

**Steps:**
1. Go to https://platform.openai.com
2. Sign up or sign in
3. Go to Settings → Billing
   - Add payment method
   - Set up usage limits (recommended: $20/month to start)
4. Go to API Keys
   - Click "Create new secret key"
   - Name: `rosterly-production`
   - Copy key (starts with `sk-proj-...`)
   - SAVE THIS KEY - you can't see it again!

5. **Add to Vercel:**
   - Go back to Vercel project settings
   - Add environment variable: `OPENAI_API_KEY` = your key
   - Redeploy

**Checkpoint:**
- [ ] OpenAI account created
- [ ] Payment method added
- [ ] API key generated
- [ ] Key added to Vercel environment variables

**Expected Costs:**
- Roster extraction: ~$1.25 per image (4 rosters/month = ~$5)
- Notifications: ~$0.01 per batch
- **Total:** ~$5-20/month for small business

---

### 1.4 Set Up Firebase for Push Notifications (10-15 minutes)

**What:** Configure Firebase Cloud Messaging for push notifications

**Steps:**
1. Go to https://console.firebase.google.com
2. Click "Add project"
   - Name: `rosterly` or `smartroster`
   - Disable Google Analytics (or enable if you want it)
   - Click "Create project"

3. **Add Android App:**
   - Click Android icon
   - Android package name: `com.yourcompany.rosterly` (must match `app/android/app/build.gradle`)
   - App nickname: `Rosterly Android`
   - Click "Register app"
   - Download `google-services.json`
   - Save to: `/Users/officerdevil/rosterly/app/android/app/google-services.json`
   - Click "Next" → "Continue to console"

4. **Add iOS App:**
   - Click iOS icon (⊕)
   - iOS bundle ID: `com.yourcompany.rosterly` (must match Xcode project)
   - App nickname: `Rosterly iOS`
   - Click "Register app"
   - Download `GoogleService-Info.plist`
   - Save to: `/Users/officerdevil/rosterly/app/ios/Runner/GoogleService-Info.plist`
   - **IMPORTANT:** Also add to Xcode:
     - Open `app/ios/Runner.xcworkspace` in Xcode
     - Drag `GoogleService-Info.plist` into Runner folder
     - Check "Copy items if needed"

5. **Enable Cloud Messaging:**
   - Go to Project Settings → Cloud Messaging
   - Cloud Messaging API: Click "Enable"
   - (May be enabled by default)

6. **Get Server Key (for API):**
   - Go to Project Settings → Cloud Messaging
   - Under "Cloud Messaging API (Legacy)", copy "Server key"
   - Add to Vercel environment variables: `FCM_SERVER_KEY`

**Checkpoint:**
- [ ] Firebase project created
- [ ] `google-services.json` downloaded and placed in `app/android/app/`
- [ ] `GoogleService-Info.plist` downloaded and added to Xcode
- [ ] Cloud Messaging enabled
- [ ] Server key added to Vercel

**Expected Outcome:**
- Firebase ready for iOS and Android
- Push notifications can be sent from backend

---

### 1.5 Update Flutter App Configuration (5 minutes)

**What:** Replace placeholder values with real credentials

**File to Edit:** `/Users/officerdevil/rosterly/app/lib/config/app_config.dart`

**Changes:**
```dart
class AppConfig {
  // Replace with your actual Supabase URL
  static const String supabaseUrl = 'https://xxxxx.supabase.co'; // From step 1.1

  // Replace with your actual Supabase anon key
  static const String supabaseAnonKey = 'eyJh...'; // From step 1.1

  // App metadata (customize as needed)
  static const String appName = 'Rosterly';
  static const String appVersion = '1.0.0';
}
```

**Also Uncomment Firebase Initialization:**

**File:** `/Users/officerdevil/rosterly/app/lib/main.dart`

Find this section (around line 20-25):
```dart
// TODO: Initialize Firebase after adding google-services.json and GoogleService-Info.plist
// await Firebase.initializeApp(
//   options: DefaultFirebaseOptions.currentPlatform,
// );
```

Uncomment it:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Checkpoint:**
- [ ] `app_config.dart` updated with real Supabase credentials
- [ ] Firebase initialization uncommented in `main.dart`
- [ ] Changes committed to git

**Expected Outcome:**
- Flutter app can connect to Supabase
- Firebase initialized on app startup

---

## Step 2: Implement Roster Upload UI (4-6 hours)

**Priority:** HIGH - Core feature demonstrating value proposition
**Estimated Time:** 4-6 hours
**Status:** ⏳ Not Started
**Dependencies:** Step 1 (Services Setup) must be complete

### 2.1 Overview

**What:** Allow managers to upload roster images, preview extracted data, disambiguate names, and publish to staff

**Current State:** Scaffold page exists at `app/lib/features/roster/presentation/pages/roster_upload_page.dart`

**Target Outcome:**
- Manager can pick image from gallery or take photo
- Image sent to `/api/ingest-roster` endpoint
- Extracted shifts displayed in preview
- Unmatched names show disambiguation UI
- Manager confirms and publishes roster
- Staff see shifts in their schedule

### 2.2 Implementation Tasks

**Task 2.1.1:** Add Image Picker Integration (1 hour)
**File:** `app/lib/features/roster/presentation/pages/roster_upload_page.dart`

**Implementation:**
```dart
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// Add state for selected file
File? _selectedFile;
final ImagePicker _imagePicker = ImagePicker();

// Image picker methods
Future<void> _pickImageFromGallery() async {
  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
  );
  if (image != null) {
    setState(() => _selectedFile = File(image.path));
  }
}

Future<void> _pickImageFromCamera() async {
  final XFile? image = await _imagePicker.pickImage(
    source: ImageSource.camera,
  );
  if (image != null) {
    setState(() => _selectedFile = File(image.path));
  }
}

Future<void> _pickFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (result != null && result.files.single.path != null) {
    setState(() => _selectedFile = File(result.files.single.path!));
  }
}
```

**UI Elements:**
- Button: "Take Photo" → calls `_pickImageFromCamera()`
- Button: "Choose from Gallery" → calls `_pickImageFromGallery()`
- Button: "Upload PDF" → calls `_pickFile()`
- Image preview when `_selectedFile != null`

**Checkpoint:**
- [ ] Image picker buttons implemented
- [ ] Selected image displays in preview
- [ ] Supports camera, gallery, and file picker

---

**Task 2.1.2:** Create Roster Upload Provider (1.5 hours)
**File:** `app/lib/features/roster/providers/roster_provider.dart` (NEW)

**Implementation:**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

part 'roster_provider.g.dart';

@riverpod
class RosterUpload extends _$RosterUpload {
  @override
  AsyncValue<Map<String, dynamic>?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> uploadRoster({
    required File imageFile,
    required String venueId,
    required DateTime weekStartDate,
  }) async {
    state = const AsyncValue.loading();

    try {
      // 1. Upload image to Supabase Storage
      final fileName = 'roster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageResponse = await Supabase.instance.client.storage
          .from('roster-images')
          .upload(fileName, imageFile);

      final imageUrl = Supabase.instance.client.storage
          .from('roster-images')
          .getPublicUrl(fileName);

      // 2. Call ingest-roster API
      final response = await http.post(
        Uri.parse('https://your-vercel-project.vercel.app/api/ingest-roster'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageUrl': imageUrl,
          'venueId': venueId,
          'weekStartDate': weekStartDate.toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process roster: ${response.body}');
      }

      final result = jsonDecode(response.body);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
```

**Checkpoint:**
- [ ] Provider created with upload method
- [ ] Image uploads to Supabase Storage
- [ ] API call to ingest-roster endpoint
- [ ] Results stored in state

---

**Task 2.1.3:** Build Preview UI with Extracted Data (1.5 hours)
**File:** `roster_upload_page.dart`

**Implementation:**
- Display extracted shifts in a ListView
- Show confidence scores
- Color-code: High confidence (green), Medium (yellow), Needs review (red)
- Allow editing of individual shift details

**UI Structure:**
```dart
// After successful upload
if (uploadResult != null) {
  ListView.builder(
    itemCount: uploadResult['shifts'].length,
    itemBuilder: (context, index) {
      final shift = uploadResult['shifts'][index];
      return ShiftPreviewCard(
        employeeName: shift['employeeName'],
        date: shift['date'],
        startTime: shift['startTime'],
        endTime: shift['endTime'],
        role: shift['role'],
        confidence: shift['confidence'],
        onEdit: () => _editShift(shift),
      );
    },
  );
}
```

**Checkpoint:**
- [ ] Shifts display in list format
- [ ] Confidence scores visible
- [ ] Edit functionality for individual shifts

---

**Task 2.1.4:** Build Name Disambiguation UI (1.5 hours)
**File:** `roster_upload_page.dart` or new widget `name_disambiguation_dialog.dart`

**Implementation:**
- Display unmatched names from API response
- Show suggested matches with similarity scores
- Allow manual selection from venue staff list
- Allow "Add New Employee" option

**UI Structure:**
```dart
// Show dialog if unmatchedNames.isNotEmpty
void _showNameDisambiguation(List<dynamic> unmatchedNames) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Match Employee Names'),
      content: Column(
        children: unmatchedNames.map((unmatched) {
          return NameMatchCard(
            extractedName: unmatched['extractedName'],
            suggestions: unmatched['suggestions'],
            onMatch: (userId) => _linkName(unmatched['id'], userId),
            onAddNew: () => _createNewEmployee(unmatched['extractedName']),
          );
        }).toList(),
      ),
    ),
  );
}
```

**Checkpoint:**
- [ ] Unmatched names displayed
- [ ] Suggested matches shown with scores
- [ ] Can select correct employee
- [ ] Can create new employee

---

**Task 2.1.5:** Publish Confirmation Flow (30 minutes)
**File:** `roster_upload_page.dart`

**Implementation:**
- Show summary of changes (if new version)
- Display count of shifts added/modified/removed
- Confirmation button to publish roster
- Call API to finalize roster and trigger notifications

**Checkpoint:**
- [ ] Change summary displayed
- [ ] Confirm button publishes roster
- [ ] Success message shown
- [ ] Navigate back to roster list

---

### 2.3 Testing Checklist

- [ ] Take photo with camera → Upload successful
- [ ] Choose from gallery → Upload successful
- [ ] Upload PDF → Upload successful
- [ ] Extracted shifts display correctly
- [ ] High confidence names auto-matched
- [ ] Low confidence names show disambiguation
- [ ] Manual name matching works
- [ ] Create new employee works
- [ ] Publish confirmation shows changes
- [ ] Published roster visible in database
- [ ] Staff users can see their shifts (test in Step 4)

---

## Step 3: Complete FCM Push Notification Integration (2-3 hours)

**Priority:** HIGH - Completes core notification system
**Estimated Time:** 2-3 hours
**Status:** ⏳ Not Started
**Dependencies:** Step 1.4 (Firebase Setup) must be complete

### 3.1 Overview

**What:** Complete the stubbed FCM push sending in notification-worker.ts

**Current State:** Worker detects changes and generates notification text, but FCM sending is stubbed

**Target Outcome:**
- Notification worker sends actual push notifications via FCM
- Staff receive notifications on their devices
- Notification history logged in database

### 3.2 Implementation Tasks

**Task 3.2.1:** Install FCM Admin SDK in API (30 minutes)
**Location:** `/Users/officerdevil/rosterly/api/`

**Steps:**
```bash
cd /Users/officerdevil/rosterly/api
npm install firebase-admin
```

**File:** `api/notification-worker.ts`

Add imports:
```typescript
import * as admin from 'firebase-admin';

// Initialize Firebase Admin (add at top of file)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}
```

**Checkpoint:**
- [ ] firebase-admin installed
- [ ] Firebase Admin initialized in worker

---

**Task 3.2.2:** Add FCM Environment Variables to Vercel (15 minutes)

**Steps:**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key" → Download JSON
3. Open JSON file and extract:
   - `project_id`
   - `client_email`
   - `private_key`

4. Add to Vercel environment variables:
   - `FIREBASE_PROJECT_ID` = value from JSON
   - `FIREBASE_CLIENT_EMAIL` = value from JSON
   - `FIREBASE_PRIVATE_KEY` = value from JSON (entire key including `-----BEGIN PRIVATE KEY-----`)

**Checkpoint:**
- [ ] Service account JSON downloaded
- [ ] Environment variables added to Vercel
- [ ] Vercel project redeployed

---

**Task 3.2.3:** Implement FCM Sending Function (1 hour)
**File:** `api/notification-worker.ts`

**Find the stubbed section (around line 250):**
```typescript
// TODO: Send actual push notification via FCM
console.log('Would send FCM notification:', {
  userId,
  title,
  body: notificationText,
});
```

**Replace with:**
```typescript
// Get user's FCM token
const { data: userData, error: userError } = await supabase
  .from('users')
  .select('fcm_token')
  .eq('id', userId)
  .single();

if (userError || !userData?.fcm_token) {
  console.warn(`No FCM token for user ${userId}`);
  continue;
}

// Send FCM notification
try {
  const message = {
    token: userData.fcm_token,
    notification: {
      title: title,
      body: notificationText,
    },
    data: {
      type: notificationType,
      shiftId: shiftId || '',
      timestamp: new Date().toISOString(),
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
    android: {
      priority: 'high' as const,
      notification: {
        sound: 'default',
        channelId: 'shift_notifications',
      },
    },
  };

  const response = await admin.messaging().send(message);
  console.log('Successfully sent FCM notification:', response);

  // Log to database
  await supabase.from('notifications').insert({
    user_id: userId,
    type: notificationType,
    title: title,
    message: notificationText,
    sent_at: new Date().toISOString(),
    fcm_message_id: response,
  });

} catch (fcmError) {
  console.error('Failed to send FCM notification:', fcmError);
  // Continue with other notifications even if one fails
}
```

**Checkpoint:**
- [ ] FCM token retrieved from database
- [ ] Notification sent via Firebase Admin SDK
- [ ] iOS and Android specific settings configured
- [ ] Notification logged to database
- [ ] Error handling implemented

---

**Task 3.2.4:** Update Flutter App to Handle FCM Tokens (1 hour)
**File:** `app/lib/main.dart` and `app/lib/features/auth/providers/auth_provider.dart`

**main.dart - Add FCM initialization:**
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Add after Firebase.initializeApp()
Future<void> _initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission (iOS)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // Get FCM token
    String? token = await messaging.getToken();
    if (token != null) {
      // Save to Supabase user record
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_saveFCMToken);
  }
}

Future<void> _saveFCMToken(String token) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    await Supabase.instance.client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', user.id);
  }
}
```

**Checkpoint:**
- [ ] FCM permission requested on app startup
- [ ] FCM token saved to user record in database
- [ ] Token refresh handled

---

### 3.3 Testing Checklist

- [ ] Deploy updated notification-worker to Vercel
- [ ] Manually trigger worker (or wait for cron)
- [ ] Check Vercel logs for "Successfully sent FCM notification"
- [ ] Check Firebase Console → Cloud Messaging for sent messages
- [ ] Check device receives notification
- [ ] Check `notifications` table in Supabase for logged entry
- [ ] Test on both iOS and Android
- [ ] Test notification tap opens app to correct screen

---

## Step 4: Implement Shift Viewing (4-6 hours)

**Priority:** MEDIUM-HIGH - Core staff feature
**Estimated Time:** 4-6 hours
**Status:** ⏳ Not Started
**Dependencies:** Step 2 (Roster Upload) must be complete to have data to display

### 4.1 Overview

**What:** Allow staff to view their assigned shifts in calendar and list formats

**Current State:** Scaffold page exists at `app/lib/features/roster/presentation/pages/roster_list_page.dart`

**Target Outcome:**
- Staff see upcoming shifts
- Calendar view and list view toggle
- Shift details (time, role, venue)
- Visual indicators for today, upcoming, past shifts

### 4.2 Implementation Tasks

**Task 4.2.1:** Create Shifts Provider (1.5 hours)
**File:** `app/lib/features/roster/providers/shifts_provider.dart` (NEW)

**Implementation:**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'shifts_provider.g.dart';

@riverpod
class UserShifts extends _$UserShifts {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _fetchUserShifts();
  }

  Future<List<Map<String, dynamic>>> _fetchUserShifts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Call Supabase function to get user's shifts
    final response = await Supabase.instance.client
        .rpc('get_user_shifts', params: {'p_user_id': user.id});

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchUserShifts());
  }
}

// Provider for shifts filtered by date range
@riverpod
Future<List<Map<String, dynamic>>> shiftsInRange(
  ShiftsInRangeRef ref,
  DateTime start,
  DateTime end,
) async {
  final allShifts = await ref.watch(userShiftsProvider.future);
  return allShifts.where((shift) {
    final shiftDate = DateTime.parse(shift['date']);
    return shiftDate.isAfter(start) && shiftDate.isBefore(end);
  }).toList();
}
```

**Checkpoint:**
- [ ] Provider fetches shifts from Supabase
- [ ] Uses `get_user_shifts` RLS function
- [ ] Supports refresh
- [ ] Date range filtering available

---

**Task 4.2.2:** Build List View UI (1.5 hours)
**File:** `app/lib/features/roster/presentation/pages/roster_list_page.dart`

**Implementation:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final shiftsAsync = ref.watch(userShiftsProvider);

  return Scaffold(
    appBar: AppBar(title: Text('My Shifts')),
    body: shiftsAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (shifts) {
        if (shifts.isEmpty) {
          return Center(child: Text('No shifts scheduled'));
        }

        // Group shifts by date
        final groupedShifts = _groupShiftsByDate(shifts);

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(userShiftsProvider.notifier).refresh();
          },
          child: ListView.builder(
            itemCount: groupedShifts.length,
            itemBuilder: (context, index) {
              final date = groupedShifts.keys.elementAt(index);
              final dayShifts = groupedShifts[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      _formatDate(date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...dayShifts.map((shift) => ShiftCard(shift: shift)),
                ],
              );
            },
          ),
        );
      },
    ),
  );
}
```

**Create ShiftCard widget:**
```dart
class ShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(_getShiftIcon(shift['role'])),
        title: Text('${shift['start_time']} - ${shift['end_time']}'),
        subtitle: Text(shift['role'] ?? 'Staff'),
        trailing: _buildShiftStatus(shift),
        onTap: () => _showShiftDetails(context, shift),
      ),
    );
  }
}
```

**Checkpoint:**
- [ ] Shifts grouped by date
- [ ] Pull-to-refresh implemented
- [ ] Empty state shown when no shifts
- [ ] Shift cards display time and role
- [ ] Tap opens shift details

---

**Task 4.2.3:** Add Calendar View (2 hours)
**File:** `roster_list_page.dart`

**Add dependency:**
```yaml
# pubspec.yaml
dependencies:
  table_calendar: ^3.0.9
```

**Implementation:**
```dart
import 'package:table_calendar/table_calendar.dart';

class RosterListPage extends ConsumerStatefulWidget {
  // Add view toggle state
  bool _isCalendarView = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Shifts'),
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month),
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
          ),
        ],
      ),
      body: _isCalendarView ? _buildCalendarView() : _buildListView(),
    );
  }

  Widget _buildCalendarView() {
    final shiftsAsync = ref.watch(userShiftsProvider);

    return shiftsAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (shifts) {
        return TableCalendar(
          firstDay: DateTime.now().subtract(Duration(days: 90)),
          lastDay: DateTime.now().add(Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            // Return shifts for this day
            return shifts.where((shift) {
              final shiftDate = DateTime.parse(shift['date']);
              return isSameDay(shiftDate, day);
            }).toList();
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isNotEmpty) {
                return Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  width: 8,
                  height: 8,
                );
              }
              return null;
            },
          ),
        );
      },
    );
  }
}
```

**Checkpoint:**
- [ ] Calendar displays with shift markers
- [ ] Toggle between list and calendar view
- [ ] Selected day shows shift details below calendar
- [ ] Events loader shows shifts for each day

---

**Task 4.2.4:** Add Shift Details Sheet (1 hour)
**File:** `roster_list_page.dart` or new widget file

**Implementation:**
```dart
void _showShiftDetails(BuildContext context, Map<String, dynamic> shift) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(DateTime.parse(shift['date'])),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          _buildDetailRow(Icons.access_time, '${shift['start_time']} - ${shift['end_time']}'),
          _buildDetailRow(Icons.work, shift['role'] ?? 'Staff'),
          _buildDetailRow(Icons.location_on, shift['venue_name'] ?? 'Unknown'),
          _buildDetailRow(Icons.timer, '${shift['duration_hours']} hours'),
          if (shift['notes'] != null)
            _buildDetailRow(Icons.note, shift['notes']),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  label: Text('Mark as Confirmed'),
                  onPressed: () => _confirmShift(shift['id']),
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                icon: Icon(Icons.calendar_today),
                label: Text('Add to Calendar'),
                onPressed: () => _addToCalendar(shift),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

**Checkpoint:**
- [ ] Bottom sheet shows full shift details
- [ ] Displays date, time, role, venue, duration
- [ ] Shows notes if present
- [ ] Actions: Confirm shift, Add to calendar

---

### 4.3 Testing Checklist

- [ ] List view displays all shifts
- [ ] Shifts grouped by date correctly
- [ ] Pull-to-refresh updates shifts
- [ ] Calendar view shows shift markers
- [ ] Tapping date shows shifts for that day
- [ ] Toggle between list and calendar works
- [ ] Shift details sheet opens on tap
- [ ] All shift information displayed correctly
- [ ] Empty state shows when no shifts
- [ ] Loading state shows during fetch

---

## Progress Tracking

**Use this checklist to track overall progress:**

### Services Setup:
- [ ] Step 1.1: Supabase project created and schema loaded
- [ ] Step 1.2: Vercel project deployed with env vars
- [ ] Step 1.3: OpenAI API key configured
- [ ] Step 1.4: Firebase project created for FCM
- [ ] Step 1.5: Flutter app config updated

### Roster Upload:
- [ ] Step 2.1.1: Image picker implemented
- [ ] Step 2.1.2: Upload provider created
- [ ] Step 2.1.3: Preview UI built
- [ ] Step 2.1.4: Name disambiguation UI built
- [ ] Step 2.1.5: Publish confirmation flow complete

### Push Notifications:
- [ ] Step 3.2.1: FCM Admin SDK installed
- [ ] Step 3.2.2: Firebase env vars added to Vercel
- [ ] Step 3.2.3: FCM sending implemented in worker
- [ ] Step 3.2.4: Flutter app handles FCM tokens

### Shift Viewing:
- [ ] Step 4.2.1: Shifts provider created
- [ ] Step 4.2.2: List view UI built
- [ ] Step 4.2.3: Calendar view added
- [ ] Step 4.2.4: Shift details sheet implemented

---

## Git Workflow

**After completing each major step, commit your changes:**

```bash
git add .
git commit -m "feat: [description of what you implemented]

- Detailed change 1
- Detailed change 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push
```

---

## Estimated Timeline

| Step | Estimated Time | Cumulative |
|------|----------------|------------|
| 1. Services Setup | 30-45 min | 0.75 hrs |
| 2. Roster Upload UI | 4-6 hrs | 5-7 hrs |
| 3. FCM Integration | 2-3 hrs | 7-10 hrs |
| 4. Shift Viewing | 4-6 hrs | 11-16 hrs |
| **Total** | **11-16 hours** | **MVP Core Features** |

After these steps, you'll have:
- Working roster upload with AI extraction
- Push notifications for shift changes
- Staff can view their shifts
- Core value proposition demonstrated

---

**Next Steps After This:** See `INITIAL_PLAN.md` for remaining features (attendance, chat, announcements, polish)

**Created:** 2025-11-01
**Status:** Ready to execute
