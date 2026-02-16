import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';

// ─── Bildirim Modeli ───────────────────────────────────

enum NotificationType {
  newChapter,
  comment,
  promotion,
  system,
  earning,
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
}

// ─── Demo bildirimler (ileride Supabase'den gelecek) ──

final _demoNotifications = [
  NotificationItem(
    id: '1',
    title: 'Yeni Bölüm Yayınlandı',
    body: '"Kayıp Şehrin Sırları" kitabına yeni bir bölüm eklendi.',
    type: NotificationType.newChapter,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  NotificationItem(
    id: '2',
    title: 'Yeni Yorum',
    body: 'Ahmet_42 kitabınıza yorum yaptı: "Harika bir bölüm!"',
    type: NotificationType.comment,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  NotificationItem(
    id: '3',
    title: 'Token Kazancı',
    body: 'Kitabınız okundu ve 15 Token kazandınız.',
    type: NotificationType.earning,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    isRead: true,
  ),
  NotificationItem(
    id: '4',
    title: 'Hafta Sonu Kampanyası',
    body: 'Bu hafta sonu tüm token alımlarında %20 bonus!',
    type: NotificationType.promotion,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  NotificationItem(
    id: '5',
    title: 'Hoş Geldiniz!',
    body: 'InkToken\'a katıldığınız için teşekkür ederiz. Hemen keşfetmeye başlayın.',
    type: NotificationType.system,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    isRead: true,
  ),
];

// ─── Provider ──────────────────────────────────────────

final notificationsListProvider =
    StateProvider<List<NotificationItem>>((ref) => _demoNotifications);

// ═════════════════════════════════════════════════════════
// BİLDİRİMLER EKRANI
// ═════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                // Tümünü okundu işaretle
                ref.read(notificationsListProvider.notifier).state =
                    notifications
                        .map((n) => NotificationItem(
                              id: n.id,
                              title: n.title,
                              body: n.body,
                              type: n.type,
                              createdAt: n.createdAt,
                              isRead: true,
                            ))
                        .toList();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tüm bildirimler okundu olarak işaretlendi ✓'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tümünü Oku'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _EmptyNotifications(theme: theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  isDark: isDark,
                  onTap: () {
                    // Okundu olarak işaretle
                    if (!notification.isRead) {
                      final updated = List<NotificationItem>.from(notifications);
                      updated[index] = NotificationItem(
                        id: notification.id,
                        title: notification.title,
                        body: notification.body,
                        type: notification.type,
                        createdAt: notification.createdAt,
                        isRead: true,
                      );
                      ref.read(notificationsListProvider.notifier).state = updated;
                    }
                  },
                  onDismiss: () {
                    final updated = List<NotificationItem>.from(notifications);
                    updated.removeAt(index);
                    ref.read(notificationsListProvider.notifier).state = updated;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bildirim silindi'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: index * 50))
                    .slideX(begin: 0.05);
              },
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
      case NotificationType.promotion:
        return (icon: Icons.local_offer_rounded, color: Colors.orange);
      case NotificationType.system:
        return (icon: Icons.info_rounded, color: Colors.grey);
      case NotificationType.earning:
        return (icon: Icons.monetization_on_rounded, color: Colors.green);
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    if (diff.inDays < 7) return '${diff.inDays}g önce';
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
              // İkon
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
              // İçerik
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
                            decoration: BoxDecoration(
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
                      _timeAgo,
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
            'Bildirim Yok',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bildirimleriniz burada görünecek.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95));
  }
}
