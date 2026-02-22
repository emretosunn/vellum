import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../data/book_like_repository.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';

class AuthorProfileScreen extends ConsumerWidget {
  const AuthorProfileScreen({super.key, required this.authorId});
  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(profileByIdProvider(authorId));
    final booksAsync = ref.watch(authorBooksProvider(authorId));
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
                isDark: isDark,
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

                      // İstatistikler (kitap sayısı, toplam beğeni, üyelik)
                      booksAsync.whenOrNull(
                            data: (books) => Consumer(
                              builder: (context, ref, _) {
                                final totalLikesAsync = ref.watch(authorTotalLikesProvider(authorId));
                                return totalLikesAsync.when(
                                  data: (totalLikes) => _StatsRow(
                                    bookCount: books.length,
                                    totalLikes: totalLikes,
                                    isDark: isDark,
                                    theme: theme,
                                    memberSince: author.createdAt,
                                  ),
                                  loading: () => _StatsRow(
                                    bookCount: books.length,
                                    totalLikes: 0,
                                    isDark: isDark,
                                    theme: theme,
                                    memberSince: author.createdAt,
                                  ),
                                  error: (_, __) => _StatsRow(
                                    bookCount: books.length,
                                    totalLikes: 0,
                                    isDark: isDark,
                                    theme: theme,
                                    memberSince: author.createdAt,
                                  ),
                                );
                              },
                            ),
                          ) ??
                          const SizedBox.shrink(),

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
                            'Yayınlanan Kitaplar',
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
                error: (_, __) => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Kitaplar yüklenemedi'),
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
          Text('Yazar bulunamadı', style: theme.textTheme.titleMedium),
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

// ─── Profil Header Sliver ─────────────────────────

class _ProfileHeaderSliver extends StatelessWidget {
  const _ProfileHeaderSliver({
    required this.author,
    required this.isDark,
  });

  final Profile author;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
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

            // Profil içeriği
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48),

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
                      child: const Text(
                        'PRO Yazar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).scale(
                          begin: const Offset(0.8, 0.8),
                          curve: Curves.easeOutBack,
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

// ─── İstatistik Satırı ─────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.bookCount,
    required this.totalLikes,
    required this.isDark,
    required this.theme,
    this.memberSince,
  });

  final int bookCount;
  final int totalLikes;
  final bool isDark;
  final ThemeData theme;
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.auto_stories_rounded,
            label: 'Kitap',
            value: '$bookCount',
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            label: 'Beğeni',
            value: _formatCount(totalLikes),
            isDark: isDark,
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_rounded,
            label: 'Üyelik',
            value: _formatMemberSince(),
            isDark: isDark,
            theme: theme,
          ),
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
    final months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${months[memberSince!.month - 1]} ${memberSince!.year}';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
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
            return _BookListItem(
              book: book,
              isDark: isDark,
              theme: theme,
            )
                .animate()
                .fadeIn(delay: Duration(milliseconds: 350 + index * 60))
                .slideX(begin: 0.03, curve: Curves.easeOutCubic);
          },
          childCount: books.length,
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
                            'Oku',
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
                'Hakkinda',
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
              'Henüz yayınlanmış kitap yok',
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
