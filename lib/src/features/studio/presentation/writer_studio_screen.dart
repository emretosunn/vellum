import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_assets.dart';
import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../../library/presentation/create_post_sheet.dart';
import '../../subscription/services/subscription_status_service.dart';
import 'create_book_screen.dart';

const int _freeBookLimit = 1;

class WriterStudioScreen extends ConsumerWidget {
  const WriterStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isProAsync = ref.watch(isProProvider);
    final myBooksAsync = ref.watch(myBooksProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPro = isProAsync.valueOrNull ?? false;

    final bottomPadding = MediaQuery.paddingOf(context).bottom + 98;

    return Scaffold(
      body: Stack(
        children: [
          ClipRect(
            child: CustomScrollView(
              slivers: [
            // Özel başlık alanı (gradient + tipografi)
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.18),
                          AppColors.primary.withValues(alpha: 0.06),
                          Colors.transparent,
                        ]
                      : [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('studio.writer_studio_title'),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
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
          ),
            ),

          // Profil yükleme alanı — yükseklik sabit (0) bırakılıyor ki Vellum Pro kartı kaymasın
          SliverToBoxAdapter(
            child: profileAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(translate('studio.load_error', args: {'error': '$err'})),
              ),
              data: (profile) {
                if (profile == null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(translate('settings.profile_not_found')),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Plan rozeti — özel kart (kayma olmaması için sabit sliver)
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _PlanBadge(isPro: isPro),
              ),
            ),
          ),

          // Kitaplarım başlığı (Yeni Kitap + Paylaşım sağ alttaki FAB’dan)
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: profileAsync.whenOrNull(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  final bookCount = myBooksAsync.valueOrNull?.length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('studio.my_books_title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          translate('studio.my_books_count',
                              args: {'n': bookCount.toString()}),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Kitap listesi
          profileAsync.when(
            loading: () =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (profile) {
              if (profile == null) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return myBooksAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      translate('studio.load_error', args: {'error': '$err'}),
                    ),
                  ),
                ),
                data: (books) {
                  if (books.isEmpty) {
                    return SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _EmptyState(theme: theme),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = books[index];
                          return RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                              key: ValueKey(book.id),
                              direction: DismissDirection.horizontal,
                              background: _BookSlideActionBackground(
                                icon: Icons.edit_rounded,
                                label: translate('common.edit'),
                                alignStart: true,
                              ),
                              secondaryBackground: _BookSlideActionBackground(
                                icon: Icons.delete_rounded,
                                label: translate('common.delete'),
                                alignStart: false,
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Düzenle: ekranı aç, listeyi yenile ama kartı silme.
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateBookScreen(
                                        initialBook: book,
                                      ),
                                    ),
                                  );
                                  ref.invalidate(myBooksProvider);
                                  ref.invalidate(publishedBooksProvider);
                                  ref.invalidate(searchedBooksProvider);
                                  return false;
                                } else {
                                  final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(
                                            translate(
                                              'studio.delete_book_title',
                                              args: {'title': book.title},
                                            ),
                                          ),
                                          content: Text(
                                            translate('studio.delete_book_confirm'),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text(translate('common.cancel')),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                              ),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(translate('common.delete')),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (!confirmed) return false;

                                  await ref.read(bookRepositoryProvider).deleteBook(book.id);
                                  ref.invalidate(myBooksProvider);
                                  ref.invalidate(publishedBooksProvider);
                                  ref.invalidate(searchedBooksProvider);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        translate(
                                          'studio.book_deleted',
                                          args: {'title': book.title},
                                        ),
                                      ),
                                    ),
                                  );

                                  return true;
                                }
                              },
                              child: _BookListItem(book: book, isPro: isPro),
                            ),
                          ),
                          );
                        },
                        childCount: books.length,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          if (!isPro)
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: _ProFeaturesCard(
                    onUpgrade: () => context.go('/subscription'),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
            ),
          ),
          Positioned(
            right: 32,
            bottom: bottomPadding,
            child: _StudioFAB(
              canCreate: isPro || (myBooksAsync.valueOrNull?.length ?? 0) < _freeBookLimit,
              onNewBook: () {
                if (isPro || (myBooksAsync.valueOrNull?.length ?? 0) < _freeBookLimit) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBookScreen()));
                } else {
                  _showUpgradeDialog(context);
                }
              },
              onCreatePost: () {
                final profile = profileAsync.valueOrNull;
                if (profile != null) showCreatePostSheet(context, ref, profile.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translate('studio.free_limit_title')),
        content: Text(
          translate('studio.free_limit_message',
              args: {'limit': '$_freeBookLimit'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(translate('common.ok')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/subscription');
            },
            child: Text(translate('subscription.subscribe_cta')),
          ),
        ],
      ),
    );
  }
}

// ─── Stüdyo FAB: sağ altta mor +, tıklanınca Yeni Kitap + Paylaşım yap ─────

class _StudioFAB extends StatefulWidget {
  const _StudioFAB({
    required this.canCreate,
    required this.onNewBook,
    required this.onCreatePost,
  });

  final bool canCreate;
  final VoidCallback onNewBook;
  final VoidCallback onCreatePost;

  @override
  State<_StudioFAB> createState() => _StudioFABState();
}

class _StudioFABState extends State<_StudioFAB> {
  bool _expanded = false;

  Widget _buildFabButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          _CreatePostFABOption(
            onTap: () {
              widget.onCreatePost();
              setState(() => _expanded = false);
            },
          ),
          const SizedBox(height: 12),
          _NewBookFABOption(
            canCreate: widget.canCreate,
            onTap: () {
              widget.onNewBook();
              setState(() => _expanded = false);
            },
          ),
          const SizedBox(height: 12),
        ],
        _buildFabButton(),
      ],
    );
  }
}

/// Paylaşım yap seçeneği: Yeni Kitap ile aynı stil — mor, beyaz ikon + metin.
class _CreatePostFABOption extends StatelessWidget {
  const _CreatePostFABOption({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                translate('studio.share_post_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni Kitap seçeneği: mor yuvarlak buton, beyaz + ve metin.
class _NewBookFABOption extends StatelessWidget {
  const _NewBookFABOption({
    required this.canCreate,
    required this.onTap,
  });

  final bool canCreate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: canCreate
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  )
                : null,
            color: canCreate ? null : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: canCreate
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                canCreate ? Icons.add_rounded : Icons.lock_outline_rounded,
                size: 20,
                color: canCreate
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                translate('studio.new_book'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: canCreate
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Plan Rozeti ─────────────────────────────────

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isPro
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              )
            : null,
        color: isPro ? null : theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.6 : 0.8,
            ),
        border: isPro ? null : Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: isPro
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPro
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPro ? Icons.workspace_premium_rounded : Icons.person_outline_rounded,
              color: isPro ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro
                      ? 'Vellum Pro'
                      : translate('subscription.free_plan'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isPro
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPro
                      ? translate('subscription.pro_plan_description')
                      : translate(
                          'studio.free_plan_summary',
                          args: {'limit': '$_freeBookLimit'},
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPro
                        ? Colors.white.withValues(alpha: 0.85)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro)
            TextButton(
              onPressed: () => context.go('/subscription'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: Text(translate('subscription.subscribe_cta')),
            ),
        ],
      ),
    );
  }
}

// ─── Boş Durum ──────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.secondary.withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              translate('studio.empty_state_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              translate('studio.empty_state_subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateBookScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        translate('studio.empty_state_cta'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

// ─── Kitap Listesi Elemanı ──────────────────────

class _BookListItem extends StatelessWidget {
  const _BookListItem({required this.book, required this.isPro});
  final Book book;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPublish = isPro;
    final isPublished = book.status == BookStatus.published;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/book-editor/${book.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Kapak / placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 56,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
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
                    Text(
                      book.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPublished
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: isPublished
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                book.status == BookStatus.published
                                    ? translate('library.published')
                                    : book.status == BookStatus.draft
                                        ? translate('library.draft')
                                        : translate('library.archived'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isPublished
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!canPublish && book.status == BookStatus.draft) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            translate('subscription.pro_badge'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookSlideActionBackground extends StatelessWidget {
  const _BookSlideActionBackground({
    required this.icon,
    required this.label,
    required this.alignStart,
  });

  final IconData icon;
  final String label;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment =
        alignStart ? Alignment.centerLeft : Alignment.centerRight;
    final padding = EdgeInsets.symmetric(horizontal: 24);

    return Container(
      decoration: BoxDecoration(
        color: alignStart
            ? AppColors.primary.withValues(alpha: 0.3)
            : Colors.redAccent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: padding,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            alignStart ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!alignStart) const SizedBox(width: 16),
          Icon(
            icon,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (alignStart) const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Pro Avantajları Kartı ──────────────────────

class _ProFeaturesCard extends StatelessWidget {
  const _ProFeaturesCard({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                translate('studio.pro_more_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _proFeature(
              theme,
              Icons.all_inclusive_rounded,
              translate('subscription.feature_unlimited')),
          _proFeature(theme, Icons.publish_rounded,
              translate('subscription.feature_studio')),
          _proFeature(theme, Icons.bar_chart_rounded,
              translate('subscription.feature4_title')),
          _proFeature(theme, Icons.verified_rounded,
              translate('subscription.feature_badge')),
          const SizedBox(height: 22),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onUpgrade,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    translate('subscription.subscribe_cta'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proFeature(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
