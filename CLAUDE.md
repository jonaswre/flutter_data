# CLAUDE.md

## Overview

Forked from [flutterdata/flutter_data](https://github.com/flutterdata/flutter_data). Flutter Data is an offline-first data framework for Flutter/Dart with SQLite-based local storage, a customizable REST client, and powerful model relationships built on Riverpod.

This fork lives at `jonaswre/flutter_data` and is used by the ServiceApp as a dependency.

## Branches

The repo has both `main` and `master` branches. CI runs on both. The current default branch is `master`.

## Commands

```bash
# Install dependencies
dart pub get

# Run tests (requires libsqlite3-dev on Linux)
dart test

# Analyze
dart analyze --fatal-infos

# Format
dart format .

# Format check (CI uses this)
dart format --set-exit-if-changed .
```

## Architecture

- **Adapters**: Central abstraction. Every `DataModel` gets a generated `Adapter` that handles CRUD, serialization, local storage, and remote calls. Custom behavior is added via Dart mixins annotated with `@DataAdapter`.
- **Repositories**: Merged into `Adapter` in v2 -- there is no separate `Repository`, `RemoteAdapter`, or `LocalAdapter` class.
- **Relationships**: Automatically synchronized, fully traversable relationship graph between models (`HasMany`, `BelongsTo`).
- **Local storage**: SQLite3-based (`LocalStorage`), configured via a Riverpod provider (`localStorageProvider`).
- **Initialization**: `initializeFlutterData(adapterProvidersMap)` -- the adapter providers map is code-generated in `main.data.dart`.
- **Code generation**: Uses `build_runner` to generate adapter wiring and relationship metadata.
- **State management**: Riverpod providers with `DataState` / `DataStateNotifier` for reactive watching (`watchOne`, `watchAll`).
- **Offline operations**: Built-in offline queue with retry support via `offlineOperations`.

## Version

Currently at `2.0.0-rc3` (release candidate, not yet stable).
