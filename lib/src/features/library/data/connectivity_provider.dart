import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bağlantı durumu: ilk değer + değişimler.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

/// İnternet yoksa true.
bool isOfflineFromConnectivity(List<ConnectivityResult> list) {
  if (list.isEmpty) return true;
  return list.every((c) => c == ConnectivityResult.none);
}
