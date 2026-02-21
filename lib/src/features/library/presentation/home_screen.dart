import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/data/review_repository.dart';
import '../../library/domain/book.dart';
import '../../notifications/presentation/notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(searchedBooksProvider);
    final recentAsync = ref.watch(recentBooksProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(searchedBooksProvider);
                ref.invalidate(publishedBooksProvider);
                ref.invalidate(featuredBooksProvider);
                ref.invalidate(recentBooksProvider);
                ref.invalidate(unreadNotificationCountProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ─── Selamlama + Bildirim ─────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Merhaba,',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                profileAsync.when(
                                  data: (profile) => Text(
                                    profile?.username ?? 'Okuyucu',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  loading: () => const SizedBox(height: 28),
                                  error: (_, __) => Text(
                                    'Okuyucu',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Consumer(
                              builder: (context, ref, _) {
                                final unreadAsync = ref.watch(
                                    unreadNotificationCountProvider);
                                final count = unreadAsync.valueOrNull ?? 0;
                                return IconButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen(),
                                      ),
                                    );
                                    ref.invalidate(
                                        unreadNotificationCountProvider);
                                  },
                                  icon: Badge(
                                    isLabelVisible: count > 0,
                                    label: Text('$count'),
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: theme.colorScheme.onSurface,
                                      size: 24,
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

                  // ─── Arama: ince, yumuşak köşe, editoryal placeholder ──────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Binlerce dünyayı keşfet...',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  ref.read(searchQueryProvider.notifier).state =
                                      value;
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showFilterSheet(context, ref),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ─── Hero / Vitrin: Editörün Seçimi ─────────────────
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final featuredAsync = ref.watch(featuredBooksProvider);
                        return featuredAsync.when(
                          data: (featured) {
                            if (featured.isEmpty) return const SizedBox.shrink();
                            return _HeroShowcase(books: featured);
                          },
                          loading: () => const SizedBox(
                            height: 200,
                            child: Center(
                                child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),

                  // ─── Kitaplar İçeriği ─────────────────────
                  booksAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Bir hata oluştu',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.invalidate(publishedBooksProvider),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (books) {
                if (books.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz yayınlanmış kitap yok',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'İlk kitabı yazmaya ne dersin?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayBooks = books.take(5).toList();
                return recentAsync.when(
                  loading: () => SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionHeader(
                        title: 'Popüler Kitaplar',
                        onSeeAll: null,
                      ),
                      SizedBox(
                        height: 268,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: displayBooks.length,
                          itemBuilder: (context, index) {
                            final book = displayBooks[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _HorizontalBookCard(book: book)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: index * 60),
                                  )
                                  .slideX(begin: 0.1),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionHeader(
                        title: 'Yeni Eklenenler',
                        onSeeAll: null,
                      ),
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                  error: (_, __) => SliverList(
                    delegate: SliverChildListDelegate([
                      _SectionHeader(
                        title: 'Popüler Kitaplar',
                        onSeeAll: null,
                      ),
                      SizedBox(
                        height: 268,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: displayBooks.length,
                          itemBuilder: (context, index) {
                            final book = displayBooks[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _HorizontalBookCard(book: book)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: index * 60),
                                  )
                                  .slideX(begin: 0.1),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionHeader(
                        title: 'Yeni Eklenenler',
                        onSeeAll: () => context.push('/books'),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                  data: (recentBooks) {
                    return SliverList(
                      delegate: SliverChildListDelegate([
                        // ─── Popüler Kitaplar (Yatay, en fazla 5) ──────
                        _SectionHeader(
                          title: 'Popüler Kitaplar',
                          onSeeAll: null,
                        ),
                        SizedBox(
                          height: 268,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: displayBooks.length,
                            itemBuilder: (context, index) {
                              final book = displayBooks[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: _HorizontalBookCard(book: book)
                                    .animate()
                                    .fadeIn(
                                      delay: Duration(
                                          milliseconds: index * 60),
                                    )
                                    .slideX(begin: 0.1),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ─── Yeni Eklenenler (Son 5, Tümünü Gör -> 25) ──────
                        _SectionHeader(
                          title: 'Yeni Eklenenler',
                          onSeeAll: () => context.push('/books'),
                        ),
                        ...recentBooks.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            child: _VerticalBookCard(book: entry.value)
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                      milliseconds: entry.key * 80),
                                )
                                .slideY(begin: 0.05),
                          );
                        }),
                        const SizedBox(height: 100),
                      ]),
                    );
                  },
                );
              },
            ),
                ],
              ),
            ),
          ),
          // Hafif grain dokusu (parşömen hissi)
          Positioned.fill(
            child: IgnorePointer(
              child: _GrainOverlay(isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Vitrin (Editörün Seçimi / Haftanın Kitabı) ─────────────────

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Editörün Seçimi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _HeroBookCard(book: book, isDark: isDark),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBookCard extends StatelessWidget {
  const _HeroBookCard({required this.book, required this.isDark});
  final Book book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (book.coverImageUrl != null)
                Image.network(
                  book.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _HeroPlaceholder(book: book),
                )
              else
                _HeroPlaceholder(book: book),
              // Karartma overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.2, 0.6, 1.0],
                  ),
                ),
              ),
              // Başlık (Serif)
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Text(
                  book.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            book.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─── Grain overlay (parşömen dokusu) ─────────────────

class _GrainOverlay extends StatelessWidget {
  const _GrainOverlay({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GrainPainter(isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: 0.015);
    final r = 0.8;
    for (var i = 0; i < 1200; i++) {
      final x = (i * 31.7 + 13) % (size.width + 20) - 10;
      final y = (i * 47.3 + 17) % (size.height + 20) - 10;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Bölüm Başlığı (Serif + Tümünü Gör) ──────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                'Tümünü Gör',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Yatay Kitap Kartı (2:3 oran, Serif başlık, Sans yazar) ───────────────────────────────

class _HorizontalBookCard extends ConsumerWidget {
  const _HorizontalBookCard({required this.book});
  final Book book;

  static const double _coverWidth = 120;
  static const double _coverHeight = 180; // 2:3

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(bookRatingStatsProvider(book.id));
    final stats = statsAsync.valueOrNull;
    final authorAsync = ref.watch(profileByIdProvider(book.authorId));

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: SizedBox(
        width: _coverWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kapak (dikey dikdörtgen, kitap oranı)
            Container(
              width: _coverWidth,
              height: _coverHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: book.coverImageUrl != null
                    ? Image.network(
                        book.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderCover(title: book.title),
                      )
                    : _PlaceholderCover(title: book.title),
              ),
            ),
            const SizedBox(height: 10),
            // Başlık (Serif)
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // Yazar (Sans-Serif)
            authorAsync.when(
              data: (profile) => Text(
                profile?.username ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              loading: () => Text(
                '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              error: (_, __) => Text(
                '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (stats != null && stats.count > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    stats.average.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Dikey Kitap Kartı (2:3 kapak, Serif başlık, Sans yazar) ───────────────────────────────

class _VerticalBookCard extends ConsumerWidget {
  const _VerticalBookCard({required this.book});
  final Book book;

  static const double _coverWidth = 72;
  static const double _coverHeight = 108; // 2:3

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authorAsync = ref.watch(profileByIdProvider(book.authorId));

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _coverWidth,
                height: _coverHeight,
                child: book.coverImageUrl != null
                    ? Image.network(
                        book.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderCover(title: book.title),
                      )
                    : _PlaceholderCover(title: book.title),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  authorAsync.when(
                    data: (profile) => Text(
                      profile?.username ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.summary.isNotEmpty
                        ? book.summary
                        : 'Açıklama yok',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: book.status == BookStatus.published
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          book.status == BookStatus.published
                              ? 'Yayında'
                              : 'Taslak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: book.status == BookStatus.published
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Oku',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder Kapak (minimalist: mor ton, sadece kitap adı) ──────────────────────────────

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─── Filtre bottom sheet (sıralama + kategori) ───────

void _showFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BookFilterSheet(
      onClose: () => Navigator.pop(ctx),
      onApply: () {
        ref.invalidate(searchedBooksProvider);
        Navigator.pop(ctx);
      },
    ),
  );
}

class _BookFilterSheet extends ConsumerStatefulWidget {
  const _BookFilterSheet({required this.onClose, required this.onApply});
  final VoidCallback onClose;
  final VoidCallback onApply;

  @override
  ConsumerState<_BookFilterSheet> createState() => _BookFilterSheetState();
}

class _BookFilterSheetState extends ConsumerState<_BookFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final sortOrder = ref.watch(bookSortOrderProvider);
    final category = ref.watch(bookCategoryFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.12),
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor,
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.06),
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor,
                ],
          stops: const [0.0, 0.25, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Özel sürükleme çubuğu
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.onSurface.withValues(alpha: 0.15),
                    theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // Başlık + kapatma
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrele ve sırala',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Sıralama — segmentli özel görünüm
          Text(
            'Sıralama',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.6,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Expanded(
                    child: _SortSegment(
                      label: 'En son',
                      icon: Icons.schedule_rounded,
                      isSelected: sortOrder == BookSortOrder.recent,
                      onTap: () {
                        ref.read(bookSortOrderProvider.notifier).state =
                            BookSortOrder.recent;
                      },
                    ),
                  ),
                  Expanded(
                    child: _SortSegment(
                      label: 'En çok puan',
                      icon: Icons.star_rounded,
                      isSelected: sortOrder == BookSortOrder.rating,
                      onTap: () {
                        ref.read(bookSortOrderProvider.notifier).state =
                            BookSortOrder.rating;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Kategori — özel kart dropdown
          Text(
            'Kategori',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.4 : 0.6,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: category,
                isExpanded: true,
                hint: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.category_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tüm kategoriler',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                icon: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(vertical: 14),
                dropdownColor: theme.colorScheme.surfaceContainerHigh,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.only(left: 18),
                      child: Text('Tümü'),
                    ),
                  ),
                  ...bookCategories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Text(c),
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  ref.read(bookCategoryFilterProvider.notifier).state = v;
                },
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Özel gradient Uygula butonu
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onApply,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                      AppColors.secondary,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Filtreleri uygula',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
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
}

/// Tek sıralama segmenti (segmentli bar içinde)
class _SortSegment extends StatelessWidget {
  const _SortSegment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.secondary,
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
