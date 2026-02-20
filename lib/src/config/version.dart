import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Uygulama sürüm bilgisini (`pubspec.yaml` -> `version`) okur.
/// Örnek: `1.0.0+3`
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

