# Firebase Setup Guide

> This guide helps contributors set up their own Firebase project for local AniMatch development.
> **Never share your Firebase credentials or commit them to version control.**

---

## Why Do I Need My Own Firebase Project?

AniMatch uses Firebase for:
- **Authentication** (Email/Password + Google Sign-In)
- **Cloud Firestore** (watchlist sync, streaming cache, search history)
- **Crashlytics** (release-only crash reporting)

The real project credentials are never committed to this repository.
Each contributor must create their own Firebase project for local development.

---

## Step 1 — Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** → name it (e.g., `animatch-dev`)
3. Disable Google Analytics (not required for development) → **Create project**

---

## Step 2 — Enable Authentication

1. In the Firebase Console sidebar → **Build → Authentication**
2. Click **Get started**
3. Enable these sign-in methods:
   - ✅ **Email/Password** — Click → Enable → Save
   - ✅ **Google** — Click → Enable → fill in Project support email → Save

> **For Google Sign-In on Android (release builds only):**
> Go to Project Settings → Your apps → Android app → Add fingerprint.
> Add your debug SHA-1: run `./gradlew signingReport` in the `android/` directory.

---

## Step 3 — Enable Cloud Firestore

1. In the sidebar → **Build → Firestore Database**
2. Click **Create database**
3. Select **Start in production mode** → choose your region → **Done**
4. After creation, go to **Rules** tab and paste these security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read and write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }

    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5. Click **Publish**

> ⚠️ These rules are required for the app to work. Without them, all Firestore reads/writes will be denied.

---

## Step 4 — Download Android Config

1. In Firebase Console → **Project Settings** (gear icon) → **Your apps**
2. Click **Add app** → select **Android** icon
3. Enter Android package name: `com.sutharg.animatch`
4. Click **Register app**
5. Download **`google-services.json`**
6. Place it at: `android/app/google-services.json`

> ✅ This file is in `.gitignore`. It will never be committed.

---

## Step 5 — Download iOS Config (if targeting iOS)

1. In Firebase Console → **Project Settings** → **Your apps**
2. Click **Add app** → select **iOS** icon
3. Enter iOS bundle ID: `com.sutharg.animatch`
4. Click **Register app**
5. Download **`GoogleService-Info.plist`**
6. Place it at: `ios/Runner/GoogleService-Info.plist`

> ✅ This file is in `.gitignore`. It will never be committed.

---

## Step 6 — Configure Environment Variables

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Open `.env` and fill in your values from **Firebase Console → Project Settings → Your apps**:

   ```env
   FIREBASE_API_KEY=...
   FIREBASE_AUTH_DOMAIN=...
   FIREBASE_PROJECT_ID=...
   FIREBASE_STORAGE_BUCKET=...
   FIREBASE_MESSAGING_SENDER_ID=...
   FIREBASE_WEB_APP_ID=...
   FIREBASE_ANDROID_API_KEY=...
   FIREBASE_ANDROID_APP_ID=...
   FIREBASE_IOS_API_KEY=...
   FIREBASE_IOS_APP_ID=...
   FIREBASE_IOS_CLIENT_ID=...
   ```

3. For **Google Sign-In Web OAuth Client ID**:
   - Go to Firebase Console → **Authentication** → **Sign-in method** → **Google**
   - Expand **Web SDK configuration**
   - Copy the **Web client ID**
   - Add to `.env`:
     ```env
     GOOGLE_SERVER_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
     ```

> ✅ `.env` is in `.gitignore`. It will never be committed.

---

## Step 7 — Run the App

```bash
flutter pub get
flutter run
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| `google-services.json not found` | Download from Firebase Console → place in `android/app/` |
| Google Sign-In fails | Ensure SHA-1 fingerprint is added to Firebase Console for your keystore |
| Firestore permission denied | Check that Firestore security rules are published correctly |
| App crashes on iOS | Ensure `GoogleService-Info.plist` is in `ios/Runner/` |
| `.env` not loading | Ensure `.env` is in the project root (same level as `pubspec.yaml`) |

---

## Security Reminder

| File | Location | Commit? |
|------|----------|---------|
| `google-services.json` | `android/app/` | ❌ Never |
| `GoogleService-Info.plist` | `ios/Runner/` | ❌ Never |
| `.env` | project root | ❌ Never |
| `.env.example` | project root | ✅ Safe |
| `lib/firebase_options.dart` | project root | ✅ Safe (reads from .env) |
