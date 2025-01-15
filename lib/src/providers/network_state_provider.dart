import 'package:riverpod/riverpod.dart';

/// Provider that exposes the current network state.
/// Can be overridden by users to provide their own network state implementation.
final networkStateProvider = Provider<bool>((ref) {
  // Default to online
  return true;
});

/// Example of how to override the network state provider:
/// ```dart
/// runApp(
///   ProviderScope(
///     overrides: [
///       networkStateProvider.overrideWith((ref) {
///         // Implement your own network state logic here
///         return myNetworkState;
///       }),
///     ],
///     child: MyApp(),
///   ),
/// );