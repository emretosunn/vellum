import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../data/image_upload_service.dart';

/// Yeni kitap oluşturma sayfası (kapak resmi + başlık + özet).
class CreateBookScreen extends ConsumerStatefulWidget {
  const CreateBookScreen({super.key});

  @override
  ConsumerState<CreateBookScreen> createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends ConsumerState<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _isCreating = false;

  Future<void> _pickCoverImage() async {
    final service = ref.read(imageUploadServiceProvider);
    final file = await service.pickImage();
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _createBook() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitap adı gerekli')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) return;

      String? coverUrl;

      // Kapak resmi yükleme
      if (_pickedImage != null) {
        // Geçici bir ID ile yükleme yapacağız, sonra bookId ile tekrar yükleriz
        coverUrl = await ref.read(imageUploadServiceProvider).uploadCoverImage(
              userId: profile.id,
              bookId: DateTime.now().millisecondsSinceEpoch.toString(),
              file: _pickedImage!,
            );
      }

      await ref.read(bookRepositoryProvider).createBook(
            authorId: profile.id,
            title: title,
            summary: _summaryController.text.trim(),
            coverImageUrl: coverUrl,
          );

      ref.invalidate(myBooksProvider);
      ref.invalidate(publishedBooksProvider);
      ref.invalidate(searchedBooksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitap oluşturuldu ✓')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Kitap Oluştur'),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _createBook,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Oluştur'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Kapak Resmi ──
            Text(
              'Kapak Resmi',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
                child: AnimatedContainer(
                  duration: 300.ms,
                  width: 180,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pickedImageBytes != null
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.1)),
                      width: 2,
                    ),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    boxShadow: _pickedImageBytes != null
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                    image: _pickedImageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_pickedImageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _pickedImageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kapak Seç',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 32),

            // ── Kitap Bilgileri ──
            Text(
              'Kitap Bilgileri',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Kitap Adı',
                hintText: 'Kitabınızın başlığını girin',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _summaryController,
              decoration: InputDecoration(
                labelText: 'Özet',
                hintText: 'Kitabınızın kısa bir özetini yazın...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }
}
