import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../data/author_post_repository.dart';
import 'widgets/post_card.dart';

/// Bir yazarın tüm paylaşımlarını listeleyen özel sayfa.
class AuthorPostsPage extends ConsumerWidget {
  const AuthorPostsPage({super.key, required this.authorId});
  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(authorId));
    final profileAsync = ref.watch(profileByIdProvider(authorId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: profileAsync.when(
          data: (p) => Text(p?.username ?? 'Paylaşımlar'),
          loading: () => const Text('Paylaşımlar'),
          error: (_, __) => const Text('Paylaşımlar'),
        ),
        centerTitle: true,
      ),
      body: postsAsync.when(
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
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(authorPostsProvider(authorId)),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz paylaşım yok',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                theme: theme,
                isDark: isDark,
                maxLines: null,
                onTap: null,
              );
            },
          );
        },
      ),
    );
  }
}
