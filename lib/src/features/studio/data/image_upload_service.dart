import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Kapak resmi yükleme servisi.
///
/// Supabase Storage'daki `book-covers` bucket'ına resim yükler
/// ve public URL döndürür.
class ImageUploadService {
  ImageUploadService(this._client);
  final SupabaseClient _client;

  static const _bucket = 'book-covers';

  /// Galeriden resim seç. Null dönerse kullanıcı iptal etmiştir.
  Future<XFile?> pickImage() async {
    final status = await Permission.photos.status;
    var granted = status.isGranted || status.isLimited;
    if (!granted) {
      final requested = await Permission.photos.request();
      granted = requested.isGranted || requested.isLimited;
    }
    if (!granted) return null;

    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );
  }

  /// Seçilen dosyayı Supabase Storage'a yükleyip public URL döndür.
  Future<String> uploadCoverImage({
    required String userId,
    required String bookId,
    required XFile file,
  }) async {
    final ext = file.name.split('.').last;
    final path = '$userId/$bookId.$ext';
    final bytes = await file.readAsBytes();

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true, // Varsa üstüne yaz
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}

// ─── Provider ─────────────────────────────────────────

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(ref.watch(supabaseClientProvider));
});
