/// Vellum uygulama istisnaları.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Kimlik doğrulama hatası.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Abonelik gerekli hatası.
class SubscriptionRequiredException extends AppException {
  const SubscriptionRequiredException()
      : super('Bu özellik için aktif abonelik gereklidir.');
}

/// Ağ hatası.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Bağlantı hatası.']);
}

/// Sunucu hatası.
class ServerException extends AppException {
  const ServerException([super.message = 'Sunucu hatası oluştu.']);
}

/// Veri bulunamadı hatası.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Veri bulunamadı.']);
}
