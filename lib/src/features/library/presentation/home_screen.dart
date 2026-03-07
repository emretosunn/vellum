import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../../../services/in_app_update_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/author_post_repository.dart';
import '../../library/data/book_like_repository.dart';
import '../../library/data/follow_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/data/connectivity_provider.dart';
import '../../library/domain/author_post.dart';
import '../../library/data/reading_progress_repository.dart';
import '../../library/data/review_repository.dart';
import '../../library/domain/book.dart';
import '../../library/offline/offline_book.dart';
import '../../library/offline/offline_download_manager.dart';
import '../../notifications/presentation/notifications_screen.dart';

/// Saate göre selamlama (referans tasarım: GOOD MORNING / EVENING)
String _timeBasedGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'İYİ SABAHLAR';
  if (hour < 18) return 'İYİ GÜNLER';
  return 'İYİ AKŞAMLAR';
}

bool _homeVerticalListAnimated = false;

enum HomeTab {
  explore,
  following,
}

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.explore);

/// Ana sayfa üst başlık: selamlama + avatar + bildirim.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Row(
        children: [
          profileAsync.when(
            data: (profile) {
              final avatarUrl = profile?.avatarUrl;
              return GestureDetector(
                onTap: () {
                  if (profile != null) context.push('/author/${profile.id}');
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  onBackgroundImageError: (avatarUrl != null && avatarUrl.isNotEmpty) ? (_, __) {} : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          (profile?.username.isNotEmpty == true ? profile!.username[0] : 'O').toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              );
            },
            loading: () => const CircleAvatar(radius: 20, child: SizedBox()),
            error: (_, __) => CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text('O', style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeBasedGreeting(),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                ),
                profileAsync.when(
                  data: (profile) => Text(
                    profile?.username ?? 'Okuyucu',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  loading: () => const SizedBox(height: 26),
                  error: (_, __) => Text('Okuyucu', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                return IconButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: Icon(Icons.notifications_outlined, color: theme.colorScheme.onSurface, size: 24),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(left: 0, top: 0, right: 0, bottom: 0, child: InAppUpdateTrigger()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HomeHeader(),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Material(
                          color: theme.scaffoldBackgroundColor,
                          child: TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            indicatorColor: AppColors.primary,
                            tabs: const [
                              Tab(text: 'Keşfet'),
                              Tab(text: 'Takip Edilenler'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _DiscoverTab(),
                              _FollowingFeedTab(),
                            ],
                          ),
                        ),
                      ],
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
}

/// Keşfet sekmesi: mevcut ana sayfa içeriği (arama, hero, kitaplar, indirilenler).
class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(searchedBooksProvider);
    final recentAsync = ref.watch(recentBooksProvider);
    final connectivityAsync = ref.watch(connectivityProvider);
    final offlineBooksAsync = ref.watch(offlineBooksListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Bağlantı bilinene kadar Keşfet içeriğini göster (beyaz ekran olmasın)
    final isOffline = connectivityAsync.when(
      data: isOfflineFromConnectivity,
      loading: () => false,
      error: (_, __) => false,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(connectivityProvider);
        ref.invalidate(offlineBooksListProvider);
        ref.invalidate(searchedBooksProvider);
        ref.invalidate(publishedBooksProvider);
        ref.invalidate(featuredBooksProvider);
        ref.invalidate(recentBooksProvider);
        ref.invalidate(unreadNotificationCountProvider);
        ref.invalidate(continueReadingEntriesProvider);
        ref.invalidate(continueReadingBooksProvider);
        ref.invalidate(likedBooksProvider);
      },
      child: ClipRect(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
                  if (isOffline) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'Çevrimdışısınız. İndirdiğiniz kitaplar aşağıda.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _IndirilenlerSliver(offlineBooksAsync: offlineBooksAsync, theme: theme, isDark: isDark),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ] else ...[
                  // ─── Arama ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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

                  // ─── İndirilenler (online iken de listele) ─────────────────
                  _IndirilenlerSliver(
                    offlineBooksAsync: offlineBooksAsync,
                    theme: theme,
                    isDark: isDark,
                    showWhenEmpty: false,
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
                        height: 302,
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
                        height: 302,
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
                        // ─── Devam Et (yarıda kalan okumalar) ──────
                        const _ContinueReadingSection(),
                        const SizedBox(height: 28),
                        // ─── Popüler Kitaplar (Yatay, en fazla 5) ──────
                        _SectionHeader(
                          title: 'Popüler Kitaplar',
                          onSeeAll: null,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 302,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: displayBooks.length,
                            itemBuilder: (context, index) {
                              final book = displayBooks[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
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
                        const SizedBox(height: 28),
                        // ─── Beğenilenler ──────
                        const _LikedBooksSection(),
                        const SizedBox(height: 28),
                        // ─── Sizin İçin Seçilenler (son 5, görüntülenme + beğeni) ──────
                        _SectionHeader(
                          title: 'Sizin İçin Seçilenler',
                          onSeeAll: () => context.push('/books'),
                        ),
                        const SizedBox(height: 14),
                        ...recentBooks.asMap().entries.map((entry) {
                          final card = Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: _VerticalBookCard(book: entry.value),
                          );

                          if (_homeVerticalListAnimated) {
                            return card;
                          }

                          final animated = card
                              .animate()
                              .fadeIn(
                                delay: Duration(
                                  milliseconds: entry.key * 80,
                                ),
                              )
                              .slideY(begin: 0.05);

                          if (entry.key == recentBooks.length - 1) {
                            _homeVerticalListAnimated = true;
                          }

                          return animated;
                        }),
                        const SizedBox(height: 120),
                      ]),
                    );
                  },
                );
              },
            ),
                  ], // else branch (online content)
                ],
              ),
            ),
          );
  }
}

/// Takip Edilenler sekmesi: takip ettiğin yazarların metin paylaşımları.
class _FollowingFeedTab extends ConsumerWidget {
  const _FollowingFeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followingFeedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(followingFeedProvider);
        ref.invalidate(followingIdsProvider);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Paylaşımlar yüklenemedi', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(followingFeedProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
              children: [
                Icon(Icons.people_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Takip ettiğin yazarların paylaşımları burada',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yazar profillerinden takip et butonuna basarak yazarları takip edebilirsin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _FeedPostCard(post: post, isDark: isDark);
            },
          );
        },
      ),
    );
  }
}

/// Tek bir post kartı (yazar adı + metin).
class _FeedPostCard extends ConsumerWidget {
  const _FeedPostCard({required this.post, required this.isDark});
  final AuthorPost post;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(profileByIdProvider(post.authorId));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: () => context.push('/author/${post.authorId}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                authorAsync.when(
                  data: (profile) => Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: (profile?.avatarUrl == null || (profile?.avatarUrl ?? '').isEmpty)
                            ? Text(
                                (profile?.username.isNotEmpty == true ? profile!.username[0] : '?').toUpperCase(),
                                style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        profile?.username ?? 'Yazar',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(height: 36),
                  error: (_, __) => Text('Yazar', style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 10),
                Text(
                  post.content,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatPostDate(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatPostDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${d.day}.${d.month}.${d.year}';
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
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Günün Hikayesi',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ÖNE ÇIKAN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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

// ─── Home Tab Switcher (Keşfet / Takip Edilenler) ──────────────────────

class _HomeTabSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final current = ref.watch(homeTabProvider);

    Widget buildChip(HomeTab tab, String label) {
      final selected = current == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => ref.read(homeTabProvider.notifier).state = tab,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? AppColors.primary : AppColors.primary)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          buildChip(HomeTab.explore, 'Keşfet'),
          buildChip(HomeTab.following, 'Takip Edilenler'),
        ],
      ),
    );
  }
}

// ─── Takip Edilenler Feed Sliver ───────────────────────────────────────

class _FollowingFeedSliver extends ConsumerWidget {
  const _FollowingFeedSliver({required this.theme, required this.isDark});

  final ThemeData theme;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(followingFeedProvider);

    return feedAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Takip edilen yazarların paylaşımları yüklenemedi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz takip ettiğin yazar yok ya da hiç paylaşım yok.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yazar profillerinden \"Takip Et\" diyerek akışını doldurabilirsin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final post = posts[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: _AuthorPostCard(post: post, isDark: isDark),
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }
}

class _AuthorPostCard extends ConsumerWidget {
  const _AuthorPostCard({required this.post, required this.isDark});

  final AuthorPost post;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileByIdProvider(post.authorId));

    final date = post.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              profileAsync.when(
                data: (profile) {
                  final avatarUrl = profile?.avatarUrl;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    onBackgroundImageError:
                        avatarUrl != null ? (_, __) {} : null,
                    child: avatarUrl == null
                        ? Text(
                            (profile?.username.isNotEmpty == true
                                    ? profile!.username[0]
                                    : 'Y')
                                .toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  );
                },
                loading: () => const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                ),
                error: (_, __) => const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileAsync.when(
                      data: (profile) => Text(
                        profile?.username ?? 'Yazar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      loading: () => Container(
                        width: 80,
                        height: 12,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      error: (_, __) => Text(
                        'Yazar',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBookCard extends ConsumerWidget {
  const _HeroBookCard({required this.book, required this.isDark});
  final Book book;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseColor = isDark ? const Color(0xFF10101A) : Colors.white;

    // Yazar ismini profilden çek (varsa)
    final authorAsync = ref.watch(profileByIdProvider(book.authorId));
    final authorName = authorAsync.maybeWhen(
      data: (p) => p?.username ?? 'Bilinmeyen Yazar',
      orElse: () => 'Bilinmeyen Yazar',
    );

    final category = (book.category != null && book.category!.isNotEmpty)
        ? book.category!
        : 'Tür belirtilmemiş';

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    baseColor,
                    const Color(0xFF181824),
                  ]
                : [
                    Colors.white,
                    Colors.white,
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Kapak
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: (book.coverImageUrl != null &&
                        book.coverImageUrl!.isNotEmpty)
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
            const SizedBox(width: 16),
            // Metin alanı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

// ─── İndirilenler (çevrimdışı kitaplar) ───────────────────────────────────

class _IndirilenlerSliver extends StatelessWidget {
  const _IndirilenlerSliver({
    required this.offlineBooksAsync,
    required this.theme,
    required this.isDark,
    this.showWhenEmpty = true,
  });
  final AsyncValue<List<OfflineBook>> offlineBooksAsync;
  final ThemeData theme;
  final bool isDark;
  /// Çevrimdışı modda true (boşken de mesaj göster). Online modda false (boşken satır gösterme).
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: offlineBooksAsync.when(
        loading: () => showWhenEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : const SizedBox.shrink(),
        error: (_, __) => showWhenEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Text(
                  'İndirilen kitaplar yüklenemedi.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            : const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) {
            if (!showWhenEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'İndirilenler',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    'Henüz indirilmiş kitabınız yok. İnternet bağlantısı varken kitapları indirebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
                child: Text(
                  'İndirilenler',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              SizedBox(
                height: 302,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final offlineBook = list[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _OfflineBookCard(
                        offlineBook: offlineBook,
                        theme: theme,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfflineBookCard extends StatelessWidget {
  const _OfflineBookCard({
    required this.offlineBook,
    required this.theme,
    required this.isDark,
  });
  final OfflineBook offlineBook;
  final ThemeData theme;
  final bool isDark;

  static const double _coverWidth = 120;
  static const double _coverHeight = 180;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/reader/${offlineBook.bookId}'),
      child: SizedBox(
        width: _coverWidth,
        height: 298,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (offlineBook.coverImage.isNotEmpty)
                    ? Image.network(
                        offlineBook.coverImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Image.asset(
                          AppAssets.defaultBookCover,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Image.asset(
                        AppAssets.defaultBookCover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              offlineBook.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              offlineBook.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
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

// ─── Devam Et bölümü (yarıda kalan okumalar) ─────────────────────────────

class _ContinueReadingSection extends ConsumerWidget {
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueReadingBooksProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SectionHeader(title: 'Devam Et', onSeeAll: null),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 302,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => context.push('/reader/${item.book.id}?chapter=${item.chapterIndex}'),
                      child: _HorizontalBookCard(book: item.book),
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

// ─── Beğenilenler bölümü ────────────────────────────────────────────────

class _LikedBooksSection extends ConsumerWidget {
  const _LikedBooksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedBooksProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SectionHeader(title: 'Beğenilenler', onSeeAll: null),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 302,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final book = list[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _HorizontalBookCard(book: book),
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
        height: 298,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                child: (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
                    ? Image.network(
                        book.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Image.asset(
                          AppAssets.defaultBookCover,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Image.asset(
                        AppAssets.defaultBookCover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // Başlık (tek satır, taşmayı önlemek için)
            Text(
              book.title,
              maxLines: 1,
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
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _formatCount(book.viewCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Consumer(
                  builder: (context, ref, _) {
                    final likeAsync = ref.watch(bookLikeCountProvider(book.id));
                    return likeAsync.when(
                      data: (count) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(count),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
            if (stats != null && stats.count > 0) ...[
              const SizedBox(height: 4),
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

String _formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (book.category != null && book.category!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.category!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(book.viewCount),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Consumer(
                        builder: (context, ref, _) {
                          final likeAsync = ref.watch(bookLikeCountProvider(book.id));
                          return likeAsync.when(
                            data: (count) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(count),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
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
                  const SizedBox(height: 6),
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
