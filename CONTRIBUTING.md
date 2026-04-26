# Contributing to AniMatch

Thank you for taking the time to contribute! This guide covers everything you need to get started.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). All interactions in this project must be respectful and inclusive.

---

## Development Setup

### Prerequisites

- **Flutter SDK** `≥ 3.11.0` — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Dart SDK** `≥ 3.0`
- **Git**
- **A Firebase account** — [Firebase Console](https://console.firebase.google.com/)

### First-time Setup

1. **Fork** the repository and clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/AniMatch.git
   cd AniMatch
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up Firebase** — follow [firebase_setup.md](firebase_setup.md) to create your own dev project.

4. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Fill in your Firebase credentials from firebase_setup.md
   ```

5. **Verify setup**:
   ```bash
   flutter analyze   # must pass with 0 errors
   flutter run       # app should launch
   ```

---

## 🔐 Security Rules — Non-Negotiable

**Before writing a single line of code, understand these rules:**

### Rule 1 — Never Commit Secrets
The following must **never** appear in any committed file:
- Firebase API keys (`AIza...`)
- OAuth Client IDs (`...googleusercontent.com`)
- Firebase App IDs (`1:...:android:...`)
- Signing keys (`.jks`, `.keystore`)
- `google-services.json` or `GoogleService-Info.plist`
- Your `.env` file

**How to check before committing:**
```bash
git diff --staged | grep -E "AIza|googleusercontent|\.env"
```

### Rule 2 — Use .env for All Credentials
All sensitive values must live in `.env` and be accessed via `flutter_dotenv`:
```dart
// ✅ Correct
final apiKey = dotenv.env['FIREBASE_API_KEY']!;

// ❌ Wrong — never do this
const apiKey = 'AIzaSyABC123...';
```

### Rule 3 — Never Weaken Firestore Rules
See [firestore_rules.md](firestore_rules.md). PRs that make Firestore rules more permissive will be rejected.

---

## Branch Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<name>` | `feature/social-login` |
| Bug fix | `bugfix/<name>` | `bugfix/watchlist-sync-crash` |
| Documentation | `docs/<name>` | `docs/update-architecture` |
| Refactor | `refactor/<name>` | `refactor/jikan-service-retry` |
| Security | `security/<name>` | `security/remove-hardcoded-key` |

All branches should be created from `main`.

---

## Pull Request Process

1. **Create your branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the architecture rules below.

3. **Run the pre-PR checklist** (all must pass):
   ```bash
   flutter analyze       # zero errors and zero warnings
   dart format lib/      # code is properly formatted
   flutter test          # all tests pass (when applicable)
   ```

4. **Verify no secrets are staged**:
   ```bash
   git diff --staged | grep -E "AIza|googleusercontent|aimatch-d3a1b"
   # Should return nothing
   ```

5. **Open a PR** against `main`. Use the PR template — fill in all checkboxes.

6. **Address review feedback** promptly. A PR with outstanding review comments for > 14 days will be closed.

---

## Riverpod Architecture Rules

AniMatch uses a strict **layered architecture**. Understanding these rules is essential before contributing UI or state logic.

### The 5-Layer Rule

```
UI Widgets  →  Riverpod Providers  →  Repositories  →  Services  →  External APIs
```

Each layer may only communicate with the layer **directly below it**.

### Layer Responsibilities

| Layer | Where | Do | Don't |
|-------|-------|----|-------|
| UI Screens | `presentation/screens/` | Display state, dispatch actions | Business logic, API calls |
| Providers | `presentation/providers/` | Manage state, call repositories | Direct API calls, UI logic |
| Repositories | `data/repositories/` | Orchestrate cache vs network | UI code, provider reads |
| Services | `data/sources/` | Network calls, JSON parsing | State management |

### Provider Rules

- Use `FutureProvider` for read-only async data.
- Use `AsyncNotifierProvider` for async state with refresh/mutation.
- Use `NotifierProvider` for synchronous mutable state.
- All providers must be declared at the file level (not inside widgets).
- Never call `context.read()` inside `build()` — use `ref.watch()`.

### Immutability

- Use immutable state classes (prefer `@immutable` or `freezed`).
- Never mutate state directly — always create new instances.

---

## Code Style Expectations

### Formatting
All code must be formatted with the default Dart formatter:
```bash
dart format lib/
```

### Naming
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables & methods**: `camelCase`
- **Constants**: `camelCase` (prefer `static const`)

### Comments
- Public methods and classes must have doc comments (`///`).
- Inline comments should explain *why*, not *what*.
- Remove debug `print()` calls before submitting — use `debugPrint()` if needed.

### Flutter Analyze
All PRs must pass:
```bash
flutter analyze
```
Zero errors. Zero warnings. Info-level hints should be addressed where possible.

---

## Architecture Boundaries

Do not cross these boundaries:

- ❌ Calling `FirebaseService` directly from a widget — go through a provider.
- ❌ Reading Firestore from a `Repository` — go through `FirebaseService`.
- ❌ Making HTTP requests from a Provider — go through a Service.
- ❌ Accessing `dotenv` from a widget — environment config belongs in services.

---

## What to Contribute

Check the [roadmap](roadmap.md) and [open issues](https://github.com/YOUR_USERNAME/AniMatch/issues) for ideas. Good first issues are labelled `good first issue`.

Areas actively welcoming contributions:
- UI polish and accessibility improvements
- Test coverage (unit and widget tests)
- Documentation improvements
- Performance optimizations
- New platform support

---

## Getting Help

If you're stuck:
1. Check [firebase_setup.md](firebase_setup.md) for setup issues.
2. Check [architecture.md](architecture.md) for design questions.
3. Open a **Discussion** on GitHub (not an issue) for general questions.
