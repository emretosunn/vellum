import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../data/author_post_repository.dart';
import '../data/book_like_repository.dart';
import '../data/book_repository.dart';
import '../data/follow_repository.dart';
import '../data/read_books_repository.dart';
import '../domain/book.dart';

String _t(String key, String fallback) {
  try {
    final t = translate(key);
    if (t.isEmpty || t == key) return fallback;
    return t;
  } catch (_) {
    return fallback;
  }
}

class AuthorProfileScreen extends ConsumerWidget {
  const AuthorProfileScreen({super.key, required this.authorId});
  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(profileByIdProvider(authorId));
    final booksAsync = ref.watch(authorBooksProvider(authorId));
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.id;
    final isOwnProfile = currentUserId != null && authorId == currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: authorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildErrorState(context, theme),
        data: (author) {
          if (author == null) return _buildErrorState(context, theme);

          return CustomScrollView(
            slivers: [
              // Profil Header
              _ProfileHeaderSliver(
                author: author,
                authorId: authorId,
                isDark: isDark,
                isOwnProfile: isOwnProfile,
              ),

              // İstatistik satırı
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

                      // İstatistikler (kitap, beğeni, takipçi, üyelik)
                      booksAsync.whenOrNull(
                            data: (books) => Consumer(
                              builder: (context, ref, _) {
                                final totalLikesAsync = ref.watch(authorTotalLikesProvider(authorId));
                                final followerCountAsync = ref.watch(followerCountProvider(authorId));
                                return totalLikesAsync.when(
                                  data: (totalLikes) => followerCountAsync.when(
                                    data: (followerCount) => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: totalLikes,
                                      followerCount: followerCount,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                    loading: () => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: totalLikes,
                                      followerCount: 0,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                    error: (_, __) => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: totalLikes,
                                      followerCount: 0,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                  ),
                                  loading: () => followerCountAsync.when(
                                    data: (followerCount) => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: 0,
                                      followerCount: followerCount,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                    loading: () => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: 0,
                                      followerCount: 0,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                    error: (_, __) => _StatsRow(
                                      bookCount: books.length,
                                      totalLikes: 0,
                                      followerCount: 0,
                                      isDark: isDark,
                                      theme: theme,
                                      memberSince: author.createdAt,
                                    ),
                                  ),
                                  error: (_, __) => _StatsRow(
                                    bookCount: books.length,
                                    totalLikes: 0,
                                    followerCount: followerCountAsync.valueOrNull ?? 0,
                                    isDark: isDark,
                                    theme: theme,
                                    memberSince: author.createdAt,
                                  ),
                                );
                              },
                            ),
                          ) ??
                          const SizedBox.shrink(),

                      // Okunan Kitaplar (sadece kendi profilde)
                      if (isOwnProfile) ...[
                        const SizedBox(height: 24),
                        _ReadBooksSection(userId: authorId),
                      ],

                      // Paylaşımlar (yazarın metin postları)
                      const SizedBox(height: 20),
                      _AuthorPostsSection(authorId: authorId, isDark: isDark, theme: theme),

                      // Bio bölümü
                      if (author.bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _BioSection(
                          bio: author.bio,
                          isDark: isDark,
                          theme: theme,
                        ).animate().fadeIn(delay: 250.ms),
                      ],

                      // Linkler bölümü
                      if (author.links.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _LinksSection(
                          links: author.links,
                          isDark: isDark,
                          theme: theme,
                        ).animate().fadeIn(delay: 300.ms),
                      ],

                      const SizedBox(height: 28),

                      // Kitaplar başlık
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
                            translate('profile.published_books'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Kitap listesi
              booksAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(translate('library.books_load_error')),
                  ),
                ),
                data: (books) {
                  if (books.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyBooksWidget(theme: theme),
                    );
                  }

                  final isWide = !context.isMobile;

                  if (isWide) {
                    return _BooksGrid(
                      books: books,
                      isDark: isDark,
                      theme: theme,
                      horizontalPadding: context.responsive(
                        mobile: 16.0,
                        tablet: 32.0,
                        desktop: 64.0,
                      ),
                    );
                  }

                  return _BooksList(
                    books: books,
                    isDark: isDark,
                    theme: theme,
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(translate('profile.author_not_found'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => context.pop(),
            child: Text(translate('common.back')),
          ),
        ],
      ),
    );
  }
}

// ─── Profil Header Sliver ─────────────────────────

class _ProfileHeaderSliver extends ConsumerWidget {
  const _ProfileHeaderSliver({
    required this.author,
    required this.authorId,
    required this.isDark,
    required this.isOwnProfile,
  });

  final Profile author;
  final String authorId;
  final bool isDark;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.id;
    final isFollowingAsync = currentUserId != null && !isOwnProfile
        ? ref.watch(isFollowingProvider((followerId: currentUserId, followingId: authorId)))
        : null;

    // Yükseklik: avatar + isim + rozet + (Takip et butonu) — taşmayı önlemek için yeterli
    const double expandedHeight = 320;
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
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient arka plan
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
              ),
            ),

            // Dekoratif daireler
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),

            // Profil içeriği (sabit yükseklikte taşma olmaması için sıkı boşluklar)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),

                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.15),
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 36,
                              ),
                            )
                          : null,
                    ),
                  ).animate().scale(
                        delay: 100.ms,
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 14),

                  // İsim + rozetler
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        author.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (author.isVerifiedAuthor) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 6),

                  // PRO rozeti
                  if (author.isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        translate('profile.pro_author'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack,
                        ),

                  // Takip et / Takipten çık — PRO Yazar'ın hemen altında, aksiyonlu buton
                  if (!isOwnProfile && currentUserId != null && isFollowingAsync != null)
                    isFollowingAsync.when(
                      data: (following) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _FollowActionButton(
                          isFollowing: following,
                          onPressed: () async {
                            final repo = ref.read(followRepositoryProvider);
                            if (following) {
                              await repo.unfollow(followerId: currentUserId, followingId: authorId);
                            } else {
                              await repo.follow(followerId: currentUserId, followingId: authorId);
                            }
                            ref.invalidate(isFollowingProvider((followerId: currentUserId, followingId: authorId)));
                            ref.invalidate(followingIdsProvider);
                            ref.invalidate(followingFeedProvider);
                            ref.invalidate(followerCountProvider(authorId));
                          },
                        ),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: 140,
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
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

/// Profil header'da kullanılan Takip et / Takipten çık aksiyon butonu (PRO Yazar altında).
class _FollowActionButton extends StatelessWidget {
  const _FollowActionButton({
    required this.isFollowing,
    required this.onPressed,
  });
  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isFollowing
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: isFollowing ? 0.4 : 0.9),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                  color: isFollowing ? Colors.white : AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isFollowing ? translate('profile.unfollow') : translate('profile.follow'),
                  style: TextStyle(
                    color: isFollowing ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

// ─── Yazar paylaşımları bölümü ─────────────────────────

class _AuthorPostsSection extends ConsumerWidget {
  const _AuthorPostsSection({required this.authorId, required this.isDark, required this.theme});
  final String authorId;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(authorId));
    return postsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary, AppColors.secondary]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(translate('profile.posts'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...posts.map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.content, style: theme.textTheme.bodyMedium, maxLines: 10, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(_formatPostDate(post.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )),
          ],
        );
      },
    );
  }

  static String _formatPostDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return translate('profile.time_just_now');
    if (diff.inMinutes < 60) return translate('profile.time_minutes_ago', args: {'n': '${diff.inMinutes}'});
    if (diff.inHours < 24) return translate('profile.time_hours_ago', args: {'n': '${diff.inHours}'});
    if (diff.inDays < 7) return translate('profile.time_days_ago', args: {'n': '${diff.inDays}'});
    return '${d.day}.${d.month}.${d.year}';
  }
}

// ─── İstatistik Satırı ─────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.bookCount,
    required this.totalLikes,
    required this.followerCount,
    required this.isDark,
    required this.theme,
    this.memberSince,
  });

  final int bookCount;
  final int totalLikes;
  final int followerCount;
  final bool isDark;
  final ThemeData theme;
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatCard(
          icon: Icons.auto_stories_rounded,
          label: translate('profile.stat_books'),
          value: '$bookCount',
          isDark: isDark,
          theme: theme,
        ),
        const SizedBox(height: 8),
        _StatCard(
          icon: Icons.favorite_rounded,
          label: translate('profile.stat_likes'),
          value: _formatCount(totalLikes),
          isDark: isDark,
          theme: theme,
        ),
        const SizedBox(height: 8),
        _StatCard(
          icon: Icons.people_rounded,
          label: translate('profile.stat_followers'),
          value: _formatCount(followerCount),
          isDark: isDark,
          theme: theme,
        ),
        const SizedBox(height: 8),
        _StatCard(
          icon: Icons.calendar_today_rounded,
          label: translate('profile.stat_membership'),
          value: _formatMemberSince(),
          isDark: isDark,
          theme: theme,
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _formatMemberSince() {
    if (memberSince == null) return '-';
    final monthKey = 'profile.month_${memberSince!.month}';
    return '${translate(monthKey)} ${memberSince!.year}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final ThemeData theme;

  /// İnce uzun yatay çubuk: icon | değer | etiket.
  static const double _barHeight = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _barHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Okunan Kitaplar (sadece kendi profilde) ────────

class _ReadBooksSection extends ConsumerWidget {
  const _ReadBooksSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final async = ref.watch(completedBooksProvider(userId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _t('library.read_books', 'Okunan Kitaplar'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < books.length - 1 ? 14 : 0,
                    ),
                    child: _ReadBookCard(
                      book: book,
                      isDark: isDark,
                      theme: theme,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReadBookCard extends StatelessWidget {
  const _ReadBookCard({
    required this.book,
    required this.isDark,
    required this.theme,
  });
  final Book book;
  final bool isDark;
  final ThemeData theme;

  static const double _coverWidth = 100;
  static const double _coverHeight = 150;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: SizedBox(
        width: _coverWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _coverWidth,
              height: _coverHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
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
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kitap Listesi (Mobil) ─────────────────────────

class _BooksList extends StatelessWidget {
  const _BooksList({
    required this.books,
    required this.isDark,
    required this.theme,
  });

  final List<Book> books;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            return RepaintBoundary(
              child: _BookListItem(
              book: book,
              isDark: isDark,
              theme: theme,
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 350 + index * 60))
                .slideX(begin: 0.03, curve: Curves.easeOutCubic),
            );
          },
          childCount: books.length,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  const _BookListItem({
    required this.book,
    required this.isDark,
    required this.theme,
  });

  final Book book;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/book/${book.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                // Kapak görseli
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 86,
                    child: (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
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
                  ),
                ),
                const SizedBox(width: 14),

                // Kitap bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          color: AppColors.primary.withValues(alpha: 0.5),
          size: 28,
        ),
      ),
    );
  }
}

// ─── Kitap Grid (Tablet/Desktop) ─────────────────

class _BooksGrid extends StatelessWidget {
  const _BooksGrid({
    required this.books,
    required this.isDark,
    required this.theme,
    required this.horizontalPadding,
  });

  final List<Book> books;
  final bool isDark;
  final ThemeData theme;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.isDesktop ? 3 : 2;

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.72,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            return _BookGridItem(
              book: book,
              isDark: isDark,
              theme: theme,
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 350 + index * 80))
                .scale(
                  begin: const Offset(0.95, 0.95),
                  curve: Curves.easeOutCubic,
                );
          },
          childCount: books.length,
        ),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  const _BookGridItem({
    required this.book,
    required this.isDark,
    required this.theme,
  });

  final Book book;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/book/${book.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kapak görseli
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
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
                ),
              ),

              // Kitap bilgisi
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            book.summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 14,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            translate('library.read'),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─── Bio Bölümü ────────────────────────────────────

class _BioSection extends StatelessWidget {
  const _BioSection({
    required this.bio,
    required this.isDark,
    required this.theme,
  });

  final String bio;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
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
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                translate('library.about'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Linkler Bölümü ────────────────────────────────

class _LinksSection extends StatelessWidget {
  const _LinksSection({
    required this.links,
    required this.isDark,
    required this.theme,
  });

  final List<Map<String, dynamic>> links;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links.map((link) {
        final title = link['title']?.toString() ?? '';
        final url = link['url']?.toString() ?? '';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launcher.launchUrl(
                  uri,
                  mode: launcher.LaunchMode.externalApplication,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getLinkIcon(title),
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getLinkIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('twitter') || lower.contains('x.com')) {
      return Icons.alternate_email;
    }
    if (lower.contains('instagram')) return Icons.camera_alt_outlined;
    if (lower.contains('youtube')) return Icons.play_circle_outline;
    if (lower.contains('github')) return Icons.code;
    if (lower.contains('linkedin')) return Icons.business_center_outlined;
    if (lower.contains('web') || lower.contains('site')) {
      return Icons.language;
    }
    return Icons.link;
  }
}

// ─── Boş Kitap Widget ─────────────────────────────

class _EmptyBooksWidget extends StatelessWidget {
  const _EmptyBooksWidget({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              translate('profile.no_books_yet'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
