# 🚀 Chatzilla - Play Store Release Guide

This guide provides everything needed to publish Chatzilla on Google Play Store.

---

## 📋 Pre-Release Checklist

| # | Task | Status |
|---|------|--------|
| 1 | Update Application ID | ⬜ |
| 2 | Generate Release Keystore | ⬜ |
| 3 | Configure Signing | ⬜ |
| 4 | Build Release AAB | ⬜ |
| 5 | Test Release Build | ⬜ |
| 6 | Prepare Store Listing | ⬜ |
| 7 | Upload to Play Console | ⬜ |

---

## 1️⃣ Update Application ID

**Current ID:** `com.example.chatzilla` (Must be changed - Play Store rejects "example")

**Edit:** `android/app/build.gradle.kts`

```kotlin
applicationId = "com.yourcompany.chatzilla"  // Change this!
```

> ⚠️ **Warning:** Once published, the Application ID cannot be changed. Choose carefully!

---

## 2️⃣ Generate Release Keystore

Run this command to create your signing keystore:

```bash
# Create keystore directory
mkdir -p android/keystore

# Generate keystore (answer prompts carefully)
keytool -genkey -v -keystore android/keystore/chatzilla-release.keystore \
  -alias chatzilla -keyalg RSA -keysize 2048 -validity 10000
```

**🔐 CRITICAL: Store these securely!**
- Keystore file (`chatzilla-release.keystore`)
- Keystore password
- Key alias (`chatzilla`)
- Key password

> 🚨 **If you lose the keystore, you cannot update your app on Play Store!**

---

## 3️⃣ Configure Signing

### Option A: Environment Variables (Recommended)

```bash
# Set before building
export KEYSTORE_PASSWORD="your_keystore_password"
export KEY_PASSWORD="your_key_password"
```

### Option B: Local Properties File

Create `android/key.properties` (add to `.gitignore`!):

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
storeFile=../keystore/chatzilla-release.keystore
keyAlias=chatzilla
```

---

## 4️⃣ Build Release AAB

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build release AAB
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

---

## 5️⃣ Test Release Build

```bash
# Install on device to test
flutter install --release

# Or build APK for direct testing
flutter build apk --release
```

---

## 6️⃣ Play Store Console Requirements

### Required Assets

| Asset | Specification | Location |
|-------|--------------|----------|
| **App Icon** | 512x512 PNG | `assets/logo/chatzilla_logo.png` |
| **Feature Graphic** | 1024x500 PNG | Need to create |
| **Screenshots** | Min 2, phone size | `screenshots/` folder |
| **Short Description** | Max 80 chars | See below |
| **Full Description** | Max 4000 chars | See below |

### Suggested Descriptions

**Short Description (80 chars):**
```
Real-time chat app with Firebase - secure messaging, groups, and notifications
```

**Full Description:**
```
Chatzilla - Your Modern Chat Companion

📱 FEATURES:
• Real-time messaging powered by Firebase
• Group chat creation and management
• Push notifications to stay connected
• Contact synchronization
• User blocking for privacy
• Clean, modern interface

🔐 SECURITY:
• Firebase Authentication
• Secure data storage with Cloud Firestore
• Privacy controls

💬 MESSAGING:
• Instant message delivery
• Chat history sync across devices
• Emoji support
• Read receipts

Download Chatzilla today and experience seamless communication!
```

### Additional Requirements

| Requirement | Notes |
|-------------|-------|
| **Privacy Policy URL** | Required - host on your website |
| **Content Rating** | Complete questionnaire in Play Console |
| **Target Audience** | Select appropriate age groups |
| **App Category** | Communication |

---

## 7️⃣ Included Files

| File | Purpose |
|------|---------|
| `screenshots/*.png` | 16 app screenshots for store listing |
| `assets/logo/chatzilla_logo.png` | App icon (512x512) |
| `ChatZilla User Manual.pdf` | User documentation |
| `README.md` | Feature descriptions |

---

## 🔧 Troubleshooting

**Build fails with signing error:**
- Verify keystore path is correct
- Check environment variables are set
- Ensure keystore password is correct

**App crashes on release:**
- Check ProGuard rules in `android/app/proguard-rules.pro`
- Review logs with `adb logcat`

**Upload rejected:**
- Ensure Application ID is not `com.example.*`
- Verify AAB is signed correctly
- Check version code is incremented for updates

---

## 📞 Support

For technical issues, refer to:
- Flutter docs: https://flutter.dev/docs/deployment/android
- Play Console help: https://support.google.com/googleplay/android-developer

---

*Generated: December 2024*
