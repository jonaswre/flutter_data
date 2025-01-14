import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../flutter_data.dart';

/// Manages network connectivity state
class NetworkState {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true;

  NetworkState() {
    _initConnectivity();
  }

  void _initConnectivity() {
    checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (_) {
      _isOnline = false;
    }
  }

  bool get isOnline => _isOnline;

  void dispose() {
    _subscription?.cancel();
  }
}

/// Extension methods for handling network state in repositories
extension NetworkStateRepositoryExtension<T extends DataModelMixin<T>> on RemoteAdapter<T> {
  /// Checks if the network is available for data operations
  bool get hasNetwork => true;

  /// Handles network-dependent operations with proper error handling
  Future<R> withNetwork<R>({
    required Future<R> Function() onSuccess,
    Future<R> Function()? onError,
    DataRequestLabel? label,
  }) async {
    try {
      if (!hasNetwork) {
        throw Exception('No network connection available');
      }
      return await onSuccess();
    } catch (e) {
      if (onError != null) {
        return await onError();
      }
      rethrow;
    }
  }
}

/// Provider for network state management
final networkStateProvider = Provider<NetworkState>((ref) {
  final state = NetworkState();
  ref.onDispose(() => state.dispose());
  return state;
});