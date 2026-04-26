# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest `main` | ✅ |
| Older branches | ❌ |

## Reporting a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

If you discover a security vulnerability in AniMatch, please report it responsibly:

1. **Email**: Open a GitHub private security advisory via **Security → Report a vulnerability** on this repository.
2. **What to include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. **Response time**: You will receive acknowledgement within **48 hours** and a resolution plan within **7 days**.

We appreciate responsible disclosure and will credit contributors who report valid issues.

---

## Secret Handling Policy

### ✅ What IS safe to commit

| File | Reason |
|------|--------|
| `lib/firebase_options.dart` | Reads credentials from `.env` at runtime — no hardcoded secrets |
| `.env.example` | Template with placeholder values only |
| `CONTRIBUTING.md`, `README.md` | Documentation — no credentials |
| All `.dart` source files | Zero hardcoded API keys, OAuth IDs, or tokens |

### ❌ What must NEVER be committed

| File | Reason |
|------|--------|
| `.env` | Contains real Firebase credentials |
| `android/app/google-services.json` | Contains real Firebase Android config |
| `ios/Runner/GoogleService-Info.plist` | Contains real Firebase iOS config |
| `*.jks` / `*.keystore` / `key.properties` | Android signing keys |
| `upload-keystore.jks` | Release signing key |
| `serviceAccountKey.json` | Firebase admin SDK credentials — full DB access |
| `firebase-adminsdk.json` | Same as above |

All of the above are covered by `.gitignore`.

---

## Firebase Configuration Policy

### For contributors
- Never share or commit your Firebase project credentials.
- Download `google-services.json` from your own Firebase project and place it locally in `android/app/`.
- Download `GoogleService-Info.plist` from your own Firebase project and place it locally in `ios/Runner/`.
- Copy `.env.example` → `.env` and fill in your project values.
- See [firebase_setup.md](firebase_setup.md) for step-by-step setup.

### Firestore Security Rules
The production Firestore rules must enforce per-user data isolation:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

**There must be no public read/write rules.** Any PR that weakens Firestore security rules will be rejected.

---

## Crash Reporting (Crashlytics)

- Firebase Crashlytics is **disabled in debug mode** (`kDebugMode` guard).
- Only the user's Firebase Auth UID is attached to crash reports — no PII (name, email, IP) is collected.
- Crashlytics is active only in release builds.

---

## Responsible Disclosure

AniMatch follows the [Responsible Disclosure](https://en.wikipedia.org/wiki/Responsible_disclosure) model. We ask that reporters:

1. Give us reasonable time to fix the issue before any public disclosure.
2. Not exploit the vulnerability for any malicious purpose.
3. Not access or modify other users' data during testing.

Thank you for helping keep AniMatch safe! 🙏
