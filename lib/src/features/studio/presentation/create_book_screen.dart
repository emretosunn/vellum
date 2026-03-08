import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../data/image_upload_service.dart';

/// Kategori değerinden çeviri anahtarı.
const Map<String, String> _categoryKeys = {
  'Korku': 'studio.cat_korku',
  'Bilim Kurgu': 'studio.cat_bilim_kurgu',
  'Tarih': 'studio.cat_tarih',
  'Kişisel Gelişim': 'studio.cat_kisisel_gelisim',
  'Çocuk': 'studio.cat_cocuk',
  'Diğer': 'studio.cat_diger',
};

/// İçerik uyarısı etiketinden çeviri anahtarı.
const Map<String, String> _contentWarningKeys = {
  'Cinsellik': 'studio.cw_cinsellik',
  'Şiddet': 'studio.cw_siddet',
  'Küfür': 'studio.cw_kufur',
  'Olgun temalar': 'studio.cw_olgun_temalar',
  'Diğer hassas içerik': 'studio.cw_diger_hassas',
};

/// Yeni kitap oluşturma / düzenleme sayfası (kapak resmi + başlık + özet).
class CreateBookScreen extends ConsumerStatefulWidget {
  const CreateBookScreen({super.key, this.initialBook});

  /// Düzenleme modunda doldurulacak mevcut kitap.
  final Book? initialBook;

  @override
  ConsumerState<CreateBookScreen> createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends ConsumerState<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _isCreating = false;

  String? _selectedCategory;
  bool _isAdult18 = false;
  final Set<String> _contentWarnings = {};

  bool get _isEditMode => widget.initialBook != null;

  @override
  void initState() {
    super.initState();
    final book = widget.initialBook;
    if (book != null) {
      _titleController.text = book.title;
      _summaryController.text = book.summary;
      _selectedCategory = book.category;
      _isAdult18 = book.isAdult18;
      _contentWarnings.addAll(book.contentWarnings);
    }
  }

  String _categoryDisplayName(String value) =>
      translate(_categoryKeys[value] ?? 'studio.cat_diger');

  String _contentWarningDisplayName(String label) =>
      translate(_contentWarningKeys[label] ?? label);

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
        SnackBar(content: Text(translate('studio.book_title_required'))),
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
        final coverBookId = _isEditMode
            ? widget.initialBook!.id
            : DateTime.now().millisecondsSinceEpoch.toString();
        coverUrl = await ref.read(imageUploadServiceProvider).uploadCoverImage(
              userId: profile.id,
              bookId: coverBookId,
              file: _pickedImage!,
            );
      }

      if (_isEditMode) {
        await ref.read(bookRepositoryProvider).updateBook(
              bookId: widget.initialBook!.id,
              title: title,
              summary: _summaryController.text.trim(),
              coverImageUrl: coverUrl,
              category: _selectedCategory,
              isAdult18: _isAdult18,
              contentWarnings: _contentWarnings.toList(),
            );

        ref.invalidate(myBooksProvider);
        ref.invalidate(publishedBooksProvider);
        ref.invalidate(searchedBooksProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translate('studio.book_updated'))),
          );
          Navigator.pop(context);
        }
      } else {
        await ref.read(bookRepositoryProvider).createBook(
              authorId: profile.id,
              title: title,
              summary: _summaryController.text.trim(),
              coverImageUrl: coverUrl,
              category: _selectedCategory,
              isAdult18: _isAdult18,
              contentWarnings: _contentWarnings.toList(),
            );

        ref.invalidate(myBooksProvider);
        ref.invalidate(publishedBooksProvider);
        ref.invalidate(searchedBooksProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translate('studio.book_created'))),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate('subscription.error', args: {'error': e.toString()}))),
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
      body: SafeArea(
        child: Column(
          children: [
            // Özel üst bar: geri + başlık + Oluştur
            _buildCustomAppBar(context, theme, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, translate('studio.cover_image')),
                    const SizedBox(height: 12),
                    _buildCoverPicker(context, theme, isDark),
                    const SizedBox(height: 28),
                    _buildSectionTitle(theme, translate('studio.book_info')),
                    const SizedBox(height: 14),
                    _buildStyledTextField(
                      theme,
                      controller: _titleController,
                      hint: translate('studio.book_title_hint'),
                      icon: Icons.title_rounded,
                      label: translate('studio.book_title_label'),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 16),
                    _buildStyledTextField(
                      theme,
                      controller: _summaryController,
                      hint: translate('studio.summary_hint'),
                      icon: Icons.description_rounded,
                      label: translate('studio.summary_label'),
                      maxLines: 5,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 26),
                    _buildSectionTitle(theme, translate('studio.category_section')),
                    const SizedBox(height: 10),
                    _buildCategorySelector(theme, isDark),
                    const SizedBox(height: 22),
                    _buildAdult18Card(theme, isDark),
                    const SizedBox(height: 22),
                    _buildSectionTitle(theme, 'İçerik uyarıları (isteğe bağlı)'),
                    const SizedBox(height: 6),
                    Text(
                      'Varsa okuyucuyu bilgilendirmek için seçin.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContentWarningsChips(theme, isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.scaffoldBackgroundColor,
            isDark
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? translate('studio.create_book_edit_title') : translate('studio.create_book_title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isCreating)
            const SizedBox(
              width: 28,
              height: 28,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _createBook,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isEditMode ? translate('studio.create_book_save') : translate('studio.create_book_btn'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCoverPicker(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    final existingCoverUrl =
        (widget.initialBook?.coverImageUrl != null && widget.initialBook!.coverImageUrl!.isNotEmpty)
            ? widget.initialBook!.coverImageUrl
            : null;

    return Center(
      child: GestureDetector(
        onTap: _pickCoverImage,
        child: AnimatedContainer(
          duration: 300.ms,
          width: 180,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pickedImageBytes != null
                  ? AppColors.primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08)),
              width: 2,
            ),
            color: _pickedImageBytes == null
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03))
                : null,
            gradient: _pickedImageBytes == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.06),
                      AppColors.secondary.withValues(alpha: 0.04),
                    ],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: (_pickedImageBytes != null
                        ? AppColors.primary
                        : Colors.black)
                    .withValues(alpha: _pickedImageBytes != null ? 0.25 : 0.06),
                blurRadius: _pickedImageBytes != null ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
            image: _pickedImageBytes != null
                ? DecorationImage(
                    image: MemoryImage(_pickedImageBytes!),
                    fit: BoxFit.cover,
                  )
                : existingCoverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(existingCoverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
          ),
          child: _pickedImageBytes == null && existingCoverUrl == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Kapak Seç',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
  }

  Widget _buildStyledTextField(
    ThemeData theme, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String label,
    int maxLines = 1,
    int? maxLength,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          counterText: maxLength != null ? null : '',
        ),
        autofocus: controller == _titleController,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCategoryDialog(context, theme),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _selectedCategory == null ? translate('studio.select_placeholder') : _categoryDisplayName(_selectedCategory!),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _selectedCategory != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        _selectedCategory != null ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, ThemeData theme) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: size.height * 0.6,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              translate('studio.category_select_title'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...[
                                    null,
                                    ...bookCategories,
                                  ].map((c) {
                                    final selected =
                                        _selectedCategory == c;
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(
                                              () => _selectedCategory = c);
                                          Navigator.of(ctx).pop();
                                        },
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                selected
                                                    ? Icons
                                                        .check_circle_rounded
                                                    : Icons.circle_outlined,
                                                size: 22,
                                                color: selected
                                                    ? AppColors.primary
                                                    : Colors.white.withValues(
                                                        alpha: 0.7),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                c ?? 'Seçiniz',
                                                style: theme
                                                    .textTheme.bodyLarge
                                                    ?.copyWith(
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : null,
                                                  color: Colors.white
                                                      .withValues(
                                                    alpha:
                                                        selected ? 1.0 : 0.9,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdult18Card(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: _isAdult18
            ? Colors.orange.withValues(alpha: 0.12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isAdult18
              ? Colors.orange.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isAdult18
                  ? Colors.orange.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isAdult18 ? Icons.warning_amber_rounded : Icons.person_rounded,
              size: 22,
              color: _isAdult18 ? Colors.orange.shade700 : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('studio.adult_content_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  translate('studio.adult_content_body'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAdult18,
            onChanged: (v) => setState(() => _isAdult18 = v),
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildContentWarningsChips(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: contentWarningLabels.map((label) {
        final selected = _contentWarnings.contains(label);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (selected) {
                  _contentWarnings.remove(label);
                } else {
                  _contentWarnings.add(label);
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: selected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _contentWarningDisplayName(label),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : null,
                      color: selected ? AppColors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
