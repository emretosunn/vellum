import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_colors.dart';
import '../../settings/data/app_config_repository.dart';

// ─── Bildirim Modeli ───────────────────────────────────

enum NotificationType { newChapter, comment, review, promotion, system, earning, bookLike }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? refType;
  final String? refId;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.refType,
    this.refId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: (json['body'] as String?) ?? '',
      type: _parseType(json['type'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      refType: json['ref_type'] as String?,
      refId: json['ref_id'] as String?,
    );
  }

  static NotificationType _parseType(String? t) {
    switch (t) {
      case 'newChapter':
        return NotificationType.newChapter;
      case 'comment':
        return NotificationType.comment;
      case 'review':
        return NotificationType.review;
      case 'promotion':
        return NotificationType.promotion;
      case 'earning':
        return NotificationType.earning;
      case 'bookLike':
        return NotificationType.bookLike;
      default:
        return NotificationType.system;
    }
  }
}

// ─── Repository ─────────────────────────────────────────

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  Future<List<NotificationItem>> getNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return data.map((j) => NotificationItem.fromJson(j)).toList();
  }

  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (data as List).length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
  }
}

// ─── Providers ──────────────────────────────────────────

final notificationRepoProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  return ref.read(notificationRepoProvider).getNotifications();
});

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.read(notificationRepoProvider).getUnreadCount();
});

// ═════════════════════════════════════════════════════════
// BİLDİRİMLER EKRANI
// ═════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final appConfigAsync = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('notifications.title')),
        actions: [
          notificationsAsync.whenOrNull(
                data: (notifications) {
                  final unreadCount =
                      notifications.where((n) => !n.isRead).length;
                  if (unreadCount == 0) return null;
                  return TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(notificationRepoProvider)
                          .markAllAsRead();
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(translate('notifications.mark_all_read_snackbar')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(translate('notifications.mark_all_read')),
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(translate('subscription.error', args: {'error': err.toString()}))),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyNotifications(theme: theme);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(appConfigProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                appConfigAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (config) {
                    if (!config.announcementEnabled ||
                        config.announcementTitle.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _SystemAnnouncementCard(config: config);
                  },
                ),
                ...notifications.map(
                  (notification) => _NotificationCard(
                    notification: notification,
                    isDark: isDark,
                    onTap: () async {
                      if (!notification.isRead) {
                        await ref
                            .read(notificationRepoProvider)
                            .markAsRead(notification.id);
                        ref.invalidate(notificationsListProvider);
                        ref.invalidate(unreadNotificationCountProvider);
                      }
                      if (context.mounted &&
                          notification.refType == 'book' &&
                          notification.refId != null) {
                        context.push('/book/${notification.refId}');
                      }
                    },
                    onDismiss: () async {
                      await ref
                          .read(notificationRepoProvider)
                          .deleteNotification(notification.id);
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(translate('notifications.deleted_snackbar')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SystemAnnouncementCard extends StatelessWidget {
  const _SystemAnnouncementCard({required this.config});

  final RemoteAppConfig config;

  Color _backgroundForLevel(bool isDark) {
    switch (config.announcementLevel) {
      case 'success':
        return AppColors.success.withValues(alpha: isDark ? 0.16 : 0.10);
      case 'warning':
        return AppColors.warning.withValues(alpha: isDark ? 0.20 : 0.12);
      default:
        return AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);
    }
  }

  Color _iconColorForLevel() {
    switch (config.announcementLevel) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForLevel() {
    switch (config.announcementLevel) {
      case 'success':
        return Icons.celebration_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _backgroundForLevel(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _iconColorForLevel().withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _iconColorForLevel().withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForLevel(),
              color: _iconColorForLevel(),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.announcementTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (config.announcementBody.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    config.announcementBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bildirim Kartı ──────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationItem notification;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  ({IconData icon, Color color}) get _typeDetails {
    switch (notification.type) {
      case NotificationType.newChapter:
        return (icon: Icons.menu_book_rounded, color: AppColors.primary);
      case NotificationType.comment:
        return (icon: Icons.chat_bubble_rounded, color: Colors.blue);
      case NotificationType.review:
        return (icon: Icons.star_rounded, color: Colors.amber);
      case NotificationType.promotion:
        return (icon: Icons.local_offer_rounded, color: Colors.orange);
      case NotificationType.system:
        return (icon: Icons.info_rounded, color: Colors.grey);
      case NotificationType.earning:
        return (icon: Icons.monetization_on_rounded, color: Colors.green);
      case NotificationType.bookLike:
        return (icon: Icons.favorite_rounded, color: Colors.pink);
    }
  }

  String _timeAgo(BuildContext context) {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return translate('profile.time_just_now');
    if (diff.inMinutes < 60) return translate('profile.time_minutes_ago', args: {'n': '${diff.inMinutes}'});
    if (diff.inHours < 24) return translate('profile.time_hours_ago', args: {'n': '${diff.inHours}'});
    if (diff.inDays < 7) return translate('profile.time_days_ago', args: {'n': '${diff.inDays}'});
    return '${notification.createdAt.day}.${notification.createdAt.month}.${notification.createdAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = _typeDetails;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02))
                : (isDark
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04))
                  : AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: details.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(details.icon, size: 22, color: details.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: notification.isRead ? 0.5 : 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(context),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Boş Durum ───────────────────────────────────────

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            translate('notifications.empty_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            translate('notifications.empty_body'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
