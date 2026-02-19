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
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(searchedBooksProvider);
            ref.invalidate(publishedBooksProvider);
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
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            loading: () => const SizedBox(height: 28),
                            error: (_, __) => Text(
                              'Okuyucu',
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bildirim ikonu
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
                                Icons.notifications_none_rounded,
                                color: theme.colorScheme.onSurface,
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

            // ─── Glassmorphism Arama Çubuğu ──────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Kitap veya yazar ara...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onChanged: (value) {
                                ref.read(searchQueryProvider.notifier).state = value;
                              },
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                ),
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

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ─── Popüler Kitaplar (Yatay) ──────
                    _SectionHeader(
                      title: 'Popüler Kitaplar',
                      onSeeAll: () {},
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
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

                    // ─── Yeni Eklenenler (Dikey) ──────
                    _SectionHeader(
                      title: 'Yeni Eklenenler',
                      onSeeAll: () {},
                    ),
                    ...books.asMap().entries.map((entry) {
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

                    const SizedBox(height: 100), // bottom nav boşluk
                  ]),
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ─── Bölüm Başlığı ──────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                'Tümünü Gör',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Yatay Kitap Kartı ───────────────────────────────

class _HorizontalBookCard extends ConsumerWidget {
  const _HorizontalBookCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statsAsync = ref.watch(bookRatingStatsProvider(book.id));
    final stats = statsAsync.valueOrNull;

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kapak
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: book.coverImageUrl != null
                      ? Image.network(
                          book.coverImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderCover(title: book.title),
                        )
                      : _PlaceholderCover(title: book.title),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Başlık
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // Rating yıldızları (yorum varsa göster)
            if (stats != null && stats.count > 0)
              Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < stats.average.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stats.average.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Henüz değerlendirme yok',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dikey Kitap Kartı ───────────────────────────────

class _VerticalBookCard extends StatelessWidget {
  const _VerticalBookCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // Kapak thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 90,
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
            const SizedBox(width: 14),
            // Bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.summary.isNotEmpty
                        ? book.summary
                        : 'Açıklama yok',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Durum + fiyat
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: book.status == BookStatus.published
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.status == BookStatus.published
                              ? 'Yayında'
                              : 'Taslak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: book.status == BookStatus.published
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Oku',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
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

// ─── Placeholder Kapak ──────────────────────────────

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
