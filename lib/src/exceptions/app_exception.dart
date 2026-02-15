/// InkToken uygulama istisnaları.
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

/// Yetersiz bakiye hatası.
class InsufficientBalanceException extends AppException {
  const InsufficientBalanceException()
      : super('Yetersiz token bakiyesi.');
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
