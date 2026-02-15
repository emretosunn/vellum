import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';

import '../../library/data/book_repository.dart';
import '../../library/domain/book.dart';
import '../../studio/data/chapter_repository.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));
    final chaptersAsync = ref.watch(chaptersByBookProvider(bookId));
    final theme = Theme.of(context);

    return Scaffold(
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Kitap bulunamadı', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => context.pop(),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Kitap bulunamadı'));
          }

          return CustomScrollView(
            slivers: [
              // Kapak + Başlık
              SliverAppBar.large(
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                    child: book.coverImageUrl != null
                        ? Image.network(book.coverImageUrl!, fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              Icons.auto_stories_rounded,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Kitap Bilgisi
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Durum
                      Chip(
                        avatar: Icon(
                          Icons.circle,
                          size: 10,
                          color: book.status == BookStatus.published
                              ? Colors.green
                              : Colors.orange,
                        ),
                        label: Text(
                          book.status == BookStatus.published
                              ? 'Yayında'
                              : book.status == BookStatus.draft
                                  ? 'Taslak'
                                  : 'Arşivlendi',
                        ),
                      ),

                      if (book.summary.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Özet',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.summary,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],

                      const SizedBox(height: 24),
                      Text(
                        'Bölümler',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),

              // Bölüm Listesi
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
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.library_books_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                'Henüz bölüm eklenmemiş',
                                style: TextStyle(
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
                        final chapter = chapters[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(chapter.title),
                          subtitle: Text(
                            chapter.isFree
                                ? 'Ücretsiz'
                                : '${chapter.price} Token',
                          ),
                          trailing: chapter.isFree
                              ? const Icon(Icons.lock_open, color: Colors.green)
                              : const Icon(Icons.lock_outline),
                          onTap: () {
                            // TODO: Okuma ekranına yönlendir
                          },
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: index * 60),
                            )
                            .slideX(begin: 0.05);
                      },
                      childCount: chapters.length,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
