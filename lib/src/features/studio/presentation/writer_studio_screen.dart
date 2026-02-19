import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
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

    final isPro = isProAsync.valueOrNull ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Yazı Stüdyosu'),
          ),

          SliverToBoxAdapter(
            child: profileAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Hata: $err'),
              ),
              data: (profile) {
                if (profile == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Profil yüklenemedi'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Plan bilgisi kartı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PlanBadge(isPro: isPro),
            ),
          ),

          // Kitaplarım başlığı + yeni kitap butonu
          SliverToBoxAdapter(
            child: profileAsync.whenOrNull(
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();

                final bookCount =
                    myBooksAsync.valueOrNull?.length ?? 0;
                final canCreate = isPro || bookCount < _freeBookLimit;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kitaplarım',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: canCreate
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateBookScreen(),
                                  ),
                                )
                            : () => _showUpgradeDialog(context),
                        icon: Icon(
                          canCreate ? Icons.add : Icons.lock_outline,
                          size: 18,
                        ),
                        label: const Text('Yeni Kitap'),
                      ),
                    ],
                  ),
                );
              },
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
                    child: Text('Hata: $err'),
                  ),
                ),
                data: (books) {
                  if (books.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(theme: theme),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = books[index];
                        return _BookListItem(book: book, isPro: isPro);
                      },
                      childCount: books.length,
                    ),
                  );
                },
              );
            },
          ),

          // Free kullanıcılar için Pro avantajları
          if (!isPro)
            SliverToBoxAdapter(
              child: _ProFeaturesCard(
                onUpgrade: () => context.go('/subscription'),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitap Limiti'),
        content: const Text(
          'Ücretsiz planda en fazla $_freeBookLimit kitap oluşturabilirsiniz. '
          'Sınırsız kitap ve yayınlama için Vellum Pro\'ya geçin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/subscription');
            },
            child: const Text('Pro\'ya Geç'),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPro
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              )
            : null,
        color: isPro ? null : theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Icon(
            isPro ? Icons.workspace_premium_rounded : Icons.person_outline,
            color: isPro ? Colors.white : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'Vellum Pro' : 'Ücretsiz Plan',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPro
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  isPro
                      ? 'Sınırsız kitap · Yayınlama · İstatistikler'
                      : '$_freeBookLimit kitap · Sadece taslak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPro
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isPro)
            TextButton(
              onPressed: () => context.go('/subscription'),
              child: const Text('Yükselt'),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Henüz kitabınız yok',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk kitabınızı oluşturarak yazmaya başlayın!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
    final canPublish = isPro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: book.coverImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(book.coverImageUrl!,
                        fit: BoxFit.cover),
                  )
                : const Icon(Icons.book, color: Colors.white, size: 24),
          ),
          title: Text(
            book.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: book.status == BookStatus.published
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                book.status == BookStatus.published
                    ? 'Yayında'
                    : book.status == BookStatus.draft
                        ? 'Taslak'
                        : 'Arşivlendi',
              ),
              if (!canPublish && book.status == BookStatus.draft) ...[
                const SizedBox(width: 8),
                Icon(Icons.lock_outline,
                    size: 12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(
                  'Yayınlamak için Pro',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/book-editor/${book.id}'),
        ),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Pro ile Daha Fazlası',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _proFeature(theme, Icons.all_inclusive, 'Sınırsız kitap oluşturma'),
              _proFeature(theme, Icons.publish, 'Kitaplarını yayınlama'),
              _proFeature(theme, Icons.bar_chart, 'Okuyucu istatistikleri'),
              _proFeature(theme, Icons.verified, 'Onaylı yazar rozeti'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onUpgrade,
                  child: const Text('Vellum Pro\'ya Geç'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proFeature(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
