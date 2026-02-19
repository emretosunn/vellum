/// Build zamanında --dart-define-from-file=.env.json ile enjekte edilen
/// ortam değişkenleri. Kaynak kodda hiçbir secret bulunmaz.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Tüm zorunlu key'lerin tanımlı olduğunu doğrular.
  /// Uygulama başlangıcında çağrılmalı.
  static void validate() {
    const required = {
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_ANON_KEY': supabaseAnonKey,
    };

    final missing = required.entries
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();

    if (missing.isNotEmpty) {
      throw StateError(
        'Eksik ortam değişkenleri: ${missing.join(', ')}.\n'
        'flutter run --dart-define-from-file=.env.json ile çalıştırın.',
      );
    }
  }
}
