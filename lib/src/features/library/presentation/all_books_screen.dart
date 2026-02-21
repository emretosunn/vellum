import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';

/// "Tümünü Gör" sayfası: en fazla 25 kitap, tasarıma uygun liste.
class AllBooksScreen extends ConsumerWidget {
  const AllBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final booksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, theme, isDark),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(allBooksProvider);
                    },
                    child: booksAsync.when(
                      loading: () => const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kitaplar yüklenemedi',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () =>
                                  ref.invalidate(allBooksProvider),
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                      data: (books) {
                        if (books.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 56,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz kitap yok',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          itemCount: books.length,
                          itemBuilder: (context, index) {
                            final book = books[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _BookListCard(book: book)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: index * 40),
                                  )
                                  .slideY(begin: 0.04),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _GrainOverlay(isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
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
            onPressed: () => context.pop(),
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
                  'Yeni Eklenenler',
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
        ],
      ),
    );
  }
}

// ─── Liste kartı (ana sayfa dikey kart ile aynı stil) ─────────────────

class _BookListCard extends ConsumerWidget {
  const _BookListCard({required this.book});
  final Book book;

  static const double _coverWidth = 72;
  static const double _coverHeight = 108;

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
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.015);
    const r = 0.8;
    for (var i = 0; i < 1200; i++) {
      final x = (i * 31.7 + 13) % (size.width + 20) - 10;
      final y = (i * 47.3 + 17) % (size.height + 20) - 10;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
