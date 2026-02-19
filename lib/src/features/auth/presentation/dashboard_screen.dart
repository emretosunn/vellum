import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../../subscription/services/subscription_status_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Panel'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Çıkış Yap',
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(isProProvider);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: profileAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )),
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

                final isActive = profile.hasActiveSubscription;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Profil Kartı
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  profile.username.isNotEmpty
                                      ? profile.username[0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.username,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          isActive
                                              ? Icons.workspace_premium
                                              : Icons.person_outline,
                                          size: 16,
                                          color: isActive
                                              ? AppColors.primary
                                              : null,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isActive
                                              ? 'Vellum Pro'
                                              : 'Ücretsiz Hesap',
                                          style:
                                              theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.05),

                      const SizedBox(height: 16),

                      // Abonelik Durumu Kartı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive
                                ? [AppColors.primary, AppColors.secondary]
                                : [Colors.grey.shade600, Colors.grey.shade800],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.workspace_premium_rounded
                                  : Icons.lock_outline,
                              color: Colors.white70,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isActive ? 'Vellum Pro' : 'Ücretsiz',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isActive
                                  ? 'Aboneliğiniz aktif'
                                  : 'Yazarlık için Pro\'ya geçin',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            if (isActive && profile.subEndDate != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Bitiş: ${profile.subEndDate!.day}.${profile.subEndDate!.month}.${profile.subEndDate!.year}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.05),

                      const SizedBox(height: 24),

                      // Hızlı Erişim
                      Text(
                        'Hızlı Erişim',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!isActive) ...[
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.workspace_premium,
                                label: 'Pro\'ya Geç',
                                color: AppColors.primary,
                                onTap: () =>
                                    context.go('/subscription'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.edit_note,
                              label: 'Stüdyo',
                              color: Colors.orange,
                              onTap: () => context.go('/studio'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.settings,
                              label: 'Ayarlar',
                              color: Colors.blueGrey,
                              onTap: () => context.go('/settings'),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 400.ms),
                    ],
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
