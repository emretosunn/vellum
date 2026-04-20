import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/user_friendly_error.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../data/chapter_repository.dart';
import '../../library/domain/chapter.dart';

/// Sayfa bazlı kitap editörü.
///
/// Her sayfa (chapter) max [_maxCharsPerPage] karakter içerir.
/// Sınır aşıldığında otomatik yeni sayfa oluşturulur.
class BookEditorScreen extends ConsumerStatefulWidget {
  const BookEditorScreen({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<BookEditorScreen> createState() => _BookEditorScreenState();
}

class _BookEditorScreenState extends ConsumerState<BookEditorScreen> {
  static const _maxCharsPerPage = 2000;

  List<Chapter> _chapters = [];
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSidebarOpen = false;
  bool _isPublishing = false;

  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  Book? _book;

  @override
  void initState() {
    super.initState();
    _loadBook();
    _textController.addListener(_onTextChanged);
  }

  Future<void> _loadBook() async {
    try {
      final book =
          await ref.read(bookRepositoryProvider).getBookById(widget.bookId);
      final chapters = await ref
          .read(chapterRepositoryProvider)
          .getChaptersByBook(widget.bookId);

      if (!mounted) return;

      setState(() {
        _book = book;
        _chapters = chapters;
        _isLoading = false;
      });

      // İlk sayfa yoksa oluştur
      if (_chapters.isEmpty) {
        await _addNewPage();
      } else {
        _loadPageContent(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyErrorMessage(e))),
        );
      }
    }
  }

  void _loadPageContent(int index) {
    if (index < 0 || index >= _chapters.length) return;

    setState(() => _currentPageIndex = index);

    final chapter = _chapters[index];
    _titleController.text = chapter.title;

    // İçerik JSONB olduğundancontent → { 'text': '...' } formatında saklıyoruz
    final content = chapter.content;
    _textController.text = (content['text'] as String?) ?? '';
    _hasUnsavedChanges = false;
  }

  void _onTextChanged() {
    _hasUnsavedChanges = true;

    // Debounce auto-save (3 saniye)
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveCurrentPage(silent: true);
    });

    // Karakter limiti kontrolü — otomatik yeni sayfa
    if (_textController.text.length > _maxCharsPerPage) {
      final overflow =
          _textController.text.substring(_maxCharsPerPage);
      _textController.text =
          _textController.text.substring(0, _maxCharsPerPage);
      // Birinciyi kaydet, yeni sayfa oluştur, taşan metni yeni sayfaya ekle
      _handleOverflow(overflow);
    }
  }

  Future<void> _handleOverflow(String overflowText) async {
    // Mevcut sayfayı kaydet
    await _saveCurrentPage(silent: true);

    // Taşma noktasında son kelimeyi bulmaya çalış
    // (kelime ortasında bölmememek için)

    // Sonraki sayfa var mı?
    if (_currentPageIndex + 1 < _chapters.length) {
      // Sonraki sayfanın başına ekle
      _loadPageContent(_currentPageIndex + 1);
      _textController.text = overflowText + _textController.text;
      _hasUnsavedChanges = true;
    } else {
      // Yeni sayfa oluştur ve taşan metni yaz
      await _addNewPage(initialText: overflowText);
    }
  }

  Future<void> _addNewPage({String initialText = ''}) async {
    try {
      final order = _chapters.length;
      final chapter = await ref
          .read(chapterRepositoryProvider)
          .createChapter(
            bookId: widget.bookId,
            title: 'Sayfa ${order + 1}',
            order: order,
          );

      // İlk metin varsa kaydet
      if (initialText.isNotEmpty) {
        await ref.read(chapterRepositoryProvider).updateChapter(
              chapterId: chapter.id,
              content: {'text': initialText},
            );
      }

      final updated = await ref
          .read(chapterRepositoryProvider)
          .getChaptersByBook(widget.bookId);

      if (mounted) {
        setState(() => _chapters = updated);
        _loadPageContent(updated.length - 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _saveCurrentPage({bool silent = false}) async {
    if (_chapters.isEmpty) return;
    if (!_hasUnsavedChanges && silent) return;

    if (!silent) setState(() => _isSaving = true);

    try {
      final chapter = _chapters[_currentPageIndex];
      await ref.read(chapterRepositoryProvider).updateChapter(
            chapterId: chapter.id,
            title: _titleController.text.trim().isEmpty
                ? 'Sayfa ${_currentPageIndex + 1}'
                : _titleController.text.trim(),
            content: {'text': _textController.text},
          );

      _hasUnsavedChanges = false;

      // Chapter listesini güncelle
      final updated = await ref
          .read(chapterRepositoryProvider)
          .getChaptersByBook(widget.bookId);
      if (mounted) setState(() => _chapters = updated);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translate('studio.saved')),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletePage(int index) async {
    if (_chapters.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Son sayfa silinemez')),
      );
      return;
    }

    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(translate('studio.delete_page_title')),
        content: Text(
          '"${_chapters[index].title}" silinecek. Bu işlem geri alınamaz.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Sil'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(chapterRepositoryProvider)
          .deleteChapter(_chapters[index].id);

      final updated = await ref
          .read(chapterRepositoryProvider)
          .getChaptersByBook(widget.bookId);

      if (mounted) {
        setState(() => _chapters = updated);
        final newIndex =
            _currentPageIndex >= updated.length ? updated.length - 1 : _currentPageIndex;
        _loadPageContent(newIndex);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _publishBook() async {
    if (_book == null) return;

    // Yayın ön koşulları:
    // - En az 3 sayfa (chapter)
    // - En az 5000 kelime (tüm sayfaların toplam metni)
    final pageCount = _chapters.length;
    int totalWords = 0;
    for (int i = 0; i < _chapters.length; i++) {
      final text = i == _currentPageIndex
          ? _textController.text
          : ((_chapters[i].content['text'] as String?) ?? '');
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      totalWords +=
          trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    final reasons = <String>[];
    if (pageCount < 3) {
      reasons.add('En az 3 sayfa gerekli. (Şu an: $pageCount)');
    }
    if (totalWords < 5000) {
      reasons.add('En az 5000 kelime gerekli. (Şu an: $totalWords)');
    }

    if (reasons.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Yayınlanamaz'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kitabınızın yayınlanması için aşağıdaki şartları tamamlamalısınız:',
              ),
              const SizedBox(height: 12),
              ...reasons.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $r'),
                  )),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(translate('studio.publish_title')),
        content: const Text(
          'Kitabınız yayınlandığında herkes görebilir ve okuyabilir.\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.publish_rounded, size: 18),
            label: const Text('Yayınla'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPublishing = true);

    try {
      // Önce mevcut sayfayı kaydet
      await _saveCurrentPage(silent: true);

      await ref.read(bookRepositoryProvider).updateBook(
            bookId: widget.bookId,
            status: 'published',
          );

      ref.invalidate(myBooksProvider);
      ref.invalidate(publishedBooksProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitap yayınlandı! 🎉'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _book = _book!.copyWith(status: BookStatus.published);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(toUserFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _unpublishBook() async {
    await ref.read(bookRepositoryProvider).updateBook(
          bookId: widget.bookId,
          status: 'draft',
        );
    ref.invalidate(myBooksProvider);
    ref.invalidate(publishedBooksProvider);
    if (mounted) {
      setState(() {
        _book = _book!.copyWith(status: BookStatus.draft);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitap taslağa alındı')),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_hasUnsavedChanges) {
      _saveCurrentPage(silent: true);
    }
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                translate('common.loading'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final charCount = _textController.text.length;
    final isPublished = _book?.status == BookStatus.published;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCustomAppBar(theme, isDark, isPublished),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEditorPanel(theme, isDark, charCount),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Karartma Overlay ──
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _isSidebarOpen = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

          // ── Sol Panel — Sayfa Listesi (slide drawer) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: _isSidebarOpen ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: Material(
              elevation: _isSidebarOpen ? 16 : 0,
              shadowColor: Colors.black38,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(0), bottomRight: Radius.circular(0)),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFFF8F7FF),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sayfalar',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 28,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _addNewPage(),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [AppColors.primary, AppColors.primaryDark],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                          const SizedBox(width: 6),
                                          Text(
                                            translate('studio.new'),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => setState(() => _isSidebarOpen = false),
                                  icon: const Icon(Icons.close_rounded, size: 22),
                                  tooltip: translate('studio.close_tooltip'),
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                      // Liste
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _chapters.length,
                          itemBuilder: (context, index) {
                            final chapter = _chapters[index];
                            final isSelected = index == _currentPageIndex;
                            final pageText =
                                (chapter.content['text'] as String?) ?? '';
                            final preview = pageText.length > 40
                                ? '${pageText.substring(0, 40)}...'
                                : (pageText.isEmpty ? 'Boş sayfa' : pageText);

                            return InkWell(
                              onTap: () {
                                if (index != _currentPageIndex) {
                                  _saveCurrentPage(silent: true);
                                  _loadPageContent(index);
                                }
                                setState(() => _isSidebarOpen = false);
                              },
                              child: AnimatedContainer(
                                duration: 200.ms,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    // Sayfa numarası
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chapter.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            preview,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_chapters.length > 1)
                                      InkWell(
                                        onTap: () => _deletePage(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildCustomAppBar(
    ThemeData theme,
    bool isDark,
    bool isPublished,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                if (_isSidebarOpen) {
                  setState(() => _isSidebarOpen = false);
                } else {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(
                _isSidebarOpen ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                size: 22,
              ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _book?.title ?? 'Kitap Editörü',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
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
            IconButton(
              onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
              icon: Icon(
                _isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_book_rounded,
                size: 24,
              ),
              tooltip: translate('studio.pages_tooltip'),
              style: IconButton.styleFrom(
                backgroundColor: _isSidebarOpen
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
              ),
            ),
            const SizedBox(width: 6),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: () => _saveCurrentPage(),
                icon: const Icon(Icons.save_rounded, size: 22),
                tooltip: translate('studio.save_tooltip'),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            const SizedBox(width: 6),
            if (_isPublishing)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isPublished ? _unpublishBook : _publishBook,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isPublished ? null : const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        color: isPublished
                            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        border: isPublished
                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                            : null,
                        boxShadow: isPublished ? null : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPublished ? Icons.unpublished_rounded : Icons.publish_rounded,
                            size: 18,
                            color: isPublished ? AppColors.primary : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPublished ? translate('studio.move_to_draft') : translate('studio.publish'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isPublished ? AppColors.primary : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Editör paneli ──
  Widget _buildEditorPanel(ThemeData theme, bool isDark, int charCount) {
    final progress = (charCount / _maxCharsPerPage).clamp(0.0, 1.0);
    final isNearLimit = charCount > _maxCharsPerPage * 0.9;

    return Column(
      children: [
        // Sayfa başlığı (özel stil)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Sayfa başlığı...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.title_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              onChanged: (_) => _hasUnsavedChanges = true,
            ),
          ),
        ),

        // Karakter sayacı + sayfa bilgisi (kart)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Sayfa ${_currentPageIndex + 1} / ${_chapters.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$charCount / $_maxCharsPerPage',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isNearLimit ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isNearLimit ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isNearLimit ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Metin editörü (özel container)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Yazmaya başlayın...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
          ),
        ),

        // Alt sayfa navigasyonu (glassmorphism tarzı)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _currentPageIndex > 0
                      ? () {
                          _saveCurrentPage(silent: true);
                          _loadPageContent(_currentPageIndex - 1);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _currentPageIndex > 0
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 28,
                      color: _currentPageIndex > 0
                          ? AppColors.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '${_currentPageIndex + 1} / ${_chapters.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _currentPageIndex < _chapters.length - 1
                      ? () {
                          _saveCurrentPage(silent: true);
                          _loadPageContent(_currentPageIndex + 1);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _currentPageIndex < _chapters.length - 1
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 28,
                      color: _currentPageIndex < _chapters.length - 1
                          ? AppColors.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
