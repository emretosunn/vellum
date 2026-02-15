import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';

class WriterStudioScreen extends ConsumerWidget {
  const WriterStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final myBooksAsync = ref.watch(myBooksProvider);
    final theme = Theme.of(context);

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

                // Yazar değilse → Yazar Ol ekranı
                if (!profile.isVerifiedAuthor) {
                  return _BecomeAuthorCard(ref: ref, userId: profile.id);
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Yazar ise → Kitaplarım
          SliverToBoxAdapter(
            child: profileAsync.whenOrNull(
              data: (profile) {
                if (profile == null || !profile.isVerifiedAuthor) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kitaplarım',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showCreateBookDialog(context, ref),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Yeni Kitap'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Kitap listesi
          myBooksAsync.when(
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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant),
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
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = books[index];
                    return _BookListItem(book: book)
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: index * 80))
                        .slideX(begin: 0.05);
                  },
                  childCount: books.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateBookDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Yeni Kitap Oluştur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Kitap Adı',
                  hintText: 'Kitabınızın başlığını girin',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                decoration: const InputDecoration(
                  labelText: 'Özet',
                  hintText: 'Kısa bir özet yazın',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                final profile =
                    await ref.read(currentProfileProvider.future);
                if (profile == null) return;

                await ref.read(bookRepositoryProvider).createBook(
                      authorId: profile.id,
                      title: titleController.text.trim(),
                      summary: summaryController.text.trim(),
                    );

                ref.invalidate(myBooksProvider);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Oluştur'),
            ),
          ],
        );
      },
    );
  }
}

class _BecomeAuthorCard extends StatelessWidget {
  const _BecomeAuthorCard({required this.ref, required this.userId});
  final WidgetRef ref;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Yazar Ol',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Kitaplarınızı yayınlayın, okuyucularınızla buluşun '
                've token kazanın!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(authRepositoryProvider)
                        .becomeAuthor(userId);
                    ref.invalidate(currentProfileProvider);
                  },
                  icon: const Icon(Icons.auto_stories),
                  label: const Text('Yazar Hesabına Geç'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}

class _BookListItem extends StatelessWidget {
  const _BookListItem({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              gradient: LinearGradient(
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
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/book/${book.id}'),
        ),
      ),
    );
  }
}
