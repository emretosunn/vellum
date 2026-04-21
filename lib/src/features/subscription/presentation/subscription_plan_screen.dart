import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lottie/lottie.dart';

import '../../../constants/app_colors.dart';
import '../../../utils/user_friendly_error.dart';
import '../services/purchase_service.dart';
import '../../auth/data/auth_repository.dart';

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
                      child: Material(
                        color: Colors.transparent,
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
  bool _loadingPrices = false;
  ProductDetails? _monthlyProduct;
  ProductDetails? _yearlyProduct;

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
  void initState() {
    super.initState();
    // Mağaza bağlantısını önceden başlat; böylece "Abone ol" tıklanınca Play penceresi hemen açılabilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.ref.read(subscriptionPurchaseServiceProvider).warmUpStore();
      _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingPrices = true);
    try {
      final products = await widget.ref
          .read(subscriptionPurchaseServiceProvider)
          .getSubscriptionProducts();
      if (!mounted) return;
      setState(() {
        _monthlyProduct = products['aylik_premium'];
        _yearlyProduct = products['yillik_premium'];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPrices = false);
      }
    }
  }

  String _currencySymbol(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'TRY':
        return '₺';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return code ?? '';
    }
  }

  String _derivedPerMonthFromYearly() {
    final yearly = _yearlyProduct;
    if (yearly == null) {
      return '\$${(_yearlyPrice / 12).toStringAsFixed(2)}';
    }
    final symbol = _currencySymbol(yearly.currencyCode);
    final v = yearly.rawPrice / 12;
    return '$symbol${v.toStringAsFixed(2)}';
  }

  String _yearlyPerYearLabel() {
    final yearly = _yearlyProduct;
    if (yearly == null) {
      return '\$${_yearlyPrice.toStringAsFixed(2)} / year';
    }
    return '${yearly.price} / ${_sub('subscription.per_year_word', 'year')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = widget.ref.read(authRepositoryProvider).currentUser?.id;
    final monthlyPriceText =
        _monthlyProduct?.price ?? '\$${_monthlyPrice.toStringAsFixed(2)}';
    final yearlyPerMonthText = _derivedPerMonthFromYearly();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
              TextButton(
                onPressed: () {},
                child: Text(_sub('subscription.restore', 'Restore')),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _sub('subscription.unlock_title', 'Unlock'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            _sub('subscription.unlock_subtitle', 'Unlimited Access'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          _BenefitTile(
            icon: Icons.lock_rounded,
            title: _sub('subscription.benefit_1_title', 'Full access to all content'),
            subtitle: _sub(
              'subscription.benefit_1_subtitle',
              'Unlock your full potential with instant and unlimited access to all content.',
            ),
          ),
          _BenefitTile(
            icon: Icons.favorite_rounded,
            title: _sub('subscription.benefit_2_title', 'AI Coach/Dietitian Assistant 24/7'),
            subtitle: _sub(
              'subscription.benefit_2_subtitle',
              'Your 24/7 smart assistant guiding your writing and productivity goals.',
            ),
          ),
          _BenefitTile(
            icon: Icons.notifications_active_rounded,
            title: _sub('subscription.benefit_3_title', 'Unlimited Habit Reminders'),
            subtitle: _sub(
              'subscription.benefit_3_subtitle',
              'Stay on track with personalized and unlimited reminders.',
            ),
          ),
          const SizedBox(height: 14),
          _PlanOptionCard(
            selected: !_isYearly,
            title: _sub('subscription.monthly_label', 'Monthly'),
            trailingTop: monthlyPriceText,
            trailingBottom: _sub('subscription.monthly_suffix', '/ month'),
            onTap: () => setState(() => _isYearly = false),
            theme: theme,
          ),
          const SizedBox(height: 10),
          _PlanOptionCard(
            selected: _isYearly,
            title: _sub('subscription.yearly_label', 'Yearly'),
            leadingBottom: _yearlyPerYearLabel(),
            badgeText: _sub('subscription.best_price_badge', 'Best Price'),
            trailingTop: yearlyPerMonthText,
            trailingBottom: _sub('subscription.billed_annually', 'Billed annually'),
            onTap: () => setState(() => _isYearly = true),
            theme: theme,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: (_isLoading || userId == null) ? null : () => _subscribe(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _sub('subscription.continue', 'Continue'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _sub('subscription.terms_short', 'Terms'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _sub('subscription.privacy_short', 'Privacy'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_loadingPrices)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _sub('subscription.loading_prices', 'Fiyatlar güncelleniyor...'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _subscribe(String userId) async {
    setState(() => _isLoading = true);

    try {
      await widget.ref
          .read(subscriptionPurchaseServiceProvider)
          .purchaseSubscription(
            userId: userId,
            isYearly: _isYearly,
          );

      if (mounted) {
        await _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        final msg = toUserFriendlyErrorMessage(
          e,
          fallbackKey: 'subscription.error',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 190,
                    child: Lottie.asset(
                      'assets/animation/hello.json',
                      repeat: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sub('subscription.success_title', 'Vellum Pro Aktif!'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sub(
                      'subscription.success_subtitle',
                      'Tüm premium özellikler artık hesabınızda aktif.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onSubscribed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _sub('subscription.success_continue', 'Harika, devam et'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.selected,
    required this.title,
    this.leadingBottom,
    this.badgeText,
    required this.trailingTop,
    required this.trailingBottom,
    required this.onTap,
    required this.theme,
  });

  final bool selected;
  final String title;
  final String? leadingBottom;
  final String? badgeText;
  final String trailingTop;
  final String trailingBottom;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : theme.colorScheme.outline.withValues(alpha: 0.35),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (leadingBottom != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        leadingBottom!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (badgeText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  trailingTop,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  trailingBottom,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

