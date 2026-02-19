import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../data/subscription_repository.dart';

/// Studio gibi premium özelliklere erişmek isteyip
/// abone olmayan kullanıcılara gösterilen paywall widget'ı.
class PaywallWidget extends ConsumerWidget {
  const PaywallWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.accent.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pro ikon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Başlık
              Text(
                'Vellum Pro\'ya Geçin',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Açıklama
              Text(
                'Kitaplarınızı yayınlayın, okuyucularınızla buluşun '
                've yazarlık yolculuğunuza başlayın!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Avantajlar
              _PaywallBenefit(
                icon: Icons.auto_stories,
                text: 'Sınırsız kitap oluşturma ve yayınlama',
              ),
              _PaywallBenefit(
                icon: Icons.edit_note,
                text: 'Zengin metin editörü ile profesyonel yazım',
              ),
              _PaywallBenefit(
                icon: Icons.verified,
                text: 'Onaylı yazar rozeti',
              ),
              _PaywallBenefit(
                icon: Icons.bar_chart,
                text: 'Detaylı okuyucu istatistikleri',
              ),

              const SizedBox(height: 28),

              // Abonelik CTA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => context.go('/subscription'),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text(
                    'Vellum Pro\'ya Abone Ol',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => context.go('/subscription'),
                child: const Text('Planları Karşılaştır'),
              ),

              const SizedBox(height: 4),

              Text(
                'İstediğiniz zaman iptal edebilirsiniz',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }
}

class _PaywallBenefit extends StatelessWidget {
  const _PaywallBenefit({required this.icon, required this.text});
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
