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
  Future<PickImageResult> pickImage({
    PickImageSource source = PickImageSource.gallery,
  }) async {
    final granted = await _ensurePermissionForSource(source);
    if (!granted) {
      return const PickImageResult(permissionDenied: true);
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source == PickImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );
    return PickImageResult(file: file, permissionDenied: false);
  }

  Future<bool> _ensurePermissionForSource(PickImageSource source) async {
    if (kIsWeb) return true;

    if (source == PickImageSource.camera) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }
      return cameraStatus.isGranted;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android'de sistem fotoğraf seçici (Photo Picker) için ek depolama izni gerekmiyor.
      return true;
    }

    var photoStatus = await Permission.photos.status;
    var granted = photoStatus.isGranted || photoStatus.isLimited;
    if (!granted) {
      photoStatus = await Permission.photos.request();
      granted = photoStatus.isGranted || photoStatus.isLimited;
    }
    return granted;
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

enum PickImageSource { gallery, camera }
