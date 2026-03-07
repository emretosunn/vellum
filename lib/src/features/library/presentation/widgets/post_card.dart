import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../constants/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/author_post.dart';

/// Paylaşım kartı: yazar avatar/ad + metin (son 2 satır veya tam) + tarih.
/// Hem Takip Edilenler feed'inde hem yazar profilinde kullanılır.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.theme,
    required this.isDark,
    this.maxLines = 2,
    this.onTap,
  });

  final AuthorPost post;
  final ThemeData theme;
  final bool isDark;
  /// null = tüm metin; 2 = önizleme (son 2 satır).
  final int? maxLines;
  final VoidCallback? onTap;

  static String formatPostDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${d.day}.${d.month}.${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorAsync = ref.watch(profileByIdProvider(post.authorId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                authorAsync.when(
                  data: (profile) => Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        onBackgroundImageError: (_, __) {},
                        child: (profile?.avatarUrl == null || (profile?.avatarUrl ?? '').isEmpty)
                            ? Text(
                                (profile?.username.isNotEmpty == true ? profile!.username[0] : '?').toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile?.username ?? 'Yazar',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  loading: () => Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.surfaceContainerHighest),
                      const SizedBox(width: 12),
                      Container(
                        height: 16,
                        width: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  error: (_, __) => Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text('?', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Text('Yazar', style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  post.content,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  formatPostDate(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
