# Firestore Security Rules

> This document specifies the production Firestore security rules required for AniMatch.
> These rules must be applied in the Firebase Console before the app will function correctly.

---

## Required Rules

Copy and paste these rules into **Firebase Console → Firestore Database → Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── User Data ─────────────────────────────────────────────────────────
    // Each user can only read and write their own document subtree.
    // This covers: watchlist, mangaWatchlist, streamingCache,
    //              searchHistory, quizHistory, metadata, history
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }

    // ── Default Deny ──────────────────────────────────────────────────────
    // Deny all access to any path not explicitly matched above.
    match /{document=**} {
      allow read, write: if false;
    }

  }
}
```

---

## What These Rules Protect

| Collection Path | Protection |
|-----------------|-----------|
| `users/{uid}/watchlist` | Only the authenticated owner can read/write |
| `users/{uid}/mangaWatchlist` | Only the authenticated owner can read/write |
| `users/{uid}/streamingCache` | Only the authenticated owner can read/write |
| `users/{uid}/searchHistory` | Only the authenticated owner can read/write |
| `users/{uid}/quizHistory` | Only the authenticated owner can read/write |
| `users/{uid}/history` | Only the authenticated owner can read/write |
| Everything else | ❌ Denied entirely |

---

## What These Rules Prevent

- ❌ Unauthenticated users reading any data
- ❌ User A reading User B's watchlist
- ❌ User A modifying User B's data
- ❌ Any wildcard public read/write access
- ❌ Admin SDK abuse from client code

---

## How to Apply

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Build → Firestore Database → Rules** tab
4. Replace the existing content with the rules above
5. Click **Publish**

Rules take effect within ~1 minute.

---

## Testing Rules (Optional)

You can test these rules in the Firebase Console using the **Rules Playground**:

| Test Scenario | Expected Result |
|---------------|----------------|
| Authenticated user reads `users/{theirUid}/watchlist` | ✅ Allowed |
| Authenticated user reads `users/{differentUid}/watchlist` | ❌ Denied |
| Unauthenticated request reads anything | ❌ Denied |
| Authenticated user writes to `/publicData` | ❌ Denied |

---

## ⚠️ Security Warning

Any pull request that modifies these rules to be more permissive **will be rejected**.
In particular:
- No `allow read, write: if true;` (public access)
- No removal of the `request.auth.uid == userId` check
- No wildcard rules that bypass user isolation

If you believe a rule change is necessary, open an issue explaining the use case before submitting a PR.
