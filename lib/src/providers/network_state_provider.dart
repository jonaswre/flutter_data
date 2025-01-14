import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod/riverpod.dart';

/// Manages network connectivity state
class NetworkStateNotifier extends StateNotifier<bool> {
  final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _subscription;
  
  NetworkStateNotifier() : _connectivity = Connectivity(), super(true) {
    _initConnectivity();
  }

  void _initConnectivity() {
    checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      state = result != ConnectivityResult.none;
    });
  }

  Future<void> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      state = result != ConnectivityResult.none;
    } catch (_) {
      state = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that exposes the current network state.
/// Returns true when online, false when offline.
final networkStateProvider = StateNotifierProvider<NetworkStateNotifier, bool>((ref) {
  return NetworkStateNotifier();
});