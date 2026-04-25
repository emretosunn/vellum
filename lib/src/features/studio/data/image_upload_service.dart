import 'package:flutter/foundation.dart';
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

  /// Galeriden resim seç.
  /// - permissionDenied=true ise izin reddedildiği için galeri açılamamıştır.
  /// - file=null, permissionDenied=false ise kullanıcı picker'ı iptal etmiştir.
  Future<PickImageResult> pickImage() async {
    final granted = await _ensureGalleryPermission();
    if (!granted) {
      return const PickImageResult(permissionDenied: true);
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );
    return PickImageResult(file: file, permissionDenied: false);
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;

    var photoStatus = await Permission.photos.status;
    var granted = photoStatus.isGranted || photoStatus.isLimited;
    if (!granted) {
      photoStatus = await Permission.photos.request();
      granted = photoStatus.isGranted || photoStatus.isLimited;
    }
    if (granted) return true;

    // Android eski sürümlerde photos yerine storage gerekebilir.
    if (defaultTargetPlatform == TargetPlatform.android) {
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      if (storageStatus.isGranted) return true;
    }

    return false;
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

class PickImageResult {
  const PickImageResult({this.file, required this.permissionDenied});

  final XFile? file;
  final bool permissionDenied;
}
