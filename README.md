# Flutter Data (Fork)

[![CI](https://img.shields.io/github/actions/workflow/status/jonaswre/flutter_data/test.yml?branch=master)](https://github.com/jonaswre/flutter_data/actions) [![codecov](https://codecov.io/gh/jonaswre/flutter_data/branch/master/graph/badge.svg)](https://codecov.io/gh/jonaswre/flutter_data) [![license](https://img.shields.io/github/license/jonaswre/flutter_data?color=%23007A88&labelColor=333940&logo=mit)](https://github.com/jonaswre/flutter_data/blob/master/LICENSE)

Persistent reactive models in Flutter with zero boilerplate.

Forked from [flutterdata/flutter_data](https://github.com/flutterdata/flutter_data). This fork adds SQLite-based local storage and is used by the ServiceApp project.

## Requirements

- Dart SDK >=3.1.0

## Features

- **Adapters for all models** -- Default CRUD and custom remote endpoints with StateNotifier watcher APIs
- **Built for offline-first** -- SQLite3-based local storage at its core, with failure handling and retry API
- **Intuitive APIs, effortless setup** -- Configurable and composable via Dart mixins and codegen, with built-in Riverpod providers
- **Exceptional relationship support** -- Automatically synchronized, fully traversable and reactive relationship graph

Compatible with Flutter (or plain Dart), json_serializable, Freezed, Riverpod, and classic JSON REST APIs. Custom adapters can support Firebase, Supabase, GraphQL, and more.

## Quick Start

Annotate a model with `@DataAdapter` and provide a custom adapter:

```dart
@JsonSerializable()
@DataAdapter([MyJSONServerAdapter])
class User extends DataModel<User> {
  @override
  final int? id;
  final String name;
  User({this.id, required this.name});
}

mixin MyJSONServerAdapter on RemoteAdapter<User> {
  @override
  String get baseUrl => "https://my-json-server.typicode.com/flutterdata/demo/";
}
```

After code generation, the resulting `Adapter<User>` is accessible via Riverpod:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.users.watchOne(1);
  if (state.isLoading) {
    return Center(child: const CircularProgressIndicator());
  }
  final user = state.model;
  return Text(user.name);
}
```

Save or update models directly:

```dart
ref.users.save(User(id: 1, name: 'Updated'));
```

Or use ActiveRecord-style extension methods:

```dart
User(id: 1, name: 'Updated').save();
```

### Initialization

Supply a local storage provider via Riverpod, then initialize:

```dart
ProviderScope(
  overrides: [
    localStorageProvider.overrideWithValue(
      LocalStorage(
        baseDirFn: () async {
          return (await getApplicationSupportDirectory()).path;
        },
        busyTimeout: 5000,
        clear: LocalStorageClearStrategy.never,
      ),
    )
  ],
  // ...
),
```

```dart
return Scaffold(
  body: ref.watch(initializeFlutterData(adapterProvidersMap)).when(
    data: (_) => child,
    error: (e, _) => const Text('Error'),
    loading: () => const Center(child: CircularProgressIndicator()),
  ),
);
```

## Development

```bash
# Install dependencies
dart pub get

# Run tests (requires libsqlite3-dev on Linux)
dart test

# Analyze
dart analyze

# Format
dart format .
```

## Branches

The repo has both `main` and `master` branches. CI runs on both. The current default branch is `master`.

## License

[MIT](https://github.com/jonaswre/flutter_data/blob/master/LICENSE)
