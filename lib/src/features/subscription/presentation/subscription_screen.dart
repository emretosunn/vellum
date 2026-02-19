import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../data/subscription_repository.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final paymentsAsync = ref.watch(paymentHistoryProvider);
    const navBarSpace = 104.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: const Text('Abonelik')),
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

                final isActive = profile.hasActiveSubscription;

                final payments =
                    paymentsAsync.valueOrNull ?? <PaymentRecord>[];

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SubscriptionStatusCard(
                        isActive: isActive,
                        subEndDate: profile.subEndDate,
                      ),
                      const SizedBox(height: 24),

                      if (isActive) ...[
                        _SubscriptionDetails(profile: profile),
                        const SizedBox(height: 24),
                        const _ActiveBenefitsCard(),
                        const SizedBox(height: 24),
                      ] else ...[
                        const _PaywallButton(),
                        const SizedBox(height: 16),
                        _SectionHeader(title: 'veya Manuel Plan Seçin'),
                        const SizedBox(height: 12),
                        _buildPlans(context, ref, profile.id),
                        const SizedBox(height: 24),
                      ],

                      const _SectionHeader(
                          title: 'Vellum Pro ile Neler Kazanırsınız?'),
                      const SizedBox(height: 12),
                      ..._features.map(
                        (f) => _FeatureItem(
                          icon: f.icon,
                          title: f.title,
                          subtitle: f.subtitle,
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (payments.isNotEmpty) ...[
                        const _SectionHeader(title: 'Ödeme Geçmişi'),
                        const SizedBox(height: 12),
                        _PaymentHistoryList(payments: payments),
                        const SizedBox(height: 16),
                      ],

                      const _SectionHeader(title: 'Sıkça Sorulan Sorular'),
                      const SizedBox(height: 12),
                      const _FaqSection(),

                      SizedBox(height: navBarSpace + bottomPad),
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

  Widget _buildPlans(BuildContext context, WidgetRef ref, String userId) {
    final isMobile = context.isMobile;

    final plans = [
      _PlanCard(
        title: 'Aylık',
        price: '₺49,99',
        period: '/ay',
        features: const [
          'Sınırsız kitap oluşturma',
          'Yazar rozeti',
          'Yayınlama yetkisi',
        ],
        isPrimary: false,
        onTap: () => _handleSubscribe(context, ref, userId, 30),
      ),
      _PlanCard(
        title: 'Yıllık',
        price: '₺399,99',
        period: '/yıl',
        features: const [
          'Tüm aylık özellikler',
          '%33 tasarruf',
          'Öncelikli destek',
        ],
        isPrimary: true,
        badge: 'En Popüler',
        onTap: () => _handleSubscribe(context, ref, userId, 365),
      ),
    ];

    if (isMobile) {
      return Column(
        children: plans
            .map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: p,
                ))
            .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plans
          .map((p) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: p,
                ),
              ))
          .toList(),
    );
  }

  Future<void> _handleSubscribe(
    BuildContext context,
    WidgetRef ref,
    String userId,
    int days,
  ) async {
    final planName = days == 365 ? 'Yıllık' : 'Aylık';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abonelik Onayı'),
        content: Text(
          '$planName plana abone olmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abone Ol'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .activateSubscription(userId: userId, durationDays: days);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(paymentHistoryProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aboneliğiniz başarıyla aktifleştirildi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ─── Paywall Button ──────────────────────────────

class _PaywallButton extends StatelessWidget {
  const _PaywallButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Abonelik için aşağıdaki planlardan birini seçebilirsiniz.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.workspace_premium_rounded, size: 22),
          label: const Text(
            'Vellum Pro\'ya Abone Ol',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ─── Abonelik Durum Kartı ────────────────────────

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({
    required this.isActive,
    this.subEndDate,
  });

  final bool isActive;
  final DateTime? subEndDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [AppColors.primary, AppColors.secondary, AppColors.accent]
              : [Colors.grey.shade600, Colors.grey.shade800],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActive ? 'Aktif Abonelik' : 'Abonelik Yok',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'PRO' : 'FREE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isActive ? 'Vellum Pro' : 'Ücretsiz Hesap',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          if (isActive && subEndDate != null)
            Text(
              'Bitiş: ${subEndDate!.day}.${subEndDate!.month}.${subEndDate!.year}',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            )
          else if (isActive)
            const Text(
              'Aboneliğiniz aktif',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            )
          else
            const Text(
              'Yazarlık özelliklerini açmak için abone olun',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

// ─── Abonelik Detayları ──────────────────────────

class _SubscriptionDetails extends StatelessWidget {
  const _SubscriptionDetails({
    required this.profile,
  });

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endDate = profile.subEndDate;
    final daysLeft =
        endDate != null ? endDate.difference(DateTime.now()).inDays : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Abonelik Detayları',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _DetailRow(
              label: 'Plan',
              value: 'Vellum Pro',
              icon: Icons.workspace_premium_rounded,
            ),
            if (endDate != null) ...[
              _DetailRow(
                label: 'Bitiş Tarihi',
                value:
                    '${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')}.${endDate.year}',
                icon: Icons.calendar_today_rounded,
              ),
              _DetailRow(
                label: 'Kalan Gün',
                value: daysLeft != null && daysLeft > 0
                    ? '$daysLeft gün'
                    : 'Yenileme bekleniyor',
                icon: Icons.timelapse_rounded,
                valueColor: daysLeft != null && daysLeft > 7
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ] else ...[
              _DetailRow(
                label: 'Süre',
                value: 'Aktif',
                icon: Icons.timelapse_rounded,
                valueColor: AppColors.success,
              ),
            ],
            const _DetailRow(
              label: 'Durum',
              value: 'Aktif',
              icon: Icons.check_circle_outline_rounded,
              valueColor: AppColors.success,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Aboneliğinizi yönetmek için uygulama mağazanızın abonelik ayarlarını kullanabilirsiniz.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                label: const Text('Aboneliği Yönet'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aktif Avantajlar ────────────────────────────

class _ActiveBenefitsCard extends StatelessWidget {
  const _ActiveBenefitsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified,
                      color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aboneliğiniz Aktif',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tüm Pro özelliklere erişiminiz var',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            const _BenefitRow(
                icon: Icons.auto_stories,
                text: 'Sınırsız kitap oluşturma ve yayınlama'),
            const _BenefitRow(
                icon: Icons.edit_note,
                text: 'Yazı Stüdyosu tam erişim'),
            const _BenefitRow(
                icon: Icons.verified_user,
                text: 'Onaylı yazar rozeti'),
            const _BenefitRow(
                icon: Icons.support_agent,
                text: 'Öncelikli destek'),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ─── Plan Kartı ──────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isPrimary,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPrimary;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    period,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isPrimary
                  ? FilledButton(
                      onPressed: onTap,
                      child: const Text('Abone Ol'),
                    )
                  : OutlinedButton(
                      onPressed: onTap,
                      child: const Text('Abone Ol'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ödeme Geçmişi ──────────────────────────────

class _PaymentHistoryList extends StatelessWidget {
  const _PaymentHistoryList({required this.payments});
  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: payments.asMap().entries.map((entry) {
            final p = entry.value;
            final isLast = entry.key == payments.length - 1;

            return Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _statusColor(p.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _statusIcon(p.status),
                      color: _statusColor(p.status),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    p.planLabel,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    p.formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        p.formattedAmount,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              _statusColor(p.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(p.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      case 'refunded':
        return AppColors.secondary;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      case 'refunded':
        return Icons.replay_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

// ─── SSS ─────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _faqs = [
    (
      'Aboneliğimi nasıl yönetebilirim?',
      '"Aboneliği Yönet" butonuna tıklayarak plan değişikliği, iptal veya geri yükleme işlemlerini kolayca yapabilirsiniz.',
    ),
    (
      'İptal ettikten sonra ne olur?',
      'Aboneliğiniz dönem sonuna kadar aktif kalır. Dönem bitiminde Pro özelliklerinize erişim sona erer. Mevcut kitaplarınız yayında kalır.',
    ),
    (
      'Tekrar abone olabilir miyim?',
      'Evet, istediğiniz zaman tekrar abone olabilirsiniz. Aylık veya yıllık plan seçeneklerinden birini tercih edebilirsiniz.',
    ),
    (
      'İade politikası nedir?',
      'İade talepleri ilgili mağaza (App Store veya Google Play) üzerinden işlenir. Detaylar için Aboneliği Yönet ekranını kullanabilirsiniz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: _faqs
              .map((faq) => ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: const Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      faq.$1,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Text(
                        faq.$2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Özellik Verisi ──────────────────────────────

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}

const _features = [
  _FeatureData(
    icon: Icons.auto_stories,
    title: 'Sınırsız Kitap Oluşturma',
    subtitle: 'Dilediğiniz kadar kitap yazın ve yayınlayın.',
  ),
  _FeatureData(
    icon: Icons.edit_note,
    title: 'Zengin Metin Editörü',
    subtitle: 'Gelişmiş formatlama araçları ile profesyonel içerik üretin.',
  ),
  _FeatureData(
    icon: Icons.verified,
    title: 'Onaylı Yazar Rozeti',
    subtitle: 'Profilinizde güvenilir yazar rozetini taşıyın.',
  ),
  _FeatureData(
    icon: Icons.bar_chart,
    title: 'Detaylı İstatistikler',
    subtitle: 'Okuyucu analizleri ve kitap performansınızı takip edin.',
  ),
  _FeatureData(
    icon: Icons.support_agent,
    title: 'Öncelikli Destek',
    subtitle: 'Sorularınıza hızlı yanıt alın.',
  ),
];

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
