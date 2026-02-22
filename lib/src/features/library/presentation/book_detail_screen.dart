import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../../library/data/book_like_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/data/book_report_repository.dart';
import '../../library/data/review_repository.dart';
import '../../library/domain/book.dart';
import '../../library/domain/chapter.dart';
import '../../library/domain/review.dart';
import '../../studio/data/chapter_repository.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));
    final chaptersAsync = ref.watch(chaptersByBookProvider(bookId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, theme),
        data: (book) {
          if (book == null) {
            return _buildErrorState(context, theme);
          }

          final authorAsync = ref.watch(profileByIdProvider(book.authorId));

          return _IncrementViewOnLoad(
            bookId: bookId,
            child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Hero kapak alanı
                  _HeroCoverSliver(
                    book: book,
                    isDark: isDark,
                    screenWidth: screenWidth,
                    onReport: () => _showReportBookSheet(context, ref, book),
                  ),

                  // İçerik
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.responsive(
                          mobile: 16,
                          tablet: 32,
                          desktop: 64,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Yazar kartı
                          authorAsync.when(
                            loading: () => const _AuthorCardSkeleton(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (author) {
                              if (author == null) return const SizedBox.shrink();
                              return _AuthorCard(
                                author: author,
                                isDark: isDark,
                              ).animate().fadeIn(delay: 200.ms).slideY(
                                    begin: 0.1,
                                    curve: Curves.easeOutCubic,
                                  );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Görüntülenme + Beğeni
                          _BookViewLikeRow(
                            book: book,
                            theme: theme,
                            isDark: isDark,
                          ).animate().fadeIn(delay: 280.ms),

                          const SizedBox(height: 24),

                          // Kitap bilgi bölümü
                          if (book.summary.isNotEmpty)
                            _BookInfoSection(
                              book: book,
                              theme: theme,
                              isDark: isDark,
                            ).animate().fadeIn(delay: 300.ms),

                          const SizedBox(height: 28),

                          // Bölümler başlık
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Bölümler',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              chaptersAsync.whenOrNull(
                                    data: (chapters) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${chapters.length} bölüm',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ) ??
                                  const SizedBox.shrink(),
                            ],
                          ).animate().fadeIn(delay: 400.ms),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Bölüm listesi
                  chaptersAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                    error: (_, __) => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Bölümler yüklenemedi'),
                      ),
                    ),
                    data: (chapters) {
                      if (chapters.isEmpty) {
                        return SliverToBoxAdapter(
                          child: _EmptyChaptersWidget(theme: theme),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsive(
                            mobile: 16,
                            tablet: 32,
                            desktop: 64,
                          ),
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final chapter = chapters[index];
                              return _ChapterCard(
                                chapter: chapter,
                                index: index,
                                bookId: book.id,
                                isDark: isDark,
                                theme: theme,
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(
                                      milliseconds: 450 + index * 60,
                                    ),
                                  )
                                  .slideX(
                                    begin: 0.03,
                                    curve: Curves.easeOutCubic,
                                  );
                            },
                            childCount: chapters.length,
                          ),
                        ),
                      );
                    },
                  ),

                  // Değerlendirmeler bölümü
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.responsive(
                          mobile: 16,
                          tablet: 32,
                          desktop: 64,
                        ),
                      ),
                      child: _ReviewsSection(bookId: book.id),
                    ),
                  ),

                  // Alt boşluk (CTA butonu için)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),

              // Okumaya Başla CTA
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ReadCtaButton(
                  book: book,
                  isDark: isDark,
                  chaptersAsync: chaptersAsync,
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  static void _showReportBookSheet(
      BuildContext context, WidgetRef ref, Book book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportBookSheet(
        book: book,
        onClose: () => Navigator.pop(ctx),
        onSubmit: (String message) async {
          final userId = ref.read(authRepositoryProvider).currentUser?.id;
          if (userId == null) return;
          await ref.read(bookReportRepositoryProvider).createReport(
                bookId: book.id,
                reporterUserId: userId,
                message: message,
              );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                  content: Text('Şikayetiniz alındı. İncelenecektir.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Kitap bulunamadı', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => context.pop(),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
  }
}

/// Kitap detayı açıldığında görüntülenme sayısını 1 artırır (uygulama oturumunda kitap başına en fazla 1 kez)
class _IncrementViewOnLoad extends ConsumerStatefulWidget {
  const _IncrementViewOnLoad({required this.bookId, required this.child});
  final String bookId;
  final Widget child;

  @override
  ConsumerState<_IncrementViewOnLoad> createState() => _IncrementViewOnLoadState();
}

class _IncrementViewOnLoadState extends ConsumerState<_IncrementViewOnLoad> {
  /// Aynı oturumda aynı kitap için birden fazla artırma yapılmaz (sayfa yeniden build olsa bile)
  static final Set<String> _incrementedInSession = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_incrementedInSession.contains(widget.bookId)) return;
      _incrementedInSession.add(widget.bookId);
      await ref.read(bookRepositoryProvider).incrementBookView(widget.bookId);
      if (!mounted) return;
      ref.invalidate(bookDetailProvider(widget.bookId));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Görüntülenme sayısı + Beğeni butonu (kitap detayda)
class _BookViewLikeRow extends ConsumerWidget {
  const _BookViewLikeRow({
    required this.book,
    required this.theme,
    required this.isDark,
  });
  final Book book;
  final ThemeData theme;
  final bool isDark;

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeCountAsync = ref.watch(bookLikeCountProvider(book.id));
    final isLikedAsync = ref.watch(isBookLikedByCurrentUserProvider(book.id));

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          '${_formatCount(book.viewCount)} görüntülenme',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 24),
        isLikedAsync.when(
          data: (isLiked) => likeCountAsync.when(
            data: (count) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final profile = await ref.read(currentProfileProvider.future);
                  if (profile == null) return;
                  await ref.read(bookLikeRepositoryProvider).toggleLike(
                    bookId: book.id,
                    userId: profile.id,
                  );
                  ref.invalidate(bookLikeCountProvider(book.id));
                  ref.invalidate(isBookLikedByCurrentUserProvider(book.id));
                  ref.invalidate(authorTotalLikesProvider(book.authorId));
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 22,
                        color: isLiked ? AppColors.error : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatCount(count),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Hero Kapak Sliver ─────────────────────────────

class _HeroCoverSliver extends StatelessWidget {
  const _HeroCoverSliver({
    required this.book,
    required this.isDark,
    required this.screenWidth,
    this.onReport,
  });

  final Book book;
  final bool isDark;
  final double screenWidth;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final expandedHeight = screenWidth < 600 ? 340.0 : 400.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black26,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        if (onReport != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.white),
              tooltip: 'Şikayet et',
              onPressed: onReport,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Arka plan görseli veya varsayılan kapak
            (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
                ? Image.network(
                    book.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      AppAssets.defaultBookCover,
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    AppAssets.defaultBookCover,
                    fit: BoxFit.cover,
                  ),

            // Gradient overlay (metin okunabilirliği için)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Kitap bilgisi (alt kısım)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Durum badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kitap başlığı
                  Text(
                    book.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.secondary,
            AppColors.primaryDark,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 100,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (book.status) {
      case BookStatus.published:
        return AppColors.success;
      case BookStatus.draft:
        return AppColors.warning;
      case BookStatus.archived:
        return AppColors.textSecondaryDark;
    }
  }

  IconData get _statusIcon {
    switch (book.status) {
      case BookStatus.published:
        return Icons.check_circle_outline;
      case BookStatus.draft:
        return Icons.edit_outlined;
      case BookStatus.archived:
        return Icons.archive_outlined;
    }
  }

  String get _statusText {
    switch (book.status) {
      case BookStatus.published:
        return 'Yayında';
      case BookStatus.draft:
        return 'Taslak';
      case BookStatus.archived:
        return 'Arşivlendi';
    }
  }
}

// ─── Yazar Kartı ─────────────────────────────────

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.author, required this.isDark});

  final Profile author;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/author/${author.id}'),
      child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundImage: author.avatarUrl != null
                      ? NetworkImage(author.avatarUrl!)
                      : null,
                  onBackgroundImageError: author.avatarUrl != null
                      ? (_, __) {}
                      : null,
                  child: author.avatarUrl == null
                      ? Text(
                          author.username.isNotEmpty
                              ? author.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Yazar bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author.username,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (author.isVerifiedAuthor) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                          if (author.isPro) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.accentDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Profili Gör',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ok ikonu
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
      ),
    );
  }
}

class _AuthorCardSkeleton extends StatelessWidget {
  const _AuthorCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.1));
  }
}

// ─── Kitap Bilgi Bölümü ─────────────────────────────

class _BookInfoSection extends StatelessWidget {
  const _BookInfoSection({
    required this.book,
    required this.theme,
    required this.isDark,
  });

  final Book book;
  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accent, AppColors.accentDark],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Hakkında',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            book.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bölüm Kartı ─────────────────────────────────

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.index,
    required this.bookId,
    required this.isDark,
    required this.theme,
  });

  final Chapter chapter;
  final int index;
  final String bookId;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/reader/$bookId'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.12),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Bölüm numarası
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Bölüm başlığı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bölüm ${index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ok ikonu
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Boş Bölüm Widget ─────────────────────────────

class _EmptyChaptersWidget extends StatelessWidget {
  const _EmptyChaptersWidget({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz bölüm eklenmemiş',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Okumaya Başla CTA ─────────────────────────────

class _ReadCtaButton extends StatelessWidget {
  const _ReadCtaButton({
    required this.book,
    required this.isDark,
    required this.chaptersAsync,
  });

  final Book book;
  final bool isDark;
  final AsyncValue<List<Chapter>> chaptersAsync;

  @override
  Widget build(BuildContext context) {
    final hasChapters = chaptersAsync.whenOrNull(
          data: (chapters) => chapters.isNotEmpty,
        ) ??
        false;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? Colors.black : Colors.white).withValues(alpha: 0.0),
            isDark ? Colors.black : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: hasChapters
                  ? LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    )
                  : null,
              color: hasChapters ? null : Colors.grey,
              borderRadius: BorderRadius.circular(16),
              boxShadow: hasChapters
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: hasChapters
                    ? () => context.push('/reader/${book.id}')
                    : null,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        hasChapters
                            ? 'Okumaya Başla'
                            : 'Henüz okunacak bölüm yok',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3);
  }
}

// ─── Değerlendirmeler Bölümü ─────────────────────

class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection({required this.bookId});
  final String bookId;

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reviewsAsync = ref.watch(bookReviewsProvider(widget.bookId));
    final statsAsync = ref.watch(bookRatingStatsProvider(widget.bookId));
    final currentUser = ref.watch(currentProfileProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),

        // Başlık + ortalama puan
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.warning, Colors.orange.shade700],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Değerlendirmeler',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            statsAsync.whenOrNull(
                  data: (stats) {
                    if (stats.count == 0) return null;
                    return Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.warning, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          stats.average.toStringAsFixed(1),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${stats.count})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ) ??
                const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 16),

        // Yorum yazma butonu
        if (currentUser != null && !_showForm)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Değerlendirme Yaz'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        // Yorum formu
        if (_showForm && currentUser != null)
          _ReviewForm(
            bookId: widget.bookId,
            userId: currentUser.id,
            onClose: () => setState(() => _showForm = false),
            onSubmitted: () {
              setState(() => _showForm = false);
              ref.invalidate(bookReviewsProvider(widget.bookId));
              ref.invalidate(bookRatingStatsProvider(widget.bookId));
              ref.invalidate(userReviewProvider(widget.bookId));
            },
          ),

        const SizedBox(height: 16),

        // Yorum listesi
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Yorumlar yüklenemedi'),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'Henüz değerlendirme yok',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İlk değerlendirmeyi siz yazın!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: reviews
                  .map((r) => _ReviewCard(
                        review: r,
                        isDark: isDark,
                        isOwn: r.userId == currentUser?.id,
                        onDelete: () async {
                          await ref
                              .read(reviewRepositoryProvider)
                              .deleteReview(r.id);
                          ref.invalidate(
                              bookReviewsProvider(widget.bookId));
                          ref.invalidate(
                              bookRatingStatsProvider(widget.bookId));
                        },
                      ))
                  .toList(),
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Yorum Formu ─────────────────────────────────

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({
    required this.bookId,
    required this.userId,
    required this.onClose,
    required this.onSubmitted,
  });

  final String bookId;
  final String userId;
  final VoidCallback onClose;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  Future<void> _loadExistingReview() async {
    final existing = await ref
        .read(reviewRepositoryProvider)
        .getUserReview(widget.bookId, widget.userId);
    if (existing != null && mounted) {
      setState(() {
        _rating = existing.rating;
        _commentController.text = existing.comment;
      });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir puan seçin')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(reviewRepositoryProvider).addOrUpdateReview(
            bookId: widget.bookId,
            userId: widget.userId,
            rating: _rating,
            comment: _commentController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değerlendirmeniz kaydedildi')),
        );
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Değerlendirmeniz',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Yıldız seçimi
          Row(
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starIndex <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: starIndex <= _rating
                        ? AppColors.warning
                        : theme.colorScheme.onSurfaceVariant,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Yorum alanı
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Yorumunuzu yazın (isteğe bağlı)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 8),

          // Gönder butonu
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Gönder'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Yorum Kartı ─────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isDark,
    required this.isOwn,
    required this.onDelete,
  });

  final Review review;
  final bool isDark;
  final bool isOwn;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: review.avatarUrl != null
                    ? NetworkImage(review.avatarUrl!)
                    : null,
                onBackgroundImageError: review.avatarUrl != null
                    ? (_, __) {}
                    : null,
                child: review.avatarUrl == null
                    ? Text(
                        (review.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),

              // İsim + tarih
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.username ?? 'Anonim',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (review.createdAt != null)
                      Text(
                        _formatDate(review.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // Yıldızlar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < review.rating
                        ? AppColors.warning
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                    size: 16,
                  );
                }),
              ),

              // Silme (kendi yorumu ise)
              if (isOwn) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.colorScheme.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Yorumu Sil',
                ),
              ],
            ],
          ),

          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yorumu Sil'),
        content: const Text('Bu değerlendirmenizi silmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

// ─── Kitap şikayet bottom sheet ───────────────────────

class _ReportBookSheet extends StatefulWidget {
  const _ReportBookSheet({
    required this.book,
    required this.onClose,
    required this.onSubmit,
  });

  final Book book;
  final VoidCallback onClose;
  final Future<void> Function(String message) onSubmit;

  @override
  State<_ReportBookSheet> createState() => _ReportBookSheetState();
}

class _ReportBookSheetState extends State<_ReportBookSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kitabı şikayet et',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${widget.book.title}" hakkında şikayetinizi yazın.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Şikayet gerekçenizi kısaca açıklayın...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending
                ? null
                : () async {
                    final msg = _controller.text.trim();
                    if (msg.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Lütfen şikayet gerekçenizi yazın')),
                      );
                      return;
                    }
                    setState(() => _sending = true);
                    await widget.onSubmit(msg);
                    if (mounted) setState(() => _sending = false);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gönder'),
          ),
        ],
      ),
    );
  }
}
