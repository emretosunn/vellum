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

/// Yayın gereksinimleri için kitap çapında metrikler (sayfa bazlı metin dahil).
class _BookPublishStats {
  const _BookPublishStats({
    required this.pageCount,
    required this.totalNonSpaceChars,
  });
  final int pageCount;
  final int totalNonSpaceChars;

  bool get meetsPageRule => pageCount >= _BookEditorScreenState._minPagesToPublish;
  bool get meetsCharRule =>
      totalNonSpaceChars >= _BookEditorScreenState._minTotalNonSpaceCharsToPublish;
}

class _BookEditorScreenState extends ConsumerState<BookEditorScreen> {
  static const _maxCharsPerPage = 2000;
  static const _minPagesToPublish = 3;
  static const _minTotalNonSpaceCharsToPublish = 500;

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

  /// Tüm sayfaların güncel metnini dahil eder (aktif sayfa için controller kullanılır).
  _BookPublishStats _computePublishStats() {
    int totalChars = 0;
    final pageCount = _chapters.length;
    for (int i = 0; i < _chapters.length; i++) {
      final text = i == _currentPageIndex
          ? _textController.text
          : ((_chapters[i].content['text'] as String?) ?? '');
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      totalChars += trimmed.replaceAll(RegExp(r'\s+'), '').length;
    }
    return _BookPublishStats(
      pageCount: pageCount,
      totalNonSpaceChars: totalChars,
    );
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

    final stats = _computePublishStats();
    final reasons = <String>[];
    if (!stats.meetsPageRule) {
      reasons.add(
        translate(
          'studio.publish_blocker_pages',
          args: {'n': '${stats.pageCount}'},
        ),
      );
    }
    if (!stats.meetsCharRule) {
      reasons.add(
        translate(
          'studio.publish_blocker_chars',
          args: {'n': '${stats.totalNonSpaceChars}'},
        ),
      );
    }

    if (reasons.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(translate('studio.cannot_publish_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('studio.cannot_publish_intro')),
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
    final publishStats = _computePublishStats();
    final isPublished = _book?.status == BookStatus.published;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final editorBottomPad = keyboardBottom > 0 ? 8.0 : 16.0;
    final dockBottomMargin = keyboardBottom > 0 ? 8.0 : 16.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                      child: _buildEditorPanel(
                        theme,
                        isDark,
                        charCount,
                        publishStats,
                        editorBottomPad,
                        dockBottomMargin,
                      ),
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
                                  translate('studio.pages'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
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
                                : (pageText.isEmpty
                                    ? translate('studio.empty_page')
                                    : pageText);

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    _book?.title ?? translate('studio.book_editor'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  Widget _buildEditorPanel(
    ThemeData theme,
    bool isDark,
    int charCount,
    _BookPublishStats publishStats,
    double editorBottomPad,
    double dockBottomMargin,
  ) {
    final pageProgress = (charCount / _maxCharsPerPage).clamp(0.0, 1.0);
    final isNearPageLimit = charCount > _maxCharsPerPage * 0.9;
    final publishCharProgress =
        (publishStats.totalNonSpaceChars / _minTotalNonSpaceCharsToPublish)
            .clamp(0.0, 1.0);
    final publishPageProgress =
        (publishStats.pageCount / _minPagesToPublish).clamp(0.0, 1.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: translate('studio.page_title_hint'),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Align(
                    widthFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.title_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minHeight: 0,
                  minWidth: 0,
                ),
              ),
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              onChanged: (_) => _hasUnsavedChanges = true,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        translate(
                          'studio.page_n_of_m',
                          args: {
                            'n': '${_currentPageIndex + 1}',
                            'm': '${_chapters.length}',
                          },
                        ),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      translate(
                        'studio.editor_this_page',
                        args: {
                          'n': '$charCount',
                          'max': '$_maxCharsPerPage',
                        },
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isNearPageLimit
                            ? AppColors.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isNearPageLimit ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pageProgress,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isNearPageLimit ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  translate('studio.editor_publish_bar_label'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      publishStats.meetsPageRule
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: publishStats.meetsPageRule
                          ? Colors.green.shade600
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        translate(
                          'studio.editor_publish_pages_hint',
                          args: {'n': '${publishStats.pageCount}'},
                        ),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: publishPageProgress,
                          minHeight: 4,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            publishStats.meetsPageRule
                                ? Colors.green.shade600
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        publishStats.meetsCharRule
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: publishStats.meetsCharRule
                            ? Colors.green.shade600
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        translate(
                          'studio.editor_publish_chars_hint',
                          args: {
                            'n':
                                '${publishStats.totalNonSpaceChars}',
                            'min': '$_minTotalNonSpaceCharsToPublish',
                          },
                        ),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: publishCharProgress,
                          minHeight: 4,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            publishStats.meetsCharRule
                                ? Colors.green.shade600
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, editorBottomPad),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: translate('studio.write_hint'),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.72),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
          ),
        ),

        Container(
          margin: EdgeInsets.fromLTRB(12, 0, 12, dockBottomMargin),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: translate('studio.prev_page_tooltip'),
                onPressed: _currentPageIndex > 0
                    ? () {
                        _saveCurrentPage(silent: true);
                        _loadPageContent(_currentPageIndex - 1);
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 30,
                  color: _currentPageIndex > 0
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              IconButton(
                tooltip: translate('studio.next_page_tooltip'),
                onPressed: _currentPageIndex < _chapters.length - 1
                    ? () {
                        _saveCurrentPage(silent: true);
                        _loadPageContent(_currentPageIndex + 1);
                      }
                    : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 30,
                  color: _currentPageIndex < _chapters.length - 1
                      ? AppColors.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
