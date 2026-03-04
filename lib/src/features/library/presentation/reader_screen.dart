import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';
import '../data/book_repository.dart';
import '../data/read_books_repository.dart';
import '../data/reading_progress_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../studio/data/chapter_repository.dart';
import '../domain/chapter.dart';
import '../offline/offline_download_manager.dart';
import '../../subscription/services/subscription_service.dart';

/// Temiz okuma ekranı.
///
/// Bölümleri sayfa bazlı gösterir — dikkat dağıtmayan, kitap okuma deneyimi.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.initialChapterIndex = 0,
  });

  final String bookId;
  final int initialChapterIndex;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  List<Chapter> _chapters = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showControls = true;
  String _bookTitle = '';
  bool _usingOffline = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork = connectivity != ConnectivityResult.none;

      final subscriptionService = ref.read(subscriptionServiceProvider);
      final isPro = await subscriptionService.isPro();

      // İnternet yok ve kullanıcı Pro değilse: erişime izin verme.
      if (!hasNetwork && !isPro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu özellik Vellum Pro üyelerine özeldir.'),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final book =
          await ref.read(bookRepositoryProvider).getBookById(widget.bookId);

      List<Chapter> chapters;

      if (!hasNetwork && isPro) {
        // Çevrimdışı Pro: Hive üzerinden oku.
        final offlineManager = ref.read(offlineDownloadManagerProvider);
        final offlineBook =
            await offlineManager.getOfflineBook(widget.bookId);
        if (offlineBook == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Bu kitap çevrimdışı indirilememiş. İnternet bağlantısı ile tekrar deneyin.'),
              ),
            );
            Navigator.pop(context);
          }
          return;
        }

        chapters = List<Chapter>.generate(
          offlineBook.chapters.length,
          (index) => Chapter(
            id: 'offline-${offlineBook.bookId}-$index',
            bookId: offlineBook.bookId,
            title: 'Bölüm ${index + 1}',
            content: {'text': offlineBook.chapters[index]},
            order: index,
          ),
        );
        _usingOffline = true;
      } else {
        // Online okuma (mevcut davranış).
        chapters = await ref
            .read(chapterRepositoryProvider)
            .getChaptersByBook(widget.bookId);
        _usingOffline = false;
      }

      if (!mounted) return;

      if (book != null && book.isAdult18) {
        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 48),
            title: const Text('18+ İçerik Uyarısı'),
            content: const Text(
              'Bu kitap yetişkinlere yönelik içerik (18+) uyarısı içermektedir. '
              'Devam etmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Geri dön'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Devam et'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm != true) {
          Navigator.pop(context);
          return;
        }
      }

      if (mounted) {
        final savedIndex = await ref.read(readingProgressRepositoryProvider).getChapterIndex(widget.bookId);
        final initialIndex = widget.initialChapterIndex > 0
            ? widget.initialChapterIndex
            : savedIndex;
        setState(() {
          _bookTitle = book?.title ?? 'Kitap';
          _chapters = chapters;
          _currentIndex = initialIndex.clamp(0, chapters.isEmpty ? 0 : chapters.length - 1);
          _isLoading = false;
        });
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

  void _goToPage(int index) {
    if (index < 0 || index >= _chapters.length) return;
    setState(() => _currentIndex = index);
    ref.read(readingProgressRepositoryProvider).saveProgress(widget.bookId, index);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  void dispose() {
    ref.read(readingProgressRepositoryProvider).saveProgress(widget.bookId, _currentIndex);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Web/masaüstü için max genişlik sınırı (okunabilirlik)
    final contentMaxWidth = screenWidth > 800 ? 700.0 : double.infinity;

    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121225) : const Color(0xFFFAF8F5),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_chapters.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121225) : const Color(0xFFFAF8F5),
        appBar: AppBar(title: Text(_bookTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Bu kitapta henüz içerik yok',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final chapter = _chapters[_currentIndex];
    final content = (chapter.content['text'] as String?) ?? '';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121225) : const Color(0xFFFAF8F5),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ── İçerik — tam ekran, ortala ──
            Positioned.fill(
              child: Container(
                color: isDark
                    ? const Color(0xFF121225)
                    : const Color(0xFFFAF8F5),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: contentMaxWidth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 80, 32, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bölüm başlığı
                            Text(
                              chapter.title,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.black.withValues(alpha: 0.85),
                              ),
                            ).animate().fadeIn(duration: 400.ms),
                            const SizedBox(height: 12),
                            // Süs çizgi
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withValues(alpha: 0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // İçerik
                            SelectableText(
                              content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.9,
                                fontSize: 17,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.black.withValues(alpha: 0.75),
                                letterSpacing: 0.2,
                              ),
                            ).animate().fadeIn(
                                  duration: 500.ms,
                                  delay: 100.ms,
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Üst Bar ──
            AnimatedPositioned(
              duration: 250.ms,
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF121225),
                            const Color(0xFF121225).withValues(alpha: 0.95),
                            const Color(0xFF121225).withValues(alpha: 0.0),
                          ]
                        : [
                            const Color(0xFFFAF8F5),
                            const Color(0xFFFAF8F5).withValues(alpha: 0.95),
                            const Color(0xFFFAF8F5).withValues(alpha: 0.0),
                          ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _bookTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${chapter.title} — Sayfa ${_currentIndex + 1} / ${_chapters.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Alt Navigasyon ──
            AnimatedPositioned(
              duration: 250.ms,
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF121225),
                            const Color(0xFF121225).withValues(alpha: 0.95),
                            const Color(0xFF121225).withValues(alpha: 0.0),
                          ]
                        : [
                            const Color(0xFFFAF8F5),
                            const Color(0xFFFAF8F5).withValues(alpha: 0.95),
                            const Color(0xFFFAF8F5).withValues(alpha: 0.0),
                          ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 24,
                    left: 16,
                    right: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Row(
                        children: [
                          // Önceki
                          Expanded(
                            child: _currentIndex > 0
                                ? TextButton.icon(
                                    onPressed: () =>
                                        _goToPage(_currentIndex - 1),
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('Önceki'),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          // Sayfa göstergesi
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${_chapters.length}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          // Sonraki
                          Expanded(
                            child: _currentIndex < _chapters.length - 1
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _goToPage(_currentIndex + 1),
                                      icon: const Text('Sonraki'),
                                      label:
                                          const Icon(Icons.chevron_right),
                                    ),
                                  )
                                : Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        final userId = ref.read(authRepositoryProvider).currentUser?.id;
                                        if (userId != null) {
                                          await ref.read(readBooksRepositoryProvider).markBookAsCompleted(
                                            userId: userId,
                                            bookId: widget.bookId,
                                          );
                                          ref.invalidate(completedBooksProvider(userId));
                                        }
                                        await ref.read(readingProgressRepositoryProvider).removeBook(widget.bookId);
                                        ref.invalidate(continueReadingEntriesProvider);
                                        ref.invalidate(continueReadingBooksProvider);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.check,
                                          size: 18),
                                      label: const Text('Bitir'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
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
}
