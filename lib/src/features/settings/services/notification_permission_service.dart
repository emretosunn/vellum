import 'package:permission_handler/permission_handler.dart';

/// Sistem bildirim iznini kontrol eder, ister ve ayarları açar.
class NotificationPermissionService {
  /// Mevcut bildirim izni durumunu döndürür.
  static Future<PermissionStatus> get status async {
    return Permission.notification.status;
  }

  /// Bildirim iznini ister.
  static Future<PermissionStatus> request() async {
    return Permission.notification.request();
  }

  /// Uygulama ayarlarını açar (kullanıcı bildirimleri manuel açar).
  static Future<bool> openSettings() async {
    return openAppSettings();
  }
}
