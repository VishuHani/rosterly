# Platform-Specific Setup Guide

This guide covers iOS and Android platform configuration for Rosterly.

---

## 📱 iOS Setup

### Prerequisites
- Mac computer with macOS 12+
- Xcode 14+ installed from App Store
- Apple Developer Account ($99/year for App Store distribution)

### 1. Configure iOS Project

1. Open iOS project in Xcode:
   ```bash
   cd rosterly
   open ios/Runner.xcworkspace
   ```

2. In Xcode, select Runner target → General:
   - **Display Name**: Rosterly
   - **Bundle Identifier**: `com.yourcompany.rosterly` (must be unique)
   - **Version**: 1.0.0
   - **Build**: 1

3. Select Runner → Signing & Capabilities:
   - **Team**: Select your Apple Developer team
   - **Automatically manage signing**: ✓ (enabled)

### 2. Add Required Capabilities

In Xcode, Runner → Signing & Capabilities, click "+ Capability":

1. **Push Notifications** (for shift reminders)
2. **Background Modes**:
   - ✓ Location updates (for background location pings)
   - ✓ Background fetch (for notifications)
   - ✓ Remote notifications (for push)

### 3. Configure Info.plist

Open `ios/Runner/Info.plist` and add these keys:

```xml
<!-- Location permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to verify you're at the venue when clocking in/out.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We track your location during shifts to verify attendance (you can disable this in Settings).</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Background location is used to verify you're on-site during your shift.</string>

<!-- Camera for roster photos -->
<key>NSCameraUsageDescription</key>
<string>Take photos of your roster to upload.</string>

<!-- Photo library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Select roster images from your photo library.</string>

<!-- Notifications -->
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
  <string>location</string>
</array>
```

### 4. Firebase Configuration

1. Download `GoogleService-Info.plist` from Firebase Console
2. Drag it into Xcode under `Runner/Runner` folder
3. Ensure "Copy items if needed" is checked

### 5. Build & Run on iOS

```bash
# Simulator
flutter run -d iPhone

# Physical device
flutter run -d <device-id>

# Build for release
flutter build ios --release
```

### 6. App Store Distribution

1. In Xcode, Product → Archive
2. Wait for build to complete
3. Click "Distribute App"
4. Choose "App Store Connect"
5. Follow the wizard

**App Store Requirements:**
- Screenshots (6.5", 5.5", 12.9" iPad)
- Privacy Policy URL (required for location tracking)
- Background location justification (explain why you need it)
- App description (max 4000 chars)

---

## 🤖 Android Setup

### Prerequisites
- Android Studio installed
- Java JDK 11 or higher
- Google Play Developer Account ($25 one-time fee)

### 1. Configure Android Project

1. Open `android/app/build.gradle`:

```gradle
android {
    namespace "com.yourcompany.rosterly"  // Change this
    compileSdk 34

    defaultConfig {
        applicationId "com.yourcompany.rosterly"  // Must match iOS bundle ID
        minSdk 23  // Android 6.0
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

2. Open `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application
        android:label="Rosterly"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- ... existing activity config ... -->

        <!-- WorkManager for background tasks -->
        <provider
            android:name="androidx.startup.InitializationProvider"
            android:authorities="${applicationId}.androidx-startup"
            android:exported="false"
            tools:node="merge">
            <meta-data
                android:name="androidx.work.WorkManagerInitializer"
                android:value="androidx.startup" />
        </provider>

    </application>
</manifest>
```

### 2. Firebase Configuration

1. Download `google-services.json` from Firebase Console
2. Place it at: `android/app/google-services.json`

3. Add Firebase to `android/build.gradle`:

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

4. Add to `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 3. App Signing (for Release)

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ~/rosterly-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rosterly
   ```

2. Create `android/key.properties`:
   ```properties
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=rosterly
   storeFile=/path/to/rosterly-keystore.jks
   ```

3. Update `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

### 4. Background Location Service

For Android 10+, background location requires a foreground service notification:

1. Create `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="app_name">Rosterly</string>
    <string name="notification_channel_name">Shift Tracking</string>
    <string name="notification_title">Tracking your shift</string>
    <string name="notification_content">Location is being tracked for attendance verification</string>
</resources>
```

2. The geofence_service package handles the foreground service automatically.

### 5. Build & Run on Android

```bash
# Debug build
flutter run -d android

# Release build (APK)
flutter build apk --release

# Release build (App Bundle for Play Store)
flutter build appbundle --release
```

### 6. Google Play Store Distribution

1. Go to https://play.google.com/console
2. Create new app
3. Fill in app details:
   - **App name**: Rosterly
   - **Category**: Business
   - **Privacy Policy**: (required, see template below)

4. Upload app bundle: `build/app/outputs/bundle/release/app-release.aab`

5. Fill out store listing:
   - Description
   - Screenshots (Phone: 16:9, Tablet: 16:9)
   - Feature graphic (1024x500)

**Play Store Requirements:**
- Privacy Policy (required for location access)
- Data Safety form (declare location, personal info collection)
- Target API Level 33+ (Android 13)

---

## 🖼️ App Icons

Generate app icons for both platforms:

### Using flutter_launcher_icons

1. Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"  # 1024x1024 PNG
  adaptive_icon_background: "#2563EB"  # Your brand color
  adaptive_icon_foreground: "assets/icon/foreground.png"
```

2. Generate icons:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

---

## 📋 Privacy Policy Template

Both app stores require a privacy policy URL. Here's a template:

```markdown
# Rosterly Privacy Policy

Last updated: [DATE]

## Information We Collect

1. **Account Information**: Email, name, phone number
2. **Location Data**: GPS coordinates when clocking in/out and during shifts (opt-in)
3. **Work Data**: Shift times, attendance records, roster information
4. **Device Information**: Device tokens for push notifications

## How We Use Your Information

- Verify attendance at work locations
- Send shift reminders and schedule updates
- Enable team communication
- Generate attendance reports for managers

## Location Tracking

Background location tracking is **optional** and only active during your scheduled shifts. You can:
- Disable it in Settings → Privacy & Location
- Revoke location permissions in your device settings
- Still use all core features without it

## Data Sharing

We do not sell or share your personal data with third parties except:
- Your employer (venue managers)
- Service providers (Supabase, Firebase) under strict contracts

## Your Rights

You can:
- Access your data
- Delete your account
- Export your data
- Opt out of non-essential tracking

## Contact

For privacy questions: privacy@rosterly.app

## Compliance

This app complies with Australian Privacy Principles (APP) and GDPR.
```

Host this at: https://your-website.com/privacy-policy

---

## 🔔 Push Notification Setup

### iOS APNs

1. In Apple Developer Portal:
   - Go to Certificates, Identifiers & Profiles
   - Create APNs Key
   - Download and upload to Firebase Console

2. In Firebase Console:
   - Project Settings → Cloud Messaging
   - iOS app configuration → Upload APNs Key

### Android FCM

1. Firebase automatically configures FCM for Android
2. No additional setup needed beyond `google-services.json`

### Test Push Notifications

1. Get device token from app logs
2. Send test notification from Firebase Console → Cloud Messaging
3. Device should receive notification

---

## 🧪 Testing Checklist

### iOS
- [ ] App launches successfully
- [ ] Sign in works
- [ ] Push notifications arrive
- [ ] Camera/photo access works
- [ ] Location permission request appears
- [ ] Clock in/out with geofence validation
- [ ] Background location indicator appears (blue bar)
- [ ] App doesn't crash when backgrounded

### Android
- [ ] App launches successfully
- [ ] Sign in works
- [ ] Push notifications arrive
- [ ] Camera/photo access works
- [ ] Location permission request appears (including background)
- [ ] Clock in/out with geofence validation
- [ ] Foreground service notification appears during shift
- [ ] WorkManager scheduling works

---

## 🐛 Common Issues

### iOS: "App installation failed"
- Check Bundle Identifier is unique
- Verify provisioning profile is valid
- Clean build folder: Product → Clean Build Folder

### Android: "google-services.json not found"
- Ensure file is at `android/app/google-services.json`
- Re-sync gradle files
- Rebuild project

### Background location not working (iOS)
- Check Info.plist has all location keys
- Verify Background Modes capability is enabled
- Ensure user granted "Always" location permission

### Push notifications not arriving
- Check Firebase server key in Vercel
- Verify device token was saved to database
- Check app has notification permission granted
- Look for errors in Firebase Console logs

---

## 📦 Build for Production

### iOS Production Build
```bash
flutter build ios --release
# Then archive in Xcode
```

### Android Production Build
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 🎯 Performance Optimization

1. **Enable code obfuscation** (Android):
   ```gradle
   buildTypes {
       release {
           minifyEnabled true
           shrinkResources true
       }
   }
   ```

2. **Reduce app size**:
   ```bash
   flutter build apk --split-per-abi
   ```

3. **Profile app performance**:
   ```bash
   flutter run --profile
   ```

---

## 📊 Monitoring & Analytics

### Crash Reporting
Consider adding:
- Sentry: https://sentry.io
- Firebase Crashlytics
- Bugsnag

### Analytics
- Firebase Analytics (already included)
- Mixpanel
- Amplitude

---

You're now ready to deploy Rosterly to both app stores! 🚀
