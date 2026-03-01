import 'package:flutter/material.dart';

/// Web / desteklenmeyen platformlarda güncelleme kontrolü yapılmaz.
Future<void> checkForInAppUpdate(BuildContext context) async {
  // No-op: in-app update sadece Android'de (Google Play) çalışır.
}
