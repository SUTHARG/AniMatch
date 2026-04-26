# Contributing to AniMatch

First off, thank you for considering contributing to AniMatch! It's people like you that make AniMatch such a great tool for the anime community.

## Development Setup
Please see the [README.md](./README.md) for instructions on setting up your local environment, including Firebase configuration.

## Branch Naming Conventions

To keep our repository organized, please follow these branch naming conventions:
- `feature/<feature-name>`: For new features (e.g., `feature/social-login`)
- `bugfix/<bug-name>`: For bug fixes (e.g., `bugfix/watchlist-sync`)
- `docs/<doc-name>`: For documentation updates (e.g., `docs/update-architecture`)
- `refactor/<refactor-name>`: For code refactoring (e.g., `refactor/api-service`)

## Pull Request Process

1. **Fork the repo** and create your branch from `main`.
2. **Commit your changes** with clear and descriptive commit messages.
3. **Run tests** and ensure everything passes before submitting.
4. **Update documentation** if your change adds or modifies a feature.
5. **Open a Pull Request** against the `main` branch.
6. A maintainer will review your code. Please address any feedback promptly.

## Riverpod Architecture Rules

AniMatch uses **Riverpod** for state management. When contributing, adhere to the following rules:

1. **Keep UI Dumb**: Flutter widgets should only watch/read providers and dispatch actions. All business logic belongs in `StateNotifier` or `Notifier` classes.
2. **Provider Separation**: 
   - `FutureProvider` for asynchronous data fetching.
   - `NotifierProvider` for mutable state that requires complex logic.
3. **Immutability**: Always use immutable states (preferably with `freezed`) for complex objects.
4. **Avoid Global State**: Do not use global variables. Everything should be injected or accessed via a provider.
5. Read more about the flow in [architecture.md](./architecture.md).

## Code Quality & Style Expectations

### 1. Flutter Analyze Required
Before submitting a PR, ensure your code passes the Flutter analyzer with zero warnings:
```bash
flutter analyze
```

### 2. Code Formatting
Format your code using the default Dart formatter:
```bash
dart format lib/
```

### 3. Clean Architecture
Follow the established directory structure (`lib/core`, `lib/data`, `lib/presentation`). Do not mix data fetching or complex logic into the `presentation` layer. 

### 4. Meaningful Variable Names
Use descriptive names for variables, methods, and classes. Avoid abbreviations that are not universally understood.

We look forward to reviewing your contributions!
