import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';
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
          SnackBar(content: Text('Yükleme hatası: $e')),
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
          SnackBar(content: Text('Sayfa oluşturma hatası: $e')),
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
          const SnackBar(
            content: Text('Kaydedildi ✓'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfayı Sil'),
        content: Text(
            '"${_chapters[index].title}" silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
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
          SnackBar(content: Text('Silme hatası: $e')),
        );
      }
    }
  }

  Future<void> _publishBook() async {
    if (_book == null) return;

    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir sayfa gerekli')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitabı Yayınla'),
        content: const Text(
          'Kitabınız yayınlandığında herkes görebilir ve okuyabilir.\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yayınla'),
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
          SnackBar(content: Text('Yayınlama hatası: $e')),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final charCount = _textController.text.length;
    final isPublished = _book?.status == BookStatus.published;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (_isSidebarOpen) {
              setState(() => _isSidebarOpen = false);
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: Icon(_isSidebarOpen ? Icons.close : Icons.arrow_back),
        ),
        title: Text(_book?.title ?? 'Kitap Editörü'),
        actions: [
          // Sidebar aç/kapa
          IconButton(
            onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
            icon: Icon(
              _isSidebarOpen ? Icons.menu_open : Icons.menu_book_rounded,
            ),
            tooltip: 'Sayfalar',
          ),
          // Kaydet
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: () => _saveCurrentPage(),
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Kaydet',
            ),
          // Yayınla / Taslağa al
          if (_isPublishing)
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
              child: isPublished
                  ? OutlinedButton.icon(
                      onPressed: _unpublishBook,
                      icon: const Icon(Icons.unpublished, size: 18),
                      label: const Text('Taslağa Al'),
                    )
                  : FilledButton.icon(
                      onPressed: _publishBook,
                      icon: const Icon(Icons.publish, size: 18),
                      label: const Text('Yayınla'),
                    ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Ana İçerik — Editör (her zaman tam genişlik) ──
          Row(
            children: [
              Expanded(
                child: _buildEditorPanel(theme, isDark, charCount),
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
              elevation: _isSidebarOpen ? 12 : 0,
              shadowColor: Colors.black45,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A2E)
                      : Colors.white,
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
                      // Başlık
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sayfalar',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _addNewPage(),
                                  icon: const Icon(Icons.add, size: 22),
                                  tooltip: 'Yeni Sayfa',
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.12),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _isSidebarOpen = false),
                                  icon: const Icon(Icons.close, size: 20),
                                  tooltip: 'Kapat',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
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

  // ── Editör paneli ──
  Widget _buildEditorPanel(ThemeData theme, bool isDark, int charCount) {
    return Column(
      children: [
        // Sayfa başlığı
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Sayfa başlığı...',
              border: InputBorder.none,
              hintStyle: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.3),
              ),
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            onChanged: (_) => _hasUnsavedChanges = true,
          ),
        ),
        const Divider(),

        // Karakter sayacı
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                'Sayfa ${_currentPageIndex + 1} / ${_chapters.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              // Karakter sayacı
              Text(
                '$charCount / $_maxCharsPerPage',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: charCount > _maxCharsPerPage * 0.9
                      ? AppColors.error
                      : theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                  fontWeight: charCount > _maxCharsPerPage * 0.9
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 12),
              // Progress bar
              SizedBox(
                width: 80,
                child: LinearProgressIndicator(
                  value: (charCount / _maxCharsPerPage).clamp(0.0, 1.0),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  color: charCount > _maxCharsPerPage * 0.9
                      ? AppColors.error
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // Metin editörü
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Yazmaya başlayın...',
                border: InputBorder.none,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.3),
                ),
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.8,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ),

        // Alt navigasyon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPageIndex > 0
                    ? () {
                        _saveCurrentPage(silent: true);
                        _loadPageContent(_currentPageIndex - 1);
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Önceki sayfa',
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPageIndex + 1} / ${_chapters.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPageIndex < _chapters.length - 1
                    ? () {
                        _saveCurrentPage(silent: true);
                        _loadPageContent(_currentPageIndex + 1);
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Sonraki sayfa',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
