import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../../constants/app_colors.dart';
import '../data/subscription_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../services/subscription_status_service.dart';

/// Plan seçim modalını gösterir. Cam saydam arka plan, yatay kaydırılabilir kartlar.
Future<bool?> showSubscriptionPlanModal(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: '',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            child: AnimatedOpacity(
              opacity: animation.value,
              duration: const Duration(milliseconds: 300),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.92,
                        maxHeight: MediaQuery.of(context).size.height * 0.88,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.75 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Consumer(
                        builder: (_, ref, __) => _SubscriptionPlanModalContent(
                          ref: ref,
                          onClose: () => Navigator.of(context).pop(false),
                          onSubscribed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _SubscriptionPlanModalContent extends ConsumerStatefulWidget {
  const _SubscriptionPlanModalContent({
    required this.ref,
    required this.onClose,
    required this.onSubscribed,
  });
  final WidgetRef ref;
  final VoidCallback onClose;
  final VoidCallback onSubscribed;

  @override
  ConsumerState<_SubscriptionPlanModalContent> createState() =>
      _SubscriptionPlanModalContentState();
}

class _SubscriptionPlanModalContentState
    extends ConsumerState<_SubscriptionPlanModalContent> {
  bool _isYearly = true;
  bool _isLoading = false;
  final _pageController = PageController(viewportFraction: 0.88);

  static const _monthlyPrice = 49.99;
  static const _yearlyPrice = 399.99;

  String _sub(String key, String fallback) {
    try {
      final t = translate(key);
      if (t.isEmpty || t == key) return fallback;
      return t;
    } catch (_) {
      return fallback;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = widget.ref.read(authRepositoryProvider).currentUser?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32),
              Text(
                '{ ${_sub('subscription.pricing_label', 'Fiyatlandırma')} }',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            _sub('subscription.premium_title', 'Her Planda Premium Araçların\nKeyfini Çıkarın'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        _ToolIconsRow(theme: theme, sub: _sub),
        const SizedBox(height: 20),
        Flexible(
          child: SizedBox(
            height: 460,
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              children: [
                _GlassPlanCard(
                  theme: theme,
                  planName: _sub('subscription.free_plan', 'Ücretsiz'),
                  accentColor: Colors.grey.shade600,
                  description: _sub('subscription.pro_description', 'Yazarlar için tasarlanmış araçlarla daha iyi içerik üretin.'),
                  features: [
                    (_sub('subscription.feature_unlimited', 'Sınırsız kitap oluşturma ve yayınlama'), false),
                    (_sub('subscription.feature_studio', 'Yazı Stüdyosu tam erişim'), false),
                    (_sub('subscription.feature_badge', 'Onaylı yazar rozeti'), false),
                    (_sub('subscription.feature_support', 'Öncelikli destek'), false),
                  ],
                  limitText: _sub('subscription.limit_3_books', 'En fazla 3 kitap'),
                  isPro: false,
                  onSubscribe: null,
                  isLoading: false,
                  sub: _sub,
                ),
                _GlassPlanCard(
                  theme: theme,
                  planName: 'Vellum Pro',
                  accentColor: AppColors.primary,
                  description: _sub('subscription.pro_description', 'Yazarlar için tasarlanmış araçlarla daha iyi içerik üretin.'),
                  features: [
                    (_sub('subscription.feature_unlimited', 'Sınırsız kitap oluşturma ve yayınlama'), true),
                    (_sub('subscription.feature_studio', 'Yazı Stüdyosu tam erişim'), true),
                    (_sub('subscription.feature_badge', 'Onaylı yazar rozeti'), true),
                    (_sub('subscription.feature_support', 'Öncelikli destek'), true),
                  ],
                  limitText: null,
                  isPro: true,
                  isYearly: _isYearly,
                  monthlyPrice: _monthlyPrice,
                  yearlyPrice: _yearlyPrice,
                  onSubscribe: userId != null ? () => _subscribe(userId) : null,
                  isLoading: _isLoading,
                  sub: _sub,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PeriodToggle(
          isYearly: _isYearly,
          onChanged: (v) => setState(() => _isYearly = v),
          sub: _sub,
        ),
        const SizedBox(height: 20),
        Text(
          _sub('subscription.swipe_hint', 'Kartları kaydırarak planları inceleyin'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _subscribe(String userId) async {
    setState(() => _isLoading = true);
    final days = _isYearly ? 365 : 30;
    final planType = _isYearly ? 'yearly' : 'monthly';
    final amount = _isYearly ? _yearlyPrice : _monthlyPrice;

    try {
      await widget.ref.read(subscriptionRepositoryProvider).activateSubscription(
            userId: userId,
            durationDays: days,
          );
      await widget.ref.read(subscriptionRepositoryProvider).recordPayment(
            userId: userId,
            planType: planType,
            amount: amount,
          );
      widget.ref.invalidate(currentProfileProvider);
      widget.ref.invalidate(paymentHistoryProvider);
      widget.ref.invalidate(isProProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_sub('subscription.activated', 'Aboneliğiniz başarıyla aktifleştirildi!')),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSubscribed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_sub('subscription.error', 'Hata') + ': $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ToolIconsRow extends StatelessWidget {
  const _ToolIconsRow({required this.theme, required this.sub});
  final ThemeData theme;
  final String Function(String, String) sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolIcon(
          icon: Icons.auto_stories_rounded,
          label: sub('subscription.tool_books', 'Kitap Oluşturma'),
          theme: theme,
        ),
        _ToolIcon(
          icon: Icons.edit_note_rounded,
          label: sub('subscription.tool_studio', 'Yazı Stüdyosu'),
          theme: theme,
        ),
        _ToolIcon(
          icon: Icons.publish_rounded,
          label: sub('subscription.tool_publish', 'Yayınlama'),
          theme: theme,
        ),
      ],
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.theme,
  });
  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GlassPlanCard extends StatelessWidget {
  const _GlassPlanCard({
    required this.theme,
    required this.planName,
    required this.accentColor,
    required this.description,
    required this.features,
    this.limitText,
    required this.isPro,
    this.isYearly,
    this.monthlyPrice,
    this.yearlyPrice,
    this.onSubscribe,
    required this.isLoading,
    required this.sub,
  });
  final ThemeData theme;
  final String planName;
  final Color accentColor;
  final String description;
  final List<(String, bool)> features;
  final String? limitText;
  final bool isPro;
  final bool? isYearly;
  final double? monthlyPrice;
  final double? yearlyPrice;
  final VoidCallback? onSubscribe;
  final bool isLoading;
  final String Function(String, String) sub;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            isPro ? Icons.workspace_premium_rounded : Icons.person_outline_rounded,
            size: 32,
            color: accentColor,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        planName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 10),
      for (final f in features)
        _FeatureRow(
          text: f.$1,
          included: f.$2,
          theme: theme,
        ),
    ];

    if (limitText != null && !isPro) {
      children.addAll([
        const SizedBox(height: 4),
        Text(
          limitText!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ]);
    }

    if (isPro && isYearly != null && monthlyPrice != null && yearlyPrice != null) {
      children.addAll([
        const SizedBox(height: 8),
        if (isYearly!)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              sub('subscription.save_percent', '%33 tasarruf'),
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₺${(isYearly! ? yearlyPrice! : monthlyPrice!).toStringAsFixed(2)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isYearly! ? sub('subscription.per_year', '/yıl') : sub('subscription.per_month', '/ay'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    sub('subscription.subscribe_btn', 'Abone Ol'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.5 : 0.6,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.text,
    required this.included,
    required this.theme,
  });
  final String text;
  final bool included;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: included ? AppColors.success : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.isYearly,
    required this.onChanged,
    required this.sub,
  });
  final bool isYearly;
  final ValueChanged<bool> onChanged;
  final String Function(String, String) sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isYearly ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sub('subscription.monthly', 'Aylık'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: !isYearly ? FontWeight.bold : FontWeight.normal,
                      color: !isYearly
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isYearly ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sub('subscription.yearly', 'Yıllık'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isYearly ? FontWeight.bold : FontWeight.normal,
                      color: isYearly
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
